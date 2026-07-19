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
var _shield_used := false     ## Kalkan muskası: köy başına 1 hasarsız yanlış
var _night_grace := false     ## Pusula muskası: ilk gece av olmaz


## Maks can — Bereket muskası +2 (yalnız aktif seferde).
func max_health() -> int:
	if RunManager.has_active_run() and RunManager.has_passive(&"bereket"):
		return MAX_HEALTH + 2
	return MAX_HEALTH


func start_village(state: VillageState) -> void:
	village = state
	health = max_health()
	score = 0
	_shield_used = false
	_night_grace = false
	village.day = 1
	village.questions_left = village.q_per_day
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
		# Pusula: ilk gece kurt avlanamaz (sürü bir şafak kazanır).
		if RunManager.has_passive(&"pusula"):
			_night_grace = true
	_set_phase(Enums.GamePhase.REVEAL_IDLE)


## Yanlış ayıklama hasarı — Zırh muskası varsa azalır (§4).
func wrong_execute_damage() -> int:
	if RunManager.has_active_run() and RunManager.has_passive(&"zirh"):
		return 3
	return WRONG_EXECUTE_DAMAGE


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
		EventBus.question_denied.emit(seat, "sorgu hakkı bitti")
		return false
	var c := village.get_character(seat)
	if not c.is_alive():
		return false
	if not c.has_more_claims():
		EventBus.question_denied.emit(seat, "söyleyecek yeni şeyi yok")
		return false
	c.given += 1
	c.testimony = c.claims[c.given - 1]
	village.questions_left -= 1
	# Müneccim ilk sorguda Gizli Kural'ı (Omen) ifşa eder → solver + HUD rozeti.
	if c.role == &"Astrologer" and village.omen_type != Enums.OmenType.NONE and village.known_omen == Enums.OmenType.NONE:
		village.known_omen = village.omen_type
		EventBus.omen_hint_learned.emit(village.omen_type)
	EventBus.character_questioned.emit(seat)
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
			if v < 0:
				break
			victims.append(v)
			EventBus.night_kill.emit(v)
		EventBus.night_passed.emit(victims)

	# Sürü düştü mü? (canlı iyi <= canlı kurt → kurtlar sürüyü ele geçirdi)
	if village.alive_good_count() <= village.alive_evil_count():
		_end(false, "sürü kurtlara yenik düştü")
		return

	# Şafak: gün ilerler, sorgu hakkı tazelenir.
	village.day += 1
	if village.day > village.max_days:
		_end(false, "şafaklar tükendi — kurtlar kazandı")
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
		_end(false, "Ermiş'i ayıkladın — felaket!")
		return

	if was_evil:
		score += 100
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
		_end(false, "can bitti")
		return
	if _won():
		_win_with_bonus()
		return

	_set_phase(Enums.GamePhase.REVEAL_IDLE)


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
		_end(false, "can bitti")
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
