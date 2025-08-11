shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0, 0.1) = 2.0;
uniform bool show_outline = true;

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    
    if (show_outline) {
        // Sample neighboring pixels for outline
        vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
        
        float alpha_sum = 0.0;
        float samples = 0.0;
        
        // More samples for smoother outline
        for(float x = -1.0; x <= 1.0; x += 0.5) {
            for(float y = -1.0; y <= 1.0; y += 0.5) {
                if (x == 0.0 && y == 0.0) continue;
                
                vec2 offset = vec2(x, y) * size;
                alpha_sum += texture(TEXTURE, UV + offset).a;
                samples += 1.0;
            }
        }
        
        float outline_alpha = alpha_sum / samples;
        
        // If current pixel is transparent but neighbors have alpha, draw outline
        if (col.a < 0.5 && outline_alpha > 0.1) {
            COLOR = outline_color;
            COLOR.a = min(outline_alpha * 2.0, 1.0);
        } else if (col.a >= 0.5) {
            // Draw the original sprite on top
            COLOR = col;
        } else {
            COLOR = vec4(0.0);
        }
    } else {
        COLOR = col;
    }
}