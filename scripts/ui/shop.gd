extends Control

## Dükkân (M4, §4). Köyler arası: kalıcı muska (pasif) satın al. Para RunManager'da.
## Basit, tema-uyumlu; UI iş mantığı içermez (satın alma RunManager.buy_passive).

var _offers: Array = []          ## bu ziyaretteki teklif id'leri
var _coins_label: Label
var _owned_label: Label
var _cards_box: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_offers = RunManager.roll_shop()
	_build()
	_refresh()
	# Giriş animasyonu: teklif kartları alttan sırayla süzülür.
	var i := 0
	for ch in _cards_box.get_children():
		ScreenFx.slide_in(ch, 0.12 + i * 0.12, Vector2(0, 60))
		i += 1


func _build() -> void:
	var fx := ScreenFx.new()
	fx.overlay = Color(0.06, 0.02, 0.04, 0.60)
	add_child(fx)

	var title := _label(Vector2(60, 44), 40, Palette.SAFFRON)
	title.text = "DÜKKÂN"
	var sub := _label(Vector2(60, 100), 18, Palette.IVORY.darkened(0.1))
	sub.text = "Sefer boyu kalıcı muskalar. Para ile al, sonra sürüye devam et."
	ScreenFx.slide_in(title, 0.02, Vector2(-60, 0))
	ScreenFx.slide_in(sub, 0.1, Vector2(-60, 0))

	# Base 1600x900 — mutlak konum (preset + custom size güvenilmez).
	_coins_label = _label(Vector2(1260, 48), 26, Color("ffd479"))
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coins_label.size = Vector2(300, 34)

	# Teklif kartları (ortada bir sıra).
	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 28)
	_cards_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_cards_box.position = Vector2(-_offer_row_width() * 0.5, -150)
	add_child(_cards_box)

	_owned_label = _label(Vector2(60, 0), 16, Palette.COPPER.lightened(0.3))
	_owned_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_owned_label.position = Vector2(60, -120)
	_owned_label.size = Vector2(900, 60)
	_owned_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var cont := Button.new()
	cont.text = "Sürüye Devam (Enter)"
	cont.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	cont.position = Vector2(-320, -92)
	cont.size = Vector2(280, 56)
	ScreenFx.style_button(cont, Palette.CRIMSON.darkened(0.15), 22)
	cont.pressed.connect(_continue)
	add_child(cont)


func _offer_row_width() -> float:
	return _offers.size() * 260.0 + max(0, _offers.size() - 1) * 28.0


func _refresh() -> void:
	_coins_label.text = "Para: %d" % RunManager.coins
	for ch in _cards_box.get_children():
		ch.queue_free()
	for id in _offers:
		_cards_box.add_child(_make_offer_card(id))
	# Sahip olunanlar
	var names: Array = []
	for p in RunManager.owned_passives:
		names.append(String(RunManager.PASSIVES[p]["name"]))
	_owned_label.text = "Muskaların: " + (", ".join(names) if not names.is_empty() else "yok")


func _make_offer_card(id: StringName) -> Control:
	var data: Dictionary = RunManager.PASSIVES[id]
	var owned: bool = RunManager.has_passive(id)
	var afford: bool = RunManager.coins >= int(data["price"])

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 230)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.03, 0.04, 0.96)
	sb.set_corner_radius_all(14)
	sb.border_color = Palette.SAFFRON.darkened(0.2) if not owned else Palette.category_color(Enums.Category.VILLAGER)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 8
	panel.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var nm := Label.new()
	nm.text = String(data["name"])
	nm.add_theme_font_size_override("font_size", 22)
	nm.add_theme_color_override("font_color", Palette.SAFFRON)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(nm)

	var ds := Label.new()
	ds.text = String(data["desc"])
	ds.add_theme_font_size_override("font_size", 15)
	ds.add_theme_color_override("font_color", Palette.IVORY)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.custom_minimum_size = Vector2(228, 90)
	ds.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	vb.add_child(ds)

	var buy := Button.new()
	buy.add_theme_font_size_override("font_size", 18)
	buy.custom_minimum_size = Vector2(0, 46)
	if owned:
		buy.text = "SAHİPSİN"
		buy.disabled = true
		_style_button(buy, Palette.category_color(Enums.Category.VILLAGER))
	else:
		buy.text = "Al  ·  %d ₿" % int(data["price"])
		buy.disabled = not afford
		_style_button(buy, Palette.CRIMSON if afford else Palette.SOOT.lightened(0.2))
		buy.pressed.connect(func(): _buy(id))
	vb.add_child(buy)
	return panel


func _buy(id: StringName) -> void:
	if RunManager.buy_passive(id):
		AudioManager.play_deal()
		_refresh()


func _continue() -> void:
	get_tree().change_scene_to_file("res://scenes/run_map.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_continue()


func _style_button(btn: Button, bg: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg.darkened(0.4) if state == "normal" else (bg.darkened(0.2) if state == "hover" else bg.darkened(0.55))
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(8)
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", Palette.IVORY)


func _label(pos: Vector2, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("140a10"), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.05, 0.05, 0.12), true)
