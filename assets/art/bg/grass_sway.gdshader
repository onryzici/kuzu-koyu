shader_type canvas_item;

// Çim tutamı: spritesheet'teki parlak bordo tutamları arka plan paletine çeker,
// dipleri koyulaştırır ve uçlara hafif rüzgar salınımı verir.
// 2D uyarlama; ilham: godotshaders.com/shader/stylized-cartoon-grass
// (kök sabit, uç salınır: root faktörü = 1 - normalize dikey konum).
// Gövde rengi bg'deki komşu tutamların gövdesiyle eşlenir; koyulaşma yalnız
// dipte (ground_start altı) — tutam yere yapışık dursun ama kararmasın.

// Sprite region'ın atlas içindeki dikey aralığı (v0, v1) — UV bunu kapsar,
// tutam-içi 0..1 konumu buradan normalize edilir.
uniform vec2 region_v = vec2(0.0, 1.0);
uniform float phase = 0.0;      // tutam başına faz (dünya x'inden) — senkron sallanmasınlar
uniform float sway_px = 7.0;    // ucun max yatay salınımı (doku pikseli)
uniform vec3 tip_color : source_color = vec3(0.34, 0.060, 0.065);
uniform vec3 root_color : source_color = vec3(0.055, 0.007, 0.009);
// Koyulaşmanın başladığı dikey nokta (0=uç, 1=dip) — yalnız EN dip kararır.
uniform float ground_start = 0.80;
// Board her gece kızıl overlay çizer ama o overlay bu sprite'ların ALTINDA kalır;
// aynı tint burada uygulanır ki çimler arka planla birlikte kızıllaşsın.
uniform float night_tint = 0.0;
uniform float sway_mul = 1.0;   // gece rüzgârı: board _night_alpha ile yükseltir
uniform float push_px = 0.0;    // imleç esintisi: anlık yatay itme (doku px, sönümlü)
uniform float wilt = 0.0;       // kurban tepkisi: 0..1 solma (karart + desatüre)

float tuft_t(vec2 uv) {
	return clamp((uv.y - region_v.x) / max(region_v.y - region_v.x, 0.0001), 0.0, 1.0);
}

void vertex() {
	float tip = 1.0 - tuft_t(UV); // 1 = uç (salınır), 0 = kök (sabit)
	float w = sin(TIME * 1.35 + phase) + 0.55 * sin(TIME * 3.1 + phase * 1.7);
	VERTEX.x += w * tip * sway_px * sway_mul + push_px * tip;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float t = tuft_t(UV);
	// Kaynak dokunun gölgelemesini (kontur/parlaklık) koru, rengi palete taşı.
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	// Gövde bg tutamlarıyla aynı tonda kalır; yalnız dip yere doğru koyulaşır.
	float ground = smoothstep(ground_start, 1.0, t);
	vec3 base = mix(tip_color, root_color, ground);
	vec3 col = base * clamp(lum / 0.12, 0.40, 1.35);
	col *= 0.82; // board'un vinyet karartmasıyla (siyah a=0.18) aynı
	col = mix(col, vec3(0.55, 0.02, 0.02), night_tint);
	// Solma: kurban yakınındaki tutam kararıp rengini kaybeder, sonra toparlar.
	col = mix(col, vec3(dot(col, vec3(0.35, 0.45, 0.20))) * 0.45, wilt * 0.75);
	COLOR = vec4(col, tex.a) * COLOR;
}
