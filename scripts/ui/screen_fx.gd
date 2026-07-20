class_name ScreenFx
extends Control

## Menü/sonuç/dükkân ekranlarının ortak atmosferi: ritüel zemin dokusu + vinyet +
## süzülen sıcak kıvılcımlar + (opsiyonel) nefes alan büyük nazar gözü.
## Board'daki görsel dille aynı aile — oyun her ekranda "aynı dünya" hissi verir.
## Yalnız görsel; input yutmaz.

const BG_TEXTURE := preload("res://assets/art/bg/ritual_ground.png")

@export var bg_texture: Texture2D = null          ## null ise ritüel zemini kullanılır
@export var tint := Color(0.34, 0.30, 0.38)      ## doku modülasyonu (koyu)
@export var overlay := Color(0.05, 0.02, 0.06, 0.55)  ## üst kaplama
@export var show_eye := false                     ## büyük göz (ana menü)
@export var eye_center := Vector2(0.5, 0.30)      ## ekran oranı cinsinden
@export var spark_count := 40

var _t := 0.0
var _sparks: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()


func _process(delta: float) -> void:
	_t += delta
	if _sparks.is_empty() and size.x > 0.0:
		for i in range(spark_count):
			_sparks.append({
				"x": _rng.randf_range(0.0, size.x),
				"y": _rng.randf_range(0.0, size.y),
				"vy": _rng.randf_range(6.0, 22.0),
				"drift": _rng.randf_range(5.0, 18.0),
				"size": _rng.randf_range(1.2, 3.2),
				"phase": _rng.randf_range(0.0, TAU),
				"spd": _rng.randf_range(1.2, 2.8),
			})
	for s in _sparks:
		s.y -= s.vy * delta
		s.x += sin(_t * 0.6 + s.phase) * s.drift * delta
		if s.y < -8.0:
			s.y = size.y + 8.0
			s.x = _rng.randf_range(0.0, size.x)
	queue_redraw()


func _draw() -> void:
	# Zemin dokusu (cover) + koyu modülasyon.
	var tex := bg_texture if bg_texture != null else BG_TEXTURE
	var ts := Vector2(tex.get_width(), tex.get_height())
	var sc := maxf(size.x / ts.x, size.y / ts.y)
	var ds := ts * sc
	draw_texture_rect(tex, Rect2((size - ds) * 0.5, ds), false, tint)
	draw_rect(Rect2(Vector2.ZERO, size), overlay, true)

	if show_eye:
		_draw_eye(Vector2(size.x * eye_center.x, size.y * eye_center.y))

	# Kıvılcımlar (4-köşe yıldız).
	for s in _sparks:
		var tw: float = 0.25 + 0.45 * (0.5 + 0.5 * sin(_t * s.spd + s.phase))
		_star(Vector2(s.x, s.y), s.size * 1.7 * (0.7 + 0.3 * tw), Color(0.96, 0.74, 0.36, tw), _t * 0.4 + s.phase)


## Büyük nazar gözü (board'daki dille): loblu koyu gövde + kızıl göz + İRİ bebek
## (kenara kayınca kızıl hilal). Board'daki yaratıkla aynı aile.
func _draw_eye(c: Vector2) -> void:
	var breathe := 0.5 + 0.5 * sin(_t * 1.1)
	var tw := _t * 1.1
	var open := 1.0
	var rx := 88.0 * (0.98 + 0.04 * breathe)
	var ry := 104.0 * (0.98 + 0.04 * breathe)
	# Koyu loblu gövde.
	draw_colored_polygon(_blob(c, rx * 1.42, ry * 1.30, tw * 0.65), Color(0.04, 0.01, 0.015, 1.0))
	var rye := ry * open
	for i in range(6):
		var f := float(i) / 6.0
		draw_colored_polygon(_almond(c, rx * (1.0 + f * 0.4), rye * (1.0 + f * 0.38), tw),
			Color(0.72, 0.06, 0.04, 0.10 * (1.0 - f) * (0.4 + 0.6 * open)))
	draw_colored_polygon(_almond(c, rx, rye, tw), Color(0.46, 0.03, 0.02, 1.0))
	draw_colored_polygon(_almond(c, rx * 0.9, rye * 0.9, tw), Color(0.86, 0.11, 0.06, 1.0))
	if open < 0.25:
		return
	var look := Vector2(sin(tw * 0.5) * 0.3, sin(tw * 0.8 + 1.0) * 0.2)
	var pc := c + Vector2(look.x * rx * 0.36, look.y * rye * 0.32)
	draw_colored_polygon(_almond(pc, rx * 0.56, rye * 0.60, tw), Color(0.05, 0.004, 0.01, 1.0))
	draw_colored_polygon(_almond(pc, rx * 0.33, rye * 0.37, tw), Color(0.0, 0.0, 0.0, 1.0))


## Loblu organik gövde konturu (board _blob_outline ile aynı dil).
func _blob(c: Vector2, rx: float, ry: float, tw: float) -> PackedVector2Array:
	var seg := 52
	var pts := PackedVector2Array()
	for i in range(seg):
		var a := TAU * float(i) / float(seg)
		var wob := 1.0 + 0.09 * sin(a * 4.0 + tw) + 0.055 * sin(a * 7.0 - tw * 0.7) + 0.04 * sin(a * 2.0 + tw * 0.5)
		pts.append(c + Vector2(cos(a) * rx * wob, sin(a) * ry * wob))
	return pts


func _almond(c: Vector2, rx: float, ry: float, tw: float) -> PackedVector2Array:
	var seg := 44
	var pts := PackedVector2Array()
	for i in range(seg):
		var a := TAU * float(i) / float(seg)
		var wob := 1.0 + 0.05 * sin(a * 3.0 + tw) + 0.03 * sin(a * 5.0 - tw * 0.6)
		pts.append(c + Vector2(cos(a) * rx * wob, sin(a) * ry * wob))
	return pts


func _star(c: Vector2, r: float, col: Color, rot: float) -> void:
	var pts := PackedVector2Array()
	for i in range(8):
		var a := rot + PI * float(i) / 4.0
		var rr := r if i % 2 == 0 else r * 0.34
		pts.append(c + Vector2(cos(a) * rr, sin(a) * rr))
	draw_colored_polygon(pts, col)


## Ortak buton stili: pahlı köşe hissi + tema rengi. Tüm ekranlar bunu kullanır.
static func style_button(btn: Button, base: Color, fs := 22) -> void:
	btn.add_theme_font_size_override("font_size", fs)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		match state:
			"hover":
				sb.bg_color = base.lightened(0.12)
			"pressed":
				sb.bg_color = base.darkened(0.35)
			"disabled":
				sb.bg_color = Color(0.16, 0.13, 0.12, 0.9)
			_:
				sb.bg_color = base
		sb.set_corner_radius_all(6)
		sb.border_color = Color(0, 0, 0, 0.9)
		sb.set_border_width_all(3)
		sb.set_content_margin_all(10)
		sb.shadow_color = Color(0, 0, 0, 0.6)
		sb.shadow_size = 0
		sb.shadow_offset = Vector2(5, 6)
		sb.shadow_size = 1
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", Color("fff2dc"))
	btn.add_theme_color_override("font_hover_color", Color("ffffff"))
	btn.add_theme_color_override("font_disabled_color", Color("8a7f72"))


## Node'u aşağıdan kaydırarak + saydamlıktan getir (giriş animasyonu).
static func slide_in(node: CanvasItem, delay: float, from_offset := Vector2(0, 46)) -> void:
	if not (node is Control):
		return
	var ctrl := node as Control
	var target := ctrl.position
	ctrl.position = target + from_offset
	ctrl.modulate.a = 0.0
	var t := ctrl.create_tween()
	t.tween_interval(delay)
	t.set_parallel(true)
	t.tween_property(ctrl, "position", target, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(ctrl, "modulate:a", 1.0, 0.4)
