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
	&"Healer": "Nabzını tuttum: ",
	&"Weaver": "Tezgâhımda dokudum: ",
	&"Midwife": "Bu köyde herkesi doğurttum — ",
	&"Milkmaid": "Süt yolunda gördüm: ",
	&"Crier": "Duyduk duymadık demeyin! ",
	&"Beekeeper": "Arılarım fısıldadı: ",
	&"Sheepdog": "Hrrr... kokusunu aldım: ",
	&"Shearer": "Yününü kırktım, tarttım: ",
	&"Drummer": "Davulumun yankısı söyledi: ",
	&"Welldigger": "Kuyunun suyu yansıttı: ",
	&"Beadcounter": "Tespihimi çektim, saydım: ",
	&"Skittish": "T-titriyorum ama biliyorum: ",
	&"Tailor": "Arşınımla ölçtüm: ",
	&"Mirrorwright": "Aynam yansıttı: ",
}

# İngilizce açılış lakapları (VOICE'un birebir karşılığı; boşsa atlanır).
const VOICE_EN := {
	&"Judge": "I sniffed them out — ",
	&"Confessor": "I read their soul: ",
	&"Oracle": "I read the fortune — ",
	&"Dreamer": "I saw it in my dream: ",
	&"Knight": "I watched both my sides: ",
	&"Sentry": "I'm on watch: ",
	&"Scout": "I followed the tracks — ",
	&"Enlightened": "It came to me: ",
	&"Architect": "I watched from the mill: ",
	&"Lover": "My heart tells me ",
	&"Gossip": "Word around the village is ",
	&"Healer": "I took their pulse: ",
	&"Weaver": "I wove it on my loom: ",
	&"Midwife": "I birthed everyone in this village — ",
	&"Milkmaid": "I saw it on my milk route: ",
	&"Crier": "Hear ye, hear ye! ",
	&"Beekeeper": "My bees whispered: ",
	&"Sheepdog": "Grrr... I caught the scent: ",
	&"Shearer": "I sheared the wool and weighed it: ",
	&"Drummer": "My drum's echo told me: ",
	&"Welldigger": "The well water showed me: ",
	&"Beadcounter": "I counted my beads: ",
	&"Skittish": "I-I'm trembling, but I know: ",
	&"Tailor": "I measured it with my yardstick: ",
	&"Mirrorwright": "My mirror showed me: ",
}


static func phrase(role: StringName, t: TestimonyClaim, rng: RandomNumberGenerator) -> String:
	var body := _body(role, t, rng)
	var intro: String = (VOICE_EN if Loc.lang == "en" else VOICE).get(role, "")
	if intro == "":
		return body
	# Lakaptan sonra cümle küçük harfle başlasın (akıcılık).
	return intro + _lower_first(body)


static func _body(role: StringName, t: TestimonyClaim, rng: RandomNumberGenerator) -> String:
	if Loc.lang == "en":
		return _body_en(role, t, rng)
	match t.type:
		Enums.TestimonyType.ALIGNMENT_OF:
			var s: int = t.targets[0]
			if t.alignment == Enums.Alignment.EVIL:
				return _pick(rng, [
					"#%d bir kurt, postuna aldanmayın." % s,
					"Şu #%d'den kan kokusu geliyor — kurt bu." % s,
					"#%d sürüden değil; kılık değiştirmiş bir kurt." % s,
					"#%d'e sakın güvenmeyin, o bir kurt." % s,
					"Gece #%d'nin gözleri parlıyor — kurt gözü o." % s,
					"#%d koyun gibi meliyor ama dişleri sivri: KURT." % s,
				])
			return _pick(rng, [
				"#%d temiz, bizden biri." % s,
				"#%d'e kefilim, o koyun." % s,
				"#%d'de kurt yok, içiniz rahat olsun." % s,
				"#%d tertemiz bir koyun." % s,
				"#%d'nin yüreği koyun yüreği; korkmayın ondan." % s,
				"#%d bizden — postu da kendi postu." % s,
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
				"tam %d kart ötemde bir kurt soluk alıyor." % d,
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
				"#%d ile #%d aynı sürüden değil; biri post giymiş." % [x, y],
			])

		Enums.TestimonyType.COUNT_PARITY_IN_SET:
			var lstp := _seat_list(t.targets)
			if t.bool_val:
				return _pick(rng, [
					"şu kartlardaki (%s) kurt sayısı ÇİFT — hiç de olabilir, iki de." % lstp,
					"%s içindeki kurtları saydım: çift çıktı, tespih artmadı." % lstp,
					"%s — bu kartlarda çift sayıda kurt var, tek değil." % lstp,
				])
			return _pick(rng, [
				"şu kartlardaki (%s) kurt sayısı TEK." % lstp,
				"%s içinde tek sayıda kurt var — bir tane artık kaldı tespihte." % lstp,
				"%s — bu kartlarda tek sayıda kurt saklanıyor." % lstp,
			])

		Enums.TestimonyType.NEAREST_EVIL_MIN_DIST:
			if t.compare == Enums.Compare.GREATER:
				return _pick(rng, [
					"en yakın kurt bile bana %d adımdan UZAK." % t.number,
					"çevremde %d adım içinde kurt yok — o kadarına eminim." % t.number,
					"kurt kokusunu ancak uzaktan alıyorum; %d adımdan ötede." % t.number,
				])
			return _pick(rng, [
				"kurt bana %d adımdan YAKIN... ensemde hissediyorum." % t.number,
				"aramızda %d adım bile yok — kurt dibimde bir yerde." % t.number,
				"%d adımdan yakında bir kurt var, titremem ondan." % t.number,
			])

		Enums.TestimonyType.WOLF_GAP:
			return _pick(rng, [
				"en yakın iki kurdun arası tam %d adım." % t.number,
				"kurtların arasını arşınladım: %d adım çıktı." % t.number,
				"iki kurt %d adım arayla oturuyor — kumaş gibi ölçtüm." % t.number,
			])

		Enums.TestimonyType.OPPOSITE_ALIGNMENT:
			var osx: int = t.targets[0]
			if t.alignment == Enums.Alignment.EVIL:
				return _pick(rng, [
					"tam karşımdaki #%d'nin yansıması KURT gösteriyor." % osx,
					"aynayı karşıya tuttum: #%d'nin postu altında kurt var." % osx,
				])
			return _pick(rng, [
				"tam karşımdaki #%d temiz — ayna yalan söylemez." % osx,
				"karşımdaki #%d'nin yansıması dupduru: koyun." % osx,
			])

		_:
			return "Söyleyecek bir şeyim yok."


## _body'nin İngilizce ikizi. Havuzlar TR ile aynı yapıda (aynı tip, aynı yer
## tutucular); halk ağzı, tehditkâr-folk tonu korunur.
static func _body_en(role: StringName, t: TestimonyClaim, rng: RandomNumberGenerator) -> String:
	match t.type:
		Enums.TestimonyType.ALIGNMENT_OF:
			var s: int = t.targets[0]
			if t.alignment == Enums.Alignment.EVIL:
				return _pick(rng, [
					"#%d is a wolf — don't be fooled by the wool." % s,
					"There's a smell of blood on #%d — that one's a wolf." % s,
					"#%d is not of the flock; a wolf in disguise." % s,
					"Don't you trust #%d — that one's a wolf." % s,
					"#%d's eyes glow at night — wolf eyes, those." % s,
					"#%d bleats like a sheep, but the teeth are sharp: WOLF." % s,
				])
			return _pick(rng, [
				"#%d is clean, one of ours." % s,
				"I vouch for #%d — that one's a sheep." % s,
				"No wolf in #%d, rest easy." % s,
				"#%d is a spotless sheep." % s,
				"#%d has a sheep's heart; nothing to fear there." % s,
				"#%d is ours — and that wool is their own." % s,
			])

		Enums.TestimonyType.COUNT_IN_SET:
			# Kural: yalnız SAYILAN KARTLARIN KENDİSİ (aradaki kartlar DEĞİL). Metin
			# asla "between" demez — muğlak olurdu; "of these cards" der. Bkz. §5.3.
			var seats: Array = t.targets
			var k: int = t.number
			var lst := _seat_list(seats)
			if seats.size() == 2:
				var a: int = seats[0]
				var b: int = seats[1]
				if k == 0:
					return _pick(rng, [
						"#%d and #%d are both sheep, neither is a wolf." % [a, b],
						"Neither #%d nor #%d is a wolf; both are clean." % [a, b],
					])
				if k == 2:
					return _pick(rng, [
						"Both #%d and #%d are wolves — the pair of them!" % [a, b],
						"#%d and #%d are both wolves." % [a, b],
					])
				return _pick(rng, [
					"Exactly one of #%d and #%d is a wolf." % [a, b],
					"Of those two cards (#%d, #%d) only one is a wolf, the other a sheep." % [a, b],
				])
			# 3+ kartlık set (ör. Rüyacı): net sayı ver, "arasında" deme.
			if k == 0:
				return "None of these cards (%s) is a wolf." % lst
			return _pick(rng, [
				"Of these cards (%s), exactly %d are wolves." % [lst, k],
				"Among %s, %d cards are wolves; the rest are sheep." % [lst, k],
			])

		Enums.TestimonyType.NEIGHBOR_HAS_EVIL:
			var c: int = t.number
			if c == 0:
				return _pick(rng, [
					"Both my neighbors are clean, no wolf beside me.",
					"Not a single wolf next to me.",
				])
			return _pick(rng, [
				"%d of my neighbors are wolves." % c,
				"there are %d wolves right beside me." % c,
				"%d of the beasts at my side turned out to be wolves." % c,
			])

		Enums.TestimonyType.NEAREST_EVIL_DISTANCE:
			var d: int = t.number
			return _pick(rng, [
				"the nearest wolf is %d steps away." % d,
				"there are %d cards between me and the nearest wolf." % d,
				"counting from here, the nearest wolf is %d away." % d,
				"a wolf draws breath exactly %d cards from me." % d,
			])

		Enums.TestimonyType.NEAREST_EVIL_DIRECTION:
			var dt := _dir_text_en(t.direction)
			if t.direction == Enums.Direction.EQUIDISTANT:
				return _pick(rng, [
					"the nearest wolves sit at equal distance on both my sides.",
					"a wolf lies the same distance either way — I can't tell which.",
				])
			return _pick(rng, [
				"the nearest wolf is %s." % dt,
				"my nose points %s to a wolf." % dt,
			])

		Enums.TestimonyType.EVIL_COUNT_IN_REGION:
			if t.compare == Enums.Compare.EQUAL:
				return _pick(rng, [
					"The half clockwise from me and the far half hold an equal count of wolves.",
					"Split the circle in two at my seat and both halves carry the same number of wolves.",
				])
			var more := t.compare == Enums.Compare.GREATER
			return _pick(rng, [
				"The half clockwise from me holds %s wolves than the far half." % ("more" if more else "fewer"),
				"Split the circle at my seat and the clockwise half has %s wolves." % ("more" if more else "fewer"),
			])

		Enums.TestimonyType.PAIR_RELATION:
			var x: int = t.targets[0]
			var y: int = t.targets[1]
			if t.bool_val:
				return _pick(rng, [
					"#%d and #%d stand on the same side — both sheep or both wolves." % [x, y],
					"#%d and #%d are of one piece; both on the same side." % [x, y],
				])
			return _pick(rng, [
				"#%d and #%d stand on opposite sides — one sheep, one wolf." % [x, y],
				"#%d and #%d are on opposing sides." % [x, y],
				"#%d and #%d are not of the same flock; one of them wears a stolen skin." % [x, y],
			])

		Enums.TestimonyType.COUNT_PARITY_IN_SET:
			var lstp := _seat_list(t.targets)
			if t.bool_val:
				return _pick(rng, [
					"the wolf count in these cards (%s) is EVEN — could be none, could be two." % lstp,
					"I counted the wolves among %s: it came out even, no bead left over." % lstp,
					"%s — an even number of wolves in these cards, not odd." % lstp,
				])
			return _pick(rng, [
				"the wolf count in these cards (%s) is ODD." % lstp,
				"there's an odd number of wolves among %s — one bead left over on my string." % lstp,
				"%s — an odd number of wolves hides in these cards." % lstp,
			])

		Enums.TestimonyType.NEAREST_EVIL_MIN_DIST:
			if t.compare == Enums.Compare.GREATER:
				return _pick(rng, [
					"even the nearest wolf is FARTHER than %d steps from me." % t.number,
					"no wolf within %d steps of me — that much I know." % t.number,
					"I only catch the wolf's scent from afar; beyond %d steps." % t.number,
				])
			return _pick(rng, [
				"a wolf is CLOSER than %d steps to me... I feel it on my neck." % t.number,
				"there aren't even %d steps between us — the wolf is right upon me." % t.number,
				"a wolf lurks closer than %d steps; that's why I tremble." % t.number,
			])

		Enums.TestimonyType.WOLF_GAP:
			return _pick(rng, [
				"the two nearest wolves sit exactly %d steps apart." % t.number,
				"I paced out the gap between the wolves: %d steps." % t.number,
				"two wolves sit %d steps apart — I measured it like cloth." % t.number,
			])

		Enums.TestimonyType.OPPOSITE_ALIGNMENT:
			var osx: int = t.targets[0]
			if t.alignment == Enums.Alignment.EVIL:
				return _pick(rng, [
					"the reflection of #%d, straight across from me, shows a WOLF." % osx,
					"I held the mirror to the far side: a wolf hides under #%d's wool." % osx,
				])
			return _pick(rng, [
				"#%d, straight across from me, is clean — mirrors don't lie." % osx,
				"the reflection of #%d across from me runs clear: a sheep." % osx,
			])

		_:
			return "I have nothing to say."


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
	# TR: dokunma (İ/ı dönüşümü riskli; havuzlar zaten uygun kurulu).
	# EN: lakaptan sonra akıcılık için ilk harfi küçült — "I" zamiri hariç.
	if Loc.lang == "en":
		if s.begins_with("I ") or s.begins_with("I'") or s.begins_with("I-"):
			return s
		return s[0].to_lower() + s.substr(1)
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


static func _dir_text_en(d: int) -> String:
	match d:
		Enums.Direction.CLOCKWISE:
			return "clockwise"
		Enums.Direction.COUNTER_CLOCKWISE:
			return "counter-clockwise"
		_:
			return "at equal distance"
