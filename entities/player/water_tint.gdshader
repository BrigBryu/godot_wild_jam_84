shader_type canvas_item;

uniform int hframes = 30;
uniform int vframes = 6;
uniform bool in_water = false;
uniform float water_depth = 0.0;  // 0.0 to 1.0, how deep player is in water
uniform vec4 water_tint : source_color = vec4(0.7, 0.85, 1.0, 1.0);

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // Keep sprite shape (don't color empty pixels)
    if (tex.a <= 0.0) {
        discard;
    }

    if (in_water && water_depth > 0.0) {
        // Get UV within current frame
        vec2 frame_uv = fract(UV * vec2(float(hframes), float(vframes)));

        // Tint based on depth - more of sprite gets tinted the deeper we go
        // At depth 0.5, bottom 50% is tinted, at depth 1.0, all is tinted
        float tint_threshold = 1.0 - water_depth;

        if (frame_uv.y > tint_threshold) {
            // Apply water tint with gradient
            float tint_strength = (frame_uv.y - tint_threshold) / (1.0 - tint_threshold);
            COLOR = mix(tex, tex * water_tint, tint_strength * 0.7);
        } else {
            COLOR = tex;
        }
    } else {
        COLOR = tex;  // Normal sprite
    }
}