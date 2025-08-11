extends Node

class_name WetSandGenerator

# Wave pattern parameters
@export var num_tide_lines: int = 5
@export var base_amplitude: float = 30.0
@export var frequency_variation: Vector2 = Vector2(0.8, 2.0)
@export var noise_strength: float = 0.3
@export var fade_distance: float = 100.0
@export var wet_color: Color = Color(0.7, 0.65, 0.5, 1.0)  # Darker sand color
@export var dry_color: Color = Color(1.0, 0.95, 0.85, 1.0)  # Normal sand color
@export var tide_spacing: float = 20.0  # Base spacing between tide lines
@export var extend_far_inland: bool = false  # Low tide mode

var noise: FastNoiseLite

func _init():
	# Initialize Perlin noise
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.02
	noise.seed = randi()

func generate_wet_sand_texture(width: int, height: int, ocean_y: int) -> ImageTexture:
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	
	# Generate multiple tide lines
	var tide_lines = []
	for i in range(num_tide_lines):
		var intensity_falloff = 0.12 if extend_far_inland else 0.2
		var amplitude_falloff = 0.08 if extend_far_inland else 0.15
		
		tide_lines.append({
			"base_y": ocean_y - (i * tide_spacing + randf() * tide_spacing * 0.4),
			"amplitude": base_amplitude * (1.0 - i * amplitude_falloff),
			"frequency": randf_range(frequency_variation.x, frequency_variation.y),
			"phase": randf() * TAU,
			"intensity": 1.0 - (i * intensity_falloff)
		})
	
	# Process each pixel
	for x in range(width):
		for y in range(height):
			var wetness = 0.0
			
			# Calculate wetness from each tide line
			for tide in tide_lines:
				var wave_y = calculate_wave_y(x, tide)
				var distance_from_wave = abs(y - wave_y)
				
				# Create a soft gradient around the wave line
				if distance_from_wave < fade_distance:
					var fade = 1.0 - (distance_from_wave / fade_distance)
					fade = smoothstep(0.0, 1.0, fade)
					
					# Add this tide's contribution
					wetness = max(wetness, fade * tide.intensity)
			
			# Apply distance fade from ocean
			if not extend_far_inland:
				var distance_from_ocean = max(0, ocean_y - y)
				if distance_from_ocean > fade_distance * 2:
					var ocean_fade = 1.0 - ((distance_from_ocean - fade_distance * 2) / (fade_distance * 3))
					wetness *= clamp(ocean_fade, 0.0, 1.0)
			else:
				# Very subtle fade for low tide - patterns visible far inland
				var distance_from_ocean = max(0, ocean_y - y)
				if distance_from_ocean > fade_distance * 4:
					var ocean_fade = 1.0 - ((distance_from_ocean - fade_distance * 4) / (fade_distance * 6))
					wetness *= clamp(ocean_fade, 0.3, 1.0)
			
			# Set pixel color based on wetness
			var color = dry_color.lerp(wet_color, wetness)
			# Add slight transparency for overlay effect
			color.a = wetness * 0.7 + 0.3
			
			image.set_pixel(x, y, color)
	
	return ImageTexture.create_from_image(image)

func calculate_wave_y(x: float, tide: Dictionary) -> float:
	# Base sine wave
	var wave = sin(x * 0.01 * tide.frequency + tide.phase) * tide.amplitude
	
	# Add secondary harmonic for more interesting patterns
	wave += sin(x * 0.02 * tide.frequency + tide.phase * 1.5) * tide.amplitude * 0.3
	
	# Add Perlin noise for organic variation
	var noise_value = noise.get_noise_2d(x * 0.5, tide.base_y) * noise_strength * tide.amplitude
	
	return tide.base_y + wave + noise_value

func generate_wetness_map(width: int, height: int, ocean_y: int) -> Array:
	# Generate a 2D array of wetness values (0.0 to 1.0)
	var wetness_map = []
	
	# Generate tide line data
	var tide_lines = []
	for i in range(num_tide_lines):
		var intensity_falloff = 0.15 if extend_far_inland else 0.25
		var amplitude_falloff = 0.1 if extend_far_inland else 0.18
		
		tide_lines.append({
			"base_y": ocean_y - (i * tide_spacing + randf() * tide_spacing * 0.5),
			"amplitude": base_amplitude * (1.0 - i * amplitude_falloff),
			"frequency": randf_range(frequency_variation.x, frequency_variation.y),
			"phase": randf() * TAU,
			"intensity": 1.0 - (i * intensity_falloff),
			"width": fade_distance * (1.0 + i * 0.3)  # Wider bands for older lines
		})
	
	# Initialize map
	for x in range(width):
		wetness_map.append([])
		for y in range(height):
			wetness_map[x].append(0.0)
	
	# Calculate wetness for each point
	for x in range(width):
		for y in range(height):
			var wetness = 0.0
			
			for tide in tide_lines:
				var wave_y = calculate_wave_y(x * 16, tide)  # Scale for tile size
				var distance_from_wave = abs(y * 16 - wave_y)
				
				if distance_from_wave < tide.width:
					var fade = 1.0 - (distance_from_wave / tide.width)
					fade = smoothstep(0.0, 1.0, fade)
					
					# Layer the wetness (take maximum, not additive)
					wetness = max(wetness, fade * tide.intensity)
			
			# Ocean proximity boost
			if y > ocean_y - 10:
				var ocean_proximity = 1.0 - ((ocean_y - y) / 10.0)
				wetness = max(wetness, ocean_proximity * 0.5)
			
			# Fade out far from ocean (much gentler fade for low tide)
			if not extend_far_inland:
				var distance_from_ocean = max(0, ocean_y - y)
				if distance_from_ocean > 30:
					var fade_out = 1.0 - ((distance_from_ocean - 30) / 50.0)
					wetness *= clamp(fade_out, 0.0, 1.0)
			else:
				# Very gentle fade for low tide mode - patterns extend far inland
				var distance_from_ocean = max(0, ocean_y - y)
				if distance_from_ocean > 80:
					var fade_out = 1.0 - ((distance_from_ocean - 80) / 120.0)
					wetness *= clamp(fade_out, 0.2, 1.0)  # Keep minimum wetness for subtle patterns
			
			wetness_map[x][y] = clamp(wetness, 0.0, 1.0)
	
	return wetness_map