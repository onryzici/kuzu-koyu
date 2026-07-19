class_name Hud
extends Control

## Köy tahtası HUD'u. Bkz. CLAUDE.md §11. Değerleri GameState'ten okur,
## EventBus sinyalleriyle güncellenir. İş mantığı yok.

signal execute_toggled
signal day_end_requested
signal restart_requested

var _quest_label: Label
var _progress_label: Label
var _day_label: Label          ## "Gün 2/5 · Sorgu ●●○"
var _deaths_label: Label       ## "☠ Kurbanlar: #2, #5" — nirengi kanıtı
var _meta_label: Label
var _village_label: Label
var _score_label: Label
var _day_btn: Button           ## Günü Bitir (gece) butonu
var _banner_label: Label
var _menu_strips: Array = []   ## sol menü banner'ları (kendi tasarım; intro'da kayar)
var _comp_off := 0.0           ## kompozisyon paneli sağdan giriş kayması
var _legend_off := 0.0         ## mark lejantı + ayıkla butonu sağdan giriş
var _globe_off := 0.0          ## can küresi soldan giriş
var _execute_btn: Button
var _legend_label: Label
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

	# Banner (alt-orta; üst-orta kart #0'ın altında kalmasın diye)
	_banner_label = _add_label(Vector2.ZERO, 22, Palette.SAFFRON)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_banner_label.offset_top = -54
	_banner_label.offset_bottom = -18

	# Arındır butonu — yuvarlak ritüel-hançer butonu (sağ-alt köşe, mutlak konum).
	_execute_btn = Button.new()
	_execute_btn.text = "Ayıkla"
	_execute_btn.add_theme_font_size_override("font_size", 19)
	_execute_btn.position = Vector2(1466, 752)
	_execute_btn.size = Vector2(116, 116)
	_execute_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_round_button(_execute_btn)
	_execute_btn.pressed.connect(func(): execute_toggled.emit())
	add_child(_execute_btn)

	# Günü Bitir (gece) butonu — Ayıkla'nın üstünde, gece indigo yuvarlak.
	# Emniyet: sorgu hakkı dururken ilk basış UYARIR, 2.5 sn içinde ikinci basış onaylar.
	_day_btn = Button.new()
	_day_btn.text = "🌙 Gece"
	_day_btn.add_theme_font_size_override("font_size", 15)
	_day_btn.position = Vector2(1478, 618)
	_day_btn.size = Vector2(92, 92)
	_day_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_night_button(_day_btn)
	_day_btn.pressed.connect(_on_day_btn)
	add_child(_day_btn)

	# Mark lejantı — yuvarlak butonun soluna. Mutlak konum (base 1600x900).
	_legend_label = _add_label(Vector2(1128, 760), 14, Palette.IVORY)
	_legend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_legend_label.size = Vector2(316, 100)
	_legend_label.add_theme_constant_override("line_spacing", 4)
	# Karta gel, tuşa bas (ya da sağ tık: döngü). Renk-körü için şekil de var.
	_legend_label.text = "İşaret — karta gel, tuşa bas:\n1 ▲ İyi   2 ◆ Şüpheli   3 ✖ Kurt\n4 ! Soru   5 Sil   (sağ tık: döngü)"

	# Hasar flaşı (tam ekran kızıl, başta görünmez)
	_dmg_flash = ColorRect.new()
	_dmg_flash.color = Color(0.7, 0.0, 0.0, 0.0)
	_dmg_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dmg_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dmg_flash)

	# Sonuç overlay'i (başta gizli)
	_overlay = ColorRect.new()
	_overlay.color = Color(0.05, 0.04, 0.06, 0.82)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	_overlay_label = Label.new()
	_overlay_label.add_theme_font_size_override("font_size", 40)
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_label.offset_top = -60
	_overlay.add_child(_overlay_label)

	_restart_btn = Button.new()
	_restart_btn.text = "Yeni Köy (R)"
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

	# Mark lejantı + ayıkla/gece butonları — sağdan (drawn kutu + node'lar aynı offset ile).
	var lx0 := _legend_label.position.x
	var ex0 := _execute_btn.position.x
	var dx0 := _day_btn.position.x
	_legend_off = 560.0
	_legend_label.position.x = lx0 + 560.0
	_execute_btn.position.x = ex0 + 560.0
	_day_btn.position.x = dx0 + 560.0
	var lt := create_tween()
	lt.tween_interval(0.22)
	lt.tween_method(func(v: float):
		_legend_off = v
		_legend_label.position.x = lx0 + v
		_execute_btn.position.x = ex0 + v
		_day_btn.position.x = dx0 + v
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


func _on_day_btn() -> void:
	# Onay/koruma akışı board'da (AĞIL seçimi ilk basışta açılır — yanlış basış emniyeti
	# de oradan gelir: gece ancak İKİNCİ basışta ya da kart seçilince çöker).
	day_end_requested.emit()


## Gece butonu: koyu indigo yuvarlak (dalgalı siyah border _draw'da).
func _style_night_button(btn: Button) -> void:
	var base := Color("223055")
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = base if state == "normal" else (base.lightened(0.14) if state == "hover" else base.darkened(0.25))
		sb.set_corner_radius_all(46)  # tam daire
		sb.set_border_width_all(0)
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", Color("dce8ff"))
	btn.add_theme_color_override("font_hover_color", Color("ffffff"))


## Yuvarlak "ritüel" butonu: göz kırmızısı daire; safran border YOK (dalgalanan
## siyah border _draw'da butonun arkasına çizilir).
func _style_round_button(btn: Button) -> void:
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = EYE_RED.darkened(0.28) if state == "normal" else (EYE_RED.lightened(0.06) if state == "hover" else EYE_RED.darkened(0.5))
		sb.set_corner_radius_all(58)  # yarıçap = boyut/2 -> tam daire
		sb.set_border_width_all(0)     # sarı border kaldırıldı
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
	if v.kills_per_night >= 2:
		_quest_label.text = "Kurtları bul! Sürü gecede %d kurban veriyor" % v.kills_per_night
	else:
		_quest_label.text = "Kurtları bul — her gece bir koyun can veriyor"
	_progress_label.text = "Ayıklanan: %d / %d Kurt" % [GameState.executed_evil(), GameState.total_evil()]
	# Gün + sorgu hakkı pip'leri (● dolu, ○ boş).
	var pips := ""
	for i in range(max(v.q_per_day, v.questions_left)):
		pips += "●" if i < v.questions_left else "○"
	_day_label.text = "Gün %d/%d   ·   Sorgu: %s" % [v.day, v.max_days, pips]
	# Kanıt: gece kurbanları (Av Düzeni bilinir → her ölüm kurt konumu kısıtıdır).
	var victims: Array = []
	for ev in v.night_events:
		victims.append("#%d" % int(ev["victim"]))
	_menu_strips[3]["visible"] = not victims.is_empty()
	if not victims.is_empty():
		_deaths_label.text = "☠ Kurbanlar: %s  (kurda en yakındılar)" % ", ".join(victims)
	if RunManager.has_active_run():
		_village_label.text = "Köy: %d / %d" % [RunManager.current_index + 1, RunManager.nodes.size()]
		_meta_label.text = "Ascension: %d   ·   Para: %d" % [RunManager.ascension + 1, RunManager.coins]
		_menu_strips[5]["visible"] = true
	else:
		_village_label.text = "Sürü: %d hayvan" % v.n
		# Bağımsız modda ascension/para satırı gereksiz — gizle (istif kendini toplar).
		_menu_strips[5]["visible"] = false
	_score_label.text = "Skor: %d" % GameState.score
	_layout_menu()
	# Kompozisyon rozetleri _draw'da (sayılar oradan GameState.village'dan okunur).
	if not _hp_animating:
		_hp_display = float(GameState.health) / float(GameState.max_health())
	queue_redraw()


func set_execute_mode(on: bool) -> void:
	if on:
		_execute_btn.text = "İptal"
		_banner_label.text = "AYIKLAMA MODU — bir kart seç (yanlışsa -5 can)"
		_banner_label.add_theme_color_override("font_color", Palette.BLOOD)
	else:
		_execute_btn.text = "Ayıkla"
		_banner_label.text = "Sorgula (sol tık) · işaretle (sağ tık) · G: günü bitir"
		_banner_label.add_theme_color_override("font_color", Palette.SAFFRON)


## Panel çerçeveleri + can küresi (radyal gauge).
func _draw() -> void:
	var font := get_theme_default_font()

	# Sol menü banner'ları (kendi tasarım, altta çizilir; etiketler node = üstte).
	for s in _menu_strips:
		if s["visible"]:
			_draw_banner(s["off"], s["y"], s["w"], s["h"], false)

	# Kompozisyon — KOMPAKT banner (sağa bitişik) + yalnız küçük ikon+sayı (yazı yok).
	var cox := _comp_off
	# Mark lejantı — 4 köşesi pahlı, yüzen siyah panel (sağdan kayar).
	_draw_panel_beveled(size.x - 486 + _legend_off, size.y - 150, 340, 116)

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

		# Gizli Kural (Omen) rozeti — kompozisyonun altında, kompakt banner (bilinirse).
		if v.known_omen != Enums.OmenType.NONE:
			var ow := 360.0
			_draw_banner(size.x - ow + 6 + cox, 90, ow + 4, 52, true)
			draw_string(font, Vector2(size.x - ow + 60 + cox, 112), "◉ " + Omen.short_label(v.known_omen),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.SAFFRON)
			draw_string(font, Vector2(size.x - ow + 60 + cox, 132), Omen.hint(v.known_omen),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.IVORY.darkened(0.05))

	# Ayıkla butonunun arkasına dalgalanan siyah border (butonun altında çizilir).
	if _execute_btn != null:
		var bc := _execute_btn.position + _execute_btn.size * 0.5
		draw_circle(bc, 68.0, Color(0, 0, 0, 0.45))  # yumuşak gölge
		# Merkez gözle aynı dalgalı siyah border (belirgin genlik + ikinci katman).
		_draw_wavy_disc(bc, 65.0, Color(0.03, 0.006, 0.012, 1.0), _t * 1.1 + 2.0, 7.5)
		_draw_wavy_disc(bc, 60.0, Color(0.05, 0.01, 0.02, 1.0), -_t * 0.8 + 2.0, 4.0)
	if _day_btn != null:
		var dc := _day_btn.position + _day_btn.size * 0.5
		# Sorgu hakları bitti → sıradaki hamle gece: buton nabız gibi çağırır.
		if GameState.village != null and GameState.is_active() and GameState.village.questions_left <= 0:
			var na := 0.30 + 0.30 * sin(_t * 4.0)
			draw_arc(dc, 58.0 + 3.0 * sin(_t * 4.0), 0, TAU, 48, Color(0.62, 0.72, 1.0, na), 3.5)
		draw_circle(dc, 55.0, Color(0, 0, 0, 0.45))
		_draw_wavy_disc(dc, 52.0, Color(0.03, 0.006, 0.012, 1.0), _t * 1.1 + 4.0, 6.0)
		_draw_wavy_disc(dc, 48.0, Color(0.05, 0.01, 0.02, 1.0), -_t * 0.8 + 4.0, 3.5)

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
	# Kalan can dolgusu — göz kırmızısı.
	var fill_col := EYE_RED if _hp_display > 0.33 else EYE_RED.lerp(Color("4a0a06"), 0.5)
	draw_circle(gc, GLOBE_R * 0.82 * maxf(_hp_display, 0.06), fill_col)
	# Radyal gauge halkası (tepeden saat yönünde) — göz kırmızısı.
	draw_arc(gc, GLOBE_R - 3.0, -PI * 0.5, -PI * 0.5 + TAU * _hp_display, 72, EYE_RED.lightened(0.2), 7.0)
	draw_arc(gc, GLOBE_R - 3.0, -PI * 0.5 + TAU * _hp_display, PI * 1.5, 72, Color(0, 0, 0, 0.4), 7.0)
	# Can sayısı (küre üstünde, konturlu).
	if font != null and GameState.village != null:
		var txt := "%d/%d" % [GameState.health, GameState.max_health()]
		var fs := int(30.0 * _hp_num_scale)
		var tsize := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var tpos := gc + Vector2(-tsize.x * 0.5, tsize.y * 0.33)
		draw_string_outline(font, tpos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color("1a0606"))
		draw_string(font, tpos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fff2dc"))
		# Kalp pip'leri (her kalp = 2 can), kürenin altında.
		var hearts := int(ceil(GameState.max_health() / 2.0))  # her kalp = 2 can (Bereket'te 6 kalp)
		var filled := int(round(GameState.health / 2.0))
		var hy := gc.y + GLOBE_R + 16.0
		var hx0 := gc.x - (hearts - 1) * 11.0
		for i in range(hearts):
			var hc := i < filled
			_draw_heart(Vector2(hx0 + i * 22.0, hy), 8.0,
				Palette.BLOOD if hc else Color("2a1414"))


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


## Basit kalp: iki daire + üçgen.
func _draw_heart(c: Vector2, s: float, col: Color) -> void:
	draw_circle(c + Vector2(-s * 0.45, -s * 0.15), s * 0.5, col)
	draw_circle(c + Vector2(s * 0.45, -s * 0.15), s * 0.5, col)
	var pts := PackedVector2Array([
		c + Vector2(-s * 0.92, 0.0),
		c + Vector2(s * 0.92, 0.0),
		c + Vector2(0.0, s * 0.95),
	])
	draw_colored_polygon(pts, col)


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
	if was_evil:
		flash_banner("✔ Kurt ayıklandı!", Palette.SAFFRON)
	else:
		flash_banner("✘ Ouch! Masum bir koyundu. -5 can", Palette.BLOOD)
	update_all()


func flash_banner(text: String, color: Color) -> void:
	_banner_label.text = text
	_banner_label.add_theme_color_override("font_color", color)


func _on_won(score: int) -> void:
	# Önce son kurtun açılışı + zoom + bölünme sinematiği görünsün, SONRA overlay.
	await get_tree().create_timer(2.5).timeout
	_overlay.visible = true
	_overlay_label.text = "SÜRÜ KURTARILDI\nSkor: %d" % score
	_overlay_label.add_theme_color_override("font_color", Palette.SAFFRON)


func _on_lost(reason: String) -> void:
	_overlay.visible = true
	_overlay_label.text = "SÜRÜ KURTLARA YEM OLDU\n(%s)" % reason
	_overlay_label.add_theme_color_override("font_color", Palette.BLOOD)


func hide_overlay() -> void:
	_overlay.visible = false
