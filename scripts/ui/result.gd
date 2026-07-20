extends Control

## Köy/sefer sonucu ekranı. Bkz. CLAUDE.md §11 (Result).
## Başlık vurgun (scale-in) + skor satırları tek tek belirir + atmosfer (ScreenFx).

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var fx := ScreenFx.new()
	add_child(fx)

	var won := RunManager.last_outcome != Enums.RunOutcome.RUN_LOST
	fx.overlay = Color(0.03, 0.05, 0.03, 0.55) if won else Color(0.10, 0.01, 0.02, 0.62)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 54)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 150
	title.offset_bottom = 230
	add_child(title)

	var lines: Array = []
	match RunManager.last_outcome:
		Enums.RunOutcome.VILLAGE_WON:
			title.text = "SÜRÜ KURTARILDI"
			title.add_theme_color_override("font_color", Palette.SAFFRON)
			lines = [
				"Sürü skoru: %d" % RunManager.last_village_score,
				"Kazanılan para: +%d" % RunManager.last_coins_awarded,
				"Toplam skor: %d   ·   Para: %d" % [RunManager.total_score, RunManager.coins],
			]
		Enums.RunOutcome.RUN_WON:
			title.text = "ALFA SÜRÜSÜ ALT EDİLDİ"
			title.add_theme_color_override("font_color", Palette.SAFFRON)
			lines = [
				"Son köy skoru: +%d" % RunManager.last_village_score,
				"Toplam skor: %d   ·   Para: %d" % [RunManager.total_score, RunManager.coins],
				"Yeni çile açıldı: Çile %d" % (RunManager.max_ascension_unlocked + 1),
			]
		Enums.RunOutcome.RUN_LOST:
			title.text = "SEFER DÜŞTÜ"
			title.add_theme_color_override("font_color", Palette.BLOOD)
			lines = [
				"Sürü kurtlara yem oldu.",
				"Toplam skor: %d   ·   Para: %d" % [RunManager.total_score, RunManager.coins],
			]
		_:
			title.text = "SONUÇ"

	# Başlık: vurgun (scale-in).
	title.pivot_offset = Vector2(size.x * 0.5, 40)
	title.scale = Vector2(1.6, 1.6)
	title.modulate.a = 0.0
	var tt := create_tween()
	tt.set_parallel(true)
	tt.tween_property(title, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tt.tween_property(title, "modulate:a", 1.0, 0.3)

	# Skor satırları: pahlı siyah pill'ler, tek tek belirir.
	for i in range(lines.size()):
		var pc := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.88)
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(12)
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.border_color = Palette.COPPER.darkened(0.3)
		sb.set_border_width_all(2)
		sb.shadow_color = Color(0, 0, 0, 0.55)
		sb.shadow_offset = Vector2(5, 6)
		sb.shadow_size = 1
		pc.add_theme_stylebox_override("panel", sb)
		pc.anchor_left = 0.5
		pc.anchor_right = 0.5
		pc.offset_top = 300.0 + i * 66.0
		pc.offset_bottom = 352.0 + i * 66.0
		add_child(pc)
		var l := Label.new()
		l.text = lines[i]
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Palette.IVORY)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pc.add_child(l)
		pc.resized.connect(func():
			pc.offset_left = -pc.size.x * 0.5
			pc.offset_right = pc.size.x * 0.5)
		# resized kendini ortalar → pozisyon animasyonuyla yarışmasın; yalnız fade.
		pc.modulate.a = 0.0
		var lt := create_tween()
		lt.tween_interval(0.35 + i * 0.18)
		lt.tween_property(pc, "modulate:a", 1.0, 0.35)

	var btn := Button.new()
	btn.text = "Devam (Enter)"
	btn.anchor_left = 0.5
	btn.anchor_right = 0.5
	btn.offset_left = -140
	btn.offset_right = 140
	btn.offset_top = 560
	btn.offset_bottom = 616
	ScreenFx.style_button(btn, Palette.CRIMSON.darkened(0.15), 22)
	btn.pressed.connect(_continue)
	add_child(btn)
	ScreenFx.slide_in(btn, 0.5 + lines.size() * 0.18)

	# Skoru panoya kopyala: skor + çile + TOHUM — arkadaşın aynı tohumla
	# (haritadaki "Tohum" girişinden) birebir aynı seferi oynayabilir.
	var copy_btn := Button.new()
	copy_btn.text = "Skoru Kopyala"
	copy_btn.anchor_left = 0.5
	copy_btn.anchor_right = 0.5
	copy_btn.offset_left = -140
	copy_btn.offset_right = 140
	copy_btn.offset_top = 632
	copy_btn.offset_bottom = 680
	ScreenFx.style_button(copy_btn, Palette.COPPER.darkened(0.35), 18)
	copy_btn.pressed.connect(func():
		DisplayServer.clipboard_set("Skorum: %d · Çile %d · Tohum: %d — Aynı tohumla dene!" % [
			RunManager.total_score, RunManager.ascension + 1, RunManager.run_seed])
		copy_btn.text = "Kopyalandı ✔")
	add_child(copy_btn)
	ScreenFx.slide_in(copy_btn, 0.65 + lines.size() * 0.18)


func _continue() -> void:
	Fader.change_scene("res://scenes/run_map.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_continue()
