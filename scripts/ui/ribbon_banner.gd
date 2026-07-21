class_name RibbonBanner
extends Control

## EKRAN ORTASI DUYURU BANDI: tam genişlik, kenarlara doğru eriyen koyu şerit +
## mesaj renginde üst/alt kenar çizgileri (sinematik "letterbox" dili). Mesaj
## gelince bant dikeyde AÇILARAK belirir, metin ardından süzülür; boş mesaj bandı
## kapatır. "AĞIL — koruyacağın kartı seç", "AV MODU" gibi tüm anlık duyurular
## buradan geçer. (Eski alt-köşe sivri şerit tasarımı kullanıcı isteğiyle emekli.)

var _text := ""
var _color := Color("e4a72e")
var _open := 0.0        ## 0 kapalı → 1 açık (çizim genişliği bundan türer)
var _target := 0.0
var _t := 0.0
var _swap_pop := 0.0    ## açıkken mesaj değişirse metin küçük bir pop yapar
var _center := false    ## true: ekran ortası (modlu istem) · false: alt bant (akış)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 260  # gece letterbox (200) ve karartma (250) üstü


## center=true: ekranın ORTASINDA açılır — hedef seçimi gibi "dur ve karar ver"
## istemleri için. Varsayılan false: akış bildirimleri alttaki bantta kalır
## (kullanıcı isteği: her yazı ortaya çıkınca oyun alanını kapatıyordu).
func show_message(text: String, color: Color, center: bool = false) -> void:
	if text.strip_edges() == "":
		_target = 0.0
		return
	_color = color
	_center = center
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


## Yatayda kenarlara doğru eriyen tam genişlik şerit (iki yarım quad, vertex
## renkleriyle gradyan — merkez yoğun, uçlar şeffaf).
func _fading_band(y: float, h: float, col_mid: Color) -> void:
	var half_w := size.x * 0.5
	var clear := Color(col_mid.r, col_mid.g, col_mid.b, 0.0)
	draw_polygon(PackedVector2Array([
		Vector2(0, y), Vector2(half_w, y), Vector2(half_w, y + h), Vector2(0, y + h),
	]), PackedColorArray([clear, col_mid, col_mid, clear]))
	draw_polygon(PackedVector2Array([
		Vector2(half_w, y), Vector2(size.x, y), Vector2(size.x, y + h), Vector2(half_w, y + h),
	]), PackedColorArray([col_mid, clear, clear, col_mid]))


func _draw() -> void:
	if _open <= 0.01 or _text == "":
		return
	var font := get_theme_default_font()
	if font == null:
		return
	var e := 1.0 - pow(1.0 - clampf(_open, 0.0, 1.0), 3.0)  # ease-out cubic
	var cy := size.y * 0.5 if _center else size.y - 56.0
	var h := (78.0 if _center else 64.0) * e
	var half := h * 0.5

	# Koyu ana bant (merkezde yoğun, uçlarda eriyen).
	_fading_band(cy - half, h, Color(0.02, 0.008, 0.015, 0.88 * e))
	# Metnin hemen arkasında yoğunlaşan ek siyah plaka (kullanıcı isteği: yazının
	# arkası okunaklı koyulukta olsun — geniş gradyan tek başına yetmiyordu).
	var fs_base := 23.0 if _center else 19.0
	var fs_est := int(fs_base * (1.0 + 0.07 * _swap_pop))
	var est_w := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_est).x
	var bw := est_w * 0.5 + 150.0
	var cx := size.x * 0.5
	var pdark := Color(0, 0, 0, 0.60 * e)
	var pclear := Color(0, 0, 0, 0.0)
	draw_polygon(PackedVector2Array([
		Vector2(cx - bw, cy - half), Vector2(cx, cy - half), Vector2(cx, cy + half), Vector2(cx - bw, cy + half),
	]), PackedColorArray([pclear, pdark, pdark, pclear]))
	draw_polygon(PackedVector2Array([
		Vector2(cx, cy - half), Vector2(cx + bw, cy - half), Vector2(cx + bw, cy + half), Vector2(cx, cy + half),
	]), PackedColorArray([pdark, pclear, pclear, pdark]))
	# Mesaj renginde üst/alt kenar çizgileri (aynı erime).
	var edge := Color(_color.r, _color.g, _color.b, 0.85 * e)
	_fading_band(cy - half - 1.2, 2.4, edge)
	_fading_band(cy + half - 1.2, 2.4, edge)
	# Bandın içinde, metnin arkasında çok hafif renk soluğu (mesajın rengi hissedilsin).
	_fading_band(cy - half * 0.5, half, Color(_color.r, _color.g, _color.b, 0.05 * e))

	# Metin: bant açıldıktan sonra süzülür; mesaj tazelenince minik pop.
	var ta := clampf((_open - 0.45) / 0.55, 0.0, 1.0)
	if ta > 0.01:
		var fs2 := int(fs_base * (1.0 + 0.07 * _swap_pop))
		var tw2 := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var tp := Vector2(size.x * 0.5 - tw2 * 0.5, cy + fs2 * 0.34)
		draw_string_outline(font, tp, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, 5,
			Color(0, 0, 0, 0.85 * ta))
		draw_string(font, tp, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2,
			Color(_color.r, _color.g, _color.b, ta))
