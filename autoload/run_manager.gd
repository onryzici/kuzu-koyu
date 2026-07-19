extends Node

## Sefer akışı: harita, köy sırası, ascension, para, skor. Bkz. CLAUDE.md §4, §13.3.
## Köy VillageState'i TUTMAZ — yalnız (seed'li) config tutar; köy determinstik
## olarak yeniden üretilebilir (§13.6). Böylece kayıt = seed + ilerleme.
##
## NOT (dürüstlük): §7.2'deki ascension tablosu Omen(M3)/Outcast(M4)/Spread(M3)
## gerektirir. M2 bunlar motorda yokken zorluğu yalnız desteklenen kollarla
## (anchor sayısı, evil sayısı) yaklaşıklar. Tam tablo M3/M4'te bağlanacak.

const COIN_BASE := 25
const COIN_PER_HEALTH := 5
const COIN_BOSS_BONUS := 50
const MAP_LENGTH := 5  # 4 köy + 1 boss (MVP doğrusal, §4)

# Köy şablonları (V2 — Sorgu & Gece, §0.5). Balans M4'te data/configs/*.tres'e taşınır.
## Köy 0-1 sade (onboarding, §12). Köy 2'den itibaren Gizli Kural (Omen) devreye
## girer. Boss: Alfa sürüsü gecede İKİ koyun avlar (kills_per_night=2) — yarış sertleşir.
## Her config bot-bütçe garantisinden geçer (üretici reddi = imkânsız köy çıkmaz).
const BASE_SPECS := [
	{"n": 5, "evil_count": 1, "demon_count": 1, "anchor_count": 1, "q_per_day": 3, "max_days": 4},
	{"n": 7, "evil_count": 2, "demon_count": 1, "anchor_count": 1, "outcast_count": 1, "hunter": true, "q_per_day": 3, "max_days": 5},
	{"n": 7, "evil_count": 2, "demon_count": 1, "anchor_count": 1, "omen_type": Enums.OmenType.PARITY, "slayer": true, "q_per_day": 3, "max_days": 5},
	{"n": 9, "evil_count": 2, "demon_count": 1, "anchor_count": 2, "omen_type": Enums.OmenType.DISPERSED, "drunk_count": 1, "q_per_day": 3, "max_days": 5},
	# Boss: çifte av — gecede 2 kurban. Sorgu hakkı +1 ile dengelenir (bot doğrular).
	{"n": 9, "evil_count": 2, "demon_count": 1, "anchor_count": 2, "boss": true, "drunk_count": 1, "kills_per_night": 2, "q_per_day": 4, "max_days": 5},
]

var active := false
var ascension := 0
var run_seed := 0
var nodes: Array = []          # her biri {type, config, cleared}
var current_index := 0
var coins := 0
var total_score := 0
var last_outcome := Enums.RunOutcome.NONE
var last_village_score := 0
var last_coins_awarded := 0
var max_ascension_unlocked := 0
var save_loaded := false  # kayıt bu oturumda bir kez yüklensin diye
var owned_passives: Array = []  # sahip olunan muskalar (dükkândan, sefer boyu kalıcı)

# Kalıcı rekorlar/istatistik (§4 "All Saved Villages" + skor).
var stat_villages_cleared := 0
var stat_runs_won := 0
var stat_best_score := 0
var stat_best_ascension := 0    # tamamlanan en yüksek ascension (1-tabanlı gösterilir)

# Günün Seferi (§4 Daily): tarih tohumlu — herkes aynı köyleri oynar.
var is_daily := false
var stat_daily_date := 0        # yyyymmdd — en son kazanılan günlük seferin tarihi
var stat_daily_best := 0        # o günün en iyi skoru


static func today_int() -> int:
	var d := Time.get_date_dict_from_system()
	return int(d["year"]) * 10000 + int(d["month"]) * 100 + int(d["day"])


## Günün Seferi: tarihten türeyen sabit tohum (determinizm §13.6 → herkes aynı bulmaca).
func start_daily() -> void:
	start_run(0, today_int() * 7 + 3)
	is_daily = true

## Dükkân muskaları (kalıcı pasifler, §4). Etkileri GameState/RunManager'da uygulanır.
const PASSIVES := {
	&"zirh": {"name": "Zırh", "desc": "Yanlış ayıklama −5 yerine −3 can.", "price": 60},
	&"kahin": {"name": "Kâhin Boncuğu", "desc": "Gizli Kural her köyde baştan bilinir.", "price": 85},
	&"ugur": {"name": "Uğur Böceği", "desc": "Her köyde İLK gün +2 sorgu hakkı.", "price": 55},
	&"kismet": {"name": "Kısmet Tılsımı", "desc": "Her köy kazancına +30 para.", "price": 70},
	&"hafiza": {"name": "Hafıza Taşı", "desc": "HER gün +1 sorgu hakkı.", "price": 95},
	&"kalkan": {"name": "Kalkan", "desc": "Her köyde İLK yanlış ayıklama hasarsız (bir kez).", "price": 90},
	&"pusula": {"name": "Pusula", "desc": "Her köyde İLK gece kurt avlanamaz (bir şafak kazan).", "price": 80},
	&"kutsama": {"name": "Kutsama Suyu", "desc": "Ermiş'i ayıklarsan felaket olmaz, sadece can cezası.", "price": 75},
	&"bereket": {"name": "Bereket Boynuzu", "desc": "Maksimum can 10 → 12 (her köyde 12 ile başlarsın).", "price": 85},
}


func has_passive(id: StringName) -> bool:
	return id in owned_passives


## Muska satın al (para yeterse). Başarılıysa true.
func buy_passive(id: StringName) -> bool:
	if has_passive(id) or not PASSIVES.has(id):
		return false
	var price: int = PASSIVES[id]["price"]
	if coins < price:
		return false
	coins -= price
	owned_passives.append(id)
	SaveManager.save_game()
	return true


## Dükkân teklifi: sahip olunmayan muskalardan (seed'li) en fazla 3 tanesi.
func roll_shop() -> Array:
	var pool: Array = []
	for id in PASSIVES:
		if not has_passive(id):
			pool.append(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + current_index * 7919 + 31
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	return pool.slice(0, min(3, pool.size()))


func start_run(ascension_level: int, seed: int) -> void:
	ascension = ascension_level
	run_seed = seed
	Rng.seed_with(seed)
	nodes = _build_map(ascension_level, seed)
	current_index = 0
	coins = 0
	total_score = 0
	last_outcome = Enums.RunOutcome.NONE
	last_village_score = 0
	last_coins_awarded = 0
	owned_passives = []
	is_daily = false
	active = true
	EventBus.run_started.emit(ascension_level, seed)


## Omen çeşitliliği (ascension'da omen zorunlu olunca düğüme göre tip seç).
const _OMEN_CYCLE := [
	Enums.OmenType.PARITY, Enums.OmenType.DISPERSED,
	Enums.OmenType.CONTIGUOUS_ARC, Enums.OmenType.MIRROR,
]


func _build_map(asc: int, seed: int) -> Array:
	var out: Array = []
	for i in range(BASE_SPECS.size()):
		var cfg := _apply_ascension(BASE_SPECS[i], asc, i)
		cfg["seed"] = seed + (i + 1) * 98765
		var is_boss: bool = cfg.get("boss", false)
		out.append({
			"type": Enums.NodeType.BOSS if is_boss else Enums.NodeType.VILLAGE,
			"config": cfg,
			"cleared": false,
		})
	return out


## Ascension katmanları (§7.2). Tutorial (n<=5, index 0) sade kalır; diğer düğümlere
## kademeli mekanik biner. Üretilebilirlik `_test_ascension` ile garanti (tüm
## ascension×düğüm kombinasyonu null değil + tek-çözümlü).
func _apply_ascension(spec: Dictionary, asc: int, node_index: int) -> Dictionary:
	var cfg: Dictionary = spec.duplicate()
	var is_boss: bool = cfg.get("boss", false)
	var is_tutorial: bool = int(cfg["n"]) <= 5
	if is_tutorial:
		return cfg  # tutorial her ascension'da sade (onboarding)

	# A1: bir anchor eksilt (simetri kırıcı azalır).
	if asc >= 1:
		cfg["anchor_count"] = max(1, int(cfg["anchor_count"]) - 1)
	# A2: Sarhoş garantisi (bir parya ekle) — henüz yoksa.
	if asc >= 2 and not cfg.has("outcast_count"):
		cfg["drunk_count"] = int(cfg.get("drunk_count", 0)) + 1
	# A3: Omen — omen'siz ÇİFT indeksli düğümlere.
	if asc >= 3 and not is_boss and not cfg.has("omen_type") and node_index % 2 == 0:
		cfg["omen_type"] = _OMEN_CYCLE[node_index % _OMEN_CYCLE.size()]
	# A4: günlük sorgu hakkı −1 (min 2) — bilgi ekonomisi sıkışır (V2).
	if asc >= 4:
		cfg["q_per_day"] = max(2, int(cfg.get("q_per_day", 3)) - 1)
	# A5: bir Evil ekle (evil_count <= n-2 sınırında).
	if asc >= 5:
		cfg["evil_count"] = min(int(cfg["evil_count"]) + 1, int(cfg["n"]) - 2)
	# A6: Kılıççı tavizi kaldırılır — üst seviyede aktif yardımcı yok.
	if asc >= 6:
		cfg.erase("slayer")
	return cfg


func has_active_run() -> bool:
	return active


func current_node() -> Dictionary:
	if current_index < 0 or current_index >= nodes.size():
		return {}
	return nodes[current_index]


func current_village_config() -> Dictionary:
	var node := current_node()
	if node.is_empty():
		return {}
	return node["config"]


func is_current_boss() -> bool:
	var node := current_node()
	return not node.is_empty() and node["type"] == Enums.NodeType.BOSS


func is_last_node() -> bool:
	return current_index == nodes.size() - 1


## Köy kazanıldı: para + skor ver, düğümü işaretle, ilerlet.
func on_village_won(village_score: int, health: int) -> void:
	if not active:
		return
	var award := COIN_BASE + health * COIN_PER_HEALTH
	if is_current_boss():
		award += COIN_BOSS_BONUS
	if has_passive(&"kismet"):
		award += 30  # Kısmet Tılsımı
	coins += award
	total_score += village_score
	last_village_score = village_score
	last_coins_awarded = award
	nodes[current_index]["cleared"] = true
	stat_villages_cleared += 1

	if is_last_node():
		last_outcome = Enums.RunOutcome.RUN_WON
		active = false
		_unlock_next_ascension()
		stat_runs_won += 1
		stat_best_score = max(stat_best_score, total_score)
		stat_best_ascension = max(stat_best_ascension, ascension + 1)
		# Günün Seferi rekoru (yalnız o günün tarihiyle kıyaslanır).
		if is_daily:
			var today := today_int()
			if stat_daily_date != today:
				stat_daily_date = today
				stat_daily_best = total_score
			else:
				stat_daily_best = max(stat_daily_best, total_score)
		EventBus.run_completed.emit(total_score, coins)
	else:
		current_index += 1
		last_outcome = Enums.RunOutcome.VILLAGE_WON
		EventBus.run_map_advanced.emit(current_index)

	SaveManager.save_game()


## Köy kaybedildi: sefer düşer.
func on_village_lost() -> void:
	if not active:
		return
	last_outcome = Enums.RunOutcome.RUN_LOST
	active = false
	EventBus.run_failed.emit(current_index)
	SaveManager.save_game()


func _unlock_next_ascension() -> void:
	if ascension >= max_ascension_unlocked:
		max_ascension_unlocked = ascension + 1


## Kayıttan sefer durumunu geri yükle (nodes seed'den yeniden kurulur).
func restore(data: Dictionary) -> void:
	max_ascension_unlocked = int(data.get("max_ascension_unlocked", 0))
	var st: Dictionary = data.get("stats", {})
	stat_villages_cleared = int(st.get("villages_cleared", 0))
	stat_runs_won = int(st.get("runs_won", 0))
	stat_best_score = int(st.get("best_score", 0))
	stat_best_ascension = int(st.get("best_ascension", 0))
	stat_daily_date = int(st.get("daily_date", 0))
	stat_daily_best = int(st.get("daily_best", 0))
	var run: Dictionary = data.get("run", {})
	if run.get("active", false):
		ascension = int(run.get("ascension", 0))
		run_seed = int(run.get("seed", 0))
		nodes = _build_map(ascension, run_seed)
		current_index = int(run.get("current_index", 0))
		coins = int(run.get("coins", 0))
		total_score = int(run.get("total_score", 0))
		# cleared bayrakları
		var cleared: Array = run.get("cleared", [])
		for i in range(min(cleared.size(), nodes.size())):
			nodes[i]["cleared"] = bool(cleared[i])
		owned_passives = []
		for p in run.get("owned_passives", []):
			owned_passives.append(StringName(p))
		is_daily = bool(run.get("is_daily", false))
		active = true
	else:
		active = false


func to_save_dict() -> Dictionary:
	var cleared: Array = []
	for node in nodes:
		cleared.append(node.get("cleared", false))
	return {
		"max_ascension_unlocked": max_ascension_unlocked,
		"stats": {
			"villages_cleared": stat_villages_cleared,
			"runs_won": stat_runs_won,
			"best_score": stat_best_score,
			"best_ascension": stat_best_ascension,
			"daily_date": stat_daily_date,
			"daily_best": stat_daily_best,
		},
		"run": {
			"active": active,
			"ascension": ascension,
			"seed": run_seed,
			"current_index": current_index,
			"coins": coins,
			"total_score": total_score,
			"cleared": cleared,
			"owned_passives": owned_passives.map(func(p): return String(p)),
			"is_daily": is_daily,
		},
	}
