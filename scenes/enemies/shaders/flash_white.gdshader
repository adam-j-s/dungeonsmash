// flash_white.gdshader
shader_type canvas_item; // Use canvas_item for 2D nodes

// Uniform controlled by GDScript. 0.0 = normal color, 1.0 = full flash color.
uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0;
// The color to flash towards. Default is white.
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	// For Polygon2D or modulating a Sprite2D, COLOR holds the base color.
	vec4 original_color = COLOR;

	// For using the texture color of a Sprite2D directly (ignoring modulate):
	// vec4 original_color = texture(TEXTURE, UV);

	// For using texture AND modulate on a Sprite2D:
	// vec4 original_color = texture(TEXTURE, UV) * COLOR;

	// Mix (Linear Interpolate) between the original color and the flash color
	// based on the flash_modifier uniform.
	vec4 final_color = mix(original_color, flash_color, flash_modifier);

	// Apply the final color.
	COLOR = final_color;
}