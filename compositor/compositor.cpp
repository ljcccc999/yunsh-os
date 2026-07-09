// YUNSH OS v1.0 - Display Compositor Implementation
// DRM/KMS + OpenGL ES 3.0 compositor with glassmorphism effects
// Pure black background for AR transparency

#include "compositor.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <chrono>
#include <thread>
#include <fstream>
#include <sstream>

// DRM headers
#include <xf86drm.h>
#include <xf86drmMode.h>
#include <drm_fourcc.h>

// EGL/GLES
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES3/gl3.h>
#include <GLES3/gl2ext.h>

// libinput
#include <libinput.h>
#include <libudev.h>

// ============================================================
// DRM structures
// ============================================================
struct drm_buffer {
    uint32_t width;
    uint32_t height;
    uint32_t stride;
    uint32_t size;
    uint32_t handle;
    uint32_t fb_id;
    uint8_t* map;
    int dmabuf_fd;
};

struct drm_screen {
    int fd;
    drmModeModeInfo mode;
    uint32_t connector_id;
    uint32_t encoder_id;
    uint32_t crtc_id;
    drmModeCrtc* saved_crtc;
    struct drm_buffer buffers[2];
    int front_buffer;
    int double_buffered;
};

// ============================================================
// EGL context
// ============================================================
struct egl_context {
    EGLDisplay display;
    EGLConfig config;
    EGLContext context;
    EGLSurface surface;
    EGLNativeWindowType native_window;
};

// ============================================================
// Shader sources
// ============================================================
static const char* glass_frag_src = R"(
#version 300 es
precision mediump float;
uniform sampler2D u_screen;
uniform vec2 u_resolution;
uniform vec2 u_position;
uniform vec2 u_size;
uniform float u_blur_radius;
uniform vec4 u_border_color;
uniform float u_opacity;
in vec2 v_texcoord;
out vec4 fragColor;

const float weights[5] = float[](0.227027, 0.194594, 0.121621, 0.054054, 0.016216);

void main() {
    vec2 texelSize = 1.0 / u_resolution;
    vec2 uv = v_texcoord;
    vec2 pos = uv * u_resolution;
    vec2 panelStart = u_position;
    vec2 panelEnd = u_position + u_size;
    vec2 edgeDist = min(uv - panelStart / u_resolution, panelEnd / u_resolution - uv);
    float minEdge = min(edgeDist.x * u_resolution.x, edgeDist.y * u_resolution.y);

    vec3 blurH = vec3(0.0);
    float tw = 0.0;
    for (int x = -4; x <= 4; x++) {
        float w = weights[abs(x)];
        vec2 off = vec2(float(x) * u_blur_radius * texelSize.x, 0.0);
        blurH += texture(u_screen, clamp(uv + off, 0.0, 1.0)).rgb * w;
        tw += w;
    }
    vec3 blurV = vec3(0.0);
    tw = 0.0;
    for (int y = -4; y <= 4; y++) {
        float w = weights[abs(y)];
        vec2 off = vec2(0.0, float(y) * u_blur_radius * texelSize.y);
        blurV += texture(u_screen, clamp(uv + off, 0.0, 1.0)).rgb * w;
        tw += w;
    }
    vec3 blurred = mix(blurH / 1.0, blurV / tw, 0.5);
    vec3 glassColor = vec3(0.078, 0.078, 0.118);
    vec3 mixed = mix(blurred, glassColor, 0.6);
    mixed *= u_opacity;
    mixed += vec3(0.02, 0.02, 0.03);

    float borderWidth = 1.5;
    float borderAlpha = 0.0;
    if (minEdge < borderWidth) {
        borderAlpha = (1.0 - minEdge / borderWidth) * 0.15;
    }
    vec3 finalC = mix(mixed, u_border_color.rgb, borderAlpha);
    fragColor = vec4(finalC, u_opacity * (0.85 + borderAlpha * 0.15));
}
)";

// ============================================================
// Full-screen quad vertex shader
// ============================================================
static const char* fullscreen_vert_src = R"(
#version 300 es
in vec4 a_position;
in vec2 a_texcoord;
out vec2 v_texcoord;
void main() {
    gl_Position = a_position;
    v_texcoord = a_texcoord;
}
)";

// ============================================================
// Cursor rendering fragment shader
// ============================================================
static const char* cursor_frag_src = R"(
#version 300 es
precision mediump float;
uniform vec4 u_cursor_color;
out vec4 fragColor;
void main() {
    vec2 uv = gl_PointCoord - vec2(0.5);
    float dist = length(uv);
    if (dist > 0.5) discard;
    float alpha = 1.0 - smoothstep(0.0, 0.5, dist);
    fragColor = vec4(u_cursor_color.rgb, alpha * 0.9);
}
)";

// ============================================================
// Constructor / Destructor
// ============================================================
YUNSHCompositor::YUNSHCompositor()
    : m_drm(nullptr)
    , m_egl(nullptr)
    , m_screen_width(1920)
    , m_screen_height(1080)
    , m_glass_program(0)
    , m_fullscreen_vao(0)
    , m_fullscreen_vbo(0)
    , m_cursor_x(960)
    , m_cursor_y(540)
    , m_cursor_visible(true)
    , m_cursor_texture(0)
    , m_next_window_id(1)
    , m_focused_window_id(0)
    , m_running(false)
    , m_frame_count(0)
    , m_fps(0.0f)
    , m_uptime_ms(0)
{
}

YUNSHCompositor::~YUNSHCompositor() {
    shutdown();
}

// ============================================================
// DRM Initialization
// ============================================================
bool YUNSHCompositor::init_drm() {
    m_drm = new drm_screen();
    memset(m_drm, 0, sizeof(drm_screen));

    // Open DRM device
    const char* devices[] = { "/dev/dri/card0", "/dev/dri/card1", nullptr };
    for (int i = 0; devices[i]; i++) {
        m_drm->fd = open(devices[i], O_RDWR | O_CLOEXEC);
        if (m_drm->fd >= 0) break;
    }
    if (m_drm->fd < 0) {
        fprintf(stderr, "YUNSH: Cannot open DRM device\n");
        return false;
    }

    // Get resources
    drmModeRes* resources = drmModeGetResources(m_drm->fd);
    if (!resources) {
        fprintf(stderr, "YUNSH: Cannot get DRM resources\n");
        return false;
    }

    // Find first connected connector
    drmModeConnector* connector = nullptr;
    for (int i = 0; i < resources->count_connectors; i++) {
        connector = drmModeGetConnector(m_drm->fd, resources->connectors[i]);
        if (connector && connector->connection == DRM_MODE_CONNECTED) {
            break;
        }
        drmModeFreeConnector(connector);
        connector = nullptr;
    }

    if (!connector) {
        fprintf(stderr, "YUNSH: No connected display found\n");
        drmModeFreeResources(resources);
        return false;
    }

    m_drm->connector_id = connector->connector_id;

    // Pick preferred mode or first mode
    bool found_mode = false;
    for (int i = 0; i < connector->count_modes && !found_mode; i++) {
        drmModeModeInfo* mode = &connector->modes[i];
        if (mode->hdisplay == 1920 && mode->vdisplay == 1080) {
            m_drm->mode = *mode;
            found_mode = true;
        }
    }
    if (!found_mode && connector->count_modes > 0) {
        // Force 1080p timing for AR glasses
        drmModeModeInfo custom_mode;
        memset(&custom_mode, 0, sizeof(custom_mode));
        custom_mode.clock = 165000;
        custom_mode.hdisplay = 1920;
        custom_mode.hsync_start = 1964;
        custom_mode.hsync_end = 1972;
        custom_mode.htotal = 2120;
        custom_mode.vdisplay = 1080;
        custom_mode.vsync_start = 1084;
        custom_mode.vsync_end = 1088;
        custom_mode.vtotal = 1086;
        custom_mode.vrefresh = 60;
        snprintf(custom_mode.name, sizeof(custom_mode.name), "1920x1080");
        m_drm->mode = custom_mode;
    }

    m_screen_width = m_drm->mode.hdisplay;
    m_screen_height = m_drm->mode.vdisplay;

    printf("YUNSH: Display mode: %dx%d@%dHz\n",
           m_screen_width, m_screen_height, m_drm->mode.vrefresh);

    // Get CRTC
    drmModeEncoder* encoder = drmModeGetEncoder(m_drm->fd, connector->encoder_id);
    if (!encoder) {
        // Try to find encoder manually
        for (int i = 0; i < resources->count_encoders; i++) {
            encoder = drmModeGetEncoder(m_drm->fd, resources->encoders[i]);
            if (encoder && (encoder->possible_crtcs & (1 << 0))) break;
            drmModeFreeEncoder(encoder);
            encoder = nullptr;
        }
    }

    if (encoder) {
        m_drm->encoder_id = encoder->encoder_id;
        m_drm->crtc_id = encoder->crtc_id;
        drmModeFreeEncoder(encoder);
    }

    // Save CRTC state
    m_drm->saved_crtc = drmModeGetCrtc(m_drm->fd, m_drm->crtc_id);

    drmModeFreeConnector(connector);
    drmModeFreeResources(resources);

    printf("YUNSH: DRM initialized, CRTC=%u, Connector=%u\n",
           m_drm->crtc_id, m_drm->connector_id);

    return true;
}

// ============================================================
// EGL Initialization
// ============================================================
bool YUNSHCompositor::init_egl() {
    m_egl = new egl_context();
    memset(m_egl, 0, sizeof(egl_context));

    // Get display
    m_egl->display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (m_egl->display == EGL_NO_DISPLAY) {
        // Try DRM display
        m_egl->display = eglGetDisplay((EGLNativeDisplayType)m_drm->fd);
    }
    if (m_egl->display == EGL_NO_DISPLAY) {
        fprintf(stderr, "YUNSH: Cannot get EGL display\n");
        return false;
    }

    EGLint major, minor;
    if (!eglInitialize(m_egl->display, &major, &minor)) {
        fprintf(stderr, "YUNSH: Cannot initialize EGL\n");
        return false;
    }
    printf("YUNSH: EGL %d.%d initialized\n", major, minor);

    // Choose config
    EGLint attribs[] = {
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
        EGL_RED_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE, 8,
        EGL_ALPHA_SIZE, 8,
        EGL_DEPTH_SIZE, 24,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
        EGL_NONE
    };

    EGLint config_count;
    if (!eglChooseConfig(m_egl->display, attribs, &m_egl->config, 1, &config_count) || config_count == 0) {
        fprintf(stderr, "YUNSH: Cannot choose EGL config\n");
        return false;
    }

    // Bind API
    eglBindAPI(EGL_OPENGL_ES_API);

    // Create context
    EGLint ctx_attribs[] = {
        EGL_CONTEXT_CLIENT_VERSION, 3,
        EGL_NONE
    };
    m_egl->context = eglCreateContext(m_egl->display, m_egl->config, EGL_NO_CONTEXT, ctx_attribs);
    if (m_egl->context == EGL_NO_CONTEXT) {
        fprintf(stderr, "YUNSH: Cannot create EGL context\n");
        return false;
    }

    // Create window surface
    // For KMS/DRM, we use EGL_KHR_platform_gbm or create pbuffer
    EGLint surf_attribs[] = {
        EGL_WIDTH, m_screen_width,
        EGL_HEIGHT, m_screen_height,
        EGL_NONE
    };
    m_egl->surface = eglCreatePbufferSurface(m_egl->display, m_egl->config, surf_attribs);
    if (m_egl->surface == EGL_NO_SURFACE) {
        fprintf(stderr, "YUNSH: Cannot create EGL surface\n");
        return false;
    }

    // Make current
    if (!eglMakeCurrent(m_egl->display, m_egl->surface, m_egl->surface, m_egl->context)) {
        fprintf(stderr, "YUNSH: Cannot make EGL current\n");
        return false;
    }

    printf("YUNSH: EGL context created, GLES %s\n", glGetString(GL_VERSION));
    return true;
}

// ============================================================
// Shader loading
// ============================================================
GLuint YUNSHCompositor::compile_shader(GLenum type, const std::string& source) {
    GLuint shader = glCreateShader(type);
    const char* src = source.c_str();
    glShaderSource(shader, 1, &src, nullptr);
    glCompileShader(shader);

    GLint compiled;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    if (!compiled) {
        GLint info_len = 0;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &info_len);
        std::string info(info_len, '\0');
        glGetShaderInfoLog(shader, info_len, nullptr, &info[0]);
        fprintf(stderr, "YUNSH: Shader compile error: %s\n", info.c_str());
        glDeleteShader(shader);
        return 0;
    }
    return shader;
}

GLuint YUNSHCompositor::link_program(GLuint vert, GLuint frag) {
    GLuint program = glCreateProgram();
    glAttachShader(program, vert);
    glAttachShader(program, frag);
    glLinkProgram(program);

    GLint linked;
    glGetProgramiv(program, GL_LINK_STATUS, &linked);
    if (!linked) {
        GLint info_len = 0;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &info_len);
        std::string info(info_len, '\0');
        glGetProgramInfoLog(program, info_len, nullptr, &info[0]);
        fprintf(stderr, "YUNSH: Program link error: %s\n", info.c_str());
        glDeleteProgram(program);
        return 0;
    }
    return program;
}

bool YUNSHCompositor::load_shaders() {
    // Glassmorphism shader
    GLuint vert = compile_shader(GL_VERTEX_SHADER, fullscreen_vert_src);
    GLuint frag = compile_shader(GL_FRAGMENT_SHADER, glass_frag_src);
    if (!vert || !frag) return false;

    m_glass_program = link_program(vert, frag);
    if (!m_glass_program) return false;

    // Get uniform locations
    u_screen_loc = glGetUniformLocation(m_glass_program, "u_screen");
    u_resolution_loc = glGetUniformLocation(m_glass_program, "u_resolution");
    u_position_loc = glGetUniformLocation(m_glass_program, "u_position");
    u_size_loc = glGetUniformLocation(m_glass_program, "u_size");
    u_blur_radius_loc = glGetUniformLocation(m_glass_program, "u_blur_radius");
    u_border_color_loc = glGetUniformLocation(m_glass_program, "u_border_color");
    u_opacity_loc = glGetUniformLocation(m_glass_program, "u_opacity");

    glDeleteShader(vert);
    glDeleteShader(frag);

    printf("YUNSH: Glassmorphism shader loaded\n");
    return true;
}

// ============================================================
// Full-screen quad setup
// ============================================================
void YUNSHCompositor::setup_framebuffer() {
    // Full-screen quad: 2 triangles forming a rectangle
    // Positions (x,y) and texture coords (u,v)
    GLfloat vertices[] = {
        // pos       // tex
        -1.0f, -1.0f, 0.0f, 0.0f,
         1.0f, -1.0f, 1.0f, 0.0f,
        -1.0f,  1.0f, 0.0f, 1.0f,
         1.0f,  1.0f, 1.0f, 1.0f,
    };

    glGenVertexArrays(1, &m_fullscreen_vao);
    glGenBuffers(1, &m_fullscreen_vbo);

    glBindVertexArray(m_fullscreen_vao);
    glBindBuffer(GL_ARRAY_BUFFER, m_fullscreen_vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), (void*)0);
    glEnableVertexAttribArray(0);

    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), (void*)(2 * sizeof(GLfloat)));
    glEnableVertexAttribArray(1);

    glBindVertexArray(0);
}

void YUNSHCompositor::render_fullscreen_quad() {
    glBindVertexArray(m_fullscreen_vao);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glBindVertexArray(0);
}

// ============================================================
// Initialization
// ============================================================
bool YUNSHCompositor::init(int argc, char** argv) {
    printf("YUNSH: Compositor initializing...\n");

    if (!init_drm()) {
        fprintf(stderr, "YUNSH: DRM init failed\n");
        return false;
    }

    // Setup DRM framebuffers for direct scanout
    printf("YUNSH: Creating framebuffers (%dx%d)\n", m_screen_width, m_screen_height);

    // Simple DRM framebuffer setup using dumb buffers
    for (int i = 0; i < 2; i++) {
        struct drm_mode_create_dumb create = {};
        create.width = m_screen_width;
        create.height = m_screen_height;
        create.bpp = 32;
        
        int ret = drmIoctl(m_drm->fd, DRM_IOCTL_MODE_CREATE_DUMB, &create);
        if (ret < 0) {
            fprintf(stderr, "YUNSH: Cannot create dumb buffer\n");
            return false;
        }

        m_drm->buffers[i].width = create.width;
        m_drm->buffers[i].height = create.height;
        m_drm->buffers[i].stride = create.pitch;
        m_drm->buffers[i].size = create.size;
        m_drm->buffers[i].handle = create.handle;

        // Get FB ID
        ret = drmModeAddFB(m_drm->fd, m_screen_width, m_screen_height,
                           24, 32, create.pitch, create.handle,
                           &m_drm->buffers[i].fb_id);
        if (ret) {
            // Try with depth 32
            ret = drmModeAddFB(m_drm->fd, m_screen_width, m_screen_height,
                               32, 32, create.pitch, create.handle,
                               &m_drm->buffers[i].fb_id);
        }
        if (ret) {
            fprintf(stderr, "YUNSH: Cannot add FB\n");
            return false;
        }

        // Map buffer
        struct drm_mode_map_dumb map = {};
        map.handle = create.handle;
        ret = drmIoctl(m_drm->fd, DRM_IOCTL_MODE_MAP_DUMB, &map);
        if (ret) {
            fprintf(stderr, "YUNSH: Cannot map dumb buffer\n");
            return false;
        }

        m_drm->buffers[i].map = (uint8_t*)mmap(0, create.size, PROT_READ | PROT_WRITE,
                                                MAP_SHARED, m_drm->fd, map.offset);
        if (m_drm->buffers[i].map == MAP_FAILED) {
            fprintf(stderr, "YUNSH: Cannot mmap dumb buffer\n");
            return false;
        }

        // Clear to pure black
        memset(m_drm->buffers[i].map, 0, create.size);
    }

    m_drm->front_buffer = 0;

    if (!init_egl()) {
        fprintf(stderr, "YUNSH: EGL init failed, continuing with software mode\n");
    }

    if (!load_shaders()) {
        fprintf(stderr, "YUNSH: Shader loading failed\n");
        return false;
    }

    setup_framebuffer();

    // Setup GL state
    glViewport(0, 0, m_screen_width, m_screen_height);
    glDisable(GL_DEPTH_TEST);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    printf("YUNSH: Compositor initialized successfully\n");
    return true;
}

// ============================================================
// Clear screen to pure black (transparent in AR glasses)
// ============================================================
void YUNSHCompositor::clear_screen() {
    // Pure black = fully transparent in AR glasses with black=transparent setup
    // Clear both backbuffer and frontbuffer
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    // Also clear the DRM buffer directly
    if (m_drm && m_drm->buffers) {
        int back = 1 - m_drm->front_buffer;
        memset(m_drm->buffers[back].map, 0, m_drm->buffers[back].size);
    }
}

// ============================================================
// Render glassmorphism panel
// ============================================================
void YUNSHCompositor::render_glass_panel(int x, int y, int w, int h, float opacity) {
    if (!m_glass_program) return;

    glUseProgram(m_glass_program);

    // Set uniforms
    glUniform2f(u_resolution_loc, m_screen_width, m_screen_height);
    glUniform2f(u_position_loc, (float)x, (float)y);
    glUniform2f(u_size_loc, (float)w, (float)h);
    glUniform1f(u_blur_radius_loc, 20.0f);
    glUniform4f(u_border_color_loc, 1.0f, 1.0f, 1.0f, 0.1f);
    glUniform1f(u_opacity_loc, opacity);

    // Bind screen texture (current FB content for blur)
    glUniform1i(u_screen_loc, 0);

    render_fullscreen_quad();
    glUseProgram(0);
}

// ============================================================
// Render cursor
// ============================================================
void YUNSHCompositor::render_cursor(int x, int y) {
    if (!m_cursor_visible) return;

    // Simple cursor: white filled circle with dark outline
    const int cursor_size = 20;
    const int outline_size = 22;

    // Draw outline
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    // We'll use a simple approach: draw a small quad with a circle texture
    // For simplicity, use points with point sprite
    // Actually, let's just draw it with a simple shader

    // For now, cursor is rendered by Qt6 UI layer; hardware cursor if available
    // Software cursor fallback:
    uint8_t* fb = m_drm->buffers[m_drm->front_buffer].map;
    int stride = m_drm->buffers[m_drm->front_buffer].stride;
    int bpp = 4; // 32-bit

    for (int dy = -outline_size/2; dy <= outline_size/2; dy++) {
        for (int dx = -outline_size/2; dx <= outline_size/2; dx++) {
            int px = x + dx;
            int py = y + dy;
            if (px < 0 || px >= m_screen_width || py < 0 || py >= m_screen_height)
                continue;

            float dist = sqrtf(dx*dx + dy*dy);
            float radius = cursor_size / 2.0f;

            if (dist <= radius + 1.0f) {
                uint32_t* pixel = (uint32_t*)(fb + py * stride + px * bpp);
                float alpha = 1.0f - smoothstep(0.0f, radius, dist);
                uint8_t a = (uint8_t)(alpha * 230);
                uint8_t r = 255, g = 255, b = 255;

                if (dist > radius - 2.0f && dist <= radius) {
                    // Dark outline
                    r = 0; g = 0; b = 0; a = 200;
                }

                // Alpha blend with existing content
                uint32_t bg = *pixel;
                uint8_t bg_r = (bg >> 16) & 0xFF;
                uint8_t bg_g = (bg >> 8) & 0xFF;
                uint8_t bg_b = bg & 0xFF;

                float a_norm = a / 255.0f;
                uint8_t out_r = (uint8_t)(r * a_norm + bg_r * (1 - a_norm));
                uint8_t out_g = (uint8_t)(g * a_norm + bg_g * (1 - a_norm));
                uint8_t out_b = (uint8_t)(b * a_norm + bg_b * (1 - a_norm));

                *pixel = (0xFF << 24) | (out_r << 16) | (out_g << 8) | out_b;
            }
        }
    }
}

// ============================================================
// Present frame - Swap buffers and flip display
// ============================================================
void YUNSHCompositor::present() {
    if (!m_drm) return;

    // Flush EGL
    if (m_egl && m_egl->display) {
        eglSwapBuffers(m_egl->display, m_egl->surface);
    }

    // Flip DRM buffers
    int back = 1 - m_drm->front_buffer;
    int ret = drmModeSetCrtc(m_drm->fd, m_drm->crtc_id,
                              m_drm->buffers[back].fb_id,
                              0, 0,
                              &m_drm->connector_id, 1,
                              &m_drm->mode);
    if (ret) {
        fprintf(stderr, "YUNSH: Flip failed: %d\n", ret);
    }

    m_drm->front_buffer = back;
    m_frame_count++;
}

// ============================================================
// Composite a full frame
// ============================================================
void YUNSHCompositor::composite_frame() {
    auto frame_start = std::chrono::steady_clock::now();

    // 1. Clear to pure black (transparent in AR)
    clear_screen();

    // 2. Render UI panels (glassmorphism)
    // Status bar at top
    render_glass_panel(0, 0, m_screen_width, 48, 0.35f);

    // Dock at bottom
    render_glass_panel(0, m_screen_height - 80, m_screen_width, 80, 0.35f);

    // 3. Render app windows
    for (auto& win : m_windows) {
        if (!win.visible) continue;
        // Glass panel for each window
        render_glass_panel(win.x, win.y, win.width, win.height, 0.35f);
    }

    // 4. Render cursor
    render_cursor(m_cursor_x, m_cursor_y);

    // 5. Present to display
    present();

    // Update FPS
    auto frame_end = std::chrono::steady_clock::now();
    auto frame_us = std::chrono::duration_cast<std::chrono::microseconds>(frame_end - frame_start).count();
    if (frame_us > 0) {
        m_fps = m_fps * 0.95f + (1000000.0f / frame_us) * 0.05f;
    }
}

// ============================================================
// Window management
// ============================================================
uint32_t YUNSHCompositor::create_window(const std::string& title, int x, int y, int w, int h) {
    yunsh_window win;
    win.id = m_next_window_id++;
    win.x = x;
    win.y = y;
    win.width = w;
    win.height = h;
    win.title = title;
    win.visible = true;
    win.focused = false;
    win.native_handle = nullptr;

    m_windows.push_back(win);
    return win.id;
}

void YUNSHCompositor::destroy_window(uint32_t id) {
    for (auto it = m_windows.begin(); it != m_windows.end(); ++it) {
        if (it->id == id) {
            m_windows.erase(it);
            break;
        }
    }
}

void YUNSHCompositor::move_window(uint32_t id, int x, int y) {
    for (auto& win : m_windows) {
        if (win.id == id) {
            win.x = x;
            win.y = y;
            break;
        }
    }
}

void YUNSHCompositor::resize_window(uint32_t id, int w, int h) {
    for (auto& win : m_windows) {
        if (win.id == id) {
            win.width = w;
            win.height = h;
            break;
        }
    }
}

void YUNSHCompositor::focus_window(uint32_t id) {
    m_focused_window_id = id;
    for (auto& win : m_windows) {
        win.focused = (win.id == id);
    }
}

void YUNSHCompositor::set_window_visible(uint32_t id, bool visible) {
    for (auto& win : m_windows) {
        if (win.id == id) {
            win.visible = visible;
            break;
        }
    }
}

// ============================================================
// Input
// ============================================================
void YUNSHCompositor::set_input_callback(std::function<void(const InputEvent&)> cb) {
    m_input_cb = cb;
}

// ============================================================
// Main loop
// ============================================================
int YUNSHCompositor::run() {
    m_running = true;
    printf("YUNSH: Compositor entering main loop\n");

    // Set initial CRTC
    drmModeSetCrtc(m_drm->fd, m_drm->crtc_id,
                    m_drm->buffers[0].fb_id,
                    0, 0,
                    &m_drm->connector_id, 1,
                    &m_drm->mode);

    auto last_time = std::chrono::steady_clock::now();
    m_uptime_ms = 0;

    // Main render loop (target 60 FPS)
    const uint64_t frame_duration_us = 16666; // ~60 FPS

    while (m_running) {
        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(now - last_time).count();
        m_uptime_ms += elapsed / 1000;

        // Composite and render a frame
        composite_frame();

        // Frame rate limiting
        auto frame_time = std::chrono::duration_cast<std::chrono::microseconds>(
            std::chrono::steady_clock::now() - now).count();

        if (frame_time < frame_duration_us) {
            std::this_thread::sleep_for(
                std::chrono::microseconds(frame_duration_us - frame_time));
        }

        last_time = now;

        // Print FPS every 5 seconds
        if (m_frame_count % 300 == 0) {
            printf("YUNSH: FPS=%.1f\n", m_fps);
        }
    }

    return 0;
}

// ============================================================
// Shutdown
// ============================================================
void YUNSHCompositor::shutdown() {
    printf("YUNSH: Compositor shutting down\n");

    if (m_drm) {
        // Restore CRTC
        if (m_drm->saved_crtc) {
            drmModeSetCrtc(m_drm->fd, m_drm->saved_crtc->crtc_id,
                           m_drm->saved_crtc->buffer_id,
                           m_drm->saved_crtc->x, m_drm->saved_crtc->y,
                           &m_drm->connector_id, 1,
                           &m_drm->saved_crtc->mode);
            drmModeFreeCrtc(m_drm->saved_crtc);
        }

        // Cleanup buffers
        for (int i = 0; i < 2; i++) {
            if (m_drm->buffers[i].map) {
                munmap(m_drm->buffers[i].map, m_drm->buffers[i].size);
            }
            if (m_drm->buffers[i].fb_id) {
                drmModeRmFB(m_drm->fd, m_drm->buffers[i].fb_id);
            }
            if (m_drm->buffers[i].handle) {
                struct drm_mode_destroy_dumb destroy = {};
                destroy.handle = m_drm->buffers[i].handle;
                drmIoctl(m_drm->fd, DRM_IOCTL_MODE_DESTROY_DUMB, &destroy);
            }
        }

        if (m_drm->fd >= 0) close(m_drm->fd);
        delete m_drm;
        m_drm = nullptr;
    }

    // Cleanup GL
    if (m_glass_program) glDeleteProgram(m_glass_program);
    if (m_fullscreen_vao) glDeleteVertexArrays(1, &m_fullscreen_vao);
    if (m_fullscreen_vbo) glDeleteBuffers(1, &m_fullscreen_vbo);

    // Cleanup EGL
    if (m_egl) {
        eglMakeCurrent(EGL_NO_DISPLAY, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        if (m_egl->context) eglDestroyContext(m_egl->display, m_egl->context);
        if (m_egl->surface) eglDestroySurface(m_egl->display, m_egl->surface);
        if (m_egl->display) eglTerminate(m_egl->display);
        delete m_egl;
        m_egl = nullptr;
    }

    printf("YUNSH: Compositor shutdown complete\n");
}
