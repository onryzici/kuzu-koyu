extends Control

## OLAY düğümü (§4): köyler arası küçük hikâye + iki seçenek. Sonuçlar seed'lidir
## (determinizm §13.6 — Günün Seferi'nde herkes aynı olayı aynı sonuçla yaşar).
## Ekonomi RunManager'da; tek köylük ödüller pending_boons ile sonraki köye taşınır.

## Her olay: id, title, desc, choices: [{text, cost (para), resolve: Callable-adı}].
## resolve string'i _resolve() içindeki match'e bağlanır (data + küçük hook, §14 ruhu).
## NOT: const içinde Loc.t ÇAĞRILAMAZ — title/desc/text alanları Loc ANAHTARIdır;
## gösterim ve sonuç anında Loc.t ile çözülür.
const EVENTS := [
	{
		"id": &"yarali_gezgin",
		"title": "event_yarali_gezgin_title",
		"desc": "event_yarali_gezgin_desc",
		"choices": [
			{"text": "event_yarali_gezgin_c1", "cost": 20, "act": &"gezgin_yardim"},
			{"text": "event_yarali_gezgin_c2", "cost": 0, "act": &"gezgin_gec"},
		],
	},
	{
		"id": &"eski_mezarlik",
		"title": "event_eski_mezarlik_title",
		"desc": "event_eski_mezarlik_desc",
		"choices": [
			{"text": "event_eski_mezarlik_c1", "cost": 0, "act": &"mezar_kaz"},
			{"text": "event_eski_mezarlik_c2", "cost": 0, "act": &"mezar_gec"},
		],
	},
	{
		"id": &"kahin_cadiri",
		"title": "event_kahin_cadiri_title",
		"desc": "event_kahin_cadiri_desc",
		"choices": [
			{"text": "event_kahin_cadiri_c1", "cost": 15, "act": &"fal_bak"},
			{"text": "event_kahin_cadiri_c2", "cost": 0, "act": &"fal_gec"},
		],
	},
	{
		"id": &"kayip_kuzu",
		"title": "event_kayip_kuzu_title",
		"desc": "event_kayip_kuzu_desc",
		"choices": [
			{"text": "event_kayip_kuzu_c1", "cost": 0, "act": &"kuzu_ara"},
			{"text": "event_kayip_kuzu_c2", "cost": 0, "act": &"kuzu_gec"},
		],
	},
	{
		"id": &"degirmen_yangini",
		"title": "event_degirmen_yangini_title",
		"desc": "event_degirmen_yangini_desc",
		"choices": [
			{"text": "event_degirmen_yangini_c1", "cost": 15, "act": &"yangin_sondur"},
			{"text": "event_degirmen_yangini_c2", "cost": 0, "act": &"yangin_izle"},
		],
	},
	{
		"id": &"bereket_sunagi",
		"title": "event_bereket_sunagi_title",
		"desc": "event_bereket_sunagi_desc",
		"choices": [
			{"text": "event_bereket_sunagi_c1", "cost": 25, "act": &"adak_sun"},
			{"text": "event_bereket_sunagi_c2", "cost": 0, "act": &"dua_et"},
		],
	},
]

var _event: Dictionary
var _rng := RandomNumberGenerator.new()
var _title: Label
var _desc: Label
var _result: Label
var _choice_btns: Array = []
var _continue_btn: Button
var _coins_label: Label
var _chosen := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Seed'li seçim: sefer tohumu + düğüm indeksi → tekrar girişte aynı olay/sonuç.
	_rng.seed = RunManager.run_seed + RunManager.current_index * 6151
	_event = EVENTS[_rng.randi() % EVENTS.size()]
	_build()


func _build() -> void:
	var fx := ScreenFx.new()
	fx.overlay = Color(0.04, 0.02, 0.05, 0.58)
	add_child(fx)

	var head := _label(Vector2(60, 44), 40, Palette.SAFFRON)
	head.text = Loc.t("event_title")
	ScreenFx.slide_in(head, 0.02, Vector2(-60, 0))

	_coins_label = _label(Vector2(1260, 48), 26, Color("ffd479"))
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coins_label.size = Vector2(300, 34)
	_coins_label.text = Loc.t("ui_coins") % RunManager.coins

	# Olay kartı: bordersız koyu panel + yumuşak gölge (yeni panel dili).
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("120a12f2")
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(0)
	sb.set_content_margin_all(28)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 16
	sb.shadow_offset = Vector2(0, 5)
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -230
	add_child(panel)
	ScreenFx.slide_in(panel, 0.12, Vector2(0, 50))

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)

	_title = Label.new()
	_title.text = Loc.t(String(_event["title"]))
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Palette.SAFFRON)
	vb.add_child(_title)

	_desc = Label.new()
	_desc.text = Loc.t(String(_event["desc"]))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(600, 0)
	_desc.add_theme_font_size_override("font_size", 17)
	_desc.add_theme_color_override("font_color", Palette.IVORY)
	vb.add_child(_desc)

	for ch in _event["choices"]:
		var b := Button.new()
		var cost: int = ch["cost"]
		b.text = Loc.t(String(ch["text"]))
		b.custom_minimum_size = Vector2(0, 48)
		ScreenFx.style_button(b, Palette.CRIMSON.darkened(0.25) if cost > 0 else Palette.COPPER.darkened(0.35), 18)
		if cost > RunManager.coins:
			b.disabled = true
			b.text += Loc.t("event_cant_afford")
		b.pressed.connect(_choose.bind(ch))
		vb.add_child(b)
		_choice_btns.append(b)

	_result = Label.new()
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.custom_minimum_size = Vector2(600, 0)
	_result.add_theme_font_size_override("font_size", 17)
	_result.add_theme_color_override("font_color", Color("ffd479"))
	_result.visible = false
	vb.add_child(_result)

	_continue_btn = Button.new()
	_continue_btn.text = Loc.t("event_continue")
	_continue_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_continue_btn.position = Vector2(-320, -92)
	_continue_btn.size = Vector2(280, 56)
	ScreenFx.style_button(_continue_btn, Palette.CRIMSON.darkened(0.15), 22)
	_continue_btn.visible = false
	_continue_btn.pressed.connect(_continue)
	add_child(_continue_btn)


func _choose(ch: Dictionary) -> void:
	if _chosen:
		return
	_chosen = true
	var cost: int = ch["cost"]
	RunManager.coins -= cost
	_result.text = _resolve(ch["act"])
	_result.visible = true
	_coins_label.text = Loc.t("ui_coins") % RunManager.coins
	for b in _choice_btns:
		b.disabled = true
	_continue_btn.visible = true
	AudioManager.play_deal()


## Seçim sonuçları. Şans içerenler _rng'den (seed'li) çekilir — savescum yok.
## Dönüş metinleri Loc.t ile aktif dilde çözülür (const değil — burada serbest).
func _resolve(act: StringName) -> String:
	match act:
		&"gezgin_yardim":
			RunManager.pending_boons.append(&"extra_q")
			return Loc.t("res_gezgin_yardim")
		&"gezgin_gec":
			RunManager.coins += 10
			return Loc.t("res_gezgin_gec")
		&"mezar_kaz":
			if _rng.randf() < 0.6:
				RunManager.coins += 40
				return Loc.t("res_mezar_kaz_win")
			return Loc.t("res_mezar_kaz_lose")
		&"mezar_gec":
			RunManager.coins += 5
			return Loc.t("res_mezar_gec")
		&"fal_bak":
			RunManager.pending_boons.append(&"reveal_omen")
			return Loc.t("res_fal_bak")
		&"fal_gec":
			return Loc.t("res_fal_gec")
		&"adak_sun":
			var pool: Array = []
			for id in RunManager.PASSIVES:
				if not RunManager.has_passive(id):
					pool.append(id)
			if pool.is_empty():
				RunManager.coins += 25
				return Loc.t("res_adak_full")
			var id: StringName = pool[_rng.randi() % pool.size()]
			RunManager.owned_passives.append(id)
			return Loc.t("res_adak_sun") % [
				RunManager.passive_name(id), RunManager.passive_desc(id)]
		&"dua_et":
			RunManager.pending_boons.append(&"extra_day")
			return Loc.t("res_dua_et")
		&"kuzu_ara":
			if _rng.randf() < 0.5:
				RunManager.coins += 25
				return Loc.t("res_kuzu_ara_win")
			return Loc.t("res_kuzu_ara_lose")
		&"kuzu_gec":
			RunManager.coins += 8
			return Loc.t("res_kuzu_gec")
		&"yangin_sondur":
			RunManager.pending_boons.append(&"extra_q")
			return Loc.t("res_yangin_sondur")
		&"yangin_izle":
			RunManager.coins += 15
			return Loc.t("res_yangin_izle")
	return ""


func _continue() -> void:
	if RunManager.has_active_run() \
			and RunManager.current_node().get("type", -1) == Enums.NodeType.EVENT:
		RunManager.on_stop_completed()
	Fader.change_scene("res://scenes/run_map.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER) and _chosen:
			_continue()


func _label(pos: Vector2, fsize: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l
