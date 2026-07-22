extends Control
## Portre önizleme sahnesi (araç, oyuna dahil değil): bir portrenin kart üstünde
## nasıl duracağını gösterir. Kırpma matematiği card.gd ile BİREBİR aynı sabitler
## (W/H/CROP_* + cover-crop, yüz üst-orta). Sağda ham görsel + kırpma kılavuzları.
## Çalıştır: godot --path . res://tests/portrait_preview.tscn

const ROLE: StringName = &"Architect"
## Dolu ise PortraitMap yerine bu dosya önizlenir — adayları oyuna bağlamadan
## denemek için (tests/preview_input.png'ye kopyala, boş bırakınca oyundaki hali).
const OVERRIDE_PATH := ""

# card.gd sabitlerinin kopyası (önizleme sadakat için; kaynak: scripts/ui/card.gd)
const W := 116.0
const H := 141.0
const CROP_SIDE := 0.11
const CROP_TOP := 0.15
const CROP_BOTTOM := 0.15

var _tex: Texture2D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if OVERRIDE_PATH != "" and ResourceLoader.exists(OVERRIDE_PATH):
		_tex = load(OVERRIDE_PATH) as Texture2D
	else:
		_tex = PortraitMap.texture(ROLE)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("14100c"))
	var font := get_theme_default_font()
	if _tex == null:
		draw_string(font, Vector2(40, 60), "Portre yüklenemedi: %s" % ROLE,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.RED)
		return

	draw_string(font, Vector2(40, 44),
		"PORTRE ÖNİZLEME — %s (%s)  ·  1x / 2x / 3x kart + ham görsel" %
		[RoleNames.display(ROLE), String(ROLE)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("EDE3C8"))

	# Kart önizlemeleri: 1x (oyun), 2x, 3x (4K'ya yakın büyütme).
	var x := 40.0
	for s: float in [1.0, 2.0, 3.0]:
		_draw_card(Vector2(x, 120.0), s, font)
		x += W * s + 48.0

	# Ham görsel + kırpma kılavuzları (kesikli değil, soluk çizgi yeter).
	var img_h := 620.0
	var img_w := img_h * float(_tex.get_width()) / float(_tex.get_height())
	var ir := Rect2(Vector2(size.x - img_w - 48.0, 120.0), Vector2(img_w, img_h))
	draw_texture_rect(_tex, ir, false)
	var gc := Color(1.0, 0.55, 0.2, 0.55)
	# motorun baştan attığı bantlar: yanlardan %11, üst/alttan %15
	draw_rect(Rect2(ir.position + Vector2(ir.size.x * CROP_SIDE, ir.size.y * CROP_TOP),
		Vector2(ir.size.x * (1.0 - 2.0 * CROP_SIDE), ir.size.y * (1.0 - CROP_TOP - CROP_BOTTOM))),
		gc, false, 2.0)
	draw_string(font, ir.position + Vector2(0, -10), "ham görsel — turuncu: motorun kullandığı alan",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, gc)


## card.gd'nin çizimini sadeleştirilmiş taklit eder: çerçeve + portre + rol bandı.
func _draw_card(pos: Vector2, s: float, font: Font) -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("221a12")
	frame.set_corner_radius_all(int(8 * s))
	frame.set_border_width_all(int(3 * s))
	frame.border_color = Palette.category_color(Enums.Category.VILLAGER)
	draw_style_box(frame, Rect2(pos, Vector2(W, H) * s))
	# portre: card.gd _draw ile aynı interior (5px kenar payı) + cover-crop
	# + yuvarlatılmış köşeler (card.gd._draw_portrait ile aynı poligon tekniği)
	var interior := Rect2(pos + Vector2(5, 5) * s, Vector2(W - 10, H - 10) * s)
	var src := _portrait_src(interior)
	var pts := _rounded_rect_points(interior, (12.0 - 3.0) * s)
	var tw := float(_tex.get_width())
	var th := float(_tex.get_height())
	var uvs := PackedVector2Array()
	for p in pts:
		var t := (p - interior.position) / interior.size
		uvs.append(Vector2(
			(src.position.x + t.x * src.size.x) / tw,
			(src.position.y + t.y * src.size.y) / th))
	draw_colored_polygon(pts, Color.WHITE, uvs, _tex)
	# rol bandı — card.gd ile aynı: koyu, köşesiz, dar şerit + kategori ayraç çizgisi
	var cat_col := Palette.category_color(Enums.Category.VILLAGER)
	var band := StyleBoxFlat.new()
	band.bg_color = Color(0.055, 0.03, 0.035, 0.96)
	draw_style_box(band, Rect2(pos + Vector2(5, H - 24) * s, Vector2(W - 10, 19) * s))
	draw_line(pos + Vector2(0, H - 24) * s, pos + Vector2(W, H - 24) * s, cat_col, 2.0 * s)
	var nm := RoleNames.display(ROLE).to_upper()
	var fs := int(11 * s)
	var ns := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, pos + Vector2(W * s * 0.5 - ns.x * 0.5, (H - 10) * s), nm,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cat_col.lightened(0.42))
	# çerçeve EN ÜSTTE (card.gd sırası): çizgi uçları jantın altında kalsın
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0, 0, 0, 0)
	border.set_corner_radius_all(int(8 * s))
	border.set_border_width_all(int(3 * s))
	border.border_color = Palette.category_color(Enums.Category.VILLAGER)
	draw_style_box(border, Rect2(pos, Vector2(W, H) * s))
	draw_string(font, pos + Vector2(0, -8), "%dx" % int(s),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("9db8e8"))


## card.gd._portrait_src'nin birebir kopyası (cover-crop, yüz üst-ortada).
func _portrait_src(interior: Rect2) -> Rect2:
	var tw := float(_tex.get_width())
	var th := float(_tex.get_height())
	var inner := Rect2(
		tw * CROP_SIDE, th * CROP_TOP,
		tw * (1.0 - 2.0 * CROP_SIDE), th * (1.0 - CROP_TOP - CROP_BOTTOM))
	var s := maxf(interior.size.x / inner.size.x, interior.size.y / inner.size.y)
	var sw := interior.size.x / s
	var sh := interior.size.y / s
	var sx := inner.position.x + (inner.size.x - sw) * 0.5
	var sy := inner.position.y + (inner.size.y - sh) * 0.25
	return Rect2(sx, sy, sw, sh)


## card.gd._rounded_rect_points'in kopyası (önizleme sadakati).
func _rounded_rect_points(rect: Rect2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var centers := [
		rect.position + Vector2(r, r),
		Vector2(rect.end.x - r, rect.position.y + r),
		rect.end - Vector2(r, r),
		Vector2(rect.position.x + r, rect.end.y - r),
	]
	for ci in range(4):
		var start := PI + ci * PI * 0.5
		for i in range(7):
			pts.append(centers[ci] + Vector2.from_angle(start + i * (PI * 0.5) / 6.0) * r)
	return pts
