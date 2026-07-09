// YUNSH OS v1.0 - Display Compositor
// Hardware: Raspberry Pi 4B/5 + 1080p Micro-OLED AR Glasses
// Key feature: Pure black (#000000) background → transparent in AR glasses
// Glassmorphism UI rendering using DRM/KMS + OpenGL ES 3.0

#ifndef YUNSH_COMPOSITOR_H
#define YUNSH_COMPOSITOR_H

#include <cstdint>
#include <string>
#include <vector>
#include <memory>
#include <functional>

// DRM structures
struct drm_screen;
struct drm_buffer;

// EGL/GLES contexts
struct egl_context;

// Window management
struct yunsh_window {
    int32_t x, y;
    int32_t width, height;
    std::string title;
    bool visible;
    bool focused;
    uint32_t id;
    void* native_handle; // Wayland/Android surface handle
};

// Compositor surface types
enum class SurfaceType {
    Desktop,      // Pure black (transparent in AR)
    GlassPanel,   // Glassmorphism panel
    AppWindow,    // Running application window
    Cursor,       // Mouse cursor overlay
    StatusBar     // Top status bar
};

// Input event
struct InputEvent {
    enum Type { MouseMove, MousePress, MouseRelease, MouseScroll,
                KeyPress, KeyRelease, TouchDown, TouchUp, TouchMove };
    Type type;
    int32_t x, y;
    int32_t dx, dy;     // Relative motion / scroll delta
    uint32_t button;     // Mouse button
    uint32_t keycode;    // Keyboard key
    uint32_t timestamp;
};

class YUNSHCompositor {
public:
    YUNSHCompositor();
    ~YUNSHCompositor();

    // Initialize DRM, EGL, and GLES
    bool init(int argc, char** argv);

    // Main loop
    int run();

    // Cleanup
    void shutdown();

    // === Window Management ===
    uint32_t create_window(const std::string& title, int x, int y, int w, int h);
    void destroy_window(uint32_t id);
    void move_window(uint32_t id, int x, int y);
    void resize_window(uint32_t id, int w, int h);
    void focus_window(uint32_t id);
    void set_window_visible(uint32_t id, bool visible);

    // === Rendering ===
    void clear_screen();                    // Pure black clear (transparent in AR)
    void render_glass_panel(int x, int y, int w, int h, float opacity);
    void render_cursor(int x, int y);
    void present();                         // Swap buffers

    // === Input ===
    void set_input_callback(std::function<void(const InputEvent&)> cb);

    // === Compositing ===
    void composite_frame();

private:
    // DRM helpers
    bool init_drm();
    bool init_egl();
    bool init_gles();
    void destroy_drm();
    void destroy_egl();

    // Shader helpers
    bool load_shaders();
    GLuint compile_shader(GLenum type, const std::string& source);
    GLuint link_program(GLuint vert, GLuint frag);

    // Frame buffer
    void setup_framebuffer();
    void render_fullscreen_quad();

    // Hardware cursor
    void setup_cursor();

    // Members
    struct drm_screen* m_drm;
    struct egl_context* m_egl;

    // Current screen state
    int32_t m_screen_width;
    int32_t m_screen_height;

    // GL resources
    GLuint m_glass_program;
    GLuint m_fullscreen_vao;
    GLuint m_fullscreen_vbo;

    // Uniform locations
    GLint u_screen_loc;
    GLint u_resolution_loc;
    GLint u_position_loc;
    GLint u_size_loc;
    GLint u_blur_radius_loc;
    GLint u_border_color_loc;
    GLint u_opacity_loc;

    // Cursor
    int32_t m_cursor_x;
    int32_t m_cursor_y;
    bool m_cursor_visible;
    GLuint m_cursor_texture;

    // Windows
    std::vector<yunsh_window> m_windows;
    uint32_t m_next_window_id;
    uint32_t m_focused_window_id;

    // State
    bool m_running;
    uint64_t m_frame_count;
    float m_fps;

    // Input callback
    std::function<void(const InputEvent&)> m_input_cb;

    // Timestamp for animations
    uint64_t m_uptime_ms;
};

#endif // YUNSH_COMPOSITOR_H
