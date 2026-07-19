extends Control

## Karakterler / Kodeks: tüm rolleri kategoriye göre listeler (ad + yetenek).
## RoleNames verisinden üretilir. Ana menüden açılır. Bkz. §4 (koleksiyon).

var overlay_mode := false

# Gruplama: başlık -> rol id listesi (+ Sarhoş kavramı ayrı satır).
const GROUPS := [
	["SÜRÜ — Bilgi Verenler (İYİ, daima doğru söyler)", [
		&"Judge", &"Confessor", &"Oracle", &"Dreamer", &"Knight",
		&"Sentry", &"Scout", &"Enlightened", &"Architect", &"Lover", &"Gossip",
	]],
	["ÖZEL & AKTİF", [&"Astrologer", &"Slayer", &"Hunter"]],
	["PARYALAR — İyi ama tuzak (kompozisyonda ilan edilir)", [&"Saint"]],
	["KURTLAR — Kötü (koyun postunda, daima yalan)", [&"Minion", &"Demon"]],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_right", 120)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 96)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_size_override("normal_font_size", 16)
	rt.add_theme_constant_override("line_separation", 4)
	rt.add_theme_color_override("default_color", Palette.IVORY)
	rt.text = _build_bbcode()
	scroll.add_child(rt)

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


func _build_bbcode() -> String:
	var s := "[center][font_size=34][color=#e4a72e]KARAKTERLER[/color][/font_size][/center]\n\n"
	for group in GROUPS:
		s += "[color=#e4a72e][font_size=21]%s[/font_size][/color]\n" % group[0]
		for id in group[1]:
			var col := "#a9713a"
			if id == &"Minion" or id == &"Demon":
				col = "#b3272d"
			elif id == &"Saint":
				col = "#e4a72e"
			elif id == &"Astrologer" or id == &"Slayer" or id == &"Hunter":
				col = "#8fe0a0"
			s += "• [b][color=%s]%s[/color][/b] — %s\n" % [col, RoleNames.display(id), RoleNames.ability(id)]
		# Sarhoş kavramı (sabit rol değil) paryalar grubuna ekle.
		if group[0].begins_with("PARYALAR"):
			s += "• [b][color=#e4a72e]Sarhoş[/color][/b] — Kendini bir köylü sanır; köylü gibi görünür ama tanıklığı yanlış olabilir. Hangisi olduğu gizli.\n"
		s += "\n"
	s += "[center][color=#a9713a]Yeni kartlar deste açıldıkça ve ascension'da devreye girer.[/color][/center]\n"
	return s


func _close() -> void:
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
