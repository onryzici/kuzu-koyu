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
	&"Healer", &"Weaver", &"Midwife", &"Milkmaid", &"Crier", &"Beekeeper",
	&"Sheepdog", &"Shearer", &"Drummer", &"Welldigger",
]

## İfadesi hedef-rastlantılı roller: 2. ifade aynı tipten (farklı hedef) olabilir.
const RANDOM_ROLES: Array[StringName] = [
	&"Judge", &"Confessor", &"Oracle", &"Dreamer", &"Gossip",
	&"Healer", &"Weaver", &"Midwife", &"Welldigger", &"Beadcounter",
]


## ROL AÇILIM KADEMELERİ: rol, ancak seferin çilesi (role_tier) bu eşiğe
## ulaşınca havuza girer. Listede olmayan rol = baştan açık. Codex kilitleri de
## bu tablodan okur. Determinizm: aynı seed + aynı çile = aynı köy (arkadaş yarışı).
const ROLE_TIERS := {
	&"Beadcounter": 1, &"Skittish": 1, &"Tailor": 1, &"Mirrorwright": 1,
}

## Özel (bayrakla atanan) roller: rastgele köylü havuzuna girmez, Sarhoş bunları
## sanamaz, Uğursuz/aktif rol ataması bunların üstüne yazamaz. V3 ziyaretçi
## rolleri (Otacı/Gözcü/Seyyah) de burada — ziyaret çözümü net kalsın (§0.7).
const SPECIAL_ROLES: Array[StringName] = [
	&"Astrologer", &"Slayer", &"Hunter", &"Trapper",
	&"Herbalist", &"Watcher", &"Wanderer", &"Hound",
]


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
	var night_rule: int = config.get("night_rule", Enums.NightRule.NEAREST)
	var has_trapper: bool = config.get("trapper", false)     # Tuzakçı var mı
	var jinxed_count: int = config.get("jinxed_count", 0)    # Uğursuz sayısı
	# V3 Gece Trafiği rolleri (bkz. §0.7) — köy bazında bayrakla açılır.
	var has_herbalist: bool = config.get("herbalist", false) # Otacı var mı
	var has_watcher: bool = config.get("watcher", false)     # Gözcü var mı
	var has_wanderer: bool = config.get("wanderer", false)   # Seyyah var mı
	var has_hound: bool = config.get("hound", false)         # Tazı var mı (V3.1)
	var has_prowler: bool = config.get("prowler", false)     # Sinsi Kurt kuralı (V3.1)
	var alternating: bool = config.get("alternating", false) # Dönek Alfa (V3.1)
	var role_tier: int = config.get("role_tier", 99)         # rol açılım kademesi (çile)
	var cull_damage: int = config.get("cull_damage", 5)      # Kuraklık: 7
	var modifiers: Array = (config.get("modifiers", []) as Array).duplicate()  # köy kuralları (İLAN edilir)
	var role_pool: Array = config.get("role_pool", [])       # sefer destesi (draft; boş = tüm havuz)
	# İLAN edilen köy kuralları: Sinsi ve Dönek modifier olarak duyurulur (§7.3).
	if has_prowler and not modifiers.has("prowler"):
		modifiers.append("prowler")
	if alternating and not modifiers.has("moody"):
		modifiers.append("moody")

	for attempt in range(max_attempts):
		# Uzun süre çözülemezse anchor sayısını kademeli artır (simetriyi kır, §5.7).
		var anchor_count := base_anchors
		if attempt > max_attempts / 2:
			anchor_count = base_anchors + 1

		var visitor_flags := {"herbalist": has_herbalist, "watcher": has_watcher,
			"wanderer": has_wanderer, "hound": has_hound}
		var state := _try_generate(n, evil_count, demon_count, anchor_count, omen_type, outcast_count, drunk_count, has_slayer, has_hunter, has_trapper, jinxed_count, role_tier, role_pool, visitor_flags, rng)
		# Seed'i BOT simülasyonundan önce yaz: Gözcü'nün sahte şafak raporları
		# seed+gün+seat'ten türetilir — bot ile gerçek oyun birebir aynı raporu üretir.
		state.seed = config.get("seed", 0)
		state.q_per_day = q_per_day
		state.night_rule = night_rule  # bot gece simülasyonu da bu kuralla oynar
		state.alternating_rule = alternating
		state.questions_left = q_per_day
		state.max_days = max_days
		state.kills_per_night = kills_per_night
		state.cull_damage = cull_damage
		state.modifiers = modifiers.duplicate()
		# SUSKUN SÜRÜ modifier'ı: herkesin TEK ifadesi var — sorgu ekonomisi sıkışır.
		# Teklik + bot-bütçe kontrolleri bu kırpılmış hâl üzerinde koşar (adalet korunur).
		if modifiers.has("silent"):
			for c in state.characters:
				if c.claims.size() > 1:
					c.claims = c.claims.slice(0, 1)

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
	sim.last_questioned = -1
	var d := 1
	while d <= sim.max_days:
		# Gün sayacı gerçek akışla birebir ilerlesin: gün damgalı şafak raporları
		# (Gözcü/Tazı) ve Dönek Alfa kuralı state.day'den okur.
		sim.day = d
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
			sim.last_questioned = pick  # V3: günün son sorgusu = Otacı hedefi
			if ch.role == &"Astrologer" and sim.omen_type != Enums.OmenType.NONE:
				sim.known_omen = sim.omen_type
		if DeductionSolver.is_determined(sim.visible_for_solver()):
			return true  # gün içinde teklik → aynı gün ayıklar, gece hiç olmaz
		# GECE (gerçek akışla birebir: -3 = şifa, av hakkı harcandı ama gece sürer)
		for k in range(sim.kills_per_night):
			if NightEngine.apply(sim) == -1:
				break
		NightEngine.dawn_reports(sim)  # Gözcü raporları (deterministik — §0.7)
		sim.last_questioned = -1
		if sim.alive_good_count() <= sim.alive_evil_count():
			return false  # sürü düştü
		if DeductionSolver.is_determined(sim.visible_for_solver()):
			return d + 1 <= sim.max_days  # şafakta teklik → ertesi gün ayıklamaya yetmeli
		d += 1
	return false


static func _try_generate(n: int, evil_count: int, demon_count: int, anchor_count: int, omen_type: int, outcast_count: int, drunk_count: int, has_slayer: bool, has_hunter: bool, has_trapper: bool, jinxed_count: int, role_tier: int, role_pool: Array, visitor_flags: Dictionary, rng: RandomNumberGenerator) -> VillageState:
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

	# Köy-özel rol havuzu: koşullu roller (Terzi ≥2 kurt, Aynacı çift n) ancak
	# anlamlıysa havuza girer. Bluff/köylü/sarhoş hepsi bu havuzdan çeker —
	# kurt da ancak bu köyde var olabilecek bir rolü taklit edebilir (adalet).
	# role_pool doluysa (sefer destesi — draft ile büyür) yalnız o roller aday olur.
	var source: Array = []
	if role_pool.is_empty():
		source = GOOD_ROLES.duplicate()
		source.append_array([&"Beadcounter", &"Skittish", &"Tailor", &"Mirrorwright"])
	else:
		for rp in role_pool:
			source.append(StringName(rp))
	var pool_all: Array = []
	for r in source:
		if ROLE_TIERS.get(r, 0) > role_tier:
			continue
		if r == &"Tailor" and evil_count < 2:
			continue
		if r == &"Mirrorwright" and n % 2 != 0:
			continue
		if not pool_all.has(r):
			pool_all.append(r)

	state.omen_type = effective_omen
	state.omen_params = {}
	# Üretim sırasında Omen bilinir kabul edilir (teklik kontrolü tutarlı olsun);
	# generate() dönmeden known_omen=NONE yapılır (oyuncu Müneccim'den öğrenir).
	state.known_omen = effective_omen

	# Kurt bluff havuzu: köylü rolleri + (açıksa) V3 ziyaretçi rolleri — kurt Otacı/
	# Gözcü/Seyyah kılığına girebilir; gece davranışı (ya da yalan raporu) onu ele verir.
	var bluff_pool := pool_all.duplicate()
	for vf: StringName in [&"Herbalist", &"Watcher", &"Wanderer", &"Hound"]:
		if visitor_flags.get(String(vf).to_lower(), false):
			bluff_pool.append(vf)
	for idx in range(evil_seats.size()):
		var s: int = evil_seats[idx]
		chars[s].alignment = Enums.Alignment.EVIL
		if idx < demon_count:
			chars[s].category = Enums.Category.DEMON
			chars[s].role = &"Demon"
		else:
			chars[s].category = Enums.Category.MINION
			chars[s].role = &"Minion"
		chars[s].bluff_role = bluff_pool[rng.randi() % bluff_pool.size()]

	# İyi köylülere MÜMKÜN OLDUĞUNCA BENZERSIZ rol ver (tekrarlı tanıklık olmasın).
	var assign_pool := _sample(pool_all, pool_all.size(), rng)
	var ri := 0
	for i in range(n):
		if chars[i].alignment == Enums.Alignment.GOOD:
			chars[i].category = Enums.Category.VILLAGER
			chars[i].role = assign_pool[ri % assign_pool.size()]
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
			chars[di].role = pool_all[rng.randi() % pool_all.size()]  # sandığı köylü rolü
		state.drunk_count = chosen_d.size()
		state.outcast_count += chosen_d.size()

	# Kılıççı/Avcı: aktif yetenekli villager.
	if has_slayer:
		_assign_active_role(chars, n, &"Slayer", rng)
	if has_hunter:
		_assign_active_role(chars, n, &"Hunter", rng)
	if has_trapper:
		_assign_active_role(chars, n, &"Trapper", rng)
	# V3 ziyaretçi rolleri (bkz. §0.7) — gece kuralları İLAN edilir.
	if visitor_flags.get("herbalist", false):
		_assign_active_role(chars, n, &"Herbalist", rng)
	if visitor_flags.get("watcher", false):
		_assign_active_role(chars, n, &"Watcher", rng)
	if visitor_flags.get("wanderer", false):
		_assign_active_role(chars, n, &"Wanderer", rng)
	if visitor_flags.get("hound", false):
		_assign_active_role(chars, n, &"Hound", rng)

	# Uğursuz (Jinxed): İYİ ve DOĞRU söyler ama sorgulayanın sürüsünden 1 can alır.
	# Açıkça görünür (kart "Uğursuz" der) — risk/ödül İLAN edilir (adalet §7.3).
	if jinxed_count > 0:
		var jpool: Array = []
		for i in range(n):
			if chars[i].alignment == Enums.Alignment.GOOD \
					and chars[i].category == Enums.Category.VILLAGER \
					and not SPECIAL_ROLES.has(chars[i].role):
				jpool.append(i)
		var chosen_j := _sample(jpool, min(jinxed_count, jpool.size()), rng)
		for ji in chosen_j:
			chars[ji].category = Enums.Category.OUTCAST
			chars[ji].role = &"Jinxed"
		state.outcast_count += chosen_j.size()

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
		&"Jinxed":
			# Uğursuz: nazar uyarısı + DOĞRU bir gözlem (İYİ ve dürüsttür; bedeli candır).
			var jt := TestimonyClaim.new()
			jt.type = Enums.TestimonyType.SELF_ANCHOR
			jt.speaker = i
			jt.text = "Bana nazar değmiş çoban... Beni konuşturursan sürüden can gider. Yine de sorarsan — doğruyu söylerim."
			out.append(jt)
			var jobs := _true_obs(i, world, n, rng)
			jobs.text = TestimonyText.phrase(&"Judge", jobs, rng)
			out.append(jobs)
		&"Astrologer":
			var at := TestimonyClaim.new()
			at.type = Enums.TestimonyType.SELF_ANCHOR
			at.speaker = i
			at.text = Omen.describe(omen_type)
			out.append(at)
			var aobs := _true_obs(i, world, n, rng)
			aobs.text = TestimonyText.phrase(&"Judge", aobs, rng)
			out.append(aobs)
		&"Slayer", &"Hunter", &"Trapper":
			var alt := TestimonyClaim.new()
			alt.type = Enums.TestimonyType.SELF_ANCHOR
			alt.speaker = i
			if c.role == &"Slayer":
				alt.text = "Kılıcım hazır — bir kez saplayabilirim. Alfa Kurt'u bulursam ölür."
			elif c.role == &"Hunter":
				alt.text = "Yayım gergin — bir kez ateş edebilirim. Kurt vurursam ölür, koyun vurursam yara alırım."
			else:
				alt.text = "Kapanım yağlı, dişleri keskin — bir gece için bir koltuğa kurarım. Kurt oraya saldırırsa postu elimde kalır."
			out.append(alt)
			var sobs := _true_obs(i, world, n, rng)
			sobs.text = TestimonyText.phrase(&"Judge", sobs, rng)
			out.append(sobs)
		&"Herbalist", &"Wanderer":
			# V3 ziyaretçi rolleri: 1. ifade GECE KURALININ İLANI (adalet §7.3 —
			# ziyaret kuralı herkese açık), 2. ifade doğru bir gözlem.
			# (Gözcü'nün ilanı da burada; raporları şafakta bedava düşer.)
			var vt := TestimonyClaim.new()
			vt.type = Enums.TestimonyType.SELF_ANCHOR
			vt.speaker = i
			if c.role == &"Herbalist":
				vt.text = ("Every night I carry my herbs to whoever was QUESTIONED LAST that day. If the wolf comes to that door, my patient lives." if Loc.lang == "en"
					else "Her gece, o gün EN SON SORGULANANIN evine ot taşırım. Kurt o kapıya dadanırsa hastam ölmez.")
			else:
				vt.text = ("I never sleep at home — each night I guest at the nearest living neighbor clockwise." if Loc.lang == "en"
					else "Evimde uyuduğum görülmemiştir — her gece saat yönündeki en yakın canlı komşuya misafir olurum.")
			out.append(vt)
			var vobs := _true_obs(i, world, n, rng)
			vobs.text = TestimonyText.phrase(&"Judge", vobs, rng)
			out.append(vobs)
		&"Watcher":
			var wt := TestimonyClaim.new()
			wt.type = Enums.TestimonyType.SELF_ANCHOR
			wt.speaker = i
			wt.text = ("I watch my neighbors' doors all night — every dawn I'll tell you how many visitors they had. No question needed." if Loc.lang == "en"
				else "Gece boyu kapı komşularımın eşiğini gözlerim — her şafak kaç ziyaretçi aldıklarını söylerim. Sorgu istemez, sözüm hediye.")
			out.append(wt)
			var wobs := _true_obs(i, world, n, rng)
			wobs.text = TestimonyText.phrase(&"Judge", wobs, rng)
			out.append(wobs)
		&"Hound":
			var ht := TestimonyClaim.new()
			ht.type = Enums.TestimonyType.SELF_ANCHOR
			ht.speaker = i
			ht.text = ("My nose never lies — each dawn I'll tell you which way the killer came from. No question needed." if Loc.lang == "en"
				else "Burnum yanılmaz — her şafak, katilin kurbana HANGİ YÖNDEN geldiğini söylerim. Sorgu istemez.")
			out.append(ht)
			var hobs := _true_obs(i, world, n, rng)
			hobs.text = TestimonyText.phrase(&"Judge", hobs, rng)
			out.append(hobs)
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
		&"Judge", &"Confessor", &"Healer":
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

		&"Midwife":
			# DÖRT kartlık set — geniş tarama (Oracle=2, Dreamer=3 ailesinin dördüncüsü).
			t.type = Enums.TestimonyType.COUNT_IN_SET
			var quad := _sample(_others(speaker, n), min(4, n - 1), rng)
			t.targets = quad
			t.number = _count_evil(quad, al)

		&"Milkmaid":
			# İki yanındaki İKİŞER komşu (±1, ±2): geniş komşuluk sayımı (deterministik).
			t.type = Enums.TestimonyType.COUNT_IN_SET
			t.targets = _ring_set(speaker, [-2, -1, 1, 2], n)
			t.number = _count_evil(t.targets, al)

		&"Crier":
			# Saat yönünde önündeki ÜÇ kart (deterministik yay).
			t.type = Enums.TestimonyType.COUNT_IN_SET
			t.targets = _ring_set(speaker, [1, 2, 3], n)
			t.number = _count_evil(t.targets, al)

		&"Beekeeper":
			# İki adım ötesindeki iki kart (±2): atlama komşuluğu (deterministik).
			t.type = Enums.TestimonyType.COUNT_IN_SET
			t.targets = _ring_set(speaker, [-2, 2], n)
			t.number = _count_evil(t.targets, al)

		&"Knight", &"Sentry", &"Sheepdog":
			t.type = Enums.TestimonyType.NEIGHBOR_HAS_EVIL
			t.number = _count_evil(BoardTopology.neighbors(speaker, n), al)

		&"Scout", &"Drummer":
			t.type = Enums.TestimonyType.NEAREST_EVIL_DISTANCE
			t.number = BoardTopology.nearest_evil_distance(speaker, evil_seats, n)

		&"Enlightened":
			t.type = Enums.TestimonyType.NEAREST_EVIL_DIRECTION
			t.direction = BoardTopology.nearest_evil_direction(speaker, evil_seats, n)

		&"Architect", &"Shearer":
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

		&"Gossip", &"Weaver", &"Welldigger":
			# İki rastgele kartın aynı safta olup olmadığı.
			t.type = Enums.TestimonyType.PAIR_RELATION
			var pr := _sample(_others(speaker, n), 2, rng)
			t.targets = pr
			t.bool_val = al[pr[0]] == al[pr[1]]

		&"Beadcounter":
			# Mod-2 bilgisi: 4 kartlık sette kurt sayısının paritesi. Tam sayı değil
			# parite — daha zayıf ama daha geniş bir kısıt (yeni matematik).
			t.type = Enums.TestimonyType.COUNT_PARITY_IN_SET
			var bset := _sample(_others(speaker, n), min(4, n - 1), rng)
			t.targets = bset
			t.bool_val = _count_evil(bset, al) % 2 == 0

		&"Skittish":
			# Eşitsizlik bilgisi: "kurt bana K'dan uzak/yakın" — İzci'nin (tam mesafe)
			# bulanık kardeşi; aralık kısıtı üretir.
			t.type = Enums.TestimonyType.NEAREST_EVIL_MIN_DIST
			var sd := BoardTopology.nearest_evil_distance(speaker, evil_seats, n)
			if sd >= 2:
				t.compare = Enums.Compare.GREATER
				t.number = 1 if sd == 2 else 1 + (rng.randi() % (sd - 1))  # 1..sd-1 → d>k DOĞRU
			else:
				t.compare = Enums.Compare.LESS
				t.number = 2  # d(=0/1) < 2 DOĞRU

		&"Tailor":
			# Kurtlar-ARASI yapı: en yakın iki kurdun çember mesafesi. Konuşanın
			# konumundan bağımsız, saf yerleşim kısıtı (Omen'in minyatürü).
			t.type = Enums.TestimonyType.WOLF_GAP
			t.number = _min_wolf_gap(evil_seats, n)

		&"Mirrorwright":
			# Karşı koltuk bilgisi: sabit hedef (speaker + n/2). Yalnız çift n'de havuzda.
			t.type = Enums.TestimonyType.OPPOSITE_ALIGNMENT
			var opp := (speaker + n / 2) % n
			t.targets = [opp]
			t.alignment = al[opp]

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
##
## İNANDIRICILIK KURALI (§7.3 adalet): yalan, HERKESİN bildiği gerçeklerle
## (n koltuk + ilan edilmiş kurt sayısı) çelişemez. "2 kurtlu köyde 3 kurt" ya da
## "5 koltukta 4 adım öte" gibi alenen imkânsız değerler yalancıyı bedavaya ele
## verirdi; tüm yanlış değerler kamusal-mümkün aralıktan seçilir.
static func _false_claim(bluff_role: StringName, speaker: int, world: Dictionary, n: int, rng: RandomNumberGenerator) -> TestimonyClaim:
	var al: Array = world["alignment"]
	var evil_seats: Array = world["evil_seats"]
	var e := evil_seats.size()
	var t := _true_claim(bluff_role, speaker, world, n, rng)

	match t.type:
		Enums.TestimonyType.ALIGNMENT_OF:
			t.alignment = Enums.Alignment.GOOD if t.alignment == Enums.Alignment.EVIL else Enums.Alignment.EVIL
		Enums.TestimonyType.COUNT_IN_SET:
			t.number = _other_count(t.number, mini(t.targets.size(), e), rng)
		Enums.TestimonyType.NEIGHBOR_HAS_EVIL:
			t.number = _other_count(t.number, mini(2, e), rng)
		Enums.TestimonyType.NEAREST_EVIL_DISTANCE:
			# Konuşan kurtsa "gerçek" mesafesi öteki kurda göredir (tek kurtta n
			# çıkar) — yanlış değer her durumda kamusal [1, maxd] aralığından gelir.
			t.number = _wrong_distance(t.number, _max_nearest_dist(n, e), rng)
		Enums.TestimonyType.NEAREST_EVIL_DIRECTION:
			# "Eşit mesafede" ancak 2+ kurtla ya da çift n'de mümkündür.
			t.direction = _other_direction(t.direction, e >= 2 or n % 2 == 0, rng)
		Enums.TestimonyType.EVIL_COUNT_IN_REGION:
			# İki yarıda eşit kurt, toplam kurt sayısı tekken (iyi konuşmacı için) imkânsız.
			t.compare = _other_compare(t.compare, e % 2 == 0, rng)
		Enums.TestimonyType.PAIR_RELATION:
			t.bool_val = not t.bool_val
		Enums.TestimonyType.COUNT_PARITY_IN_SET:
			t.bool_val = not t.bool_val
		Enums.TestimonyType.NEAREST_EVIL_MIN_DIST:
			# Eşitsizlik yalanı iki yönden kurulabilir; ikisi de hem YANLIŞ hem
			# kamusal sınırda kalmalı: "d>k" için d_true<=k<maxd (k'dan uzak
			# olmadığı kesin), "d<k" için 2<=k<=min(d_true, maxd). Seed'li seçim.
			var d_true := BoardTopology.nearest_evil_distance(speaker, evil_seats, n)
			var maxd := _max_nearest_dist(n, e)
			var opts: Array = []
			for kg in range(maxi(1, d_true), maxd):
				opts.append([Enums.Compare.GREATER, kg])
			for kl in range(2, mini(d_true, maxd) + 1):
				opts.append([Enums.Compare.LESS, kl])
			if not opts.is_empty():
				var pick: Array = opts[rng.randi() % opts.size()]
				t.compare = pick[0]
				t.number = pick[1]
		Enums.TestimonyType.WOLF_GAP:
			# e kurdun en yakın ikisi en fazla floor(n/e) adım açılabilir (güvercin yuvası).
			t.number = _wrong_distance(t.number, int(n / float(maxi(e, 1))), rng)
		Enums.TestimonyType.OPPOSITE_ALIGNMENT:
			t.alignment = Enums.Alignment.GOOD if t.alignment == Enums.Alignment.EVIL else Enums.Alignment.EVIL
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


## En yakın iki kurdun çember mesafesi (Terzi/WOLF_GAP).
static func _min_wolf_gap(evil_seats: Array, n: int) -> int:
	var best := n
	for i in range(evil_seats.size()):
		for j in range(i + 1, evil_seats.size()):
			best = mini(best, BoardTopology.distance(int(evil_seats[i]), int(evil_seats[j]), n))
	return best


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


## Kompozisyon herkese açıkken (e kurt, n koltuk) "en yakın kurda mesafe"nin
## alabileceği en büyük değer: kurtlar tek blok olsa bile kalan boşluğun
## ortasındaki koyunun mesafesi = floor((n-e+1)/2). İYİ bir konuşmacı için
## bundan büyüğü alenen imkânsızdır — yalan da bu sınırın içinde kalmalı.
static func _max_nearest_dist(n: int, e: int) -> int:
	return maxi(1, int((n - e + 1) / 2.0))


## true_val'dan farklı, [1, max_plaus] içinde bir "yanlış mesafe". max_plaus,
## kompozisyondan türeyen kamusal üst sınırdır (bkz. _false_claim inandırıcılık
## kuralı) — çemberin yarısından ya da kurt sayısının izin verdiğinden büyük
## sayı söyleyen yalan kendini ele verir.
static func _wrong_distance(true_val: int, max_plaus: int, rng: RandomNumberGenerator) -> int:
	var options: Array = []
	for k in range(1, max_plaus + 1):
		if k != true_val:
			options.append(k)
	if options.is_empty():
		return true_val + 1  # tek seçenek gerçeğin kendisi: evaluate-fallback devralır
	return options[rng.randi() % options.size()]


static func _other_direction(true_dir: int, allow_equidistant: bool, rng: RandomNumberGenerator) -> int:
	var options: Array = []
	for d in [Enums.Direction.CLOCKWISE, Enums.Direction.COUNTER_CLOCKWISE]:
		if d != true_dir:
			options.append(d)
	if allow_equidistant and true_dir != Enums.Direction.EQUIDISTANT:
		options.append(Enums.Direction.EQUIDISTANT)
	return options[rng.randi() % options.size()]


static func _other_compare(true_cmp: int, allow_equal: bool, rng: RandomNumberGenerator) -> int:
	var options: Array = []
	for c in [Enums.Compare.LESS, Enums.Compare.GREATER]:
		if c != true_cmp:
			options.append(c)
	if allow_equal and true_cmp != Enums.Compare.EQUAL:
		options.append(Enums.Compare.EQUAL)
	return options[rng.randi() % options.size()]


# --- yardımcılar ---

## Özel rolü (aktif yetenekli ya da V3 ziyaretçi) bir düz köylüye ata — başka bir
## özel rolün üstüne yazmaz (SPECIAL_ROLES tek doğruluk kaynağı).
static func _assign_active_role(chars: Array, n: int, role: StringName, rng: RandomNumberGenerator) -> void:
	var pool: Array = []
	for i in range(n):
		var c: Character = chars[i]
		if c.alignment == Enums.Alignment.GOOD and c.category == Enums.Category.VILLAGER \
				and not SPECIAL_ROLES.has(c.role):
			pool.append(i)
	if not pool.is_empty():
		chars[pool[rng.randi() % pool.size()]].role = role


## Konuşana göre sabit offset kümesi -> benzersiz seat listesi (kendisi hariç).
static func _ring_set(speaker: int, offsets: Array, n: int) -> Array:
	var out: Array = []
	for off in offsets:
		var s: int = ((speaker + int(off)) % n + n) % n
		if s != speaker and not (s in out):
			out.append(s)
	return out


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
