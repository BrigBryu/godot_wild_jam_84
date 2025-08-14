shader_type canvas_item;

uniform float shore_y = 420.0;
uniform float Rmax = 100.0;
uniform float k = 0.003;   // spatial variation along X
uniform float w = 0.5;      // speed of up/down cycle
uniform float edge_width = 50.0;
uniform vec4 band_color : source_color = vec4(0.2, 1.0, 1.0, 1.0);

// NOTE: Use screen-space to avoid Control/UV quirks.
float runup_amount(float x, float t) {
    // Each X column has a fixed spatial phase, oscillating in time (no sideways travel).
    float spatial = k * x;
    float p = fract(w * t + spatial); // 0..1
    if (p < 0.42) {
        float u = p / 0.42;
        return pow(u, 0.6) * Rmax;        // uprush
    } else if (p > 0.58) {
        float v = (p - 0.58) / 0.42;
        return (1.0 - pow(v, 0.6)) * Rmax; // backwash
    } else {
        return Rmax;                       // brief pause at top
    }
}

void fragment() {
    // For ColorRect, use UV * viewport size to get consistent coordinates
    vec2 screen_px = UV * vec2(1280.0, 720.0);

    float r = runup_amount(screen_px.x, TIME);
    float edge_y = shore_y - r;

    // horizontal band centered on the moving shoreline
    float d = screen_px.y - edge_y;
    float band = 1.0 - smoothstep(0.0, edge_width, abs(d));

    COLOR = vec4(band_color.rgb, band * band_color.a);
}