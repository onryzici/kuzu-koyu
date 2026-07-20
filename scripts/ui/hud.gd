class_name Hud
extends Control

## Köy tahtası HUD'u. Bkz. CLAUDE.md §11. Değerleri GameState'ten okur,
## EventBus sinyalleriyle güncellenir. İş mantığı yok.

signal execute_toggled
signal day_end_requested
signal log_toggled                       ## İfade Defteri butonu
signal night_hover_changed(hovering: bool)  ## GECE hover → av önizlemesi
signal restart_requested

var _quest_label: Label
var _progress_label: Label
var _day_label: Label          ## "Gün 2/5 · Sorgu ●●○"
var _deaths_label: Label       ## "☠ Kurbanlar: #2, #5" — nirengi kanıtı
var _mod_label: Label          ## köy modifier ilanı (Suskun Sürü / Kanlı Ay / Kuraklık)
var _mod_strip: Dictionary = {}  ## _menu_strips içindeki modifier şeridi (referans)
var _meta_label: Label
var _village_label: Label
var _score_label: Label
var _day_btn: Button           ## Günü Bitir (gece) butonu
var _log_btn: Button           ## İfade Defteri butonu (TAB)
var _info_btn: Button          ## "?" Kurallar butonu (oyun içi bilgi — menüden kalktı)
var _buyq_btn: Button          ## parayla +1 sorgu (yalnız seferde — para döngüde işlesin)
var _banner: RibbonBanner  ## board sahibi; attach_banner ile bağlanır
var _menu_strips: Array = []   ## sol menü banner'ları (kendi tasarım; intro'da kayar)
var _comp_off := 0.0           ## kompozisyon paneli sağdan giriş kayması
var _legend_off := 0.0         ## mark lejantı + ayıkla butonu sağdan giriş
var _globe_off := 0.0          ## can küresi soldan giriş
var _execute_btn: Button
var _exec_icon: Control        ## butonun içine çizilen hançer/iptal ikonu (emoji yok)
var _day_icon: Control         ## gece butonuna çizilen hilal ikonu (emoji yok)
var _exec_mode := false
var _overlay: ColorRect
var _overlay_label: Label
var _restart_btn: Button
var _dmg_flash: ColorRect
var _hp_display := 1.0        ## animasyonlu can oranı (çizim için)
var _hp_animating := false
var _globe_shake := Vector2.ZERO
var _hp_num_scale := 1.0

const GLOBE_R := 54.0
const EYE_RED := Color(0.86, 0.11, 0.06)   ## merkez gözle aynı kırmızı
var _t := 0.0                              ## dalgalanan border animasyonu için


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_connect_events()
	update_all()


## Dalgalanan border'lar için her kare yeniden çiz.
func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	# Buton ikonları canlı (göz bebeği gezinir, zZz süzülür) — her kare tazele.
	if _exec_icon != null:
		_exec_icon.queue_redraw()
	if _day_icon != null:
		_day_icon.queue_redraw()


## Yuvarlak buton çerçevesi: yumuşak düşen gölge; hover'da gölge butonla birlikte
## büyür + arkada sıcak hale belirir. Av modu sinyali ring_col ile ince tek halka.
func _draw_button_frame(c: Vector2, r: float, ring_col: Color, hovered: bool) -> void:
	var rr := r * (1.08 if hovered else 1.0)
	draw_circle(c + Vector2(0, 5), rr + 6.0, Color(0, 0, 0, 0.35))
	if hovered:
		# Sıcak kandil parıltısı — imleç üstündeyken buton "uyanır".
		draw_circle(c, rr + 24.0, Color(0.95, 0.72, 0.35, 0.05))
		draw_circle(c, rr + 12.0, Color(0.95, 0.72, 0.35, 0.09))
	# Av modu açıkken tek ince kızıl halka (işlevsel sinyal; süs değil).
	if ring_col.r > 0.5:
		draw_arc(c, rr + 2.0, 0, TAU, 56, ring_col, 2.5, true)


## Dalgalanan (organik) dolu disk — siyah border'ların temeli.
func _draw_wavy_disc(c: Vector2, r: float, col: Color, tw: float, amp: float) -> void:
	var seg := 46
	var pts := PackedVector2Array()
	for i in range(seg):
		var a := TAU * float(i) / float(seg)
		var rr := r + amp * sin(a * 3.0 + tw) + amp * 0.5 * sin(a * 5.0 - tw * 0.7)
		pts.append(c + Vector2(cos(a) * rr, sin(a) * rr))
	draw_colored_polygon(pts, col)


func _build() -> void:
	# Sol menü: ayrı istiflenmiş paneller (referans stili), intro'da yandan kayar.
	_build_left_menu()

	# Kompozisyon başlığı + rozetleri artık _draw'da (kayma animasyonu için).

	# Can küresi (sol-alt): tüm çizim (gauge + sayı) _draw'da.

	# Duyuru şeridi (RibbonBanner) BOARD'a aittir — gece HUD çekilirken görünür
	# kalsın diye; attach_banner ile bağlanır.

	# Arındır butonu — yuvarlak ritüel-hançer butonu (sağ-alt köşe, mutlak konum).
	# Metin yerine ÇİZİLMİŞ ikon (hançer / iptal çarpısı) + altında ad — emoji yok.
	_execute_btn = Button.new()
	_execute_btn.text = ""
	_execute_btn.position = Vector2(1466, 752)
	_execute_btn.size = Vector2(116, 116)
	_execute_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_round_button(_execute_btn)
	_execute_btn.pressed.connect(func(): execute_toggled.emit())
	add_child(_execute_btn)
	_exec_icon = _add_btn_icon(_execute_btn, _draw_exec_icon)
	_setup_hover(_execute_btn)

	# Günü Bitir (gece) butonu — Ayıkla'nın üstünde, gece indigo yuvarlak.
	# Emniyet: sorgu hakkı dururken ilk basış UYARIR, 2.5 sn içinde ikinci basış onaylar.
	_day_btn = Button.new()
	_day_btn.text = ""
	_day_btn.position = Vector2(1478, 618)
	_day_btn.size = Vector2(92, 92)
	_day_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_night_button(_day_btn)
	_day_btn.pressed.connect(_on_day_btn)
	# Hover: Av Düzeni önizlemesi (board olası kurbanları vurgular).
	_day_btn.mouse_entered.connect(func(): night_hover_changed.emit(true))
	_day_btn.mouse_exited.connect(func(): night_hover_changed.emit(false))
	add_child(_day_btn)
	_day_icon = _add_btn_icon(_day_btn, _draw_day_icon)
	_setup_hover(_day_btn)

	# İfade Defteri butonu — gece butonunun solunda küçük yuvarlak (TAB kısayolu).
	_log_btn = Button.new()
	_log_btn.text = ""
	_log_btn.position = Vector2(1392, 634)
	_log_btn.size = Vector2(62, 62)
	_log_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_log_btn.tooltip_text = Loc.t("log_btn_tip")
	_style_night_button(_log_btn)
	_log_btn.pressed.connect(func(): log_toggled.emit())
	add_child(_log_btn)
	_add_btn_icon(_log_btn, _draw_log_icon)
	_setup_hover(_log_btn)

	# Bilgi butonu — defterin solunda küçük yuvarlak "?" (Kurallar overlay'i açar).
	# Ana menüdeki Kurallar butonu kaldırıldı; oyun içi erişim noktası burası + ESC.
	_info_btn = Button.new()
	_info_btn.text = ""
	_info_btn.position = Vector2(1318, 634)
	_info_btn.size = Vector2(62, 62)
	_info_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_info_btn.tooltip_text = Loc.t("menu_rules")
	_style_night_button(_info_btn)
	_info_btn.pressed.connect(func(): GameMenu.open_rules())
	add_child(_info_btn)
	_add_btn_icon(_info_btn, _draw_info_icon)
	_setup_hover(_info_btn)

	# Sorgu satın alma butonu — "?"nin solunda, amber para pulu (yalnız seferde).
	# Fiyat her alışta tırmanır (GameState.question_price); etiket _draw'da.
	_buyq_btn = Button.new()
	_buyq_btn.text = ""
	_buyq_btn.position = Vector2(1244, 634)
	_buyq_btn.size = Vector2(62, 62)
	_buyq_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_night_button(_buyq_btn)
	_buyq_btn.pressed.connect(_on_buy_question)
	_buyq_btn.visible = false
	add_child(_buyq_btn)
	_add_btn_icon(_buyq_btn, _draw_buyq_icon)
	_setup_hover(_buyq_btn)

	# Hasar flaşı (tam ekran kızıl, başta görünmez)
	_dmg_flash = ColorRect.new()
	_dmg_flash.color = Color(0.7, 0.0, 0.0, 0.0)
	_dmg_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dmg_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dmg_flash)

	# Sonuç overlay'i (başta gizli). Karartma güçlü — yazılar kartların üstünde
	# okunaklı dursun (kullanıcı geri bildirimi: yazı/kart çakışması).
	_overlay = ColorRect.new()
	_overlay.color = Color(0.03, 0.02, 0.04, 0.90)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	_overlay_label = Label.new()
	_overlay_label.add_theme_font_size_override("font_size", 40)
	_overlay_label.add_theme_constant_override("outline_size", 10)
	_overlay_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_label.offset_top = -60
	_overlay.add_child(_overlay_label)

	_restart_btn = Button.new()
	_restart_btn.text = Loc.t("new_village_btn")
	_restart_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_restart_btn.position = Vector2(-85, 40)
	_restart_btn.size = Vector2(170, 44)
	_restart_btn.pressed.connect(func(): restart_requested.emit())
	_overlay.add_child(_restart_btn)


## Sol menü — KENDİ banner tasarımım: koyu maroon gövde + bronz kenar + sivri kuyruk,
## ekran kenarına TAM BİTİŞİK. Etiketler node, banner gövdeleri _draw'da (altta).
const MENU_PAD := 24.0
const BANNER_FILL := Color(0.0, 0.0, 0.0, 0.96)  # full siyah

func _build_left_menu() -> void:
	_quest_label = _menu_label(19, Color("f4e9cf"))
	_progress_label = _menu_label(17, Palette.SAFFRON)
	_day_label = _menu_label(17, Color("9db8e8"))  # gün/sorgu — gece mavisi
	_deaths_label = _menu_label(15, Color("d88f8a"))  # kanıt: gece kurbanları
	_village_label = _menu_label(15, Palette.IVORY.darkened(0.08))
	_meta_label = _menu_label(15, Palette.COPPER.lightened(0.25))  # para/ascension
	_score_label = _menu_label(16, Color("8fe0a0"))
	# Modifier ilanı (adalet §7.3: köy kuralı BAŞTAN duyurulur) — amber, dikkat çekici.
	_mod_label = _menu_label(15, Color("f0b53c"))
	# Aralarında belirgin boşluk (dip dibe olmasın): gap ~20px.
	_menu_strips = [
		{"label": _quest_label, "y": 14.0, "w": 430.0, "h": 56.0, "off": -560.0, "visible": true},
		{"label": _progress_label, "y": 96.0, "w": 300.0, "h": 48.0, "off": -560.0, "visible": true},
		{"label": _day_label, "y": 164.0, "w": 300.0, "h": 48.0, "off": -560.0, "visible": true},
		{"label": _deaths_label, "y": 232.0, "w": 300.0, "h": 48.0, "off": -560.0, "visible": false},
		{"label": _village_label, "y": 232.0, "w": 300.0, "h": 48.0, "off": -560.0, "visible": true},
		{"label": _meta_label, "y": 300.0, "w": 330.0, "h": 48.0, "off": -560.0, "visible": true},
		{"label": _score_label, "y": 368.0, "w": 290.0, "h": 48.0, "off": -560.0, "visible": true},
	]
	_mod_strip = {"label": _mod_label, "y": 436.0, "w": 340.0, "h": 48.0, "off": -560.0, "visible": false}
	_menu_strips.append(_mod_strip)
	_layout_menu()


func _menu_label(fs: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


const MENU_TAIL := 44.0   ## yazıdan sonra sağ pah/kuyruk için pay
const MENU_GAP := 24.0    ## banner'lar arası dikey boşluk

## Her banner genişliği YAZIYA GÖRE; görünür banner'lar üstten alta OTOMATİK istiflenir
## (gizlenen olursa boşluk kalmaz).
func _layout_menu() -> void:
	var y := 14.0
	for s in _menu_strips:
		var l: Label = s["label"]
		l.visible = s["visible"]
		if not s["visible"]:
			continue
		var tw: float = l.get_minimum_size().x
		s["w"] = MENU_PAD + tw + MENU_TAIL
		s["y"] = y
		l.position = Vector2(s["off"] + MENU_PAD, y)
		l.size = Vector2(tw + 6.0, s["h"])
		y += s["h"] + MENU_GAP


## KÖŞELİ (pahlı/beveled) banner: dış köşeler 45° kesik + KÖŞELİ offset gölge (blur
## değil). Flush kenar ekran dışına taşar. flip=false sola, true sağa bitişik.
func _draw_banner(x: float, y: float, w: float, h: float, flip: bool) -> void:
	var pts := _banner_poly(x, y, w, h, 13.0, flip)
	# Köşeli (sert) offset gölge — solid poligon, blur yok.
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(7, 9))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.6))
	# Gövde (full siyah; üst highlight yok)
	draw_colored_polygon(pts, BANNER_FILL)


## Yüzen (kenara bitişik olmayan) panel: 4 köşesi 45° pahlı + köşeli sert gölge, siyah.
func _draw_panel_beveled(x: float, y: float, w: float, h: float) -> void:
	var c := 12.0
	var pts := PackedVector2Array([
		Vector2(x + c, y), Vector2(x + w - c, y), Vector2(x + w, y + c), Vector2(x + w, y + h - c),
		Vector2(x + w - c, y + h), Vector2(x + c, y + h), Vector2(x, y + h - c), Vector2(x, y + c)])
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(6, 8))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.6))
	draw_colored_polygon(pts, BANNER_FILL)


## Köşeleri 45° kesik banner poligonu (flush kenar `ext` kadar ekran dışına taşar).
func _banner_poly(x: float, y: float, w: float, h: float, c: float, flip: bool) -> PackedVector2Array:
	var ext := 14.0
	if not flip:
		# flush SOL (sol kenar ekran dışı), pahlı SAĞ köşeler
		return PackedVector2Array([
			Vector2(x - ext, y),
			Vector2(x + w - c, y),
			Vector2(x + w, y + c),
			Vector2(x + w, y + h - c),
			Vector2(x + w - c, y + h),
			Vector2(x - ext, y + h)])
	# flush SAĞ (sağ kenar ekran dışı), pahlı SOL köşeler
	return PackedVector2Array([
		Vector2(x + c, y),
		Vector2(x + w + ext, y),
		Vector2(x + w + ext, y + h),
		Vector2(x + c, y + h),
		Vector2(x, y + h - c),
		Vector2(x, y + c)])


## Tüm HUD panelleri EKRAN DIŞINDAN (drawer gibi) içeri kayar: sol menü soldan,
## kompozisyon/lejant/buton sağdan, can küresi soldan. Staggered.
func play_intro() -> void:
	# Sol menü — soldan, tam ekran dışından (drawer). Her banner kendi off'uyla kayar.
	for i in range(_menu_strips.size()):
		var s: Dictionary = _menu_strips[i]
		s["off"] = -560.0
		var t := create_tween()
		t.tween_interval(0.05 + i * 0.09)
		t.tween_method(func(v: float): s["off"] = v; _layout_menu(); queue_redraw(), -560.0, 0.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Kompozisyon paneli — sağdan.
	_comp_off = 560.0
	var ct := create_tween()
	ct.tween_interval(0.15)
	ct.tween_method(func(v: float): _comp_off = v; queue_redraw(), 560.0, 0.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Ayıkla/gece/defter butonları — sağdan giriş.
	var ex0 := _execute_btn.position.x
	var dx0 := _day_btn.position.x
	var lg0 := _log_btn.position.x
	var in0 := _info_btn.position.x
	var bq0 := _buyq_btn.position.x
	_legend_off = 560.0
	_execute_btn.position.x = ex0 + 560.0
	_day_btn.position.x = dx0 + 560.0
	_log_btn.position.x = lg0 + 560.0
	_info_btn.position.x = in0 + 560.0
	_buyq_btn.position.x = bq0 + 560.0
	var lt := create_tween()
	lt.tween_interval(0.22)
	lt.tween_method(func(v: float):
		_legend_off = v
		_execute_btn.position.x = ex0 + v
		_day_btn.position.x = dx0 + v
		_log_btn.position.x = lg0 + v
		_info_btn.position.x = in0 + v
		_buyq_btn.position.x = bq0 + v
		queue_redraw(), 560.0, 0.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Can küresi — soldan.
	_globe_off = -360.0
	var gt := create_tween()
	gt.tween_interval(0.1)
	gt.tween_method(func(v: float): _globe_off = v; queue_redraw(), -360.0, 0.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _style_button(btn: Button, bg: Color, border: Color) -> void:
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg.darkened(0.5) if state == "normal" else (bg.darkened(0.3) if state == "hover" else bg.darkened(0.6))
		sb.set_corner_radius_all(10)
		sb.border_color = border
		sb.set_border_width_all(2)
		sb.set_content_margin_all(8)
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", Palette.IVORY)


## Yuvarlak buton hover'ı: yumuşak büyüme (geri esnemeli), çıkışta sakin dönüş.
## Basılıyken hafif çökme. Parıltı _draw'daki çerçevede (is_hovered ile).
func _setup_hover(btn: Button) -> void:
	btn.pivot_offset = btn.size * 0.5
	btn.mouse_entered.connect(func():
		var t := create_tween()
		t.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.14) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	btn.mouse_exited.connect(func():
		var t := create_tween()
		t.tween_property(btn, "scale", Vector2.ONE, 0.16) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT))
	btn.button_down.connect(func():
		var t := create_tween()
		t.tween_property(btn, "scale", Vector2(0.97, 0.97), 0.06))
	btn.button_up.connect(func():
		var t := create_tween()
		t.tween_property(btn, "scale", Vector2(1.08, 1.08) if btn.is_hovered() else Vector2.ONE, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


## Butonun içine tam-kaplama, tıklama yutmayan ikon katmanı ekler.
func _add_btn_icon(btn: Button, draw_fn: Callable) -> Control:
	var ic := Control.new()
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.draw.connect(draw_fn.bind(ic))
	btn.add_child(ic)
	return ic


## Merkez nazar gözünün minyatür konturu (aynı wobble dili) — buton ikonları
## board'daki dev gözle akraba görünsün (kullanıcı isteği: "o tarz bi şey").
func _mini_eye(c: Vector2, rx: float, ry: float, tw: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(36):
		var a := TAU * float(i) / 36.0
		var wob := 1.0 + 0.05 * sin(a * 3.0 + tw) + 0.03 * sin(a * 5.0 - tw * 0.6)
		var yb := sin(a)
		pts.append(c + Vector2(cos(a) * rx * wob, yb * ry * (1.0 + 0.06 * yb) * wob))
	return pts


## Defter butonu ikonu: TOMAR (rulo parşömen) — üst/alt rulo + gövde + satırlar.
func _draw_log_icon(ic: Control) -> void:
	var parch := Color("e8dcc0")
	var ink := Color("6a5a42")
	var c := Vector2(ic.size.x * 0.5, ic.size.y * 0.5)
	# Gövde (dikey parşömen şeridi).
	ic.draw_rect(Rect2(c + Vector2(-9.0, -11.0), Vector2(18.0, 22.0)), parch)
	# Üst ve alt rulolar: gövdeden koyu ayrım çizgisiyle kopan silindirler.
	for sy: float in [-1.0, 1.0]:
		var ry: float = c.y + sy * 12.0
		ic.draw_rect(Rect2(Vector2(c.x - 12.0, ry - 3.0), Vector2(24.0, 6.0)), parch)
		ic.draw_line(Vector2(c.x - 12.0, ry - sy * 3.0), Vector2(c.x + 12.0, ry - sy * 3.0),
			Color(ink.r, ink.g, ink.b, 0.5), 1.4)
		ic.draw_circle(Vector2(c.x - 12.0, ry), 3.0, parch)
		ic.draw_circle(Vector2(c.x + 12.0, ry), 3.0, parch)
		ic.draw_circle(Vector2(c.x + 12.0, ry), 1.4, ink)
	# Satırlar (yazı hissi).
	for r in [-5.0, 0.0, 5.0]:
		ic.draw_line(c + Vector2(-5.5, r), c + Vector2(5.5, r), Color(ink.r, ink.g, ink.b, 0.75), 1.5)


## Sorgu satın alma ikonu: amber para pulu + artı (köy içinde para harcama noktası).
func _draw_buyq_icon(ic: Control) -> void:
	var gold := Color("ffd479")
	var c := ic.size * 0.5 + Vector2(0, -2.0)
	ic.draw_circle(c, 11.0, Color(0.24, 0.16, 0.05))
	ic.draw_arc(c, 11.0, 0, TAU, 26, gold, 2.2, true)
	ic.draw_arc(c, 7.4, 0, TAU, 22, Color(gold.r, gold.g, gold.b, 0.55), 1.2, true)
	# Artı: sağ-alt köşede küçük yeşilimsi rozet ("+1 sorgu").
	var pc := c + Vector2(11.0, 11.0)
	ic.draw_circle(pc, 7.0, Color(0.10, 0.16, 0.10))
	ic.draw_arc(pc, 7.0, 0, TAU, 18, Color("8fe0a0"), 1.6, true)
	ic.draw_line(pc + Vector2(-3.4, 0), pc + Vector2(3.4, 0), Color("8fe0a0"), 2.0)
	ic.draw_line(pc + Vector2(0, -3.4), pc + Vector2(0, 3.4), Color("8fe0a0"), 2.0)


func _on_buy_question() -> void:
	var price := GameState.question_price()
	if GameState.buy_question():
		AudioManager.play_deal()
		flash_banner(Loc.t("buyq_ok") % price, Color("8fe0a0"))
	else:
		flash_banner(Loc.t("buyq_poor") % price, Palette.BLOOD)
	update_all()


## Bilgi butonu ikonu: soru işareti (yay + kısa sap + nokta) — kurallara erişim.
func _draw_info_icon(ic: Control) -> void:
	var col := Color("e8dcc0")
	var c := ic.size * 0.5
	ic.draw_arc(c + Vector2(0, -5.0), 7.5, -PI * 0.9, PI * 0.55, 20, col, 3.0, true)
	ic.draw_line(c + Vector2(2.3, 0.2), c + Vector2(0, 5.5), col, 3.0)
	ic.draw_circle(c + Vector2(0, 11.0), 2.4, col)


## Gece butonu ikonu: dolgun HİLAL (gerçek iki-çember kesişimiyle hesaplanmış
## kavis) + minik yıldızlar. Altında "GECE".
func _draw_day_icon(ic: Control) -> void:
	var moon := Color("f2e6bf")
	var c := ic.size * 0.5
	# Hilal poligonu: dış çember r=13, kesen çember merkez +7x r=10.
	# Kesişim açıları: dışta ±49.6° (0.867 rad), kesende ±81.8° (1.427 rad).
	var pts := PackedVector2Array()
	var seg := 22
	for i in range(seg + 1):
		var a := lerpf(0.867, TAU - 0.867, float(i) / float(seg))  # dış yay (uzun yol)
		pts.append(c + Vector2(cos(a), sin(a)) * 13.0)
	for i in range(seg + 1):
		var a := lerpf(TAU - 1.427, 1.427, float(i) / float(seg))  # kesen yay (geri)
		pts.append(c + Vector2(7.0, 0.0) + Vector2(cos(a), sin(a)) * 10.0)
	ic.draw_colored_polygon(pts, moon)
	# Hilalin açığında iki minik yıldız (twinkle).
	for s in [[Vector2(9.0, -8.0), 0.0], [Vector2(12.0, 3.0), 2.4]]:
		var sp: Vector2 = c + s[0]
		var tw := 0.6 + 0.4 * sin(_t * 2.6 + float(s[1]))
		ic.draw_line(sp + Vector2(-3.2 * tw, 0), sp + Vector2(3.2 * tw, 0), moon, 1.5)
		ic.draw_line(sp + Vector2(0, -3.2 * tw), sp + Vector2(0, 3.2 * tw), moon, 1.5)


## Avla butonu ikonu: KESKİN NİŞANGÂH — tırnak hizalarında boşluklu dış halka
## (dürbün retikülü), içeri uzanan tırnaklar, ince iç artı + merkez nokta.
## Yavaşça döner + nefes alır. Av modunda vazgeç çarpısı. Yazı yok (ikon yeter).
func _draw_exec_icon(ic: Control) -> void:
	var cream := Color("fff2dc")
	var red := Color(0.84, 0.17, 0.12)
	var c := ic.size * 0.5
	if _exec_mode:
		# Vazgeç: kalın çarpı.
		ic.draw_line(c + Vector2(-13, -13), c + Vector2(13, 13), cream, 6.0)
		ic.draw_line(c + Vector2(13, -13), c + Vector2(-13, 13), cream, 6.0)
		return
	var rot := _t * 0.5                      # yavaş retikül dönüşü
	var r := 19.0 + 1.0 * sin(_t * 2.2)      # nefes
	# Dış halka: tırnak hizalarında boşluk bırakan 4 yay (retikül dili).
	for k in range(4):
		var a0 := rot + PI * 0.5 * float(k) + 0.30
		ic.draw_arc(c, r, a0, a0 + PI * 0.5 - 0.60, 18, red, 2.6, true)
	# Tırnaklar: halkadan İÇERİ uzanan 4 çizgi (boşlukların ortasından).
	for k in range(4):
		var a := rot + PI * 0.5 * float(k)
		var dirv := Vector2(cos(a), sin(a))
		ic.draw_line(c + dirv * (r + 3.0), c + dirv * (r - 7.0), red, 2.6)
	# İnce iç artı (merkeze değmez — hedef noktası nefes alsın).
	for k in range(4):
		var a := rot + PI * 0.5 * float(k)
		var dirv := Vector2(cos(a), sin(a))
		ic.draw_line(c + dirv * 9.0, c + dirv * 4.5, Color(red.r, red.g, red.b, 0.75), 1.6)
	# Merkez nokta + dışına çok ince soluk halka.
	ic.draw_circle(c, 2.2, Color(1.0, 0.42, 0.32))
	ic.draw_arc(c, 12.5, 0, TAU, 28, Color(red.r, red.g, red.b, 0.28), 1.2, true)


func _on_day_btn() -> void:
	# Onay/koruma akışı board'da (AĞIL seçimi ilk basışta açılır — yanlış basış emniyeti
	# de oradan gelir: gece ancak İKİNCİ basışta ya da kart seçilince çöker).
	day_end_requested.emit()


## Gece butonu: koyu antrasit (indigo alt-ton) daire; gri-siyah halka _draw'da.
func _style_night_button(btn: Button) -> void:
	var base := Color("14161d")
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = base if state == "normal" else (base.lightened(0.10) if state == "hover" else base.darkened(0.3))
		sb.set_corner_radius_all(46)  # tam daire
		sb.set_border_width_all(0)
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", Color("dce8ff"))
	btn.add_theme_color_override("font_hover_color", Color("ffffff"))


## Ayıkla butonu: koyu antrasit (kızıl alt-ton) daire — kızıl göz ikonu üstünde
## patlar; görünür gri-siyah halka _draw'daki _draw_button_frame'den gelir.
func _style_round_button(btn: Button) -> void:
	var base := Color("1a1013")
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = base if state == "normal" else (base.lightened(0.10) if state == "hover" else base.darkened(0.35))
		sb.set_corner_radius_all(58)  # yarıçap = boyut/2 -> tam daire
		sb.set_border_width_all(0)
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", Color("fff2dc"))
	btn.add_theme_color_override("font_hover_color", Color("fff2dc"))


func _panel_box(rect: Rect2, border: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.02, 0.03, 0.62)
	sb.set_corner_radius_all(12)
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 5
	draw_style_box(sb, rect)


func _add_label(pos: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _connect_events() -> void:
	EventBus.character_questioned.connect(func(_s): update_all())
	EventBus.question_bought.connect(func(_l, _c): update_all())
	EventBus.day_started.connect(func(_d): update_all())
	EventBus.night_kill.connect(func(_s): update_all())
	EventBus.card_executed.connect(_on_executed)
	EventBus.player_damaged.connect(_on_damaged)
	EventBus.mark_changed.connect(func(_s, _m): update_all())
	EventBus.village_won.connect(_on_won)
	EventBus.village_lost.connect(_on_lost)


func update_all() -> void:
	if GameState.village == null:
		return
	var v := GameState.village
	if v.night_rule == Enums.NightRule.FARTHEST:
		_quest_label.text = Loc.t("quest_foggy") \
				+ (Loc.t("quest_kills_suffix") % v.kills_per_night if v.kills_per_night >= 2 else "")
	elif v.kills_per_night >= 2:
		_quest_label.text = Loc.t("quest_multi") % v.kills_per_night
	else:
		_quest_label.text = Loc.t("quest_basic")
	_progress_label.text = Loc.t("hunted_progress") % [GameState.executed_evil(), GameState.total_evil()]
	# Gün + sorgu hakkı pip'leri (● dolu, ○ boş).
	var pips := ""
	for i in range(max(v.q_per_day, v.questions_left)):
		pips += "●" if i < v.questions_left else "○"
	_day_label.text = Loc.t("day_label") % [v.day, v.max_days, pips]
	# Kanıt: gece kurbanları (Av Düzeni bilinir → her ölüm kurt konumu kısıtıdır).
	var victims: Array = []
	for ev in v.night_events:
		victims.append("#%d" % int(ev["victim"]))
	_menu_strips[3]["visible"] = not victims.is_empty()
	if not victims.is_empty():
		_deaths_label.text = Loc.t("deaths_label") % ", ".join(victims)
	if RunManager.has_active_run():
		_village_label.text = Loc.t("village_label") % [RunManager.current_index + 1, RunManager.nodes.size()]
		_meta_label.text = Loc.t("meta_label") % [RunManager.ascension + 1, RunManager.coins]
		_menu_strips[5]["visible"] = true
	else:
		_village_label.text = Loc.t("flock_label") % v.n
		# Bağımsız modda ascension/para satırı gereksiz — gizle (istif kendini toplar).
		_menu_strips[5]["visible"] = false
	_score_label.text = Loc.t("score_label") % GameState.score
	# Sorgu satın alma yalnız seferde (para RunManager'da) ve köy aktifken.
	if _buyq_btn != null:
		_buyq_btn.visible = RunManager.has_active_run() and GameState.is_active()
		_buyq_btn.tooltip_text = Loc.t("buyq_tip") % GameState.question_price()
	# Köy modifier ilanı (varsa) — kural baştan ve her an görünür (adalet §7.3).
	var mods: Array = v.modifiers
	_mod_strip["visible"] = not mods.is_empty()
	if not mods.is_empty():
		var mod_lines: Array = []
		for m in mods:
			mod_lines.append(Loc.t("mod_%s" % m))
		_mod_label.text = "⚠ " + "  ·  ".join(mod_lines)
	_layout_menu()
	# Kompozisyon rozetleri _draw'da (sayılar oradan GameState.village'dan okunur).
	if not _hp_animating:
		_hp_display = float(GameState.health) / float(GameState.max_health())
	queue_redraw()


func set_execute_mode(on: bool) -> void:
	_exec_mode = on
	if _exec_icon != null:
		_exec_icon.queue_redraw()
	if on:
		flash_banner(Loc.t("hunt_mode_on"), Palette.BLOOD)
	else:
		flash_banner(Loc.t("hunt_mode_off"), Palette.SAFFRON)


## Panel çerçeveleri + can küresi (radyal gauge).
func _draw() -> void:
	var font := get_theme_default_font()

	# Sol menü banner'ları (kendi tasarım, altta çizilir; etiketler node = üstte).
	for s in _menu_strips:
		if s["visible"]:
			_draw_banner(s["off"], s["y"], s["w"], s["h"], false)

	# Kompozisyon — KOMPAKT banner (sağa bitişik) + yalnız küçük ikon+sayı (yazı yok).
	var cox := _comp_off

	if GameState.village != null and font != null:
		var v := GameState.village
		var vill := v.n - v.evil_count - v.outcast_count
		var cw := 292.0
		_draw_banner(size.x - cw + 6 + cox, 12, cw + 4, 70, true)  # kuyruk solda, sağa bitişik
		var chips := [
			["sheep", Palette.category_color(Enums.Category.VILLAGER), vill],
			["flame", Palette.category_color(Enums.Category.OUTCAST), v.outcast_count],
			["paw", Palette.BLOOD, v.minion_count],
			["skull", Palette.CRIMSON.darkened(0.1), v.demon_count],
		]
		# Kuyruktan sonra başla, sıkı aralık (yazı yok, çok ayrık durmasın).
		var cbase := size.x - cw + 62.0 + cox
		for i in range(chips.size()):
			var cx := cbase + i * 56.0
			_draw_comp_icon(chips[i][0], Vector2(cx, 34.0), chips[i][1])
			var num := str(chips[i][2])
			var ns := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
			var np := Vector2(cx - ns.x * 0.5, 62.0)
			draw_string_outline(font, np, num, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 3, Color("140a06"))
			draw_string(font, np, num, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("fff2dc"))

		# Gizli Kural (Omen) rozeti — kompozisyonun altında, kompakt banner.
		# VARLIĞI her zaman ilan edilir (adalet §7.3 — kompozisyon gibi); içeriği
		# ancak Müneccim/fal/tümdengelimle çözülünce görünür.
		if v.omen_type != Enums.OmenType.NONE:
			var known := v.known_omen != Enums.OmenType.NONE
			var l1 := ("◉ " + Omen.short_label(v.known_omen)) if known else Loc.t("omen_unknown")
			var l2 := Omen.hint(v.known_omen) if known else Loc.t("omen_unknown_hint")
			# Banner genişliği METNE göre: uzun ipuçları taşmasın (kullanıcı bug'ı).
			var w1 := font.get_string_size(l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			var w2 := font.get_string_size(l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			var ow := maxf(360.0, maxf(w1, w2) + 84.0)
			_draw_banner(size.x - ow + 6 + cox, 90, ow + 4, 52, true)
			if known:
				draw_string(font, Vector2(size.x - ow + 60 + cox, 112), l1,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.SAFFRON)
			else:
				# Çözülmemiş: soluk, nabız gibi hafif yanıp sönen "???".
				var oa := 0.55 + 0.25 * sin(_t * 2.2)
				draw_string(font, Vector2(size.x - ow + 60 + cox, 112), l1,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Palette.SAFFRON.r, Palette.SAFFRON.g, Palette.SAFFRON.b, oa))
			draw_string(font, Vector2(size.x - ow + 60 + cox, 132), l2,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.IVORY.darkened(0.05))

	# Sağ-alt yuvarlak butonların çerçeveleri: görünür GRİ-SİYAH halka + gölge
	# (dalgalı siyah diskler koyu zeminde kayboluyordu — kullanıcı geri bildirimi).
	var ring_gray := Color(0.29, 0.29, 0.32)  # siyaha yakın koyu gri (kullanıcı isteği)
	if _execute_btn != null:
		var bc := _execute_btn.position + _execute_btn.size * 0.5
		# Av modunda çerçeve kızıla döner (tehlikeli mod açık sinyali).
		_draw_button_frame(bc, 58.0, Palette.BLOOD.lightened(0.12) if _exec_mode else ring_gray, _execute_btn.is_hovered())
	if _day_btn != null:
		var dc := _day_btn.position + _day_btn.size * 0.5
		# Sorgu hakları bitti → sıradaki hamle gece: buton nabız gibi çağırır.
		if GameState.village != null and GameState.is_active() and GameState.village.questions_left <= 0:
			var na := 0.30 + 0.30 * sin(_t * 4.0)
			draw_arc(dc, 60.0 + 3.0 * sin(_t * 4.0), 0, TAU, 48, Color(0.62, 0.72, 1.0, na), 3.5)
		_draw_button_frame(dc, 46.0, ring_gray, _day_btn.is_hovered())
	if _log_btn != null:
		var lc := _log_btn.position + _log_btn.size * 0.5
		_draw_button_frame(lc, 31.0, ring_gray, _log_btn.is_hovered())
	if _info_btn != null:
		var ic := _info_btn.position + _info_btn.size * 0.5
		_draw_button_frame(ic, 31.0, ring_gray, _info_btn.is_hovered())
	if _buyq_btn != null and _buyq_btn.visible:
		var qc := _buyq_btn.position + _buyq_btn.size * 0.5
		_draw_button_frame(qc, 31.0, ring_gray, _buyq_btn.is_hovered())
		# Fiyat etiketi butonun altında (konturlu — tırmanan fiyat hep görünür).
		if font != null:
			var ptxt := "%d ₿" % GameState.question_price()
			var pts := font.get_string_size(ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
			var pp := Vector2(qc.x - pts.x * 0.5, _buyq_btn.position.y + _buyq_btn.size.y + 16.0)
			draw_string_outline(font, pp, ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.85))
			draw_string(font, pp, ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffd479"))

	var gc := Vector2(90.0 + _globe_off, size.y - 96.0) + _globe_shake
	# Düşük can uyarısı: küre çevresinde nabız gibi atan kızıl halkalar.
	if _hp_display <= 0.31 and GameState.village != null:
		var pa := 0.28 + 0.28 * sin(_t * 5.5)
		draw_arc(gc, GLOBE_R + 16.0, 0, TAU, 48, Color(0.9, 0.10, 0.05, pa), 4.0)
		draw_arc(gc, GLOBE_R + 24.0, 0, TAU, 48, Color(0.9, 0.10, 0.05, pa * 0.4), 2.5)
	draw_circle(gc, GLOBE_R + 12.0, Color(0, 0, 0, 0.5))  # yumuşak gölge
	# Merkez gözle aynı dalgalı siyah border (belirgin genlik + ikinci katman).
	_draw_wavy_disc(gc, GLOBE_R + 9.0, Color(0.03, 0.006, 0.012, 1.0), _t * 1.1, 8.0)
	_draw_wavy_disc(gc, GLOBE_R + 3.0, Color(0.05, 0.01, 0.02, 1.0), -_t * 0.8, 4.0)
	draw_circle(gc, GLOBE_R, Color("1a0c0a"))  # koyu taban
	# Kalan can dolgusu — cana göre parlaktan koyu kana kayar (yumuşak).
	var fill_col := Color("4a0a06").lerp(EYE_RED, clampf(_hp_display, 0.0, 1.0))
	draw_circle(gc, GLOBE_R * 0.82 * maxf(_hp_display, 0.06), fill_col)
	# İç kenar gölgesi (küreye derinlik).
	draw_arc(gc, GLOBE_R * 0.82, 0, TAU, 64, Color(0, 0, 0, 0.30), 3.0)
	# Radyal gauge: koyu ray + parlak ilerleme yayı (tepeden saat yönünde).
	draw_arc(gc, GLOBE_R - 3.0, 0, TAU, 72, Color(0, 0, 0, 0.5), 7.0)
	if _hp_display > 0.003:
		draw_arc(gc, GLOBE_R - 3.0, -PI * 0.5, -PI * 0.5 + TAU * _hp_display, 72, EYE_RED.lightened(0.2), 7.0)
	if font != null and GameState.village != null:
		var maxhp := GameState.max_health()
		# Segment tikleri: her can birimi için ince koyu çizgi (kadran hissi).
		for i in range(maxhp):
			var ta := -PI * 0.5 + TAU * float(i) / float(maxhp)
			var tv := Vector2(cos(ta), sin(ta))
			draw_line(gc + tv * (GLOBE_R - 7.5), gc + tv * (GLOBE_R + 1.5), Color(0.05, 0.02, 0.02, 0.85), 2.0)
		# Can sayısı (küre üstünde, konturlu).
		var txt := "%d/%d" % [GameState.health, maxhp]
		var fs := int(30.0 * _hp_num_scale)
		var tsize := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var tpos := gc + Vector2(-tsize.x * 0.5, tsize.y * 0.33)
		draw_string_outline(font, tpos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color("1a0606"))
		draw_string(font, tpos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fff2dc"))
		# Segmentli can barı (kürenin altında): her birim ince bir çubuk.
		var seg_w := 7.0
		var seg_gap := 3.0
		var bw := maxhp * seg_w + (maxhp - 1) * seg_gap
		var bx := gc.x - bw * 0.5
		var by := gc.y + GLOBE_R + 13.0
		for i in range(maxhp):
			var filled := i < GameState.health
			var r := Rect2(Vector2(bx + i * (seg_w + seg_gap), by), Vector2(seg_w, 7.0))
			draw_rect(r.grow(1.0), Color(0, 0, 0, 0.75), true)
			draw_rect(r, EYE_RED.lightened(0.08) if filled else Color("2a1414"), true)


## Kompozisyon rozeti: prosedürel ikon + altında sayı + kategori adı (referans stili).
func _comp_chip(font: Font, center: Vector2, kind: String, col: Color, count: int, label: String) -> void:
	_draw_comp_icon(kind, center, col)
	var num := str(count)
	var ns := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 19)
	var np := center + Vector2(-ns.x * 0.5, 30.0)
	draw_string_outline(font, np, num, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, 3, Color("140a06"))
	draw_string(font, np, num, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("fff2dc"))
	var ls := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(font, center + Vector2(-ls.x * 0.5, 46.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.IVORY.darkened(0.15))


## Küçük prosedürel kategori ikonları (~20px). Özgün; telifli ikon kopyalanmaz.
func _draw_comp_icon(kind: String, c: Vector2, col: Color) -> void:
	match kind:
		"sheep":  # koyun: beyaz yün öbeği + koyu baş
			var wool := Color("efe7d6")
			draw_circle(c + Vector2(-7, 0), 7.0, wool)
			draw_circle(c + Vector2(7, 0), 7.0, wool)
			draw_circle(c + Vector2(0, -5), 8.0, wool)
			draw_circle(c + Vector2(0, 4), 6.5, wool)
			draw_circle(c + Vector2(0, 7), 4.5, Color("30271f"))
		"flame":  # parya: amber alev
			var f := col.lightened(0.05)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -11), c + Vector2(-7, 3), c + Vector2(7, 3)]), f)
			draw_circle(c + Vector2(0, 4), 6.0, f)
			draw_circle(c + Vector2(0, 3), 3.0, Color("fff0c8"))
		"paw":  # kurt: pati izi
			var p := col.lightened(0.12)
			draw_circle(c + Vector2(0, 5), 7.5, p)
			for toe in [Vector2(-8, -3), Vector2(-3, -9), Vector2(3, -9), Vector2(8, -3)]:
				draw_circle(c + toe, 3.6, p)
		"skull":  # alfa: kafatası (kemik + kızıl göz çukuru)
			var bone := Color("e8dcc4")
			draw_circle(c + Vector2(0, -2), 9.0, bone)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-5, 4), c + Vector2(5, 4), c + Vector2(3.5, 11), c + Vector2(-3.5, 11)]), bone)
			draw_circle(c + Vector2(-3.6, -2), 2.6, Color("6a0e0e"))
			draw_circle(c + Vector2(3.6, -2), 2.6, Color("6a0e0e"))
		_:
			draw_circle(c, 9.0, col)


func _on_damaged(_amount: int, hp: int) -> void:
	_hp_animating = true
	var target := float(hp) / float(GameState.max_health())
	var t := create_tween()
	t.tween_method(_set_hp, _hp_display, target, 0.5).set_trans(Tween.TRANS_QUAD)
	t.finished.connect(func(): _hp_animating = false)

	# Küre sarsıntısı.
	var s := create_tween()
	s.tween_method(func(v: Vector2): _globe_shake = v; queue_redraw(),
		Vector2(14, 0), Vector2.ZERO, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Ekran kızıl flaş.
	_dmg_flash.color.a = 0.0
	var f := create_tween()
	f.tween_property(_dmg_flash, "color:a", 0.42, 0.06)
	f.tween_property(_dmg_flash, "color:a", 0.0, 0.45)

	# Sayı pop.
	var p := create_tween()
	p.tween_method(func(v: float): _hp_num_scale = v; queue_redraw(), 1.5, 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	update_all()


func _set_hp(v: float) -> void:
	_hp_display = v
	queue_redraw()


func _on_executed(_seat: int, was_evil: bool) -> void:
	# Kurt avında banner YOK — sinematik (yırtılma + replik) anlatıyor; banner
	# aynı anda binince ekran karmaşıklaşıyordu. İlerleme etiketi zaten güncellenir.
	if not was_evil:
		flash_banner(Loc.t("wrong_cull"), Palette.BLOOD)
	update_all()


func flash_banner(text: String, color: Color) -> void:
	if _banner != null:
		_banner.show_message(text, color)


## Board'un sahiplendiği duyuru şeridini bağla (gece HUD kaybolsa da şerit kalır).
func attach_banner(b: RibbonBanner) -> void:
	_banner = b


## Gece çökerken HUD tamamen çekilir — paneller, rozetler, butonlar gider;
## sahnede yalnız gökyüzü, kartlar ve duyuru şeridi kalır (tam daldırma).
func set_night_dim(a: float) -> void:
	modulate.a = 1.0 - a
	visible = a < 0.98


func _on_won(score: int) -> void:
	# Sefer modunda overlay YOK: board sinematik bitiminde haritaya/sonuca geçiyor;
	# overlay o geçişin üstüne binip kart/yazı karmaşası yaratıyordu (kullanıcı
	# geri bildirimi). Yalnız bağımsız modda ve sinematik TAMAMEN bitince göster.
	if RunManager.has_active_run():
		return
	await get_tree().create_timer(3.2).timeout
	if not is_inside_tree():
		return
	_overlay.visible = true
	_overlay_label.text = Loc.t("overlay_won") % score
	_overlay_label.add_theme_color_override("font_color", Palette.SAFFRON)


func _on_lost(reason: String) -> void:
	# Sefer modunda overlay YOK (board sonuç ekranına geçer); bağımsız modda
	# kaybediş sinematiği (~3.2 sn) bittikten sonra göster.
	if RunManager.has_active_run():
		return
	await get_tree().create_timer(3.4).timeout
	if not is_inside_tree():
		return
	_overlay.visible = true
	_overlay_label.text = Loc.t("overlay_lost") % reason
	_overlay_label.add_theme_color_override("font_color", Palette.BLOOD)


func hide_overlay() -> void:
	_overlay.visible = false
