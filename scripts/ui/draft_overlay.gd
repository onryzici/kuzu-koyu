class_name DraftOverlay
extends Control

## ROL DRAFT'I overlay'i ("Sürüye Yeni Kan"): köy ZAFERİNİN hemen ardından, daha
## köyden ayrılmadan gösterilir (kullanıcı kararı — haritada geç geliyordu).
## RunManager.draft_choices()'tan 3 aday sunar; seçim RunManager.apply_draft ile
## desteye işler ve overlay kendini kapatır. Aday yoksa sessizce geçer.
## run_map de eski kayıtlardan kalan pending_draft için yedek olarak kullanır.

signal closed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 400  # sinematik karartmasının da üstünde
	var choices := RunManager.draft_choices()
	if choices.is_empty():
		RunManager.apply_draft(&"")
		_close.call_deferred()
		return
	_build(choices)


func _build(choices: Array) -> void:
	# TAM SİYAH zemin (kullanıcı kararı): arkada kartlar/balonlar sızmasın —
	# draft kendi başına bir ekran gibi okunmalı.
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.005, 0.01, 1.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -320
	box.offset_right = 320
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(box)

	var title := Label.new()
	title.text = Loc.t("draft_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Palette.SAFFRON)
	box.add_child(title)

	var sub := Label.new()
	sub.text = Loc.t("draft_sub")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Palette.IVORY.darkened(0.08))
	box.add_child(sub)

	for role in choices:
		var b := Button.new()
		b.text = "%s\n%s" % [RoleNames.display(role).to_upper(), RoleNames.ability(role)]
		b.custom_minimum_size = Vector2(640, 72)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 15)
		ScreenFx.style_button(b, Color(0.10, 0.06, 0.08, 0.97), 15)
		b.pressed.connect(func():
			RunManager.apply_draft(role)
			_close())
		box.add_child(b)

	var skip := Button.new()
	skip.text = Loc.t("draft_skip")
	skip.custom_minimum_size = Vector2(240, 44)
	ScreenFx.style_button(skip, Color(0.07, 0.05, 0.06, 0.95), 15)
	skip.pressed.connect(func():
		RunManager.apply_draft(&"")
		_close())
	box.add_child(skip)

	# Yumuşak giriş.
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.3)


func _close() -> void:
	closed.emit()
	queue_free()
