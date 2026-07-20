extends Node

## Global duraklat/ayar menüsü + tam ekran. Autoload olduğu için tüm sahnelerde
## çalışır (village_board, run_map, result...). ESC menüyü açar/kapar, F11 tam ekran.
## Menü açıkken oyun duraklar (get_tree().paused); menü PROCESS_MODE_ALWAYS ile çalışır.

var _layer: CanvasLayer
var _root: Control
var _open := false
var _rules_overlay: Control = null      ## ESC menüsünden / HUD "?"den açılan kurallar
var _settings_overlay: Control = null   ## ESC menüsünden açılan ayarlar (overlay)
var _codex_overlay: Control = null      ## Ayarlar'dan açılan Karakterler (overlay)
var _loc_nodes: Array = []              ## [node, loc_anahtarı] — menü açılırken tazelenir


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	# Kayıtlı tam ekran tercihini uygula (headless testlerde atla).
	if DisplayServer.get_name() != "headless" and SaveManager.settings.get("fullscreen", true):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 128  # her şeyin üstünde
	add_child(_layer)

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	_layer.add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.01, 0.02, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(300, 0)
	# ortala
	box.position = Vector2(-150, -170)
	_root.add_child(box)

	var title := Label.new()
	title.text = Loc.t("pause_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Palette.SAFFRON)
	box.add_child(title)
	_loc_nodes.append([title, "pause_title"])

	_add_button(box, "pause_resume", _resume)
	_add_button(box, "menu_rules", open_rules)
	_add_button(box, "menu_settings", _open_settings)
	_add_button(box, "pause_fullscreen", _toggle_fullscreen)
	_add_button(box, "pause_main", _to_main)
	_add_button(box, "pause_quit", func(): get_tree().quit())


## key = Loc anahtarı; menü her açılışta tazelenir (dil değişmiş olabilir).
func _add_button(box: VBoxContainer, key: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = Loc.t(key)
	_loc_nodes.append([b, key])
	b.custom_minimum_size = Vector2(300, 52)
	b.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Palette.CRIMSON.darkened(0.5) if state == "normal" else (Palette.BLOOD.darkened(0.25) if state == "hover" else Palette.CRIMSON.darkened(0.6))
		sb.set_corner_radius_all(12)
		sb.border_color = Palette.SAFFRON.darkened(0.15)
		sb.set_border_width_all(2)
		sb.set_content_margin_all(10)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", Palette.IVORY)
	b.add_theme_color_override("font_hover_color", Color("fff2dc"))
	b.pressed.connect(cb)
	box.add_child(b)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			_toggle_fullscreen()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			# Açık overlay (karakterler/ayarlar/kurallar) varsa üstteni kapat, yoksa menü.
			if is_instance_valid(_codex_overlay):
				_codex_overlay.queue_free()
			elif is_instance_valid(_settings_overlay):
				_settings_overlay.queue_free()
			elif is_instance_valid(_rules_overlay):
				_rules_overlay.queue_free()
			else:
				_toggle_menu()
			get_viewport().set_input_as_handled()


## Kurallar'ı overlay olarak aç (oyunu kaybetmeden). ESC menüsü + HUD "?" butonu
## bunu çağırır — ana menüdeki Kurallar butonu kaldırıldı (menü sadeleşti).
func open_rules() -> void:
	if is_instance_valid(_rules_overlay):
		return
	var r: Control = load("res://scenes/rules.tscn").instantiate()
	r.overlay_mode = true
	_layer.add_child(r)  # pause menüsünün ÜSTÜnde (en son eklenen)
	_rules_overlay = r


## Karakterler (Codex) overlay'i — Ayarlar ekranındaki buton çağırır.
func open_codex() -> void:
	if is_instance_valid(_codex_overlay):
		return
	var cdx: Control = load("res://scenes/codex.tscn").instantiate()
	cdx.overlay_mode = true
	_layer.add_child(cdx)
	_codex_overlay = cdx


## ESC menüsünden Ayarlar'ı overlay olarak aç.
func _open_settings() -> void:
	if is_instance_valid(_settings_overlay):
		return
	var s: Control = load("res://scenes/settings.tscn").instantiate()
	s.overlay_mode = true
	_layer.add_child(s)
	_settings_overlay = s


func _toggle_menu() -> void:
	_open = not _open
	if _open:
		# Dil, menü kapalıyken değişmiş olabilir — metinleri açarken tazele.
		for e in _loc_nodes:
			e[0].text = Loc.t(e[1])
	_root.visible = _open
	get_tree().paused = _open


func _resume() -> void:
	_open = false
	_root.visible = false
	get_tree().paused = false


func _toggle_fullscreen() -> void:
	var m := DisplayServer.window_get_mode()
	var is_fs := m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if is_fs else DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	# Tercihi kalıcı yap (Ayarlar ekranıyla senkron).
	SaveManager.settings["fullscreen"] = not is_fs
	SaveManager.save_settings()


func _to_main() -> void:
	_resume()
	Fader.change_scene("res://scenes/run_map.tscn")
