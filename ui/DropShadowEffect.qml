// YUNSH OS - Drop Shadow Effect

import QtQuick 2.15

ShaderEffect {
    property var source
    property real radius: 32.0
    property int samples: 65
    property color color: Qt.rgba(0, 0, 0, 0.3)
    property real horizontalOffset: 0
    property real verticalOffset: 8
    
    fragmentShader: "
        #version 150
        uniform sampler2D source;
        uniform vec2 qt_SubRect_Size;
        uniform float radius;
        uniform vec4 color;
        uniform vec2 offset;
        
        in vec2 qt_TexCoord0;
        out vec4 fragColor;
        
        void main() {
            vec2 uv = qt_TexCoord0 - offset * qt_SubRect_Size;
            float alpha = 0.0;
            vec2 pixel = qt_SubRect_Size * 2.0;
            
            float stepSize = radius / float(32);
            for (float x = -radius; x <= radius; x += stepSize) {
                for (float y = -radius; y <= radius; y += stepSize) {
                    float dist = length(vec2(x, y));
                    if (dist > radius) continue;
                    float w = exp(-dist * dist / (radius * radius * 0.5));
                    alpha += texture(source, uv + vec2(x, y) * pixel).a * w;
                }
            }
            
            alpha = min(alpha / 200.0, 1.0);
            fragColor = vec4(color.rgb, color.a * alpha);
        }
    "
}
