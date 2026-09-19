shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float line_thickness : hint_range(0.0, 5.0) = 1.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	
	if (col.a > 0.1) {
		COLOR = col;
	} else {
		vec2 size = TEXTURE_PIXEL_SIZE * line_thickness;
		
		// 4 cardinal samples to prevent diagonal cross-bleed on tight sprite atlases
		float a = 0.0;
		a = max(a, texture(TEXTURE, UV + vec2(0.0, -size.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0, size.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(-size.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV + vec2(size.x, 0.0)).a);
		
		if (a > 0.5) {
			COLOR = line_color;
		} else {
			COLOR = col;
		}
	}
}
