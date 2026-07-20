class_name AbilityTooltip
extends PanelContainer

## Kartın üstüne gelince beliren "yetenek kutusu" (Demon Bluff "More Info").
## Rol adı + ne yaptığı + kategori/hizalanma rozetleri. Yalnız görsel; veri
## GameState'ten okunur. Bkz. CLAUDE.md §11 (etkileşim), §7.5 (mark).

const WIDTH := 216.0

var _title: Label
var _ability: Label
var _badges: HBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40
	visible = false
	custom_minimum_size = Vector2(WIDTH, 0)

	# Bordersız koyu panel + geniş yumuşak gölge (referans dili: siyah yüzen kutu).
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("120a12f2")
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(0)
	sb.set_content_margin_all(13)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 4)
	add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 7)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vb)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 19)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_title)

	_ability = Label.new()
	_ability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ability.custom_minimum_size = Vector2(WIDTH - 24, 0)
	_ability.add_theme_font_size_override("font_size", 14)
	_ability.add_theme_color_override("font_color", Palette.IVORY)
	_ability.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_ability)

	_badges = HBoxContainer.new()
	_badges.add_theme_constant_override("separation", 6)
	_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_badges)


## seat: hangi kartın kutusu. avoid_side: kartın konuşma balonunun tarafı — tooltip
## onun TERSİNE konur ki üst üste binmesin.
func show_for(seat: int, card_rect: Rect2, screen: Vector2, avoid_side := "right") -> void:
	if GameState.village == null:
		return
	var c: Character = GameState.village.get_character(seat)
	_clear_badges()

	# V2: yüzler baştan açık. Ölmüş/ayıklanmışsa GERÇEK kimlik, canlıysa iddia (bluff olabilir).
	var truth_known := c.executed or c.night_killed
	var shown_role := c.role if truth_known else c.shown_role()
	var shown_cat := c.category
	var shown_evil := c.is_evil()
	if not truth_known and c.is_evil():
		shown_cat = Enums.Category.VILLAGER  # koyun postunda
		shown_evil = false
	if not truth_known and c.category == Enums.Category.OUTCAST and c.role != &"Saint" and c.role != &"Jinxed":
		shown_cat = Enums.Category.VILLAGER  # sarhoş kendini köylü sanır
	var cat_col := Palette.category_color(shown_cat)
	_title.text = RoleNames.display(shown_role)
	_title.add_theme_color_override("font_color", cat_col.lightened(0.25))
	_ability.text = RoleNames.ability(shown_role)
	if c.night_killed:
		_ability.text = Loc.t("tip_night_dead")
	elif c.is_alive():
		var left := c.claims.size() - c.given
		_ability.text += Loc.t("tip_question_hint") % left
	# Verdiği TÜM ifadeler (balonda yalnız sonuncusu görünür — eskiler kaybolmasın).
	if c.given > 0:
		var lines: Array = []
		for k in range(c.given):
			lines.append("%d) „%s”" % [k + 1, c.claims[k].text])
		_ability.text += Loc.t("tip_claims_header") + "\n".join(lines)
	_add_badge(_category_name(shown_cat), cat_col)
	if truth_known:
		_add_badge(Loc.t("tip_was_wolf") if shown_evil else Loc.t("tip_was_good"), Palette.BLOOD if shown_evil else Color("3FBF6B"))
	elif seat in GameState.village.anchors:
		_add_badge(Loc.t("tip_anchor"), Palette.SAFFRON)

	reset_size()
	_place(card_rect, screen, avoid_side)
	visible = true


func hide_tip() -> void:
	visible = false


func _place(card_rect: Rect2, screen: Vector2, avoid_side: String) -> void:
	var sz := get_combined_minimum_size()
	sz.x = max(sz.x, WIDTH)
	# Konuşma balonu sağdaysa tooltip'i SOLA koy (ters taraf), tersi de öyle.
	var left := card_rect.position.x - sz.x - 12.0
	var right := card_rect.position.x + card_rect.size.x + 12.0
	var x: float
	if avoid_side == "right":
		x = left if left >= 8.0 else right
	else:  # "left" / "top" / "bottom" -> sağı tercih et
		x = right if right + sz.x <= screen.x - 8.0 else left
	x = clampf(x, 8.0, screen.x - sz.x - 8.0)
	# Dikeyde kartla hizalı ama biraz aşağı (üstteki seat pill'iyle çakışmasın).
	var y := clampf(card_rect.position.y + 8.0, 8.0, screen.y - sz.y - 8.0)
	position = Vector2(x, y)


func _clear_badges() -> void:
	for ch in _badges.get_children():
		ch.queue_free()


func _add_badge(text: String, col: Color) -> void:
	var b := Label.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color("faf3e2"))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.15)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	b.add_theme_stylebox_override("normal", sb)
	# Label stylebox'ı yok; PanelContainer sarmalı kullan.
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_theme_stylebox_override("panel", sb)
	pc.add_child(b)
	_badges.add_child(pc)


func _category_name(cat: int) -> String:
	match cat:
		Enums.Category.VILLAGER:
			return Loc.t("cat_villager")
		Enums.Category.OUTCAST:
			return Loc.t("cat_outcast")
		Enums.Category.MINION:
			return Loc.t("cat_minion")
		Enums.Category.DEMON:
			return Loc.t("cat_demon")
		_:
			return ""
