class_name RibbonBanner
extends Control

## Alt-orta DUYURU ŞERİDİ: sivri uçlu koyu bant + klasik ofset gölge + uçlarda
## katlanmış kuyruklar. Mesaj gelince ortadan AÇILARAK belirir (unfold), metin
## ardından süzülür; boş mesaj şeridi katlar. "AĞIL — koruyacağın kartı seç",
## "AV MODU" gibi tüm anlık duyurular buradan geçer (eski düz Label yerine).

var _text := ""
var _color := Color("e4a72e")
var _open := 0.0        ## 0 kapalı → 1 açık (çizim genişliği bundan türer)
var _target := 0.0
var _t := 0.0
var _swap_pop := 0.0    ## açıkken mesaj değişirse metin küçük bir pop yapar


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -84
	offset_bottom = -14
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 260  # gece letterbox (200) ve karartma (250) üstü


func show_message(text: String, color: Color) -> void:
	if text.strip_edges() == "":
		_target = 0.0
		return
	_color = color
	if _open > 0.9 and _target == 1.0:
		# Şerit zaten açık: metni tazele + küçük pop (tekrar katlanıp açılmasın).
		_text = text
		_swap_pop = 1.0
	else:
		_text = text
		_target = 1.0


func clear() -> void:
	_target = 0.0


func _process(delta: float) -> void:
	_t += delta
	var speed := 3.6 if _target > _open else 5.5  # açılış görülür, kapanış çevik
	_open = move_toward(_open, _target, delta * speed)
	_swap_pop = maxf(0.0, _swap_pop - delta * 3.5)
	if _open > 0.001:
		queue_redraw()


static func _ease_out_back(p: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(p - 1.0, 3.0) + c1 * pow(p - 1.0, 2.0)


func _draw() -> void:
	if _open <= 0.01 or _text == "":
		return
	var font := get_theme_default_font()
	if font == null:
		return
	var fs := 20
	var e := _ease_out_back(clampf(_open, 0.0, 1.0))
	var text_w := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w := (text_w + 130.0) * maxf(e, 0.06)
	var h := 46.0
	var c := Vector2(size.x * 0.5, size.y * 0.5)
	var bevel := minf(18.0, w * 0.25)

	# Sivri uçlu şerit gövdesi (klasik bant silueti).
	var body := PackedVector2Array([
		c + Vector2(-w * 0.5, 0), c + Vector2(-w * 0.5 + bevel, -h * 0.5),
		c + Vector2(w * 0.5 - bevel, -h * 0.5), c + Vector2(w * 0.5, 0),
		c + Vector2(w * 0.5 - bevel, h * 0.5), c + Vector2(-w * 0.5 + bevel, h * 0.5),
	])

	# Uç kuyrukları: şerit tam açılınca uçlardan aşağı katlanır (gövdeden ÖNCE — arkada).
	if _open > 0.88:
		var ta2 := clampf((_open - 0.88) / 0.12, 0.0, 1.0)
		for side in [-1.0, 1.0]:
			var tip := c + Vector2(side * (w * 0.5 - 2.0), 0.0)
			draw_colored_polygon(PackedVector2Array([
				tip, tip + Vector2(side * 16.0 * ta2, 12.0 * ta2), tip + Vector2(side * 3.0, 18.0 * ta2),
			]), Color(0.01, 0.005, 0.01, 0.9 * ta2))

	# Klasik ofset gölge (panellerle aynı dil) + gövde.
	var sh := PackedVector2Array()
	for p in body:
		sh.append(p + Vector2(6, 7))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.55))
	draw_colored_polygon(body, Color(0.02, 0.01, 0.02, 0.96))
	# Üstte ince ışık, altta mesaj renginde vurgu çizgisi.
	draw_line(body[1], body[2], Color(1, 1, 1, 0.07), 1.2)
	draw_line(body[5] + Vector2(4, -2), body[4] + Vector2(-4, -2),
		Color(_color.r, _color.g, _color.b, 0.85), 2.4)

	# Metin: şerit açıldıktan sonra süzülür; mesaj tazelenince minik pop.
	var ta := clampf((_open - 0.55) / 0.45, 0.0, 1.0)
	if ta > 0.01:
		var fs2 := int(fs * (1.0 + 0.07 * _swap_pop))
		var tw2 := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var tp := Vector2(c.x - tw2 * 0.5, c.y + fs2 * 0.34)
		draw_string_outline(font, tp, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, 4,
			Color(0, 0, 0, 0.8 * ta))
		draw_string(font, tp, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2,
			Color(_color.r, _color.g, _color.b, ta))
