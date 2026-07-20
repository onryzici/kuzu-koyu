class_name TutorialGuide
extends Control

## TUTORIAL REHBERİ (§12 katmanlı öğretim): seferin ilk köyünde, oyun olaylarına
## bağlı adım adım yönlendirme. Oyunu DURDURMAZ — alt-orta rehber kartı + hedefe
## nabızlı ok. Bir kez tamamlanınca settings["tutorial_done"] ile sonsuza dek kapanır.
## Yalnız görsel/metin; kural motoruna dokunmaz.

signal finished

## Adımlar: metin + ok hedefi. İlerleme _advance() içindeki olay eşlemesiyle.
const STEPS := [
	{
		"text": "Sürüne hoş geldin çoban. Bu koyunlardan biri POSTA BÜRÜNMÜŞ KURT.\nBir karaktere tıklayıp SORGULA — herkes bir ifade verir.",
		"target": "cards",
	},
	{
		"text": "İşte bir ifade. İYİLER daima doğru söyler; KURT ise HER ifadesinde YALAN söyler.\nAynı karakteri tekrar sorgulayabilirsin — kurt konuştukça kendini ele verir.",
		"target": "cards",
	},
	{
		"text": "İpuçlarını kaybetme: TAB ile İFADE DEFTERİ'ni aç, sağ tıkla kartlara işaret koy.\nSorgu hakkın bitince GECE butonuyla günü kapat — ama bil: gece kurt avlanır.",
		"target": "day",
	},
	{
		"text": "Kurt, kendisine ÇEMBERDE EN YAKIN koyunu yedi. Ceset asla yalan söylemez:\nölüm yerinden kurdun nerede OLAMAYACAĞINI çıkar. GECE'ye basmadan önce\nbutonun üstünde bekleyerek olası kurbanları görebilirsin.",
		"target": "log",
	},
	{
		"text": "Kurdu bulduğuna inanıyorsan AVLA (E) butonuna bas, sonra kartı seç.\nDikkat: yanlış av sürüne −5 CAN. Emin ol, sonra vur.",
		"target": "exec",
	},
	{
		"text": "Kurdu buldun! Tüm kurtlar avlanınca köy kurtulur.\nBundan sonrası sende çoban — sürünü koru.",
		"target": "",
	},
]

# Ok hedef noktaları (HUD mutlak yerleşimiyle aynı taban: 1600x900).
const TARGETS := {
	"day": Vector2(1524.0, 664.0),
	"exec": Vector2(1524.0, 810.0),
	"log": Vector2(1423.0, 665.0),
}

var _step := -1
var _t := 0.0
var _panel: PanelContainer
var _label: Label
var _timer := 0.0          ## bazı adımlar süreyle de ilerler (takılıp kalma olmasın)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 240  # gece katmanı (200) üstü, sinematik karartma (250) altı

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0e080ef2")
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(0)
	sb.set_content_margin_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 4)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -350
	_panel.offset_right = 350
	_panel.offset_top = -170
	_panel.offset_bottom = -34
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_panel.add_child(vb)

	var head := HBoxContainer.new()
	vb.add_child(head)
	var title := Label.new()
	title.text = "ÇOBAN REHBERİ"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Palette.SAFFRON)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var skip := Button.new()
	skip.text = "Rehberi Geç"
	skip.flat = true
	skip.add_theme_font_size_override("font_size", 13)
	skip.add_theme_color_override("font_color", Palette.IVORY.darkened(0.3))
	skip.pressed.connect(_finish)
	head.add_child(skip)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(660, 0)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Palette.IVORY)
	vb.add_child(_label)

	# Olay güdümlü ilerleme.
	EventBus.character_questioned.connect(_on_questioned)
	EventBus.night_passed.connect(_on_night)
	EventBus.card_executed.connect(_on_executed)
	EventBus.village_won.connect(func(_s): _finish())
	EventBus.village_lost.connect(func(_r): _finish())


func start() -> void:
	_goto(0)


func _goto(i: int) -> void:
	if i >= STEPS.size():
		_finish()
		return
	_step = i
	_timer = 0.0
	_label.text = STEPS[i]["text"]
	# Panel yumuşak giriş: aşağıdan süzül.
	_panel.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_panel, "modulate:a", 1.0, 0.3)
	queue_redraw()


func _on_questioned(_seat: int) -> void:
	if _step == 0:
		_goto(1)
	elif _step == 1:
		_goto(2)


func _on_night(_victims: Array) -> void:
	if _step <= 2:
		_goto(3)


func _on_executed(_seat: int, was_evil: bool) -> void:
	if was_evil:
		_goto(5)
	elif _step <= 4:
		# Yanlış ayıklama — uyarıyı tazele (adım değişmez).
		_label.text = "Bu bir koyundu — sürü −5 can kaybetti! İfadeleri DEFTERden tekrar tara;\nkurt, ifadesi yalanlarla çelişendir. Acele etme."


func _process(delta: float) -> void:
	_t += delta
	_timer += delta
	# Ceset dersi (adım 3) 12 sn sonra kendiliğinden av dersine geçer.
	if _step == 3 and _timer > 12.0:
		_goto(4)
	# Son adım 6 sn görünüp kapanır.
	if _step == STEPS.size() - 1 and _timer > 6.0:
		_finish()
	queue_redraw()


func _finish() -> void:
	if _step >= STEPS.size() - 1 or _step < 0:
		pass
	finished.emit()
	queue_free()


func _draw() -> void:
	if _step < 0 or _step >= STEPS.size():
		return
	var target: String = STEPS[_step]["target"]
	if target == "":
		return
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	if target == "cards":
		# Kart çemberini gösteren, merkezin üstünde süzülen aşağı-ok.
		var p := Vector2(size.x * 0.5, size.y * 0.20 - 8.0 * pulse)
		_draw_arrow(p, Vector2(0, 1), pulse)
		return
	var tp: Vector2 = TARGETS.get(target, Vector2.ZERO)
	# Buton hedefleri: butonun solunda, ona doğru bakan sağ-ok.
	var p2 := tp + Vector2(-86.0 - 8.0 * pulse, 0.0)
	_draw_arrow(p2, Vector2(1, 0), pulse)


## Nabızlı yönlendirme oku: safran, konturlu üçgen + kısa sap.
func _draw_arrow(p: Vector2, dir: Vector2, pulse: float) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var col := Color(Palette.SAFFRON.r, Palette.SAFFRON.g, Palette.SAFFRON.b, 0.75 + 0.25 * pulse)
	var tip := p + dir * 22.0
	draw_line(p - dir * 16.0, p, Color(0, 0, 0, 0.6), 9.0)
	draw_line(p - dir * 16.0, p, col, 5.0)
	draw_colored_polygon(PackedVector2Array([
		tip, p + perp * 13.0, p - perp * 13.0,
	]), col)
