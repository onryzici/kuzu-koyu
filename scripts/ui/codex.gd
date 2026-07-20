extends Control

## Karakterler / Kodeks: tüm roller PORTRELİ kartlar hâlinde, kategoriye göre
## gruplu ızgarada. Kategori rengi kart çerçevesinde (board ile aynı dil).
## Ana menüden açılır. Bkz. §4 (koleksiyon), §10 (görsel dil).

var overlay_mode := false

# Gruplama: başlık -> rol id listesi (+ Sarhoş kavramı ayrı kart).
const GROUPS := [
	["SÜRÜ — Bilgi Verenler (İYİ, daima doğru söyler)", [
		&"Judge", &"Confessor", &"Healer", &"Oracle", &"Dreamer", &"Midwife",
		&"Knight", &"Sentry", &"Milkmaid", &"Beekeeper", &"Crier",
		&"Scout", &"Enlightened", &"Architect", &"Lover", &"Gossip", &"Weaver",
		&"Sheepdog", &"Shearer", &"Drummer", &"Welldigger",
		&"Beadcounter", &"Skittish", &"Tailor", &"Mirrorwright",
	]],
	["ÖZEL & AKTİF", [&"Astrologer", &"Slayer", &"Hunter", &"Trapper"]],
	["PARYALAR — İyi ama tuzak (kompozisyonda ilan edilir)", [&"Saint", &"Jinxed"]],
	["KURTLAR — Kötü (koyun postunda, daima yalan)", [&"Minion", &"Demon"]],
]

const PORTRAIT_SIZE := Vector2(86, 108)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	if not overlay_mode:
		add_child(ScreenFx.new())

	var title := Label.new()
	title.text = "KARAKTERLER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Palette.SAFFRON)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 26
	title.offset_bottom = 78
	add_child(title)
	ScreenFx.slide_in(title, 0.02, Vector2(0, -26))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 110)
	margin.add_theme_constant_override("margin_right", 110)
	margin.add_theme_constant_override("margin_top", 96)
	margin.add_theme_constant_override("margin_bottom", 96)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var card_i := 0
	for group in GROUPS:
		var head := Label.new()
		head.text = group[0]
		head.add_theme_font_size_override("font_size", 21)
		head.add_theme_color_override("font_color", Palette.SAFFRON)
		vbox.add_child(head)

		var sep := ColorRect.new()
		sep.color = Palette.COPPER.darkened(0.4)
		sep.custom_minimum_size = Vector2(0, 2)
		vbox.add_child(sep)

		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 14)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(grid)

		for id in group[1]:
			# ROL AÇILIMI: çile eşiği aşılmamış roller gizemli/kilitli kart olur.
			var tier: int = VillageGenerator.ROLE_TIERS.get(id, 0)
			if tier > RunManager.max_ascension_unlocked:
				_add_card(grid, "??? — Kilitli",
					"Bu karakter Çile %d seferlerinde sürüye katılır. Alfa Kurt'u alt edip çileyi yükselt." % (tier + 1),
					null, Color(0.45, 0.42, 0.40), card_i)
				card_i += 1
				continue
			_add_card(grid, RoleNames.display(id), RoleNames.ability(id),
				PortraitMap.texture(id), _role_color(id), card_i)
			card_i += 1
		# Sarhoş kavramı (sabit rol değil) paryalar grubuna ekle — portresi gizli (?).
		if String(group[0]).begins_with("PARYALAR"):
			_add_card(grid, "Sarhoş",
				"Kendini bir köylü sanır; köylü gibi görünür ama tanıklığı yanlış olabilir. Hangisi olduğu gizli.",
				null, Palette.SAFFRON, card_i)
			card_i += 1

		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 10)
		vbox.add_child(gap)

	var foot := Label.new()
	foot.text = "Yeni kartlar deste açıldıkça ve çile katmanlarında devreye girer."
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 15)
	foot.add_theme_color_override("font_color", Palette.BRONZE.lightened(0.15))
	vbox.add_child(foot)

	var back := Button.new()
	back.text = "Geri (Esc)"
	back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	back.position = Vector2(-260, -76)
	back.size = Vector2(220, 50)
	ScreenFx.style_button(back, Palette.CRIMSON.darkened(0.3), 22)
	back.pressed.connect(_close)
	add_child(back)


func _role_color(id: StringName) -> Color:
	if id == &"Minion" or id == &"Demon":
		return Palette.BLOOD
	if id == &"Saint":
		return Palette.SAFFRON
	if id == &"Astrologer" or id == &"Slayer" or id == &"Hunter":
		return Color("8fe0a0")
	return Palette.BRONZE


## Tek karakter kartı: portre (kategori renkli çerçeve) + ad + yetenek metni.
func _add_card(grid: GridContainer, display_name: String, ability: String,
		portrait: Texture2D, col: Color, idx: int) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.03, 0.045, 0.92)
	sb.set_corner_radius_all(10)
	sb.border_color = col.darkened(0.15)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(3, 4)
	panel.add_theme_stylebox_override("panel", sb)
	grid.add_child(panel)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	panel.add_child(h)

	# Portre: kategori renkli ince çerçeveli kutu içinde cover-crop görsel.
	var frame := PanelContainer.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0.12, 0.07, 0.09, 1.0)
	fsb.set_corner_radius_all(8)
	fsb.border_color = col
	fsb.set_border_width_all(3)
	fsb.set_content_margin_all(3)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.custom_minimum_size = PORTRAIT_SIZE
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(frame)
	if portrait != null:
		var tr := TextureRect.new()
		tr.texture = portrait
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		frame.add_child(tr)
	else:
		var q := Label.new()
		q.text = "?"
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.add_theme_font_size_override("font_size", 52)
		q.add_theme_color_override("font_color", col)
		frame.add_child(q)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(v)

	var name_l := Label.new()
	name_l.text = display_name.to_upper()
	name_l.add_theme_font_size_override("font_size", 20)
	name_l.add_theme_color_override("font_color", col.lightened(0.25))
	v.add_child(name_l)

	var ab := Label.new()
	ab.text = ability
	ab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ab.add_theme_font_size_override("font_size", 15)
	ab.add_theme_color_override("font_color", Palette.IVORY.darkened(0.05))
	v.add_child(ab)

	# Kademeli belirme (konteyner pozisyonu yönetir; yalnız alfa güvenli).
	panel.modulate.a = 0.0
	var t := panel.create_tween()
	t.tween_interval(0.08 + 0.035 * idx)
	t.tween_property(panel, "modulate:a", 1.0, 0.3)


func _close() -> void:
	if overlay_mode:
		queue_free()
	else:
		Fader.change_scene("res://scenes/run_map.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if overlay_mode:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("120810f2"), true)
