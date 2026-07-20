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
const COIN_MINIBOSS_BONUS := 25

## 3 PERDE HARİTASI (kullanıcı kararı — sefer kısa geliyordu):
##   Perde 1 Yayla (ısınma) → Perde 2 Vadi (omen + parya) → Perde 3 Kara Orman.
## Her perde sonunda boss (P1-P2 mini, P3 Alfa finali); perde aralarında dükkân,
## içlerinde olay + ELİT köy (isteğe bağlı — zor ama muska ödüllü, atlanabilir).
## Her config bot-bütçe garantisinden geçer (üretici reddi = imkânsız köy çıkmaz).
## t: "village" | "elite" | "miniboss" | "boss" | "shop" | "event".
const MAP_SPECS := [
	# --- PERDE 1: YAYLA ---
	{"t": "village", "act": 1, "n": 5, "evil_count": 1, "demon_count": 1, "anchor_count": 1, "q_per_day": 3, "max_days": 4},
	{"t": "village", "act": 1, "n": 7, "evil_count": 2, "demon_count": 1, "anchor_count": 1, "outcast_count": 1, "hunter": true, "q_per_day": 3, "max_days": 5},
	{"t": "event", "act": 1},
	{"t": "elite", "act": 1, "n": 8, "evil_count": 2, "demon_count": 1, "anchor_count": 1, "omen_type": Enums.OmenType.PARITY, "jinxed_count": 1, "cull_damage": 7, "modifiers": ["drought"], "q_per_day": 3, "max_days": 5},
	{"t": "miniboss", "act": 1, "boss_name": "miniboss_howl", "n": 8, "evil_count": 2, "demon_count": 1, "anchor_count": 2, "slayer": true, "q_per_day": 3, "max_days": 5},
	{"t": "shop", "act": 1},
	# --- PERDE 2: VADİ ---
	{"t": "village", "act": 2, "n": 9, "evil_count": 2, "demon_count": 1, "anchor_count": 2, "omen_type": Enums.OmenType.DISPERSED, "drunk_count": 1, "trapper": true, "night_rule": Enums.NightRule.FARTHEST, "q_per_day": 3, "max_days": 5},
	{"t": "village", "act": 2, "n": 9, "evil_count": 3, "demon_count": 1, "anchor_count": 2, "omen_type": Enums.OmenType.CONTIGUOUS_ARC, "drunk_count": 1, "kills_per_night": 2, "q_per_day": 4, "max_days": 5, "modifiers": ["blood_moon"]},
	{"t": "event", "act": 2},
	{"t": "elite", "act": 2, "n": 10, "evil_count": 3, "demon_count": 1, "anchor_count": 2, "omen_type": Enums.OmenType.MIRROR, "jinxed_count": 1, "modifiers": ["silent"], "q_per_day": 4, "max_days": 6},
	{"t": "miniboss", "act": 2, "boss_name": "miniboss_shadow", "n": 10, "evil_count": 3, "demon_count": 1, "anchor_count": 2, "night_rule": Enums.NightRule.FARTHEST, "hunter": true, "q_per_day": 4, "max_days": 5},
	{"t": "shop", "act": 2},
	# --- PERDE 3: KARA ORMAN ---
	{"t": "village", "act": 3, "n": 11, "evil_count": 3, "demon_count": 1, "anchor_count": 2, "omen_type": Enums.OmenType.SAME_SIDE, "drunk_count": 1, "slayer": true, "q_per_day": 4, "max_days": 6},
	{"t": "village", "act": 3, "n": 12, "evil_count": 3, "demon_count": 1, "anchor_count": 2, "omen_type": Enums.OmenType.DISPERSED, "trapper": true, "kills_per_night": 2, "q_per_day": 4, "max_days": 6, "modifiers": ["blood_moon"]},
	{"t": "event", "act": 3},
	{"t": "shop", "act": 3},  # finalden önce son hazırlık (para burada da erisin)
	{"t": "boss", "act": 3},
]

## Alfa Kurt VARYANTLARI: her seferde tohuma göre biri seçilir — final hep aynı
## olmasın. Hepsi üretici bot-bütçe garantisinden geçer (_test_ascension dener).
const BOSS_SPECS := [
	# Aç Alfa: gecede 2 av; +1 sorgu ile dengeli (klasik).
	# boss_name = Loc anahtarı; gösterim yerinde Loc.t ile çözülür (const'ta çağrı olmaz).
	{"n": 10, "evil_count": 3, "demon_count": 1, "anchor_count": 2, "boss": true,
		"boss_name": "boss_hungry", "drunk_count": 1, "kills_per_night": 2, "q_per_day": 4, "max_days": 5},
	# Gölge Sürüsü: 4 kurt (3+alfa), tek av — kalabalık sürü, geniş köy, sisli gece.
	{"n": 11, "evil_count": 4, "demon_count": 1, "anchor_count": 2, "boss": true,
		"boss_name": "boss_shadow", "drunk_count": 1, "kills_per_night": 1, "night_rule": Enums.NightRule.FARTHEST, "q_per_day": 4, "max_days": 6},
	# Sabırsız Alfa: 2 av + kısılmış sorgu; karşılığında +1 şafak.
	{"n": 10, "evil_count": 3, "demon_count": 1, "anchor_count": 2, "boss": true,
		"boss_name": "boss_impatient", "drunk_count": 1, "kills_per_night": 2, "q_per_day": 3, "max_days": 6},
]

## SEFER DESTESİ (rol draft'ı): sefer bu çekirdek havuzla başlar; her köy zaferi
## sonrası 3 adaydan biri desteye katılır (draft). Generator yalnız bu havuzdan
## koyun rolü/bluff seçer — deste büyüdükçe köyler çeşitlenir.
const STARTER_POOL := [
	&"Judge", &"Confessor", &"Oracle", &"Dreamer", &"Knight", &"Sentry",
	&"Scout", &"Enlightened", &"Architect", &"Lover", &"Gossip", &"Healer",
]
## Draft aday havuzu (STARTER dışında kalanlar; ROLE_TIERS kilidi ayrıca uygulanır).
const DRAFTABLE := [
	&"Weaver", &"Midwife", &"Milkmaid", &"Crier", &"Beekeeper",
	&"Sheepdog", &"Shearer", &"Drummer", &"Welldigger",
	&"Beadcounter", &"Skittish", &"Tailor", &"Mirrorwright",
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
var pending_boons: Array = []   # olay ödülleri; sonraki köy başında tüketilir (GameState)
var role_pool: Array = []       # sefer destesi (StringName; draft ile büyür)
var pending_draft := false      # köy kazanıldı → haritada rol draft'ı sun
var last_elite_reward: StringName = &""  # elit köy ödülü (harita bir kez gösterir)
var endless := false            # Sonsuz Sürü: final sonrası köy zinciri sürer
var endless_extra := 0          # üretilmiş endless düğüm sayısı (determinizm: seed'den)

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
## Ad/açıklama metinleri Loc tablosunda ("passive_<id>_name" / "_desc") — const içinde
## Loc.t çağrılamaz; gösterim yerleri passive_name()/passive_desc() ile çözer.
const PASSIVES := {
	&"zirh": {"price": 60},
	&"kahin": {"price": 85},
	&"ugur": {"price": 55},
	&"kismet": {"price": 70},
	&"hafiza": {"price": 95},
	&"kalkan": {"price": 90},
	&"pusula": {"price": 80},
	&"kutsama": {"price": 75},
	&"bereket": {"price": 85},
	&"cesaret": {"price": 70},
	&"sadaka": {"price": 50},
	# LANETLİ muskalar: güçlü etki + açık bedel (açıklamada yazar; ucuzdur).
	&"kanli": {"price": 45, "cursed": true},     # +1 sorgu/gün; maks can −2
	&"karakese": {"price": 40, "cursed": true},  # köy ödülü +25; köye 1 can eksik başla
}


## Muska adı (aktif dilde). Loc anahtarı: passive_<id>_name.
func passive_name(id: StringName) -> String:
	return Loc.t("passive_%s_name" % id)


## Muska açıklaması (aktif dilde). Loc anahtarı: passive_<id>_desc.
func passive_desc(id: StringName) -> String:
	return Loc.t("passive_%s_desc" % id)


## Muskanın bu seferki fiyatı (Sadaka Kesesi ile %25 indirim; kendisi hariç).
func price_of(id: StringName) -> int:
	var price: int = PASSIVES[id]["price"]
	if has_passive(&"sadaka") and id != &"sadaka":
		price = int(price * 0.75)
	return price


func has_passive(id: StringName) -> bool:
	return id in owned_passives


## Muska satın al (para yeterse). Başarılıysa true.
func buy_passive(id: StringName) -> bool:
	if has_passive(id) or not PASSIVES.has(id):
		return false
	var price := price_of(id)
	if coins < price:
		return false
	coins -= price
	owned_passives.append(id)
	SaveManager.save_game()
	return true


## Dükkân teklifi: sahip olunmayan muskalardan (seed'li) en fazla 3 tanesi.
## salt = reroll sayısı (parayla teklifi yenile — her reroll farklı karışım).
func roll_shop(salt: int = 0) -> Array:
	var pool: Array = []
	for id in PASSIVES:
		if not has_passive(id):
			pool.append(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + current_index * 7919 + 31 + salt * 104729
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	return pool.slice(0, min(3, pool.size()))


## AZIKLAR: tek köylük takviyeler (dükkânda satılır; pending_boons ile sonraki
## köy başında tüketilir — olay ödülleriyle AYNI mekanizma, §4).
const BOONS := {
	&"extra_q": {"price": 30},      # sonraki köyde her gün +1 sorgu
	&"extra_day": {"price": 45},    # sonraki köyde +1 şafak
	&"reveal_omen": {"price": 50},  # sonraki köyde Gizli Kural baştan açık
}


func boon_name(id: StringName) -> String:
	return Loc.t("boon_%s_name" % id)


func boon_desc(id: StringName) -> String:
	return Loc.t("boon_%s_desc" % id)


## Azık fiyatı (Sadaka Kesesi indirimi muskalardaki gibi %25 uygular).
func boon_price(id: StringName) -> int:
	var price: int = BOONS[id]["price"]
	if has_passive(&"sadaka"):
		price = int(price * 0.75)
	return price


## Azık satın al: para düş, sonraki köyün başında etkisi işlensin.
func buy_boon(id: StringName) -> bool:
	if not BOONS.has(id):
		return false
	var price := boon_price(id)
	if coins < price:
		return false
	coins -= price
	pending_boons.append(id)
	SaveManager.save_game()
	return true


func start_run(ascension_level: int, seed: int) -> void:
	ascension = ascension_level
	run_seed = seed
	Rng.seed_with(seed)
	endless = false
	endless_extra = 0
	nodes = _build_map(ascension_level, seed)
	current_index = 0
	coins = 0
	total_score = 0
	last_outcome = Enums.RunOutcome.NONE
	last_village_score = 0
	last_coins_awarded = 0
	owned_passives = []
	pending_boons = []
	role_pool = STARTER_POOL.duplicate()
	pending_draft = false
	last_elite_reward = &""
	is_daily = false
	active = true
	EventBus.run_started.emit(ascension_level, seed)


## Omen çeşitliliği (ascension'da omen zorunlu olunca düğüme göre tip seç).
const _OMEN_CYCLE := [
	Enums.OmenType.PARITY, Enums.OmenType.DISPERSED,
	Enums.OmenType.CONTIGUOUS_ARC, Enums.OmenType.MIRROR,
	Enums.OmenType.SEAL_EQUIDISTANT, Enums.OmenType.SAME_SIDE,
]


func _build_map(asc: int, seed: int) -> Array:
	var out: Array = []
	for i in range(MAP_SPECS.size()):
		var spec: Dictionary = MAP_SPECS[i]
		var t: String = spec["t"]
		var act: int = spec.get("act", 1)
		if t == "shop":
			out.append({"type": Enums.NodeType.SHOP, "act": act, "config": {}, "cleared": false})
			continue
		if t == "event":
			out.append({"type": Enums.NodeType.EVENT, "act": act, "config": {}, "cleared": false})
			continue
		var s: Dictionary = spec.duplicate(true)
		s.erase("t")
		s.erase("act")
		var ntype: int = Enums.NodeType.VILLAGE
		match t:
			"boss":
				s = BOSS_SPECS[absi(seed) % BOSS_SPECS.size()].duplicate(true)
				ntype = Enums.NodeType.BOSS
			"miniboss":
				s["boss"] = true
				s["miniboss"] = true
				ntype = Enums.NodeType.BOSS
			"elite":
				s["elite"] = true
				ntype = Enums.NodeType.ELITE
		var cfg := _apply_ascension(s, asc, i)
		cfg["seed"] = seed + (i + 1) * 98765
		out.append({"type": ntype, "act": act, "config": cfg, "cleared": false})
	# Sonsuz Sürü: final sonrası üretilen ek köyler (determinizm: seed + indeks).
	for k in range(endless_extra):
		out.append(_endless_node(k))
	return out


## Sonsuz Sürü düğümü: zorluk döngüsel tırmanır ama üretilebilirlik sınırında kalır
## (n 9-12, kurt ≤ 4). Modifier'lar dönüşümlü; her köy yine bot-bütçe garantili.
func _endless_node(k: int) -> Dictionary:
	var spec := {
		"n": 9 + (k % 4),
		"evil_count": mini(3 + int(k / 4.0), 4),
		"demon_count": 1,
		"anchor_count": 2,
		"drunk_count": 1 if k % 2 == 0 else 0,
		"q_per_day": 4,
		"max_days": 6,
		"endless": true,
	}
	var omen_cycle := [Enums.OmenType.PARITY, Enums.OmenType.DISPERSED,
		Enums.OmenType.CONTIGUOUS_ARC, Enums.OmenType.SAME_SIDE]
	spec["omen_type"] = omen_cycle[k % omen_cycle.size()]
	match k % 3:
		1:
			spec["kills_per_night"] = 2
			spec["modifiers"] = ["blood_moon"]
		2:
			spec["cull_damage"] = 7
			spec["modifiers"] = ["drought"]
	var cfg := _apply_ascension(spec, ascension, 100 + k)
	cfg["seed"] = run_seed + 777777 + k * 13579
	return {"type": Enums.NodeType.VILLAGE, "act": 4, "config": cfg, "cleared": false}


## Dükkân/Olay düğümü tamamlandı: işaretle ve haritada ilerle (köy-dışı düğümler
## için on_village_won muadili — para/skor vermez).
func on_stop_completed() -> void:
	if not active:
		return
	nodes[current_index]["cleared"] = true
	current_index += 1
	EventBus.run_map_advanced.emit(current_index)
	SaveManager.save_game()


## Ascension katmanları (§7.2). Tutorial (n<=5, index 0) sade kalır; diğer düğümlere
## kademeli mekanik biner. Üretilebilirlik `_test_ascension` ile garanti (tüm
## ascension×düğüm kombinasyonu null değil + tek-çözümlü).
func _apply_ascension(spec: Dictionary, asc: int, node_index: int) -> Dictionary:
	var cfg: Dictionary = spec.duplicate()
	cfg["role_tier"] = asc  # rol açılımları: Çile yükseldikçe havuz genişler
	var is_boss: bool = cfg.get("boss", false)
	var is_tutorial: bool = int(cfg["n"]) <= 5
	if is_tutorial:
		return cfg  # tutorial her ascension'da sade (onboarding)
	if is_boss:
		# Boss spec'leri elle dengeli (n/kurt/av zaten üst sınırda): çile yalnız
		# sorgu hakkını kısar (min 3). Daha fazlası köyü üretilemez yapıyordu
		# (bot-bütçe garantisi tutmaz — test_ascension yakaladı).
		if asc >= 4:
			cfg["q_per_day"] = max(3, int(cfg.get("q_per_day", 4)) - 1)
		return cfg

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
	var cfg: Dictionary = node["config"].duplicate(true)
	# Sefer destesi (draft): generator koyun rollerini yalnız bu havuzdan seçer.
	if not role_pool.is_empty():
		cfg["role_pool"] = role_pool.duplicate()
	return cfg


func is_current_boss() -> bool:
	var node := current_node()
	return not node.is_empty() and node["type"] == Enums.NodeType.BOSS


func is_last_node() -> bool:
	return current_index == nodes.size() - 1


## Köy kazanıldı: para + skor ver, düğümü işaretle, ilerlet.
## Elit köy: seed'li rastgele bir muska hediye. Endless: final sonrası zincir sürer.
func on_village_won(village_score: int, health: int) -> void:
	if not active:
		return
	var cfg := current_village_config()
	var award := COIN_BASE + health * COIN_PER_HEALTH
	if is_current_boss():
		award += COIN_MINIBOSS_BONUS if cfg.get("miniboss", false) else COIN_BOSS_BONUS
	if has_passive(&"kismet"):
		award += 30  # Kısmet Tılsımı
	if has_passive(&"karakese"):
		award += 25  # Kara Kese (lanetli) — bedeli köy başında 1 can
	coins += award
	total_score += village_score
	last_village_score = village_score
	last_coins_awarded = award
	nodes[current_index]["cleared"] = true
	stat_villages_cleared += 1

	# Elit ödülü: sahipsiz muskalardan seed'li biri (bedava; harita duyurur).
	last_elite_reward = &""
	if cfg.get("elite", false):
		var pool: Array = []
		for id in PASSIVES:
			if not has_passive(id):
				pool.append(id)
		if not pool.is_empty():
			var err := RandomNumberGenerator.new()
			err.seed = run_seed + current_index * 733 + 17
			var pick: StringName = pool[err.randi() % pool.size()]
			owned_passives.append(pick)
			last_elite_reward = pick

	if is_last_node():
		if endless:
			# Sonsuz Sürü: yeni köy üret, zincir devam. Skor/istatistik akmaya devam eder.
			endless_extra += 1
			nodes.append(_endless_node(endless_extra - 1))
			current_index += 1
			last_outcome = Enums.RunOutcome.VILLAGE_WON
			pending_draft = true
			stat_best_score = max(stat_best_score, total_score)
			EventBus.run_map_advanced.emit(current_index)
		else:
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
		pending_draft = true  # haritada rol draft'ı sunulur (sefer destesi büyür)
		EventBus.run_map_advanced.emit(current_index)

	SaveManager.save_game()


## ELİT köyü atla (ödülsüz ilerle) — elit her zaman İSTEĞE BAĞLIDIR.
func skip_elite() -> void:
	if not active or current_node().get("type", -1) != Enums.NodeType.ELITE:
		return
	nodes[current_index]["cleared"] = true
	current_index += 1
	EventBus.run_map_advanced.emit(current_index)
	SaveManager.save_game()


## SONSUZ SÜRÜ: final boss yenildikten sonra (sonuç ekranından) zinciri sürdür.
func continue_endless() -> void:
	if active or last_outcome != Enums.RunOutcome.RUN_WON or is_daily:
		return
	endless = true
	endless_extra += 1
	nodes.append(_endless_node(endless_extra - 1))
	current_index = nodes.size() - 1
	last_outcome = Enums.RunOutcome.VILLAGE_WON
	active = true
	SaveManager.save_game()


## ROL DRAFT'I: köy zaferi sonrası 3 aday (seed'li, deterministik). Aday havuzu:
## desteye henüz girmemiş roller (çile kilidi uygulanır).
func draft_choices() -> Array:
	var cands: Array = []
	for r in DRAFTABLE:
		if not role_pool.has(r) and VillageGenerator.ROLE_TIERS.get(r, 0) <= ascension:
			cands.append(r)
	if cands.is_empty():
		return []
	var drng := RandomNumberGenerator.new()
	drng.seed = run_seed + current_index * 5471 + 3
	for i in range(cands.size() - 1, 0, -1):
		var j := drng.randi() % (i + 1)
		var tmp = cands[i]
		cands[i] = cands[j]
		cands[j] = tmp
	return cands.slice(0, mini(3, cands.size()))


func apply_draft(role: StringName) -> void:
	pending_draft = false
	if role != &"" and not role_pool.has(role):
		role_pool.append(role)
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
		endless = bool(run.get("endless", false))
		endless_extra = int(run.get("endless_extra", 0))
		nodes = _build_map(ascension, run_seed)  # endless_extra set → ek düğümler de kurulur
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
		pending_boons = []
		for b in run.get("pending_boons", []):
			pending_boons.append(StringName(b))
		role_pool = []
		for r in run.get("role_pool", []):
			role_pool.append(StringName(r))
		if role_pool.is_empty():
			role_pool = STARTER_POOL.duplicate()  # eski kayıt: varsayılan deste
		pending_draft = bool(run.get("pending_draft", false))
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
			"pending_boons": pending_boons.map(func(b): return String(b)),
			"role_pool": role_pool.map(func(r): return String(r)),
			"pending_draft": pending_draft,
			"endless": endless,
			"endless_extra": endless_extra,
			"is_daily": is_daily,
		},
	}
