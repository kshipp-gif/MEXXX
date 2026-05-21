// Simple separable box blur for the pause menu background effect.
// Compatible with GL Compatibility renderer (no early return in fragment).
shader_type canvas_item;

uniform float blur_amount: hint_range(0.0, 10.0) = 0.0;
uniform vec2 texture_size = vec2(1152.0, 648.0);

void fragment() {
	if (blur_amount < 0.001) {
		COLOR = texture(TEXTURE, UV);
	} else {
		vec2 pixel = blur_amount / texture_size;
		vec4 col = vec4(0.0);
		float total = 0.0;

		for (int x = -3; x <= 3; x++) {
			for (int y = -3; y <= 3; y++) {
				vec2 offset = vec2(float(x), float(y)) * pixel;
				col += texture(TEXTURE, UV + offset);
				total += 1.0;
			}
		}

		COLOR = col / total;
	}
}
