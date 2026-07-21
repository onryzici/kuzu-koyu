class_name NightEngine
extends RefCounted

## GECE AVI — V2 imza mekaniği. Bkz. CLAUDE.md §0.5.
## Av Düzeni (bilinen, deterministik): kurban = canlı İYİ karakterlerden, herhangi
## bir canlı KURDA çember mesafesi en küçük olan; eşitlikte küçük seat numarası.
## SİSLİ GECE (NightRule.FARTHEST): kurt görüşü bozulur — EN UZAK koyunu avlar
## (köyde İLAN edilir; adalet §7.3).
## TUZAK: Tuzakçı bir koltuğa kapan kurduysa ve av o koltuğa denk gelirse kurban
## ölmez; SALDIRAN kurt (kurbana en yakın kurt) yakalanıp gerçek yüzü açılır.
##
## TEK DOĞRULUK KAYNAĞI (§18): gerçek gece (GameState.end_day), solver'ın gece
## kısıtı VE üreticinin bot simülasyonu — üçü de pick_victim'i kullanır. Kural
## değişirse yalnız burası değişir.
##
## V3 — GECE TRAFİĞİ (bkz. CLAUDE.md §0.7): bazı karakterler gece başka evlere
## gider; kurallar BİLİNEN ve DETERMİNİSTİKTİR, akşam anlık görüntüsünden bağımsız
## hesaplanır (zincirleme etki yok). Otacı son sorgulanana şifa taşır (av oraya
## denk gelirse kurban KURTULUR — sessiz şafak); Seyyah saat yönünde en yakın
## canlıya misafir olur; saldıran kurt kurbanın evini ziyaret etmiş sayılır.
## Gözcü şafakta komşularının ziyaret sayısını raporlar (VISITOR_COUNT claim).
## Öncelik: TUZAK > ŞİFA.

## alignments: seat -> Enums.Alignment (aday dünya YA DA gerçek durum).
## alive: canlı seat listesi (kurban aday havuzu + avcı kurtlar bunun içinden).
## protected: AĞIL — çobanın o gece koruduğu seat (kurban havuzundan çıkar; -1 = yok).
## rule: Av Düzeni (NEAREST varsayılan; FARTHEST = sisli gece).
## Döndürür: kurban seat; av mümkün değilse (kurt ya da koyun kalmadıysa) -1.
static func pick_victim(alignments: Array, alive: Array, n: int, protected: int = -1,
		rule: int = Enums.NightRule.NEAREST) -> int:
	var wolves: Array = []
	var sheep: Array = []
	for s in alive:
		if alignments[s] == Enums.Alignment.EVIL:
			wolves.append(s)
		elif s != protected:
			sheep.append(s)
	if wolves.is_empty() or sheep.is_empty():
		return -1
	var best := -1
	var best_d := (n + 1) if rule == Enums.NightRule.NEAREST else -1
	for g in sheep:
		var d := n + 1
		for w in wolves:
			var dd := BoardTopology.distance(g, w, n)
			if dd < d:
				d = dd
		# eşitlikte küçük seat: sheep artan sırada gezilir, strict karşılaştırma yeter
		if rule == Enums.NightRule.NEAREST:
			if d < best_d:
				best_d = d
				best = g
		else:  # FARTHEST (sisli gece)
			if d > best_d:
				best_d = d
				best = g
	return best


## Kurbana saldıran kurt: kurbana çember mesafesi en küçük CANLI kurt; eşitlikte
## küçük seat. (Tuzak yakalaması + ileri analiz için.)
static func pick_attacker(alignments: Array, alive: Array, victim: int, n: int) -> int:
	var best := -1
	var best_d := n + 1
	for s in alive:
		if alignments[s] == Enums.Alignment.EVIL:
			var d := BoardTopology.distance(victim, s, n)
			if d < best_d:
				best_d = d
				best = s
	return best


## V3.1: bir gecenin FİİLİ av kuralı. Dönek Alfa (alternating) köyünde kural gece
## gece değişir: TEK günler NEAREST, ÇİFT günler FARTHEST (İLAN edilir — §7.3).
static func effective_rule(state: VillageState) -> int:
	if state.alternating_rule:
		return Enums.NightRule.NEAREST if state.day % 2 == 1 else Enums.NightRule.FARTHEST
	return state.night_rule


## V3.1: saldıran kurdun kurbana geliş yönü (Tazı raporunun tek doğruluk kaynağı).
static func attack_direction(victim: int, attacker: int, n: int) -> int:
	var cw := BoardTopology.cw_distance(victim, attacker, n)
	var ccw := BoardTopology.ccw_distance(victim, attacker, n)
	if cw == ccw:
		return Enums.Direction.EQUIDISTANT
	return Enums.Direction.CLOCKWISE if cw < ccw else Enums.Direction.COUNTER_CLOCKWISE


## V3.1: Sinsi Kurt'un hedefi — EN ÇOK SORGULANAN canlı karakter (eşitlikte küçük
## seat; kimse sorgulanmadıysa -1). mq olay kaydına akşam yazılır (kamusal).
static func prowler_target(mq: int, wolf: int) -> int:
	if mq < 0 or mq == wolf:
		return -1
	return mq


## V3: Otacı'nın gece hedefi — o gün EN SON SORGULANAN canlı karakter.
## Kimse sorgulanmadıysa, hedef kendisiyse ya da hedef akşam sağ değilse evde kalır (-1).
static func healer_target(healer_seat: int, last_q: int, alive: Array) -> int:
	if last_q < 0 or last_q == healer_seat or not (last_q in alive):
		return -1
	return last_q


## V3: Seyyah'ın gece hedefi — saat yönünde en yakın CANLI karakter (kendisi hariç).
static func wanderer_target(seat: int, alive: Array, n: int) -> int:
	for step in range(1, n):
		var s := (seat + step) % n
		if s in alive:
			return s
	return -1


## V3 — TEK DOĞRULUK KAYNAĞI: bir gecenin ev->ziyaretçi kümesi, verili alignment
## dünyasına göre. Gerçek gece kaydı, Gözcü raporu üretimi VE solver'ın VISITOR_COUNT
## değerlendirmesi ÜÇÜ de burayı kullanır (§18).
## day_events: aynı günün gece olayları (kills_per_night>1 → birden çok kayıt;
## akşam anlık görüntüsü — alive/last_q/healers/wanderers — ilk kayıttan okunur).
## Döndürür: { house_seat: {visitor_seat: true, ...} } (ayrık ziyaretçi kümeleri).
static func visitors_by_house(alignments: Array, day_events: Array, n: int) -> Dictionary:
	var houses: Dictionary = {}
	if day_events.is_empty():
		return houses
	var ev0: Dictionary = day_events[0]
	var dusk_alive: Array = ev0["alive"]
	# Otacı(lar): W'de İYİ olan iddialı Otacılar son sorgulanana gider (gece başına 1 kez).
	for h in ev0.get("healers", []):
		if alignments[h] == Enums.Alignment.GOOD:
			var ht := healer_target(int(h), int(ev0.get("last_q", -1)), dusk_alive)
			if ht >= 0:
				_add_visit(houses, ht, int(h))
	# Seyyah(lar): W'de İYİ olanlar saat yönünde en yakın canlıya misafir olur.
	for wd in ev0.get("wanderers", []):
		if alignments[wd] == Enums.Alignment.GOOD:
			var wt := wanderer_target(int(wd), dusk_alive, n)
			if wt >= 0:
				_add_visit(houses, wt, int(wd))
	# Sinsi Kurt (İLAN edilen köy kuralı): en küçük seat'li CANLI kurt, en çok
	# sorgulanana sürtünür — öldürmez ama Gözcü sayımına iz bırakır (§0.7 V3.1).
	if ev0.get("prowler", false):
		var pw := -1
		for s in dusk_alive:
			if alignments[s] == Enums.Alignment.EVIL:
				pw = s
				break
		if pw >= 0:
			var pt := prowler_target(int(ev0.get("mq", -1)), pw)
			if pt >= 0:
				_add_visit(houses, pt, pw)
	# Saldıran kurt(lar): her av olayında kurbanın (ya da kapanın) evine girer.
	for ev in day_events:
		var expected := pick_victim(alignments, ev["alive"], n,
			int(ev.get("protected", -1)), int(ev.get("rule", Enums.NightRule.NEAREST)))
		if expected >= 0:
			var atk := pick_attacker(alignments, ev["alive"], expected, n)
			if atk >= 0:
				_add_visit(houses, expected, atk)
	return houses


static func _add_visit(houses: Dictionary, house: int, visitor: int) -> void:
	if not houses.has(house):
		houses[house] = {}
	houses[house][visitor] = true


## Gerçek durumda geceyi uygula: kurbanı seç; tuzağa denk geldiyse kurdu yakala,
## Otacı oradaysa kurbanı kurtar, yoksa öldür. Gece olayını YALNIZ kamusal
## girdilerle kaydet (solver kısıtı; kurtarılanın kimliği sızmaz — §0.7).
## Döndürür: kurban seat; -1 = av yok; -2 = TUZAK tetiklendi (kurt açıldı);
## -3 = ŞİFA — Otacı kurbanın evindeydi, ölüm yok (sessiz şafak).
static func apply(state: VillageState, protected: int = -1) -> int:
	var alive := state.alive_seats()
	var al: Array = []
	for c in state.characters:
		al.append(c.alignment)
	# Kamusal akşam görüntüsü: iddialı ziyaretçi rolleri (shown_role herkese açık).
	var claimed_healers: Array = []
	var claimed_wanderers: Array = []
	for c in state.characters:
		if c.is_alive():
			if c.shown_role() == &"Herbalist":
				claimed_healers.append(c.seat)
			elif c.shown_role() == &"Wanderer":
				claimed_wanderers.append(c.seat)
	# Kamusal akşam girdileri: en çok sorgulanan (Sinsi hedefi; eşitlikte küçük seat).
	var mq := -1
	var mq_best := 0
	for s in alive:
		var g: int = state.get_character(s).given
		if g > mq_best:
			mq_best = g
			mq = s
	var rule := effective_rule(state)
	var trap := state.trap_seat
	var victim := pick_victim(al, alive, state.n, protected, rule)
	state.trap_seat = -1  # kapan tek geceliktir — tetiklenmese de sabah bozulur
	if victim < 0:
		return -1
	var ev := {"alive": alive, "victim": victim, "day": state.day,
		"protected": protected, "rule": rule, "trapped": trap,
		"last_q": state.last_questioned, "healers": claimed_healers,
		"wanderers": claimed_wanderers,
		"prowler": state.modifiers.has("prowler"), "mq": mq}
	if trap >= 0 and victim == trap:
		# TUZAK: saldıran kurt yakalandı — postu düşer, gerçek yüz açılır (ölmez).
		var caught := pick_attacker(al, alive, victim, state.n)
		if caught >= 0:
			state.get_character(caught).revealed = true
		ev["victim"] = -1
		ev["caught"] = caught
		state.night_events.append(ev)
		return -2
	# ŞİFA (tuzaktan sonra): GERÇEK bir Otacı'nın hedefi kurbansa kurban kurtulur.
	for h in claimed_healers:
		if state.get_character(h).role == &"Herbalist" \
				and healer_target(h, state.last_questioned, alive) == victim:
			ev["victim"] = -1
			state.night_events.append(ev)
			return -3
	var c := state.get_character(victim)
	c.night_killed = true
	c.revealed = true  # gerçek yüz (kesin İYİ) açığa çıkar
	state.night_events.append(ev)
	return victim


## V3: Şafak raporları — sağ Gözcüler (iddialı; shown_role) sorgu harcamadan
## iki kapı komşusunun o gece aldığı TOPLAM ziyaret sayısını söyler. Gerçek Gözcü
## doğruyu sayar; kurt-Gözcü YALAN söylemek zorunda (sayı kamusal-mümkün aralıktan,
## seed+gün+seat'ten DETERMİNİSTİK — bot ve gerçek oyun birebir aynı raporu üretir).
## Rapor, karakterin verilmiş ifadelerine eklenir (İfade Defteri + balon).
## Döndürür: rapor veren seat listesi.
static func dawn_reports(state: VillageState) -> Array:
	var day_events: Array = []
	for ev in state.night_events:
		if int(ev.get("day", -1)) == state.day:
			day_events.append(ev)
	if day_events.is_empty():
		return []
	var al: Array = []
	for c in state.characters:
		al.append(c.alignment)
	var gt_houses := visitors_by_house(al, day_events, state.n)
	var ev0: Dictionary = day_events[0]
	# Tazı raporu gecenin İLK ölümü hakkındadır (deterministik seçim).
	var first_victim := -1
	for ev in day_events:
		if int(ev.get("victim", -1)) >= 0:
			first_victim = int(ev["victim"])
			break
	var out: Array = []
	for c in state.characters:
		if not c.is_alive():
			continue
		var shown := c.shown_role()
		var t: TestimonyClaim = null
		var rng := RandomNumberGenerator.new()
		rng.seed = int(state.seed) * 1000003 + state.day * 131 + c.seat * 7919
		if shown == &"Watcher":
			var nb := BoardTopology.neighbors(c.seat, state.n)
			var truth := 0
			for h in nb:
				truth += (gt_houses[h] as Dictionary).size() if gt_houses.has(h) else 0
			var num := truth
			if c.role != &"Watcher":
				# Kurt bluff'u: yanlış ama inandırıcı sayı — kamusal üst sınır içinde.
				var pmax: int = ev0.get("healers", []).size() + ev0.get("wanderers", []).size() \
					+ day_events.size() + (1 if ev0.get("prowler", false) else 0)
				var opts: Array = []
				for k in range(pmax + 1):
					if k != truth:
						opts.append(k)
				num = truth + 1 if opts.is_empty() else opts[rng.randi() % opts.size()]
			t = TestimonyClaim.new()
			t.type = Enums.TestimonyType.VISITOR_COUNT
			t.targets = nb
			t.number = num
		elif shown == &"Hound" and first_victim >= 0:
			# Tazı: saldıranın kurbana geliş yönü. Ölümsüz gecede iz yok (rapor da yok
			# — gerçek ve sahte Tazı aynı davranır, sızıntı olmaz).
			var true_atk := pick_attacker(al, ev0["alive"], first_victim, state.n)
			var true_dir := attack_direction(first_victim, true_atk, state.n)
			var dir := true_dir
			if c.role != &"Hound":
				var dopts: Array = []
				for d in [Enums.Direction.CLOCKWISE, Enums.Direction.COUNTER_CLOCKWISE]:
					if d != true_dir:
						dopts.append(d)
				if state.n % 2 == 0 and true_dir != Enums.Direction.EQUIDISTANT:
					dopts.append(Enums.Direction.EQUIDISTANT)
				dir = dopts[rng.randi() % dopts.size()]
			t = TestimonyClaim.new()
			t.type = Enums.TestimonyType.ATTACKER_DIRECTION
			t.targets = [first_victim]
			t.direction = dir
		if t == null:
			continue
		t.speaker = c.seat
		t.day = state.day
		t.text = TestimonyText.phrase(shown, t, rng)
		c.claims.insert(c.given, t)
		c.given += 1
		c.claim_days.append(state.day)
		c.testimony = t
		out.append(c.seat)
	return out


## Bir aday dünya (alignment ataması) kayıtlı gece olaylarıyla tutarlı mı?
## Her olay: o anki canlı kümede (korunan hariç), W'ye göre av kuralı TAM O sonucu
## üretmeliydi. Tuzaklı gecelerde: dünya avı kapana yolluyorsa gerçek sonuç da
## "yakalama" olmalı (ve saldıran kurt tutmalı); yollamıyorsa kurban tutmalı.
## V3 ŞİFA: W'de İYİ bir iddialı Otacı'nın hedefi beklenen kurbansa sonuç
## SESSİZ ŞAFAK (victim=-1) olmalıydı — ve tersi (ceset varsa şifa OLMAMALIYDI).
static func consistent_with_nights(alignments: Array, night_events: Array, n: int) -> bool:
	for ev in night_events:
		var rule := int(ev.get("rule", Enums.NightRule.NEAREST))
		var trapped := int(ev.get("trapped", -1))
		var expected := pick_victim(alignments, ev["alive"], n, int(ev.get("protected", -1)), rule)
		if trapped >= 0 and expected == trapped:
			# Dünya avı kapana yolluyor → gerçekte de tuzak tetiklenmiş olmalı
			# ("caught" anahtarı yalnız tuzak tetiklenince yazılır — sessiz şafağın
			# tuzaktan mı şifadan mı geldiği kamusal olarak bilinir).
			if int(ev["victim"]) != -1 or not ev.has("caught"):
				return false
			var caught := int(ev.get("caught", -1))
			if caught >= 0 and pick_attacker(alignments, ev["alive"], trapped, n) != caught:
				return false
			continue
		# Tuzak tetiklenmediyse: gerçekte yakalama olduysa bu dünya tutmaz.
		if ev.has("caught"):
			return false
		# ŞİFA öngörüsü: W'de iyi bir iddialı Otacı beklenen kurbanın evinde miydi?
		var saved_pred := false
		if expected >= 0:
			for h in ev.get("healers", []):
				if alignments[h] == Enums.Alignment.GOOD \
						and healer_target(int(h), int(ev.get("last_q", -1)), ev["alive"]) == expected:
					saved_pred = true
					break
		if saved_pred:
			if int(ev["victim"]) != -1:
				return false
		elif expected != int(ev["victim"]):
			return false
	return true
