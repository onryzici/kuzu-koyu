extends Control

## OLAY düğümü (§4): köyler arası küçük hikâye + iki seçenek. Sonuçlar seed'lidir
## (determinizm §13.6 — Günün Seferi'nde herkes aynı olayı aynı sonuçla yaşar).
## Ekonomi RunManager'da; tek köylük ödüller pending_boons ile sonraki köye taşınır.

## Her olay: id, title, desc, choices: [{text, cost (para), resolve: Callable-adı}].
## resolve string'i _resolve() içindeki match'e bağlanır (data + küçük hook, §14 ruhu).
const EVENTS := [
	{
		"id": &"yarali_gezgin",
		"title": "YARALI GEZGİN",
		"desc": "Patikada bacağı kanayan bir gezgin oturuyor. Gözlerinde korku:\n\"Sürünün oradan geliyorum... İçlerinde KURT var, gördüm. Yaramı sararsan bildiklerimi anlatırım.\"",
		"choices": [
			{"text": "Yarasını sar (20 altın)", "cost": 20, "act": &"gezgin_yardim"},
			{"text": "Yoluna devam et", "cost": 0, "act": &"gezgin_gec"},
		],
	},
	{
		"id": &"eski_mezarlik",
		"title": "ESKİ MEZARLIK",
		"desc": "Çalıların ardında çökük mezar taşları. Birinin dibi yeni kazılmış gibi...\nToprağın altından soluk bir parıltı vuruyor. Ama buranın nazarına bulaşmak hayra alamet değil.",
		"choices": [
			{"text": "Mezarı kaz", "cost": 0, "act": &"mezar_kaz"},
			{"text": "Saygıyla geç, bir taş bırak", "cost": 0, "act": &"mezar_gec"},
		],
	},
	{
		"id": &"kahin_cadiri",
		"title": "KÂHİNİN ÇADIRI",
		"desc": "Yol kenarında yamalı bir çadır; içeriden tütsü dumanı sızıyor. Yaşlı kadın boncuklarını sayıyor:\n\"Lanetin bir DÜZENİ var evlat. Gümüşünü ver, düzenini söyleyeyim.\"",
		"choices": [
			{"text": "Fal baktır (15 altın)", "cost": 15, "act": &"fal_bak"},
			{"text": "\"Boncuğa inanmam\" de, geç", "cost": 0, "act": &"fal_gec"},
		],
	},
	{
		"id": &"kayip_kuzu",
		"title": "KAYIP KUZU",
		"desc": "Yol kenarında ağlayan bir çocuk: \"Kuzum kayboldu... Çalıların oradan kurt sesi geldi.\"\nHava kararmak üzere. Karar senin çoban.",
		"choices": [
			{"text": "Kuzuyu aramaya çık", "cost": 0, "act": &"kuzu_ara"},
			{"text": "\"Üzgünüm evlat\" de, yürü", "cost": 0, "act": &"kuzu_gec"},
		],
	},
	{
		"id": &"degirmen_yangini",
		"title": "DEĞİRMEN YANGINI",
		"desc": "Tepedeki değirmenden duman yükseliyor; değirmenci avazı çıktığı kadar bağırıyor.\nSöndürmek için köyden kova ve bez almak gerek — bedava değil.",
		"choices": [
			{"text": "Malzeme al, yangına koş (15 altın)", "cost": 15, "act": &"yangin_sondur"},
			{"text": "Uzaktan izle", "cost": 0, "act": &"yangin_izle"},
		],
	},
	{
		"id": &"bereket_sunagi",
		"title": "BEREKET SUNAĞI",
		"desc": "Dut ağacının altında yosun tutmuş eski bir sunak. Üzerinde kurumuş çiçekler,\nadak mumları... Buraya bir şey bırakanın eli boş dönmediği söylenir.",
		"choices": [
			{"text": "Adak sun (25 altın)", "cost": 25, "act": &"adak_sun"},
			{"text": "Sessizce dua et", "cost": 0, "act": &"dua_et"},
		],
	},
]

var _event: Dictionary
var _rng := RandomNumberGenerator.new()
var _title: Label
var _desc: Label
var _result: Label
var _choice_btns: Array = []
var _continue_btn: Button
var _coins_label: Label
var _chosen := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Seed'li seçim: sefer tohumu + düğüm indeksi → tekrar girişte aynı olay/sonuç.
	_rng.seed = RunManager.run_seed + RunManager.current_index * 6151
	_event = EVENTS[_rng.randi() % EVENTS.size()]
	_build()


func _build() -> void:
	var fx := ScreenFx.new()
	fx.overlay = Color(0.04, 0.02, 0.05, 0.58)
	add_child(fx)

	var head := _label(Vector2(60, 44), 40, Palette.SAFFRON)
	head.text = "OLAY"
	ScreenFx.slide_in(head, 0.02, Vector2(-60, 0))

	_coins_label = _label(Vector2(1260, 48), 26, Color("ffd479"))
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coins_label.size = Vector2(300, 34)
	_coins_label.text = "Para: %d" % RunManager.coins

	# Olay kartı: bordersız koyu panel + yumuşak gölge (yeni panel dili).
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("120a12f2")
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(0)
	sb.set_content_margin_all(28)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 16
	sb.shadow_offset = Vector2(0, 5)
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -230
	add_child(panel)
	ScreenFx.slide_in(panel, 0.12, Vector2(0, 50))

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)

	_title = Label.new()
	_title.text = _event["title"]
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Palette.SAFFRON)
	vb.add_child(_title)

	_desc = Label.new()
	_desc.text = _event["desc"]
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(600, 0)
	_desc.add_theme_font_size_override("font_size", 17)
	_desc.add_theme_color_override("font_color", Palette.IVORY)
	vb.add_child(_desc)

	for ch in _event["choices"]:
		var b := Button.new()
		var cost: int = ch["cost"]
		b.text = String(ch["text"])
		b.custom_minimum_size = Vector2(0, 48)
		ScreenFx.style_button(b, Palette.CRIMSON.darkened(0.25) if cost > 0 else Palette.COPPER.darkened(0.35), 18)
		if cost > RunManager.coins:
			b.disabled = true
			b.text += "  (para yetmiyor)"
		b.pressed.connect(_choose.bind(ch))
		vb.add_child(b)
		_choice_btns.append(b)

	_result = Label.new()
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.custom_minimum_size = Vector2(600, 0)
	_result.add_theme_font_size_override("font_size", 17)
	_result.add_theme_color_override("font_color", Color("ffd479"))
	_result.visible = false
	vb.add_child(_result)

	_continue_btn = Button.new()
	_continue_btn.text = "Yola Devam (Enter)"
	_continue_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_continue_btn.position = Vector2(-320, -92)
	_continue_btn.size = Vector2(280, 56)
	ScreenFx.style_button(_continue_btn, Palette.CRIMSON.darkened(0.15), 22)
	_continue_btn.visible = false
	_continue_btn.pressed.connect(_continue)
	add_child(_continue_btn)


func _choose(ch: Dictionary) -> void:
	if _chosen:
		return
	_chosen = true
	var cost: int = ch["cost"]
	RunManager.coins -= cost
	_result.text = _resolve(ch["act"])
	_result.visible = true
	_coins_label.text = "Para: %d" % RunManager.coins
	for b in _choice_btns:
		b.disabled = true
	_continue_btn.visible = true
	AudioManager.play_deal()


## Seçim sonuçları. Şans içerenler _rng'den (seed'li) çekilir — savescum yok.
func _resolve(act: StringName) -> String:
	match act:
		&"gezgin_yardim":
			RunManager.pending_boons.append(&"extra_q")
			return "Gezgin yarasını sardığın için minnettar: \"Kurdun dilini bilirim — sorularını keskinleştir.\"\n→ Sonraki köyde her gün +1 SORGU hakkı."
		&"gezgin_gec":
			RunManager.coins += 10
			return "Geçerken patikada düşmüş küçük bir kese buldun.\n→ +10 altın."
		&"mezar_kaz":
			if _rng.randf() < 0.6:
				RunManager.coins += 40
				return "Toprağın altından eski gümüş takılar çıktı. Mezarın sahibi sesini çıkarmadı...\n→ +40 altın."
			return "Kazdıkça toprak soğudu, rüzgâr uğuldadı. Bir şey bulamadan elin boş döndün.\nEnsende hâlâ bir bakış hissediyorsun."
		&"mezar_gec":
			RunManager.coins += 5
			return "Taşı bırakırken mezarın dibinde parlayan bir sikke gördün — hediye sayılır.\n→ +5 altın."
		&"fal_bak":
			RunManager.pending_boons.append(&"reveal_omen")
			return "Kadın boncukları savurdu, gözleri kaydı: \"Gördüm... lanetin oturduğu deseni gördüm.\"\n→ Sonraki köyde GİZLİ KURAL baştan bilinir."
		&"fal_gec":
			return "Çadırdan uzaklaşırken arkandan güldü: \"İnanmayanın yolu uzun olur evlat.\""
		&"adak_sun":
			var pool: Array = []
			for id in RunManager.PASSIVES:
				if not RunManager.has_passive(id):
					pool.append(id)
			if pool.is_empty():
				RunManager.coins += 25
				return "Sunak adağını geri itti — sende zaten her muska var.\n→ Paran iade edildi."
			var id: StringName = pool[_rng.randi() % pool.size()]
			RunManager.owned_passives.append(id)
			return "Mumlar kendiliğinden yandı; sunağın üstünde bir muska belirdi:\n→ %s — %s" % [
				RunManager.PASSIVES[id]["name"], RunManager.PASSIVES[id]["desc"]]
		&"dua_et":
			RunManager.pending_boons.append(&"extra_day")
			return "Dua bitince rüzgâr durdu; içine bir ferahlık yayıldı.\n→ Sonraki köyde +1 ŞAFAK (gün sınırı)."
		&"kuzu_ara":
			if _rng.randf() < 0.5:
				RunManager.coins += 25
				return "Kuzuyu bir çalının dibinde titrerken buldun. Çocuğun ailesi minnettar:\n→ +25 altın ödül."
			return "Çalıların arasında yalnız ısıran bir soğuk ve tüy yumakları buldun...\nKuzudan iz yok. Çocuğa bakamadan yürüdün."
		&"kuzu_gec":
			RunManager.coins += 8
			return "Yürürken yol üstünde birinin düşürdüğü birkaç sikke buldun.\n→ +8 altın. (Çocuğun ağlaması kulağında.)"
		&"yangin_sondur":
			RunManager.pending_boons.append(&"extra_q")
			return "Alevleri birlikte söndürdünüz. Değirmenci soluk soluğa teşekkür etti:\n\"Ben her şeyi duyarım çoban — kurtların dedikodusunu sana taşırım.\"\n→ Sonraki köyde her gün +1 SORGU hakkı."
		&"yangin_izle":
			RunManager.coins += 15
			return "Kalabalık yangına koşarken düşen bir kese senin oldun.\n→ +15 altın. (Değirmen artık kül.)"
	return ""


func _continue() -> void:
	if RunManager.has_active_run() \
			and RunManager.current_node().get("type", -1) == Enums.NodeType.EVENT:
		RunManager.on_stop_completed()
	Fader.change_scene("res://scenes/run_map.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER) and _chosen:
			_continue()


func _label(pos: Vector2, fsize: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l
