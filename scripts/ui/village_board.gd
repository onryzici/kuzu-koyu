extends Control

## Ana köy tahtası controller'ı. Bkz. CLAUDE.md §11, §13.2.
## Kartları çember üzerinde dizer; reveal/execute/mark girişini GameState'e yönlendirir.
## Görselleştirme + giriş; kural mantığı GameState/engine'de.

const CardScene := preload("res://scenes/card.tscn")
const HudScene := preload("res://scenes/hud.tscn")
const BG_TEXTURE := preload("res://assets/art/bg/ritual_ground.png")

const VILLAGE_CONFIG := {"n": 7, "evil_count": 2, "demon_count": 1, "anchor_count": 1}

const MARK_CYCLE := [
	Enums.MarkType.NONE,
	Enums.MarkType.MARK_GOOD,
	Enums.MarkType.MARK_SUSPECT,
	Enums.MarkType.MARK_EVIL,
	Enums.MarkType.MARK_QUESTION,
]

var _cards: Array[CardView] = []
var _hud: Hud
var _tooltip: AbilityTooltip
var _cine_dim: ColorRect      ## ayıklama sinematiğinde arka karartma
var _night_layer: Control     ## gece göğü (indigo + hilal + yıldızlar)
var _night_alpha := 0.0       ## gece katmanı görünürlüğü (0..1)
var _burst: Array = []        ## kazanma yıldız patlaması parçacıkları
var _cinematic := false       ## sinematik oynarken girişi kilitle
var _execute_mode := false
var _hovered_seat := -1
var _night_count := 0          ## geçen gece sayısı (arka plan kızıla kayar — tehdit)
var _slayer_seat := -1         ## Kılıççı hedefleme modu (aktif yetenek)
var _protect_mode := false     ## AĞIL: gece öncesi koruma seçim modu

# --- Atmosfer (yalnız görsel; oyun mantığına dokunmaz) ---
# Süzülen kıvılcım/toz + merkezde nefes alan ritüel parıltısı + mum titremesi.
# Kozmetik olduğu için ayrı, lokal bir RNG kullanır — gameplay Rng stream'ini
# bozmaz (§13.6 determinizmi etkilenmez).
const SPARK_COUNT := 54
var _time := 0.0
var _sparks: Array = []           ## her biri: {x, y, vy, drift, size, phase, spd, warm}
var _fx_rng := RandomNumberGenerator.new()
var _eye_look := Vector2.ZERO     ## gözün YUMUŞATILMIŞ bakış yönü (her kare lerp)
var _slots: Array = []            ## seat başına Rect2 — kesikli boş kart yeri

# 1–5 tuşları -> mark (Demon Bluff'taki gibi). 5 = temizle.
const MARK_KEYS := {
	KEY_1: Enums.MarkType.MARK_GOOD,
	KEY_2: Enums.MarkType.MARK_SUSPECT,
	KEY_3: Enums.MarkType.MARK_EVIL,
	KEY_4: Enums.MarkType.MARK_QUESTION,
	KEY_5: Enums.MarkType.NONE,
}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_rng.randomize()  # kozmetik kıvılcımlar her açılışta farklı dağılsın
	_hud = HudScene.instantiate()
	add_child(_hud)
	_hud.execute_toggled.connect(_toggle_execute_mode)
	_hud.day_end_requested.connect(_on_end_day)
	_hud.restart_requested.connect(_new_village)
	_tooltip = AbilityTooltip.new()
	add_child(_tooltip)
	# Ayıklama sinematiği için karartma katmanı (kartların üstünde, zoom kartın altında).
	_cine_dim = ColorRect.new()
	_cine_dim.color = Color(0.02, 0.0, 0.01, 0.78)
	_cine_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cine_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cine_dim.z_index = 250
	_cine_dim.visible = false
	add_child(_cine_dim)
	# Gece katmanı (koyu indigo + hilal + yıldızlar; gece avı sekansında belirir).
	_night_layer = Control.new()
	_night_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_night_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_night_layer.z_index = 200
	_night_layer.draw.connect(_draw_night_layer)
	add_child(_night_layer)
	resized.connect(_relayout)
	_connect_events()
	_new_village()


func _connect_events() -> void:
	EventBus.card_executed.connect(_on_card_executed)
	EventBus.character_questioned.connect(_on_questioned)
	EventBus.question_denied.connect(_on_question_denied)
	EventBus.night_passed.connect(_on_night_passed)
	EventBus.slayer_used.connect(_on_slayer_used)
	EventBus.mark_changed.connect(func(_s, _m): _refresh_cards())
	EventBus.village_won.connect(_on_village_won)
	EventBus.village_lost.connect(_on_village_lost)


func _new_village() -> void:
	var conf: Dictionary
	if RunManager.has_active_run():
		# Sefer modu: mevcut düğümün (seed'li) config'i.
		conf = RunManager.current_village_config().duplicate()
	else:
		# Bağımsız mod (test/geliştirme): rastgele köy.
		conf = VILLAGE_CONFIG.duplicate()
		conf["seed"] = Rng.randomize_seed()
	Rng.seed_with(int(conf["seed"]))
	var state := VillageGenerator.generate(conf, Rng.rng())
	if state == null:
		push_error("Köy üretilemedi")
		return
	GameState.start_village(state)
	AudioManager.play_deal()
	_hud.hide_overlay()
	_hud.update_all()  # üst panelleri HEMEN doldur
	_set_execute_mode(false)
	_hovered_seat = -1
	_night_count = 0
	_slayer_seat = -1
	_protect_mode = false
	if _tooltip != null:
		_tooltip.hide_tip()
	_spawn_cards(state.n)
	_relayout()
	_refresh_cards()
	_deal_cards()
	_hud.play_intro()
	# Tutorial köyünde (sefer başı) kısa yönlendirme (§12 katmanlı öğretim).
	if RunManager.has_active_run() and RunManager.current_index == 0 and state.n <= 5:
		_hud.flash_banner("Karakterlere tıklayıp SORGULA — kurt her ifadesinde yalan söyler. Gece basmadan bul!", Palette.SAFFRON)
	queue_redraw()


func _spawn_cards(n: int) -> void:
	for c in _cards:
		c.queue_free()
	_cards.clear()
	for i in range(n):
		var card: CardView = CardScene.instantiate()
		card.setup(i)
		card.clicked.connect(_on_card_clicked)
		card.right_clicked.connect(_on_card_right_clicked)
		card.hover_changed.connect(_on_card_hover)
		add_child(card)
		_cards.append(card)
	# Tooltip kartların ÜSTÜNde kalsın (en son eklenen en üstte çizilir).
	if _tooltip != null:
		move_child(_tooltip, get_child_count() - 1)


## Kartlar ortak desteden (alt-orta, ekran dışı) TEK TEK dağıtılsın.
func _deal_cards() -> void:
	var deck_pos := Vector2(size.x * 0.5 - CardView.W * 0.5, size.y + 80.0)
	for i in range(_cards.size()):
		_cards[i].deal_in(_cards[i].position, 0.15 + i * 0.13, deck_pos)


## Kart ayıklandı: yüzünü çevir (gerçek kimlik). Evil ise sinematik zoom + fiziksel
## bölünme oynat.
func _on_card_executed(seat: int, was_evil: bool) -> void:
	_animate_seat(seat)
	if was_evil and seat < _cards.size():
		var card := _cards[seat]
		await get_tree().create_timer(0.35).timeout  # flip (gerçek kurt yüzü) görünsün
		await _play_execute_cinematic(card)


## Kurt kartına yavaşça zoom + karart, sonra kartı fiziksel olarak ikiye böl.
func _play_execute_cinematic(card: CardView) -> void:
	_cinematic = true
	if _tooltip != null:
		_tooltip.hide_tip()
	_cine_dim.visible = true
	_cine_dim.modulate.a = 0.0
	card.z_index = 300
	var center_pos := Vector2(size.x * 0.5 - card.size.x * 0.5, size.y * 0.4 - card.size.y * 0.5)

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_cine_dim, "modulate:a", 1.0, 0.5)
	t.tween_property(card, "position", center_pos, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "scale", Vector2(2.1, 2.1), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await t.finished

	await get_tree().create_timer(0.18).timeout
	card.play_split()
	await get_tree().create_timer(0.75).timeout
	card.visible = false  # kurt yok oldu

	var ft := create_tween()
	ft.tween_property(_cine_dim, "modulate:a", 0.0, 0.4)
	await ft.finished
	_cine_dim.visible = false
	card.z_index = 0
	_cinematic = false


## SORGU: ifade alındı — balon pop + HUD tazele.
func _on_questioned(seat: int) -> void:
	for card in _cards:
		if card.seat == seat:
			card.pop_bubble()
		else:
			card.refresh()
	if _hud != null:
		_hud.update_all()


func _on_question_denied(_seat: int, reason: String) -> void:
	if _hud != null:
		_hud.flash_banner("✋ " + reason.capitalize(), Palette.SAFFRON)


## GECE SEKANSI: karanlık çöker, kurt avlanır (kurban kartları pençelenir), şafak söker.
## GameState.end_day() senkron işledi; burada yalnız görsel sekans oynar.
func _on_night_passed(victims: Array) -> void:
	_night_count += 1
	_cinematic = true
	if _tooltip != null:
		_tooltip.hide_tip()
	# Karanlık çöker (gece göğü: indigo + hilal + yıldızlar).
	var t := create_tween()
	t.tween_method(_set_night_alpha, 0.0, 1.0, 0.5)
	await t.finished
	if _hud != null:
		_hud.flash_banner("🌙 Gece çöktü..." if victims.is_empty() else "🌙 Gece çöktü — sürüden ulumalar geliyor...", Color("9db8e8"))
	await get_tree().create_timer(0.55).timeout
	# Kurbanlar pençelenir.
	for v in victims:
		for card in _cards:
			if card.seat == v:
				card.refresh()
				card.play_night_death()
				break
		if _hud != null:
			_hud.flash_banner("🐺 Kurt avlandı: #%d can verdi!" % v, Palette.BLOOD)
		await get_tree().create_timer(0.9).timeout
	if victims.is_empty() and _hud != null:
		_hud.flash_banner("Sürü bu gece sağ çıktı.", Palette.SAFFRON)
		await get_tree().create_timer(0.6).timeout
	# Şafak söker.
	var t2 := create_tween()
	t2.tween_method(_set_night_alpha, 1.0, 0.0, 0.6)
	await t2.finished
	_cinematic = false
	_refresh_cards()
	if _hud != null:
		_hud.update_all()
		if GameState.is_active():
			_hud.flash_banner("☀ GÜN %d — sorgu hakların tazelendi" % GameState.village.day, Palette.SAFFRON)
	queue_redraw()


func _relayout() -> void:
	if _cards.is_empty():
		return
	var center := Vector2(size.x * 0.5, size.y * 0.5 + 2.0)
	# Büyük köylerde (n>=8) kartları biraz daha dışa it — balonlar üst üste binmesin.
	var n := _cards.size()
	var radius := minf(size.x, size.y) * (0.305 + maxf(0.0, n - 7) * 0.008)
	_slots.clear()
	for i in range(n):
		# Seat 0 tepede, saat yönünde artar (§5.1).
		var ang := -PI * 0.5 + TAU * float(i) / float(n)
		var dir := Vector2(cos(ang), sin(ang))
		var pos := center + dir * radius
		_cards[i].position = pos - _cards[i].size * 0.5
		# Slot (kesikli border ile çizilen boş kart yeri) — dağıtım hedefi.
		_slots.append(Rect2(_cards[i].position, _cards[i].size))
		# Balonu dış-yana koy. Üst/alt ORTA kartlar hariç hep sağ/sol (ekran taşmasın).
		var side := "right"
		if absf(dir.x) >= 0.3:
			side = "right" if dir.x > 0.0 else "left"
		elif dir.y < 0.0:
			side = "right"  # üst-orta: yana
		else:
			side = "bottom"  # yalnız gerçek alt-orta kart
		_cards[i].set_bubble_side(side)


func _refresh_cards() -> void:
	for card in _cards:
		card.refresh()
		var alive := GameState.village.get_character(card.seat).is_alive()
		card.set_executable_hint(_execute_mode and alive)
		card.set_protect_hint(_protect_mode and alive)


## Belirli bir seat'i flip animasyonuyla çevir, diğerlerini sessizce tazele.
func _animate_seat(seat: int) -> void:
	for card in _cards:
		if card.seat == seat:
			card.animate_reveal()
		else:
			card.refresh()
		card.set_executable_hint(_execute_mode and GameState.village.get_character(card.seat).is_alive())


## Atmosfer animasyonu: her kare ilerlet + yeniden çiz. Kozmetik.
func _process(delta: float) -> void:
	_time += delta
	if _sparks.is_empty() and size.x > 0.0:
		_init_sparks()
	for s in _sparks:
		s.y -= s.vy * delta
		s.x += sin(_time * 0.6 + s.phase) * s.drift * delta
		if s.y < -8.0:
			s.y = size.y + 8.0
			s.x = _fx_rng.randf_range(0.0, size.x)

	# Göz bakışını YUMUŞAK takip et (ani sıçrama yok). Hedef: hover kart yönü ya da
	# yavaş idle gezinme.
	var center := Vector2(size.x * 0.5, size.y * 0.5 + 2.0)
	var target := Vector2(sin(_time * 0.5) * 0.32, sin(_time * 0.83 + 1.0) * 0.22)
	if _hovered_seat >= 0 and _hovered_seat < _cards.size():
		var cc: Vector2 = _cards[_hovered_seat].position + _cards[_hovered_seat].size * 0.5
		var d := cc - center
		if d.length() > 1.0:
			target = d.normalized()
	# kritik-sönümlü his: kısa mesafede hızlı, uzakta yumuşak
	_eye_look = _eye_look.lerp(target, clampf(delta * 6.0, 0.0, 1.0))

	# Kazanma patlaması parçacıkları (sönümlü uçuş).
	if not _burst.is_empty():
		var alive_b: Array = []
		for p in _burst:
			p.life -= delta * 0.85
			if p.life > 0.0:
				p.pos += p.vel * delta
				p.vel *= 1.0 - 1.8 * delta
				p.rot += delta * 3.0
				alive_b.append(p)
		_burst = alive_b
	queue_redraw()


func _init_sparks() -> void:
	_sparks.clear()
	for i in range(SPARK_COUNT):
		_sparks.append({
			"x": _fx_rng.randf_range(0.0, size.x),
			"y": _fx_rng.randf_range(0.0, size.y),
			"vy": _fx_rng.randf_range(7.0, 26.0),
			"drift": _fx_rng.randf_range(6.0, 22.0),
			"size": _fx_rng.randf_range(1.2, 3.6),
			"phase": _fx_rng.randf_range(0.0, TAU),
			"spd": _fx_rng.randf_range(1.4, 3.2),
			"warm": _fx_rng.randf() < 0.7,  # çoğu safran/bakır, azı soğuk
		})


## Mum ışığı gibi düzensiz titreme (0.7..1.0). İki sinüsün çarpımı = sözde-gürültü.
func _flicker() -> float:
	return 0.82 + 0.18 * sin(_time * 11.0) * sin(_time * 6.3 + 1.1)


func _draw() -> void:
	# Ritüel arka planı (pentagram + kandiller + kafatasları görselde).
	# "cover": en-boyu koruyup ekranı doldur (kırpma).
	var tex_size := Vector2(BG_TEXTURE.get_width(), BG_TEXTURE.get_height())
	var scale := maxf(size.x / tex_size.x, size.y / tex_size.y)
	var draw_size := tex_size * scale
	var offset := (size - draw_size) * 0.5
	# Doku olduğu gibi (renk modülasyonu YOK — kullanıcı kararı).
	draw_texture_rect(BG_TEXTURE, Rect2(offset, draw_size), false)
	# Hafif vinyet/karartma (kenarları koyulaştır, kartlar öne çıksın).
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.01, 0.01, 0.18), true)
	# Geceler geçtikçe arka plan KIZILA kayar (tehdit büyüyor — §10.5 dinamik tint).
	if _night_count > 0:
		var tint := minf(0.34, _night_count * 0.09)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.02, 0.02, tint), true)

	# Kesikli (dashed) boş kart slotları — kartlar buraya tek tek dağıtılır.
	for slot in _slots:
		_draw_dashed_slot(slot, 13.0, Color(0.92, 0.66, 0.32, 0.34))

	# Merkezde nefes alan ritüel parıltısı (mum titremesiyle modüle).
	var center := Vector2(size.x * 0.5, size.y * 0.5 + 2.0)
	var breathe := 0.5 + 0.5 * sin(_time * 1.15)
	var glow := (0.55 + 0.45 * breathe) * _flicker()
	for layer in [[230.0, 0.05], [150.0, 0.07], [90.0, 0.11], [48.0, 0.16]]:
		var r: float = layer[0] * (0.92 + 0.08 * breathe)
		draw_circle(center, r, Color(0.70, 0.10, 0.08, layer[1] * glow))

	# --- Merkez nazar / kem göz: seçili/hover karta doğru bakar (§10.1) ---
	_draw_eye_arms(center, breathe)     # gözden çıkan dalgalanan koyu kollar
	_draw_eye_backing(center, breathe)  # gözün gömülü olduğu koyu soket
	_draw_nazar_eye(center, breathe)

	# Süzülen kıvılcım/toz parçacıkları — 4-köşe yıldız (twinkle).
	for s in _sparks:
		var tw: float = 0.30 + 0.5 * (0.5 + 0.5 * sin(_time * s.spd + s.phase))
		var col := Color(0.96, 0.74, 0.36, tw)  # hepsi sıcak (soğuk mavi arka planla çelişiyordu)
		_draw_star(Vector2(s.x, s.y), s.size * 1.7 * (0.7 + 0.3 * tw), col, _time * 0.4 + s.phase)

	# Kazanma yıldız patlaması (altın, merkezden dışa).
	for p in _burst:
		var la := clampf(p.life, 0.0, 1.0)
		_draw_star(p.pos, p.size * (0.6 + 0.4 * la), Color(1.0, 0.84, 0.42, la), p.rot)
		_draw_star(p.pos, p.size * 0.5 * la, Color(1.0, 0.97, 0.85, la), -p.rot * 0.7)


## Merkez nazar / kem göz — SADE: kırmızı gradyan gövde + koyu bebek. Parlama/
## catchlight YOK. Arkasında düz tek siyah border (_draw_eye_backing).
func _draw_nazar_eye(center: Vector2, breathe: float) -> void:
	# Referans: büyük KIRMIZI göz + büyük KOYU bebek + yumuşak kızıl kenar.
	# DÜZ renkler (bantlı gradyan / beyaz parıltı / iris dokusu YOK).
	var tw := _time * 1.1
	var rx := 74.0 * (0.98 + 0.03 * breathe)
	var ry := 88.0 * (0.98 + 0.03 * breathe)

	# Gözden dışa yumuşak kızıl kenar (glow) — koyu çevreye sızar (birkaç faint katman).
	for i in range(6):
		var f := float(i) / 6.0
		draw_colored_polygon(_eye_outline(center, rx * (1.0 + f * 0.34), ry * (1.0 + f * 0.32), tw),
			Color(0.72, 0.06, 0.04, 0.11 * (1.0 - f)))

	# Düz kırmızı göz (ince koyu kenar + ana kırmızı — 2 ton, banding yok).
	draw_colored_polygon(_eye_outline(center, rx, ry, tw), Color(0.46, 0.03, 0.02, 1.0))
	draw_colored_polygon(_eye_outline(center, rx * 0.9, ry * 0.9, tw), Color(0.86, 0.11, 0.06, 1.0))

	# Büyük koyu bebek (dikey oval), bakışa göre kayar.
	var pc := center + Vector2(_eye_look.x * rx * 0.36, _eye_look.y * ry * 0.4)
	draw_colored_polygon(_eye_outline(pc, rx * 0.42, ry * 0.5, tw), Color(0.03, 0.0, 0.0, 1.0))


## Gözün organik konturu: dikey yumurta (elips) + zamanla dalgalanan canlı kenar.
## Aynı wobble tüm ölçeklerde kullanıldığı için katmanlar temiz yuvalanır.
func _eye_outline(c: Vector2, rx: float, ry: float, tw: float) -> PackedVector2Array:
	var seg := 46
	var pts := PackedVector2Array()
	for i in range(seg):
		var a := TAU * float(i) / float(seg)
		var wob := 1.0 + 0.045 * sin(a * 3.0 + tw) + 0.028 * sin(a * 5.0 - tw * 0.6)
		# hafif yumurta: alt yarı biraz daha dolgun
		var yb := sin(a)
		var yr := ry * (1.0 + 0.06 * yb)
		pts.append(c + Vector2(cos(a) * rx * wob, yb * yr * wob))
	return pts


## Gözden çıkan DALGALANAN koyu kollar (yaratık hissi). Her kol incelen, sinüsle
## kıvrılan koyu bir şerit; zamanla sallanır. Gözün arkasında çizilir.
func _draw_eye_arms(center: Vector2, breathe: float) -> void:
	var rx := 74.0 * (0.98 + 0.03 * breathe) * 1.28
	var ry := 88.0 * (0.98 + 0.03 * breathe) * 1.28
	var arms := 9
	var col := Color(0.03, 0.006, 0.012, 1.0)
	for k in range(arms):
		var base_a := TAU * float(k) / float(arms)
		var ang := base_a + 0.20 * sin(_time * 1.2 + k * 0.8)
		var root := center + Vector2(cos(ang), sin(ang)) * Vector2(rx * 0.72, ry * 0.72)
		var length := (rx + ry) * 0.5 * (0.85 + 0.3 * sin(_time * 0.9 + k * 1.3))
		_draw_wavy_arm(root, ang, length, 16.0 + 4.0 * sin(_time + k), col, k)


## Kökten uca incelen, boyunca sinüsle kıvrılan koyu şerit.
func _draw_wavy_arm(root: Vector2, angle: float, length: float, base_w: float, col: Color, idx: int) -> void:
	var seg := 9
	var dir := Vector2(cos(angle), sin(angle))
	var perp := Vector2(-dir.y, dir.x)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(seg + 1):
		var t := float(i) / float(seg)
		var wob := sin(t * 3.2 + _time * 2.2 + idx) * (14.0 * t)  # uca doğru artan kıvrım
		var w := base_w * (1.0 - t) * (1.0 - t)                    # uca doğru incel
		var p := root + dir * (length * t) + perp * wob
		left.append(p + perp * w)
		right.append(p - perp * w)
	var pts := PackedVector2Array()
	for p in left:
		pts.append(p)
	for i in range(right.size()):
		pts.append(right[right.size() - 1 - i])
	draw_colored_polygon(pts, col)


## Kırmızı gözün oturduğu KOYU çevre (soket). Gözden biraz büyük düz koyu şekil.
func _draw_eye_backing(center: Vector2, breathe: float) -> void:
	var rx := 74.0 * (0.98 + 0.03 * breathe) * 1.28
	var ry := 88.0 * (0.98 + 0.03 * breathe) * 1.28
	draw_colored_polygon(_eye_outline(center, rx, ry, _time * 1.1), Color(0.04, 0.01, 0.015, 1.0))


## Göz gradyan rengi: t=0 kenar (koyu kan) -> t=1 merkez (sıcak kor). eg parlaklık.
func _eye_grad(t: float, eg: float) -> Color:
	var edge := Color(0.24, 0.02, 0.02)
	var mid := Color(0.82, 0.12, 0.06)
	var core := Color(1.0, 0.58, 0.26)
	var c: Color
	if t < 0.58:
		c = edge.lerp(mid, t / 0.58)
	else:
		c = mid.lerp(core, (t - 0.58) / 0.42)
	return Color(c.r * eg, c.g * eg, c.b * eg, 1.0)


func _set_night_alpha(v: float) -> void:
	_night_alpha = v
	if _night_layer != null:
		_night_layer.queue_redraw()


## Gece göğü: koyu indigo kaplama + parlayan HİLAL + titreyen yıldızlar.
## Alt kenardan yukarı hafif gradyan (ufuk hâlâ seçilsin).
func _draw_night_layer() -> void:
	if _night_alpha <= 0.0:
		return
	var a := _night_alpha
	var sz := _night_layer.size
	_night_layer.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.02, 0.03, 0.10, 0.60 * a), true)
	# üstte daha koyu bant (gökyüzü hissi)
	_night_layer.draw_rect(Rect2(Vector2.ZERO, Vector2(sz.x, sz.y * 0.35)), Color(0.01, 0.02, 0.08, 0.35 * a), true)

	# Hilal: dolu ay + üstüne kaydırılmış gök-rengi daire (ısırık).
	var mc := Vector2(sz.x * 0.86, sz.y * 0.16)
	for g in range(4):
		_night_layer.draw_circle(mc, 34.0 + g * 10.0, Color(0.85, 0.88, 1.0, 0.045 * a * (1.0 - g * 0.2)))
	_night_layer.draw_circle(mc, 30.0, Color(0.92, 0.93, 0.98, 0.95 * a))
	_night_layer.draw_circle(mc + Vector2(-12, -7), 26.0, Color(0.05, 0.06, 0.14, 0.97 * a))

	# Yıldızlar: deterministik konum (hash), zamanla titrer.
	for i in range(26):
		var fx := fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
		var fy := fposmod(sin(float(i) * 78.233) * 12578.1459, 1.0)
		var sp := Vector2(fx * sz.x, fy * sz.y * 0.5)
		var tw := 0.35 + 0.55 * (0.5 + 0.5 * sin(_time * (1.5 + fx * 2.0) + float(i)))
		_night_layer.draw_circle(sp, 1.6 + fx * 1.4, Color(0.9, 0.92, 1.0, tw * a * 0.8))


## Kazanma yıldız patlaması: merkezden dışa uçan altın yıldızlar.
func _spawn_win_burst() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	for i in range(46):
		var ang := _fx_rng.randf_range(0.0, TAU)
		var spd := _fx_rng.randf_range(140.0, 520.0)
		_burst.append({
			"pos": center,
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"life": _fx_rng.randf_range(0.7, 1.25),
			"size": _fx_rng.randf_range(3.0, 8.0),
			"rot": _fx_rng.randf_range(0.0, TAU),
		})


## Kesikli kenarlı boş kart slotu: hafif dolgu + köşeleri yuvarlak dashed border.
## Kartlar dağıtılınca üstünü kapatır; "buraya kart gelecek" hissini verir.
func _draw_dashed_slot(rect: Rect2, radius: float, col: Color) -> void:
	# hafif iç dolgu
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.0, 0.0, 0.0, 0.16)
	fill.set_corner_radius_all(int(radius))
	draw_style_box(fill, rect)
	# kesikli kenarlar (düz kısımlar; köşeler yuvarlaklık için boş bırakılır)
	var dash := 9.0
	var gap := 7.0
	var r := radius
	var p := rect.position
	var s := rect.size
	_dashed_line(p + Vector2(r, 0), p + Vector2(s.x - r, 0), dash, gap, col)          # üst
	_dashed_line(p + Vector2(r, s.y), p + Vector2(s.x - r, s.y), dash, gap, col)        # alt
	_dashed_line(p + Vector2(0, r), p + Vector2(0, s.y - r), dash, gap, col)            # sol
	_dashed_line(p + Vector2(s.x, r), p + Vector2(s.x, s.y - r), dash, gap, col)        # sağ


func _dashed_line(a: Vector2, b: Vector2, dash: float, gap: float, col: Color) -> void:
	var dir := b - a
	var total := dir.length()
	if total <= 0.0:
		return
	dir = dir / total
	var t := 0.0
	while t < total:
		var e := minf(t + dash, total)
		draw_line(a + dir * t, a + dir * e, col, 2.0)
		t += dash + gap


## 4-köşe parıltı yıldızı.
func _draw_star(c: Vector2, r: float, col: Color, rot: float) -> void:
	var pts := PackedVector2Array()
	for i in range(8):
		var a := rot + PI * float(i) / 4.0
		var rr := r if i % 2 == 0 else r * 0.34
		pts.append(c + Vector2(cos(a) * rr, sin(a) * rr))
	draw_colored_polygon(pts, col)


# --- giriş ---

func _on_card_clicked(seat: int) -> void:
	if _cinematic or not GameState.is_active():
		return
	# AĞIL: koruma seçim modundaysa bu tık koruma + gece.
	if _protect_mode:
		var pc := GameState.village.get_character(seat)
		if not pc.is_alive():
			if _hud != null:
				_hud.flash_banner("Ölüler ağıla alınmaz — koruma seç ya da tekrar 🌙", Color("9db8e8"))
			return
		_protect_mode = false
		_refresh_cards()
		if _hud != null:
			_hud.flash_banner("🛡 #%d ağıla alındı — gece çöküyor..." % seat, Color("9db8e8"))
		GameState.end_day(seat)
		return
	# Aktif yetenek (Kılıççı/Avcı) hedefleme modu: sıradaki tık hedef (aynı karta tık = iptal).
	if _slayer_seat >= 0:
		var sl := _slayer_seat
		_slayer_seat = -1
		if seat == sl:
			if _hud != null:
				_hud.set_execute_mode(false)  # banner'ı sıfırla
		elif GameState.village.get_character(sl).role == &"Hunter":
			GameState.hunt(sl, seat)
		else:
			GameState.slay(sl, seat)
		_refresh_cards()
		return
	if _execute_mode:
		GameState.execute(seat)
		_set_execute_mode(false)
		return
	# Kılıççı/Avcı'ya tıklama → hedefleme moduna gir (yetenek; sorgu değil).
	var c := GameState.village.get_character(seat)
	if c.is_alive() and not c.ability_used and not c.is_evil() and (c.role == &"Slayer" or c.role == &"Hunter"):
		_slayer_seat = seat
		if _hud != null:
			var vt := "kılıç saplayacağın" if c.role == &"Slayer" else "ok atacağın"
			_hud.flash_banner("⚔ %s — %s kartı seç (iptal: tekrar tık)" % [RoleNames.display(c.role).to_upper(), vt], Palette.SAFFRON)
		_refresh_cards()
		return
	# V2: tık = SORGU (1 hak harcar; karakter sıradaki ifadesini verir).
	GameState.question(seat)


## Günü bitir (HUD butonu ya da G tuşu). İKİ AŞAMALI — AĞIL (koruma) + emniyet:
## 1. basış: koruma seçim modu açılır ("koyacağın kartı seç ya da tekrar bas").
## 2. basış: korumasız gece. Kart seçilirse: o kart ağıla alınıp gece çöker.
func _on_end_day() -> void:
	if _cinematic or not GameState.is_active():
		return
	_slayer_seat = -1
	_set_execute_mode(false)
	if not _protect_mode:
		_protect_mode = true
		if _hud != null:
			var extra := ""
			if GameState.village.questions_left > 0:
				extra = "  (%d sorgu hakkın yanacak!)" % GameState.village.questions_left
			_hud.flash_banner("🛡 AĞIL — koruyacağın kartı seç · korumasız gece: tekrar 🌙/G%s" % extra, Color("9db8e8"))
		_refresh_cards()  # mavi koruma halesi
		return
	_protect_mode = false
	_refresh_cards()
	GameState.end_day(-1)


## Kılıç sonucu banner'ı.
func _on_slayer_used(_slayer_seat_arg: int, target: int, hit: bool) -> void:
	if _hud == null:
		return
	if hit:
		_hud.flash_banner("⚔ İsabet — kurt vuruldu ve öldü!", Palette.SAFFRON)
	else:
		_hud.flash_banner("⚔ Iska — #%d bir kurt değildi." % target, Palette.BLOOD)


func _on_card_right_clicked(seat: int) -> void:
	if GameState.village == null:
		return
	var cur: int = GameState.village.marks[seat]
	var idx := MARK_CYCLE.find(cur)
	var next: int = MARK_CYCLE[(idx + 1) % MARK_CYCLE.size()]
	GameState.set_mark(seat, next)


func _on_card_hover(seat: int, entered: bool) -> void:
	if entered:
		_hovered_seat = seat
		if _tooltip != null and seat < _cards.size():
			var card := _cards[seat]
			_tooltip.show_for(seat, Rect2(card.position, card.size), size, card.get_bubble_side())
	else:
		if _hovered_seat == seat:
			_hovered_seat = -1
			if _tooltip != null:
				_tooltip.hide_tip()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# 1–5: üstüne gelinen karta mark koy.
		if _hovered_seat >= 0 and MARK_KEYS.has(event.keycode):
			GameState.set_mark(_hovered_seat, MARK_KEYS[event.keycode])
			return
		match event.keycode:
			KEY_E:
				# E: ayıklama modunu aç/kapat. (ESC artık global duraklat menüsü.)
				if GameState.is_active():
					_toggle_execute_mode()
			KEY_G:
				# G: günü bitir (gece).
				_on_end_day()
			KEY_R:
				_new_village()


func _on_village_won(_score: int) -> void:
	_set_execute_mode(false)
	_spawn_win_burst()  # altın yıldız patlaması (sinematikle birlikte)
	# Son kurt ayıklanınca HEMEN sonuç ekranına atlama; kurt kartının açılışı +
	# kesme efekti görünsün, sonra geç. (HUD "Sürü kurtarıldı" overlay'i de gecikir.)
	if RunManager.has_active_run():
		await get_tree().create_timer(2.5).timeout  # ayıklama sinematiği bitsin
		RunManager.on_village_won(GameState.score, GameState.health)
		if RunManager.has_active_run():
			# Köy kazanıldı, sefer sürüyor → dükkâna uğra (M4).
			get_tree().call_deferred("change_scene_to_file", "res://scenes/shop.tscn")
		else:
			# Boss alt edildi / sefer bitti → sonuç ekranı.
			_go_to_result()


func _on_village_lost(_reason: String) -> void:
	_set_execute_mode(false)
	if RunManager.has_active_run():
		RunManager.on_village_lost()
		_go_to_result()


func _go_to_result() -> void:
	# Sinyal içinde sahne değiştirme; freed olurken güvenli olsun diye deferred.
	get_tree().call_deferred("change_scene_to_file", "res://scenes/result.tscn")


func _toggle_execute_mode() -> void:
	_set_execute_mode(not _execute_mode)


func _set_execute_mode(on: bool) -> void:
	_slayer_seat = -1
	if on:
		_protect_mode = false  # ayıklama moduna geçiş korumayı iptal eder
	_execute_mode = on and GameState.is_active()
	if _hud != null:
		_hud.set_execute_mode(_execute_mode)
	_refresh_cards()
