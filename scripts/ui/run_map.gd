extends Control

## Sefer haritası / ana hub. Bkz. CLAUDE.md §4, §11 (RunMap).
## İki mod: ANA MENÜ (sefer yok — büyük nazar gözü + merkez butonlar) ve
## SEFER HARİTASI (düğüm zinciri + devam). Atmosfer ScreenFx'te (board ile aynı dil).

const NODE_R := 26.0

## Ana menü görseli: koyun postlu kurt SAĞ yarıda, pentagram ortada — menü/başlık
## SOL yarıya yerleşir (görsel kompozisyonla sözleşme; değişirse yerleşimi güncelle).
const MENU_BG: Texture2D = preload("res://assets/art/bg/menu_bg.png")
const MAP_BG: Texture2D = preload("res://assets/art/bg/run_map_bg.png")
## Başlık fontu (Revoback, medieval-tall). Yalnız oyun adında — Türkçe gövde
## metinlerinde glyph riski var; onlar proje fontunda (Aminute) kalır.
const FONT_TITLE: Font = preload("res://assets/fonts/Revoback.ttf")

var _fx: ScreenFx
var _map_layer: Control        ## düğüm zinciri bu katmana çizilir (ScreenFx'in üstünde)
var _title: Label
var _subtitle: Label
var _info: Label
var _action_btn: Button
var _asc_btn: Button
var _daily_btn: Button
var _seed_row: HBoxContainer   ## tohumlu sefer girişi (yalnız menüde)
var _seed_edit: LineEdit
var _life_layer: Control       ## yaşayan menü: yanıp sönen kurt gözleri
var _eyes: Array = []          ## aktif göz çiftleri: {pos, t, dur, gap}
var _eye_timer := 0.0
var _life_rng := RandomNumberGenerator.new()
var _settings_btn: Button
var _cases_btn: Button         ## V3.1: el yapımı vakalar menüsü
var _cases_layer: Control      ## vaka seçim overlay'i
var _btn_row: BoxContainer     ## ikincil butonlar (menüde dikey sütun, seferde yatay sıra)
var _records_panel: PanelContainer
var _skip_btn: Button          ## elit köyü atla (yalnız ELITE düğümünde görünür)
var _draft_layer: Control      ## rol draft'ı overlay'i (köy zaferi sonrası)
var _pending_ascension := 0
var _howl_t := 9.0             ## menüde uzak kurt uluması sayacı
var _t := 0.0
var _map_intro := 0.0    ## harita giriş animasyonu saati (düğümler sırayla belirir)

## Menü görselindeki pentagram mumlarının konumları (bg uzayı 3840×2160) — _draw_life
## menüde bunlara titrek kandil parıltısı çizer (görselle sözleşme).
const MENU_CANDLES := [
	Vector2(2093, 860), Vector2(1786, 1046), Vector2(2400, 1023),
	Vector2(1920, 1302), Vector2(2285, 1302), Vector2(2093, 1094),
]


## V3.1 VAKALAR: el yapımı, isimli, sabit seed'li senaryolar (bkz. CLAUDE.md §0.7).
## Testler her config'in üretilebilirliğini doğrular (_test_night_traffic2).
const CASES := [
	{"key": "case_herb", "cfg": {"n": 7, "evil_count": 2, "demon_count": 1, "anchor_count": 1,
		"herbalist": true, "q_per_day": 3, "max_days": 5, "seed": 731001}},
	{"key": "case_quiet", "cfg": {"n": 9, "evil_count": 2, "demon_count": 1, "anchor_count": 2,
		"herbalist": true, "watcher": true, "wanderer": true, "q_per_day": 3, "max_days": 5, "seed": 731002}},
	{"key": "case_trails", "cfg": {"n": 9, "evil_count": 3, "demon_count": 1, "anchor_count": 2,
		"hound": true, "night_rule": Enums.NightRule.FARTHEST, "omen_type": Enums.OmenType.DISPERSED,
		"q_per_day": 4, "max_days": 6, "seed": 731003}},
	{"key": "case_prowl", "cfg": {"n": 10, "evil_count": 3, "demon_count": 1, "anchor_count": 2,
		"herbalist": true, "watcher": true, "wanderer": true, "prowler": true,
		"omen_type": Enums.OmenType.PARITY, "q_per_day": 4, "max_days": 6, "seed": 731004}},
	{"key": "case_moody", "cfg": {"n": 10, "evil_count": 3, "demon_count": 1, "anchor_count": 2,
		"alternating": true, "hound": true, "drunk_count": 1, "q_per_day": 4, "max_days": 6, "seed": 731005}},
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ensure_save_loaded()
	GameState.case_config = {}  # haritaya dönüş vaka modunu kapatır
	_pending_ascension = RunManager.max_ascension_unlocked
	_build()
	_refresh()
	_play_intro()


func _process(delta: float) -> void:
	_t += delta
	_map_intro += delta
	# Çalılarda gözler: ara ara bir çift amber göz belirir, göz kırpar, kaybolur.
	_eye_timer -= delta
	if _eye_timer <= 0.0:
		_eye_timer = _life_rng.randf_range(3.5, 8.0)
		var spots := [
			Vector2(0.07, 0.20), Vector2(0.13, 0.74), Vector2(0.88, 0.16),
			Vector2(0.93, 0.66), Vector2(0.44, 0.92), Vector2(0.62, 0.05),
		]
		_eyes.append({
			"pos": spots[_life_rng.randi() % spots.size()],
			"t": 0.0, "dur": _life_rng.randf_range(2.4, 3.6),
			"gap": _life_rng.randf_range(9.0, 13.0),
		})
	for e in _eyes:
		e.t += delta
	_eyes = _eyes.filter(func(e): return e.t < e.dur)
	if _life_layer != null:
		_life_layer.queue_redraw()
	if _map_layer != null and RunManager.has_active_run():
		_map_layer.queue_redraw()  # aktif düğüm nabzı + giriş animasyonu
	# MENÜ CİLASI: başlık nefes alır + ara ara uzaktan kurt ulur (yalnız menüde).
	if not RunManager.has_active_run():
		if _title != null:
			_title.modulate.a = 0.90 + 0.10 * sin(_t * 1.3)
		_howl_t -= delta
		if _howl_t <= 0.0:
			_howl_t = _life_rng.randf_range(24.0, 42.0)
			AudioManager.sfx("howl", -16.0, _life_rng.randf_range(0.85, 1.0))


func _ensure_save_loaded() -> void:
	if not RunManager.save_loaded:
		SaveManager.load_game()
		RunManager.save_loaded = true


func _build() -> void:
	_fx = ScreenFx.new()
	# Doku/tint _refresh'te moda göre atanır: menüde kurt görseli, seferde orman.
	_fx.bg_texture = MAP_BG
	_fx.tint = Color(0.88, 0.90, 0.92)
	_fx.overlay = Color(0.02, 0.03, 0.04, 0.22)
	add_child(_fx)

	# YAŞAYAN MENÜ: alçak sis + çalılarda ara ara yanıp sönen kurt gözleri.
	var fog := ColorRect.new()
	fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fog_mat := ShaderMaterial.new()
	fog_mat.shader = preload("res://assets/art/bg/ground_fog.gdshader")
	fog_mat.set_shader_parameter("density", 0.10)
	fog.material = fog_mat
	add_child(fog)
	_life_layer = Control.new()
	_life_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_life_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_life_layer.draw.connect(_draw_life)
	add_child(_life_layer)
	_life_rng.randomize()  # kozmetik — gameplay Rng stream'ine dokunmaz

	_map_layer = Control.new()
	_map_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_layer.draw.connect(_draw_map)
	add_child(_map_layer)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 52)
	_title.add_theme_color_override("font_color", Palette.IVORY)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 380
	_title.offset_bottom = 448
	add_child(_title)

	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override("font_size", 18)
	_subtitle.add_theme_color_override("font_color", Palette.SAFFRON.darkened(0.05))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_subtitle.offset_top = 452
	_subtitle.offset_bottom = 486
	add_child(_subtitle)

	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 17)
	_info.add_theme_color_override("font_color", Palette.IVORY.darkened(0.06))
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_info.offset_top = 494
	_info.offset_bottom = 560
	add_child(_info)

	# Birincil buton: yeni sefer / sürüye gir.
	_action_btn = Button.new()
	_action_btn.anchor_left = 0.5
	_action_btn.anchor_right = 0.5
	_action_btn.offset_left = -170
	_action_btn.offset_right = 170
	_action_btn.offset_top = 574
	_action_btn.offset_bottom = 634
	ScreenFx.style_button(_action_btn, Palette.CRIMSON.darkened(0.15), 24)
	_action_btn.pressed.connect(_on_action)
	_action_btn.mouse_entered.connect(func(): AudioManager.sfx("mark", -14.0, 1.3))
	add_child(_action_btn)

	# Elit köyü atla (yalnız ELITE düğümünde; elit her zaman İSTEĞE BAĞLI).
	_skip_btn = Button.new()
	_skip_btn.anchor_left = 0.5
	_skip_btn.anchor_right = 0.5
	_skip_btn.offset_left = 190
	_skip_btn.offset_right = 440
	_skip_btn.offset_top = 706
	_skip_btn.offset_bottom = 754
	ScreenFx.style_button(_skip_btn, Color(0.10, 0.06, 0.08, 0.96), 16)
	_skip_btn.text = Loc.t("btn_skip_elite")
	_skip_btn.visible = false
	_skip_btn.pressed.connect(func():
		RunManager.skip_elite()
		_refresh())
	add_child(_skip_btn)

	# Telif satırı (sol-alt, silik) — stüdyo kimliği her ekranda küçükçe dursun.
	var copyright := Label.new()
	copyright.text = "© 2026 Codezu"
	copyright.add_theme_font_size_override("font_size", 12)
	copyright.add_theme_color_override("font_color", Color(1, 1, 1, 0.28))
	copyright.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	copyright.position = Vector2(16, -30)
	add_child(copyright)

	# İkincil butonlar: zorluk + kurallar + karakterler + ayarlar.
	# BoxContainer: menüde dikey sütun (sol yarı), aktif seferde yatay sıra (_refresh).
	_btn_row = BoxContainer.new()
	_btn_row.add_theme_constant_override("separation", 18)
	_btn_row.anchor_left = 0.5
	_btn_row.anchor_right = 0.5
	# 4 buton × 190 + 3 aralık × 18 = 814 → yarı 407 (sabit; resized-yarışı olmasın).
	_btn_row.offset_left = -407
	_btn_row.offset_right = 407
	_btn_row.offset_top = 660
	_btn_row.offset_bottom = 710
	add_child(_btn_row)

	# Sadeleştirilmiş menü (kullanıcı kararı): Kurallar oyun içi "?" butonunda ve
	# ESC menüsünde; Karakterler Ayarlar ekranından açılır. Menü kalabalık olmasın.
	_asc_btn = _secondary_btn(_btn_row, Loc.t("map_asc_btn") % 1, _cycle_ascension)
	_daily_btn = _secondary_btn(_btn_row, Loc.t("btn_daily"), _start_daily)
	_cases_btn = _secondary_btn(_btn_row, Loc.t("btn_cases"), _toggle_cases)
	_settings_btn = _secondary_btn(_btn_row, Loc.t("menu_settings"), func(): Fader.change_scene("res://scenes/settings.tscn"))
	_build_cases_layer()

	# Tohumlu sefer: arkadaşının kopyaladığı TOHUM ile birebir aynı seferi oyna
	# (skor yarışı — determinizm §13.6). Yalnız menüde (aktif sefer yokken) görünür.
	_seed_row = HBoxContainer.new()
	_seed_row.add_theme_constant_override("separation", 10)
	_seed_row.anchor_left = 0.5
	_seed_row.anchor_right = 0.5
	_seed_row.offset_left = -220
	_seed_row.offset_right = 220
	_seed_row.offset_top = 722
	_seed_row.offset_bottom = 756
	add_child(_seed_row)
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = Loc.t("map_seed_placeholder")
	_seed_edit.custom_minimum_size = Vector2(280, 34)
	_seed_edit.add_theme_font_size_override("font_size", 14)
	_seed_row.add_child(_seed_edit)
	var seed_btn := Button.new()
	seed_btn.text = Loc.t("map_seed_btn")
	seed_btn.custom_minimum_size = Vector2(140, 34)
	ScreenFx.style_button(seed_btn, Color(0.10, 0.06, 0.08, 0.96), 14)
	seed_btn.pressed.connect(_start_seeded)
	_seed_row.add_child(seed_btn)

	# Rekorlar: alt-orta pahlı siyah panel.
	_records_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.88)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(14)
	sb.border_color = Palette.COPPER.darkened(0.25)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_offset = Vector2(6, 7)
	sb.shadow_size = 1
	_records_panel.add_theme_stylebox_override("panel", sb)
	# Yatay ortalama: anchor noktası etrafında iki yöne büyü (resized-hack'i yerine
	# yerleşik grow — script döngüsü yok, anchor değişse de çalışır).
	_records_panel.anchor_left = 0.5
	_records_panel.anchor_right = 0.5
	_records_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_records_panel.offset_top = 760
	_records_panel.offset_bottom = 812
	add_child(_records_panel)
	var rec := Label.new()
	rec.name = "RecLabel"
	rec.add_theme_font_size_override("font_size", 15)
	rec.add_theme_color_override("font_color", Palette.COPPER.lightened(0.3))
	_records_panel.add_child(rec)


## Çalıdaki göz çifti: yumuşak amber parıltı + bebek; ortada kısa göz kırpma.
## Menüde ek olarak pentagram mumlarına titrek kandil parıltısı çizilir.
func _draw_life() -> void:
	if not RunManager.has_active_run():
		# Kurt görselindeki 5+1 mum: bg-cover dönüşümüyle ekrana sabitlenir.
		var ts := Vector2(MENU_BG.get_width(), MENU_BG.get_height())
		var sc := maxf(_life_layer.size.x / ts.x, _life_layer.size.y / ts.y)
		var off := (_life_layer.size - ts * sc) * 0.5
		for ci in range(MENU_CANDLES.size()):
			var cp: Vector2 = off + (MENU_CANDLES[ci] as Vector2) * sc
			var fl := 0.70 + 0.30 * sin(_t * (5.8 + float(ci) * 0.7) + float(ci) * 2.1) \
					* sin(_t * 3.3 + float(ci) * 1.4)
			for gl in [[42.0, 0.05], [21.0, 0.10], [9.0, 0.16]]:
				_life_layer.draw_circle(cp, gl[0] * fl, Color(1.0, 0.50, 0.16, gl[1] * fl))
	for e in _eyes:
		var prog: float = e.t / e.dur
		var a: float = sin(PI * prog)
		if prog > 0.46 and prog < 0.54:  # göz kırpar
			a *= 0.08
		var p := Vector2(e.pos.x * _life_layer.size.x, e.pos.y * _life_layer.size.y)
		for dx in [-e.gap * 0.5, e.gap * 0.5]:
			var ec: Vector2 = p + Vector2(dx, 0.0)
			_life_layer.draw_circle(ec, 6.0, Color(0.95, 0.60, 0.10, 0.10 * a))
			_life_layer.draw_circle(ec, 2.4, Color(1.0, 0.74, 0.16, 0.85 * a))
			_life_layer.draw_circle(ec, 1.0, Color(0.7, 0.15, 0.05, 0.9 * a))


func _secondary_btn(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(190, 48)
	ScreenFx.style_button(b, Color(0.10, 0.06, 0.08, 0.96), 18)
	b.pressed.connect(cb)
	b.mouse_entered.connect(func(): AudioManager.sfx("mark", -14.0, 1.3))  # hover tıkı
	parent.add_child(b)
	return b


func _play_intro() -> void:
	ScreenFx.slide_in(_title, 0.05, Vector2(0, 30))
	ScreenFx.slide_in(_subtitle, 0.12, Vector2(0, 30))
	ScreenFx.slide_in(_info, 0.18, Vector2(0, 30))
	ScreenFx.slide_in(_action_btn, 0.26)
	ScreenFx.slide_in(_asc_btn.get_parent(), 0.34)
	# Rekor paneli resized ile kendini ortalar → pozisyon animasyonu yarışır; yalnız fade.
	_records_panel.modulate.a = 0.0
	var rt := create_tween()
	rt.tween_interval(0.42)
	rt.tween_property(_records_panel, "modulate:a", 1.0, 0.4)


func _refresh() -> void:
	var active := RunManager.has_active_run()
	_fx.show_eye = false                # menü görselinin kendi pentagramı var; göz çizme
	_map_intro = 0.0                    # harita her görünüşünde giriş animasyonu
	_map_layer.queue_redraw()
	_asc_btn.visible = not active
	_daily_btn.disabled = active
	if _cases_btn != null:
		_cases_btn.disabled = active
	_records_panel.visible = not active
	if _seed_row != null:
		_seed_row.visible = not active

	if active:
		# SEFER HARİTASI: orman görseli, tam genişlik ortalı yerleşim.
		_fx.bg_texture = MAP_BG
		_fx.tint = Color(0.88, 0.90, 0.92)
		_fx.overlay = Color(0.02, 0.03, 0.04, 0.22)
		_title.remove_theme_font_override("font")
		_title.add_theme_font_size_override("font_size", 52)
		for l: Control in [_title, _subtitle, _info]:
			l.anchor_left = 0.0
			l.anchor_right = 1.0
		_action_btn.anchor_left = 0.5
		_action_btn.anchor_right = 0.5
		_action_btn.offset_left = -170
		_action_btn.offset_right = 170
		_btn_row.vertical = false
		_btn_row.add_theme_constant_override("separation", 18)
		_btn_row.anchor_left = 0.5
		_btn_row.anchor_right = 0.5
		# 3 buton × 190 + 2 aralık × 18 = 606 → yarı 303.
		_btn_row.offset_left = -303
		_btn_row.offset_right = 303
		_title.offset_top = 60
		_title.offset_bottom = 128
		_subtitle.offset_top = 132
		_subtitle.offset_bottom = 166
		_info.offset_top = 172
		_info.offset_bottom = 238
		_action_btn.offset_top = 700
		_action_btn.offset_bottom = 760
		# İkincil sıra ana butonun ALTINA insin (üst üste binmesin — bug fix).
		_btn_row.offset_top = 786
		_btn_row.offset_bottom = 836
		_title.modulate.a = 1.0  # menü nefes animasyonundan dönerken sıfırla
		_title.text = Loc.t("map_title_daily") if RunManager.is_daily else Loc.t("map_title_run")
		_subtitle.text = (Loc.t("map_daily_sub") if RunManager.is_daily
			else Loc.t("map_asc_sub") % (RunManager.ascension + 1))
		var boss := RunManager.is_current_boss()
		var ntype: int = RunManager.current_node().get("type", Enums.NodeType.VILLAGE)
		# Perde satırı: hangi perdedeyiz (Yayla/Vadi/Kara Orman/Sonsuz).
		var act_i: int = int(RunManager.current_node().get("act", 1))
		var act_keys := ["act_meadow", "act_valley", "act_forest", "act_endless"]
		_info.text = Loc.t("act_line") % [act_i, Loc.t(act_keys[clampi(act_i - 1, 0, 3)])]
		# boss_name config'te Loc anahtarı taşır — gösterim anında çözülür.
		_info.text += "\n" + Loc.t("map_stop_line") % [
			RunManager.current_index + 1, RunManager.nodes.size(),
			"  (%s)" % Loc.t(String(RunManager.current_village_config().get("boss_name", "boss_default"))) if boss else "",
			RunManager.coins, RunManager.total_score,
		]
		if ntype == Enums.NodeType.ELITE:
			_info.text += "\n" + Loc.t("elite_hint")
		# Elit ödülü kazanıldıysa bir kez duyur (tüketilir).
		if RunManager.last_elite_reward != &"":
			_info.text += "\n" + Loc.t("elite_reward_line") % RunManager.passive_name(RunManager.last_elite_reward)
			RunManager.last_elite_reward = &""
		var pnames: Array = []
		for p in RunManager.owned_passives:
			pnames.append(RunManager.passive_name(p))
		if not pnames.is_empty():
			_info.text += "\n" + Loc.t("map_charms") + ", ".join(pnames)
		match ntype:
			Enums.NodeType.SHOP:
				_action_btn.text = Loc.t("btn_enter_shop")
			Enums.NodeType.EVENT:
				_action_btn.text = Loc.t("btn_enter_event")
			Enums.NodeType.ELITE:
				_action_btn.text = Loc.t("btn_enter_elite")
			_:
				_action_btn.text = Loc.t("btn_enter_boss") if boss else Loc.t("btn_enter_flock")
		_skip_btn.visible = ntype == Enums.NodeType.ELITE
		# Rol draft'ı normalde köy tahtasında sunulur; eski kayıt yedeği burada.
		if RunManager.pending_draft:
			_show_draft()
	else:
		# ANA MENÜ: kurt görseli sağ yarıda → menünün tamamı SOL yarıya dizilir.
		_skip_btn.visible = false
		if _draft_layer != null and is_instance_valid(_draft_layer):
			_draft_layer.queue_free()
			_draft_layer = null
		_fx.bg_texture = MENU_BG
		_fx.tint = Color(0.97, 0.96, 0.95)
		_fx.overlay = Color(0.0, 0.0, 0.0, 0.10)
		_title.add_theme_font_override("font", FONT_TITLE)
		_title.add_theme_font_size_override("font_size", 88)
		for l: Control in [_title, _subtitle, _info]:
			l.anchor_left = 0.0
			l.anchor_right = 0.5
		_action_btn.anchor_left = 0.25
		_action_btn.anchor_right = 0.25
		_action_btn.offset_left = -170
		_action_btn.offset_right = 170
		_btn_row.vertical = true
		_btn_row.add_theme_constant_override("separation", 14)  # dikey sütun sıkı dursun
		_btn_row.anchor_left = 0.25
		_btn_row.anchor_right = 0.25
		_btn_row.offset_left = -170
		_btn_row.offset_right = 170
		_seed_row.anchor_left = 0.25
		_seed_row.anchor_right = 0.25
		_records_panel.anchor_left = 0.25
		_records_panel.anchor_right = 0.25
		# Sütun üstten başlar, altta nefes payı kalır (900'de alt boşluk ~54px).
		_title.offset_top = 140
		_title.offset_bottom = 255
		_subtitle.offset_top = 260
		_subtitle.offset_bottom = 294
		_info.offset_top = 300
		_info.offset_bottom = 356
		_action_btn.offset_top = 370
		_action_btn.offset_bottom = 426
		_btn_row.offset_top = 442          # 3 buton × 48 + 2 aralık × 14 = 172
		_btn_row.offset_bottom = 614
		_seed_row.offset_top = 630
		_seed_row.offset_bottom = 664
		_records_panel.offset_top = 676
		_records_panel.offset_bottom = 726
		_action_btn.text = Loc.t("btn_new_run")
		match RunManager.last_outcome:
			Enums.RunOutcome.RUN_WON:
				_title.text = Loc.t("map_run_done_title")
				_subtitle.text = Loc.t("map_run_done_sub") % (RunManager.max_ascension_unlocked + 1)
				_info.text = Loc.t("map_total_line") % [RunManager.total_score, RunManager.coins]
			Enums.RunOutcome.RUN_LOST:
				_title.text = Loc.t("map_run_lost_title")
				_subtitle.text = Loc.t("map_run_lost_sub")
				_info.text = ""
			_:
				_title.text = Loc.t("game_title")
				_subtitle.text = Loc.t("game_tagline")
				_info.text = ""
		# Rekorlar.
		var rec: Label = _records_panel.get_node("RecLabel")
		if RunManager.stat_villages_cleared > 0:
			rec.text = Loc.t("map_records") % [
				RunManager.stat_runs_won, RunManager.stat_villages_cleared,
				RunManager.stat_best_score, max(1, RunManager.stat_best_ascension)]
			if RunManager.stat_daily_date == RunManager.today_int():
				rec.text += Loc.t("map_records_today") % RunManager.stat_daily_best
			_records_panel.visible = true
		else:
			_records_panel.visible = false
		_update_asc_btn()


## Rol draft'ı ASIL yeri köy tahtasıdır (zaferin hemen ardından — DraftOverlay).
## Burası yalnız YEDEK: eski kayıttan pending_draft ile haritaya dönülmüşse sun.
func _show_draft() -> void:
	if _draft_layer != null and is_instance_valid(_draft_layer):
		return
	var d := DraftOverlay.new()
	d.closed.connect(func():
		_draft_layer = null
		_refresh())
	_draft_layer = d
	add_child(d)


func _update_asc_btn() -> void:
	_asc_btn.text = Loc.t("map_asc_btn") % (_pending_ascension + 1)


func _cycle_ascension() -> void:
	var maxa := RunManager.max_ascension_unlocked
	_pending_ascension = (_pending_ascension + 1) % (maxa + 1)
	_update_asc_btn()


func _on_action() -> void:
	if _draft_layer != null and is_instance_valid(_draft_layer):
		return  # önce draft kararı (overlay açıkken Enter köye girmesin)
	if RunManager.has_active_run():
		# Düğüm tipine göre rota: dükkân / olay / köy (elit köy de köy sahnesidir).
		match RunManager.current_node().get("type", Enums.NodeType.VILLAGE):
			Enums.NodeType.SHOP:
				Fader.change_scene("res://scenes/shop.tscn")
			Enums.NodeType.EVENT:
				Fader.change_scene("res://scenes/event.tscn")
			_:
				Fader.change_scene("res://scenes/village_board.tscn")
	else:
		RunManager.start_run(_pending_ascension, Rng.randomize_seed())
		_refresh()


## Günün Seferi: tarih tohumlu — bugün herkes aynı köyleri oynar (§4 Daily).
func _start_daily() -> void:
	if RunManager.has_active_run():
		return
	RunManager.start_daily()
	_refresh()


## Tohumlu sefer: girilen sayıyla başlat (arkadaş skor yarışı). Metinden yalnız
## rakamlar alınır — "Tohum: 12345" yapıştırılsa da çalışır.
func _start_seeded() -> void:
	if RunManager.has_active_run() or _seed_edit == null:
		return
	var digits := ""
	for ch in _seed_edit.text:
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits.is_empty():
		_seed_edit.placeholder_text = Loc.t("map_seed_invalid")
		_seed_edit.text = ""
		return
	RunManager.start_run(_pending_ascension, int(digits.substr(0, 12)))
	_refresh()


## V3.1 VAKALAR: seçim overlay'i — isimli, sabit seed'li senaryolar. Aynı vaka
## herkes için aynı köydür (determinizm §13.6) — "şu vakayı çözebildin mi?" yarışı.
func _build_cases_layer() -> void:
	_cases_layer = Control.new()
	_cases_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cases_layer.visible = false
	add_child(_cases_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.03, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_cases_layer.visible = false)
	_cases_layer.add_child(dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.03, 0.05, 0.98)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(26)
	sb.border_color = Color(0.72, 0.52, 0.28)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -290
	panel.offset_bottom = 290
	_cases_layer.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var title := Label.new()
	title.text = Loc.t("cases_title")
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("f0b53c"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := Label.new()
	sub.text = Loc.t("cases_sub")
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color("d8cbb0"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(sub)
	for case in CASES:
		var key: String = case["key"]
		var b := Button.new()
		b.text = "%s\n%s" % [Loc.t(key + "_name"), Loc.t(key + "_desc")]
		b.custom_minimum_size = Vector2(0, 62)
		b.add_theme_font_size_override("font_size", 14)
		ScreenFx.style_button(b, Color(0.09, 0.06, 0.09, 0.96), 14)
		b.pressed.connect(_start_case.bind(case["cfg"]))
		vb.add_child(b)
	var close := Button.new()
	close.text = Loc.t("cases_close")
	close.custom_minimum_size = Vector2(0, 40)
	ScreenFx.style_button(close, Color(0.12, 0.05, 0.05, 0.96), 14)
	close.pressed.connect(func(): _cases_layer.visible = false)
	vb.add_child(close)


func _toggle_cases() -> void:
	if _cases_layer != null:
		_cases_layer.visible = not _cases_layer.visible
		move_child(_cases_layer, get_child_count() - 1)


func _start_case(cfg: Dictionary) -> void:
	GameState.case_config = cfg.duplicate(true)
	Fader.change_scene("res://scenes/village_board.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_action()


## Düğüm zinciri — ScreenFx'in ÜSTÜNDEKİ katmana çizilir (aktif seferde).
## Referans dili: koyu kumaş şerit üstünde dalgalı kesikli yol; köy düğümlerinde
## ev kümesi ikonu, boss'ta kırmızı şeytan başı; aktif düğümde nabız + işaretçi.
## Düğümler sırayla belirir (_map_intro).
func _draw_map() -> void:
	if not RunManager.has_active_run() or RunManager.nodes.is_empty():
		return
	var n := RunManager.nodes.size()
	var cy := size.y * 0.46
	var x0 := size.x * 0.15
	var x1 := size.x * 0.85
	var step_x := (x1 - x0) / float(max(1, n - 1))

	# Koyu sefer şeridi (banner): hafif eğik kenarlı bant — referanstaki gibi
	# neredeyse tam siyah + kenarlardan zemine yumuşak gölge taşması.
	var bh := 170.0
	var band := PackedVector2Array([
		Vector2(x0 - 110, cy - bh), Vector2(x1 + 110, cy - bh * 0.82),
		Vector2(x1 + 110, cy + bh * 0.92), Vector2(x0 - 110, cy + bh),
	])
	for gi in range(3):
		var g := float(gi + 1) * 16.0
		_map_layer.draw_colored_polygon(PackedVector2Array([
			band[0] + Vector2(-g, -g), band[1] + Vector2(g, -g),
			band[2] + Vector2(g, g), band[3] + Vector2(-g, g),
		]), Color(0.0, 0.0, 0.0, 0.10))
	_map_layer.draw_colored_polygon(band, Color(0.005, 0.004, 0.008, 0.94))

	# Dekor siluetleri: deterministik minik ağaç/çalı (banner dokusu).
	for i in range(16):
		var fx := fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
		var fy := fposmod(sin(float(i) * 78.233) * 12578.1459, 1.0)
		var dp := Vector2(lerpf(x0 - 70.0, x1 + 70.0, fx), cy + (fy - 0.5) * bh * 1.45)
		if i % 3 == 0:
			_draw_tree(dp, 9.0 + fx * 9.0)
		else:
			_map_layer.draw_circle(dp, 1.8 + fx * 2.0, Color(0.10, 0.12, 0.10, 0.45))

	# Düğüm konumları: dalgalı yol (düz çizgi sıkıcıydı).
	var pts: Array = []
	for i in range(n):
		pts.append(Vector2(x0 + step_x * float(i), cy + sin(float(i) * 1.9 + 0.7) * bh * 0.34))

	# Kesikli bağlantılar: gidilen kısım altın, ilerisi soluk; uçlar düğüme değmez.
	for i in range(n - 1):
		var ap := clampf((_map_intro - 0.10 * float(i) - 0.15) / 0.30, 0.0, 1.0)
		if ap <= 0.0:
			continue
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var dirv := (b - a).normalized()
		var col := Palette.SAFFRON.darkened(0.15) if i < RunManager.current_index else Color(0.75, 0.78, 0.82, 0.55)
		_dash_on_layer(a + dirv * (NODE_R + 12.0), a.lerp(b, ap) - dirv * (NODE_R + 12.0) * ap, col, 3.0)

	# Düğümler (sırayla, hafif taşmalı büyüyerek belirir).
	for i in range(n):
		var node: Dictionary = RunManager.nodes[i]
		var ap := _ease_out_back(clampf((_map_intro - 0.08 * float(i) - 0.1) / 0.30, 0.0, 1.0))
		if ap <= 0.0:
			continue
		var p: Vector2 = pts[i]
		var is_boss: bool = node["type"] == Enums.NodeType.BOSS
		var is_mini: bool = is_boss and bool(node["config"].get("miniboss", false))
		var is_elite: bool = node["type"] == Enums.NodeType.ELITE
		var cleared: bool = node.get("cleared", false)
		var current := i == RunManager.current_index
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		var r := NODE_R * ((1.15 if is_mini else 1.4) if is_boss else 1.0) * ap
		var ntype: int = node["type"]
		if is_boss:
			var bcol := Palette.SAFFRON.darkened(0.15) if cleared else Palette.BLOOD
			_draw_devil(p, r, bcol, pulse if current else 0.0)
		else:
			var ring := Color(0.72, 0.75, 0.80, 0.75)   # ileride: soluk
			var house := Color(0.62, 0.64, 0.68, 0.80)
			if cleared:
				ring = Palette.SAFFRON.darkened(0.25)
				house = Palette.SAFFRON.darkened(0.35)
			elif current:
				ring = Palette.SAFFRON
				house = Palette.IVORY
			elif is_elite:
				ring = Palette.SAFFRON.darkened(0.10)  # elit: altın çift halka + yıldız
			_map_layer.draw_circle(p, r, Color(0.04, 0.05, 0.09, 1.0))
			_map_layer.draw_arc(p, r, 0, TAU, 40, ring, 3.5)
			if is_elite:
				_map_layer.draw_arc(p, r + 5.0, 0, TAU, 40, ring.darkened(0.15), 1.8)
			match ntype:
				Enums.NodeType.SHOP:
					_draw_coin_icon(p, r * 0.52, house)
				Enums.NodeType.EVENT:
					_draw_question_icon(p, r * 0.55, house)
				_:
					_draw_houses(p, r * 0.60, house)
					if is_elite and r > 6.0:
						# Çatının üstünde minik altın yıldız (elit rozeti).
						var sp := p + Vector2(0, -r * 0.62)
						var scol := Palette.SAFFRON if not cleared else Palette.SAFFRON.darkened(0.25)
						for k2 in range(2):
							var ang2 := _t * 0.8 + PI * 0.25 * float(k2)
							_map_layer.draw_line(sp + Vector2(cos(ang2), sin(ang2)) * 5.0,
								sp - Vector2(cos(ang2), sin(ang2)) * 5.0, scol, 2.0)
			if cleared:
				# Sağ-alt köşede minik onay rozeti.
				var bp := p + Vector2(r * 0.72, r * 0.72)
				_map_layer.draw_circle(bp, 8.0, Color(0.05, 0.04, 0.02, 0.95))
				_map_layer.draw_arc(bp, 8.0, 0, TAU, 20, Palette.SAFFRON.darkened(0.2), 1.5)
				_map_layer.draw_line(bp + Vector2(-3.5, 0.5), bp + Vector2(-1.0, 3.0), Palette.SAFFRON, 2.0)
				_map_layer.draw_line(bp + Vector2(-1.0, 3.0), bp + Vector2(4.0, -3.0), Palette.SAFFRON, 2.0)
		if current:
			# Nabız halkası + üstte zıplayan işaretçi (buradasın).
			_map_layer.draw_arc(p, r + 7.0 + pulse * 4.0, 0, TAU, 44, Palette.SAFFRON, 2.0)
			var my := p.y - r - 24.0 - 5.0 * sin(_t * 4.0)
			_map_layer.draw_colored_polygon(PackedVector2Array([
				Vector2(p.x - 9.0, my - 12.0), Vector2(p.x + 9.0, my - 12.0), Vector2(p.x, my),
			]), Palette.SAFFRON)


static func _ease_out_back(p: float) -> float:
	if p <= 0.0:
		return 0.0
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(p - 1.0, 3.0) + c1 * pow(p - 1.0, 2.0)


func _dash_on_layer(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var dirv := b - a
	var total := dirv.length()
	if total <= 0.001:
		return
	dirv /= total
	var t := 0.0
	while t < total:
		_map_layer.draw_line(a + dirv * t, a + dirv * minf(t + 9.0, total), col, w)
		t += 17.0


## Dükkân düğümü ikonu: para kesesi — daire + boyun bağı + üstte minik halka.
func _draw_coin_icon(c: Vector2, s: float, col: Color) -> void:
	_map_layer.draw_circle(c + Vector2(0, s * 0.18), s * 0.85, col)
	_map_layer.draw_rect(Rect2(c + Vector2(-s * 0.28, -s * 0.85), Vector2(s * 0.56, s * 0.34)), col)
	_map_layer.draw_line(c + Vector2(-s * 0.42, -s * 0.52), c + Vector2(s * 0.42, -s * 0.52),
		Color(0.04, 0.05, 0.09, 1.0), 2.0)
	# Kese üstünde para simgesi (basit yatay çizgili "o").
	_map_layer.draw_arc(c + Vector2(0, s * 0.18), s * 0.34, 0, TAU, 20, Color(0.04, 0.05, 0.09, 0.9), 2.0)


## Olay düğümü ikonu: soru işareti (bilinmezlik) — yay + kısa sap + nokta.
func _draw_question_icon(c: Vector2, s: float, col: Color) -> void:
	_map_layer.draw_arc(c + Vector2(0, -s * 0.30), s * 0.42, -PI * 0.9, PI * 0.55, 20, col, 3.2)
	_map_layer.draw_line(c + Vector2(s * 0.13, -s * 0.02), c + Vector2(0, s * 0.30), col, 3.2)
	_map_layer.draw_circle(c + Vector2(0, s * 0.62), 2.6, col)


## Minik çam silueti (dekor).
func _draw_tree(p: Vector2, s: float) -> void:
	var col := Color(0.09, 0.11, 0.09, 0.5)
	_map_layer.draw_colored_polygon(PackedVector2Array([
		p + Vector2(0, -s * 1.6), p + Vector2(-s * 0.7, 0), p + Vector2(s * 0.7, 0),
	]), col)
	_map_layer.draw_rect(Rect2(p + Vector2(-s * 0.1, 0), Vector2(s * 0.2, s * 0.45)), col)


## Köy ikonu: üç minik ev kümesi (orta büyük, yanlar küçük).
func _draw_houses(c: Vector2, s: float, col: Color) -> void:
	_draw_house(c + Vector2(-s * 0.62, s * 0.55), s * 0.55, col)
	_draw_house(c + Vector2(s * 0.60, s * 0.58), s * 0.50, col)
	_draw_house(c + Vector2(0, s * 0.30), s * 0.72, col)


## Tek ev: gövde + çatı üçgeni. p = taban orta noktası, s = genişlik.
func _draw_house(p: Vector2, s: float, col: Color) -> void:
	if s < 2.0:
		return  # giriş animasyonunda minicik: üçgen dejenere olur (triangulation hatası)
	_map_layer.draw_rect(Rect2(p + Vector2(-s * 0.5, -s * 0.55), Vector2(s, s * 0.55)), col)
	_map_layer.draw_colored_polygon(PackedVector2Array([
		p + Vector2(-s * 0.62, -s * 0.55), p + Vector2(0, -s * 1.05), p + Vector2(s * 0.62, -s * 0.55),
	]), col)


## Boss ikonu: boynuzlu kırmızı şeytan başı (referans haritadaki gibi).
func _draw_devil(c: Vector2, r: float, col: Color, pulse: float) -> void:
	if r < 3.0:
		return  # giriş animasyonunda minicik: boynuz üçgenleri dejenere olur
	if pulse > 0.0:
		_map_layer.draw_circle(c, r * 1.55, Color(col.r, col.g, col.b, 0.08 + 0.08 * pulse))
	_map_layer.draw_circle(c, r, Color(0.05, 0.008, 0.012, 1.0))
	_map_layer.draw_arc(c, r, 0, TAU, 44, col, 4.0)
	# Boynuzlar.
	_map_layer.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 0.50, -r * 0.72), c + Vector2(-r * 1.05, -r * 1.55), c + Vector2(-r * 0.08, -r * 0.95),
	]), col)
	_map_layer.draw_colored_polygon(PackedVector2Array([
		c + Vector2(r * 0.50, -r * 0.72), c + Vector2(r * 1.05, -r * 1.55), c + Vector2(r * 0.08, -r * 0.95),
	]), col)
	# Kızgın gözler (içe eğik çizikler).
	_map_layer.draw_line(c + Vector2(-r * 0.42, -r * 0.02), c + Vector2(-r * 0.10, -r * 0.24), col, 3.5)
	_map_layer.draw_line(c + Vector2(r * 0.42, -r * 0.02), c + Vector2(r * 0.10, -r * 0.24), col, 3.5)
	# Sırıtış.
	_map_layer.draw_arc(c, r * 0.52, 0.35, PI - 0.35, 16, col, 3.0)
