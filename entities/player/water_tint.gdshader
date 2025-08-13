shader_type canvas_item;

uniform int hframes = 30;
uniform int vframes = 6;
uniform bool in_water = false;
uniform vec4 water_tint : source_color = vec4(0.7, 0.85, 1.0, 1.0);

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // Remap to 0..1 within the *current frame* on the sheet
    vec2 frame_uv = fract(UV * vec2(float(hframes), float(vframes)));

    // Keep sprite shape (don't color empty pixels)
    if (tex.a <= 0.0) {
        discard;
    }

    // Bottom 25% gets slight blue tint only when in water
    if (in_water && frame_uv.y > 0.75) {
        COLOR = tex * water_tint;  // Bottom 25% tinted blue
    } else {
        COLOR = tex;  // Normal sprite
    }
}