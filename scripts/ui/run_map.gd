extends Control

## Sefer haritası / ana hub. Bkz. CLAUDE.md §4, §11 (RunMap).
## İki mod: ANA MENÜ (sefer yok — büyük nazar gözü + merkez butonlar) ve
## SEFER HARİTASI (düğüm zinciri + devam). Atmosfer ScreenFx'te (board ile aynı dil).

const NODE_R := 26.0

var _fx: ScreenFx
var _map_layer: Control        ## düğüm zinciri bu katmana çizilir (ScreenFx'in üstünde)
var _title: Label
var _subtitle: Label
var _info: Label
var _action_btn: Button
var _asc_btn: Button
var _daily_btn: Button
var _rules_btn: Button
var _codex_btn: Button
var _settings_btn: Button
var _records_panel: PanelContainer
var _pending_ascension := 0
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ensure_save_loaded()
	_pending_ascension = RunManager.max_ascension_unlocked
	_build()
	_refresh()
	_play_intro()


func _process(delta: float) -> void:
	_t += delta
	if _map_layer != null and RunManager.has_active_run():
		_map_layer.queue_redraw()  # aktif düğüm nabzı


func _ensure_save_loaded() -> void:
	if not RunManager.save_loaded:
		SaveManager.load_game()
		RunManager.save_loaded = true


func _build() -> void:
	_fx = ScreenFx.new()
	add_child(_fx)

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
	add_child(_action_btn)

	# İkincil sıra: zorluk + kurallar + karakterler + ayarlar.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	# 5 buton × 190 + 4 aralık × 18 = 1022 → yarı 511 (sabit; resized-yarışı olmasın).
	row.offset_left = -511
	row.offset_right = 511
	row.offset_top = 660
	row.offset_bottom = 710
	add_child(row)

	_asc_btn = _secondary_btn(row, "Zorluk: A1", _cycle_ascension)
	_daily_btn = _secondary_btn(row, "☀ Günün Seferi", _start_daily)
	_rules_btn = _secondary_btn(row, "Kurallar", func(): get_tree().change_scene_to_file("res://scenes/rules.tscn"))
	_codex_btn = _secondary_btn(row, "Karakterler", func(): get_tree().change_scene_to_file("res://scenes/codex.tscn"))
	_settings_btn = _secondary_btn(row, "Ayarlar", func(): get_tree().change_scene_to_file("res://scenes/settings.tscn"))

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
	_records_panel.anchor_left = 0.5
	_records_panel.anchor_right = 0.5
	_records_panel.offset_top = 760
	_records_panel.offset_bottom = 812
	add_child(_records_panel)
	var rec := Label.new()
	rec.name = "RecLabel"
	rec.add_theme_font_size_override("font_size", 15)
	rec.add_theme_color_override("font_color", Palette.COPPER.lightened(0.3))
	_records_panel.add_child(rec)
	_records_panel.resized.connect(func():
		_records_panel.offset_left = -_records_panel.size.x * 0.5
		_records_panel.offset_right = _records_panel.size.x * 0.5)


func _secondary_btn(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(190, 48)
	ScreenFx.style_button(b, Color(0.10, 0.06, 0.08, 0.96), 18)
	b.pressed.connect(cb)
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
	_fx.show_eye = not active           # ana menüde büyük göz; haritada sade
	_fx.eye_center = Vector2(0.5, 0.24)
	_map_layer.queue_redraw()
	_asc_btn.visible = not active
	_daily_btn.disabled = active
	_records_panel.visible = not active

	if active:
		_title.offset_top = 60
		_title.offset_bottom = 128
		_subtitle.offset_top = 132
		_subtitle.offset_bottom = 166
		_info.offset_top = 172
		_info.offset_bottom = 238
		_action_btn.offset_top = 700
		_action_btn.offset_bottom = 760
		_title.text = "GÜNÜN SEFERİ" if RunManager.is_daily else "SEFER"
		_subtitle.text = ("Tarih tohumlu — bugün herkes aynı köyleri oynuyor" if RunManager.is_daily
			else "Ascension A%d" % (RunManager.ascension + 1))
		var boss := RunManager.is_current_boss()
		_info.text = "Sürü %d / %d%s   ·   Para: %d   ·   Skor: %d" % [
			RunManager.current_index + 1, RunManager.nodes.size(),
			"  (ALFA SÜRÜSÜ)" if boss else "", RunManager.coins, RunManager.total_score,
		]
		var pnames: Array = []
		for p in RunManager.owned_passives:
			pnames.append(String(RunManager.PASSIVES[p]["name"]))
		if not pnames.is_empty():
			_info.text += "\nMuskalar: " + ", ".join(pnames)
		_action_btn.text = "Alfa Sürüsüne Gir (Enter)" if boss else "Sürüye Gir (Enter)"
	else:
		_title.offset_top = 380
		_title.offset_bottom = 448
		_subtitle.offset_top = 452
		_subtitle.offset_bottom = 486
		_info.offset_top = 494
		_info.offset_bottom = 560
		_action_btn.offset_top = 574
		_action_btn.offset_bottom = 634
		_action_btn.text = "Yeni Sefer (Enter)"
		match RunManager.last_outcome:
			Enums.RunOutcome.RUN_WON:
				_title.text = "SEFER TAMAMLANDI!"
				_subtitle.text = "Alfa sürüsü alt edildi — yeni ascension açıldı: A%d" % (RunManager.max_ascension_unlocked + 1)
				_info.text = "Toplam skor: %d   ·   Para: %d" % [RunManager.total_score, RunManager.coins]
			Enums.RunOutcome.RUN_LOST:
				_title.text = "SEFER DÜŞTÜ"
				_subtitle.text = "Sürü kurtlara yem oldu. Tekrar dene."
				_info.text = ""
			_:
				_title.text = "KOYUN POSTU"
				_subtitle.text = "Gündüz sorgula · gece kurt avlanır · kanıt her zaman tutar"
				_info.text = ""
		# Rekorlar.
		var rec: Label = _records_panel.get_node("RecLabel")
		if RunManager.stat_villages_cleared > 0:
			rec.text = "REKORLAR   ·   Sefer: %d   ·   Köy: %d   ·   En iyi skor: %d   ·   En yüksek: A%d" % [
				RunManager.stat_runs_won, RunManager.stat_villages_cleared,
				RunManager.stat_best_score, max(1, RunManager.stat_best_ascension)]
			if RunManager.stat_daily_date == RunManager.today_int():
				rec.text += "   ·   ☀ Bugün: %d" % RunManager.stat_daily_best
			_records_panel.visible = true
		else:
			_records_panel.visible = false
		_update_asc_btn()


func _update_asc_btn() -> void:
	_asc_btn.text = "Zorluk: A%d" % (_pending_ascension + 1)


func _cycle_ascension() -> void:
	var maxa := RunManager.max_ascension_unlocked
	_pending_ascension = (_pending_ascension + 1) % (maxa + 1)
	_update_asc_btn()


func _on_action() -> void:
	if RunManager.has_active_run():
		get_tree().change_scene_to_file("res://scenes/village_board.tscn")
	else:
		RunManager.start_run(_pending_ascension, Rng.randomize_seed())
		_refresh()


## Günün Seferi: tarih tohumlu — bugün herkes aynı köyleri oynar (§4 Daily).
func _start_daily() -> void:
	if RunManager.has_active_run():
		return
	RunManager.start_daily()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_action()


## Düğüm zinciri — ScreenFx'in ÜSTÜNDEKİ katmana çizilir (aktif seferde).
func _draw_map() -> void:
	if not RunManager.has_active_run() or RunManager.nodes.is_empty():
		return
	var n := RunManager.nodes.size()
	var y := size.y * 0.5
	var x0 := size.x * 0.16
	var x1 := size.x * 0.84
	var step := (x1 - x0) / float(max(1, n - 1))
	_map_layer.draw_line(Vector2(x0, y), Vector2(x1, y), Palette.TILE_BLUE.darkened(0.2), 3.0)
	for i in range(n):
		var node: Dictionary = RunManager.nodes[i]
		var pos := Vector2(x0 + step * i, y)
		var is_boss: bool = node["type"] == Enums.NodeType.BOSS
		var col := Palette.CRIMSON if is_boss else Palette.TILE_BLUE
		if node.get("cleared", false):
			col = Palette.SAFFRON.darkened(0.15)
		elif i == RunManager.current_index:
			col = Palette.SAFFRON
		var r := NODE_R * (1.35 if is_boss else 1.0)
		_map_layer.draw_circle(pos, r, Palette.NIGHT_INDIGO)
		_map_layer.draw_arc(pos, r, 0, TAU, 40, col, 4.0)
		if i == RunManager.current_index:
			# Aktif düğüm: nabız halkası.
			var pulse := 0.5 + 0.5 * sin(_t * 3.0)
			_map_layer.draw_arc(pos, r + 6 + pulse * 4.0, 0, TAU, 40, Palette.IVORY, 2.0)
		if is_boss:
			_map_layer.draw_circle(pos, r * 0.32, Palette.BLOOD)
