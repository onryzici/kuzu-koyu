class_name TestimonyLog
extends Control

## İFADE DEFTERİ (dedüksiyon UX): şimdiye dek verilen TÜM ifadeler + gece
## kurbanları tek yerde, güne göre gruplu. Oyuncu kartları tek tek gezmeden
## kanıtları tarayabilsin diye. TAB ya da HUD'daki Defter butonu açar/kapar.
## Yalnız görsel — veri GameState.village'dan okunur, hiçbir şey değiştirmez.

const PANEL_W := 420.0

var _scroll: ScrollContainer
var _list: VBoxContainer
var _open := false
var _anim: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -PANEL_W
	offset_top = 150.0
	offset_bottom = -170.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 180  # kartların üstü, gece/sinematik katmanların (200+) altı
	visible = false

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP  # açıkken alttaki kartlara tıklanmasın
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0e080ef4")
	sb.corner_radius_top_left = 14
	sb.corner_radius_bottom_left = 14
	sb.set_border_width_all(0)
	sb.set_content_margin_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 14
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var title := Label.new()
	title.text = Loc.t("log_title")
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Palette.SAFFRON)
	vb.add_child(title)

	var hint := Label.new()
	hint.text = Loc.t("log_hint")
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Palette.IVORY.darkened(0.25))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(hint)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)


func toggle() -> void:
	set_open(not _open)


## Aç/kapa animasyonlu: sağdan süzülerek gelir (fade + kayma), kapanırken
## hızlıca sağa çekilir. Ani aç-kapa "efektsiz" duruyordu.
func set_open(open: bool) -> void:
	if open == _open:
		return
	_open = open
	if _anim != null and _anim.is_valid():
		_anim.kill()
	if open:
		refresh()
		visible = true
		modulate.a = 0.0
		offset_left = -PANEL_W + 110.0
		offset_right = 110.0
		_anim = create_tween().set_parallel(true)
		_anim.tween_property(self, "offset_left", -PANEL_W, 0.28) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_anim.tween_property(self, "offset_right", 0.0, 0.28) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_anim.tween_property(self, "modulate:a", 1.0, 0.20)
	else:
		_anim = create_tween().set_parallel(true)
		_anim.tween_property(self, "offset_left", -PANEL_W + 90.0, 0.18) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_anim.tween_property(self, "offset_right", 90.0, 0.18) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_anim.tween_property(self, "modulate:a", 0.0, 0.16)
		_anim.chain().tween_callback(func(): visible = false)


func is_open() -> bool:
	return _open


## Defteri güne göre yeniden kur. Girdiler: sorgu ifadeleri (gün etiketli) +
## gece kurbanları (kesin İYİ — sarsılmaz kanıt) + ayıklama sonuçları.
func refresh() -> void:
	if _list == null or GameState.village == null:
		return
	for ch in _list.get_children():
		ch.queue_free()
	var v: VillageState = GameState.village

	# Girdileri (gün, sıra, metin, renk) olarak topla, sonra güne göre yaz.
	var entries: Array = []
	for c in v.characters:
		for k in range(c.given):
			var day: int = c.claim_days[k] if k < c.claim_days.size() else 1
			var col: Color = Palette.IVORY
			# Gerçek yüzü açılmış kurtların eski ifadeleri kızıl düşer (yalandı).
			if c.revealed and c.is_evil():
				col = Palette.BLOOD.lightened(0.15)
			entries.append({
				"day": day, "order": k,
				"text": "#%d %s: „%s”" % [c.seat, RoleNames.display(c.shown_role()), c.claims[k].text],
				"color": col,
			})
	for ev in v.night_events:
		var rule_txt := Loc.t("night_rule_nearest") \
				if int(ev.get("rule", Enums.NightRule.NEAREST)) == Enums.NightRule.NEAREST \
				else Loc.t("night_rule_farthest")
		if int(ev["victim"]) < 0:
			entries.append({
				"day": int(ev["day"]), "order": 999,
				"text": Loc.t("log_trap_entry")
						% [int(ev["day"]), int(ev.get("trapped", -1)), int(ev.get("caught", -1))],
				"color": Palette.SAFFRON,
			})
			continue
		entries.append({
			"day": int(ev["day"]), "order": 999,
			"text": Loc.t("log_night_entry")
					% [int(ev["day"]), int(ev["victim"]), rule_txt],
			"color": Color("9db8e8"),
		})
	for c in v.characters:
		if c.executed:
			entries.append({
				"day": 998, "order": c.seat,
				"text": (Loc.t("log_cull_wolf") if c.is_evil() else Loc.t("log_cull_good")) % c.seat,
				"color": Palette.SAFFRON if c.is_evil() else Palette.BLOOD.lightened(0.2),
			})

	entries.sort_custom(func(a, b):
		return a["day"] < b["day"] if a["day"] != b["day"] else a["order"] < b["order"])

	var cur_day := -1
	for e in entries:
		if e["day"] < 900 and e["day"] != cur_day:
			cur_day = e["day"]
			_add_line(Loc.t("log_day_header") % cur_day, Palette.SAFFRON.darkened(0.1), 15)
		elif e["day"] == 998 and cur_day != 998:
			cur_day = 998
			_add_line(Loc.t("log_culls_header"), Palette.SAFFRON.darkened(0.1), 15)
		_add_line(e["text"], e["color"], 14)

	if entries.is_empty():
		_add_line(Loc.t("log_empty"), Palette.IVORY.darkened(0.3), 14)


func _add_line(text: String, col: Color, fsize: int) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(PANEL_W - 60, 0)
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	_list.add_child(l)
