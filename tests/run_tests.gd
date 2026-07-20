extends Node

## Headless test runner (GUT bağımlılığı olmadan). Sahne olarak çalışır ki
## autoload'lar (EventBus/Rng/GameState) yüklensin.
## Çalıştırma:
##   godot --headless --path <proje> res://tests/test_runner.tscn
## Çıkış kodu: 0 = tüm testler geçti, 1 = en az bir test başarısız.
## Bkz. CLAUDE.md §0.5 (V2) ve §13.7.

var _pass := 0
var _fail := 0
var _section := ""


func _ready() -> void:
	print("=== NAZAR motor testleri (V2 Sorgu & Gece) ===")
	_test_topology()
	_test_testimony()
	_test_solver()
	_test_night_engine()
	_test_generator()
	_test_lie_plausibility()
	_test_budget()
	_test_features()
	_test_omen()
	_test_outcast()
	_test_slayer()
	_test_ascension()
	_test_gameflow()
	_test_run_manager()
	_test_save_manager()
	_test_board_smoke()
	print("\n=== SONUC: %d gecti, %d basarisiz ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _section_start(name: String) -> void:
	_section = name
	print("\n[%s]" % name)


func check(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL (%s): %s" % [_section, msg])


func eq(a, b, msg: String) -> void:
	check(a == b, "%s  (beklenen %s, gelen %s)" % [msg, str(b), str(a)])


## Test için: n kişilik köy, verilen seat'ler minion, gerisi Judge köylü.
func _make_state(n: int, evil_seats: Array) -> VillageState:
	var st := VillageState.new()
	st.n = n
	var chars: Array[Character] = []
	for i in range(n):
		var c := Character.new()
		c.seat = i
		if i in evil_seats:
			c.alignment = Enums.Alignment.EVIL
			c.category = Enums.Category.MINION
			c.role = &"Minion"
		else:
			c.alignment = Enums.Alignment.GOOD
			c.category = Enums.Category.VILLAGER
			c.role = &"Judge"
		chars.append(c)
	st.characters = chars
	st.evil_count = evil_seats.size()
	st.minion_count = evil_seats.size()
	st.demon_count = 0
	st.anchors = []
	st.marks = []
	for i in range(n):
		st.marks.append(Enums.MarkType.NONE)
	return st


## Tüm ifadeler verilmiş say (üretici teklik kontrolüyle aynı görünüm).
func _give_all(state: VillageState) -> void:
	for c in state.characters:
		c.given = c.claims.size()


func _give_none(state: VillageState) -> void:
	for c in state.characters:
		c.given = 0


# -------------------------------------------------------------------
func _test_topology() -> void:
	_section_start("BoardTopology")
	var n := 8
	eq(BoardTopology.left(0, n), 7, "left wrap")
	eq(BoardTopology.right(7, n), 0, "right wrap")
	eq(BoardTopology.distance(0, 4, n), 4, "opposite distance")
	eq(BoardTopology.distance(0, 5, n), 3, "distance short way")
	eq(BoardTopology.distance(7, 1, n), 2, "distance wrap")
	eq(BoardTopology.cw_distance(6, 1, n), 3, "cw wrap")
	eq(BoardTopology.ccw_distance(1, 6, n), 3, "ccw wrap")

	eq(BoardTopology.nearest_evil_direction(0, [2], n), Enums.Direction.CLOCKWISE, "evil ahead cw")
	eq(BoardTopology.nearest_evil_direction(0, [6], n), Enums.Direction.COUNTER_CLOCKWISE, "evil behind ccw")
	eq(BoardTopology.nearest_evil_direction(0, [4], n), Enums.Direction.EQUIDISTANT, "opposite equidistant")
	eq(BoardTopology.nearest_evil_direction(0, [2, 6], n), Enums.Direction.EQUIDISTANT, "two sides equidistant")
	eq(BoardTopology.nearest_evil_direction(0, [1, 6], n), Enums.Direction.CLOCKWISE, "nearer cw wins")

	eq(BoardTopology.nearest_evil_distance(0, [3, 5], n), 3, "nearest dist")
	eq(BoardTopology.arc(6, 3, n), [6, 7, 0], "arc wrap")


# -------------------------------------------------------------------
func _test_testimony() -> void:
	_section_start("TestimonyClaim.evaluate")
	# n=5, evil = {1,3}
	var al := [Enums.Alignment.GOOD, Enums.Alignment.EVIL, Enums.Alignment.GOOD, Enums.Alignment.EVIL, Enums.Alignment.GOOD]
	var world := {"n": 5, "alignment": al, "evil_seats": [1, 3]}

	var t1 := TestimonyClaim.new()
	t1.type = Enums.TestimonyType.ALIGNMENT_OF
	t1.targets = [1]
	t1.alignment = Enums.Alignment.EVIL
	check(t1.evaluate(world), "ALIGNMENT_OF true")
	t1.alignment = Enums.Alignment.GOOD
	check(not t1.evaluate(world), "ALIGNMENT_OF false")

	var t2 := TestimonyClaim.new()
	t2.type = Enums.TestimonyType.COUNT_IN_SET
	t2.targets = [0, 1]
	t2.number = 1
	check(t2.evaluate(world), "COUNT_IN_SET true")
	t2.number = 2
	check(not t2.evaluate(world), "COUNT_IN_SET false")

	var t3 := TestimonyClaim.new()
	t3.type = Enums.TestimonyType.NEIGHBOR_HAS_EVIL
	t3.speaker = 2  # komşular 1 ve 3, ikisi de Evil
	t3.number = 2
	check(t3.evaluate(world), "NEIGHBOR_HAS_EVIL true (2 evil neighbors)")

	var t4 := TestimonyClaim.new()
	t4.type = Enums.TestimonyType.NEAREST_EVIL_DISTANCE
	t4.speaker = 0  # en yakın evil #1, mesafe 1
	t4.number = 1
	check(t4.evaluate(world), "NEAREST_EVIL_DISTANCE true")

	var t5 := TestimonyClaim.new()
	t5.type = Enums.TestimonyType.PAIR_RELATION
	t5.targets = [1, 3]  # ikisi de evil -> aynı
	t5.bool_val = true
	check(t5.evaluate(world), "PAIR_RELATION same true")

	# --- Yeni matematik tipleri (Tespihçi/Ürkek/Terzi/Aynacı) ---
	var t6 := TestimonyClaim.new()
	t6.type = Enums.TestimonyType.COUNT_PARITY_IN_SET
	t6.targets = [0, 1, 2, 3]  # kurtlar {1,3} -> 2 kurt = ÇİFT
	t6.bool_val = true
	check(t6.evaluate(world), "PARITY çift true")
	t6.targets = [0, 1, 2]  # 1 kurt = TEK
	check(not t6.evaluate(world), "PARITY tek iken çift iddiası false")

	var t7 := TestimonyClaim.new()
	t7.type = Enums.TestimonyType.NEAREST_EVIL_MIN_DIST
	t7.speaker = 0  # en yakın kurt #1, d=1
	t7.compare = Enums.Compare.LESS
	t7.number = 2
	check(t7.evaluate(world), "MIN_DIST d=1 < 2 true")
	t7.compare = Enums.Compare.GREATER
	check(not t7.evaluate(world), "MIN_DIST d=1 > 2 false")

	var t8 := TestimonyClaim.new()
	t8.type = Enums.TestimonyType.WOLF_GAP
	t8.number = 2  # kurtlar 1 ve 3 -> arası 2
	check(t8.evaluate(world), "WOLF_GAP 2 true")
	t8.number = 1
	check(not t8.evaluate(world), "WOLF_GAP 1 false")

	var t9 := TestimonyClaim.new()
	t9.type = Enums.TestimonyType.OPPOSITE_ALIGNMENT
	t9.speaker = 0
	t9.alignment = Enums.Alignment.GOOD
	check(not t9.evaluate(world), "OPPOSITE tek n'de false (üretici kullanmaz)")
	var world6 := {"n": 6, "alignment": [
		Enums.Alignment.GOOD, Enums.Alignment.EVIL, Enums.Alignment.GOOD,
		Enums.Alignment.EVIL, Enums.Alignment.GOOD, Enums.Alignment.GOOD,
	], "evil_seats": [1, 3]}
	t9.alignment = Enums.Alignment.EVIL  # 0'ın karşısı 3 -> kurt
	check(t9.evaluate(world6), "OPPOSITE çift n'de kurt true")


# -------------------------------------------------------------------
func _test_solver() -> void:
	_section_start("DeductionSolver")

	# Elle kurulmuş köy: n=4, evil_count=1. Gerçek evil = #2.
	# #0 (Judge): "#2 Evil" (DOĞRU). #1 (Judge): "#3 temiz" (DOĞRU).
	var chars: Array = []
	for i in range(4):
		var c := Character.new()
		c.seat = i
		c.alignment = Enums.Alignment.GOOD
		chars.append(c)
	chars[2].alignment = Enums.Alignment.EVIL

	var vs := VillageState.new()
	vs.n = 4
	vs.evil_count = 1
	vs.characters.assign(chars)
	# Anchor #0 = kesin GOOD; simetriyi kırıp tek çözüm garantiler (§5.7).
	vs.anchors = [0]
	vs.marks = [0, 0, 0, 0]

	var claim0 := TestimonyClaim.new()
	claim0.type = Enums.TestimonyType.ALIGNMENT_OF
	claim0.speaker = 0
	claim0.targets = [2]
	claim0.alignment = Enums.Alignment.EVIL
	chars[0].claims = [claim0]
	chars[0].given = 1

	var claim1 := TestimonyClaim.new()
	claim1.type = Enums.TestimonyType.ALIGNMENT_OF
	claim1.speaker = 1
	claim1.targets = [3]
	claim1.alignment = Enums.Alignment.GOOD
	chars[1].claims = [claim1]
	chars[1].given = 1

	var sols := DeductionSolver.solve(vs.visible_for_solver())
	eq(sols.size(), 1, "hand village unique")
	if sols.size() == 1:
		eq(sols[0][2], Enums.Alignment.EVIL, "solver found #2 evil")
	check(DeductionSolver.is_determined(vs.visible_for_solver()), "is_determined true")
	eq(DeductionSolver.certain_evil(vs.visible_for_solver()), [2], "certain_evil = [2]")

	# Belirsiz köy: hiç ifade verilmedi, anchor [0] -> evil in {1,2,3} = 3 dünya.
	_give_none(vs)
	var ambig := DeductionSolver.solve(vs.visible_for_solver())
	eq(ambig.size(), 3, "no claims + anchor[0] -> 3 worlds")
	check(not DeductionSolver.is_determined(vs.visible_for_solver()), "ambiguous not determined")

	# Anchor'ı kaldır: evil_count=1 -> C(4,1)=4 dünya.
	vs.anchors = []
	eq(DeductionSolver.solve(vs.visible_for_solver()).size(), 4, "no anchor -> C(4,1)=4 worlds")

	# KESİN KİMLİK (known) pini: #1 gece öldü (kesin İYİ) -> 3 dünya kalır.
	var vis := vs.visible_for_solver()
	vis["known"] = [{"seat": 1, "alignment": Enums.Alignment.GOOD}]
	eq(DeductionSolver.solve(vis).size(), 3, "known-good pin dünyayı eler")
	# #2 ayıklandı ve KURT çıktı -> tek dünya.
	vis["known"] = [{"seat": 2, "alignment": Enums.Alignment.EVIL}]
	eq(DeductionSolver.solve(vis).size(), 1, "known-evil pin tekliğe indirir")


# -------------------------------------------------------------------
func _test_night_engine() -> void:
	_section_start("NightEngine (gece avı)")

	# Av Düzeni: en yakın canlı koyun; eşitlikte küçük seat.
	var al7: Array = []
	for i in range(7):
		al7.append(Enums.Alignment.GOOD)
	al7[3] = Enums.Alignment.EVIL
	var alive_all := [0, 1, 2, 3, 4, 5, 6]
	eq(NightEngine.pick_victim(al7, alive_all, 7), 2, "kurban: komşu koyunlardan küçük seat (#2)")

	# #2 öldüyse: kalan en yakın #4 (d=1).
	eq(NightEngine.pick_victim(al7, [0, 1, 3, 4, 5, 6], 7), 4, "sonraki kurban #4")

	# Kurt yoksa av yok.
	var al_good: Array = []
	for i in range(5):
		al_good.append(Enums.Alignment.GOOD)
	eq(NightEngine.pick_victim(al_good, [0, 1, 2, 3, 4], 5), -1, "kurt yoksa av yok")

	# apply: kurban ölür, gerçek yüz açılır, olay kaydedilir.
	var st := _make_state(7, [3])
	var v := NightEngine.apply(st)
	eq(v, 2, "apply kurbanı seçti (#2)")
	check(st.get_character(2).night_killed, "kurban night_killed")
	check(st.get_character(2).revealed, "kurbanın gerçek yüzü açık")
	eq(st.night_events.size(), 1, "gece olayı kaydedildi")
	eq(st.alive_good_count(), 5, "canlı koyun 6->5")

	# CESETLER YALAN SÖYLEMEZ: gece olayı, yanlış kurt konumlarını eler.
	# Gerçek dünya (evil={3}) tutarlı; evil={6} olsaydı kurban #0 olurdu -> tutarsız.
	var al_wrong: Array = []
	for i in range(7):
		al_wrong.append(Enums.Alignment.GOOD)
	al_wrong[6] = Enums.Alignment.EVIL
	check(NightEngine.consistent_with_nights(al7, st.night_events, 7), "gerçek dünya gece ile tutarlı")
	check(not NightEngine.consistent_with_nights(al_wrong, st.night_events, 7), "yanlış dünya gece ile TUTARSIZ (nirengi)")

	# Solver'a gece kısıtı: ifadesiz köyde bile cesetler dünyaları daraltır.
	var vis := st.visible_for_solver()
	var worlds := DeductionSolver.solve(vis)
	var all_consistent := true
	for w in worlds:
		if not NightEngine.consistent_with_nights(w, st.night_events, 7):
			all_consistent = false
	check(all_consistent, "solver yalnız gece-tutarlı dünyaları döndürür")
	check(worlds.size() < 6, "gece kısıtı dünya sayısını düşürdü (%d<6)" % worlds.size())

	# --- AĞIL (koruma): korunan kart av havuzundan çıkar; sonraki en yakın ölür ---
	eq(NightEngine.pick_victim(al7, alive_all, 7, 2), 4, "korunan #2 atlanır, kurban #4")
	var stp := _make_state(7, [3])
	var vp := NightEngine.apply(stp, 2)
	eq(vp, 4, "apply koruma ile #4'ü seçti")
	eq(int(stp.night_events[0]["protected"]), 2, "koruma gece olayına kaydedildi")
	# Koruma kaydı solver tutarlılığını korur: gerçek dünya hâlâ tutarlı.
	check(NightEngine.consistent_with_nights(al7, stp.night_events, 7), "korumalı olay gerçek dünyayla tutarlı")
	# GameState.end_day(protected): korunan sağ kalır.
	var stg := _make_state(7, [3])
	GameState.start_village(stg)
	GameState.end_day(2)
	check(stg.get_character(2).is_alive(), "ağıla alınan #2 geceyi sağ atlattı")
	check(stg.get_character(4).night_killed, "kurt bir sonraki en yakını (#4) aldı")

	# --- SİSLİ GECE (FARTHEST): kurt en UZAK koyunu avlar ---
	var alf: Array = []
	for i in range(7):
		alf.append(Enums.Alignment.GOOD)
	alf[0] = Enums.Alignment.EVIL
	var alive7 := [0, 1, 2, 3, 4, 5, 6]
	eq(NightEngine.pick_victim(alf, alive7, 7, -1, Enums.NightRule.NEAREST), 1, "yakın av: #1")
	eq(NightEngine.pick_victim(alf, alive7, 7, -1, Enums.NightRule.FARTHEST), 3, "sisli av: en uzak #3")
	var stf := _make_state(7, [0])
	stf.night_rule = Enums.NightRule.FARTHEST
	NightEngine.apply(stf)
	check(stf.get_character(3).night_killed, "apply sisli kuralla #3'ü aldı")
	check(NightEngine.consistent_with_nights(
		alf, stf.night_events, 7), "sisli olay gerçek dünyayla tutarlı")

	# --- TUZAK: av kapana denk gelirse kurban ölmez, saldıran kurt yakalanır ---
	var ts := _make_state(5, [2])
	ts.trap_seat = 1  # kurt #2'ye en yakın koyun #1 (eşitlikte küçük seat)
	eq(NightEngine.apply(ts), -2, "tuzak tetiklendi (-2)")
	check(ts.get_character(2).revealed, "yakalanan kurt (#2) açıldı")
	check(ts.get_character(1).is_alive(), "kapandaki koyun (#1) sağ")
	eq(ts.trap_seat, -1, "kapan geceyle tüketildi")
	var tev: Dictionary = ts.night_events.back()
	eq(int(tev.get("caught", -1)), 2, "saldıran kurt olaya kaydedildi")
	var al5: Array = []
	for c in ts.characters:
		al5.append(c.alignment)
	check(NightEngine.consistent_with_nights(al5, ts.night_events, 5), "tuzak olayı gerçekle tutarlı")
	var bad5: Array = al5.duplicate()
	bad5[2] = Enums.Alignment.GOOD
	bad5[4] = Enums.Alignment.EVIL
	check(not NightEngine.consistent_with_nights(bad5, ts.night_events, 5), "tuzak kaydı yanlış dünyayı eler")

	# --- arm_trap akışı + Uğursuz sorgu bedeli ---
	var tg := _make_state(5, [2])
	tg.get_character(0).role = &"Trapper"
	GameState.start_village(tg)
	GameState.arm_trap(0, 1)
	eq(tg.trap_seat, 1, "arm_trap kapanı kurdu")
	check(tg.get_character(0).ability_used, "Tuzakçı yeteneği harcandı")
	var jg := _make_state(5, [2])
	jg.get_character(3).role = &"Jinxed"
	jg.get_character(3).category = Enums.Category.OUTCAST
	var jclaim := TestimonyClaim.new()
	jclaim.type = Enums.TestimonyType.SELF_ANCHOR
	jclaim.speaker = 3
	jclaim.text = "nazar testi"
	jg.get_character(3).claims = [jclaim]
	GameState.start_village(jg)
	var hp0 := GameState.health
	GameState.question(3)
	eq(GameState.health, hp0 - 1, "Uğursuz sorgusu -1 can")
	GameState.village = null


# -------------------------------------------------------------------
func _test_generator() -> void:
	_section_start("VillageGenerator (V2 çoklu ifade)")
	var rng := RandomNumberGenerator.new()

	var configs := [
		{"n": 7, "evil_count": 2, "demon_count": 1, "anchor_count": 1},
		{"n": 9, "evil_count": 2, "demon_count": 1, "anchor_count": 1},
		{"n": 5, "evil_count": 1, "demon_count": 1, "anchor_count": 1},
	]

	var total := 0
	var determined := 0
	var null_count := 0
	var claims_ok := true
	for cfg in configs:
		for s in range(1, 81):
			rng.seed = s * 7919 + int(cfg["n"]) * 31
			var conf: Dictionary = cfg.duplicate()
			conf["seed"] = int(rng.seed)
			var state := VillageGenerator.generate(conf, rng)
			total += 1
			if state == null:
				null_count += 1
				continue
			# Üretici tüm-ifadeler-verilmiş teklik garantiler; tekrar doğrula.
			_give_all(state)
			if DeductionSolver.is_determined(state.visible_for_solver()):
				determined += 1
			_give_none(state)
			var gt := state.ground_truth_world()
			for c in state.characters:
				if c.claims.size() < 1:
					claims_ok = false
				if c.is_evil():
					# §0.5: kurt HER ifadesinde yalan söyler.
					for cl in c.claims:
						if cl.evaluate(gt):
							claims_ok = false
					# İlk ifade bluff rolünün tipinde olmalı (§5.3).
					check(c.claims[0].type == _expected_claim_type(c.bluff_role),
						"kurt ilk ifadesi bluff tipinde (rol=%s)" % c.bluff_role)
				elif c.category == Enums.Category.VILLAGER and not (c.role in [&"Slayer", &"Hunter", &"Astrologer"]):
					# Düz köylü: HER ifadesi doğru.
					for cl in c.claims:
						if cl.type != Enums.TestimonyType.SELF_ANCHOR and not cl.evaluate(gt):
							claims_ok = false

	print("  üretilen: %d, tek-çözümlü: %d, null: %d" % [total, determined, null_count])
	eq(null_count, 0, "hiç null üretim yok")
	eq(determined, total - null_count, "TÜM köyler tek-çözümlü (adalet garantisi)")
	check(claims_ok, "ifade doğruluk kuralları (kurt hep yalan, koyun hep doğru)")

	# Determinizm: aynı seed -> aynı köy.
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 424242
	var va := VillageGenerator.generate({"n": 7, "evil_count": 2, "demon_count": 1, "seed": 424242}, rng_a)
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 424242
	var vb := VillageGenerator.generate({"n": 7, "evil_count": 2, "demon_count": 1, "seed": 424242}, rng_b)
	var same := true
	if va == null or vb == null:
		same = false
	else:
		for i in range(va.n):
			if va.characters[i].alignment != vb.characters[i].alignment:
				same = false
			if va.characters[i].role != vb.characters[i].role:
				same = false
	check(same, "aynı seed -> aynı köy (determinizm)")


# -------------------------------------------------------------------
## İnandırıcılık (§7.3): HİÇBİR ifade — yalan bile — herkesin bildiği gerçeklerle
## (n koltuk + ilan edilmiş kurt sayısı) çelişemez. "2 kurtlu köyde 3 kurt gördüm"
## veya "5 koltukta 4 adım öte" gibi alenen imkânsız değerler yalancıyı bedavaya
## ele verir. Bkz. VillageGenerator._false_claim inandırıcılık kuralı.
func _test_lie_plausibility() -> void:
	_section_start("Yalan inandırıcılığı (kamusal bilgiyle çelişki yok)")
	var rng := RandomNumberGenerator.new()
	var configs := [
		{"n": 5, "evil_count": 1, "demon_count": 1, "anchor_count": 1},   # tek kurt (İzci/Bekçi bug'ları)
		{"n": 7, "evil_count": 2, "demon_count": 1, "anchor_count": 1},
		{"n": 10, "evil_count": 3, "demon_count": 1, "anchor_count": 2},  # tek sayıda kurt + çift n (Mimar/Aynacı)
	]
	var checked := 0
	var bad := 0
	var bad_msg := ""
	for cfg in configs:
		for s in range(1, 26):
			rng.seed = s * 4241 + int(cfg["n"]) * 977
			var conf: Dictionary = cfg.duplicate()
			conf["seed"] = int(rng.seed)
			var state := VillageGenerator.generate(conf, rng)
			if state == null:
				continue
			var e: int = state.evil_count
			for c in state.characters:
				for cl in c.claims:
					checked += 1
					if not _claim_plausible(cl, state.n, e):
						bad += 1
						if bad_msg == "":
							bad_msg = "seat=%d rol=%s tip=%d num=%d" % [c.seat, c.role, cl.type, cl.number]
	print("  denetlenen ifade: %d" % checked)
	check(checked > 300, "yeterli ifade örneklendi (%d)" % checked)
	eq(bad, 0, "alenen imkânsız ifade yok (ilk ihlal: %s)" % bad_msg)


## Bir ifadenin yalnız KAMUSAL bilgiyle (n, kurt sayısı e; konuşan İYİ varsayımıyla)
## mümkün olup olmadığı. Üretici tüm ifadeleri bu süzgeçten geçirmiş olmalı.
func _claim_plausible(cl: TestimonyClaim, n: int, e: int) -> bool:
	var maxd := VillageGenerator._max_nearest_dist(n, e)
	match cl.type:
		Enums.TestimonyType.COUNT_IN_SET:
			return cl.number >= 0 and cl.number <= mini(cl.targets.size(), e)
		Enums.TestimonyType.COUNT_PARITY_IN_SET:
			return true
		Enums.TestimonyType.NEIGHBOR_HAS_EVIL:
			return cl.number >= 0 and cl.number <= mini(2, e)
		Enums.TestimonyType.NEAREST_EVIL_DISTANCE:
			return cl.number >= 1 and cl.number <= maxd
		Enums.TestimonyType.NEAREST_EVIL_MIN_DIST:
			if cl.compare == Enums.Compare.GREATER:
				return cl.number >= 1 and cl.number < maxd  # "d>k": k=maxd olsa hiç kimse sağlayamaz
			return cl.number >= 2 and cl.number <= maxd     # "d<k": k<2 hiç, k>maxd boş laf
		Enums.TestimonyType.WOLF_GAP:
			return cl.number >= 1 and cl.number <= int(n / float(maxi(e, 1)))
		Enums.TestimonyType.NEAREST_EVIL_DIRECTION:
			if cl.direction == Enums.Direction.EQUIDISTANT:
				return e >= 2 or n % 2 == 0
			return true
		Enums.TestimonyType.EVIL_COUNT_IN_REGION:
			if cl.compare == Enums.Compare.EQUAL:
				return e % 2 == 0
			return true
		_:
			return true


# -------------------------------------------------------------------
func _test_budget() -> void:
	_section_start("Bütçe garantisi (bot: sorgu + gece içinde çözülebilir)")
	# Üretilen her köy, botun sorgu bütçesi + gün sınırı içinde çözebildiği köydür.
	var rng := RandomNumberGenerator.new()
	var n_ok := 0
	var total := 0
	for s in range(30):
		rng.seed = 31000 + s
		var conf := {"n": 7, "evil_count": 2, "demon_count": 1, "anchor_count": 1,
			"q_per_day": 3, "max_days": 5, "seed": rng.seed}
		var st: VillageState = VillageGenerator.generate(conf, rng)
		if st == null:
			continue
		total += 1
		if VillageGenerator._budget_solvable(st):
			n_ok += 1
	check(total >= 28, "bütçe köyleri üretildi (%d/30)" % total)
	eq(n_ok, total, "üretilen her köy bot-bütçesinde çözülebilir")

	# Sıkı bütçe (q=2, 3 gün, çifte av) da üretilebilmeli (boss benzeri).
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 32000
	var tight := VillageGenerator.generate({"n": 9, "evil_count": 2, "demon_count": 1,
		"anchor_count": 2, "q_per_day": 4, "max_days": 5, "kills_per_night": 2, "seed": 32000}, rng2)
	check(tight != null, "çifte-av (boss) köyü üretilebildi")
	if tight != null:
		eq(tight.kills_per_night, 2, "kills_per_night state'e işledi")


# -------------------------------------------------------------------
## Yeni içerik kolları: modifier'lar (Suskun/Kuraklık/Kanlı Ay), sefer destesi
## (role_pool + draft), Sonsuz Sürü spec'leri, lanetli muskalar.
func _test_features() -> void:
	_section_start("Modifier + deste + endless + lanetli muska")
	var rng := RandomNumberGenerator.new()

	# SUSKUN SÜRÜ: herkes tek ifade — yine de tek-çözümlü + bot-bütçe garantili.
	var silent_ok := 0
	for s in range(12):
		rng.seed = 71000 + s
		var st: VillageState = VillageGenerator.generate({"n": 7, "evil_count": 2, "demon_count": 1,
			"anchor_count": 2, "modifiers": ["silent"], "q_per_day": 3, "max_days": 5, "seed": rng.seed}, rng)
		if st == null:
			continue
		var all_one := true
		for c in st.characters:
			if c.claims.size() > 1:
				all_one = false
		if all_one and st.modifiers.has("silent"):
			silent_ok += 1
	check(silent_ok >= 10, "Suskun Sürü köyleri üretildi + herkes tek ifadeli (%d/12)" % silent_ok)

	# KURAKLIK: cull_damage köye işler, yanlış avlama −7.
	rng.seed = 72000
	var dst: VillageState = VillageGenerator.generate({"n": 7, "evil_count": 2, "demon_count": 1,
		"cull_damage": 7, "modifiers": ["drought"], "seed": 72000}, rng)
	check(dst != null, "Kuraklık köyü üretildi")
	if dst != null:
		eq(dst.cull_damage, 7, "cull_damage state'e işledi")
		GameState.start_village(dst)
		var good := -1
		for c in dst.characters:
			if not c.is_evil():
				good = c.seat
				break
		GameState.execute(good)
		eq(GameState.health, 3, "Kuraklıkta yanlış avlama −7 can")
		GameState.village = null

	# SEFER DESTESİ: role_pool verilince koyun rolleri yalnız havuzdan gelir.
	rng.seed = 73000
	var pool := [&"Judge", &"Oracle", &"Knight", &"Scout", &"Enlightened", &"Gossip"]
	var pst: VillageState = VillageGenerator.generate({"n": 7, "evil_count": 2, "demon_count": 1,
		"role_pool": pool, "seed": 73000}, rng)
	check(pst != null, "deste köyü üretildi")
	if pst != null:
		var pool_ok := true
		for c in pst.characters:
			if c.is_evil():
				if not pool.has(c.bluff_role):
					pool_ok = false
			elif c.category == Enums.Category.VILLAGER \
					and not (c.role in [&"Astrologer", &"Slayer", &"Hunter", &"Trapper"]):
				if not pool.has(c.role):
					pool_ok = false
		check(pool_ok, "tüm koyun rolleri + bluff'lar desteden geldi")

	# GEÇ OYUN + DESTE: en büyük köy (n=12) başlangıç destesiyle de üretilebilmeli
	# (canlıda draft yapılmadan Kara Orman'a gelinebilir).
	rng.seed = 73500
	var late_cfg := {"n": 12, "evil_count": 3, "demon_count": 1, "anchor_count": 2,
		"omen_type": Enums.OmenType.DISPERSED, "trapper": true, "kills_per_night": 2,
		"q_per_day": 4, "max_days": 6, "role_pool": RunManager.STARTER_POOL.duplicate(), "seed": 73500}
	check(VillageGenerator.generate(late_cfg, rng) != null, "n=12 köy başlangıç destesiyle üretilebilir")

	# SONSUZ SÜRÜ: ilk 6 endless spec'i üretilebilir (bot-bütçe garantili) olmalı.
	RunManager.run_seed = 74000
	RunManager.ascension = 0
	var e_fails: Array = []
	for k in range(6):
		var node: Dictionary = RunManager._endless_node(k)
		var cfg: Dictionary = node["config"]
		var erng := RandomNumberGenerator.new()
		erng.seed = int(cfg["seed"])
		if VillageGenerator.generate(cfg, erng) == null:
			e_fails.append(k)
	check(e_fails.is_empty(), "endless köyleri üretilebilir (kırık: %s)" % str(e_fails))

	# DRAFT: seçenekler deterministik, uygula → deste büyür.
	RunManager.start_run(0, 424001)
	var ch1 := RunManager.draft_choices()
	var ch2 := RunManager.draft_choices()
	eq(ch1, ch2, "draft adayları deterministik (aynı seed→aynı liste)")
	check(ch1.size() == 3, "3 draft adayı sunuldu")
	var before: int = RunManager.role_pool.size()
	RunManager.apply_draft(ch1[0])
	eq(RunManager.role_pool.size(), before + 1, "draft rolü desteye eklendi")
	check(not RunManager.pending_draft, "draft tüketildi")
	RunManager.active = false

	# LANETLİ MUSKALAR: Kanlı Tılsım (+1 sorgu, −2 maks can), Kara Kese (−1 canla başla).
	RunManager.start_run(0, 424002)
	RunManager.owned_passives = [&"kanli", &"karakese"]
	var cst := _make_state(5, [2])
	var base_q2: int = cst.q_per_day
	GameState.start_village(cst)
	eq(GameState.max_health(), 8, "Kanlı Tılsım: maks can 10→8")
	eq(cst.q_per_day, base_q2 + 1, "Kanlı Tılsım: +1 sorgu/gün")
	eq(GameState.health, 7, "Kara Kese: köye 1 can eksik başlandı (8−1)")
	RunManager.owned_passives.clear()
	RunManager.active = false
	GameState.village = null

	# EKONOMİ: köy içi sorgu satın alma (tırmanan fiyat) + azık + dükkân reroll'u.
	RunManager.start_run(0, 424003)
	RunManager.coins = 100
	var est := _make_state(5, [2])
	GameState.start_village(est)
	eq(GameState.question_price(), 25, "ilk sorgu fiyatı 25")
	check(GameState.buy_question(), "sorgu satın alındı")
	eq(est.questions_left, 4, "sorgu hakkı 3→4")
	eq(RunManager.coins, 75, "para düştü (100−25)")
	eq(GameState.question_price(), 40, "fiyat tırmandı 25→40")
	check(GameState.buy_question(), "ikinci sorgu alındı")
	eq(RunManager.coins, 35, "para 75−40=35")
	check(not GameState.buy_question(), "para yetmeyince satılmaz (55 gerek)")
	# Azık: para düşer, pending_boons'a girer; SONRAKİ köy başında işler.
	RunManager.coins = 100
	check(RunManager.buy_boon(&"extra_q"), "azık alındı")
	eq(RunManager.coins, 70, "azık parası düştü (30)")
	check(RunManager.pending_boons.has(&"extra_q"), "azık beklemede")
	var est2 := _make_state(5, [2])
	var eq0: int = est2.q_per_day
	GameState.start_village(est2)
	eq(est2.q_per_day, eq0 + 1, "azık sonraki köyde işledi (+1 sorgu/gün)")
	check(RunManager.pending_boons.is_empty(), "azık tüketildi (tek köylük)")
	# Reroll: salt deterministik ve farklı karışım verir.
	var r0 := RunManager.roll_shop(0)
	var r1 := RunManager.roll_shop(1)
	eq(RunManager.roll_shop(1), r1, "reroll deterministik (aynı salt → aynı teklif)")
	check(r0 != r1, "reroll farklı teklif üretir")
	RunManager.active = false
	GameState.village = null


# -------------------------------------------------------------------
func _test_omen() -> void:
	_section_start("Omen (gizli kural)")

	var n := 9
	check(Omen.satisfies(Enums.OmenType.PARITY, {}, [1, 3, 5], n), "PARITY hepsi tek")
	check(not Omen.satisfies(Enums.OmenType.PARITY, {}, [1, 2], n), "PARITY karışık -> yanlış")
	check(Omen.satisfies(Enums.OmenType.CONTIGUOUS_ARC, {}, [3, 4, 5], n), "ARC bitişik")
	check(Omen.satisfies(Enums.OmenType.CONTIGUOUS_ARC, {}, [8, 0, 1], n), "ARC wrap bitişik")
	check(not Omen.satisfies(Enums.OmenType.CONTIGUOUS_ARC, {}, [0, 2, 4], n), "ARC dağınık -> yanlış")
	# Yeni omenler: Mühür Terazisi (eşit uzaklık) + Tek Yaka.
	check(Omen.satisfies(Enums.OmenType.SEAL_EQUIDISTANT, {}, [2, 7], n), "TERAZİ 2,7 -> d=2,2")
	check(not Omen.satisfies(Enums.OmenType.SEAL_EQUIDISTANT, {}, [1, 3], n), "TERAZİ d=1,3 -> yanlış")
	check(Omen.satisfies(Enums.OmenType.SAME_SIDE, {}, [1, 4], n), "TEK YAKA sağ")
	check(Omen.satisfies(Enums.OmenType.SAME_SIDE, {}, [5, 8], n), "TEK YAKA sol")
	check(not Omen.satisfies(Enums.OmenType.SAME_SIDE, {}, [1, 5], n), "iki yaka -> yanlış")
	check(not Omen.satisfies(Enums.OmenType.SAME_SIDE, {}, [0, 3], n), "mühürde kurt -> yanlış")
	check(Omen.satisfies(Enums.OmenType.DISPERSED, {}, [0, 2, 4], n), "DISPERSED komşusuz")
	check(not Omen.satisfies(Enums.OmenType.DISPERSED, {}, [0, 1], n), "DISPERSED komşu -> yanlış")
	check(Omen.satisfies(Enums.OmenType.MIRROR, {}, [1, 3], 8), "MIRROR simetrik (eksen 2)")

	for otype in [Enums.OmenType.PARITY, Enums.OmenType.CONTIGUOUS_ARC, Enums.OmenType.DISPERSED, Enums.OmenType.MIRROR, Enums.OmenType.SEAL_EQUIDISTANT, Enums.OmenType.SAME_SIDE]:
		var placements := Omen.valid_placements(otype, {}, n, 2)
		check(placements.size() > 0, "valid_placements boş değil (tip %d)" % otype)
		var all_ok := true
		for combo in placements:
			if not Omen.satisfies(otype, {}, combo, n):
				all_ok = false
				break
		check(all_ok, "valid_placements hepsi sağlıyor (tip %d)" % otype)

	# Üretici: Omen'li köyler tek-çözümlü VE gerçekten Omen'i sağlıyor mu?
	var rng := RandomNumberGenerator.new()
	var checked := 0
	var determined_ok := 0
	var omen_ok := 0
	var has_astro := 0
	for otype in [Enums.OmenType.PARITY, Enums.OmenType.CONTIGUOUS_ARC, Enums.OmenType.DISPERSED, Enums.OmenType.MIRROR, Enums.OmenType.SEAL_EQUIDISTANT, Enums.OmenType.SAME_SIDE]:
		for s in range(40):
			rng.seed = 4200 + otype * 1000 + s
			var conf := {"n": 9, "evil_count": 2, "demon_count": 1, "anchor_count": 2, "omen_type": otype, "seed": rng.seed}
			var state: VillageState = VillageGenerator.generate(conf, rng)
			if state == null:
				continue
			checked += 1
			var gt: Array = []
			var astro := false
			for c in state.characters:
				if c.is_evil():
					gt.append(c.seat)
				if c.role == &"Astrologer":
					astro = true
			if astro:
				has_astro += 1
			if Omen.satisfies(otype, {}, gt, 9):
				omen_ok += 1
			# Müneccim ifşa edilmiş varsay -> tüm ifadelerle tek çözüm.
			state.known_omen = otype
			_give_all(state)
			if DeductionSolver.is_determined(state.visible_for_solver()):
				determined_ok += 1
			_give_none(state)
			state.known_omen = Enums.OmenType.NONE
	check(checked > 0, "Omen köyleri üretildi (%d)" % checked)
	eq(omen_ok, checked, "üretilen her Omen köyü kuralı sağlıyor")
	eq(determined_ok, checked, "üretilen her Omen köyü (Müneccim ifşa edilince) tek-çözümlü")
	eq(has_astro, checked, "her Omen köyünde Müneccim var")
	print("  omen: uretilen %d, kural-ok %d, tek-cozum %d" % [checked, omen_ok, determined_ok])


# -------------------------------------------------------------------
func _test_outcast() -> void:
	_section_start("Outcast (Ermiş/Saint + Sarhoş)")

	var rng := RandomNumberGenerator.new()
	var checked := 0
	var saint_ok := 0
	var determined_ok := 0
	for s in range(40):
		rng.seed = 7700 + s
		var conf := {"n": 7, "evil_count": 2, "demon_count": 1, "anchor_count": 1, "outcast_count": 1, "seed": rng.seed}
		var state: VillageState = VillageGenerator.generate(conf, rng)
		if state == null:
			continue
		checked += 1
		var saints := 0
		var saint_good := true
		for c in state.characters:
			if c.role == &"Saint":
				saints += 1
				if c.is_evil() or c.category != Enums.Category.OUTCAST:
					saint_good = false
		if saints == 1 and saint_good and state.outcast_count == 1:
			saint_ok += 1
		_give_all(state)
		if DeductionSolver.is_determined(state.visible_for_solver()):
			determined_ok += 1
		_give_none(state)
	check(checked >= 30, "outcast köyleri üretildi (%d/40)" % checked)
	eq(saint_ok, checked, "her köyde 1 iyi Ermiş (parya, ilan edilmiş)")
	eq(determined_ok, checked, "outcast köyleri tek-çözümlü")

	# --- Sarhoş (Drunk) solver gevşetmesi ---
	var claim := TestimonyClaim.new()
	claim.type = Enums.TestimonyType.ALIGNMENT_OF
	claim.speaker = 1
	claim.targets = [2]
	claim.alignment = Enums.Alignment.EVIL
	var vis := {"n": 3, "evil_count": 1, "anchors": [], "revealed": [{"seat": 1, "testimony": claim}], "drunk_count": 0}
	eq(DeductionSolver.solve(vis).size(), 2, "drunk=0 -> 2 dünya")
	vis["drunk_count"] = 1
	eq(DeductionSolver.solve(vis).size(), 3, "drunk=1 -> yanlış-iyi=sarhoş, 3 dünya")
	vis["anchors"] = [1]
	eq(DeductionSolver.solve(vis).size(), 1, "anchor sarhoş olamaz -> 1 dünya")

	# --- Sarhoş üretimi: 1 gizli sarhoş (köylü rolünde), tek-çözümlü ---
	var d_checked := 0
	var d_ok := 0
	var d_det := 0
	for s in range(40):
		rng.seed = 8800 + s
		var conf := {"n": 7, "evil_count": 2, "demon_count": 1, "anchor_count": 1, "drunk_count": 1, "seed": rng.seed}
		var st: VillageState = VillageGenerator.generate(conf, rng)
		if st == null:
			continue
		d_checked += 1
		var drunks := 0
		for c in st.characters:
			if c.category == Enums.Category.OUTCAST and c.role != &"Saint":
				drunks += 1
		if drunks == 1 and st.drunk_count == 1:
			d_ok += 1
		_give_all(st)
		if DeductionSolver.is_determined(st.visible_for_solver()):
			d_det += 1
		_give_none(st)
	check(d_checked >= 25, "sarhoş köyleri üretildi (%d/40)" % d_checked)
	eq(d_ok, d_checked, "her köyde 1 gizli sarhoş (köylü rolünde parya)")
	eq(d_det, d_checked, "sarhoş köyleri tek-çözümlü")

	# Ermiş'i ayıklamak ANINDA kaybettirir (§6).
	var vs := _make_state(5, [3])
	vs.get_character(1).role = &"Saint"
	vs.get_character(1).category = Enums.Category.OUTCAST
	GameState.start_village(vs)
	GameState.execute(1)
	eq(GameState.phase, Enums.GamePhase.VILLAGE_END, "Ermiş ayıklanınca köy biter")
	check(not GameState.is_active(), "Ermiş sonrası oyun pasif")


# -------------------------------------------------------------------
func _test_slayer() -> void:
	_section_start("Kılıççı (Slayer) + Avcı (Hunter)")

	# Elle köy: seat 0 Kılıççı, seat 2 Alfa, gerisi köylü.
	var vs := VillageState.new()
	vs.n = 4
	var chars: Array[Character] = []
	for i in range(4):
		var c := Character.new()
		c.seat = i
		c.alignment = Enums.Alignment.GOOD
		c.category = Enums.Category.VILLAGER
		chars.append(c)
	chars[0].role = &"Slayer"
	chars[2].role = &"Demon"
	chars[2].alignment = Enums.Alignment.EVIL
	chars[2].category = Enums.Category.DEMON
	vs.characters = chars
	vs.evil_count = 1
	vs.demon_count = 1
	vs.marks = [0, 0, 0, 0]
	GameState.start_village(vs)

	GameState.slay(0, 1)  # ıska
	check(chars[0].ability_used, "kılıç kullanıldı (tek sefer)")
	check(not chars[2].executed, "yanlış hedef -> Alfa yaşıyor")

	chars[0].ability_used = false
	GameState.slay(0, 2)  # isabet
	check(chars[2].executed, "kılıç Alfa Kurt'u öldürdü")
	eq(GameState.phase, Enums.GamePhase.VILLAGE_END, "Alfa ölünce köy biter (tek evil)")

	# --- Avcı: her kurdu vurur; koyun vurursan -3 can ---
	var vh := VillageState.new()
	vh.n = 4
	var ch: Array[Character] = []
	for i in range(4):
		var cc := Character.new()
		cc.seat = i
		cc.alignment = Enums.Alignment.GOOD
		cc.category = Enums.Category.VILLAGER
		ch.append(cc)
	ch[0].role = &"Hunter"
	ch[2].role = &"Minion"
	ch[2].alignment = Enums.Alignment.EVIL
	ch[2].category = Enums.Category.MINION
	ch[3].role = &"Demon"
	ch[3].alignment = Enums.Alignment.EVIL
	ch[3].category = Enums.Category.DEMON
	vh.characters = ch
	vh.evil_count = 2
	vh.demon_count = 1
	vh.minion_count = 1
	vh.marks = [0, 0, 0, 0]
	GameState.start_village(vh)
	GameState.hunt(0, 2)  # Kurt (minion)
	check(ch[2].executed, "Avcı kurdu vurdu (öldü)")
	check(ch[0].ability_used, "Avcı yeteneği kullanıldı (tek sefer)")
	ch[0].ability_used = false
	var hp_before := GameState.health
	GameState.hunt(0, 1)  # koyun
	eq(GameState.health, hp_before - 3, "koyun vurunca -3 can")

	# Üretici: slayer'lı köyler — 1 Kılıççı, tek-çözümlü.
	var rng := RandomNumberGenerator.new()
	var sc := 0
	var s_ok := 0
	var s_det := 0
	for s in range(30):
		rng.seed = 9900 + s
		var conf := {"n": 7, "evil_count": 2, "demon_count": 1, "anchor_count": 1, "slayer": true, "seed": rng.seed}
		var st: VillageState = VillageGenerator.generate(conf, rng)
		if st == null:
			continue
		sc += 1
		var slayers := 0
		for c in st.characters:
			if c.role == &"Slayer":
				slayers += 1
		if slayers == 1:
			s_ok += 1
		_give_all(st)
		if DeductionSolver.is_determined(st.visible_for_solver()):
			s_det += 1
		_give_none(st)
	check(sc >= 22, "slayer köyleri üretildi (%d/30)" % sc)
	eq(s_ok, sc, "her köyde 1 Kılıççı")
	eq(s_det, sc, "slayer köyleri tek-çözümlü")


# -------------------------------------------------------------------
func _test_ascension() -> void:
	_section_start("Ascension kapsama (tüm düğümler üretilebilir mi)")

	var fails: Array = []
	var tried := 0
	for asc in range(7):
		var nodes: Array = RunManager._build_map(asc, 55555)
		for i in range(nodes.size()):
			# Dükkân/olay durakları köy üretmez — atla.
			var nt: int = nodes[i]["type"]
			if nt == Enums.NodeType.SHOP or nt == Enums.NodeType.EVENT:
				continue
			var cfg: Dictionary = nodes[i]["config"]
			var rng := RandomNumberGenerator.new()
			rng.seed = int(cfg["seed"])
			var st: VillageState = VillageGenerator.generate(cfg, rng)
			tried += 1
			if st == null:
				fails.append("asc%d/node%d" % [asc, i])
	check(fails.is_empty(), "tüm ascension×düğüm üretilebilir (kırık: %s)" % str(fails))
	print("  ascension kapsama: %d köy denendi" % tried)

	# V2 knob: A4 sorgu hakkını kısar.
	var m4: Array = RunManager._build_map(4, 999)
	eq(int(m4[1]["config"]["q_per_day"]), 2, "asc4: köy 1'de sorgu hakkı 3->2")
	# Boss çifte av (boss artık son düğüm — dükkân/olay araya girdi; seed 999 → Aç Alfa).
	var m0: Array = RunManager._build_map(0, 999)
	eq(int(m0[m0.size() - 1]["config"].get("kills_per_night", 1)), 2, "boss gecede 2 av")

	# Boss VARYANTLARI: her biri düşük ve yüksek çilede üretilebilir olmalı.
	var bfails: Array = []
	for bi in range(RunManager.BOSS_SPECS.size()):
		for basc in [0, 6]:
			var bcfg: Dictionary = RunManager._apply_ascension(RunManager.BOSS_SPECS[bi], basc, 4)
			bcfg["seed"] = 91000 + bi * 100 + basc
			var brng := RandomNumberGenerator.new()
			brng.seed = int(bcfg["seed"])
			if VillageGenerator.generate(bcfg, brng) == null:
				bfails.append("boss%d/asc%d" % [bi, basc])
	check(bfails.is_empty(), "boss varyantları üretilebilir (kırık: %s)" % str(bfails))


# -------------------------------------------------------------------
func _test_gameflow() -> void:
	_section_start("GameState akışı (V2: sorgu + gece)")
	var gs = GameState
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260720
	var state := VillageGenerator.generate({"n": 7, "evil_count": 2, "demon_count": 1, "seed": 20260720}, rng)
	check(state != null, "gameflow köyü üretildi")
	if state == null:
		return

	gs.start_village(state)
	eq(gs.health, 10, "başlangıç can 10")
	eq(gs.remaining_evil(), 2, "başta 2 kurt tehdit")
	eq(state.day, 1, "gün 1")
	eq(state.questions_left, 3, "3 sorgu hakkı")
	check(gs.is_active(), "köy aktif")

	# SORGU: ifade alınır, hak düşer; aynı karakter tekrar sorgulanabilir.
	check(gs.question(0), "sorgu 1 başarılı")
	eq(state.get_character(0).given, 1, "1 ifade verildi")
	eq(state.questions_left, 2, "hak 3->2")
	check(gs.question(0), "aynı karakter tekrar sorgulanabilir")
	eq(state.get_character(0).given, 2, "2 ifade verildi")
	check(not gs.question(0), "ifadesi bitince sorgu reddedilir (hak yanmaz)")
	eq(state.questions_left, 1, "reddedilen sorgu hak yakmaz")
	check(gs.question(1), "sorgu 3 başarılı")
	check(not gs.question(2), "hak bitti -> sorgu reddedilir")

	# GÜNÜ BİTİR: gece avı — bir koyun ölür, şafakta haklar tazelenir.
	var killed := [-1]
	EventBus.night_kill.connect(func(s): killed[0] = s, CONNECT_ONE_SHOT)
	gs.end_day()
	check(killed[0] >= 0, "gece bir kurban verdi")
	check(state.get_character(killed[0]).night_killed, "kurban night_killed")
	check(not state.get_character(killed[0]).is_evil(), "kurban her zaman koyundur")
	eq(state.day, 2, "şafak: gün 2")
	eq(state.questions_left, 3, "haklar tazelendi")
	eq(state.night_events.size(), 1, "gece olayı kayıtlı")

	# Ölü sorgulanamaz.
	check(not gs.question(killed[0]), "ölü karakter sorgulanamaz")

	# Yanlış ayıklama -5.
	var good_seat := -1
	for c in state.characters:
		if not c.is_evil() and c.is_alive():
			good_seat = c.seat
			break
	gs.execute(good_seat)
	eq(gs.health, 5, "yanlış ayıklama -5 can")
	check(gs.is_active(), "1 hata sonrası hâlâ aktif")

	# Tüm kurtları ayıkla -> kazanç (+bonuslar).
	var won := [false]
	EventBus.village_won.connect(func(_s): won[0] = true, CONNECT_ONE_SHOT)
	for c in state.characters:
		if c.is_evil():
			gs.execute(c.seat)
	eq(gs.remaining_evil(), 0, "tüm kurtlar ayıklandı")
	check(won[0], "village_won sinyali yayıldı")
	eq(gs.phase, Enums.GamePhase.VILLAGE_END, "faz VILLAGE_END")
	check(gs.score >= 200 + 50, "skor: 2 kurt + can bonusu + gün bonusu (%d)" % gs.score)

	# KAYIP: şafaklar tükenirse köy düşer.
	var st2 := _make_state(9, [4])
	st2.max_days = 2
	gs.start_village(st2)
	var lost := [false]
	EventBus.village_lost.connect(func(_r): lost[0] = true, CONNECT_ONE_SHOT)
	gs.end_day()  # gece 1 -> gün 2
	check(gs.is_active(), "gün 2'de hâlâ aktif")
	gs.end_day()  # gece 2 -> gün 3 > max_days=2 -> kayıp
	check(lost[0], "şafaklar tükenince köy düşer")

	# KAYIP: sürü kurt sayısına inerse.
	var st3 := _make_state(4, [1, 3])  # 2 koyun 2 kurt
	gs.start_village(st3)
	var lost2 := [false]
	EventBus.village_lost.connect(func(_r): lost2[0] = true, CONNECT_ONE_SHOT)
	gs.end_day()  # 1 koyun ölür -> 1 <= 2 -> kayıp
	check(lost2[0], "sürü kurda yenik düşünce köy düşer")

	# Mark sistemi.
	var st4 := _make_state(5, [2])
	gs.start_village(st4)
	gs.set_mark(0, Enums.MarkType.MARK_EVIL)
	eq(st4.marks[0], Enums.MarkType.MARK_EVIL, "mark kaydedildi")


# -------------------------------------------------------------------
func _test_run_manager() -> void:
	_section_start("RunManager")
	var rm = RunManager

	rm.start_run(0, 999)
	check(rm.has_active_run(), "sefer aktif")
	# 3 perde: 8 köy + 2 elit + 2 mini-boss + 3 olay + 3 dükkân + final = 17 düğüm.
	eq(rm.nodes.size(), 17, "harita 17 düğüm (3 perde)")
	eq(rm.current_index, 0, "başlangıç düğümü 0")
	eq(int(rm.current_village_config()["n"]), 5, "ilk köy n=5")
	check(rm.is_current_boss() == false, "ilk düğüm boss değil")
	eq(rm.coins, 0, "başta 0 para")
	eq(int(rm.nodes[2]["type"]), Enums.NodeType.EVENT, "3. düğüm OLAY")
	eq(int(rm.nodes[3]["type"]), Enums.NodeType.ELITE, "4. düğüm ELİT köy")
	check(bool(rm.nodes[4]["config"].get("miniboss", false)), "5. düğüm mini-boss")
	eq(int(rm.nodes[5]["type"]), Enums.NodeType.SHOP, "6. düğüm DÜKKÂN")
	eq(int(rm.nodes[15]["type"]), Enums.NodeType.SHOP, "finalden önce DÜKKÂN")
	eq(int(rm.nodes[16]["type"]), Enums.NodeType.BOSS, "son düğüm Alfa finali")

	# Haritayı boss'a kadar yürü: köyler kazanılır, duraklar tamamlanır.
	while not rm.is_last_node():
		var nt: int = rm.current_node()["type"]
		if nt == Enums.NodeType.SHOP or nt == Enums.NodeType.EVENT:
			rm.on_stop_completed()
		else:
			rm.on_village_won(100, 8)
	eq(rm.current_index, 16, "boss'a gelindi (16. indeks)")
	check(rm.is_current_boss(), "son düğüm boss")
	eq(rm.last_outcome, Enums.RunOutcome.VILLAGE_WON, "ara sonuç VILLAGE_WON")
	check(rm.nodes[2]["cleared"] and rm.nodes[5]["cleared"], "durak düğümleri tamamlandı")
	check(rm.owned_passives.size() >= 2, "iki elit köy iki muska hediye etti")
	check(rm.pending_draft, "köy zaferi rol draft'ı bekletiyor")

	var run_done := [false]
	EventBus.run_completed.connect(func(_s, _c): run_done[0] = true, CONNECT_ONE_SHOT)
	rm.on_village_won(100, 8)
	eq(rm.last_outcome, Enums.RunOutcome.RUN_WON, "sefer kazanıldı")
	check(not rm.has_active_run(), "sefer bitti (pasif)")
	check(run_done[0], "run_completed sinyali")
	eq(rm.total_score, 1100, "toplam skor 11*100")
	# Para: 8 köy/elit (65) + 2 mini-boss (65+25) + final (65+50).
	eq(rm.coins, 8 * 65 + 2 * 90 + 115, "para: köyler + mini-boss + final")
	eq(rm.max_ascension_unlocked, 1, "A2 açıldı")

	# --- SONSUZ SÜRÜ: final sonrası zincir sürer, kayıpta biter ---
	rm.continue_endless()
	check(rm.has_active_run(), "endless: sefer yeniden aktif")
	eq(rm.nodes.size(), 18, "endless: yeni köy düğümü eklendi")
	eq(int(rm.current_node()["type"]), Enums.NodeType.VILLAGE, "endless düğümü köy")
	rm.on_village_won(100, 8)
	check(rm.has_active_run(), "endless: kazanınca zincir devam ediyor")
	eq(rm.nodes.size(), 19, "endless: bir köy daha eklendi")
	rm.on_village_lost()
	check(not rm.has_active_run(), "endless: kayıpla biter")

	# Ascension ölçekleme: tutorial sade kalır.
	var m4: Array = rm._build_map(4, 999)
	eq(int(m4[0]["config"]["evil_count"]), 1, "tutorial ascension'da sade kalır (evil 1)")

	rm.start_run(0, 5)
	rm.on_village_lost()
	eq(rm.last_outcome, Enums.RunOutcome.RUN_LOST, "sefer düştü")
	check(not rm.has_active_run(), "kayıpta sefer pasif")

	# --- Günün Seferi: tarih tohumlu, kazanınca günlük rekor işlenir ---
	rm.start_daily()
	check(rm.is_daily, "günlük sefer bayrağı")
	eq(rm.run_seed, RunManager.today_int() * 7 + 3, "tohum tarihten türedi")
	while rm.has_active_run():
		var dnt: int = rm.current_node()["type"]
		if dnt == Enums.NodeType.SHOP or dnt == Enums.NodeType.EVENT:
			rm.on_stop_completed()
		else:
			rm.on_village_won(100, 8)
	eq(rm.stat_daily_date, RunManager.today_int(), "günlük rekor tarihi bugün")
	eq(rm.stat_daily_best, 1100, "günlük en iyi skor kaydedildi (11 köy × 100)")
	check(not rm.is_daily or not rm.active, "günlük sefer bitti")

	# --- Bereket Boynuzu: maks can 12 ---
	rm.start_run(0, 6)
	rm.owned_passives.append(&"bereket")
	var bs := _make_state(5, [2])
	GameState.start_village(bs)
	eq(GameState.health, 12, "Bereket ile köy 12 canla başlar")
	rm.owned_passives.clear()

	# --- Olay ödülleri (pending_boons): sonraki köyde tüketilir ---
	rm.pending_boons = [&"extra_q", &"extra_day"]
	var bs2 := _make_state(5, [2])
	var base_q: int = bs2.q_per_day
	var base_days: int = bs2.max_days
	GameState.start_village(bs2)
	eq(bs2.q_per_day, base_q + 1, "olay ödülü: +1 sorgu/gün işledi")
	eq(bs2.max_days, base_days + 1, "olay ödülü: +1 şafak işledi")
	check(rm.pending_boons.is_empty(), "ödüller tüketildi (tek köylük)")
	rm.active = false

	# --- İfade Defteri altyapısı: sorgu günü kaydedilir ---
	var ds := _make_state(5, [2])
	var dtc := TestimonyClaim.new()
	dtc.type = Enums.TestimonyType.SELF_ANCHOR
	dtc.speaker = 0
	dtc.text = "defter testi"
	ds.get_character(0).claims = [dtc]
	GameState.start_village(ds)
	GameState.question(0)
	eq(int(GameState.village.get_character(0).claim_days[0]), 1, "ifadenin günü kaydedildi")
	GameState.village = null


# -------------------------------------------------------------------
func _test_save_manager() -> void:
	_section_start("SaveManager")
	var rm = RunManager
	SaveManager.delete_save()
	check(not SaveManager.has_save(), "temiz başlangıç: kayıt yok")

	rm.stat_villages_cleared = 0
	rm.stat_runs_won = 0
	rm.stat_best_score = 0
	rm.stat_best_ascension = 0
	rm.start_run(1, 424242)
	rm.on_village_won(100, 6)  # index 0 -> 1
	rm.on_village_won(100, 4)  # index 1 -> 2
	check(rm.stat_villages_cleared >= 2, "rekor: kurtarılan köy sayacı arttı")
	SaveManager.save_game()
	check(SaveManager.has_save(), "kayıt yazıldı")

	var saved_index: int = rm.current_index
	var saved_coins: int = rm.coins
	var saved_score: int = rm.total_score
	var saved_cleared: int = rm.stat_villages_cleared

	rm.active = false
	rm.current_index = 0
	rm.coins = 0
	rm.total_score = 0
	rm.stat_villages_cleared = 0
	var ok := SaveManager.load_game()
	check(ok, "kayıt yüklendi")
	check(rm.has_active_run(), "yükleme sonrası sefer aktif")
	eq(rm.ascension, 1, "ascension geri geldi")
	eq(rm.current_index, saved_index, "düğüm ilerlemesi geri geldi")
	eq(rm.coins, saved_coins, "para geri geldi")
	eq(rm.total_score, saved_score, "skor geri geldi")
	eq(rm.nodes.size(), 17, "harita seed'den yeniden kuruldu (3 perde, 17 düğüm)")
	check(rm.nodes[0]["cleared"] and rm.nodes[1]["cleared"], "temizlenen düğümler geri geldi")
	eq(rm.stat_villages_cleared, saved_cleared, "rekor: kurtarılan köy geri geldi")

	SaveManager.delete_save()
	rm.active = false
	rm.save_loaded = false


func _expected_claim_type(role: StringName) -> int:
	match role:
		&"Judge", &"Confessor", &"Healer": return Enums.TestimonyType.ALIGNMENT_OF
		&"Oracle", &"Dreamer", &"Midwife", &"Milkmaid", &"Crier", &"Beekeeper":
			return Enums.TestimonyType.COUNT_IN_SET
		&"Knight", &"Sentry", &"Sheepdog": return Enums.TestimonyType.NEIGHBOR_HAS_EVIL
		&"Scout", &"Drummer": return Enums.TestimonyType.NEAREST_EVIL_DISTANCE
		&"Enlightened": return Enums.TestimonyType.NEAREST_EVIL_DIRECTION
		&"Architect", &"Shearer": return Enums.TestimonyType.EVIL_COUNT_IN_REGION
		&"Lover", &"Gossip", &"Weaver", &"Welldigger": return Enums.TestimonyType.PAIR_RELATION
		&"Beadcounter": return Enums.TestimonyType.COUNT_PARITY_IN_SET
		&"Skittish": return Enums.TestimonyType.NEAREST_EVIL_MIN_DIST
		&"Tailor": return Enums.TestimonyType.WOLF_GAP
		&"Mirrorwright": return Enums.TestimonyType.OPPOSITE_ALIGNMENT
		_: return Enums.TestimonyType.ALIGNMENT_OF


# -------------------------------------------------------------------
func _test_board_smoke() -> void:
	_section_start("VillageBoard smoke (UI instantiate)")
	var board_scene := load("res://scenes/village_board.tscn")
	check(board_scene != null, "board sahnesi yüklendi")
	if board_scene == null:
		return
	var board = board_scene.instantiate()
	add_child(board)  # _ready tetiklenir: köy üretir, kartları döşer, HUD kurar

	var card_count := 0
	var has_hud := false
	for child in board.get_children():
		if child is CardView:
			card_count += 1
		if child is Hud:
			has_hud = true
	eq(card_count, 7, "7 kart oluşturuldu")
	check(has_hud, "HUD eklendi")
	check(GameState.village != null, "board köy başlattı")

	# Bir sorgu simüle et.
	var alive0: int = GameState.village.alive_seats()[0]
	check(GameState.question(alive0), "sorgu çalıştı")
	check(GameState.village.get_character(alive0).given == 1, "ifade verildi")

	board.queue_free()
