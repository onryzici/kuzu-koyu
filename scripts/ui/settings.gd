extends Control

## Ayarlar ekranı: ses seviyeleri + tam ekran. Bkz. CLAUDE.md §11.
## Değişiklikler anında uygulanır (AudioManager) ve SaveManager'a yazılır.
## overlay_mode=true iken oyun içi menüden açılır (sahne değiştirmez).

var overlay_mode := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	# Yatay ortalanmış, üstten 120px, 560 geniş sabit sütun (fullscreen'de de ortalı).
	var vb := VBoxContainer.new()
	vb.anchor_left = 0.5
	vb.anchor_right = 0.5
	vb.anchor_top = 0.0
	vb.anchor_bottom = 0.0
	vb.offset_left = -280
	vb.offset_right = 280
	vb.offset_top = 120
	vb.add_theme_constant_override("separation", 26)
	add_child(vb)

	var title := Label.new()
	title.text = "AYARLAR"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Palette.SAFFRON)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var s: Dictionary = SaveManager.settings
	_add_slider(vb, "Ana ses", "vol_master", s.get("vol_master", 0.9))
	_add_slider(vb, "Müzik", "vol_music", s.get("vol_music", 0.6))
	_add_slider(vb, "Efektler", "vol_sfx", s.get("vol_sfx", 1.0))
	_add_fullscreen_toggle(vb, s.get("fullscreen", false))

	var back := Button.new()
	back.text = "Geri (Esc)"
	back.add_theme_font_size_override("font_size", 22)
	back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	back.position = Vector2(-260, -76)
	back.size = Vector2(220, 50)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Palette.CRIMSON.darkened(0.4) if st == "normal" else Palette.CRIMSON.darkened(0.2)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(8)
		back.add_theme_stylebox_override(st, sb)
	back.add_theme_color_override("font_color", Palette.IVORY)
	back.pressed.connect(_close)
	add_child(back)


func _add_slider(parent: Node, label_text: String, key: String, value: float) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Palette.IVORY)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(560, 28)
	row.add_child(slider)

	var refresh := func(v: float):
		lbl.text = "%s   %d%%" % [label_text, int(round(v * 100))]
	refresh.call(value)
	slider.value_changed.connect(func(v: float):
		SaveManager.settings[key] = v
		AudioManager.apply_volumes()
		refresh.call(v)
	)
	# Sürükleme bitince diske yaz (her frame yazma).
	slider.drag_ended.connect(func(_changed): SaveManager.save_settings())


func _add_fullscreen_toggle(parent: Node, value: bool) -> void:
	var cb := CheckButton.new()
	cb.text = "Tam ekran"
	cb.button_pressed = value
	cb.add_theme_font_size_override("font_size", 20)
	cb.add_theme_color_override("font_color", Palette.IVORY)
	cb.toggled.connect(func(on: bool):
		SaveManager.settings["fullscreen"] = on
		SaveManager.save_settings()
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
		)
	)
	parent.add_child(cb)


func _close() -> void:
	SaveManager.save_settings()
	if overlay_mode:
		queue_free()
	else:
		get_tree().change_scene_to_file("res://scenes/run_map.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if overlay_mode:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("120810f2"), true)
