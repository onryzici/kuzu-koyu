extends Control

## Dükkân (M4, §4) — genişletilmiş ekonomi (kullanıcı isteği: "para işe yarasın"):
##   1. MUSKALAR: sefer boyu kalıcı pasifler (RunManager.buy_passive).
##   2. AZIKLAR: tek köylük takviyeler (RunManager.buy_boon → pending_boons).
##   3. YENİ KAN: parayla rol draft'ı (DraftOverlay — deste burada da büyür).
##   4. YENİDEN KARIŞTIR: muska tekliflerini parayla tazele (fiyat tırmanır).
## UI iş mantığı içermez; tüm satın almalar RunManager üzerinden.

const DRAFT_PRICE := 60
const REROLL_BASE := 20
const REROLL_STEP := 15

var _offers: Array = []          ## bu ziyaretteki muska teklifleri
var _rerolls := 0                ## bu ziyaretteki reroll sayısı (fiyat + seed salt)
var _bought_boons: Array = []    ## bu ziyarette alınan azıklar (tekrar alınmasın)
var _coins_label: Label
var _owned_label: Label
var _cards_box: HBoxContainer
var _boons_box: HBoxContainer
var _reroll_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_offers = RunManager.roll_shop()
	_build()
	_refresh()
	# Giriş animasyonu: BÖLÜM KUTULARI alttan süzülür. (Container İÇİNDEKİ kart
	# pozisyonlarını tween'lemek HBox layout'uyla yarışıyordu — kartlar üst üste
	# biniyordu; kutuyu kaydır, kartlara dokunma.)
	ScreenFx.slide_in(_cards_box, 0.12, Vector2(0, 60))
	ScreenFx.slide_in(_boons_box, 0.26, Vector2(0, 60))


func _build() -> void:
	var fx := ScreenFx.new()
	fx.overlay = Color(0.06, 0.02, 0.04, 0.60)
	add_child(fx)

	var title := _label(Vector2(60, 40), 40, Palette.SAFFRON)
	title.text = Loc.t("shop_title")
	var sub := _label(Vector2(60, 96), 18, Palette.IVORY.darkened(0.1))
	sub.text = Loc.t("shop_sub")
	ScreenFx.slide_in(title, 0.02, Vector2(-60, 0))
	ScreenFx.slide_in(sub, 0.1, Vector2(-60, 0))

	# Base 1600x900 — mutlak konum (preset + custom size güvenilmez).
	_coins_label = _label(Vector2(1260, 44), 26, Color("ffd479"))
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coins_label.size = Vector2(300, 34)

	# --- MUSKALAR bölümü ---
	var charms_h := _label(Vector2(60, 152), 17, Palette.COPPER.lightened(0.25))
	charms_h.text = Loc.t("shop_charms_title")

	_reroll_btn = Button.new()
	_reroll_btn.position = Vector2(1300, 140)
	_reroll_btn.size = Vector2(240, 44)
	ScreenFx.style_button(_reroll_btn, Color(0.10, 0.06, 0.08, 0.96), 15)
	_reroll_btn.pressed.connect(_reroll)
	add_child(_reroll_btn)

	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 28)
	_cards_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_cards_box.position = Vector2(-_row_width(3, 260.0) * 0.5, -258)
	add_child(_cards_box)

	# --- AZIKLAR bölümü (tek köylük) + YENİ KAN ---
	var boons_h := _label(Vector2(60, 462), 17, Palette.COPPER.lightened(0.25))
	boons_h.text = Loc.t("shop_boons_title")

	_boons_box = HBoxContainer.new()
	_boons_box.add_theme_constant_override("separation", 24)
	_boons_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_boons_box.position = Vector2(-_row_width(4, 250.0) * 0.5, 52)
	add_child(_boons_box)

	_owned_label = _label(Vector2(60, 0), 15, Palette.COPPER.lightened(0.3))
	_owned_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_owned_label.position = Vector2(60, -108)
	_owned_label.size = Vector2(980, 60)
	_owned_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var cont := Button.new()
	cont.text = Loc.t("shop_continue")
	cont.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	cont.position = Vector2(-320, -92)
	cont.size = Vector2(280, 56)
	ScreenFx.style_button(cont, Palette.CRIMSON.darkened(0.15), 22)
	cont.pressed.connect(_continue)
	add_child(cont)


func _row_width(count: int, card_w: float) -> float:
	return count * card_w + max(0, count - 1) * 26.0


func _reroll_price() -> int:
	return REROLL_BASE + _rerolls * REROLL_STEP


func _draft_price() -> int:
	var p := DRAFT_PRICE
	if RunManager.has_passive(&"sadaka"):
		p = int(p * 0.75)
	return p


func _refresh() -> void:
	_coins_label.text = Loc.t("ui_coins") % RunManager.coins
	_reroll_btn.text = Loc.t("shop_reroll") % _reroll_price()
	_reroll_btn.disabled = RunManager.coins < _reroll_price()
	for ch in _cards_box.get_children():
		ch.queue_free()
	for id in _offers:
		_cards_box.add_child(_make_offer_card(id))
	for ch in _boons_box.get_children():
		ch.queue_free()
	for id in RunManager.BOONS:
		_boons_box.add_child(_make_boon_card(id))
	_boons_box.add_child(_make_draft_card())
	# Sahip olunanlar + bekleyen azıklar
	var names: Array = []
	for p in RunManager.owned_passives:
		names.append(RunManager.passive_name(p))
	var txt: String = Loc.t("shop_owned_label") + (", ".join(names) if not names.is_empty() else Loc.t("shop_none"))
	if not RunManager.pending_boons.is_empty():
		var bnames: Array = []
		for b in RunManager.pending_boons:
			bnames.append(RunManager.boon_name(b))
		txt += "\n" + Loc.t("shop_pending_boons") + ", ".join(bnames)
	_owned_label.text = txt


func _make_offer_card(id: StringName) -> Control:
	var owned: bool = RunManager.has_passive(id)
	var price := RunManager.price_of(id)  # Sadaka Kesesi indirimi dahil
	var afford: bool = RunManager.coins >= price
	var cursed: bool = RunManager.PASSIVES[id].get("cursed", false)

	var panel := _panel(Vector2(260, 236),
		Palette.category_color(Enums.Category.VILLAGER) if owned
		else (Palette.BLOOD.darkened(0.1) if cursed else Palette.SAFFRON.darkened(0.2)))
	var vb: VBoxContainer = panel.get_child(0)

	var nm := Label.new()
	nm.text = ("⚠ " if cursed else "") + RunManager.passive_name(id)
	nm.add_theme_font_size_override("font_size", 21)
	nm.add_theme_color_override("font_color", Palette.BLOOD.lightened(0.25) if cursed else Palette.SAFFRON)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(nm)

	var ds := Label.new()
	ds.text = RunManager.passive_desc(id)
	ds.add_theme_font_size_override("font_size", 15)
	ds.add_theme_color_override("font_color", Palette.IVORY)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.custom_minimum_size = Vector2(228, 96)
	ds.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	vb.add_child(ds)

	var buy := Button.new()
	buy.add_theme_font_size_override("font_size", 18)
	buy.custom_minimum_size = Vector2(0, 46)
	if owned:
		buy.text = Loc.t("shop_owned_btn")
		buy.disabled = true
		_style_button(buy, Palette.category_color(Enums.Category.VILLAGER))
	else:
		buy.text = Loc.t("shop_buy") % price
		buy.disabled = not afford
		_style_button(buy, Palette.CRIMSON if afford else Palette.SOOT.lightened(0.2))
		buy.pressed.connect(func(): _buy(id))
	vb.add_child(buy)
	return panel


## Azık kartı: tek köylük takviye (sonraki köy başında işler — pending_boons).
func _make_boon_card(id: StringName) -> Control:
	var price := RunManager.boon_price(id)
	var bought: bool = id in _bought_boons
	var afford: bool = RunManager.coins >= price

	var panel := _panel(Vector2(250, 196), Color(0.42, 0.52, 0.72, 0.8))
	var vb: VBoxContainer = panel.get_child(0)

	var nm := Label.new()
	nm.text = RunManager.boon_name(id)
	nm.add_theme_font_size_override("font_size", 18)
	nm.add_theme_color_override("font_color", Color("9db8e8"))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(nm)

	var ds := Label.new()
	ds.text = RunManager.boon_desc(id)
	ds.add_theme_font_size_override("font_size", 14)
	ds.add_theme_color_override("font_color", Palette.IVORY)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.custom_minimum_size = Vector2(218, 66)
	ds.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	vb.add_child(ds)

	var buy := Button.new()
	buy.add_theme_font_size_override("font_size", 16)
	buy.custom_minimum_size = Vector2(0, 42)
	if bought:
		buy.text = Loc.t("shop_bought")
		buy.disabled = true
		_style_button(buy, Palette.category_color(Enums.Category.VILLAGER))
	else:
		buy.text = Loc.t("shop_buy") % price
		buy.disabled = not afford
		_style_button(buy, Color(0.28, 0.38, 0.62) if afford else Palette.SOOT.lightened(0.2))
		buy.pressed.connect(func():
			if RunManager.buy_boon(id):
				_bought_boons.append(id)
				AudioManager.play_deal()
				_refresh())
	vb.add_child(buy)
	return panel


## YENİ KAN kartı: parayla rol draft'ı — deste dükkânda da büyür.
func _make_draft_card() -> Control:
	var price := _draft_price()
	var has_candidates := not RunManager.draft_choices().is_empty()
	var afford: bool = RunManager.coins >= price

	var panel := _panel(Vector2(250, 196), Palette.SAFFRON.darkened(0.1))
	var vb: VBoxContainer = panel.get_child(0)

	var nm := Label.new()
	nm.text = Loc.t("shop_draft_name")
	nm.add_theme_font_size_override("font_size", 18)
	nm.add_theme_color_override("font_color", Palette.SAFFRON)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(nm)

	var ds := Label.new()
	ds.text = Loc.t("shop_draft_desc") if has_candidates else Loc.t("shop_draft_empty")
	ds.add_theme_font_size_override("font_size", 14)
	ds.add_theme_color_override("font_color", Palette.IVORY)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.custom_minimum_size = Vector2(218, 66)
	ds.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	vb.add_child(ds)

	var buy := Button.new()
	buy.add_theme_font_size_override("font_size", 16)
	buy.custom_minimum_size = Vector2(0, 42)
	buy.text = Loc.t("shop_buy") % price
	buy.disabled = not (has_candidates and afford)
	_style_button(buy, Palette.CRIMSON if (has_candidates and afford) else Palette.SOOT.lightened(0.2))
	buy.pressed.connect(_buy_draft)
	vb.add_child(buy)
	return panel


func _buy_draft() -> void:
	var price := _draft_price()
	if RunManager.coins < price or RunManager.draft_choices().is_empty():
		return
	RunManager.coins -= price
	SaveManager.save_game()
	AudioManager.play_deal()
	var d := DraftOverlay.new()
	d.closed.connect(_refresh)
	add_child(d)
	_refresh()


func _reroll() -> void:
	var price := _reroll_price()
	if RunManager.coins < price:
		return
	RunManager.coins -= price
	_rerolls += 1
	_offers = RunManager.roll_shop(_rerolls)
	SaveManager.save_game()
	AudioManager.play_deal()
	_refresh()


## Ortak kart paneli: pahlı koyu kutu + kategori-renkli kenar; içine VBox koyar.
func _panel(min_size: Vector2, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.03, 0.04, 0.96)
	sb.set_corner_radius_all(14)
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_content_margin_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 8
	panel.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	return panel


func _buy(id: StringName) -> void:
	if RunManager.buy_passive(id):
		AudioManager.play_deal()
		_refresh()


func _continue() -> void:
	# Dükkân artık harita DÜĞÜMÜ (§4): çıkışta düğümü tamamla, haritada ilerle.
	if RunManager.has_active_run() \
			and RunManager.current_node().get("type", -1) == Enums.NodeType.SHOP:
		RunManager.on_stop_completed()
	Fader.change_scene("res://scenes/run_map.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_continue()


func _style_button(btn: Button, bg: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg.darkened(0.4) if state == "normal" else (bg.darkened(0.2) if state == "hover" else bg.darkened(0.55))
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(8)
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", Palette.IVORY)


func _label(pos: Vector2, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("140a10"), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.05, 0.05, 0.12), true)
