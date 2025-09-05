shader_type canvas_item;

uniform vec4  outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0, 0.1) = 3.0;
uniform bool  show_outline = true;
uniform float glow_intensity : hint_range(0.0, 1.0, 0.01) = 0.02;

void fragment() {
    vec4 original_color = texture(TEXTURE, UV);

    if (!show_outline) {
        // No early return in fragment(); just assign and let the branch end.
        COLOR = original_color;
    } else {
        // If TEXTURE_PIXEL_SIZE ever worries you, replace with:
        // vec2 texel = 1.0 / vec2(textureSize(TEXTURE, 0));
        vec2 pixel_size = TEXTURE_PIXEL_SIZE * outline_width;

        if (original_color.a < 0.1) {
            float max_outline_alpha = 0.0;

            const int SAMPLES = 16;                       // compile-time constant
            float angle_step = 6.283185307 / float(SAMPLES); // 2 * PI

            for (int i = 0; i < SAMPLES; i++) {
                float angle = float(i) * angle_step;
                vec2  offset = vec2(cos(angle), sin(angle)) * pixel_size;
                float sample_a = texture(TEXTURE, UV + offset).a;
                max_outline_alpha = max(max_outline_alpha, sample_a);
            }

            if (max_outline_alpha > 0.1) {
                COLOR = vec4(outline_color.rgb, max_outline_alpha * outline_color.a);
            } else {
                // fully transparent
                COLOR = vec4(0.0, 0.0, 0.0, 0.0);
            }
        } else {
            // Inside the sprite: subtle glow tint
            vec3 glow = mix(original_color.rgb, outline_color.rgb, glow_intensity);
            COLOR = vec4(glow, original_color.a);
        }
    }
}