shader_type canvas_item;
render_mode blend_add;
// Fixed: No return statements in fragment shader

uniform vec2 rect_size;
uniform float current_edge_y = 420.0;     // computed edge position from script (top of wave)
uniform float computed_foam_alpha = 1.0;  // computed foam alpha from script
uniform float shore_y = 420.0;
uniform float wave_bottom_y = 420.0;      // wave bottom boundary
uniform float Rmax    = 80.0;
uniform float w       = 0.45;
uniform float k       = 0.0;
uniform bool  lock_vertical = true;

uniform sampler2D foamNoise : filter_linear_mipmap; // grayscale seamless
uniform float edge_width    = 12.0;                 // foam band thickness
uniform float crest_offset  = 7.0;                  // extra line slightly seaward
uniform float foam_scroll   = 0.2;                  // sideways drift for breakup
uniform float foam_alpha    = 0.85;

void fragment(){
    vec2 px = UV * rect_size;

    // Use the computed edge position from script (single source of truth)
    float edge_y = current_edge_y;

    // Wave boundaries: only show foam between edge_y (top) and wave_bottom_y (bottom)
    if (px.y < edge_y || px.y > wave_bottom_y) {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0);  // Transparent outside wave boundaries
    } else {

        // signed distance to instantaneous edge (positive = water side)
        float d = px.y - edge_y;

        // Only create foam ON or BELOW the waterline (d >= 0)
        float band = 0.0;
        if (d >= 0.0) {
            band = 1.0 - smoothstep(0.0, edge_width, d);
        }

        // breakup with scrolling grayscale noise (wrapped to stay in bounds)
        // Scale UV by 3.0 to make foam bubbles smaller
        float n = texture(foamNoise, vec2(fract(UV.x * 3.0 + TIME * foam_scroll), UV.y * 3.0)).r;
        float foam = band * smoothstep(0.55, 1.0, n);

        // thin crest a bit seaward (only if in water)
        float crest = 0.0;
        if (d + crest_offset >= 0.0) {
            crest = smoothstep(2.0, 0.0, d + crest_offset);
        }
        foam = clamp(foam + 0.9 * crest, 0.0, 1.0);

        // Use the computed alpha from script (single source of truth)
        COLOR = vec4(vec3(1.0), foam * foam_alpha * computed_foam_alpha);
    }
}