class_name TestimonyText
extends RefCounted

## Bir tanıklığın DOĞAL DİL metnini üretir. Yapısal claim (TestimonyClaim) girer,
## karaktere/role uygun, VARYANTLI Türkçe cümle çıkar. Bkz. CLAUDE.md §5.3.
##
## Neden ayrı modül: generator yalnız yapısal alanları kurar; metin tek yerde,
## veri gibi durur. Her tip için birkaç varyant var (rng seçer) → aynı köy iki kez
## açılınca bile "hep aynı cümle" hissi kırılır. Yalan/doğru AYNI metin havuzunu
## kullanır (yalan = yapısal değeri bozulmuş doğru), böylece bluff ele vermez.
##
## Tema: sürü (koyun) vs kurt. Kurtlar koyun postuna bürünür; metinler halk ağzında.

# Rol-özel açılış lakabı (aynı claim tipini farklı ağızdan söyletir; boşsa atlanır).
const VOICE := {
	&"Judge": "Kokladım, ",
	&"Confessor": "İçini okudum: ",
	&"Oracle": "Fala baktım — ",
	&"Dreamer": "Rüyamda gördüm: ",
	&"Knight": "İki yanımı kolladım: ",
	&"Sentry": "Nöbetteyim: ",
	&"Scout": "İz sürdüm, ",
	&"Enlightened": "İçime doğdu: ",
	&"Architect": "Değirmenden baktım: ",
	&"Lover": "Yüreğim diyor ki ",
	&"Gossip": "Duyduğuma göre ",
}


static func phrase(role: StringName, t: TestimonyClaim, rng: RandomNumberGenerator) -> String:
	var body := _body(role, t, rng)
	var intro: String = VOICE.get(role, "")
	if intro == "":
		return body
	# Lakaptan sonra cümle küçük harfle başlasın (akıcılık).
	return intro + _lower_first(body)


static func _body(role: StringName, t: TestimonyClaim, rng: RandomNumberGenerator) -> String:
	match t.type:
		Enums.TestimonyType.ALIGNMENT_OF:
			var s: int = t.targets[0]
			if t.alignment == Enums.Alignment.EVIL:
				return _pick(rng, [
					"#%d bir kurt, postuna aldanmayın." % s,
					"Şu #%d'den kan kokusu geliyor — kurt bu." % s,
					"#%d sürüden değil; kılık değiştirmiş bir kurt." % s,
					"#%d'e sakın güvenmeyin, o bir kurt." % s,
				])
			return _pick(rng, [
				"#%d temiz, bizden biri." % s,
				"#%d'e kefilim, o koyun." % s,
				"#%d'de kurt yok, içiniz rahat olsun." % s,
				"#%d tertemiz bir koyun." % s,
			])

		Enums.TestimonyType.COUNT_IN_SET:
			# Kural: yalnız SAYILAN KARTLARIN KENDİSİ (aradaki kartlar DEĞİL). Metin
			# asla "arasında" demez — muğlak olurdu; "bu kartlardan" der. Bkz. §5.3.
			var seats: Array = t.targets
			var k: int = t.number
			var lst := _seat_list(seats)
			if seats.size() == 2:
				var a: int = seats[0]
				var b: int = seats[1]
				if k == 0:
					return _pick(rng, [
						"#%d ve #%d'nin ikisi de koyun, hiçbiri kurt değil." % [a, b],
						"Ne #%d ne #%d kurt; ikisi de temiz." % [a, b],
					])
				if k == 2:
					return _pick(rng, [
						"Hem #%d hem #%d kurt — ikisi de!" % [a, b],
						"#%d ve #%d'nin ikisi de kurt." % [a, b],
					])
				return _pick(rng, [
					"#%d ve #%d'den tam biri kurt." % [a, b],
					"Şu iki karttan (#%d, #%d) yalnızca biri kurt, diğeri koyun." % [a, b],
				])
			# 3+ kartlık set (ör. Rüyacı): net sayı ver, "arasında" deme.
			if k == 0:
				return "Şu kartların (%s) hiçbiri kurt değil." % lst
			return _pick(rng, [
				"Şu kartlardan (%s) tam %d tanesi kurt." % [lst, k],
				"%s içinden %d kart kurt, gerisi koyun." % [lst, k],
			])

		Enums.TestimonyType.NEIGHBOR_HAS_EVIL:
			var c: int = t.number
			if c == 0:
				return _pick(rng, [
					"İki komşum da tertemiz, yanımda kurt yok.",
					"Bitişiğimde tek kurt bile yok.",
				])
			return _pick(rng, [
				"komşularımdan %d tanesi kurt." % c,
				"bitişiğimde %d kurt var." % c,
				"yanı başımdaki %d hayvan kurt çıktı." % c,
			])

		Enums.TestimonyType.NEAREST_EVIL_DISTANCE:
			var d: int = t.number
			return _pick(rng, [
				"en yakın kurt %d adım ötede." % d,
				"en yakın kurtla aramda %d kart var." % d,
				"buradan sayınca en yakın kurt %d uzakta." % d,
			])

		Enums.TestimonyType.NEAREST_EVIL_DIRECTION:
			var dt := _dir_text(t.direction)
			if t.direction == Enums.Direction.EQUIDISTANT:
				return _pick(rng, [
					"en yakın kurtlar iki yanımda da eşit uzaklıkta.",
					"iki yönde de kurt aynı mesafede, seçemiyorum.",
				])
			return _pick(rng, [
				"en yakın kurt %s." % dt,
				"burnum %s bir kurt gösteriyor." % dt,
			])

		Enums.TestimonyType.EVIL_COUNT_IN_REGION:
			if t.compare == Enums.Compare.EQUAL:
				return _pick(rng, [
					"Benden saat yönündeki yarıyla karşı yarıda eşit sayıda kurt var.",
					"Çemberi benden ortadan bölersen iki yarıda da kurt sayısı aynı.",
				])
			var more := t.compare == Enums.Compare.GREATER
			return _pick(rng, [
				"Benden saat yönündeki yarı, karşı yarıdan %s kurt tutuyor." % ("daha çok" if more else "daha az"),
				"Çemberi benden ikiye bölersen saat yönündeki yarıda %s kurt var." % ("daha fazla" if more else "daha az"),
			])

		Enums.TestimonyType.PAIR_RELATION:
			var x: int = t.targets[0]
			var y: int = t.targets[1]
			if t.bool_val:
				return _pick(rng, [
					"#%d ile #%d aynı saftan — ya ikisi de koyun ya ikisi de kurt." % [x, y],
					"#%d ve #%d bir bütün; ikisi de aynı taraf." % [x, y],
				])
			return _pick(rng, [
				"#%d ile #%d ayrı saftan — biri koyun, biri kurt." % [x, y],
				"#%d ve #%d zıt taraflarda." % [x, y],
			])

		_:
			return "Söyleyecek bir şeyim yok."


static func _pick(rng: RandomNumberGenerator, options: Array) -> String:
	return options[rng.randi() % options.size()]


static func _seat_list(seats: Array) -> String:
	var parts: Array = []
	for s in seats:
		parts.append("#%d" % s)
	return ", ".join(parts)


static func _lower_first(s: String) -> String:
	if s.is_empty():
		return s
	# Cümle zaten küçük harfle başlıyorsa (komşu/en yakın gibi) dokunma.
	return s


static func _dir_text(d: int) -> String:
	match d:
		Enums.Direction.CLOCKWISE:
			return "saat yönünde"
		Enums.Direction.COUNTER_CLOCKWISE:
			return "saat yönünün tersinde"
		_:
			return "eşit mesafede"
