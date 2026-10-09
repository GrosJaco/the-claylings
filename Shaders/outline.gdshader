shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float line_thickness : hint_range(0.0, 5.0) = 1.0;
uniform vec4 texture_region = vec4(0.0); // (x, y, width, height) in pixel coordinates

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	
	vec2 size = TEXTURE_PIXEL_SIZE * line_thickness;
	
	// If texture_region was not specified, default to full texture (0.0 to 1.0)
	vec2 uv_min = vec2(0.0);
	vec2 uv_max = vec2(1.0);
	if (texture_region.z > 0.0 && texture_region.w > 0.0) {
		uv_min = texture_region.xy * TEXTURE_PIXEL_SIZE;
		uv_max = (texture_region.xy + texture_region.zw) * TEXTURE_PIXEL_SIZE;
	}
	
	if (col.a > 0.1) {
		// Opaque pixel: if it touches the frame border where external quad fragments
		// don't exist, contour the border pixel itself so the outline is unbroken.
		bool on_border = (UV.x - size.x < uv_min.x || UV.x + size.x > uv_max.x ||
		                  UV.y - size.y < uv_min.y || UV.y + size.y > uv_max.y);
		if (on_border) {
			COLOR = line_color;
		} else {
			COLOR = col;
		}
	} else {
		// 4 cardinal samples respecting atlas / texture bounds to avoid cross-bleed
		float a = 0.0;
		
		vec2 uv_up = UV + vec2(0.0, -size.y);
		if (uv_up.x >= uv_min.x && uv_up.x <= uv_max.x && uv_up.y >= uv_min.y && uv_up.y <= uv_max.y) {
			a = max(a, texture(TEXTURE, uv_up).a);
		}
		
		vec2 uv_down = UV + vec2(0.0, size.y);
		if (uv_down.x >= uv_min.x && uv_down.x <= uv_max.x && uv_down.y >= uv_min.y && uv_down.y <= uv_max.y) {
			a = max(a, texture(TEXTURE, uv_down).a);
		}
		
		vec2 uv_left = UV + vec2(-size.x, 0.0);
		if (uv_left.x >= uv_min.x && uv_left.x <= uv_max.x && uv_left.y >= uv_min.y && uv_left.y <= uv_max.y) {
			a = max(a, texture(TEXTURE, uv_left).a);
		}
		
		vec2 uv_right = UV + vec2(size.x, 0.0);
		if (uv_right.x >= uv_min.x && uv_right.x <= uv_max.x && uv_right.y >= uv_min.y && uv_right.y <= uv_max.y) {
			a = max(a, texture(TEXTURE, uv_right).a);
		}
		
		if (a > 0.5) {
			COLOR = line_color;
		} else {
			COLOR = col;
		}
	}
}
