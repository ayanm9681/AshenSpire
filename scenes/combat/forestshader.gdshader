shader_type canvas_item;

uniform sampler2D lava_texture : repeat_enable;
uniform float scroll_x : hint_range(-1.0, 1.0) = 0.05;
uniform float scroll_y : hint_range(-1.0, 1.0) = 0.02;
uniform float distortion_strength : hint_range(0.0, 0.05) = 0.015;
uniform float distortion_speed : hint_range(0.0, 3.0) = 0.8;

void fragment() {
    vec2 uv = UV;
    
    // Wavy distortion to simulate heat/flow
    uv.x += sin(uv.y * 6.0 + TIME * distortion_speed) * distortion_strength;
    uv.y += cos(uv.x * 6.0 + TIME * distortion_speed) * distortion_strength;
    
    // Scroll the texture
    uv.x += TIME * scroll_x;
    uv.y += TIME * scroll_y;
    
    COLOR = texture(lava_texture, uv);
}