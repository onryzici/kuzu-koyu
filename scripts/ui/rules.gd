extends Control

## Kurallar / Nasıl Oynanır ekranı. Ana menüden (sahne) ya da ESC menüsünden
## (overlay) açılır. İçerik tema diliyle (sürü/kurt); bölümler ikonlu panel
## kartlarda, kademeli giriş animasyonuyla belirir. Bkz. CLAUDE.md §11, §12.

var overlay_mode := false        ## true: ESC menüsü üstünde açıldı (kapat = queue_free)

## Bölümler: [ikon, başlık anahtarı, bbcode gövde anahtarı]. Metinler Loc
## tablosundadır (const içinde Loc.t çağrılamaz); paneller kurulurken çözülür.
## bbcode etiketleri iki dilde de korunur.
const SECTIONS := [
	["◎", "rules_s1_title", "rules_s1_body"],
	["☾", "rules_s2_title", "rules_s2_body"],
	["✦", "rules_s3_title", "rules_s3_body"],
	["❖", "rules_s4_title", "rules_s4_body"],
	["▤", "rules_s5_title", "rules_s5_body"],
	["✧", "rules_s6_title", "rules_s6_body"],
	["!", "rules_s7_title", "rules_s7_body"],
	["◉", "rules_s8_title", "rules_s8_body"],
	["➤", "rules_s9_title", "rules_s9_body"],
	["★", "rules_s10_title", "rules_s10_body"],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS  # overlay olarak duraklamada da çalışsın
	_build()


func _build() -> void:
	# Sahne modunda oyunun ortak atmosferi (doku + kıvılcım); overlay'de sade kal.
	if not overlay_mode:
		add_child(ScreenFx.new())

	var title := Label.new()
	title.text = Loc.t("rules_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Palette.SAFFRON)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 26
	title.offset_bottom = 78
	add_child(title)
	ScreenFx.slide_in(title, 0.02, Vector2(0, -26))

	var subtitle := Label.new()
	subtitle.text = Loc.t("rules_subtitle")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Palette.COPPER.lightened(0.2))
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_top = 80
	subtitle.offset_bottom = 104
	add_child(subtitle)
	ScreenFx.slide_in(subtitle, 0.08, Vector2(0, -18))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 210)
	margin.add_theme_constant_override("margin_right", 210)
	margin.add_theme_constant_override("margin_top", 116)
	margin.add_theme_constant_override("margin_bottom", 96)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	for i in range(SECTIONS.size()):
		var sec: Array = SECTIONS[i]
		var panel := _section_panel(sec[0], Loc.t(sec[1]), Loc.t(sec[2]))
		vbox.add_child(panel)
		# Konteyner pozisyonu yönettiği için yalnız alfa animasyonu (yarış olmasın).
		panel.modulate.a = 0.0
		var t := panel.create_tween()
		t.tween_interval(0.10 + 0.06 * i)
		t.tween_property(panel, "modulate:a", 1.0, 0.35)

	var quote := Label.new()
	quote.text = Loc.t("rules_quote")
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote.add_theme_font_size_override("font_size", 16)
	quote.add_theme_color_override("font_color", Palette.BRONZE.lightened(0.15))
	vbox.add_child(quote)

	var back := Button.new()
	back.text = Loc.t("ui_back")
	back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	back.position = Vector2(-260, -76)
	back.size = Vector2(220, 50)
	ScreenFx.style_button(back, Palette.CRIMSON.darkened(0.3), 22)
	back.pressed.connect(_close)
	add_child(back)


## Tek bölüm paneli: ikon + başlık + ayraç + bbcode gövde. Ortak koyu kart stili.
func _section_panel(icon: String, heading: String, body: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.03, 0.045, 0.92)
	sb.set_corner_radius_all(10)
	sb.border_color = Palette.COPPER.darkened(0.25)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(4, 5)
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var head := Label.new()
	head.text = "%s  %s" % [icon, heading]
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", Palette.SAFFRON)
	v.add_child(head)

	var sep := ColorRect.new()
	sep.color = Palette.COPPER.darkened(0.4)
	sep.custom_minimum_size = Vector2(0, 2)
	v.add_child(sep)

	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_size_override("normal_font_size", 17)
	rt.add_theme_constant_override("line_separation", 5)
	rt.add_theme_color_override("default_color", Palette.IVORY)
	rt.text = body
	v.add_child(rt)
	return panel


func _close() -> void:
	if overlay_mode:
		queue_free()
	else:
		Fader.change_scene("res://scenes/run_map.tscn")


func _unhandled_input(event: InputEvent) -> void:
	# Overlay modda ESC'i GameMenu yönetir (çakışma olmasın); yalnız sahne modunda.
	if overlay_mode:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("120810f2"), true)
