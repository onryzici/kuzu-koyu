extends Control

## Ana köy tahtası controller'ı. Bkz. CLAUDE.md §11, §13.2.
## Kartları çember üzerinde dizer; reveal/execute/mark girişini GameState'e yönlendirir.
## Görselleştirme + giriş; kural mantığı GameState/engine'de.

const CardScene := preload("res://scenes/card.tscn")
const HudScene := preload("res://scenes/hud.tscn")
const BG_TEXTURE := preload("res://assets/art/bg/ritual_ground.png")
const GRASS_TEXTURE := preload("res://assets/art/bg/grass_tufts.png")
const GRASS_SHADER := preload("res://assets/art/bg/grass_sway.gdshader")
const FOG_SHADER := preload("res://assets/art/bg/ground_fog.gdshader")

# Bg'deki 5 ritüel mumunun alev konumları (bg uzayı, 3344x1882) — glow çizimi için.
const CANDLE_SPOTS := [
	Vector2(1685, 558),   # tepe
	Vector2(1358, 832),   # sol-üst
	Vector2(2047, 837),   # sağ-üst
	Vector2(1500, 1158),  # sol-alt
	Vector2(1906, 1157),  # sağ-alt
]

# Spritesheet'ten seçilmiş tutam kutuları (px; alfa bbox taramasıyla çıkarıldı).
const GRASS_TUFTS := [
	Rect2(396, 148, 160, 336),    # 0 dar/küçük
	Rect2(2396, 176, 216, 324),   # 1 orta
	Rect2(340, 616, 268, 292),    # 2 geniş
	Rect2(1064, 592, 252, 320),   # 3 orta
	Rect2(2012, 568, 196, 344),   # 4 sivri
	Rect2(688, 1044, 256, 252),   # 5 basık
	Rect2(2156, 1000, 104, 300),  # 6 ince
	Rect2(340, 1064, 272, 228),   # 7 basık/geniş
	Rect2(1108, 1416, 204, 304),  # 8 orta
	Rect2(2028, 1416, 272, 304),  # 9 kafataslı
	Rect2(1420, 564, 212, 348),   # 10 uzun
]

# Yerleşim: bg uzayında (3344x1882) tutamın TABAN-ORTA noktası. Arka planda çim
# olmayan boşluklara serpiştirildi; cover ölçeğiyle birlikte bg'ye yapışık kalır.
const GRASS_SPOTS := [
	{"pos": Vector2(575, 940), "tuft": 2, "scale": 1.0, "flip": false},
	{"pos": Vector2(790, 330), "tuft": 0, "scale": 0.8, "flip": false},
	{"pos": Vector2(1240, 640), "tuft": 6, "scale": 0.9, "flip": false},
	{"pos": Vector2(2260, 500), "tuft": 4, "scale": 0.9, "flip": true},
	{"pos": Vector2(2560, 1380), "tuft": 3, "scale": 1.0, "flip": false},
	{"pos": Vector2(950, 1690), "tuft": 8, "scale": 1.05, "flip": false},
	{"pos": Vector2(1520, 1810), "tuft": 5, "scale": 0.95, "flip": true},
	{"pos": Vector2(2160, 1720), "tuft": 9, "scale": 1.0, "flip": false},
	{"pos": Vector2(3130, 1420), "tuft": 1, "scale": 0.9, "flip": true},
	{"pos": Vector2(160, 1150), "tuft": 7, "scale": 0.95, "flip": true},
	{"pos": Vector2(1920, 250), "tuft": 10, "scale": 0.75, "flip": false},
]

const VILLAGE_CONFIG := {"n": 7, "evil_count": 2, "demon_count": 1, "anchor_count": 1}

## Köye giriş kartı için başlık fontu (menüyle aynı: Revoback).
const FONT_TITLE: Font = preload("res://assets/fonts/Revoback.ttf")

## Seed'li köy adları (giriş kartında). Revoback'te ğ/ı/ş/İ glyph'i yok — liste
## bilerek yalnız güvenli harflerden (Ç Ö Ü dahil) kurulu.
const VILLAGE_NAMES := [
	"KUZUÖREN", "KURTKAYA", "KARAKOYUN", "DOLUNAY", "AYAZKÖY", "BOZTEPE",
	"YÜNKÖY", "KURUDERE", "ALACAKAYA", "KARAÇALI", "OBRUK", "KANLICA",
]

const MARK_CYCLE := [
	Enums.MarkType.NONE,
	Enums.MarkType.MARK_GOOD,
	Enums.MarkType.MARK_SUSPECT,
	Enums.MarkType.MARK_EVIL,
	Enums.MarkType.MARK_QUESTION,
]

var _cards: Array[CardView] = []
var _hud: Hud
var _grass_layer: Node2D            ## bg üstü, kartlar altı çim tutamları
var _grass_sprites: Array[Sprite2D] = []
var _grass_gust: Array[float] = []  ## tutam başına imleç itmesi (doku px, sönümlü)
var _grass_wilt: Array[float] = []  ## tutam başına solma (0..1; kurban tepkisi)
var _fog: ColorRect                 ## alçak zemin sisi (çim üstü, kart altı)
var _tooltip: AbilityTooltip
var _cine_dim: ColorRect      ## ayıklama sinematiğinde arka karartma
var _night_layer: Control     ## gece göğü (indigo + hilal + yıldızlar)
var _night_alpha := 0.0       ## gece katmanı görünürlüğü (0..1)
var _burst: Array = []        ## kazanma yıldız patlaması parçacıkları
var _cinematic := false       ## sinematik oynarken girişi kilitle
var _execute_mode := false
var _hovered_seat := -1
var _night_count := 0          ## geçen gece sayısı (arka plan kızıla kayar — tehdit)
var _slayer_seat := -1         ## Kılıççı hedefleme modu (aktif yetenek)
var _protect_mode := false     ## AĞIL: gece öncesi koruma seçim modu

# --- Atmosfer (yalnız görsel; oyun mantığına dokunmaz) ---
# Süzülen kıvılcım/toz + merkezde nefes alan ritüel parıltısı + mum titremesi.
# Kozmetik olduğu için ayrı, lokal bir RNG kullanır — gameplay Rng stream'ini
# bozmaz (§13.6 determinizmi etkilenmez).
const SPARK_COUNT := 54
var _time := 0.0
var _sparks: Array = []           ## her biri: {x, y, vy, drift, size, phase, spd, warm}
var _fx_rng := RandomNumberGenerator.new()
var _eye_look := Vector2.ZERO     ## gözün YUMUŞATILMIŞ bakış yönü (her kare lerp)
var _arm_tips: PackedVector2Array = PackedVector2Array()  ## kol uçları (kart yoklama)
var _slots: Array = []            ## seat başına Rect2 — kesikli boş kart yeri
var _blood_stains: Array = []     ## kalıcı kan izleri: {pos, blobs, alpha} (kurt öldü)
var _blood_parts: Array = []      ## anlık kan SIÇRAMASI parçacıkları (ölüm ânı)
var _burst_layer: Control         ## kanın kartların ÜSTÜNDE uçtuğu katman
var _kill_label: Label            ## sinematikte kurdun son repliği
# --- Dedüksiyon UX (yalnız görsel yardım; motor kararlarına dokunmaz) ---
var _log: TestimonyLog            ## İfade Defteri (TAB / HUD butonu)
var _intro_layer: Control         ## köye giriş kartı (siyah zemin + başlık)
var _intro_done := false
var _ribbon: RibbonBanner         ## animasyonlu duyuru şeridi (flash_banner hedefi)
var _tutorial: TutorialGuide      ## sefer ilk köyünde rehber (bir kez)
var _worlds: Array = []           ## solver'ın tutarlı dünyaları (olay sonrası önbellek)
var _conflicts: Dictionary = {}   ## seat -> Array[seat]: ikisi birden dürüst OLAMAZ
var _night_preview := false       ## GECE butonu hover: olası kurbanlar vurgulu
var _night_risk: Array = []       ## tutarlı dünyalara göre bu gece ölebilecekler
# --- İfade görselleştirme: yön oku / mesafe yayı (yalnız görsel) ---
# Yön (Yaşlı Koç) ve mesafe (İzci) ifadeleri çember üzerinde kavisli okla /
# adım iziyle gösterilir. İfade verilince kısa süre otomatik, sonra hover'da.
var _clue_seat := -1
var _clue_hold := 0.0             ## otomatik gösterim için kalan süre (sn)
var _clue_alpha := 0.0
var _clue_prog := 0.0             ## okun çizilme ilerlemesi (0..1)
const CLUE_VIOLET := Color(0.83, 0.56, 0.98)
const CLUE_AMBER := Color(1.0, 0.78, 0.35)

# 1–5 tuşları -> mark (Demon Bluff'taki gibi). 5 = temizle.
const MARK_KEYS := {
	KEY_1: Enums.MarkType.MARK_GOOD,
	KEY_2: Enums.MarkType.MARK_SUSPECT,
	KEY_3: Enums.MarkType.MARK_EVIL,
	KEY_4: Enums.MarkType.MARK_QUESTION,
	KEY_5: Enums.MarkType.NONE,
}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_rng.randomize()  # kozmetik kıvılcımlar her açılışta farklı dağılsın
	_build_grass()
	_hud = HudScene.instantiate()
	add_child(_hud)
	_hud.execute_toggled.connect(_toggle_execute_mode)
	_hud.day_end_requested.connect(_on_end_day)
	_hud.restart_requested.connect(_new_village)
	_hud.log_toggled.connect(func(): _log.toggle())
	_hud.night_hover_changed.connect(_on_night_hover)
	_tooltip = AbilityTooltip.new()
	add_child(_tooltip)
	_log = TestimonyLog.new()
	add_child(_log)
	# Duyuru şeridi BOARD'undur: gece HUD çekilirken duyurular görünür kalır.
	_ribbon = RibbonBanner.new()
	add_child(_ribbon)
	_hud.attach_banner(_ribbon)
	# Ayıklama sinematiği için karartma katmanı (kartların üstünde, zoom kartın altında).
	_cine_dim = ColorRect.new()
	# a=0.78 koyu portrelerde ekranı simsiyah bırakıyordu; kart yine öne çıkıyor.
	_cine_dim.color = Color(0.02, 0.0, 0.01, 0.52)
	_cine_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cine_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cine_dim.z_index = 250
	_cine_dim.visible = false
	add_child(_cine_dim)
	# Gece katmanı (koyu indigo + hilal + yıldızlar; gece avı sekansında belirir).
	_night_layer = Control.new()
	_night_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_night_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_night_layer.z_index = 200
	_night_layer.draw.connect(_draw_night_layer)
	add_child(_night_layer)
	# Kan sıçraması katmanı: ölüm ânında damlalar kartların da ÜSTÜNDE uçar
	# (referans: Demon Bluff ölüm sıçraması; bloody-pool shader'ın birleşen
	# damla fikrinin 2D parçacık uyarlaması).
	_burst_layer = Control.new()
	_burst_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_burst_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burst_layer.z_index = 310
	_burst_layer.draw.connect(_draw_blood_parts)
	add_child(_burst_layer)
	resized.connect(_relayout)
	_connect_events()
	_new_village()


func _connect_events() -> void:
	EventBus.card_executed.connect(_on_card_executed)
	EventBus.character_questioned.connect(_on_questioned)
	EventBus.question_denied.connect(_on_question_denied)
	EventBus.night_passed.connect(_on_night_passed)
	EventBus.slayer_used.connect(_on_slayer_used)
	EventBus.trap_set.connect(func(_tr, target):
		if _hud != null:
			_hud.flash_banner(Loc.t("trap_set") % target, Palette.SAFFRON)
		_refresh_cards())
	EventBus.trap_sprung.connect(func(trapped, caught):
		if _hud != null:
			_hud.flash_banner(Loc.t("trap_sprung") % [trapped, caught], Palette.SAFFRON)
		_recompute_deduction())
	EventBus.mark_changed.connect(func(_s, _m): _refresh_cards())
	EventBus.village_won.connect(_on_village_won)
	EventBus.village_lost.connect(_on_village_lost)


func _new_village() -> void:
	var conf: Dictionary
	if RunManager.has_active_run():
		# Sefer modu: mevcut düğümün (seed'li) config'i.
		conf = RunManager.current_village_config().duplicate()
	else:
		# Bağımsız mod (test/geliştirme): rastgele köy.
		conf = VILLAGE_CONFIG.duplicate()
		conf["seed"] = Rng.randomize_seed()
	Rng.seed_with(int(conf["seed"]))
	var state := VillageGenerator.generate(conf, Rng.rng())
	if state == null:
		push_error("Köy üretilemedi")
		return
	GameState.start_village(state)
	_hud.hide_overlay()
	_hud.update_all()  # üst panelleri HEMEN doldur
	_set_execute_mode(false)
	_hovered_seat = -1
	_night_count = 0
	_blood_stains.clear()
	_blood_parts.clear()
	_sync_grass_night_tint()
	_slayer_seat = -1
	_protect_mode = false
	if _tooltip != null:
		_tooltip.hide_tip()
	_spawn_cards(state.n)
	_relayout()
	_refresh_cards()
	if _log != null:
		_log.set_open(false)
	_recompute_deduction()
	# Kartlar giriş kartı bitene dek görünmesin (deal intro sonunda başlar).
	for card in _cards:
		card.modulate.a = 0.0
	_start_village_intro(conf)
	queue_redraw()


## KÖYE GİRİŞ KARTI: Fader'ın karanlığından çıkarken siyah zemin üstünde perde +
## köy adı + kompozisyon + modifier uyarıları belirir; sonra kart kalkarken deste
## dağıtılır (kullanıcı isteği: "Sürüye Gir" geçişi sahnelensin). Tık = geç.
func _start_village_intro(conf: Dictionary) -> void:
	_cinematic = true
	_intro_done = false
	var v := GameState.village

	_intro_layer = Control.new()
	_intro_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro_layer.z_index = 350
	_intro_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_intro_layer.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_end_village_intro())
	add_child(_intro_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.005, 0.01, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_layer.add_child(bg)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -430
	box.offset_right = 430
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_layer.add_child(box)

	var lines: Array = []  # [Label, gecikme]
	if RunManager.has_active_run():
		var act_i: int = int(RunManager.current_node().get("act", 1))
		var act_keys := ["act_meadow", "act_valley", "act_forest", "act_endless"]
		lines.append(_intro_label(box, Loc.t("act_line") % [act_i, Loc.t(act_keys[clampi(act_i - 1, 0, 3)])],
			18, Palette.SAFFRON.darkened(0.05)))

	# Başlık: boss adı ya da seed'li köy adı (Revoback — menü başlığıyla aynı dil).
	var title_text: String
	if conf.get("boss", false):
		title_text = Loc.t(String(conf.get("boss_name", "boss_default")))
	else:
		title_text = VILLAGE_NAMES[absi(int(conf.get("seed", 0))) % VILLAGE_NAMES.size()]
	var title := _intro_label(box, title_text, 64, Palette.IVORY)
	title.add_theme_font_override("font", FONT_TITLE)
	lines.append(title)

	if conf.get("elite", false):
		lines.append(_intro_label(box, Loc.t("intro_elite_badge"), 17, Palette.SAFFRON))

	# Kompozisyon + gece kuralı tek satırda (köye dair her şey baştan açık — §7.3).
	var comp := Loc.t("intro_comp") % [v.n - v.evil_count - v.outcast_count, v.outcast_count, v.evil_count]
	if v.kills_per_night >= 2:
		comp += Loc.t("intro_kills") % v.kills_per_night
	if v.night_rule == Enums.NightRule.FARTHEST:
		comp += Loc.t("intro_foggy")
	lines.append(_intro_label(box, comp, 17, Palette.IVORY.darkened(0.10)))

	if not v.modifiers.is_empty():
		var mod_lines: Array = []
		for m in v.modifiers:
			mod_lines.append(Loc.t("mod_%s" % m))
		lines.append(_intro_label(box, "⚠ " + "  ·  ".join(mod_lines), 15, Color("f0b53c")))

	lines.append(_intro_label(box, Loc.t("intro_skip"), 12, Color(1, 1, 1, 0.30)))

	# Satırlar sırayla belirip hafif yukarı süzülür.
	for i in range(lines.size()):
		var l: Label = lines[i]
		l.modulate.a = 0.0
		var t := l.create_tween()
		t.tween_interval(0.12 + i * 0.14)
		t.tween_property(l, "modulate:a", 1.0, 0.35)
	# Uzaktan tek uluma — köyün eşiğindeyiz hissi (kısık).
	AudioManager.sfx("howl", -22.0, 1.06)
	# Node'a bağlı tween (sahne değişirse callback güvenle ölür — SceneTreeTimer değil).
	var auto := create_tween()
	auto.tween_interval(2.1)
	auto.tween_callback(_end_village_intro)


func _intro_label(parent: Node, text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Giriş kartını kapat: kart kalkarken deste dağıtılır + HUD içeri kayar.
func _end_village_intro() -> void:
	if _intro_done:
		return
	_intro_done = true
	_cinematic = false
	AudioManager.play_deal()
	_deal_cards()
	_hud.play_intro()
	_maybe_start_tutorial()
	if _intro_layer != null and is_instance_valid(_intro_layer):
		_intro_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t := create_tween()
		t.tween_property(_intro_layer, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
		t.tween_callback(_intro_layer.queue_free)
	_intro_layer = null


## Sefer başı REHBER (§12): yalnız ilk düğümde ve daha önce tamamlanmadıysa.
func _maybe_start_tutorial() -> void:
	if _tutorial != null:
		_tutorial.queue_free()
		_tutorial = null
	if not RunManager.has_active_run() or RunManager.current_index != 0:
		return
	if SaveManager.settings.get("tutorial_done", false):
		return
	_tutorial = TutorialGuide.new()
	add_child(_tutorial)
	_tutorial.finished.connect(func():
		_tutorial = null
		SaveManager.settings["tutorial_done"] = true
		SaveManager.save_settings())
	_tutorial.start()


## Arka planda boş kalan yerlere spritesheet'ten çim tutamları serpiştirir.
## Renk eşleme + dip koyulaştırma + salınım grass_sway.gdshader'da (§10.5).
## Board'un kendi _draw'ı (bg + vinyet) tüm çocukların altında çizildiği için
## katman ilk çocuk yapılır: bg üstünde, kartların/HUD'un altında kalır.
func _build_grass() -> void:
	_grass_layer = Node2D.new()
	add_child(_grass_layer)
	move_child(_grass_layer, 0)
	var sheet_h := float(GRASS_TEXTURE.get_height())
	for spot in GRASS_SPOTS:
		var tuft: Rect2 = GRASS_TUFTS[spot.tuft]
		var spr := Sprite2D.new()
		spr.texture = GRASS_TEXTURE
		spr.region_enabled = true
		spr.region_rect = tuft
		spr.centered = false
		spr.offset = Vector2(-tuft.size.x * 0.5, -tuft.size.y)  # taban-orta pivot
		spr.flip_h = spot.flip
		var mat := ShaderMaterial.new()
		mat.shader = GRASS_SHADER
		mat.set_shader_parameter("region_v", Vector2(tuft.position.y / sheet_h, tuft.end.y / sheet_h))
		mat.set_shader_parameter("phase", spot.pos.x * 0.011)
		mat.set_shader_parameter("sway_px", tuft.size.x * 0.055)
		spr.material = mat
		_grass_layer.add_child(spr)
		_grass_sprites.append(spr)
		_grass_gust.append(0.0)
		_grass_wilt.append(0.0)
	# Alçak sis: çimlerin üstünde, kartların altında (child sırası: grass=0, fog=1).
	_fog = ColorRect.new()
	_fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fog_mat := ShaderMaterial.new()
	fog_mat.shader = FOG_SHADER
	_fog.material = fog_mat
	add_child(_fog)
	move_child(_fog, 1)
	# _ready sırasında size henüz oturmamış olabilir; bir kare sonra tekrar yerleştir.
	_layout_grass.call_deferred()


## Bg "cover" dönüşümü: [scale, offset]. Hem _draw hem çim yerleşimi bunu kullanır
## ki tutamlar her pencere boyutunda bg ile aynı noktada dursun.
func _bg_cover() -> Array:
	var tex_size := Vector2(BG_TEXTURE.get_width(), BG_TEXTURE.get_height())
	var s := maxf(size.x / tex_size.x, size.y / tex_size.y)
	return [s, (size - tex_size * s) * 0.5]


func _layout_grass() -> void:
	if _grass_sprites.is_empty():
		return
	var cover := _bg_cover()
	var s: float = cover[0]
	var off: Vector2 = cover[1]
	for i in range(GRASS_SPOTS.size()):
		var spot: Dictionary = GRASS_SPOTS[i]
		_grass_sprites[i].position = off + spot.pos * s
		_grass_sprites[i].scale = Vector2.ONE * (s * spot.scale)


## Gece kızıl tint'i board _draw'da overlay olarak çizilir ama o overlay çim
## sprite'larının ALTINDA kalır — aynı tint shader uniform'uyla çime de uygulanır.
func _sync_grass_night_tint() -> void:
	var tint := minf(0.34, _night_count * 0.09) if _night_count > 0 else 0.0
	for spr in _grass_sprites:
		spr.material.set_shader_parameter("night_tint", tint)


## Her kare: imleç esintisi (yakın tutamı it, sönümlü bırak), gece rüzgârı
## (_night_alpha ile salınım çarpanı) ve solma sönümü. Yalnız görsel.
func _update_grass_fx(delta: float) -> void:
	if _grass_sprites.is_empty():
		return
	var mouse := get_local_mouse_position()
	var wind := 1.0 + 1.5 * _night_alpha  # gece: rüzgâr sertleşir, şafakta diner
	for i in range(_grass_sprites.size()):
		var spr := _grass_sprites[i]
		var half_h := spr.region_rect.size.y * spr.scale.y * 0.5
		var mid := spr.position - Vector2(0.0, half_h)  # position = taban-orta
		var dist := mouse.distance_to(mid)
		var radius := spr.region_rect.size.x * spr.scale.x * 1.15
		var target := 0.0
		if dist < radius:
			var away := signf(mid.x - mouse.x)
			target = (away if away != 0.0 else 1.0) \
					* (1.0 - dist / radius) * spr.region_rect.size.x * 0.13
		_grass_gust[i] = lerpf(_grass_gust[i], target, minf(1.0, delta * 6.0))
		_grass_wilt[i] = maxf(0.0, _grass_wilt[i] - delta * 0.35)  # ~3 sn'de toparlar
		var mat: ShaderMaterial = spr.material
		mat.set_shader_parameter("push_px", _grass_gust[i])
		mat.set_shader_parameter("sway_mul", wind)
		mat.set_shader_parameter("wilt", _grass_wilt[i])


## Dedüksiyon yardımını tazele: solver dünyaları + çelişki çiftleri.
## Her bilgi olayı (sorgu/gece/ayıklama/kılıç) sonrası çağrılır.
##
## OPTİMİZASYON (n=11-12 + Sonsuz Sürü için): çelişki kontrolü çift başına bir
## solver çağrısı. Bir SORGU yalnız o koltuğun çiftlerini etkileyebilir (iki kişilik
## dürüstlük testi sadece o ikilinin ifadelerine + global kısıtlara bakar) →
## changed_seat verilirse yalnız onun çiftleri yeniden denenir (sorgu başına
## O(konuşan) çağrı; tam matris O(konuşan²) geç köylerde takılma yapıyordu).
## Global kısıt değiştiren olaylarda (gece/ayıklama/kapan/Omen öğrenme) tam matris.
func _recompute_deduction(changed_seat: int = -1) -> void:
	_worlds = []
	if GameState.village == null:
		_conflicts.clear()
		return
	var v := GameState.village
	_worlds = DeductionSolver.solve(v.visible_for_solver())
	# Çelişki: konuşmuş (ve gerçek yüzü açılmamış) iki koltuk aynı anda dürüst-İYİ
	# olamıyorsa ikisini de işaretle — "en az biri yalan söylüyor (ya da Sarhoş)".
	var speakers: Array = []
	for c in v.characters:
		if c.given > 0 and not c.revealed:
			speakers.append(c.seat)
	if changed_seat >= 0 and changed_seat in speakers:
		# Artımlı: önce changed_seat'in eski bağlarını sök, sonra yalnız onun
		# çiftlerini yeniden dene (diğer çiftler bu sorgudan etkilenmez).
		if _conflicts.has(changed_seat):
			for other in _conflicts[changed_seat]:
				_conflicts[other].erase(changed_seat)
				if _conflicts[other].is_empty():
					_conflicts.erase(other)
			_conflicts.erase(changed_seat)
		for s in speakers:
			if s == changed_seat:
				continue
			if not _can_both_be_honest(v, changed_seat, s):
				if not _conflicts.has(changed_seat):
					_conflicts[changed_seat] = []
				if not _conflicts.has(s):
					_conflicts[s] = []
				_conflicts[changed_seat].append(s)
				_conflicts[s].append(changed_seat)
	else:
		_conflicts.clear()
		for i in range(speakers.size()):
			for j in range(i + 1, speakers.size()):
				var a: int = speakers[i]
				var b: int = speakers[j]
				if not _can_both_be_honest(v, a, b):
					if not _conflicts.has(a):
						_conflicts[a] = []
					if not _conflicts.has(b):
						_conflicts[b] = []
					_conflicts[a].append(b)
					_conflicts[b].append(a)
	for card in _cards:
		card.conflict_hint = _conflicts.has(card.seat)
		card.queue_redraw()
	if _log != null and _log.is_open():
		_log.refresh()
	queue_redraw()


## a ve b AYNI ANDA dürüst-İYİ olabilir mi? Kompozisyon + kefiller + cesetler +
## bilinen kimlikler/Omen kısıtı altında ikisinin de tüm ifadeleri doğru olan tek
## bir dünya bile yoksa → çelişki. (Sarhoş payı bilinçli olarak 0: "ikisinden biri
## yanlış konuşuyor" bilgisi Sarhoş ihtimalinde de değerlidir; etiket bunu söyler.)
func _can_both_be_honest(v: VillageState, a: int, b: int) -> bool:
	var vis := {
		"n": v.n,
		"evil_count": v.evil_count,
		"anchors": v.anchors.duplicate(),
		"revealed": [],
		"known": [
			{"seat": a, "alignment": Enums.Alignment.GOOD},
			{"seat": b, "alignment": Enums.Alignment.GOOD},
		],
		"nights": v.night_events,
		"known_omen": v.known_omen,
		"omen_params": v.omen_params,
		"drunk_count": 0,
	}
	for s in [a, b]:
		var c := v.get_character(s)
		for k in range(c.given):
			vis["revealed"].append({"seat": s, "testimony": c.claims[k]})
	for c in v.characters:
		if c.revealed and c.seat != a and c.seat != b:
			vis["known"].append({"seat": c.seat, "alignment": c.alignment})
	return not DeductionSolver.solve(vis).is_empty()


## GECE butonu hover: Av Düzeni önizlemesi — tutarlı TÜM dünyalarda bu gece kimin
## ölebileceğini (birleşim küme) gece mavisiyle vurgula. Cesetlerin kanıt değerini
## oyuncuya öğreten en doğal araç: bakış "kurban → kurt konumu" yönünde kurulur.
func _on_night_hover(hovering: bool) -> void:
	_night_preview = hovering
	_night_risk.clear()
	if hovering and GameState.is_active():
		var v := GameState.village
		if _worlds.is_empty():
			_recompute_deduction()
		var alive := v.alive_seats()
		var seen := {}
		for w in _worlds:
			var vic := NightEngine.pick_victim(w, alive, v.n, -1, v.night_rule)
			if vic >= 0:
				seen[vic] = true
		_night_risk = seen.keys()
	for card in _cards:
		card.night_risk_hint = _night_preview and (card.seat in _night_risk)
		card.queue_redraw()


## Göz kolunun ucu bir karta değince kartı "yokla" (Balatro-vari dokunma tepkisi:
## kart yana yaslanır + ürperir — kart.probe_touch). Sinematikte devre dışı.
func _probe_cards() -> void:
	if _cinematic or _arm_tips.is_empty():
		return
	for card in _cards:
		var cc: Vector2 = card.position + card.size * 0.5
		for tip in _arm_tips:
			var d := cc.distance_to(tip)
			if d < 85.0:
				card.probe_touch(cc - tip, 1.0 - d / 85.0)


## Gece kurbanının yakınındaki tutamlar solar (ceset izi). Mesafe ekran px'i.
func _wilt_grass_near(pos: Vector2) -> void:
	for i in range(_grass_sprites.size()):
		var d := pos.distance_to(_grass_sprites[i].position)
		if d < 300.0:
			_grass_wilt[i] = maxf(_grass_wilt[i], 1.0 - d / 300.0)


func _spawn_cards(n: int) -> void:
	for c in _cards:
		c.queue_free()
	_cards.clear()
	for i in range(n):
		var card: CardView = CardScene.instantiate()
		card.setup(i)
		card.clicked.connect(_on_card_clicked)
		card.right_clicked.connect(_on_card_right_clicked)
		card.hover_changed.connect(_on_card_hover)
		add_child(card)
		_cards.append(card)
	# Tooltip kartların ÜSTÜNde kalsın (en son eklenen en üstte çizilir).
	if _tooltip != null:
		move_child(_tooltip, get_child_count() - 1)


## Kartlar ortak desteden (alt-orta, ekran dışı) TEK TEK dağıtılsın.
func _deal_cards() -> void:
	var deck_pos := Vector2(size.x * 0.5 - CardView.W * 0.5, size.y + 80.0)
	for i in range(_cards.size()):
		_cards[i].deal_in(_cards[i].position, 0.15 + i * 0.13, deck_pos)


## Kart ayıklandı: yüzünü çevir (gerçek kimlik). Evil ise sinematik zoom + fiziksel
## bölünme oynat.
func _on_card_executed(seat: int, was_evil: bool) -> void:
	_animate_seat(seat)
	_recompute_deduction()
	if was_evil and seat < _cards.size():
		var card := _cards[seat]
		await get_tree().create_timer(0.35).timeout  # flip (gerçek kurt yüzü) görünsün
		await _play_execute_cinematic(card)


## Kurt ayıklanınca son bir replik söyler (referans: "Ugh, cheap shot...").
## Loc anahtarları tutulur (const'ta Loc.t çağrılamaz); gösterimde çözülür.
const WOLF_LAST_WORDS := [
	"wolf_last_1",
	"wolf_last_2",
	"wolf_last_3",
	"wolf_last_4",
	"wolf_last_5",
	"wolf_last_6",
]


## Kurt kartı OLDUĞU YERDE pençelenir (zoom/bölünme yok — kullanıcı kararı):
## hafif karartma + kart öne çıkar → replik → iki pençe savuruşu + kan sıçraması →
## kart YARALI/KARARMIŞ hâliyle yerinde KALIR; çevresinde koyulaşan kan lekeleri.
func _play_execute_cinematic(card: CardView) -> void:
	_cinematic = true
	if _tooltip != null:
		_tooltip.hide_tip()
	_cine_dim.visible = true
	_cine_dim.modulate.a = 0.0
	card.z_index = 300
	card.hide_bubble()  # balon sinematikte kalabalık yapıyordu
	# Kurdun koltuğuna kalıcı kan izi (kanıt/atmosfer; köy bitince temizlenir).
	_spawn_blood_stain(card.position + card.size * 0.5)

	# Sahne hafifçe kararır, kart yerinde bir tık büyüyüp öne çıkar.
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_cine_dim, "modulate:a", 0.7, 0.4)
	t.tween_property(card, "scale", Vector2(1.22, 1.22), 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished

	# Son replik: kartın hemen üstünde (ekran içinde kalacak şekilde kelepçeli).
	var line_x := clampf(card.position.x + card.size.x * 0.5, 190.0, size.x - 190.0)
	_show_kill_line(Loc.t(WOLF_LAST_WORDS[_fx_rng.randi_range(0, WOLF_LAST_WORDS.size() - 1)]),
		Vector2(line_x, card.position.y - 30.0))

	await get_tree().create_timer(0.35).timeout
	card.play_execute_death()
	_spawn_blood_burst(card.position + card.size * 0.5)  # savuruş ânında sıçrama
	await get_tree().create_timer(1.5).timeout

	var ft := create_tween()
	ft.set_parallel(true)
	ft.tween_property(_cine_dim, "modulate:a", 0.0, 0.35)
	ft.tween_property(card, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await ft.finished
	_cine_dim.visible = false
	card.z_index = 0
	_cinematic = false


## Anlık kan PATLAMASI: damlalar dışa savrulur, hız yönünde uzar, hızla söner.
## Kalıcı iz ayrı (_spawn_blood_stain) — bu yalnız ölüm ânının şoku.
func _spawn_blood_burst(pos: Vector2) -> void:
	for i in range(22):
		var a := _fx_rng.randf_range(0.0, TAU)
		var spd := _fx_rng.randf_range(90.0, 380.0)
		_blood_parts.append({
			"pos": pos + Vector2(cos(a), sin(a)) * _fx_rng.randf_range(0.0, 26.0),
			"vel": Vector2(cos(a), sin(a)) * spd,
			"r": _fx_rng.randf_range(3.0, 11.0),
			"life": _fx_rng.randf_range(0.5, 0.9),
		})


func _draw_blood_parts() -> void:
	for p in _blood_parts:
		var la: float = clampf(p.life / 0.6, 0.0, 1.0)
		var col := Color(0.72, 0.04, 0.04, 0.9 * la)
		var v: Vector2 = p.vel
		var dirv: Vector2 = v.normalized() if v.length() > 1.0 else Vector2.RIGHT
		# Damla: hız yönünde uzayan üç disk — üst üste binince "birleşen" kan hissi.
		for k in range(3):
			_burst_layer.draw_circle(p.pos - dirv * (p.r * 0.8 * float(k)), p.r * (1.0 - 0.28 * float(k)), col)
		_burst_layer.draw_circle(p.pos, p.r * 0.5, Color(0.45, 0.01, 0.01, 0.9 * la))


## Kurdun koltuğuna prosedürel kan sıçraması üret (blob demeti; _draw çizer).
## Sinematikte parlak, sonra soluk kalıcı iz (köy sonuna dek).
func _spawn_blood_stain(pos: Vector2) -> void:
	var blobs: Array = []
	# Lekeler kartın ETRAFINA oturur (merkezde değil) — ölen kart görünür kalır,
	# çevresi kanla çevrelenir (kullanıcı kararı).
	for i in range(16):
		var ang := _fx_rng.randf_range(0.0, TAU)
		var dist := _fx_rng.randf_range(38.0, 104.0)
		blobs.append({
			"off": Vector2(cos(ang), sin(ang)) * dist * Vector2(1.0, 0.80),
			"r": _fx_rng.randf_range(4.0, 15.0) * (1.0 - dist / 230.0),
		})
	# Birkaç uzun damla sıçrama yönünde.
	var splash_a := _fx_rng.randf_range(0.0, TAU)
	for i in range(4):
		var a2 := splash_a + _fx_rng.randf_range(-0.5, 0.5)
		var d2 := _fx_rng.randf_range(60.0, 118.0)
		blobs.append({
			"off": Vector2(cos(a2), sin(a2)) * d2 * Vector2(1.0, 0.72),
			"r": _fx_rng.randf_range(2.0, 5.0),
		})
	_blood_stains.append({"pos": pos, "blobs": blobs, "alpha": 1.0})


## Sinematikte kurdun son repliği: kızıl, yukarı süzülüp sönen tek satır.
func _show_kill_line(text: String, top_center: Vector2) -> void:
	if _kill_label == null:
		_kill_label = Label.new()
		_kill_label.z_index = 300
		_kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_kill_label.add_theme_font_size_override("font_size", 30)
		_kill_label.add_theme_color_override("font_color", Color(0.78, 0.10, 0.08))
		_kill_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		_kill_label.add_theme_constant_override("shadow_offset_y", 3)
		add_child(_kill_label)
	_kill_label.text = text
	_kill_label.reset_size()
	_kill_label.position = top_center - Vector2(_kill_label.get_minimum_size().x * 0.5, 30.0)
	_kill_label.modulate.a = 0.0
	_kill_label.visible = true
	var t := create_tween()
	t.tween_property(_kill_label, "modulate:a", 1.0, 0.28)
	t.parallel().tween_property(_kill_label, "position:y", _kill_label.position.y - 26.0, 1.6)
	t.tween_interval(0.5)
	t.tween_property(_kill_label, "modulate:a", 0.0, 0.45)
	t.tween_callback(func(): _kill_label.visible = false)


## SORGU: ifade alındı — balon pop + HUD tazele + dedüksiyon yardımı güncelle.
func _on_questioned(seat: int) -> void:
	for card in _cards:
		if card.seat == seat:
			card.pop_bubble()
		else:
			card.refresh()
	if _hud != null:
		_hud.update_all()
	# Müneccim Omen'i öğretmiş olabilir (global kısıt) → tam matris; değilse artımlı.
	var full := GameState.village != null \
			and GameState.village.get_character(seat).role == &"Astrologer"
	_recompute_deduction(-1 if full else seat)
	# Yön/mesafe ifadesi: çember üzerinde otomatik görselleştir.
	if _clue_claim(seat) != null:
		_clue_seat = seat
		_clue_hold = 4.0
		_clue_prog = 0.0


func _on_question_denied(_seat: int, reason: String) -> void:
	if _hud != null:
		_hud.flash_banner(reason.capitalize(), Palette.SAFFRON)


## GECE SEKANSI: karanlık çöker, kurt avlanır (kurban kartları pençelenir), şafak söker.
## GameState.end_day() senkron işledi; burada yalnız görsel sekans oynar.
func _on_night_passed(victims: Array) -> void:
	_night_count += 1
	_sync_grass_night_tint()
	_cinematic = true
	if _tooltip != null:
		_tooltip.hide_tip()
	# Karanlık YAVAŞÇA çöker (alacakaranlık hissi — ani gece basmasın).
	# Gök kararır → letterbox iner → ay doğar → yıldızlar tek tek açılır
	# (sahneleme _draw_night_layer'da alfa eşikleriyle). Sonra bir nefeslik
	# tam-gece sessizliği: oyuncu göğü GÖRSÜN, sonra av başlasın.
	var t := create_tween()
	t.tween_method(_set_night_alpha, 0.0, 1.0, 3.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	await get_tree().create_timer(0.8).timeout
	if _hud != null:
		_hud.flash_banner(Loc.t("night_fell") if victims.is_empty() else Loc.t("night_fell_howls"), Color("9db8e8"))
	await get_tree().create_timer(0.55).timeout
	# Kurbanlar pençelenir.
	for v in victims:
		for card in _cards:
			if card.seat == v:
				card.refresh()
				card.play_night_death()
				var vc: Vector2 = card.position + card.size * 0.5
				_spawn_blood_burst(vc)   # ölen kuzunun çevresine sıçrama (referans)
				_spawn_blood_stain(vc)   # + kalıcı iz: ceset yerini sabahleyin de anlat
				_wilt_grass_near(vc)
				break
		if _hud != null:
			_hud.flash_banner(Loc.t("wolf_attacked") % v, Palette.BLOOD)
		await get_tree().create_timer(0.9).timeout
	if victims.is_empty() and _hud != null:
		_hud.flash_banner(Loc.t("flock_survived"), Palette.SAFFRON)
		await get_tree().create_timer(0.6).timeout
	# Şafak YAVAŞÇA söker (yıldızlar önce kaybolur, gök en son ağarır).
	var t2 := create_tween()
	t2.tween_method(_set_night_alpha, 1.0, 0.0, 2.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t2.finished
	_cinematic = false
	_refresh_cards()
	_recompute_deduction()  # ceset = yeni (yalan söylemeyen) kısıt
	if _hud != null:
		_hud.update_all()
		if GameState.is_active():
			_hud.flash_banner(Loc.t("day_refreshed") % GameState.village.day, Palette.SAFFRON)
	queue_redraw()


func _relayout() -> void:
	_layout_grass()
	if _cards.is_empty():
		return
	var center := Vector2(size.x * 0.5, size.y * 0.5 + 2.0)
	# Büyük köylerde (n>=8) kartları biraz daha dışa it — balonlar üst üste binmesin.
	var n := _cards.size()
	var radius := minf(size.x, size.y) * (0.305 + maxf(0.0, n - 7) * 0.008)
	_slots.clear()
	for i in range(n):
		# Seat 0 tepede, saat yönünde artar (§5.1).
		var ang := -PI * 0.5 + TAU * float(i) / float(n)
		var dir := Vector2(cos(ang), sin(ang))
		var pos := center + dir * radius
		_cards[i].position = pos - _cards[i].size * 0.5
		# Slot (kesikli border ile çizilen boş kart yeri) — dağıtım hedefi.
		_slots.append(Rect2(_cards[i].position, _cards[i].size))
		# Balonu dış-yana koy. Üst/alt ORTA kartlar hariç hep sağ/sol (ekran taşmasın).
		var side := "right"
		if absf(dir.x) >= 0.3:
			side = "right" if dir.x > 0.0 else "left"
		elif dir.y < 0.0:
			side = "right"  # üst-orta: yana
		else:
			side = "bottom"  # yalnız gerçek alt-orta kart
		_cards[i].set_bubble_side(side)


func _refresh_cards() -> void:
	for card in _cards:
		card.refresh()
		var alive := GameState.village.get_character(card.seat).is_alive()
		card.set_executable_hint(_execute_mode and alive)
		card.set_protect_hint(_protect_mode and alive)


## Belirli bir seat'i flip animasyonuyla çevir, diğerlerini sessizce tazele.
func _animate_seat(seat: int) -> void:
	for card in _cards:
		if card.seat == seat:
			card.animate_reveal()
		else:
			card.refresh()
		card.set_executable_hint(_execute_mode and GameState.village.get_character(card.seat).is_alive())


## Atmosfer animasyonu: her kare ilerlet + yeniden çiz. Kozmetik.
func _process(delta: float) -> void:
	_time += delta
	_update_grass_fx(delta)
	_probe_cards()
	# Kan izleri taze kızıldan KOYULAŞMIŞ (kurumuş) kalıcı ize sönümlenir.
	for stn in _blood_stains:
		stn.alpha = maxf(0.55, stn.alpha - delta * 0.35)
	# Anlık kan sıçraması parçacıkları: savrul, yavaşla, sön.
	if not _blood_parts.is_empty():
		var alive_p: Array = []
		for p in _blood_parts:
			p.life -= delta
			if p.life > 0.0:
				p.pos += p.vel * delta
				p.vel *= 1.0 - 4.5 * delta
				alive_p.append(p)
		_blood_parts = alive_p
		_burst_layer.queue_redraw()
	if _sparks.is_empty() and size.x > 0.0:
		_init_sparks()
	for s in _sparks:
		s.y -= s.vy * delta
		s.x += sin(_time * 0.6 + s.phase) * s.drift * delta
		if s.y < -8.0:
			s.y = size.y + 8.0
			s.x = _fx_rng.randf_range(0.0, size.x)

	# Göz bakışını YUMUŞAK takip et (ani sıçrama yok). Hedef: hover kart yönü ya da
	# yavaş idle gezinme.
	var center := Vector2(size.x * 0.5, size.y * 0.5 + 2.0)
	var target := Vector2(sin(_time * 0.5) * 0.32, sin(_time * 0.83 + 1.0) * 0.22)
	if _hovered_seat >= 0 and _hovered_seat < _cards.size():
		var cc: Vector2 = _cards[_hovered_seat].position + _cards[_hovered_seat].size * 0.5
		var d := cc - center
		if d.length() > 1.0:
			target = d.normalized()
	# kritik-sönümlü his: kısa mesafede hızlı, uzakta yumuşak
	_eye_look = _eye_look.lerp(target, clampf(delta * 6.0, 0.0, 1.0))

	# Yön/mesafe ifadesi görünürlüğü: hover öncelikli, sonra otomatik süre.
	_clue_hold = maxf(0.0, _clue_hold - delta)
	var want_seat := -1
	if _hovered_seat >= 0 and _clue_claim(_hovered_seat) != null:
		want_seat = _hovered_seat
	elif _clue_hold > 0.0 and _clue_claim(_clue_seat) != null:
		want_seat = _clue_seat
	if want_seat >= 0:
		if want_seat != _clue_seat:
			_clue_prog = 0.0
		_clue_seat = want_seat
		_clue_alpha = minf(1.0, _clue_alpha + delta * 4.0)
		_clue_prog = minf(1.0, _clue_prog + delta * 2.2)
	else:
		_clue_alpha = maxf(0.0, _clue_alpha - delta * 3.0)

	# Kazanma patlaması parçacıkları (sönümlü uçuş).
	if not _burst.is_empty():
		var alive_b: Array = []
		for p in _burst:
			p.life -= delta * 0.85
			if p.life > 0.0:
				p.pos += p.vel * delta
				p.vel *= 1.0 - 1.8 * delta
				p.rot += delta * 3.0
				alive_b.append(p)
		_burst = alive_b
	queue_redraw()


func _init_sparks() -> void:
	_sparks.clear()
	for i in range(SPARK_COUNT):
		_sparks.append({
			"x": _fx_rng.randf_range(0.0, size.x),
			"y": _fx_rng.randf_range(0.0, size.y),
			"vy": _fx_rng.randf_range(7.0, 26.0),
			"drift": _fx_rng.randf_range(6.0, 22.0),
			"size": _fx_rng.randf_range(1.2, 3.6),
			"phase": _fx_rng.randf_range(0.0, TAU),
			"spd": _fx_rng.randf_range(1.4, 3.2),
			"warm": _fx_rng.randf() < 0.7,  # çoğu safran/bakır, azı soğuk
		})


## Mum ışığı gibi düzensiz titreme (0.7..1.0). İki sinüsün çarpımı = sözde-gürültü.
func _flicker() -> float:
	return 0.82 + 0.18 * sin(_time * 11.0) * sin(_time * 6.3 + 1.1)


func _draw() -> void:
	# Ritüel arka planı (pentagram + kandiller + kafatasları görselde).
	# "cover": en-boyu koruyup ekranı doldur (kırpma).
	var cover := _bg_cover()
	var draw_size := Vector2(BG_TEXTURE.get_width(), BG_TEXTURE.get_height()) * float(cover[0])
	var offset: Vector2 = cover[1]
	# Doku olduğu gibi (renk modülasyonu YOK — kullanıcı kararı).
	draw_texture_rect(BG_TEXTURE, Rect2(offset, draw_size), false)
	# Hafif vinyet/karartma (kenarları koyulaştır, kartlar öne çıksın).
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.01, 0.01, 0.18), true)
	# Geceler geçtikçe arka plan KIZILA kayar (tehdit büyüyor — §10.5 dinamik tint).
	if _night_count > 0:
		var tint := minf(0.34, _night_count * 0.09)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.02, 0.02, tint), true)

	# Bg'deki 5 ritüel mumuna titreyen sıcak parıltı (bg-uzayına sabit, §10.7).
	# Her mumun fazı farklı — senkron yanıp sönmesinler.
	var cs := float(cover[0])
	for ci in range(CANDLE_SPOTS.size()):
		var cp: Vector2 = offset + CANDLE_SPOTS[ci] * cs
		var fl := 0.72 + 0.28 * sin(_time * (6.5 + float(ci) * 0.9) + float(ci) * 2.1) \
				* sin(_time * 3.7 + float(ci) * 1.3)
		for gl in [[52.0, 0.06], [26.0, 0.11], [11.0, 0.18]]:
			draw_circle(cp, gl[0] * cs * fl, Color(1.0, 0.52, 0.18, gl[1] * fl))

	# Kan izleri: ölüm koltuklarının çevresinde kalıcı leke. Taze kan parlak kızıl
	# doğar, zamanla KURUMUŞ koyu kahve-kızıla döner (alpha 1.0 → 0.55 sönümü
	# "tazelik" olarak okunur; leke kaybolmaz, koyulaşır — kullanıcı kararı).
	for stn in _blood_stains:
		var sa: float = stn.alpha
		var fresh := clampf((sa - 0.55) / 0.45, 0.0, 1.0)
		var base := Color(0.20, 0.012, 0.015).lerp(Color(0.55, 0.05, 0.04), fresh)
		for b in stn.blobs:
			draw_circle(stn.pos + b.off, b.r, Color(base.r, base.g, base.b, 0.78))
			draw_circle(stn.pos + b.off, b.r * 0.62, Color(base.r * 0.55, base.g * 0.6, base.b * 0.6, 0.7))

	# Kesikli (dashed) boş kart slotları — kartlar buraya tek tek dağıtılır.
	for slot in _slots:
		_draw_dashed_slot(slot, 13.0, Color(0.92, 0.66, 0.32, 0.34))

	# Merkezde nefes alan ritüel parıltısı (mum titremesiyle modüle).
	var center := Vector2(size.x * 0.5, size.y * 0.5 + 2.0)
	var breathe := 0.5 + 0.5 * sin(_time * 1.15)
	var glow := (0.55 + 0.45 * breathe) * _flicker()
	for layer in [[230.0, 0.05], [150.0, 0.07], [90.0, 0.11], [48.0, 0.16]]:
		var r: float = layer[0] * (0.92 + 0.08 * breathe)
		draw_circle(center, r, Color(0.70, 0.10, 0.08, layer[1] * glow))

	# --- Merkez nazar / kem göz: seçili/hover karta doğru bakar (§10.1) ---
	_draw_eye_arms(center, breathe)     # gözden çıkan dalgalanan koyu kollar
	_draw_eye_backing(center, breathe)  # gözün gömülü olduğu koyu gövde
	_draw_nazar_eye(center, breathe)

	# --- Yön/mesafe ifadesi görselleştirmesi (kavisli ok / adım izi) ---
	if _clue_alpha > 0.01 and _clue_seat >= 0:
		_draw_clue_fx(center)

	# --- Çelişki bağları: hover edilen çelişkili karttan ortaklarına kızıl kesikli hat.
	# Hat kart MERKEZLERİNE değil KENARLARINA bağlanır (kartın altından garip
	# çıkmasın); iki uçta küçük düğüm noktası — "bağ" okunur.
	if _hovered_seat >= 0 and _conflicts.has(_hovered_seat) and _hovered_seat < _cards.size():
		var from: Vector2 = _cards[_hovered_seat].position + _cards[_hovered_seat].size * 0.5
		for other in _conflicts[_hovered_seat]:
			if other < _cards.size():
				var to: Vector2 = _cards[other].position + _cards[other].size * 0.5
				var dirv := (to - from).normalized()
				var a := from + dirv * 96.0
				var b := to - dirv * 96.0
				if a.distance_to(b) > 24.0:
					var lcol := Color(0.86, 0.11, 0.06, 0.7)
					draw_dashed_line(a, b, lcol, 3.0, 12.0)
					draw_circle(a, 4.0, lcol)
					draw_circle(b, 4.0, lcol)

	# Süzülen kıvılcım/toz parçacıkları — 4-köşe yıldız (twinkle).
	for s in _sparks:
		var tw: float = 0.30 + 0.5 * (0.5 + 0.5 * sin(_time * s.spd + s.phase))
		var col := Color(0.96, 0.74, 0.36, tw)  # hepsi sıcak (soğuk mavi arka planla çelişiyordu)
		_draw_star(Vector2(s.x, s.y), s.size * 1.7 * (0.7 + 0.3 * tw), col, _time * 0.4 + s.phase)

	# Kazanma yıldız patlaması (altın, merkezden dışa).
	for p in _burst:
		var la := clampf(p.life, 0.0, 1.0)
		_draw_star(p.pos, p.size * (0.6 + 0.4 * la), Color(1.0, 0.84, 0.42, la), p.rot)
		_draw_star(p.pos, p.size * 0.5 * la, Color(1.0, 0.97, 0.85, la), -p.rot * 0.7)


## Kartın SON ifadesi yön/mesafe tipiyse döndür; değilse null.
func _clue_claim(seat: int) -> TestimonyClaim:
	if GameState.village == null or seat < 0 or seat >= GameState.village.n:
		return null
	var c := GameState.village.get_character(seat)
	if c == null or not c.is_alive() or c.testimony == null:
		return null
	var t := c.testimony
	if t.type == Enums.TestimonyType.NEAREST_EVIL_DIRECTION \
			or t.type == Enums.TestimonyType.NEAREST_EVIL_DISTANCE:
		return t
	return null


## İfade görselleştirmesi: konuşan karttan çember boyunca kavisli ok (yön) ya da
## iki yana adım izi + hedef işareti (mesafe). Referans dili: mor rehber oklar.
func _draw_clue_fx(center: Vector2) -> void:
	var t := _clue_claim(_clue_seat)
	if t == null or _cards.is_empty():
		return
	var n := _cards.size()
	var step := TAU / float(n)
	var a0 := -PI * 0.5 + step * float(_clue_seat)
	# Ok yayı kart çemberinin biraz içinde döner (göz ile kartlar arası boşluk).
	var r := minf(size.x, size.y) * (0.305 + maxf(0.0, n - 7) * 0.008) * 0.80
	if t.type == Enums.TestimonyType.NEAREST_EVIL_DIRECTION:
		match t.direction:
			Enums.Direction.CLOCKWISE:
				_draw_curved_arrow(center, r, a0 + step * 0.30, a0 + step * 1.85, CLUE_VIOLET)
			Enums.Direction.COUNTER_CLOCKWISE:
				_draw_curved_arrow(center, r, a0 - step * 0.30, a0 - step * 1.85, CLUE_VIOLET)
			_:
				# Eşit uzaklık: iki yöne kısa ok.
				_draw_curved_arrow(center, r, a0 + step * 0.30, a0 + step * 1.30, CLUE_VIOLET)
				_draw_curved_arrow(center, r, a0 - step * 0.30, a0 - step * 1.30, CLUE_VIOLET)
	else:
		_draw_distance_trail(center, r, a0, step, t.number, 1)
		_draw_distance_trail(center, r, a0, step, t.number, -1)


static func _ease_out_cubic(p: float) -> float:
	return 1.0 - pow(1.0 - clampf(p, 0.0, 1.0), 3.0)


## Kavisli ok: kuyruktan uca kalınlaşan/parlaklaşan yay + nabızlı ok başı.
func _draw_curved_arrow(center: Vector2, radius: float, ang_from: float, ang_to: float, col: Color) -> void:
	var alpha := _clue_alpha
	var sweep := (ang_to - ang_from) * _ease_out_cubic(_clue_prog)
	var segs := 26
	var pts := PackedVector2Array()
	for i in range(segs + 1):
		var a := ang_from + sweep * float(i) / float(segs)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	for i in range(segs):
		var f := float(i) / float(segs)
		var w := lerpf(2.5, 7.5, f)
		var sa := alpha * lerpf(0.22, 1.0, f)
		draw_line(pts[i], pts[i + 1], Color(col.r, col.g, col.b, sa * 0.30), w + 6.0)  # glow
		draw_line(pts[i], pts[i + 1], Color(col.r, col.g, col.b, sa), w)
	# Ok başı: uç teğeti yönünde üçgen, hafif nabız.
	var tip := pts[segs]
	var tangent := (pts[segs] - pts[segs - 1]).normalized()
	if tangent == Vector2.ZERO:
		return
	var perp := Vector2(-tangent.y, tangent.x)
	var hs := 17.0 * (1.0 + 0.08 * sin(_time * 6.0))
	draw_circle(tip, hs * 0.95, Color(col.r, col.g, col.b, alpha * 0.16))
	draw_colored_polygon(PackedVector2Array([
		tip + tangent * hs,
		tip - tangent * hs * 0.45 + perp * hs * 0.62,
		tip - tangent * hs * 0.45 - perp * hs * 0.62,
	]), Color(col.r, col.g, col.b, alpha))


## Mesafe izi: konuşandan d adım öteye noktalı yay + hedefte nabızlı elmas.
## İki yöne de çizilir — "en yakın kurt d adımda" iki taraftan biri demektir.
func _draw_distance_trail(center: Vector2, radius: float, a0: float, step: float, d: int, dir_sign: int) -> void:
	if d <= 0:
		return
	var alpha := _clue_alpha
	var prog := _ease_out_cubic(_clue_prog)
	var a1 := a0 + float(dir_sign) * step * 0.30
	var a2 := a0 + float(dir_sign) * step * float(d) * prog
	var dots := maxi(2, int(absf(a2 - a1) * radius / 16.0))
	for i in range(dots + 1):
		var f := float(i) / float(dots)
		var a := lerpf(a1, a2, f)
		var p := center + Vector2(cos(a), sin(a)) * radius
		draw_circle(p, 2.6, Color(CLUE_AMBER.r, CLUE_AMBER.g, CLUE_AMBER.b, alpha * lerpf(0.30, 0.85, f)))
	# Hedef koltuk hizasında işaret (yay tamamlanınca belirir).
	if prog > 0.92:
		var ta := a0 + float(dir_sign) * step * float(d)
		var tp := center + Vector2(cos(ta), sin(ta)) * radius
		var s := 9.0 * (1.0 + 0.15 * sin(_time * 5.0))
		draw_circle(tp, s * 1.8, Color(CLUE_AMBER.r, CLUE_AMBER.g, CLUE_AMBER.b, alpha * 0.18))
		draw_colored_polygon(PackedVector2Array([
			tp + Vector2(0, -s), tp + Vector2(s, 0), tp + Vector2(0, s), tp + Vector2(-s, 0),
		]), Color(CLUE_AMBER.r, CLUE_AMBER.g, CLUE_AMBER.b, alpha))


## Merkez nazar / kem göz — SADE: kırmızı gradyan gövde + koyu bebek. Parlama/
## catchlight YOK. Arkasında düz tek siyah border (_draw_eye_backing).
func _draw_nazar_eye(center: Vector2, breathe: float) -> void:
	# Referans: büyük KIRMIZI göz + İRİ koyu bebek (kenara kayınca kızıl HİLAL
	# kalır) + yumuşak kızıl kenar.
	var tw := _time * 1.1
	var rx := 74.0 * (0.98 + 0.03 * breathe)
	var ry := 88.0 * (0.98 + 0.03 * breathe)

	# Gözden dışa yumuşak kızıl kenar (glow) — koyu çevreye sızar (birkaç faint katman).
	for i in range(6):
		var f := float(i) / 6.0
		draw_colored_polygon(_eye_outline(center, rx * (1.0 + f * 0.34), ry * (1.0 + f * 0.32), tw),
			Color(0.72, 0.06, 0.04, 0.11 * (1.0 - f)))

	# Düz kırmızı göz (ince koyu kenar + ana kırmızı — 2 ton, banding yok).
	draw_colored_polygon(_eye_outline(center, rx, ry, tw), Color(0.46, 0.03, 0.02, 1.0))
	draw_colored_polygon(_eye_outline(center, rx * 0.9, ry * 0.9, tw), Color(0.86, 0.11, 0.06, 1.0))

	# İRİ koyu bebek — bakış yönüne kaydıkça kırmızı hilal ortaya çıkar (referans).
	var pc := center + Vector2(_eye_look.x * rx * 0.34, _eye_look.y * ry * 0.30)
	draw_colored_polygon(_eye_outline(pc, rx * 0.58, ry * 0.62, tw), Color(0.05, 0.004, 0.01, 1.0))
	# Bebek çekirdeği: daha da koyu iç (derinlik hissi).
	var cc := pc + Vector2(_eye_look.x * 6.0, _eye_look.y * 5.0)
	draw_colored_polygon(_eye_outline(cc, rx * 0.34, ry * 0.38, tw), Color(0.0, 0.0, 0.0, 1.0))


## Gözün organik konturu: dikey yumurta (elips) + zamanla dalgalanan canlı kenar.
## Aynı wobble tüm ölçeklerde kullanıldığı için katmanlar temiz yuvalanır.
func _eye_outline(c: Vector2, rx: float, ry: float, tw: float) -> PackedVector2Array:
	var seg := 46
	var pts := PackedVector2Array()
	for i in range(seg):
		var a := TAU * float(i) / float(seg)
		var wob := 1.0 + 0.045 * sin(a * 3.0 + tw) + 0.028 * sin(a * 5.0 - tw * 0.6)
		# hafif yumurta: alt yarı biraz daha dolgun
		var yb := sin(a)
		var yr := ry * (1.0 + 0.06 * yb)
		pts.append(c + Vector2(cos(a) * rx * wob, yb * yr * wob))
	return pts


## Gözden çıkan DALGALANAN koyu kollar (yaratık hissi). Her kol incelen, sinüsle
## kıvrılan koyu bir şerit; zamanla sallanır. Gözün arkasında çizilir.
## Kollar ARA ARA kart çemberine kadar uzanır — uç bir karta değince kart
## "yoklanır" (bkz. _probe_cards): göz sürüyü tek tek kontrol ediyor hissi.
func _draw_eye_arms(center: Vector2, breathe: float) -> void:
	var rx := 74.0 * (0.98 + 0.03 * breathe) * 1.48
	var ry := 88.0 * (0.98 + 0.03 * breathe) * 1.36
	var arms := 9
	var col := Color(0.03, 0.006, 0.012, 1.0)
	# Kart çemberi yarıçapı (_relayout ile aynı formül) — kolların max erimi.
	var ring := minf(size.x, size.y) * (0.305 + maxf(0.0, _cards.size() - 7) * 0.008)
	_arm_tips.clear()
	for k in range(arms):
		var base_a := TAU * float(k) / float(arms)
		var ang := base_a + 0.20 * sin(_time * 1.2 + k * 0.8)
		var root := center + Vector2(cos(ang), sin(ang)) * Vector2(rx * 0.72, ry * 0.72)
		# Yavaş, kol başına faz kaymalı nefes: tepe noktasında uç kartlara değer,
		# çukurda gözün dibine çekilir ("ara ara" dokunma motorun kendisinden).
		var stretch := 0.34 + 0.40 * sin(_time * 0.55 + float(k) * 2.3)
		var length := maxf(30.0, ring * (0.42 + stretch) - root.distance_to(center))
		var tip := _draw_wavy_arm(root, ang, length, 16.0 + 4.0 * sin(_time + k), col, k)
		_arm_tips.append(tip)


## Kökten uca incelen, boyunca sinüsle kıvrılan koyu şerit. Uç noktasını döndürür.
func _draw_wavy_arm(root: Vector2, angle: float, length: float, base_w: float, col: Color, idx: int) -> Vector2:
	var seg := 9
	var dir := Vector2(cos(angle), sin(angle))
	var perp := Vector2(-dir.y, dir.x)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(seg + 1):
		var t := float(i) / float(seg)
		var wob := sin(t * 3.2 + _time * 2.2 + idx) * (14.0 * t)  # uca doğru artan kıvrım
		var w := base_w * (1.0 - t) * (1.0 - t)                    # uca doğru incel
		var p := root + dir * (length * t) + perp * wob
		left.append(p + perp * w)
		right.append(p - perp * w)
	var pts := PackedVector2Array()
	for p in left:
		pts.append(p)
	for i in range(right.size()):
		pts.append(right[right.size() - 1 - i])
	draw_colored_polygon(pts, col)
	var tip_wob := sin(3.2 + _time * 2.2 + idx) * 14.0
	return root + dir * length + perp * tip_wob


## Kırmızı gözün gömülü olduğu KOYU YARATIK GÖVDESİ: loblu, yavaş dalgalanan
## organik kütle + kenarında için için yanan kızıl çatlaklar (referans: dev tek
## gözlü gölge-yaratık).
func _draw_eye_backing(center: Vector2, breathe: float) -> void:
	var rx := 74.0 * (0.98 + 0.03 * breathe) * 1.48
	var ry := 88.0 * (0.98 + 0.03 * breathe) * 1.36
	# Dış yumuşak gölge (gövde zemine sızar).
	draw_colored_polygon(_blob_outline(center, rx * 1.18, ry * 1.15, _time * 0.7, 2.0),
		Color(0.02, 0.005, 0.01, 0.55))
	# Ana gövde.
	draw_colored_polygon(_blob_outline(center, rx, ry, _time * 0.7, 0.0),
		Color(0.045, 0.012, 0.018, 1.0))


## Loblu organik gövde konturu: _eye_outline'dan daha güçlü, çok frekanslı dalga.
func _blob_outline(c: Vector2, rx: float, ry: float, tw: float, seed_off: float) -> PackedVector2Array:
	var seg := 56
	var pts := PackedVector2Array()
	for i in range(seg):
		var a := TAU * float(i) / float(seg)
		var wob := 1.0 \
			+ 0.09 * sin(a * 4.0 + tw + seed_off) \
			+ 0.055 * sin(a * 7.0 - tw * 0.7 + seed_off * 2.0) \
			+ 0.04 * sin(a * 2.0 + tw * 0.5)
		pts.append(c + Vector2(cos(a) * rx * wob, sin(a) * ry * wob))
	return pts


## Göz gradyan rengi: t=0 kenar (koyu kan) -> t=1 merkez (sıcak kor). eg parlaklık.
func _eye_grad(t: float, eg: float) -> Color:
	var edge := Color(0.24, 0.02, 0.02)
	var mid := Color(0.82, 0.12, 0.06)
	var core := Color(1.0, 0.58, 0.26)
	var c: Color
	if t < 0.58:
		c = edge.lerp(mid, t / 0.58)
	else:
		c = mid.lerp(core, (t - 0.58) / 0.42)
	return Color(c.r * eg, c.g * eg, c.b * eg, 1.0)


func _set_night_alpha(v: float) -> void:
	_night_alpha = v
	if _night_layer != null:
		_night_layer.queue_redraw()
	# Gece çökerken HUD tamamen çekilir — sahnede yalnız gök + kartlar + şerit kalır.
	if _hud != null:
		_hud.set_night_dim(v)


## Gece göğü: koyu indigo kaplama + parlayan HİLAL + titreyen yıldızlar.
## Alt kenardan yukarı hafif gradyan (ufuk hâlâ seçilsin).
func _draw_night_layer() -> void:
	if _night_alpha <= 0.0:
		return
	var a := _night_alpha
	var sz := _night_layer.size
	# SAHNELEME: her öğe farklı alfa aralığında girer (gerçek alacakaranlık sırası).
	# gök 0.00-0.60 · letterbox 0.10-0.55 · ay 0.30-0.80 · yıldızlar 0.45-1.00.
	var sky := clampf(a / 0.60, 0.0, 1.0)
	var lba := clampf((a - 0.10) / 0.45, 0.0, 1.0)
	var moon_a := clampf((a - 0.30) / 0.50, 0.0, 1.0)
	# Gece iyice karanlık bassın (kullanıcı isteği) — çift katman.
	_night_layer.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.015, 0.02, 0.08, 0.78 * sky), true)
	# üstte daha koyu bant (gökyüzü hissi)
	_night_layer.draw_rect(Rect2(Vector2.ZERO, Vector2(sz.x, sz.y * 0.35)), Color(0.008, 0.015, 0.06, 0.5 * sky), true)

	# Sinematik letterbox bantları: ekran dışından SÜZÜLEREK iner/çıkar.
	var lb := 64.0 * _ease_out_cubic(lba)
	if lb > 0.5:
		_night_layer.draw_rect(Rect2(Vector2.ZERO, Vector2(sz.x, lb)), Color(0, 0, 0, 0.92 * lba), true)
		_night_layer.draw_rect(Rect2(Vector2(0, sz.y - lb), Vector2(sz.x, lb)), Color(0, 0, 0, 0.92 * lba), true)
		_night_layer.draw_line(Vector2(0, lb), Vector2(sz.x, lb), Color(0.79, 0.45, 0.23, 0.28 * lba), 1.5)
		_night_layer.draw_line(Vector2(0, sz.y - lb), Vector2(sz.x, sz.y - lb), Color(0.79, 0.45, 0.23, 0.28 * lba), 1.5)

	# Hilal: ufuktan DOĞAR (alfayla yukarı süzülür), dolu ay + gök-rengi ısırık.
	if moon_a > 0.01:
		var rise := (1.0 - _ease_out_cubic(moon_a)) * 70.0
		var mc := Vector2(sz.x * 0.86, sz.y * 0.16 + rise)
		for g in range(4):
			_night_layer.draw_circle(mc, 34.0 + g * 10.0, Color(0.85, 0.88, 1.0, 0.045 * moon_a * (1.0 - g * 0.2)))
		_night_layer.draw_circle(mc, 30.0, Color(0.92, 0.93, 0.98, 0.95 * moon_a))
		_night_layer.draw_circle(mc + Vector2(-12, -7), 26.0, Color(0.05, 0.06, 0.14, 0.97 * moon_a))

	# Yıldızlar: TEK TEK, parlayıp yerine oturarak açılır ("pop"); zamanla titrer.
	# Büyükler artı-parıltılı — gökyüzü gerçekten dolu ve okunur hissetsin.
	for i in range(42):
		var fx := fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
		var fy := fposmod(sin(float(i) * 78.233) * 12578.1459, 1.0)
		var star_a := clampf((a - 0.40 - fx * 0.42) / 0.16, 0.0, 1.0)
		if star_a <= 0.0:
			continue
		var sp := Vector2(fx * sz.x, fy * sz.y * 0.52)
		var tw := 0.5 + 0.5 * (0.5 + 0.5 * sin(_time * (1.5 + fx * 2.0) + float(i)))
		var pop := 1.0 + (1.0 - star_a) * 2.2  # doğarken büyük parlar, oturur
		var r := (1.8 + fx * 1.8) * pop
		var col := Color(0.92, 0.94, 1.0, tw * star_a)
		_night_layer.draw_circle(sp, r, col)
		# Parlak yıldızlarda ince artı-ışıma.
		if fx > 0.62:
			var arm := r * 2.6 * tw
			_night_layer.draw_line(sp + Vector2(-arm, 0), sp + Vector2(arm, 0),
				Color(col.r, col.g, col.b, col.a * 0.55), 1.2)
			_night_layer.draw_line(sp + Vector2(0, -arm), sp + Vector2(0, arm),
				Color(col.r, col.g, col.b, col.a * 0.55), 1.2)


## Kazanma yıldız patlaması: merkezden dışa uçan altın yıldızlar.
func _spawn_win_burst() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	for i in range(46):
		var ang := _fx_rng.randf_range(0.0, TAU)
		var spd := _fx_rng.randf_range(140.0, 520.0)
		_burst.append({
			"pos": center,
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"life": _fx_rng.randf_range(0.7, 1.25),
			"size": _fx_rng.randf_range(3.0, 8.0),
			"rot": _fx_rng.randf_range(0.0, TAU),
		})


## Kesikli kenarlı boş kart slotu: hafif dolgu + köşeleri yuvarlak dashed border.
## Kartlar dağıtılınca üstünü kapatır; "buraya kart gelecek" hissini verir.
func _draw_dashed_slot(rect: Rect2, radius: float, col: Color) -> void:
	# hafif iç dolgu
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.0, 0.0, 0.0, 0.16)
	fill.set_corner_radius_all(int(radius))
	draw_style_box(fill, rect)
	# kesikli kenarlar (düz kısımlar; köşeler yuvarlaklık için boş bırakılır)
	var dash := 9.0
	var gap := 7.0
	var r := radius
	var p := rect.position
	var s := rect.size
	_dashed_line(p + Vector2(r, 0), p + Vector2(s.x - r, 0), dash, gap, col)          # üst
	_dashed_line(p + Vector2(r, s.y), p + Vector2(s.x - r, s.y), dash, gap, col)        # alt
	_dashed_line(p + Vector2(0, r), p + Vector2(0, s.y - r), dash, gap, col)            # sol
	_dashed_line(p + Vector2(s.x, r), p + Vector2(s.x, s.y - r), dash, gap, col)        # sağ


func _dashed_line(a: Vector2, b: Vector2, dash: float, gap: float, col: Color) -> void:
	var dir := b - a
	var total := dir.length()
	if total <= 0.0:
		return
	dir = dir / total
	var t := 0.0
	while t < total:
		var e := minf(t + dash, total)
		draw_line(a + dir * t, a + dir * e, col, 2.0)
		t += dash + gap


## 4-köşe parıltı yıldızı. Çok küçük yarıçapta poligon dejenere olup
## "triangulation failed" hatası basıyordu — o boyutta zaten görünmez, atla.
func _draw_star(c: Vector2, r: float, col: Color, rot: float) -> void:
	if r < 0.75:
		return
	var pts := PackedVector2Array()
	for i in range(8):
		var a := rot + PI * float(i) / 4.0
		var rr := r if i % 2 == 0 else r * 0.34
		pts.append(c + Vector2(cos(a) * rr, sin(a) * rr))
	draw_colored_polygon(pts, col)


# --- giriş ---

func _on_card_clicked(seat: int) -> void:
	if _cinematic or not GameState.is_active():
		return
	# AĞIL: koruma seçim modundaysa bu tık koruma + gece.
	if _protect_mode:
		var pc := GameState.village.get_character(seat)
		if not pc.is_alive():
			if _hud != null:
				_hud.flash_banner(Loc.t("pen_dead_denied"), Color("9db8e8"))
			return
		_protect_mode = false
		_refresh_cards()
		if _hud != null:
			_hud.flash_banner(Loc.t("pen_protected") % seat, Color("9db8e8"))
		GameState.end_day(seat)
		return
	# Aktif yetenek (Kılıççı/Avcı) hedefleme modu: sıradaki tık hedef (aynı karta tık = iptal).
	if _slayer_seat >= 0:
		var sl := _slayer_seat
		_slayer_seat = -1
		if seat == sl:
			if _hud != null:
				_hud.set_execute_mode(false)  # banner'ı sıfırla
		elif GameState.village.get_character(sl).role == &"Hunter":
			GameState.hunt(sl, seat)
		elif GameState.village.get_character(sl).role == &"Trapper":
			GameState.arm_trap(sl, seat)
		else:
			GameState.slay(sl, seat)
		_refresh_cards()
		return
	if _execute_mode:
		GameState.execute(seat)
		_set_execute_mode(false)
		return
	# Kılıççı/Avcı'ya tıklama → hedefleme moduna gir (yetenek; sorgu değil).
	var c := GameState.village.get_character(seat)
	if c.is_alive() and not c.ability_used and not c.is_evil() \
			and (c.role == &"Slayer" or c.role == &"Hunter" or c.role == &"Trapper"):
		_slayer_seat = seat
		if _hud != null:
			var vt := Loc.t("target_verb_slay")
			if c.role == &"Hunter":
				vt = Loc.t("target_verb_hunt")
			elif c.role == &"Trapper":
				vt = Loc.t("target_verb_trap")
			_hud.flash_banner(Loc.t("target_pick") % [RoleNames.display(c.role).to_upper(), vt], Palette.SAFFRON)
		_refresh_cards()
		return
	# V2: tık = SORGU (1 hak harcar; karakter sıradaki ifadesini verir).
	GameState.question(seat)


## Günü bitir (HUD butonu ya da G tuşu). İKİ AŞAMALI — AĞIL (koruma) + emniyet:
## 1. basış: koruma seçim modu açılır ("koyacağın kartı seç ya da tekrar bas").
## 2. basış: korumasız gece. Kart seçilirse: o kart ağıla alınıp gece çöker.
func _on_end_day() -> void:
	if _cinematic or not GameState.is_active():
		return
	_slayer_seat = -1
	_set_execute_mode(false)
	if not _protect_mode:
		_protect_mode = true
		if _hud != null:
			var extra := ""
			if GameState.village.questions_left > 0:
				extra = Loc.t("pen_qwarn") % GameState.village.questions_left
			_hud.flash_banner(Loc.t("pen_prompt") % extra, Color("9db8e8"))
		_refresh_cards()  # mavi koruma halesi
		return
	_protect_mode = false
	_refresh_cards()
	GameState.end_day(-1)


## Kılıç sonucu banner'ı.
func _on_slayer_used(_slayer_seat_arg: int, target: int, hit: bool) -> void:
	if _hud == null:
		return
	if hit:
		_hud.flash_banner(Loc.t("slayer_hit"), Palette.SAFFRON)
	else:
		_hud.flash_banner(Loc.t("slayer_miss") % target, Palette.BLOOD)


func _on_card_right_clicked(seat: int) -> void:
	if GameState.village == null:
		return
	var cur: int = GameState.village.marks[seat]
	var idx := MARK_CYCLE.find(cur)
	var next: int = MARK_CYCLE[(idx + 1) % MARK_CYCLE.size()]
	GameState.set_mark(seat, next)


func _on_card_hover(seat: int, entered: bool) -> void:
	if entered:
		_hovered_seat = seat
		if _tooltip != null and seat < _cards.size():
			var card := _cards[seat]
			_tooltip.show_for(seat, Rect2(card.position, card.size), size, card.get_bubble_side())
	else:
		if _hovered_seat == seat:
			_hovered_seat = -1
			if _tooltip != null:
				_tooltip.hide_tip()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Giriş kartı açıkken herhangi bir tuş = geç.
		if not _intro_done and _intro_layer != null and is_instance_valid(_intro_layer):
			_end_village_intro()
			return
		# 1–5: üstüne gelinen karta mark koy.
		if _hovered_seat >= 0 and MARK_KEYS.has(event.keycode):
			GameState.set_mark(_hovered_seat, MARK_KEYS[event.keycode])
			return
		match event.keycode:
			KEY_E:
				# E: ayıklama modunu aç/kapat. (ESC artık global duraklat menüsü.)
				if GameState.is_active():
					_toggle_execute_mode()
			KEY_G:
				# G: günü bitir (gece).
				_on_end_day()
			KEY_R:
				if not _cinematic:
					_new_village()


## TAB burada (unhandled değil): UI odak gezintisi (buton sekmesi) TAB'ı yutuyordu.
## _input odaktan ÖNCE çalışır; olayı işleyip yutarız → defter güvenilir açılır.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_TAB:
		if _log != null:
			_log.toggle()
		get_viewport().set_input_as_handled()


func _on_village_won(_score: int) -> void:
	_set_execute_mode(false)
	_spawn_win_burst()  # altın yıldız patlaması (sinematikle birlikte)
	# Zafer ânında sahne SADELEŞSİN: balonlar ve tooltip kalksın — kutlama yazıları
	# kart/balon kalabalığının üstüne binmesin (kullanıcı geri bildirimi).
	if _tooltip != null:
		_tooltip.hide_tip()
	for card in _cards:
		card.hide_bubble()
	if _log != null:
		_log.set_open(false)
	# Son kurt ayıklanınca HEMEN sonuç ekranına atlama; pençe sinematiği (~2.7 sn)
	# görünsün, sonra geç. (Bağımsız modda HUD overlay'i sinematik sonrası gelir.)
	if RunManager.has_active_run():
		await get_tree().create_timer(3.2).timeout
		RunManager.on_village_won(GameState.score, GameState.health)
		if RunManager.has_active_run():
			# ROL DRAFT'I burada — zaferin hemen ardından, köyden ayrılmadan
			# (kullanıcı kararı: haritada geç geliyordu). Seçim bitince haritaya.
			if RunManager.pending_draft:
				var draft := DraftOverlay.new()
				add_child(draft)
				await draft.closed
			# Köy kazanıldı, sefer sürüyor → haritaya dön (dükkân/olay artık DÜĞÜM).
			Fader.change_scene.call_deferred("res://scenes/run_map.tscn")
		else:
			# Boss alt edildi / sefer bitti → sonuç ekranı.
			_go_to_result()


func _on_village_lost(_reason: String) -> void:
	_set_execute_mode(false)
	await _play_lose_cinematic()
	if RunManager.has_active_run():
		RunManager.on_village_lost()
		_go_to_result()


## SÜRÜ DÜŞTÜ sinematiği: kızıl karanlık çöker, hayattaki kurtlar sırayla postu
## atıp gerçek yüzünü gösterir, son söz ekrana düşer. Sonra sonuç ekranı (sefer)
## ya da HUD overlay'i (bağımsız mod — hud 3.4 sn gecikmeli gösterir).
func _play_lose_cinematic() -> void:
	_cinematic = true
	if _tooltip != null:
		_tooltip.hide_tip()
	if _log != null:
		_log.set_open(false)
	_cine_dim.visible = true
	_cine_dim.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_cine_dim, "modulate:a", 0.85, 0.6)
	await t.finished
	for card in _cards:
		var ch := GameState.village.get_character(card.seat)
		if ch != null and ch.is_evil() and not ch.executed:
			ch.revealed = true
			card.z_index = 300
			card.hide_bubble()
			card.animate_reveal()
			AudioManager.sfx("cull_good", -10.0, 0.55)
			await get_tree().create_timer(0.55).timeout
	_show_kill_line(Loc.t("wolves_win_line"), Vector2(size.x * 0.5, size.y * 0.24))
	await get_tree().create_timer(2.0).timeout
	_cinematic = false


func _go_to_result() -> void:
	# Sinyal içinde sahne değiştirme; freed olurken güvenli olsun diye deferred.
	Fader.change_scene.call_deferred("res://scenes/result.tscn")


func _toggle_execute_mode() -> void:
	_set_execute_mode(not _execute_mode)


func _set_execute_mode(on: bool) -> void:
	_slayer_seat = -1
	if on:
		_protect_mode = false  # ayıklama moduna geçiş korumayı iptal eder
	_execute_mode = on and GameState.is_active()
	if _hud != null:
		_hud.set_execute_mode(_execute_mode)
	_refresh_cards()
