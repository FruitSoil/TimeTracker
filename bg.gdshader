shader_type canvas_item;

vec3 hsv_to_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);

	vec3 p = abs(
		fract(c.xxx + K.xyz) * 6.0 - K.www
	);

	return c.z * mix(
		K.xxx,
		clamp(p - K.xxx, 0.0, 1.0),
		c.y
	);
}

void fragment() {
	vec2 uv = UV;

	float wave1 = sin(uv.x * 4.0 + TIME * 0.4) * 0.5 + 0.5;
	float wave2 = cos(uv.y * 3.0 - TIME * 0.3) * 0.5 + 0.5;

	float wave = (wave1 + wave2) * 0.4;

	vec3 base_color = vec3(0.10, 0.10, 0.13);
	vec3 accent_color = vec3(0.15, 0.20, 0.32);

	vec3 final_color = mix(
		base_color,
		accent_color,
		wave
	);

	float brightness = 0.12 + wave * 0.08;

	float hue = fract(TIME * 0.015);

	vec3 color_shift = hsv_to_rgb(
		vec3(
			hue,
			0.65,
			brightness
		)
	);

	final_color = mix(
		final_color,
		color_shift,
		0.75
	);

	COLOR = vec4(final_color, 1.0);
}
