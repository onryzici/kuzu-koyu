shader_type canvas_item;

// Alçak zemin sisi: procedural fbm gürültüsü, iki katman ters yönde sürüklenir.
// Alt kenara + ekran kenarlarına ağırlıklı maske — merkez (mühür/kartlar) temiz
// kalır, folk-horror havası kenarlardan sızar. Bkz. CLAUDE.md §10.5/§10.7.

uniform float density : hint_range(0.0, 1.0) = 0.13;
uniform vec3 fog_color : source_color = vec3(0.34, 0.10, 0.10);
uniform vec2 drift = vec2(0.010, 0.0025);

float f_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(f_hash(i), f_hash(i + vec2(1.0, 0.0)), u.x),
			mix(f_hash(i + vec2(0.0, 1.0)), f_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.5 * vnoise(p);
	v += 0.25 * vnoise(p * 2.03 + 17.0);
	v += 0.125 * vnoise(p * 4.01 + 47.0);
	return v / 0.875;
}

void fragment() {
	// Ekran oranından bağımsız yumuşak yamalar (x'i geniş tut).
	vec2 p = vec2(UV.x * 3.2, UV.y * 5.5);
	float n = fbm(p + TIME * drift * 60.0);
	float n2 = fbm(p * 1.7 - TIME * drift * 38.0 + vec2(5.0, 9.0));
	float fog = smoothstep(0.38, 0.85, n * 0.6 + n2 * 0.4);
	// Maske: alta doğru artar + kenarlarda hafif; merkez temiz.
	float bottom = smoothstep(0.52, 0.98, UV.y);
	float edge = smoothstep(0.30, 0.72, length(UV - 0.5));
	float band = max(bottom, edge * 0.55);
	COLOR = vec4(fog_color, fog * band * density);
}
