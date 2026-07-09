#version 300 es

// YUNSH OS Compositor - Full-screen quad vertex shader
in vec4 a_position;
in vec2 a_texcoord;
out vec2 v_texcoord;

void main() {
    gl_Position = a_position;
    v_texcoord = a_texcoord;
}
