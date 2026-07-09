#version 300 es
precision mediump float;

// YUNSH OS Compositor - Glassmorphism shader
// Renders frosted glass effect with blur and transparency

uniform sampler2D u_screen;
uniform vec2 u_resolution;
uniform vec2 u_position;
uniform vec2 u_size;
uniform float u_blur_radius;
uniform vec4 u_border_color;
uniform float u_opacity;

in vec2 v_texcoord;

out vec4 fragColor;

// Gaussian blur using 2-pass separable convolution
// 9-tap kernel approximation
const float weights[5] = float[](
    0.227027,  // center
    0.194594,  // 1 step
    0.121621,  // 2 steps
    0.054054,  // 3 steps
    0.016216   // 4 steps
);

void main() {
    vec2 texelSize = 1.0 / u_resolution;
    vec2 uv = v_texcoord;
    
    // Calculate pixel position in screen space
    vec2 pos = uv * u_resolution;
    
    // Check if we're inside the glass panel
    vec2 panelStart = u_position;
    vec2 panelEnd = u_position + u_size;
    
    // Edge distance for border calculation
    vec2 edgeDist = min(uv - panelStart / u_resolution, panelEnd / u_resolution - uv);
    float minEdge = min(edgeDist.x * u_resolution.x, edgeDist.y * u_resolution.y);
    
    // Blur the background (only sample if inside panel)
    vec3 blurColor = vec3(0.0);
    float totalWeight = 0.0;
    
    // Horizontal blur pass
    for (int x = -4; x <= 4; x++) {
        float weight = weights[abs(x)];
        vec2 offset = vec2(float(x) * u_blur_radius * texelSize.x, 0.0);
        vec2 sampleUV = uv + offset;
        
        // Clamp to screen bounds
        sampleUV = clamp(sampleUV, 0.0, 1.0);
        
        vec4 sample = texture(u_screen, sampleUV);
        blurColor += sample.rgb * weight;
        totalWeight += weight;
    }
    
    // Vertical blur pass (on the already-horizontally-blurred result)
    vec3 finalBlur = vec3(0.0);
    totalWeight = 0.0;
    for (int y = -4; y <= 4; y++) {
        float weight = weights[abs(y)];
        vec2 offset = vec2(0.0, float(y) * u_blur_radius * texelSize.y);
        vec2 sampleUV = uv + offset;
        sampleUV = clamp(sampleUV, 0.0, 1.0);
        
        vec4 sample = texture(u_screen, sampleUV);
        finalBlur += sample.rgb * weight;
        totalWeight += weight;
    }
    
    // Glass overlay color (dark translucent)
    vec3 glassColor = vec3(0.078, 0.078, 0.118); // rgba(20,20,30)
    
    // Mix blurred background with glass color
    vec3 outputColor = mix(finalBlur / totalWeight, glassColor, 0.6);
    
    // Apply opacity
    outputColor *= u_opacity;
    
    // Add frosted white tint
    outputColor += vec3(0.02, 0.02, 0.03);
    
    // Border: thin white semi-transparent edge
    float borderWidth = 1.5;
    float borderAlpha = 0.0;
    if (minEdge < borderWidth) {
        borderAlpha = 1.0 - (minEdge / borderWidth);
        borderAlpha *= 0.15; // 15% opacity border
    }
    
    vec3 borderOutput = mix(outputColor, u_border_color.rgb, borderAlpha);
    
    fragColor = vec4(borderOutput, u_opacity * (0.85 + borderAlpha * 0.15));
}
