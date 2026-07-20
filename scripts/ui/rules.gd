extends Control

## Kurallar / Nasıl Oynanır ekranı. Ana menüden (sahne) ya da ESC menüsünden
## (overlay) açılır. İçerik tema diliyle (sürü/kurt); bölümler ikonlu panel
## kartlarda, kademeli giriş animasyonuyla belirir. Bkz. CLAUDE.md §11, §12.

var overlay_mode := false        ## true: ESC menüsü üstünde açıldı (kapat = queue_free)

## Bölümler: [ikon, başlık, bbcode gövde]. Panel kartlar bu veriden kurulur.
const SECTIONS := [
	["◎", "Amaç",
		"Sürüye [color=#b3272d]kurtlar[/color] sızdı — koyun postuna büründüler, sahte rollerle aranızda dolaşıyorlar. Sen çobansın: [b]gündüz sorgula, geceden önce kurtları bul ve avla.[/b] Çünkü her gece kurt, sürüden [color=#b3272d]bir koyun avlar[/color]. [color=#b3272d]10 canın[/color] var; her yanlış av [color=#b3272d]−5 can[/color]."],
	["☾", "Gün & Gece Döngüsü",
		"• [b]GÜNDÜZ:[/b] Günde [color=#e4a72e]3 sorgu hakkın[/color] var. Bir karaktere tıkla → bir ifade verir. [b]Aynı kişiyi tekrar sorgulayabilirsin[/b] — herkesin söyleyecek 2 sözü var.
• [b]GECE[/b] (GECE butonu ya da G): kurt avlanır, bir koyun ölür. Şafakta sorgu hakların tazelenir.
• [b]Süre:[/b] Şafak sayısı sınırlı (sol panelde \"Gün X/Y\"). Sürü kurt sayısına inerse ya da şafaklar tükenirse [color=#b3272d]kaybedersin[/color]."],
	["✦", "Temel Kural — Yalan & Kanıt",
		"• [color=#8fe0a0]Koyunlar[/color] [b]DAİMA doğru[/b] söyler.
• [color=#b3272d]Kurtlar[/color] [b]DAİMA yalan[/b] söyler — her ifadesinde! [b]Yalancıyı konuştur:[/b] kurt konuştukça kendini ele verir.
• [b]Cesetler yalan söylemez:[/b] Av Düzeni bellidir — [i]kurt, kendine en yakın canlı koyunu avlar[/i] (eşitlikte küçük numara). Her ölüm, kurdun YERİ hakkında kesin bir kanıttır. Ölüm yerlerinden kurdu nirengi yap!
[b]Kanıt her zaman tutar[/b] — her köy, sorgu bütçen içinde saf mantıkla çözülebilir; tahmine mecbur kalmazsın."],
	["❖", "Eylemler",
		"• [b]Sorgula[/b] (sol tık): 1 hak harcar, bir ifade alırsın.
• [b]İşaretle[/b] (sağ tık ya da 1–5): şüpheni karta not et. ▲iyi ◆şüpheli ✖kurt !soru.
• [b]Ayıkla[/b] (E, sonra karta tık): kurt sandığını sürüden at. Doğruysa [color=#8fe0a0]✔[/color], yanlışsa [color=#b3272d]−5 can[/color]. Günün her anında yapabilirsin.
• [b]Günü Bitir[/b] (GECE / G): İLK basış [color=#9db8e8]AĞIL[/color]'ı açar — bir kartı seçip o gece [b]korursun[/b] (kurt onu avlayamaz, en yakın BAŞKA koyunu arar). Korumasız gece için tekrar bas. Koruma da kanıttır: kimi koruduğun kayda geçer, ölümler yine iz bırakır."],
	["▤", "Kompozisyon",
		"Sağ üstte köyde kaç [color=#a9713a]Koyun[/color] · [color=#e4a72e]Parya[/color] · [color=#b3272d]Kurt[/color] · Alfa olduğu baştan yazar. Sürpriz yok — adalet için sayılar bilinir. Kefilli (altın çerçeveli) kartlar [b]kesin iyidir[/b]."],
	["✧", "Özel Roller",
		"• [color=#e4a72e]Müneccim[/color]: sorgularsan [b]Gizli Kural[/b]'ı öğrenirsin.
• [color=#e4a72e]Kılıççı[/color] (aktif, tek kullanım): karta tıkla → hedef seç; [b]Alfa Kurt[/b] ise ölür, değilse boşa gider.
• [color=#e4a72e]Avcı[/color] (aktif, tek kullanım): hedefi vurur — herhangi bir [b]kurt[/b] ise ölür, [b]koyun[/b] vurursan −3 can."],
	["!", "Paryalar (Tuzaklar)",
		"• [color=#b3272d]Ermiş[/color]: İYİdir ama [b]avlarsan felaket[/b] — anında kaybedersin. Sakın dokunma.
• [color=#b3272d]Sarhoş[/color]: iyidir ama kendini köylü sanır; ifadeleri [b]yanlış olabilir[/b]. Köylü gibi görünür — kompozisyon + çelişkiden çöz."],
	["◉", "Gizli Kural (Omen)",
		"Kurtların çemberdeki yerleşimi gizli bir desene uyar (tek/çift parite · aynalı · dağınık · bitişik yay). Kişiyi değil, [b]deseni[/b] çözersin. Müneccim'i sorgulayınca öğrenirsin."],
	["➤", "Sefer & Dükkân",
		"Köyleri geç, sonda [color=#b3272d]Alfa sürüsü[/color] boss köyünü yen (gecede [b]2 av[/b]!). Kazanınca [color=#ffd479]para[/color] → [b]dükkânda kalıcı muska[/b] al (Zırh, Pusula, Hafıza Taşı...). [b]Çile[/b] = her seferden sonra açılan zorluk katmanı (daha az sorgu, daha çok kurt, omen zorunlu...)."],
	["★", "Skor",
		"Kurt başına +100 · kalan can ×10 · [b]erken bitirme[/b] (kalan şafak ×25) · kurtarılan koyun ×5. Hız ödüllendirilir."],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS  # overlay olarak duraklamada da çalışsın
	_build()


func _build() -> void:
	# Sahne modunda oyunun ortak atmosferi (doku + kıvılcım); overlay'de sade kal.
	if not overlay_mode:
		add_child(ScreenFx.new())

	var title := Label.new()
	title.text = "NASIL OYNANIR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Palette.SAFFRON)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 26
	title.offset_bottom = 78
	add_child(title)
	ScreenFx.slide_in(title, 0.02, Vector2(0, -26))

	var subtitle := Label.new()
	subtitle.text = "— kurtlar yalan söyler; cesetler ve kanıt asla —"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Palette.COPPER.lightened(0.2))
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_top = 80
	subtitle.offset_bottom = 104
	add_child(subtitle)
	ScreenFx.slide_in(subtitle, 0.08, Vector2(0, -18))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 210)
	margin.add_theme_constant_override("margin_right", 210)
	margin.add_theme_constant_override("margin_top", 116)
	margin.add_theme_constant_override("margin_bottom", 96)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	for i in range(SECTIONS.size()):
		var sec: Array = SECTIONS[i]
		var panel := _section_panel(sec[0], sec[1], sec[2])
		vbox.add_child(panel)
		# Konteyner pozisyonu yönettiği için yalnız alfa animasyonu (yarış olmasın).
		panel.modulate.a = 0.0
		var t := panel.create_tween()
		t.tween_interval(0.10 + 0.06 * i)
		t.tween_property(panel, "modulate:a", 1.0, 0.35)

	var quote := Label.new()
	quote.text = "Kurtlar yalan söyler — ama cesetler ve kanıt asla."
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote.add_theme_font_size_override("font_size", 16)
	quote.add_theme_color_override("font_color", Palette.BRONZE.lightened(0.15))
	vbox.add_child(quote)

	var back := Button.new()
	back.text = "Geri (Esc)"
	back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	back.position = Vector2(-260, -76)
	back.size = Vector2(220, 50)
	ScreenFx.style_button(back, Palette.CRIMSON.darkened(0.3), 22)
	back.pressed.connect(_close)
	add_child(back)


## Tek bölüm paneli: ikon + başlık + ayraç + bbcode gövde. Ortak koyu kart stili.
func _section_panel(icon: String, heading: String, body: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.03, 0.045, 0.92)
	sb.set_corner_radius_all(10)
	sb.border_color = Palette.COPPER.darkened(0.25)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(4, 5)
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var head := Label.new()
	head.text = "%s  %s" % [icon, heading]
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", Palette.SAFFRON)
	v.add_child(head)

	var sep := ColorRect.new()
	sep.color = Palette.COPPER.darkened(0.4)
	sep.custom_minimum_size = Vector2(0, 2)
	v.add_child(sep)

	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_size_override("normal_font_size", 17)
	rt.add_theme_constant_override("line_separation", 5)
	rt.add_theme_color_override("default_color", Palette.IVORY)
	rt.text = body
	v.add_child(rt)
	return panel


func _close() -> void:
	if overlay_mode:
		queue_free()
	else:
		Fader.change_scene("res://scenes/run_map.tscn")


func _unhandled_input(event: InputEvent) -> void:
	# Overlay modda ESC'i GameMenu yönetir (çakışma olmasın); yalnız sahne modunda.
	if overlay_mode:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("120810f2"), true)
