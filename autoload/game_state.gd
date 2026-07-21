extends Node

## Aktif köy durumu + oyuncu can/skoru. Motorun oynanış katmanı (V2: Sorgu & Gece).
## Bkz. CLAUDE.md §0.5. UI iş mantığı içermez; UI yalnız EventBus sinyallerine tepki
## verir (§13.3, §16).

const MAX_HEALTH := 10
const WRONG_EXECUTE_DAMAGE := 5

var village: VillageState = null
var health: int = MAX_HEALTH
var score: int = 0
var phase: int = Enums.GamePhase.SETUP
var case_config: Dictionary = {}  ## V3.1 VAKA modu: seçili senaryonun config'i (boş = normal)
## KANIT ZİNCİRİ: her kanıt olayında dünya sayısı düşüşü kaydedilir (board yazar);
## köy sonu özeti "hangi kanıt neyi eledi"yi anlatır. [{day, src, from, to}]
var evidence_log: Array = []


## Köy sonu özeti: en çok dünya eleyen kanıtlar, kronolojik sırada (en fazla maxn).
func evidence_summary(maxn: int = 4) -> Array:
	var idx := 0
	var entries: Array = []
	for e in evidence_log:
		if int(e["from"]) > int(e["to"]):
			entries.append({"i": idx, "e": e})
		idx += 1
	entries.sort_custom(func(a, b):
		return int(a["e"]["from"]) - int(a["e"]["to"]) > int(b["e"]["from"]) - int(b["e"]["to"]))
	var top := entries.slice(0, maxn)
	top.sort_custom(func(a, b): return int(a["i"]) < int(b["i"]))
	var out: Array = []
	for t in top:
		var e: Dictionary = t["e"]
		out.append(Loc.t("ev_line") % [int(e["day"]), String(e["src"]), int(e["from"]), int(e["to"])])
	return out
var _shield_used := false     ## Kalkan muskası: köy başına 1 hasarsız yanlış
var _night_grace := false     ## Pusula muskası: ilk gece av olmaz
var _q_bought := 0            ## bu köyde parayla alınan sorgu sayısı (fiyat tırmanır)

## Köy içi SORGU SATIN ALMA: para çekirdek döngüde işe yarasın (kullanıcı isteği).
## Fiyat her alışta tırmanır — sınırsız bilgiye para yetmez (denge).
const Q_BUY_BASE := 25
const Q_BUY_STEP := 15


func question_price() -> int:
	return Q_BUY_BASE + _q_bought * Q_BUY_STEP


## Parayla +1 sorgu hakkı (yalnız aktif seferde; para RunManager'da). true = alındı.
func buy_question() -> bool:
	if not is_active() or not RunManager.has_active_run():
		return false
	var price := question_price()
	if RunManager.coins < price:
		return false
	RunManager.coins -= price
	_q_bought += 1
	village.questions_left += 1
	EventBus.question_bought.emit(village.questions_left, RunManager.coins)
	SaveManager.save_game()
	return true


## Maks can — Bereket muskası +2; Kanlı Tılsım (lanetli) −2 (yalnız aktif seferde).
func max_health() -> int:
	var hp := MAX_HEALTH
	if RunManager.has_active_run():
		if RunManager.has_passive(&"bereket"):
			hp += 2
		if RunManager.has_passive(&"kanli"):
			hp -= 2
	return hp


func start_village(state: VillageState) -> void:
	village = state
	health = max_health()
	score = 0
	_shield_used = false
	_night_grace = false
	_q_bought = 0
	village.day = 1
	village.questions_left = village.q_per_day
	village.last_questioned = -1
	evidence_log = []
	# Muska etkileri (dükkândan, §4). Yalnız aktif seferde.
	if RunManager.has_active_run():
		# Kâhin Boncuğu: Gizli Kural baştan bilinir (Müneccim beklemeden).
		if RunManager.has_passive(&"kahin") and village.omen_type != Enums.OmenType.NONE:
			village.known_omen = village.omen_type
		# Uğur Böceği: ilk gün +2 sorgu hakkı.
		if RunManager.has_passive(&"ugur"):
			village.questions_left += 2
		# Hafıza Taşı: her gün +1 sorgu hakkı (kalıcı; q_per_day'e işler).
		if RunManager.has_passive(&"hafiza"):
			village.q_per_day += 1
			village.questions_left += 1
		# Kanlı Tılsım (lanetli): +1 sorgu/gün — bedeli max_health()'te (−2 can).
		if RunManager.has_passive(&"kanli"):
			village.q_per_day += 1
			village.questions_left += 1
		# Kara Kese (lanetli): köy ödülü +25 altın; bedeli — köye 1 can eksik başla.
		if RunManager.has_passive(&"karakese"):
			health = maxi(1, health - 1)
		# Pusula: ilk gece kurt avlanamaz (sürü bir şafak kazanır).
		if RunManager.has_passive(&"pusula"):
			_night_grace = true
		# Olay düğümü ödülleri (tek köylük; tüketilir — bkz. RunManager.pending_boons).
		for boon in RunManager.pending_boons:
			match boon:
				&"extra_q":
					village.q_per_day += 1
					village.questions_left += 1
				&"extra_day":
					village.max_days += 1
				&"reveal_omen":
					if village.omen_type != Enums.OmenType.NONE:
						village.known_omen = village.omen_type
		RunManager.pending_boons.clear()
	_set_phase(Enums.GamePhase.REVEAL_IDLE)


## Yanlış ayıklama hasarı — köyün cezası (Kuraklık modifier'ı 7'ye çıkarır);
## Zırh muskası 2 azaltır (§4).
func wrong_execute_damage() -> int:
	var dmg := WRONG_EXECUTE_DAMAGE
	if village != null:
		dmg = village.cull_damage
	if RunManager.has_active_run() and RunManager.has_passive(&"zirh"):
		dmg = maxi(1, dmg - 2)
	return dmg


func _set_phase(p: int) -> void:
	phase = p
	EventBus.phase_changed.emit(p)


func is_active() -> bool:
	return village != null and phase != Enums.GamePhase.VILLAGE_END


## SORGULA (V2): 1 sorgu hakkı harca → karakter sıradaki ifadesini verir.
## Kurt her ifadesinde yalan söyler → tekrar sorgu yalancıyı köşeye sıkıştırır.
## true = ifade alındı; false = hak yok / ölü / söyleyecek şeyi kalmadı.
func question(seat: int) -> bool:
	if not is_active():
		return false
	if village.questions_left <= 0:
		EventBus.question_denied.emit(seat, Loc.t("qdeny_no_questions"))
		return false
	var c := village.get_character(seat)
	if not c.is_alive():
		return false
	if not c.has_more_claims():
		EventBus.question_denied.emit(seat, Loc.t("qdeny_no_claims"))
		return false
	c.given += 1
	c.testimony = c.claims[c.given - 1]
	c.claim_days.append(village.day)  # İfade Defteri: hangi gün söylendi
	village.questions_left -= 1
	# V3: günün son sorgusu Otacı'nın gece hedefidir (sorgu SIRASI taktik araç — §0.7).
	village.last_questioned = seat
	# Müneccim ilk sorguda Gizli Kural'ı (Omen) ifşa eder → solver + HUD rozeti.
	if c.role == &"Astrologer" and village.omen_type != Enums.OmenType.NONE and village.known_omen == Enums.OmenType.NONE:
		village.known_omen = village.omen_type
		EventBus.omen_hint_learned.emit(village.omen_type)
	EventBus.character_questioned.emit(seat)
	# Uğursuz: sorgulayanın sürüsünden 1 can alır (nazar) — İLAN edilen bedel.
	if c.role == &"Jinxed":
		health -= 1
		EventBus.player_damaged.emit(1, health)
		if health <= 0:
			_end(false, Loc.t("lose_jinxed"))
	return true


## V3.1 YÜZLEŞTİRME: 2 sorgu hakkına, `asker` SEÇİLEN `target` hakkında konuşur.
## Dinamik ALIGNMENT_OF: iyi→doğru, kurt→ters, Sarhoş→seed'li %50. Çift başına 1 kez.
## Bütçe botu bunu KULLANMAZ — adalet garantisi yüzleştirmesiz sağlanır (§0.7 V3.1).
const CONFRONT_COST := 2

func confront(asker: int, target: int) -> bool:
	if not is_active() or asker == target:
		return false
	if village.questions_left < CONFRONT_COST:
		EventBus.question_denied.emit(asker, Loc.t("confront_no_q"))
		return false
	var a := village.get_character(asker)
	var b := village.get_character(target)
	if not a.is_alive() or not b.is_alive():
		return false
	var pair := "%d:%d" % [asker, target]
	if village.confronted.has(pair):
		EventBus.question_denied.emit(asker, Loc.t("confront_pair_used"))
		return false
	village.confronted[pair] = true
	village.questions_left -= CONFRONT_COST
	# Cevap: gerçeği hesapla, konuşana göre bük (§18 yalan üretim kuralı).
	var rng := RandomNumberGenerator.new()
	rng.seed = int(village.seed) * 999983 + village.day * 17 + asker * 131 + target * 7919
	var truth: int = b.alignment
	var said := truth
	if a.is_evil():
		said = Enums.Alignment.GOOD if truth == Enums.Alignment.EVIL else Enums.Alignment.EVIL
	elif a.category == Enums.Category.OUTCAST and village.drunk_count > 0 and a.role != &"Saint" and a.role != &"Jinxed":
		# Sarhoş adayı: %50 yanlış (seed'li — aynı çift hep aynı cevabı verir).
		if rng.randf() < 0.5:
			said = Enums.Alignment.GOOD if truth == Enums.Alignment.EVIL else Enums.Alignment.EVIL
	var t := TestimonyClaim.new()
	t.type = Enums.TestimonyType.ALIGNMENT_OF
	t.speaker = asker
	t.targets = [target]
	t.alignment = said
	t.text = TestimonyText.phrase(a.shown_role(), t, rng)
	a.claims.insert(a.given, t)
	a.given += 1
	a.claim_days.append(village.day)
	a.testimony = t
	village.last_questioned = asker  # yüzleştirme de sorgudur — Otacı hedefi kayar
	SaveManager.bump_stat("stat_confronts")
	SaveManager.unlock_achievement("ach_confront")
	EventBus.character_questioned.emit(asker)
	# Uğursuz bedeli yüzleştirmede de işler (onu konuşturuyorsun).
	if a.role == &"Jinxed":
		health -= 1
		EventBus.player_damaged.emit(1, health)
		if health <= 0:
			_end(false, Loc.t("lose_jinxed"))
	return true


## GÜNÜ BİTİR (V2): gece çöker — kurt Av Düzeni'ne göre avlanır, şafakta yeni gün.
## Av Düzeni bilinir + deterministiktir; cesetler solver'a yalan söylemeyen kısıt ekler.
## protected: AĞIL — çobanın bu gece koruduğu kart (av havuzundan çıkar; -1 = yok).
func end_day(protected: int = -1) -> void:
	if not is_active():
		return
	_set_phase(Enums.GamePhase.RESOLVE)

	# Gece avı (Pusula muskası ilk geceyi atlatır).
	if _night_grace:
		_night_grace = false
		EventBus.night_passed.emit([])
	else:
		var victims: Array = []
		for k in range(village.kills_per_night):
			var v := NightEngine.apply(village, protected)
			if v == -1:
				break
			if v == -2:
				# TUZAK tetiklendi: ölüm yok; yakalanan kurt son gece olayında.
				var ev: Dictionary = village.night_events.back()
				EventBus.trap_sprung.emit(int(ev["trapped"]), int(ev.get("caught", -1)))
				SaveManager.unlock_achievement("ach_trap")
				continue
			if v == -3:
				# ŞİFA: Otacı kurbanın evindeydi — ölüm yok (sessiz şafak, §0.7).
				SaveManager.bump_stat("stat_quiet_dawns")
				SaveManager.unlock_achievement("ach_quiet_dawn")
				EventBus.night_saved.emit()
				continue
			victims.append(v)
			EventBus.night_kill.emit(v)
		# V3: Gözcü şafak raporları (sorgu maliyetsiz; İfade Defteri'ne işlenir).
		var reporters := NightEngine.dawn_reports(village)
		if not reporters.is_empty():
			EventBus.dawn_reports_given.emit(reporters)
		EventBus.night_passed.emit(victims)
	village.last_questioned = -1  # Otacı hedefi güne aittir — şafakta sıfırlanır

	# Sürü düştü mü? (canlı iyi <= canlı kurt → kurtlar sürüyü ele geçirdi)
	if village.alive_good_count() <= village.alive_evil_count():
		_end(false, Loc.t("lose_overrun"))
		return

	# Şafak: gün ilerler, sorgu hakkı tazelenir.
	village.day += 1
	if village.day > village.max_days:
		_end(false, Loc.t("lose_days"))
		return
	village.questions_left = village.q_per_day
	EventBus.day_started.emit(village.day)
	_set_phase(Enums.GamePhase.REVEAL_IDLE)


## Kartı AYIKLA (commit). Kurt ise ilerleme; koyun ise can cezası. Gün içinde her an.
func execute(seat: int) -> void:
	if not is_active():
		return
	var c := village.get_character(seat)
	if not c.is_alive():
		return

	_set_phase(Enums.GamePhase.RESOLVE)
	c.executed = true
	c.revealed = true  # gerçek yüz açılır
	var was_evil := c.is_evil()
	EventBus.card_executed.emit(seat, was_evil)

	# Ermiş (Saint) ayıklandı → anında felaket (§6). Kutsama Suyu varsa felaket
	# yerine normal yanlış-ayıklama cezası (aşağı düşer).
	if c.role == &"Saint" and not (RunManager.has_active_run() and RunManager.has_passive(&"kutsama")):
		_end(false, Loc.t("lose_saint"))
		return

	if was_evil:
		score += 100
		SaveManager.unlock_achievement("ach_first_wolf")
		# Cesaret Tılsımı: kurt avı o gün +1 sorgu hakkı kazandırır.
		if RunManager.has_active_run() and RunManager.has_passive(&"cesaret"):
			village.questions_left += 1
	else:
		var dmg := wrong_execute_damage()
		# Kalkan: köy başına ilk yanlış hasarsız.
		if RunManager.has_active_run() and RunManager.has_passive(&"kalkan") and not _shield_used:
			_shield_used = true
			EventBus.player_damaged.emit(0, health)
		else:
			health -= dmg
			EventBus.player_damaged.emit(dmg, health)

	if health <= 0:
		_end(false, Loc.t("lose_health"))
		return
	if _won():
		_win_with_bonus()
		return

	_set_phase(Enums.GamePhase.REVEAL_IDLE)


## Tuzakçı aktif yeteneği: bu GECE için bir koltuğa kapan kur (tek kullanım).
## Av o koltuğa denk gelirse kurban ölmez; saldıran kurt yakalanır (yüzü açılır).
func arm_trap(trapper_seat: int, target_seat: int) -> void:
	if not is_active():
		return
	var tr := village.get_character(trapper_seat)
	if tr.role != &"Trapper" or tr.ability_used or not tr.is_alive():
		return
	if not village.get_character(target_seat).is_alive():
		return
	tr.ability_used = true
	village.trap_seat = target_seat
	EventBus.trap_set.emit(trapper_seat, target_seat)


## Kılıççı (Slayer) aktif yeteneği: slayer_seat, target_seat'e kılıç saplar.
## Hedef Alfa Kurt (Demon) ise ölür (ayıklama gibi); değilse boşa gider. Tek kullanım.
func slay(slayer_seat: int, target_seat: int) -> void:
	if not is_active():
		return
	var s := village.get_character(slayer_seat)
	if s.role != &"Slayer" or s.ability_used or not s.is_alive():
		return
	s.ability_used = true
	var t := village.get_character(target_seat)
	var hit := t.category == Enums.Category.DEMON and t.is_alive()
	if hit:
		t.executed = true
		t.revealed = true
		score += 100
		EventBus.card_executed.emit(target_seat, true)  # Alfa öldü (ölüm sinematiği)
	EventBus.slayer_used.emit(slayer_seat, target_seat, hit)
	if hit and _won():
		_win_with_bonus()


## Avcı (Hunter) aktif yeteneği: hedefe ateş eder. Kurt/Alfa ise ölür; koyun ise
## -3 can (yanlış atış). Tek kullanım. Kılıççı'dan farkı: her kurdu vurur ama ıska cezalı.
func hunt(hunter_seat: int, target_seat: int) -> void:
	if not is_active():
		return
	var s := village.get_character(hunter_seat)
	if s.role != &"Hunter" or s.ability_used or not s.is_alive():
		return
	s.ability_used = true
	var t := village.get_character(target_seat)
	var hit := t.is_evil() and t.is_alive()
	if hit:
		t.executed = true
		t.revealed = true
		score += 100
		EventBus.card_executed.emit(target_seat, true)  # kurt öldü (ölüm sinematiği)
	else:
		health -= 3
		EventBus.player_damaged.emit(3, health)
	EventBus.slayer_used.emit(hunter_seat, target_seat, hit)  # aynı sinyal (ok/ıska banner)
	if health <= 0:
		_end(false, Loc.t("lose_health"))
		return
	if hit and _won():
		_win_with_bonus()


func set_mark(seat: int, mark: int) -> void:
	if village == null:
		return
	if seat < 0 or seat >= village.marks.size():
		return
	village.marks[seat] = mark
	EventBus.mark_changed.emit(seat, mark)


## Kazanma: tüm kurtlar ayıklandı (V2 — spread yok, tek kural).
func _won() -> bool:
	if village == null:
		return false
	return remaining_evil() == 0


## Skor bonusları: kalan can + kalan şafaklar (hız ödülü) + kurtarılan koyunlar.
func _win_with_bonus() -> void:
	score += health * 10
	score += (village.max_days - village.day) * 25       # erken bitirme
	score += village.alive_good_count() * 5              # hayatta kalan sürü
	if health >= max_health():
		SaveManager.unlock_achievement("ach_flawless")   # tek yara almadan
	if not case_config.is_empty():
		SaveManager.unlock_achievement("ach_case")       # bir vaka dosyası kapandı
	_end(true, "")


## Hâlâ tehdit olan (ayıklanmamış) kurt sayısı.
func remaining_evil() -> int:
	if village == null:
		return 0
	var count := 0
	for c in village.characters:
		if c.is_evil() and not c.executed:
			count += 1
	return count


func total_evil() -> int:
	if village == null:
		return 0
	return village.evil_count


func executed_evil() -> int:
	return total_evil() - remaining_evil()


func _end(won: bool, reason: String) -> void:
	_set_phase(Enums.GamePhase.VILLAGE_END)
	if won:
		EventBus.village_won.emit(score)
	else:
		EventBus.village_lost.emit(reason)
