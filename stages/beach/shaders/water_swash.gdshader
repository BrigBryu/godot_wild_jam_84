shader_type canvas_item;
// Fixed: No return statements in fragment shader
// SAFE MODE: SCREEN_TEXTURE available but sand renders first now
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// ---------- geometry + motion ----------
uniform vec2 rect_size;                 // pixels covered by the Water sprite
uniform float current_edge_y = 420.0;   // computed edge position from script (top of wave)
uniform float computed_water_alpha = 1.0; // computed water transparency from script
uniform float shore_y = 420.0;          // baseline shoreline (in pixels from top)
uniform float wave_bottom_y = 420.0;    // wave bottom boundary
uniform float Rmax    = 80.0;           // max run-up distance in px
uniform float w       = 0.45;           // cycle speed (uprush → pause → backwash)
uniform float k       = 0.0;            // tiny spatial phase across X (start 0)
uniform bool  lock_vertical = true;     // true = pure up/down swash

// ---------- wave colors ----------
uniform vec4 wave_front : source_color = vec4(0.08, 0.55, 0.62, 0.95);  // Front edge color (lighter blue-green)
uniform vec4 wave_tail  : source_color = vec4(0.05, 0.45, 0.58, 0.95);   // Tail edge color (slightly darker blue-green)
uniform float refract_strength = 0.006;

// ---------- normals (optional but nice) ----------
uniform sampler2D normalA : filter_linear_mipmap;
uniform sampler2D normalB : filter_linear_mipmap;
uniform vec2 nscrollA = vec2(0.02, 0.01);
uniform vec2 nscrollB = vec2(-0.015, 0.008);

// No helper functions needed - all computed in script

void fragment(){
    vec2 px = UV * rect_size;

    // Use the computed edge position from script (single source of truth)
    float edge_y = current_edge_y;

    // Wave boundaries: only show water between edge_y (top) and wave_bottom_y (bottom)
    if (px.y < edge_y || px.y > wave_bottom_y) {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0);  // Transparent outside wave boundaries
    } else {
        // Position factor 0..1 from wave front (edge_y) to wave tail (wave_bottom_y)
        float wave_position = clamp((px.y - edge_y) / max(wave_bottom_y - edge_y, 1.0), 0.0, 1.0);
        vec4 base_col = mix(wave_front, wave_tail, wave_position);

        // Subtle refraction
        vec2 tA = UV + TIME * nscrollA;
        vec2 tB = UV + TIME * nscrollB;
        vec2 n  = ((texture(normalA, tA).rg + texture(normalB, tB).rg) * 2.0 - 2.0);
        n = normalize(n + vec2(1e-4));
        vec2 suv = SCREEN_UV + n * (refract_strength * (1.0 - 0.5 * wave_position));
        vec4 refr = texture(SCREEN_TEXTURE, suv);

        vec4 final_color = mix(base_col, refr, 0.12);
        
        // Pure dynamic wave - just apply computed alpha everywhere
        float alpha_multiplier = computed_water_alpha;
        
        COLOR = vec4(final_color.rgb, final_color.a * alpha_multiplier);
    }
}