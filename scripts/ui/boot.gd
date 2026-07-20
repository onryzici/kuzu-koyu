extends Control

## AÇILIŞ SEKANSI (profesyonel boot akışı):
##   siyah → SAĞLIK & KAYIT UYARISI → CODEZU logosu (nazar boncuklu "O") → ana menü.
## Her ekran, minimum süre dolduktan sonra herhangi bir tuş/tıkla geçilebilir.
## Yalnız görsel; oyun durumuna dokunmaz. Ana sahne budur (project.godot).

const NEXT_SCENE := "res://scenes/run_map.tscn"

## Faz zamanlaması: [fade_in, bekleme, fade_out] (saniye).
const PHASES := [
	{"id": "warning", "in": 0.6, "hold": 5.0, "out": 0.5, "min_skip": 1.2},
	{"id": "logo", "in": 0.9, "hold": 2.6, "out": 0.7, "min_skip": 0.8},
]

var _phase := 0
var _pt := 0.0            ## faz-içi zaman
var _done := false
var _warning_box: VBoxContainer
var _logo: Control
var _logo_t := 0.0        ## logo animasyon saati (parıltı/blink)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Saf siyah zemin — açılışta hiçbir şey sızmasın.
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_warning()
	_build_logo()
	_warning_box.modulate.a = 0.0
	_logo.modulate.a = 0.0


func _build_warning() -> void:
	_warning_box = VBoxContainer.new()
	_warning_box.add_theme_constant_override("separation", 22)
	_warning_box.anchor_left = 0.5
	_warning_box.anchor_right = 0.5
	_warning_box.anchor_top = 0.5
	_warning_box.anchor_bottom = 0.5
	_warning_box.offset_left = -430
	_warning_box.offset_right = 430
	_warning_box.offset_top = -190
	add_child(_warning_box)

	var head := Label.new()
	head.text = "SAĞLIK UYARISI"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 26)
	head.add_theme_color_override("font_color", Color("d8cfc2"))
	_warning_box.add_child(head)

	var body := Label.new()
	body.text = "Bu oyun yanıp sönen görüntüler ve ani ışık değişimleri içerebilir.\nNadir de olsa bu görüntüler, ışığa duyarlı kişilerde epilepsi nöbetlerini tetikleyebilir.\nBaş dönmesi, görme bozukluğu ya da rahatsızlık hissederseniz oyunu hemen bırakın\nve bir hekime danışın."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 17)
	body.add_theme_color_override("font_color", Color("9a938b"))
	_warning_box.add_child(body)

	var save_note := Label.new()
	save_note.text = "Bu oyun ilerlemenizi otomatik olarak kaydeder.\nKayıt sırasında uygulamayı kapatmayın."
	save_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_note.add_theme_font_size_override("font_size", 15)
	save_note.add_theme_color_override("font_color", Color("6f6a64"))
	_warning_box.add_child(save_note)

	var skip := Label.new()
	skip.text = "devam etmek için bir tuşa basın"
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip.add_theme_font_size_override("font_size", 13)
	skip.add_theme_color_override("font_color", Color("4a4642"))
	_warning_box.add_child(skip)


func _build_logo() -> void:
	_logo = Control.new()
	_logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_logo.draw.connect(_draw_logo)
	add_child(_logo)


func _process(delta: float) -> void:
	if _done:
		return
	_pt += delta
	_logo_t += delta
	var ph: Dictionary = PHASES[_phase]
	var total: float = ph["in"] + ph["hold"] + ph["out"]
	# Faz alfası: gir → bekle → çık.
	var a: float
	if _pt < ph["in"]:
		a = _pt / ph["in"]
	elif _pt < ph["in"] + ph["hold"]:
		a = 1.0
	else:
		a = maxf(0.0, 1.0 - (_pt - ph["in"] - ph["hold"]) / ph["out"])
	if ph["id"] == "warning":
		_warning_box.modulate.a = a
	else:
		_logo.modulate.a = a
		_logo.queue_redraw()
	if _pt >= total:
		_advance()


func _advance() -> void:
	_phase += 1
	_pt = 0.0
	if _phase >= PHASES.size():
		_done = true
		Fader.change_scene(NEXT_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	var ph: Dictionary = PHASES[_phase]
	# Minimum görünme süresi dolduysa fade-out'a atla (uyarı yutulmasın).
	if _pt >= float(ph["min_skip"]) and _pt < ph["in"] + ph["hold"]:
		_pt = ph["in"] + ph["hold"]


## Stüdyo kartı: SADE — logo icat etmiyoruz. Hazır logo dosyası varsa
## (assets/art/ui/codezu_logo.png) onu ortalar; yoksa yalın, geniş harf aralıklı
## "CODEZU" yazısı. Altta yalnız telif satırı.
const LOGO_PATH := "res://assets/art/ui/codezu_logo.png"

func _draw_logo() -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var c := size * 0.5

	var tex: Texture2D = load(LOGO_PATH) if ResourceLoader.exists(LOGO_PATH) else null
	if tex != null:
		# Hazır logo: en fazla 420 px genişlikte, ortalanmış.
		var ts := Vector2(tex.get_width(), tex.get_height())
		var sc := minf(1.0, 420.0 / ts.x)
		var ds := ts * sc
		_logo.draw_texture_rect(tex, Rect2(c - ds * 0.5, ds), false)
	else:
		# Yalın wordmark: geniş harf aralıklı düz beyaz-kırık yazı, süs yok.
		var fs := 64
		var tracking := 14.0
		var text := "CODEZU"
		var total := 0.0
		for ch in text:
			total += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + tracking
		total -= tracking
		var x := c.x - total * 0.5
		var base_y := c.y + fs * 0.34
		for ch in text:
			_logo.draw_string(font, Vector2(x, base_y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("e8e2d6"))
			x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + tracking

	var foot := "© 2026 Codezu · Tüm hakları saklıdır"
	var fw := font.get_string_size(foot, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	_logo.draw_string(font, Vector2(c.x - fw * 0.5, size.y - 42.0), foot,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("55504a"))
