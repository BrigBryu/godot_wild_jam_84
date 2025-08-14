shader_type canvas_item;

// Ocean background - solid wave tail color
uniform vec4 ocean_color : source_color = vec4(0.05, 0.45, 0.58, 1.0);  // Wave tail color but fully opaque

void fragment() {
	COLOR = ocean_color;
}