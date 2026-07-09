// YUNSH OS - Glass Effect (Qt ShaderEffect)
// Provides frosted glass blur effect for QML items

import QtQuick 2.15

ShaderEffect {
    property var source
    property real blurRadius: 20.0
    
    fragmentShader: "
        #version 150
        uniform sampler2D source;
        uniform vec2 qt_SubRect_Size;
        uniform float blurRadius;
        
        in vec2 qt_TexCoord0;
        out vec4 fragColor;
        
        const float weights[5] = float[](
            0.227027, 0.194594, 0.121621, 0.054054, 0.016216
        );
        
        void main() {
            vec2 texelSize = qt_SubRect_Size / blurRadius;
            vec2 uv = qt_TexCoord0;
            vec4 color = vec4(0.0);
            float totalWeight = 0.0;
            
            // Horizontal blur
            for (int i = -4; i <= 4; i++) {
                float w = weights[abs(i)];
                color += texture(source, uv + vec2(float(i) * texelSize.x, 0.0)) * w;
                totalWeight += w;
            }
            
            // Vertical blur
            vec4 colorV = vec4(0.0);
            totalWeight = 0.0;
            for (int i = -4; i <= 4; i++) {
                float w = weights[abs(i)];
                colorV += texture(source, uv + vec2(0.0, float(i) * texelSize.y)) * w;
                totalWeight += w;
            }
            
            fragColor = mix(color / 1.0, colorV / totalWeight, 0.5);
        }
    "
}
