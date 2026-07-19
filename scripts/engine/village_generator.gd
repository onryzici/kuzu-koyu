class_name VillageGenerator
extends RefCounted

## Bulmaca üretici (V2 — Sorgu & Gece). Bkz. CLAUDE.md §0.5 ve §8.
##
## Altın kural (§13.7, v2 hali): üretilen her köy İKİ garantiyle canlıya çıkar:
##   a) TABAN TEKLİK: tüm ifadeler verilmiş sayılırken solver tam 1 dünya bulur.
##   b) BÜTÇE GARANTİSİ: basit bir bot, günlük sorgu hakkı + gece avlarıyla
##      max_days içinde tekliğe ulaşabilir (_budget_solvable). Ulaşamazsa köy RED.
##
## Yalan üretimi (§18): önce ground truth'a göre DOĞRU claim'i hesapla, sonra onu
## İHLAL eden bir claim seç — böylece çözücüyle tutarlı kalır.
##
## V2 ifade modeli: her karakterin 2 ifadesi var (claims); kurt HEPSİNDE yalan
## söyler. Deterministik-ifadeli rollerin (Bekçi/İzci...) 2. ifadesi "gözlem"dir
## (ALIGNMENT_OF) — aynı cümleyi iki kez kurmasın.
##
## Determinizm (§13.6): tüm rastlantı tek bir seed'li RandomNumberGenerator üzerinden.

## İyi rol havuzu. Büyük havuz = her köy farklı bir alt küme gösterir (çeşitlilik).
const GOOD_ROLES: Array[StringName] = [
	&"Judge", &"Confessor", &"Oracle", &"Dreamer", &"Knight", &"Sentry",
	&"Scout", &"Enlightened", &"Architect", &"Lover", &"Gossip",
]

## İfadesi hedef-rastlantılı roller: 2. ifade aynı tipten (farklı hedef) olabilir.
const RANDOM_ROLES: Array[StringName] = [&"Judge", &"Confessor", &"Oracle", &"Dreamer", &"Gossip"]


## config: { n, evil_count, demon_count, anchor_count, seed, max_attempts,
##           omen_type, outcast_count, drunk_count, slayer, hunter,
##           q_per_day, max_days, kills_per_night }
static func generate(config: Dictionary, rng: RandomNumberGenerator) -> VillageState:
	var n: int = config.get("n", 7)
	var evil_count: int = config.get("evil_count", 2)
	var demon_count: int = config.get("demon_count", 1)
	var base_anchors: int = config.get("anchor_count", 1)
	var max_attempts: int = config.get("max_attempts", 600)
	var omen_type: int = config.get("omen_type", Enums.OmenType.NONE)
	var outcast_count: int = config.get("outcast_count", 0)  # Ermiş sayısı
	var drunk_count: int = config.get("drunk_count", 0)      # Sarhoş sayısı
	var has_slayer: bool = config.get("slayer", false)       # Kılıççı var mı
	var has_hunter: bool = config.get("hunter", false)       # Avcı var mı
	var q_per_day: int = config.get("q_per_day", 3)
	var max_days: int = config.get("max_days", 5)
	var kills_per_night: int = config.get("kills_per_night", 1)

	for attempt in range(max_attempts):
		# Uzun süre çözülemezse anchor sayısını kademeli artır (simetriyi kır, §5.7).
		var anchor_count := base_anchors
		if attempt > max_attempts / 2:
			anchor_count = base_anchors + 1

		var state := _try_generate(n, evil_count, demon_count, anchor_count, omen_type, outcast_count, drunk_count, has_slayer, has_hunter, rng)
		state.q_per_day = q_per_day
		state.questions_left = q_per_day
		state.max_days = max_days
		state.kills_per_night = kills_per_night

		# a) Taban teklik: tüm ifadeler verilmiş sayılırken tek çözüm mü?
		for c in state.characters:
			c.given = c.claims.size()
		var determined := DeductionSolver.is_determined(state.visible_for_solver())
		for c in state.characters:
			c.given = 0

		# b) Bütçe garantisi: bot, sorgu bütçesi + geceler içinde tekliğe ulaşabilmeli.
		if determined and not _budget_solvable(state):
			determined = false

		if determined:
			state.seed = config.get("seed", 0)
			# Omen GİZLİ başlar: oyuncu Müneccim'i sorgulayınca öğrenir.
			# (Teklik kontrolü yukarıda omen-bilinir varsayımıyla yapıldı.)
			state.known_omen = Enums.OmenType.NONE
			return state

	push_error("VillageGenerator: %d denemede çözülebilir köy üretilemedi (n=%d evil=%d)" % [max_attempts, n, evil_count])
	return null


## BÜTÇE BOTU (§0.5 adalet): en az sorgulanandan başlayarak günde q_per_day sorgu,
## sonra gece avı — solver tekliğe ulaşırsa köy "yetişilebilir". Bot Müneccim'i
## sorgulayınca Omen'i öğrenir (gerçek akışla birebir). Derin kopyada oynar.
static func _budget_solvable(state: VillageState) -> bool:
	var sim: VillageState = state.duplicate(true)
	for c in sim.characters:
		c.given = 0
	sim.night_events = []
	sim.known_omen = Enums.OmenType.NONE
	var d := 1
	while d <= sim.max_days:
		# GÜNDÜZ: q sorgu — canlı + ifadesi kalanlardan en az sorgulanmış (küçük seat).
		for q in range(sim.q_per_day):
			var pick := -1
			var best_given := 9999
			for c in sim.characters:
				if c.is_alive() and c.given < c.claims.size() and c.given < best_given:
					best_given = c.given
					pick = c.seat
			if pick < 0:
				break
			var ch := sim.get_character(pick)
			ch.given += 1
			if ch.role == &"Astrologer" and sim.omen_type != Enums.OmenType.NONE:
				sim.known_omen = sim.omen_type
		if DeductionSolver.is_determined(sim.visible_for_solver()):
			return true  # gün içinde teklik → aynı gün ayıklar, gece hiç olmaz
		# GECE
		for k in range(sim.kills_per_night):
			if NightEngine.apply(sim) < 0:
				break
		if sim.alive_good_count() <= sim.alive_evil_count():
			return false  # sürü düştü
		if DeductionSolver.is_determined(sim.visible_for_solver()):
			return d + 1 <= sim.max_days  # şafakta teklik → ertesi gün ayıklamaya yetmeli
		d += 1
	return false


static func _try_generate(n: int, evil_count: int, demon_count: int, anchor_count: int, omen_type: int, outcast_count: int, drunk_count: int, has_slayer: bool, has_hunter: bool, rng: RandomNumberGenerator) -> VillageState:
	var state := VillageState.new()
	state.n = n
	state.evil_count = evil_count
	state.demon_count = demon_count
	state.minion_count = evil_count - demon_count
	state.outcast_count = 0
	state.drunk_count = 0

	var chars: Array[Character] = []
	for i in range(n):
		var c := Character.new()
		c.seat = i
		chars.append(c)

	# Evil yerleşimi: Omen varsa kuralı sağlayan bir kombinasyondan seç (§5.5),
	# yoksa rastgele. Omen sağlanamazsa (boş küme) NONE'a düş.
	var effective_omen := omen_type
	var evil_seats: Array
	if omen_type != Enums.OmenType.NONE:
		var valid := Omen.valid_placements(omen_type, {}, n, evil_count)
		if valid.is_empty():
			effective_omen = Enums.OmenType.NONE
			evil_seats = _sample(_seq(n), evil_count, rng)
		else:
			evil_seats = (valid[rng.randi() % valid.size()] as Array).duplicate()
	else:
		evil_seats = _sample(_seq(n), evil_count, rng)

	state.omen_type = effective_omen
	state.omen_params = {}
	# Üretim sırasında Omen bilinir kabul edilir (teklik kontrolü tutarlı olsun);
	# generate() dönmeden known_omen=NONE yapılır (oyuncu Müneccim'den öğrenir).
	state.known_omen = effective_omen

	for idx in range(evil_seats.size()):
		var s: int = evil_seats[idx]
		chars[s].alignment = Enums.Alignment.EVIL
		if idx < demon_count:
			chars[s].category = Enums.Category.DEMON
			chars[s].role = &"Demon"
		else:
			chars[s].category = Enums.Category.MINION
			chars[s].role = &"Minion"
		chars[s].bluff_role = GOOD_ROLES[rng.randi() % GOOD_ROLES.size()]

	# İyi köylülere MÜMKÜN OLDUĞUNCA BENZERSIZ rol ver (tekrarlı tanıklık olmasın).
	var role_pool := _sample(GOOD_ROLES, GOOD_ROLES.size(), rng)
	var ri := 0
	for i in range(n):
		if chars[i].alignment == Enums.Alignment.GOOD:
			chars[i].category = Enums.Category.VILLAGER
			chars[i].role = role_pool[ri % role_pool.size()]
			ri += 1

	# Omen varsa: bir GOOD seat'i Müneccim (Astrologer) yap — Gizli Kural'ı ifşa eder.
	# Astrologer GOOD_ROLES'ta yok → Evil onu bluff'layamaz (yanlış omen olmaz).
	if effective_omen != Enums.OmenType.NONE:
		var good_idx: Array = []
		for i in range(n):
			if chars[i].alignment == Enums.Alignment.GOOD:
				good_idx.append(i)
		if not good_idx.is_empty():
			chars[good_idx[rng.randi() % good_idx.size()]].role = &"Astrologer"

	# Outcast (Ermiş/Saint): iyi ama tuzak. Kompozisyonda ilan edilir (adalet, §7.3).
	if outcast_count > 0:
		var op: Array = []
		for i in range(n):
			if chars[i].alignment == Enums.Alignment.GOOD and chars[i].role != &"Astrologer":
				op.append(i)
		var chosen_out := _sample(op, min(outcast_count, op.size()), rng)
		for si in chosen_out:
			chars[si].category = Enums.Category.OUTCAST
			chars[si].role = &"Saint"
		state.outcast_count = chosen_out.size()

	# Sarhoş (Drunk): iyi bir parya ama kendini bir köylü sanır → köylü GİBİ görünür
	# ve ifadeleri GÜVENİLMEZ (her biri %50 yanlış). Hangisi olduğu gizli (§5.4).
	if drunk_count > 0:
		var dp: Array = []
		for i in range(n):
			if chars[i].alignment == Enums.Alignment.GOOD and chars[i].category == Enums.Category.VILLAGER and chars[i].role != &"Astrologer":
				dp.append(i)
		var chosen_d := _sample(dp, min(drunk_count, dp.size()), rng)
		for di in chosen_d:
			chars[di].category = Enums.Category.OUTCAST
			chars[di].role = GOOD_ROLES[rng.randi() % GOOD_ROLES.size()]  # sandığı köylü rolü
		state.drunk_count = chosen_d.size()
		state.outcast_count += chosen_d.size()

	# Kılıççı/Avcı: aktif yetenekli villager.
	if has_slayer:
		_assign_active_role(chars, n, &"Slayer", rng)
	if has_hunter:
		_assign_active_role(chars, n, &"Hunter", rng)

	state.characters = chars

	var world := state.ground_truth_world()

	# İFADELER (V2: her karakterin claims listesi; sorgulandıkça sırayla verilir).
	for i in range(n):
		var c := chars[i]
		c.claims = _build_claims(c, world, n, rng, effective_omen)
		c.given = 0
		c.testimony = null

	# Anchor: birkaç GOOD (parya değil) seat'i "confirmed" işaretle.
	var good_seats: Array = []
	for i in range(n):
		if chars[i].alignment == Enums.Alignment.GOOD and chars[i].category != Enums.Category.OUTCAST:
			good_seats.append(i)
	var chosen := _sample(good_seats, min(anchor_count, good_seats.size()), rng)
	state.anchors = chosen

	state.marks = []
	for i in range(n):
		state.marks.append(Enums.MarkType.NONE)

	return state


## Bir karakterin TÜM ifadelerini üret (tipik 2). Kurallar (§0.5):
##   GOOD villager → hepsi DOĞRU. EVIL → hepsi YANLIŞ (bluff tipinde).
##   Sarhoş → her ifade bağımsız %50 yanlış. Ermiş → tek uyarı (kısıtsız).
##   Müneccim → Omen metni + doğru gözlem. Kılıççı/Avcı → flavor + doğru gözlem.
static func _build_claims(c: Character, world: Dictionary, n: int, rng: RandomNumberGenerator, omen_type: int = Enums.OmenType.NONE) -> Array:
	var out: Array = []
	var i := c.seat

	if c.alignment == Enums.Alignment.EVIL:
		var first := _false_claim(c.bluff_role, i, world, n, rng)
		first.text = TestimonyText.phrase(c.bluff_role, first, rng)
		out.append(first)
		var second: TestimonyClaim
		if c.bluff_role in RANDOM_ROLES:
			second = _distinct_retry(first, func(): return _false_claim(c.bluff_role, i, world, n, rng))
		else:
			second = _false_obs(i, world, n, rng)
		second.text = TestimonyText.phrase(c.bluff_role, second, rng)
		out.append(second)
		return out

	match c.role:
		&"Saint":
			var stt := TestimonyClaim.new()
			stt.type = Enums.TestimonyType.SELF_ANCHOR
			stt.speaker = i
			stt.text = "Bana dokunmayın — ben kutsanmış bir masumum. Ayıklarsanız felaket olur!"
			out.append(stt)
		&"Astrologer":
			var at := TestimonyClaim.new()
			at.type = Enums.TestimonyType.SELF_ANCHOR
			at.speaker = i
			at.text = Omen.describe(omen_type)
			out.append(at)
			var aobs := _true_obs(i, world, n, rng)
			aobs.text = TestimonyText.phrase(&"Judge", aobs, rng)
			out.append(aobs)
		&"Slayer", &"Hunter":
			var alt := TestimonyClaim.new()
			alt.type = Enums.TestimonyType.SELF_ANCHOR
			alt.speaker = i
			alt.text = ("Kılıcım hazır — bir kez saplayabilirim. Alfa Kurt'u bulursam ölür." if c.role == &"Slayer"
				else "Yayım gergin — bir kez ateş edebilirim. Kurt vurursam ölür, koyun vurursam yara alırım.")
			out.append(alt)
			var sobs := _true_obs(i, world, n, rng)
			sobs.text = TestimonyText.phrase(&"Judge", sobs, rng)
			out.append(sobs)
		_:
			if c.category == Enums.Category.OUTCAST:
				# Sarhoş: sandığı rolün tipinde ama her ifade bağımsız %50 yanlış.
				for k in range(2):
					var dc: TestimonyClaim
					if k == 0 or c.role in RANDOM_ROLES:
						dc = (_true_claim(c.role, i, world, n, rng) if rng.randf() < 0.5
							else _false_claim(c.role, i, world, n, rng))
					else:
						dc = (_true_obs(i, world, n, rng) if rng.randf() < 0.5
							else _false_obs(i, world, n, rng))
					dc.text = TestimonyText.phrase(c.role, dc, rng)
					out.append(dc)
			else:
				# Düz köylü: 2 DOĞRU ifade. Deterministik rollerde 2.si gözlem.
				var first := _true_claim(c.role, i, world, n, rng)
				first.text = TestimonyText.phrase(c.role, first, rng)
				out.append(first)
				var second: TestimonyClaim
				if c.role in RANDOM_ROLES:
					second = _distinct_retry(first, func(): return _true_claim(c.role, i, world, n, rng))
				else:
					second = _true_obs(i, world, n, rng)
				second.text = TestimonyText.phrase(c.role, second, rng)
				out.append(second)

	return out


## İkinci ifade birinciyle yapısal olarak aynı çıkmasın diye birkaç kez yeniden dene.
static func _distinct_retry(first: TestimonyClaim, maker: Callable) -> TestimonyClaim:
	var second: TestimonyClaim = maker.call()
	for attempt in range(8):
		if not _same_claim(first, second):
			break
		second = maker.call()
	return second


static func _same_claim(a: TestimonyClaim, b: TestimonyClaim) -> bool:
	return a.type == b.type and a.targets == b.targets and a.number == b.number \
		and a.direction == b.direction and a.compare == b.compare \
		and a.bool_val == b.bool_val and a.alignment == b.alignment


## Genel "gözlem" ifadesi: rastgele bir hedefin safı — DOĞRU sürümü.
static func _true_obs(speaker: int, world: Dictionary, n: int, rng: RandomNumberGenerator) -> TestimonyClaim:
	var t := TestimonyClaim.new()
	t.speaker = speaker
	t.type = Enums.TestimonyType.ALIGNMENT_OF
	var tgt := _rand_other(speaker, n, rng)
	t.targets = [tgt]
	t.alignment = world["alignment"][tgt]
	return t


## Gözlem ifadesinin YANLIŞ sürümü (saf ters çevrilir).
static func _false_obs(speaker: int, world: Dictionary, n: int, rng: RandomNumberGenerator) -> TestimonyClaim:
	var t := _true_obs(speaker, world, n, rng)
	t.alignment = Enums.Alignment.GOOD if t.alignment == Enums.Alignment.EVIL else Enums.Alignment.EVIL
	return t


## Rol tipine uygun, ground truth'ta DOĞRU bir claim üretir (yapısal alanlar; metin yok).
static func _true_claim(role: StringName, speaker: int, world: Dictionary, n: int, rng: RandomNumberGenerator) -> TestimonyClaim:
	var t := TestimonyClaim.new()
	t.speaker = speaker
	var al: Array = world["alignment"]
	var evil_seats: Array = world["evil_seats"]

	match role:
		&"Judge", &"Confessor":
			t.type = Enums.TestimonyType.ALIGNMENT_OF
			var tgt := _rand_other(speaker, n, rng)
			t.targets = [tgt]
			t.alignment = al[tgt]

		&"Oracle":
			t.type = Enums.TestimonyType.COUNT_IN_SET
			var pair := _sample(_others(speaker, n), 2, rng)
			t.targets = pair
			t.number = _count_evil(pair, al)

		&"Dreamer":
			# Üç kartlık set — Oracle'dan yapısal olarak farklı bilgi.
			t.type = Enums.TestimonyType.COUNT_IN_SET
			var trio := _sample(_others(speaker, n), min(3, n - 1), rng)
			t.targets = trio
			t.number = _count_evil(trio, al)

		&"Knight", &"Sentry":
			t.type = Enums.TestimonyType.NEIGHBOR_HAS_EVIL
			t.number = _count_evil(BoardTopology.neighbors(speaker, n), al)

		&"Scout":
			t.type = Enums.TestimonyType.NEAREST_EVIL_DISTANCE
			t.number = BoardTopology.nearest_evil_distance(speaker, evil_seats, n)

		&"Enlightened":
			t.type = Enums.TestimonyType.NEAREST_EVIL_DIRECTION
			t.direction = BoardTopology.nearest_evil_direction(speaker, evil_seats, n)

		&"Architect":
			t.type = Enums.TestimonyType.EVIL_COUNT_IN_REGION
			var half := int(n / 2.0)
			var ra := BoardTopology.arc((speaker + 1) % n, half, n)
			var rb: Array = []
			for s in range(n):
				if s != speaker and not (s in ra):
					rb.append(s)
			t.region_a = ra
			t.region_b = rb
			var ca := _count_evil(ra, al)
			var cb := _count_evil(rb, al)
			if ca > cb:
				t.compare = Enums.Compare.GREATER
			elif ca < cb:
				t.compare = Enums.Compare.LESS
			else:
				t.compare = Enums.Compare.EQUAL

		&"Lover":
			# İki komşusunun aynı safta olup olmadığı.
			t.type = Enums.TestimonyType.PAIR_RELATION
			var nb := BoardTopology.neighbors(speaker, n)
			t.targets = [nb[0], nb[1]]
			t.bool_val = al[nb[0]] == al[nb[1]]

		&"Gossip":
			# İki rastgele kartın aynı safta olup olmadığı.
			t.type = Enums.TestimonyType.PAIR_RELATION
			var pr := _sample(_others(speaker, n), 2, rng)
			t.targets = pr
			t.bool_val = al[pr[0]] == al[pr[1]]

		_:
			t.type = Enums.TestimonyType.ALIGNMENT_OF
			var tgt2 := _rand_other(speaker, n, rng)
			t.targets = [tgt2]
			t.alignment = al[tgt2]

	return t


## Dışarıdan (SpreadEngine legacy) kullanım için public yalan-claim üretici.
static func make_false_claim(bluff_role: StringName, speaker: int, world: Dictionary, n: int, rng: RandomNumberGenerator) -> TestimonyClaim:
	return _false_claim(bluff_role, speaker, world, n, rng)


## bluff_role'un tanıklık tipinde ama ground truth'ta kesinlikle YANLIŞ bir claim.
## Yöntem (§18): önce o rolün DOĞRU claim'ini üret, sonra iddia edilen değeri
## bozarak yalana çevir. Böylece gösterilen rol ile tanıklık tipi tutarlı kalır.
static func _false_claim(bluff_role: StringName, speaker: int, world: Dictionary, n: int, rng: RandomNumberGenerator) -> TestimonyClaim:
	var al: Array = world["alignment"]
	var evil_seats: Array = world["evil_seats"]
	var t := _true_claim(bluff_role, speaker, world, n, rng)

	match t.type:
		Enums.TestimonyType.ALIGNMENT_OF:
			t.alignment = Enums.Alignment.GOOD if t.alignment == Enums.Alignment.EVIL else Enums.Alignment.EVIL
		Enums.TestimonyType.COUNT_IN_SET:
			t.number = _other_count(t.number, t.targets.size(), rng)
		Enums.TestimonyType.NEIGHBOR_HAS_EVIL:
			t.number = _other_count(t.number, 2, rng)
		Enums.TestimonyType.NEAREST_EVIL_DISTANCE:
			t.number = _wrong_distance(t.number, n)
		Enums.TestimonyType.NEAREST_EVIL_DIRECTION:
			t.direction = _other_direction(t.direction, rng)
		Enums.TestimonyType.EVIL_COUNT_IN_REGION:
			t.compare = _other_compare(t.compare, rng)
		Enums.TestimonyType.PAIR_RELATION:
			t.bool_val = not t.bool_val
		_:
			pass

	# Garanti: gerçekten yanlış olmalı. Değilse evrensel-yanlış fallback.
	var check_world := {"n": n, "alignment": al, "evil_seats": evil_seats}
	if t.evaluate(check_world):
		t.type = Enums.TestimonyType.ALIGNMENT_OF
		for s in range(n):
			if s != speaker and al[s] == Enums.Alignment.GOOD:
				t.targets = [s]
				t.alignment = Enums.Alignment.EVIL  # good seat'i Evil demek -> yanlış
				break
	return t


static func _count_evil(seats: Array, al: Array) -> int:
	var c := 0
	for s in seats:
		if al[s] == Enums.Alignment.EVIL:
			c += 1
	return c


## [0..max_count] aralığında true_val'dan farklı bir sayı (yanlış sayım).
static func _other_count(true_val: int, max_count: int, rng: RandomNumberGenerator) -> int:
	var options: Array = []
	for k in range(max_count + 1):
		if k != true_val:
			options.append(k)
	return options[rng.randi() % options.size()]


static func _wrong_distance(true_val: int, n: int) -> int:
	var w := true_val + 1
	if w > int(n / 2.0):
		w = max(1, true_val - 1)
	if w == true_val:
		w = true_val + 1
	return w


static func _other_direction(true_dir: int, rng: RandomNumberGenerator) -> int:
	var options: Array = []
	for d in [Enums.Direction.CLOCKWISE, Enums.Direction.COUNTER_CLOCKWISE, Enums.Direction.EQUIDISTANT]:
		if d != true_dir:
			options.append(d)
	return options[rng.randi() % options.size()]


static func _other_compare(true_cmp: int, rng: RandomNumberGenerator) -> int:
	var options: Array = []
	for c in [Enums.Compare.LESS, Enums.Compare.EQUAL, Enums.Compare.GREATER]:
		if c != true_cmp:
			options.append(c)
	return options[rng.randi() % options.size()]


# --- yardımcılar ---

## Aktif yetenekli rolü (Slayer/Hunter) bir düz köylüye ata (Astrologer/başka aktif değil).
static func _assign_active_role(chars: Array, n: int, role: StringName, rng: RandomNumberGenerator) -> void:
	var pool: Array = []
	for i in range(n):
		var c: Character = chars[i]
		if c.alignment == Enums.Alignment.GOOD and c.category == Enums.Category.VILLAGER \
				and c.role != &"Astrologer" and c.role != &"Slayer" and c.role != &"Hunter":
			pool.append(i)
	if not pool.is_empty():
		chars[pool[rng.randi() % pool.size()]].role = role


static func _seq(n: int) -> Array:
	var out: Array = []
	for i in range(n):
		out.append(i)
	return out


static func _others(x: int, n: int) -> Array:
	var out: Array = []
	for i in range(n):
		if i != x:
			out.append(i)
	return out


static func _rand_other(x: int, n: int, rng: RandomNumberGenerator) -> int:
	var pool := _others(x, n)
	return pool[rng.randi() % pool.size()]


## Pool'dan k farklı eleman (seed'li Fisher-Yates).
static func _sample(pool: Array, k: int, rng: RandomNumberGenerator) -> Array:
	var arr := pool.duplicate()
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
	return arr.slice(0, k)
