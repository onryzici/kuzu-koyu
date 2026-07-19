class_name CardView
extends Control

## Tek bir kartın görseli + etkileşimi (V2: Sorgu & Gece — bkz. CLAUDE.md §0.5).
## Kapalı kart YOK: herkes baştan iddia ettiği rolüyle görünür. Tık = SORGU.
## Kart durumları: canlı (yüz açık) / gece-öldü (solgun + pençe izi, gerçek rol) /
## ayıklanmış (kurt: kızıl, bölünme sinematiği; koyun: ✚).
## Dağıtımda desteden göz-arkalı uçar, slotuna oturunca yüzü açılır. İş mantığı yok.

signal clicked(seat: int)
signal right_clicked(seat: int)
signal hover_changed(seat: int, entered: bool)

const W := 116.0
const H := 141.0
const RADIUS := 12
const BAND_H := 24.0

# Portre çerçeve kırpması: tarot görsellerinin krem kenarını + üst rakam +
# alt başlık bandını at. Tüm kartlarda temiz görünsün diye cömert kırp.
const CROP_SIDE := 0.11
const CROP_TOP := 0.15
const CROP_BOTTOM := 0.15

const BACK_BG := Color("1b0f12")   ## kart arkası: koyu göz-soketi tabanı
const EYE_AMBER := Color("e4a72e")
const EYE_COPPER := Color("c9743b")
const BACK_EYE_RED := Color(0.86, 0.11, 0.06)  ## merkez nazar gözüyle aynı kırmızı
const BUBBLE_BG := Color("f4ecd6")
const BUBBLE_BORDER := Color("2a2320")
const BUBBLE_TEXT := Color("1c1712")

var seat: int = -1
var selected := false
var executable_hint := false
var protect_hint := false   ## AĞIL seçim modunda: korunabilir kart (mavi hale)

var _seat_label: Label
var _role_label: Label
var _mark_label: Label
var _status_label: Label
var _bubble: PanelContainer
var _bubble_label: Label
var _bubble_side := "right"

var _bg_color := BACK_BG
var _border_color := EYE_COPPER
var _band_color := Color(0, 0, 0, 0)
var _facedown := true      ## yalnız dağıtım uçuşunda true (oyunda yüzler hep açık)
var _portrait: Texture2D = null
var _is_anchor := false
var _is_dead := false      ## gece kurda yem oldu
var _given := 0            ## verdiği ifade sayısı (pip göstergesi)
var _claims_total := 0
var _flipping := false
var _hovered := false
var _cut := 0.0          ## ayıklama kesme efekti (1->0 sönen çizik)
var _split := 0.0        ## fiziksel 2'ye bölünme ilerlemesi (0->1)
var _curse := 0.0        ## gece pençe efekti (1->0 kızıl-is dalgası)
var _dust := 0.0         ## slota oturma toz bulutu (1->0)
var _t := 0.0            ## kart-arkası gözü animasyonu


func setup(s: int) -> void:
	seat = s


## Kart arkası (dağıtım uçuşu) canlı dursun diye yalnız o sırada her kare çiz.
func _process(delta: float) -> void:
	_t += delta
	if _facedown and _split <= 0.0:
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	pivot_offset = Vector2(W, H) * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_children()
	refresh()
	mouse_entered.connect(_on_hover_in)
	mouse_exited.connect(_on_hover_out)


func _build_children() -> void:
	# Seat numarası _draw_seat_tag ile kartın ÜSTÜNDE çiziliyor; bu child gizli.
	_seat_label = _make_label(14, HORIZONTAL_ALIGNMENT_LEFT)
	_seat_label.visible = false

	_mark_label = _make_label(22, HORIZONTAL_ALIGNMENT_RIGHT)
	_mark_label.position = Vector2(W - 40, 5)
	_mark_label.size = Vector2(34, 26)

	_role_label = _make_label(13, HORIZONTAL_ALIGNMENT_CENTER)
	_role_label.position = Vector2(5, H - BAND_H - 4)
	_role_label.size = Vector2(W - 10, BAND_H)
	_role_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_status_label = _make_label(36, HORIZONTAL_ALIGNMENT_CENTER)
	_status_label.position = Vector2(0, H * 0.4)
	_status_label.size = Vector2(W, 44)

	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.pivot_offset = Vector2(0, 20)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BUBBLE_BG
	sb.set_corner_radius_all(9)
	sb.border_color = BUBBLE_BORDER
	sb.set_border_width_all(2)
	sb.set_content_margin_all(7)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	_bubble.add_theme_stylebox_override("panel", sb)
	_bubble.z_index = 50
	_bubble_label = Label.new()
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.custom_minimum_size = Vector2(148, 0)
	_bubble_label.add_theme_font_size_override("font_size", 13)
	_bubble_label.add_theme_color_override("font_color", BUBBLE_TEXT)
	_bubble.add_child(_bubble_label)
	add_child(_bubble)
	_bubble.visible = false


func _make_label(font_size: int, halign: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.horizontal_alignment = halign
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func refresh() -> void:
	if GameState.village == null or seat < 0:
		return
	var c: Character = GameState.village.get_character(seat)
	_is_anchor = seat in GameState.village.anchors
	_is_dead = c.night_killed
	_given = c.given
	_claims_total = c.claims.size()

	_seat_label.text = "#%d" % seat

	var mark: int = GameState.village.marks[seat] if seat < GameState.village.marks.size() else Enums.MarkType.NONE
	_mark_label.text = Palette.mark_glyph(mark)
	_mark_label.add_theme_color_override("font_color", Palette.mark_color(mark))

	# V2: yüz HEP açık (iddia edilen rol). Gerçek yüz: ayıklanınca/ölünce.
	var shown_cat := _shown_category(c)
	var cat_col := Palette.category_color(shown_cat)
	_bg_color = Color("2c151a")
	_border_color = cat_col
	_band_color = cat_col
	_portrait = PortraitMap.texture(c.shown_role())
	_role_label.text = RoleNames.display(c.shown_role()).to_upper()
	_role_label.add_theme_color_override("font_color", Color("faf3e2"))
	_status_label.text = ""

	# Balon: SON verilen ifade (yalnız canlıyken).
	var claim_text := c.testimony.text if c.testimony != null else ""
	if claim_text != "" and c.is_alive():
		_bubble_label.text = claim_text
		_bubble.visible = true
	else:
		_bubble.visible = false

	if c.night_killed:
		# Gece kurbanı: gerçek rolü açığa çıkar (kesin İYİ), solgun görünüm.
		_portrait = PortraitMap.texture(c.role)
		_role_label.text = RoleNames.display(c.role).to_upper()
		_border_color = Color("55504a")
		_band_color = Color("3a3733")
	elif c.executed:
		if c.is_evil():
			_border_color = Palette.BLOOD
			_band_color = Palette.BLOOD
			_portrait = PortraitMap.texture(c.role)
			_role_label.text = RoleNames.display(c.role).to_upper()
		else:
			_status_label.text = "✚"
			_status_label.add_theme_color_override("font_color", Color("f6ecd2"))

	if _is_anchor and c.is_alive():
		_border_color = Palette.SAFFRON

	_reposition_bubble()
	queue_redraw()


func _shown_category(c: Character) -> int:
	if c.is_evil() and not (c.executed or c.night_killed):
		return Enums.Category.VILLAGER
	# Sarhoş (parya ama Ermiş değil) kendini köylü sanır → köylü gibi görünür (gizli).
	if c.category == Enums.Category.OUTCAST and c.role != &"Saint":
		return Enums.Category.VILLAGER
	return c.category


func set_bubble_side(side: String) -> void:
	_bubble_side = side
	_reposition_bubble()


func get_bubble_side() -> String:
	return _bubble_side


func _reposition_bubble() -> void:
	if _bubble == null or not _bubble.visible:
		return
	var bs := _bubble.get_combined_minimum_size()
	_bubble.size = bs
	match _bubble_side:
		"left":
			_bubble.position = Vector2(-bs.x - 12, (H - bs.y) * 0.4)
		"top":
			_bubble.position = Vector2((W - bs.x) * 0.5, -bs.y - 12)
		"bottom":
			_bubble.position = Vector2((W - bs.x) * 0.5, H + 12)
		_:
			_bubble.position = Vector2(W + 12, (H - bs.y) * 0.4)


## Yeni ifade alındı: balon pop animasyonu.
func pop_bubble() -> void:
	refresh()
	if not _bubble.visible:
		return
	_bubble.modulate.a = 0.0
	_bubble.scale = Vector2(0.7, 0.7)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_bubble, "modulate:a", 1.0, 0.16)
	t.tween_property(_bubble, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Deste-dağıtma: kart desteden GÖZ ARKASIYLA uçar, slotuna oturunca yüzü açılır.
func deal_in(target: Vector2, delay: float, deck_pos: Vector2) -> void:
	_facedown = true
	position = deck_pos
	rotation = deg_to_rad(-16.0)
	modulate.a = 0.0
	scale = Vector2(0.7, 0.7)
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_property(self, "modulate:a", 1.0, 0.1)
	t.set_parallel(true)
	t.tween_property(self, "position", target, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "rotation", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.set_parallel(false)
	# Slota oturunca yüzünü çevir (flip) + toz bulutu.
	t.tween_property(self, "scale", Vector2(0.02, 1.06), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		_facedown = false
		_dust = 1.0
		var dt := create_tween()
		dt.tween_method(func(v: float): _dust = v; queue_redraw(), 1.0, 0.0, 0.45)
		queue_redraw()
	)
	t.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Ayıklama "kesme" efekti: çapraz parlayan çizik + punch.
func play_cut() -> void:
	_cut = 1.0
	var t := create_tween()
	t.tween_method(func(v: float): _cut = v; queue_redraw(), 1.0, 0.0, 0.55)
	var p := create_tween()
	p.tween_property(self, "scale", Vector2(1.12, 0.92), 0.08).set_trans(Tween.TRANS_BACK)
	p.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Gece pençesi: kurt bu kartı avladı — kızıl-is dalgası + sarsıntı, sonra solgunlaşır.
func play_night_death() -> void:
	_curse = 1.0
	var t := create_tween()
	t.tween_method(func(v: float): _curse = v; queue_redraw(), 1.0, 0.0, 0.9)
	var p := create_tween()
	p.tween_property(self, "scale", Vector2(1.12, 1.12), 0.1).set_trans(Tween.TRANS_SINE)
	p.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_SINE)
	# solgunlaşma (ölü görünüm refresh'te; modulate ile yumuşat)
	modulate = Color(1, 1, 1, 1)
	var m := create_tween()
	m.tween_property(self, "modulate", Color(0.72, 0.68, 0.66, 0.92), 0.7)


## Kartı fiziksel olarak İKİYE böler: iki yarım ayrılır, döner, düşer, söner.
func play_split() -> void:
	_bubble.visible = false
	_split = 0.001
	var t := create_tween()
	t.tween_method(func(v: float): _split = v; queue_redraw(), 0.0, 1.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Flip animasyonu (gerçek yüz açığa çıkarken — ayıklama).
func animate_reveal() -> void:
	if _flipping:
		refresh()
		return
	_flipping = true
	var t := create_tween()
	t.set_trans(Tween.TRANS_QUAD)
	t.tween_property(self, "scale", Vector2(0.02, 1.08), 0.13).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		refresh()
		if _bubble.visible:
			_bubble.modulate.a = 0.0
			_bubble.scale = Vector2(0.8, 0.8)
	)
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.16).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_bubble, "modulate:a", 1.0, 0.2)
	t.parallel().tween_property(_bubble, "scale", Vector2(1.0, 1.0), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): _flipping = false)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)

	# Fiziksel bölünme oynuyorsa normal çizimin yerine onu çiz.
	if _split > 0.0:
		_draw_split()
		return

	# --- Dış parıltı/hale ---
	var glow_col := _border_color
	var glow := 0.0
	if _is_anchor:
		glow = 0.25
	if _hovered or selected:
		glow = 0.35
	if executable_hint:
		glow_col = Palette.BLOOD
		glow = maxf(glow, 0.4)
	if protect_hint:
		glow_col = Color(0.45, 0.60, 1.0)  # ağıl: gece mavisi
		glow = maxf(glow, 0.45)
	if glow > 0.0 and not _is_dead:
		for i in range(2):
			var g := StyleBoxFlat.new()
			g.bg_color = Color(glow_col.r, glow_col.g, glow_col.b, 0.08 * glow)
			g.set_corner_radius_all(RADIUS + 5 + i * 5)
			draw_style_box(g, rect.grow(4.0 + i * 5.0))

	# --- Gölge + taban ---
	var bg := StyleBoxFlat.new()
	bg.bg_color = _bg_color
	bg.set_corner_radius_all(RADIUS)
	bg.shadow_color = Color(0, 0, 0, 0.45)
	bg.shadow_size = 5
	bg.shadow_offset = Vector2(0, 3)
	draw_style_box(bg, rect)

	if _facedown:
		# Dağıtım uçuşu: merkez nazar gözünün SADE, hareketli kopyası.
		_draw_back_eye(rect)
		var fb := StyleBoxFlat.new()
		fb.bg_color = Color(0, 0, 0, 0)
		fb.set_corner_radius_all(RADIUS)
		fb.border_color = EYE_COPPER
		fb.set_border_width_all(5)
		draw_style_box(fb, rect)
	else:
		if _portrait != null:
			_draw_portrait(Rect2(5, 5, W - 10, H - 10))
		_draw_role_band()

		# --- Çerçeve: kalın kategori-renkli + üst highlight (gloss) ---
		var border := StyleBoxFlat.new()
		border.bg_color = Color(0, 0, 0, 0)
		border.set_corner_radius_all(RADIUS)
		border.border_color = _border_color
		border.set_border_width_all(6 if (selected or _hovered) else 5)
		draw_style_box(border, rect)
		var gloss := StyleBoxFlat.new()
		gloss.bg_color = Color(0, 0, 0, 0)
		gloss.set_corner_radius_all(RADIUS - 2)
		gloss.border_color = _border_color.lightened(0.5)
		gloss.border_width_top = 2
		gloss.border_width_left = 2
		gloss.border_width_right = 2
		gloss.border_width_bottom = 0
		draw_style_box(gloss, rect.grow(-5))

		# Gece kurbanı: karartma + pençe izleri (üç paralel çizik).
		if _is_dead:
			var dark := StyleBoxFlat.new()
			dark.bg_color = Color(0.06, 0.04, 0.05, 0.55)
			dark.set_corner_radius_all(RADIUS)
			draw_style_box(dark, rect)
			for k in range(3):
				var off := -14.0 + k * 14.0
				draw_line(Vector2(W * 0.28 + off, H * 0.2), Vector2(W * 0.52 + off, H * 0.78),
					Color(0.45, 0.08, 0.06, 0.9), 4.0)
			# mezar işareti
			var font := get_theme_default_font()
			if font != null:
				draw_string_outline(font, Vector2(W - 30, 30), "✝", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 4, Color(0, 0, 0, 0.9))
				draw_string(font, Vector2(W - 30, 30), "✝", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("d8cfc2"))

		# İfade pip'leri: verdiği/toplam (sorgu ekonomisi göstergesi, sol-üst).
		if not _is_dead and _claims_total > 0:
			for k in range(_claims_total):
				var pc := Vector2(14 + k * 13.0, 14)
				draw_circle(pc, 4.5, Color(0, 0, 0, 0.65))
				draw_circle(pc, 3.2, Color("e4a72e") if k < _given else Color("4a3a30"))

	if selected:
		var sel := StyleBoxFlat.new()
		sel.bg_color = Color(0, 0, 0, 0)
		sel.set_corner_radius_all(RADIUS + 3)
		sel.border_color = Color("fff2dc")
		sel.set_border_width_all(2)
		draw_style_box(sel, rect.grow(3))

	# --- Gece pençe dalgası: kızıl-is kaplaması (söner) ---
	if _curse > 0.0:
		var cv := StyleBoxFlat.new()
		cv.bg_color = Color(0.35, 0.0, 0.02, _curse * 0.6)
		cv.set_corner_radius_all(RADIUS)
		cv.border_color = Color(Palette.BLOOD.r, Palette.BLOOD.g, Palette.BLOOD.b, _curse)
		cv.set_border_width_all(int(4.0 * _curse) + 1)
		draw_style_box(cv, rect)

	# --- Slota oturma tozu: kenarlardan dışa savrulan sıcak zerreler ---
	if _dust > 0.0:
		var dc := Vector2(W, H) * 0.5
		for k in range(10):
			var da := TAU * float(k) / 10.0 + 0.4
			var dist := (W * 0.52) + (1.0 - _dust) * 26.0
			var dp := dc + Vector2(cos(da) * dist, sin(da) * dist * 0.8 + 6.0)
			draw_circle(dp, 2.6 * _dust + 0.6, Color(0.92, 0.78, 0.5, 0.55 * _dust))

	# --- Seat numarası kartın ÜSTÜNDE, konturlu pill ---
	_draw_seat_tag()

	# --- Ayıklama kesme efekti: çapraz parlayan çizik ---
	if _cut > 0.0:
		var a := _cut
		var p1 := Vector2(-8, H * 0.16)
		var p2 := Vector2(W + 8, H * 0.86)
		draw_line(p1, p2, Color(0.7, 0.0, 0.0, a * 0.7), 16.0 * a + 3.0)
		draw_line(p1, p2, Color(1.0, 0.95, 0.85, a), 5.0 * a + 2.0)
		var dark2 := StyleBoxFlat.new()
		dark2.bg_color = Color(0.0, 0.0, 0.0, 0.35 * a)
		dark2.set_corner_radius_all(RADIUS)
		draw_style_box(dark2, Rect2(Vector2.ZERO, size))


## Kart arkası: merkez nazar gözünün SADE, hareketli kopyası — kollar/iris dokusu
## YOK; yalnız dalgalanan kızıl badem + koyu bebek + yumuşak kenar glow.
func _draw_back_eye(rect: Rect2) -> void:
	var c := rect.get_center()
	var tw := _t * 1.1
	var rx := W * 0.30
	var ry := H * 0.25
	for i in range(4):
		var f := float(i) / 4.0
		draw_colored_polygon(_almond(c, rx * (1.0 + f * 0.5), ry * (1.0 + f * 0.5), tw),
			Color(0.7, 0.06, 0.04, 0.10 * (1.0 - f)))
	draw_colored_polygon(_almond(c, rx * 1.16, ry * 1.16, tw), Color(0.05, 0.01, 0.02, 1.0))
	draw_colored_polygon(_almond(c, rx, ry, tw), Color(0.46, 0.03, 0.02, 1.0))
	draw_colored_polygon(_almond(c, rx * 0.9, ry * 0.9, tw), BACK_EYE_RED)
	var look := Vector2(sin(tw * 0.7) * 0.22, sin(tw * 1.05 + 1.0) * 0.18)
	var pc := c + Vector2(look.x * rx * 0.5, look.y * ry * 0.5)
	draw_colored_polygon(_almond(pc, rx * 0.4, ry * 0.5, tw), Color(0.02, 0.0, 0.0, 1.0))


## Dikey badem (elips) + zamanla dalgalanan canlı kenar. Merkez gözle aynı formül.
func _almond(c: Vector2, rx: float, ry: float, tw: float) -> PackedVector2Array:
	var seg := 40
	var pts := PackedVector2Array()
	for i in range(seg):
		var a := TAU * float(i) / float(seg)
		var wob := 1.0 + 0.05 * sin(a * 3.0 + tw) + 0.03 * sin(a * 5.0 - tw * 0.6)
		pts.append(c + Vector2(cos(a) * rx * wob, sin(a) * ry * wob))
	return pts


## Kartın üstünde ortalanmış seat rozeti: koyu pill + konturlu beyaz "#n".
func _draw_seat_tag() -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var txt := "#%d" % seat
	var fs := 16
	var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pw := ts.x + 22.0
	var pill := Rect2(W * 0.5 - pw * 0.5, -32, pw, 25)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.05, 0.03, 0.90)
	sb.set_corner_radius_all(12)
	sb.border_color = _border_color
	sb.set_border_width_all(2)
	draw_style_box(sb, pill)
	var tp := Vector2(W * 0.5 - ts.x * 0.5, -32 + 18)
	draw_string_outline(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color("100804"))
	draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fff2dc"))


## interior hedefi için portrenin (cover-crop) kaynak dikdörtgeni.
func _portrait_src(interior: Rect2) -> Rect2:
	var tw := float(_portrait.get_width())
	var th := float(_portrait.get_height())
	var inner := Rect2(
		tw * CROP_SIDE, th * CROP_TOP,
		tw * (1.0 - 2.0 * CROP_SIDE), th * (1.0 - CROP_TOP - CROP_BOTTOM))
	var s := maxf(interior.size.x / inner.size.x, interior.size.y / inner.size.y)  # cover
	var sw := interior.size.x / s
	var sh := interior.size.y / s
	var sx := inner.position.x + (inner.size.x - sw) * 0.5
	var sy := inner.position.y + (inner.size.y - sh) * 0.25  # üst-orta (yüz) göster
	return Rect2(sx, sy, sw, sh)


func _draw_portrait(interior: Rect2) -> void:
	draw_texture_rect_region(_portrait, interior, _portrait_src(interior))


## Fiziksel bölünme çizimi: iki yarım ayrılır/döner/düşer/söner.
func _draw_split() -> void:
	var prog := _split
	var alpha := 1.0 - smoothstep(0.62, 1.0, prog)
	var sep := prog * W * 0.55
	var fall := prog * 44.0
	var ang := prog * 0.42
	_draw_card_half(true, Vector2(-sep, fall), -ang, alpha)
	_draw_card_half(false, Vector2(sep, fall * 1.12), ang, alpha)
	if prog < 0.33:
		var fa := 1.0 - prog / 0.33
		draw_line(Vector2(W * 0.5, -12), Vector2(W * 0.5, H + 12), Color(1.0, 0.96, 0.86, fa), 7.0)


func _draw_card_half(is_left: bool, offset: Vector2, angle: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	draw_set_transform(Vector2(W, H) * 0.5 + offset, angle, Vector2.ONE)
	var hw := W * 0.5
	var rect := Rect2(-hw, -H * 0.5, hw, H) if is_left else Rect2(0.0, -H * 0.5, hw, H)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(_bg_color.r, _bg_color.g, _bg_color.b, alpha)
	if is_left:
		bg.corner_radius_top_left = RADIUS
		bg.corner_radius_bottom_left = RADIUS
	else:
		bg.corner_radius_top_right = RADIUS
		bg.corner_radius_bottom_right = RADIUS
	draw_style_box(bg, rect)

	if _portrait != null:
		var interior := Rect2(5, 5, W - 10, H - 10)
		var src := _portrait_src(interior)
		var ci := Rect2(5 - hw, 5 - H * 0.5, W - 10, H - 10)
		if is_left:
			draw_texture_rect_region(_portrait,
				Rect2(ci.position, Vector2(ci.size.x * 0.5, ci.size.y)),
				Rect2(src.position, Vector2(src.size.x * 0.5, src.size.y)),
				Color(1, 1, 1, alpha))
		else:
			draw_texture_rect_region(_portrait,
				Rect2(ci.position + Vector2(ci.size.x * 0.5, 0), Vector2(ci.size.x * 0.5, ci.size.y)),
				Rect2(src.position + Vector2(src.size.x * 0.5, 0), Vector2(src.size.x * 0.5, src.size.y)),
				Color(1, 1, 1, alpha))

	var border := StyleBoxFlat.new()
	border.bg_color = Color(0, 0, 0, 0)
	if is_left:
		border.corner_radius_top_left = RADIUS
		border.corner_radius_bottom_left = RADIUS
	else:
		border.corner_radius_top_right = RADIUS
		border.corner_radius_bottom_right = RADIUS
	border.border_color = Color(Palette.BLOOD.r, Palette.BLOOD.g, Palette.BLOOD.b, alpha)
	border.set_border_width_all(4)
	draw_style_box(border, rect)
	draw_line(Vector2(0.0, -H * 0.5), Vector2(0.0, H * 0.5), Color(1.0, 0.4, 0.15, alpha * 0.9), 3.0)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_role_band() -> void:
	var band := StyleBoxFlat.new()
	band.bg_color = _band_color.darkened(0.1)
	band.corner_radius_bottom_left = RADIUS - 3
	band.corner_radius_bottom_right = RADIUS - 3
	draw_style_box(band, Rect2(4, H - BAND_H - 4, W - 8, BAND_H))


func set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


func set_executable_hint(v: bool) -> void:
	executable_hint = v
	queue_redraw()


func set_protect_hint(v: bool) -> void:
	protect_hint = v
	queue_redraw()


func _on_hover_in() -> void:
	_hovered = true
	z_index = 5
	if not _flipping:
		var t := create_tween()
		t.tween_property(self, "scale", Vector2(1.06, 1.06), 0.1).set_trans(Tween.TRANS_SINE)
	hover_changed.emit(seat, true)
	queue_redraw()


func _on_hover_out() -> void:
	_hovered = false
	z_index = 0
	if not _flipping:
		var t := create_tween()
		t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)
	hover_changed.emit(seat, false)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(seat)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			right_clicked.emit(seat)
			accept_event()
