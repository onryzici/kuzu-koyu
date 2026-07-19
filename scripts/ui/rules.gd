extends Control

## Kurallar / Nasıl Oynanır ekranı. Ana menüden (sahne) ya da ESC menüsünden
## (overlay) açılır. İçerik tema diliyle (sürü/kurt). Bkz. CLAUDE.md §11, §12.

var overlay_mode := false        ## true: ESC menüsü üstünde açıldı (kapat = queue_free)

const RULES_BBCODE := "[center][font_size=34][color=#e4a72e]NASIL OYNANIR[/color][/font_size][/center]

[color=#e4a72e][font_size=22]Amaç[/font_size][/color]
Sürüye [color=#b3272d]kurtlar[/color] sızdı — koyun postuna büründüler, sahte rollerle aranızda dolaşıyorlar. Sen çobansın: [b]gündüz sorgula, geceden önce kurtları bul ve ayıkla.[/b] Çünkü her gece kurt, sürüden [color=#b3272d]bir koyun avlar[/color]. [color=#b3272d]10 canın[/color] var; her yanlış ayıklama [color=#b3272d]−5 can[/color].

[color=#e4a72e][font_size=22]Gün & Gece Döngüsü[/font_size][/color]
• [b]GÜNDÜZ:[/b] Günde [color=#e4a72e]3 sorgu hakkın[/color] var. Bir karaktere tıkla → bir ifade verir. [b]Aynı kişiyi tekrar sorgulayabilirsin[/b] — herkesin söyleyecek 2 sözü var.
• [b]GECE[/b] (🌙 butonu ya da G): kurt avlanır, bir koyun ölür. Şafakta sorgu hakların tazelenir.
• [b]Süre:[/b] Şafak sayısı sınırlı (sol panelde \"Gün X/Y\"). Sürü kurt sayısına inerse ya da şafaklar tükenirse [color=#b3272d]kaybedersin[/color].

[color=#e4a72e][font_size=22]Temel Kural — yalan & kanıt[/font_size][/color]
• [color=#8fe0a0]Koyunlar[/color] [b]DAİMA doğru[/b] söyler.
• [color=#b3272d]Kurtlar[/color] [b]DAİMA yalan[/b] söyler — her ifadesinde! [b]Yalancıyı konuştur:[/b] kurt konuştukça kendini ele verir.
• [b]Cesetler yalan söylemez:[/b] Av Düzeni bellidir — [i]kurt, kendine en yakın canlı koyunu avlar[/i] (eşitlikte küçük numara). Her ölüm, kurdun YERİ hakkında kesin bir kanıttır. Ölüm yerlerinden kurdu nirengi yap!
[b]Kanıt her zaman tutar[/b] — her köy, sorgu bütçen içinde saf mantıkla çözülebilir; tahmine mecbur kalmazsın.

[color=#e4a72e][font_size=22]Eylemler[/font_size][/color]
• [b]Sorgula[/b] (sol tık): 1 hak harcar, bir ifade alırsın.
• [b]İşaretle[/b] (sağ tık ya da 1–5): şüpheni karta not et. ▲iyi ◆şüpheli ✖kurt !soru.
• [b]Ayıkla[/b] (E, sonra karta tık): kurt sandığını sürüden at. Doğruysa [color=#8fe0a0]✔[/color], yanlışsa [color=#b3272d]−5 can[/color]. Günün her anında yapabilirsin.
• [b]Günü Bitir[/b] (🌙 / G): İLK basış [color=#9db8e8]AĞIL[/color]'ı açar — bir kartı seçip o gece [b]korursun[/b] (kurt onu avlayamaz, en yakın BAŞKA koyunu arar). Korumasız gece için tekrar bas. Koruma da kanıttır: kimi koruduğun kayda geçer, ölümler yine iz bırakır.

[color=#e4a72e][font_size=22]Kompozisyon[/font_size][/color]
Sağ üstte köyde kaç [color=#a9713a]Koyun[/color] · [color=#e4a72e]Parya[/color] · [color=#b3272d]Kurt[/color] · Alfa olduğu baştan yazar. Sürpriz yok — adalet için sayılar bilinir. Kefilli (altın çerçeveli) kartlar [b]kesin iyidir[/b].

[color=#e4a72e][font_size=22]Özel Roller[/font_size][/color]
• [color=#e4a72e]Müneccim[/color]: sorgularsan [b]Gizli Kural[/b]'ı öğrenirsin.
• [color=#e4a72e]Kılıççı[/color] (aktif, tek kullanım): karta tıkla → hedef seç; [b]Alfa Kurt[/b] ise ölür, değilse boşa gider.
• [color=#e4a72e]Avcı[/color] (aktif, tek kullanım): hedefi vurur — herhangi bir [b]kurt[/b] ise ölür, [b]koyun[/b] vurursan −3 can.

[color=#e4a72e][font_size=22]Paryalar (Tuzaklar)[/font_size][/color]
• [color=#b3272d]Ermiş[/color]: İYİdir ama [b]ayıklarsan felaket[/b] — anında kaybedersin. Sakın dokunma.
• [color=#b3272d]Sarhoş[/color]: iyidir ama kendini köylü sanır; ifadeleri [b]yanlış olabilir[/b]. Köylü gibi görünür — kompozisyon + çelişkiden çöz.

[color=#e4a72e][font_size=22]Gizli Kural (Omen)[/font_size][/color]
Kurtların çemberdeki yerleşimi gizli bir desene uyar (tek/çift parite · aynalı · dağınık · bitişik yay). Kişiyi değil, [b]deseni[/b] çözersin. Müneccim'i sorgulayınca öğrenirsin.

[color=#e4a72e][font_size=22]Sefer & Dükkân[/font_size][/color]
Köyleri geç, sonda [color=#b3272d]Alfa sürüsü[/color] boss köyünü yen (gecede [b]2 av[/b]!). Kazanınca [color=#ffd479]para[/color] → [b]dükkânda kalıcı muska[/b] al (Zırh, Pusula, Hafıza Taşı...). [b]Ascension[/b] = her seferden sonra açılan zorluk katmanı (daha az sorgu, daha çok kurt, omen zorunlu...).

[color=#e4a72e][font_size=22]Skor[/font_size][/color]
Kurt başına +100 · kalan can ×10 · [b]erken bitirme[/b] (kalan şafak ×25) · kurtarılan koyun ×5. Hız ödüllendirilir.

[center][color=#a9713a]Kurtlar yalan söyler — ama cesetler ve kanıt asla.[/color][/center]
"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS  # overlay olarak duraklamada da çalışsın
	_build()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_right", 120)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 96)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_size_override("normal_font_size", 17)
	rt.add_theme_constant_override("line_separation", 5)
	rt.add_theme_color_override("default_color", Palette.IVORY)
	rt.text = RULES_BBCODE
	scroll.add_child(rt)

	var back := Button.new()
	back.text = "Geri (Esc)"
	back.add_theme_font_size_override("font_size", 22)
	back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	back.position = Vector2(-260, -76)
	back.size = Vector2(220, 50)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Palette.CRIMSON.darkened(0.4) if st == "normal" else Palette.CRIMSON.darkened(0.2)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(8)
		back.add_theme_stylebox_override(st, sb)
	back.add_theme_color_override("font_color", Palette.IVORY)
	back.pressed.connect(_close)
	add_child(back)


func _close() -> void:
	if overlay_mode:
		queue_free()
	else:
		get_tree().change_scene_to_file("res://scenes/run_map.tscn")


func _unhandled_input(event: InputEvent) -> void:
	# Overlay modda ESC'i GameMenu yönetir (çakışma olmasın); yalnız sahne modunda.
	if overlay_mode:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("120810f2"), true)
