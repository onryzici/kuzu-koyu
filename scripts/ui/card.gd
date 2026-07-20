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
var _is_slain := false     ## ayıklanan kurt: kart yerinde yaralı/kararmış kalır
var _given := 0            ## verdiği ifade sayısı (pip göstergesi)
var _claims_total := 0
var _flipping := false
var _hovered := false
var _curse := 0.0        ## gece pençe efekti (1->0 kızıl-is dalgası)
var _claw := 2.0         ## pençe savuruşları (0..2; ölüm animasyonunda sırayla iner)
var _dust := 0.0         ## slota oturma toz bulutu (1->0)
var _t := 0.0            ## kart-arkası gözü animasyonu
var _mark := 0           ## mevcut işaret (rozet _draw'da çizilir; Label değil)
var _mark_pop := 0.0     ## işaret değişince rozet pop animasyonu (1->0)
var _probe := 0.0            ## göz kolu yoklaması (0..1, yumuşatılmış)
var _probe_target := 0.0
var _probe_dir := Vector2.RIGHT
var _probe_active := false
var conflict_hint := false       ## çelişki: bu kart bir başkasıyla aynı anda dürüst olamaz
var night_risk_hint := false     ## Av Düzeni önizlemesi: bu gece kurban olabilir


func setup(s: int) -> void:
	seat = s


## Kart arkası (dağıtım uçuşu) canlı dursun diye yalnız o sırada her kare çiz.
func _process(delta: float) -> void:
	_t += delta
	if _facedown:
		queue_redraw()
	# Nabızlı rozetler (çelişki/av önizlemesi) canlı kalsın.
	if conflict_hint or night_risk_hint:
		queue_redraw()
	# Göz kolu yoklaması: dokunma yönüne yaslan + ürper (Balatro hover'ın dokunma
	# sürümü); temas kesilince sönümlenip rotasyon sıfırlanır. Dağıtım (facedown)
	# sırasında dokunmaz.
	_probe_target = maxf(0.0, _probe_target - delta * 2.2)
	_probe = lerpf(_probe, _probe_target, minf(1.0, delta * 9.0))
	if _probe > 0.005:
		_probe_active = true
		if not _facedown:
			rotation = _probe_dir.x * 0.085 * _probe + sin(_t * 15.0) * 0.02 * _probe
		queue_redraw()
	elif _probe_active:
		_probe_active = false
		rotation = 0.0
		queue_redraw()


## Board çağırır: gözün kolu bu karta değdi. Yön = uçtan kart merkezine.
func probe_touch(dir: Vector2, strength: float) -> void:
	if dir.length() > 0.001:
		_probe_dir = dir.normalized()
	_probe_target = maxf(_probe_target, clampf(strength, 0.0, 1.0))


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

	_role_label = _make_label(13, HORIZONTAL_ALIGNMENT_CENTER)
	_role_label.position = Vector2(6, H - 30)
	_role_label.size = Vector2(W - 12, 25)
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
	_is_slain = c.executed and c.is_evil()
	_given = c.given
	_claims_total = c.claims.size()

	_seat_label.text = "#%d" % seat

	# İşaret rozeti (_draw çizer): değişince kısa pop animasyonu.
	var mark: int = GameState.village.marks[seat] if seat < GameState.village.marks.size() else Enums.MarkType.NONE
	if mark != _mark:
		_mark = mark
		if mark != Enums.MarkType.NONE:
			_mark_pop = 1.0
			var mt := create_tween()
			mt.tween_method(func(v: float): _mark_pop = v; queue_redraw(), 1.0, 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# V2: yüz HEP açık (iddia edilen rol). Gerçek yüz: ayıklanınca/ölünce.
	var shown_cat := _shown_category(c)
	var cat_col := Palette.category_color(shown_cat)
	_bg_color = Color("2c151a")
	_border_color = cat_col
	_band_color = cat_col
	_portrait = PortraitMap.texture(c.shown_role())
	_role_label.text = RoleNames.display(c.shown_role()).to_upper()
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

	# Rol yazısı bant renginin açık tonu (referans stil: koyu bantta renkli ad).
	_role_label.add_theme_color_override("font_color", _band_color.lightened(0.42))

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


## AYIKLANAN KURT: kart yok olmaz — yerinde pençelenir, kararır ve yara izleri +
## çevresindeki kan lekeleriyle KALIR (kullanıcı kararı: eski ikiye-bölünme efekti
## kaldırıldı; ceset sahnede kalınca hem daha okunur hem daha ürkütücü).
func play_execute_death() -> void:
	_bubble.visible = false
	_curse = 1.0
	var t := create_tween()
	t.tween_method(func(v: float): _curse = v; queue_redraw(), 1.0, 0.0, 1.4)
	# İki pençe savuruşu (gece avıyla aynı dil — tek yerde: _draw_claw_marks).
	_claw = 0.0
	var ct := create_tween()
	ct.tween_interval(0.10)
	for k in range(2):
		ct.tween_method(func(v: float): _claw = v; queue_redraw(),
			float(k), float(k) + 1.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		ct.tween_callback(_claw_punch)
		ct.tween_interval(0.22)
	# Pençeler bitince kart kararıp "ölü" tonuna oturur (hafif kızıl kalıntı).
	var m := create_tween()
	m.tween_interval(0.85)
	m.tween_property(self, "modulate", Color(0.82, 0.70, 0.70, 0.96), 0.7)


## Gece pençesi: kurt bu kartı avladı — kızıl-is dalgası + sarsıntı, sonra solgunlaşır.
func play_night_death() -> void:
	_curse = 1.0
	var t := create_tween()
	t.tween_method(func(v: float): _curse = v; queue_redraw(), 1.0, 0.0, 1.6)
	# İki pençe SAVURUŞU sırayla iner: hızlı süpürüş + kartta sarsıntı punch'ı.
	_claw = 0.0
	var ct := create_tween()
	ct.tween_interval(0.12)
	for k in range(2):
		ct.tween_method(func(v: float): _claw = v; queue_redraw(),
			float(k), float(k) + 1.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		ct.tween_callback(_claw_punch)
		ct.tween_interval(0.24)
	# solgunlaşma (ölü görünüm refresh'te; modulate ile yumuşat) — pençeler bitince.
	modulate = Color(1, 1, 1, 1)
	var m := create_tween()
	m.tween_interval(0.9)
	m.tween_property(self, "modulate", Color(0.72, 0.68, 0.66, 0.92), 0.8)


## Pençe darbesi ânı: kart sarsılır (küçük ezilme + geri esneme).
func _claw_punch() -> void:
	var p := create_tween()
	p.tween_property(self, "scale", Vector2(1.09, 0.96), 0.05).set_trans(Tween.TRANS_SINE)
	p.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Konuşma balonunu gizle (sinematik başında — ekran sade kalsın).
func hide_bubble() -> void:
	if _bubble != null:
		_bubble.visible = false


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
	if _probe > 0.02:
		glow_col = Color(0.86, 0.11, 0.06)  # nazar kızılı — göz bu kartı yokluyor
		glow = maxf(glow, 0.55 * _probe)
	if night_risk_hint and not _is_dead:
		glow_col = Color(0.55, 0.65, 1.0)  # av önizlemesi: gece mavisi nabız
		glow = maxf(glow, 0.35 + 0.20 * sin(_t * 5.0))
	if glow > 0.0 and not (_is_dead or _is_slain):
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
		# İç halka + köşe perçinleri (ön yüz çerçevesiyle aynı dil).
		var fb2 := StyleBoxFlat.new()
		fb2.bg_color = Color(0, 0, 0, 0)
		fb2.set_corner_radius_all(RADIUS - 4)
		fb2.border_color = EYE_COPPER.darkened(0.35)
		fb2.set_border_width_all(2)
		draw_style_box(fb2, rect.grow(-7))
		for corner in [Vector2(10, 10), Vector2(W - 10, 10), Vector2(10, H - 10), Vector2(W - 10, H - 10)]:
			_draw_stud(corner, 3.2, EYE_COPPER)
	else:
		if _portrait != null:
			_draw_portrait(Rect2(5, 5, W - 10, H - 10))

		# Portre alt geçişi: banda inen YUMUŞAK gradyan (vertex renkli — bantsız/kademesiz).
		draw_polygon(PackedVector2Array([
			Vector2(5, H - 62), Vector2(W - 5, H - 62), Vector2(W - 5, H - 5), Vector2(5, H - 5),
		]), PackedColorArray([
			Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.55),
		]))

		# Alt isim bandı: tam genişlik koyu şerit + üstünde kategori renkli ayraç çizgisi.
		var band := StyleBoxFlat.new()
		band.bg_color = Color(0.055, 0.03, 0.035, 0.96)
		band.corner_radius_bottom_left = RADIUS - 3
		band.corner_radius_bottom_right = RADIUS - 3
		draw_style_box(band, Rect2(5, H - 30, W - 10, 25))
		draw_line(Vector2(6, H - 30), Vector2(W - 6, H - 30), _band_color, 2.0)

		# --- Çerçeve: dış ince koyu jant + kategori renkli ana çerçeve (temiz, sade) ---
		var rim := StyleBoxFlat.new()
		rim.bg_color = Color(0, 0, 0, 0)
		rim.set_corner_radius_all(RADIUS + 2)
		rim.border_color = Color(0.05, 0.02, 0.02, 0.9)
		rim.set_border_width_all(2)
		draw_style_box(rim, rect.grow(2))
		var border := StyleBoxFlat.new()
		border.bg_color = Color(0, 0, 0, 0)
		border.set_corner_radius_all(RADIUS)
		border.border_color = _border_color if not (selected or _hovered) else _border_color.lightened(0.12)
		border.set_border_width_all(5)
		draw_style_box(border, rect)

		# Gece kurbanı / ayıklanan kurt: karartma + pençe yırtıkları (aynı dil).
		if _is_dead or _is_slain:
			var dark := StyleBoxFlat.new()
			# Kurt cesedi hafif kızıl-karanlık; koyun kurbanı gri-karanlık.
			dark.bg_color = Color(0.10, 0.02, 0.03, 0.50) if _is_slain else Color(0.06, 0.04, 0.05, 0.55)
			dark.set_corner_radius_all(RADIUS)
			draw_style_box(dark, rect)
			_draw_claw_marks()
			# mezar işareti yalnız gece kurbanında (kesin İYİ ceset — kanıt dili)
			if _is_dead:
				var font := get_theme_default_font()
				if font != null:
					draw_string_outline(font, Vector2(W - 30, 30), "✝", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 4, Color(0, 0, 0, 0.9))
					draw_string(font, Vector2(W - 30, 30), "✝", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("d8cfc2"))

		# İfade pip'leri: verdiği/toplam (sorgu ekonomisi göstergesi, sol-üst).
		if not (_is_dead or _is_slain) and _claims_total > 0:
			for k in range(_claims_total):
				var pc := Vector2(14 + k * 13.0, 14)
				draw_circle(pc, 4.5, Color(0, 0, 0, 0.65))
				draw_circle(pc, 3.2, Color("e4a72e") if k < _given else Color("4a3a30"))

		# İşaret rozeti: sağ-üst köşeye oturan disk + çizilmiş şekil (hizalı, net).
		if not (_is_dead or _is_slain) and _mark != Enums.MarkType.NONE:
			_draw_mark_badge()

		# Çelişki rozeti: sol-alt köşede amber şimşek — "bu ifade başka biriyle
		# çelişiyor". Hover'da board çelişki ortaklarına kesikli hat çizer.
		if not (_is_dead or _is_slain) and conflict_hint:
			_draw_conflict_badge()

		# Kapan rozeti: bu koltuğa gecelik tuzak kurulu (Tuzakçı yeteneği).
		if not (_is_dead or _is_slain) and GameState.village != null and GameState.village.trap_seat == seat:
			_draw_trap_badge()

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


## İşaret rozeti: sağ-üst köşede koyu disk + renkli halka + VEKTÖR şekil.
## Font glifi değil (hizalama derdi yok); işaret değişince kısa pop büyümesi.
## Kapan rozeti: alt-orta çelik çene — iki sıra zigzag diş (kurulu tuzak işareti).
func _draw_trap_badge() -> void:
	var c := Vector2(W * 0.5, H - 16.0)
	draw_circle(c, 12.5, Color(0.05, 0.04, 0.03, 0.92))
	draw_arc(c, 12.5, 0, TAU, 24, Color(0.72, 0.70, 0.64, 0.9), 1.6)
	for side in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for i in range(5):
			var x := -8.0 + 4.0 * float(i)
			var jag := -4.0 if i % 2 == 0 else 0.5
			pts.append(c + Vector2(x, side * (3.0 + jag)))
		draw_polyline(pts, Color(0.85, 0.82, 0.74), 1.8)


## Çelişki rozeti: sol-alt köşede koyu disk + amber şimşek (çakışan ifade uyarısı).
func _draw_conflict_badge() -> void:
	var c := Vector2(16.0, H - 42.0)
	var pulse := 0.85 + 0.15 * sin(_t * 4.0)
	draw_circle(c, 11.0, Color(0.06, 0.03, 0.02, 0.92))
	draw_arc(c, 11.0, 0, TAU, 22, Color(0.89, 0.65, 0.18, 0.9 * pulse), 1.6)
	# Şimşek: iki kırık çizgiden zigzag.
	var col := Color(0.95, 0.72, 0.2, pulse)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(1.5, -6.5), c + Vector2(-3.5, 0.5), c + Vector2(-0.5, 0.5),
		c + Vector2(-1.5, 6.5), c + Vector2(3.5, -0.5), c + Vector2(0.5, -0.5),
	]), col)


func _draw_mark_badge() -> void:
	var col := Palette.mark_color(_mark)
	var c := Vector2(W - 12.0, 12.0)
	var s := 1.0 + 0.38 * _mark_pop
	var r := 12.0 * s
	draw_circle(c + Vector2(1.5, 2.2), r + 1.2, Color(0, 0, 0, 0.55))  # sert gölge
	draw_circle(c, r, Color(0.07, 0.035, 0.03, 0.97))
	draw_arc(c, r - 0.5, 0, TAU, 28, col, 2.2)
	var g := r * 0.52
	match _mark:
		Enums.MarkType.MARK_GOOD:      # üçgen (iyi)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -g * 1.05), c + Vector2(g * 0.95, g * 0.72), c + Vector2(-g * 0.95, g * 0.72),
			]), col)
		Enums.MarkType.MARK_SUSPECT:   # elmas (şüpheli)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -g * 1.1), c + Vector2(g * 0.85, 0), c + Vector2(0, g * 1.1), c + Vector2(-g * 0.85, 0),
			]), col)
		Enums.MarkType.MARK_EVIL:      # çarpı (kurt)
			draw_line(c + Vector2(-g, -g), c + Vector2(g, g), col, 3.2)
			draw_line(c + Vector2(g, -g), c + Vector2(-g, g), col, 3.2)
		Enums.MarkType.MARK_QUESTION:  # ünlem (soru)
			draw_line(c + Vector2(0, -g * 1.05), c + Vector2(0, g * 0.30), col, 3.2)
			draw_circle(c + Vector2(0, g * 0.85), 2.0, col)


## Pençe yırtıkları: üç kavisli, uçlara doğru incelen çizik (iğ biçimli poligon,
## koyu dış + kızıl iç + taze et çizgisi) + uç noktalarda kan damlaları.
## Gece ölüm animasyonu (_curse 1->0) oynarken yırtıklar yukarıdan aşağı "atılır".
func _draw_claw_marks() -> void:
	# İKİ pençe SAVURUŞU; her savuruş 3 PARALEL yara bırakır (gerçek pençe izi).
	# Yara anatomisi: açık renkli YIRTIK KÂĞIT kenarı + koyu derin oyuk + kan çizgisi.
	var swipes := [
		{"from": Vector2(0.24, 0.16), "to": Vector2(0.66, 0.84), "bow": 5.0},
		{"from": Vector2(0.82, 0.24), "to": Vector2(0.36, 0.80), "bow": -5.0},
	]
	for k in range(swipes.size()):
		var prog := clampf(_claw - float(k), 0.0, 1.0)
		if prog <= 0.0:
			continue
		var fresh := 1.0 - prog
		var sw: Dictionary = swipes[k]
		var a := Vector2(sw.from.x * W, sw.from.y * H)
		var b0 := Vector2(sw.to.x * W, sw.to.y * H)
		var dirv := (b0 - a).normalized()
		var perp := Vector2(-dirv.y, dirv.x)
		for g in range(3):
			# Paralel tırnaklar: orta uzun, yanlar hafif kısa ve kademeli başlar.
			var off := perp * (float(g) - 1.0) * 12.0
			var lag := dirv * absf(float(g) - 1.0) * 9.0
			var ga := a + off + lag
			var gb := ga.lerp(b0 + off - lag, prog)
			var w := 5.6 - absf(float(g) - 1.0) * 1.3
			var bow: float = sw.bow
			# 1) Yırtık kâğıt kenarı (kartın açık tonu — kenara ışık vurur).
			_draw_claw_slash(ga + Vector2(1.2, 1.2), gb + Vector2(1.2, 1.2), w * 1.9, bow,
				Color(0.86, 0.78, 0.64, 0.8))
			# 2) Derin oyuk (neredeyse siyah — yaranın gövdesi).
			_draw_claw_slash(ga, gb, w * 1.35, bow, Color(0.07, 0.015, 0.02, 0.97))
			# 3) Kan çizgisi (taze inişte parlak, sonra koyulaşır).
			_draw_claw_slash(ga, gb, w * 0.55, bow,
				Color(0.48 + 0.34 * fresh, 0.05 + 0.12 * fresh, 0.05, 0.95))
		# Savuruş ucunda kan damlaları (savuruş tamamlanınca).
		if prog > 0.9:
			var tip := b0
			draw_circle(tip + Vector2(1.0, 6.0), 2.4, Color(0.45, 0.05, 0.04, 0.85))
			draw_circle(tip + Vector2(-3.0, 11.0), 1.5, Color(0.40, 0.04, 0.04, 0.7))
			draw_circle(tip + perp.x * Vector2(4.0, 4.0) + Vector2(0, 14.0), 1.1, Color(0.38, 0.04, 0.04, 0.6))


## Tek yırtık: uçlarda sıfıra inen genişlik (iğ) + orta boyunca hafif kavis.
func _draw_claw_slash(from: Vector2, to: Vector2, w: float, bow: float, col: Color) -> void:
	var seg := 10
	var d := to - from
	var length := d.length()
	if length < 2.0:
		return
	d /= length
	var perp := Vector2(-d.y, d.x)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(seg + 1):
		var t := float(i) / float(seg)
		var half_w := w * 0.5 * sin(PI * t)          # uçlarda 0, ortada max
		var p := from + d * (length * t) + perp * (bow * sin(PI * t))
		left.append(p + perp * half_w)
		right.append(p - perp * half_w)
	var pts := PackedVector2Array()
	for p in left:
		pts.append(p)
	for i in range(right.size()):
		pts.append(right[right.size() - 1 - i])
	draw_colored_polygon(pts, col)


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


## Minik elmas perçin (kart arkası köşe süsü): renkli elmas + fildişi parlak nokta.
func _draw_stud(c: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0),
	]), col)
	draw_circle(c, s * 0.32, Color(1, 1, 0.92, 0.75))


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
