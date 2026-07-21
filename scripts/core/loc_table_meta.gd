class_name LocTableMeta
extends RefCounted

## Yerelleştirme tablosu (meta modülü). Loc autoload'u _ready'de birleştirir.
## Biçim: "anahtar": {"tr": "...", "en": "..."} — % yer tutucuları korunur.
## Kapsam: harita/menü, dükkân, olay, sonuç, kurallar, kodeks, ayarlar, boot,
## duraklat menüsü, muskalar (PASSIVES) ve boss adları.

const T := {
	# ---- Ortak ----
	"ui_back": {"tr": "Geri (Esc)", "en": "Back (Esc)"},
	"ui_coins": {"tr": "Para: %d", "en": "Coins: %d"},
	"menu_rules": {"tr": "Kurallar", "en": "Rules"},
	"menu_chars": {"tr": "Karakterler", "en": "Characters"},
	"menu_settings": {"tr": "Ayarlar", "en": "Settings"},

	# ---- Harita / ana menü (run_map) ----
	"game_title": {"tr": "KOYUN POSTU", "en": "WOLF IN WOOL"},
	"game_tagline": {
		"tr": "Gündüz sorgula · gece kurt avlanır · kanıt her zaman tutar",
		"en": "Question by day · the wolf hunts by night · the proof always holds",
	},
	"map_title_run": {"tr": "SEFER", "en": "THE JOURNEY"},
	"map_title_daily": {"tr": "GÜNÜN SEFERİ", "en": "TODAY'S JOURNEY"},
	"map_daily_sub": {
		"tr": "Tarih tohumlu — bugün herkes aynı köyleri oynuyor",
		"en": "Date-seeded — everyone walks the same villages today",
	},
	"map_asc_sub": {"tr": "Çile %d", "en": "Ordeal %d"},
	"map_stop_line": {
		"tr": "Durak %d / %d%s   ·   Para: %d   ·   Skor: %d",
		"en": "Stop %d / %d%s   ·   Coins: %d   ·   Score: %d",
	},
	"map_charms": {"tr": "Muskalar: ", "en": "Charms: "},
	"btn_enter_shop": {"tr": "Dükkâna Gir (Enter)", "en": "Enter the Shop (Enter)"},
	"btn_enter_event": {"tr": "Ne Var Orada? (Enter)", "en": "What's Out There? (Enter)"},
	"btn_enter_boss": {"tr": "Alfa Sürüsüne Gir (Enter)", "en": "Face the Alpha Pack (Enter)"},
	"btn_enter_flock": {"tr": "Sürüye Gir (Enter)", "en": "Join the Flock (Enter)"},
	"btn_new_run": {"tr": "Yeni Sefer (Enter)", "en": "New Journey (Enter)"},
	"btn_daily": {"tr": "Günün Seferi", "en": "Daily Journey"},
	"btn_cases": {"tr": "Vakalar", "en": "Cases"},
	"cases_title": {"tr": "VAKA DOSYALARI", "en": "CASE FILES"},
	"cases_sub": {
		"tr": "El yapımı, sabit tohumlu senaryolar — herkes aynı bulmacayı çözer. Y: yüzleştirme · H: hipotez.",
		"en": "Handcrafted, fixed-seed scenarios — everyone solves the same puzzle. Y: confront · H: hypothesis.",
	},
	"cases_close": {"tr": "Kapat", "en": "Close"},
	"case_herb_name": {"tr": "VAKA I — Otacının Yemini", "en": "CASE I — The Herbalist's Oath"},
	"case_herb_desc": {"tr": "İlk şifa köyü: son sorgunu silaha çevir.", "en": "The first healing village: turn your last question into a weapon."},
	"case_quiet_name": {"tr": "VAKA II — Sessiz Şafak", "en": "CASE II — The Quiet Dawn"},
	"case_quiet_desc": {"tr": "Gözcü sayar, Seyyah gezer — kim gerçek?", "en": "The Watcher counts, the Wayfarer roams — who is real?"},
	"case_trails_name": {"tr": "VAKA III — Karda İzler", "en": "CASE III — Trails in the Snow"},
	"case_trails_desc": {"tr": "Sisli gece + Tazı burnu: yönlerden nirengi kur.", "en": "Foggy night + the Hound's nose: triangulate from directions."},
	"case_prowl_name": {"tr": "VAKA IV — Sinsi", "en": "CASE IV — The Prowler"},
	"case_prowl_desc": {"tr": "Sayımlarda fazladan bir gölge var. Kimin gölgesi?", "en": "There is one shadow too many in the counts. Whose?"},
	"case_moody_name": {"tr": "VAKA V — Dönek Alfa", "en": "CASE V — The Fickle Alpha"},
	"case_moody_desc": {"tr": "Av kuralı gece gece değişir — cesetleri ona göre oku.", "en": "The hunt rule flips night by night — read the corpses accordingly."},
	"map_asc_btn": {"tr": "Çile: %d", "en": "Ordeal: %d"},
	"map_run_done_title": {"tr": "SEFER TAMAMLANDI!", "en": "JOURNEY COMPLETE!"},
	"map_run_done_sub": {
		"tr": "Alfa sürüsü alt edildi — yeni çile açıldı: Çile %d",
		"en": "The alpha pack is slain — a new ordeal opens: Ordeal %d",
	},
	"map_total_line": {
		"tr": "Toplam skor: %d   ·   Para: %d",
		"en": "Total score: %d   ·   Coins: %d",
	},
	"map_run_lost_title": {"tr": "SEFER DÜŞTÜ", "en": "THE JOURNEY IS LOST"},
	"map_run_lost_sub": {
		"tr": "Sürü kurtlara yem oldu. Tekrar dene.",
		"en": "The flock fell to the wolves. Try again.",
	},
	"map_records": {
		"tr": "REKORLAR   ·   Sefer: %d   ·   Köy: %d   ·   En iyi skor: %d   ·   En yüksek: A%d",
		"en": "RECORDS   ·   Journeys: %d   ·   Villages: %d   ·   Best score: %d   ·   Highest: A%d",
	},
	"map_records_today": {"tr": "   ·   Bugün: %d", "en": "   ·   Today: %d"},
	"map_seed_placeholder": {"tr": "Tohum (arkadaşından)", "en": "Seed (from a friend)"},
	"map_seed_btn": {"tr": "Tohumla Başla", "en": "Start with Seed"},
	"map_seed_invalid": {"tr": "Geçerli bir tohum gir!", "en": "Enter a valid seed!"},

	# ---- Boss adları (RunManager BOSS_SPECS -> config["boss_name"] anahtarı) ----
	"boss_default": {"tr": "ALFA SÜRÜSÜ", "en": "ALPHA PACK"},
	"boss_hungry": {"tr": "AÇ ALFA", "en": "HUNGRY ALPHA"},
	"boss_shadow": {"tr": "GÖLGE SÜRÜSÜ", "en": "SHADOW PACK"},
	"boss_impatient": {"tr": "SABIRSIZ ALFA", "en": "RESTLESS ALPHA"},
	"boss_moody": {"tr": "DÖNEK ALFA", "en": "FICKLE ALPHA"},
	"miniboss_howl": {"tr": "İLK ULUMA", "en": "FIRST HOWL"},
	"miniboss_shadow": {"tr": "PUSUDAKİ GÖLGE", "en": "LURKING SHADOW"},

	# ---- Perdeler / elit köy / rol draft'ı / Sonsuz Sürü ----
	"act_line": {"tr": "Perde %d — %s", "en": "Act %d — %s"},
	"act_meadow": {"tr": "Yayla", "en": "The Meadow"},
	"act_valley": {"tr": "Vadi", "en": "The Valley"},
	"act_forest": {"tr": "Kara Orman", "en": "The Dark Forest"},
	"act_endless": {"tr": "Sonsuz Sürü", "en": "The Endless Flock"},
	"btn_enter_elite": {"tr": "ELİT Köye Gir (Enter)", "en": "Enter the ELITE Village (Enter)"},
	"btn_skip_elite": {"tr": "Elit köyü atla (ödülsüz)", "en": "Skip the elite village (no reward)"},
	"elite_hint": {
		"tr": "ELİT KÖY: daha zorlu — ama kazanana bedava muska.",
		"en": "ELITE VILLAGE: harder — but the winner earns a free charm.",
	},
	"elite_reward_line": {"tr": "Elit ödülü: %s", "en": "Elite reward: %s"},
	"draft_title": {"tr": "SÜRÜYE YENİ KAN", "en": "NEW BLOOD FOR THE FLOCK"},
	"draft_sub": {
		"tr": "Bir rol seç — sefer destene katılsın; sonraki köylerde görünebilir.",
		"en": "Pick a role to join your journey deck; it may appear in later villages.",
	},
	"draft_skip": {"tr": "Geç (rol ekleme)", "en": "Pass (add none)"},
	"endless_btn": {"tr": "SONSUZ SÜRÜ — devam et", "en": "ENDLESS FLOCK — keep going"},

	# ---- Köye giriş kartı (village_board intro) ----
	"intro_elite_badge": {
		"tr": "ELİT KÖY — kazanana bedava muska",
		"en": "ELITE VILLAGE — a free charm for the winner",
	},
	"intro_comp": {"tr": "%d koyun · %d parya · %d kurt", "en": "%d sheep · %d outcast · %d wolves"},
	"intro_kills": {"tr": " · gecede %d av", "en": " · %d kills a night"},
	"intro_foggy": {"tr": " · SİSLİ GECE (kurt en uzağı avlar)", "en": " · FOGGY NIGHT (the wolf hunts the farthest)"},
	"intro_skip": {"tr": "tık ya da tuş — geç", "en": "click or press a key — skip"},
	# Köy girişinde gece trafiği rolü öğretileri (ilk bakışta tek cümle).
	"intro_herb": {"tr": "🌿 OTACI köyde: günün SON sorgusu gece onun şifa hedefi olur", "en": "🌿 A HERBALIST lives here: your LAST question marks their night visit"},
	"intro_watcher": {"tr": "👁 GÖZCÜ köyde: her şafak komşularının ziyaret sayısını bedava söyler", "en": "👁 A WATCHER lives here: each dawn they report their neighbors' visits, free"},
	"intro_wanderer": {"tr": "🚶 SEYYAH köyde: her gece saat yönündeki en yakın canlıya misafir olur", "en": "🚶 A WAYFARER lives here: each night they guest at the nearest living neighbor clockwise"},
	"intro_hound": {"tr": "🐕 TAZI köyde: her şafak katilin geliş yönünü koklar", "en": "🐕 A HOUND lives here: each dawn it sniffs out the killer's approach"},
	# Başarım adları (SaveManager.ACH_IDS ile eşleşir).
	"ach_first_wolf_name": {"tr": "İlk Post", "en": "First Pelt"},
	"ach_flawless_name": {"tr": "Tek Yara Almadan", "en": "Not a Scratch"},
	"ach_quiet_dawn_name": {"tr": "Sessiz Şafak", "en": "Quiet Dawn"},
	"ach_hypo_proof_name": {"tr": "Olmayana Ergi", "en": "Proof by Contradiction"},
	"ach_confront_name": {"tr": "Gözünün İçine Bak", "en": "Look Them in the Eye"},
	"ach_trap_name": {"tr": "Kapan Kurdu", "en": "The Trap Snaps"},
	"ach_run_won_name": {"tr": "Sürü Kurtuldu", "en": "The Flock Endures"},
	"ach_case_name": {"tr": "Dosya Kapandı", "en": "Case Closed"},
	"map_records_meta": {
		"tr": "Başarım: %d/%d   ·   Yüzleştirme: %d   ·   Sessiz şafak: %d",
		"en": "Achievements: %d/%d   ·   Confrontations: %d   ·   Quiet dawns: %d",
	},

	# ---- Köy modifier'ları (İLAN edilir — HUD sol menü) ----
	"mod_silent": {"tr": "SUSKUN SÜRÜ: herkes yalnız 1 ifade verir", "en": "SILENT FLOCK: everyone gives only 1 statement"},
	"mod_blood_moon": {"tr": "KANLI AY: gecede 2 av · günde +1 sorgu", "en": "BLOOD MOON: 2 kills a night · +1 question a day"},
	"mod_drought": {"tr": "KURAKLIK: yanlış avlama −7 can", "en": "DROUGHT: a wrong cull costs 7 health"},
	"mod_prowler": {"tr": "SİNSİ KURT: en küçük no'lu canlı kurt her gece EN ÇOK sorgulanana sürtünür (iz bırakır, öldürmez)", "en": "PROWLER: the lowest-numbered living wolf brushes past the MOST-questioned each night (leaves traces, no kill)"},
	"mod_moody": {"tr": "DÖNEK ALFA: TEK günler en yakını, ÇİFT günler en uzağı avlar", "en": "FICKLE ALPHA: hunts the nearest on ODD days, the farthest on EVEN days"},

	# ---- Dükkân (shop) ----
	"shop_title": {"tr": "DÜKKÂN", "en": "THE SHOP"},
	"shop_sub": {
		"tr": "Sefer boyu kalıcı muskalar. Para ile al, sonra sürüye devam et.",
		"en": "Charms that last the whole journey. Buy with coin, then walk on with the flock.",
	},
	"shop_continue": {"tr": "Sürüye Devam (Enter)", "en": "Back to the Flock (Enter)"},
	"shop_owned_btn": {"tr": "SAHİPSİN", "en": "OWNED"},
	"shop_buy": {"tr": "Al  ·  %d ₿", "en": "Buy  ·  %d ₿"},
	"shop_owned_label": {"tr": "Muskaların: ", "en": "Your charms: "},
	"shop_none": {"tr": "yok", "en": "none"},
	"shop_charms_title": {
		"tr": "MUSKALAR — sefer boyu kalıcı",
		"en": "CHARMS — last the whole journey",
	},
	"shop_boons_title": {
		"tr": "AZIKLAR — yalnız SONRAKİ köyde geçerli",
		"en": "PROVISIONS — for the NEXT village only",
	},
	"shop_reroll": {"tr": "Yeniden Karıştır · %d ₿", "en": "Reshuffle · %d ₿"},
	"shop_bought": {"tr": "ALINDI", "en": "BOUGHT"},
	"shop_pending_boons": {"tr": "Azığın (sonraki köy): ", "en": "Provisions (next village): "},
	"shop_draft_name": {"tr": "YENİ KAN", "en": "NEW BLOOD"},
	"shop_draft_desc": {
		"tr": "Sefer destene yeni bir rol kat — 3 aday arasından seç.",
		"en": "Add a new role to your journey deck — pick from 3 candidates.",
	},
	"shop_draft_empty": {
		"tr": "Katılabilecek rol kalmadı — deste dolu.",
		"en": "No roles left to join — the deck is full.",
	},

	# ---- Azıklar (RunManager.BOONS — boon_name/desc yardımcıları çözer) ----
	"boon_extra_q_name": {"tr": "Tuz Torbası", "en": "Salt Pouch"},
	"boon_extra_q_desc": {
		"tr": "Sonraki köyde her gün +1 sorgu hakkı.",
		"en": "+1 question every day in the next village.",
	},
	"boon_extra_day_name": {"tr": "Kandil Yağı", "en": "Lamp Oil"},
	"boon_extra_day_desc": {
		"tr": "Sonraki köyde +1 şafak (fazladan bir gün).",
		"en": "+1 dawn in the next village (an extra day).",
	},
	"boon_reveal_omen_name": {"tr": "Yıldız Haritası", "en": "Star Chart"},
	"boon_reveal_omen_desc": {
		"tr": "Sonraki köyde Gizli Kural baştan açık.",
		"en": "The Hidden Rule is known from the start in the next village.",
	},

	# ---- Köy içi sorgu satın alma (HUD para pulu) ----
	"buyq_tip": {"tr": "Sorgu satın al — %d ₿ (fiyat her alışta artar)", "en": "Buy a question — %d ₿ (price rises each time)"},
	"buyq_ok": {"tr": "+1 sorgu hakkı (−%d ₿)", "en": "+1 question (−%d ₿)"},
	"buyq_poor": {"tr": "Para yetmiyor — %d ₿ gerek", "en": "Not enough coin — need %d ₿"},

	# ---- Muskalar (RunManager.PASSIVES — passive_name/desc yardımcıları çözer) ----
	"passive_zirh_name": {"tr": "Zırh", "en": "Armor"},
	"passive_zirh_desc": {
		"tr": "Yanlış av −5 yerine −3 can.",
		"en": "A wrong cull costs −3 health instead of −5.",
	},
	"passive_kahin_name": {"tr": "Kâhin Boncuğu", "en": "Seer's Bead"},
	"passive_kahin_desc": {
		"tr": "Gizli Kural her köyde baştan bilinir.",
		"en": "The Hidden Rule is known from the start in every village.",
	},
	"passive_ugur_name": {"tr": "Uğur Böceği", "en": "Lucky Beetle"},
	"passive_ugur_desc": {
		"tr": "Her köyde İLK gün +2 sorgu hakkı.",
		"en": "+2 questions on the FIRST day of every village.",
	},
	"passive_kismet_name": {"tr": "Kısmet Tılsımı", "en": "Fortune Talisman"},
	"passive_kismet_desc": {
		"tr": "Her köy kazancına +30 para.",
		"en": "+30 coins from every village won.",
	},
	"passive_hafiza_name": {"tr": "Hafıza Taşı", "en": "Memory Stone"},
	"passive_hafiza_desc": {
		"tr": "HER gün +1 sorgu hakkı.",
		"en": "+1 question EVERY day.",
	},
	"passive_kalkan_name": {"tr": "Kalkan", "en": "Shield"},
	"passive_kalkan_desc": {
		"tr": "Her köyde İLK yanlış av hasarsız (bir kez).",
		"en": "The FIRST wrong cull in each village deals no damage (once).",
	},
	"passive_pusula_name": {"tr": "Pusula", "en": "Compass"},
	"passive_pusula_desc": {
		"tr": "Her köyde İLK gece kurt avlanamaz (bir şafak kazan).",
		"en": "On the FIRST night of each village the wolf cannot hunt (gain a dawn).",
	},
	"passive_kutsama_name": {"tr": "Kutsama Suyu", "en": "Blessed Water"},
	"passive_kutsama_desc": {
		"tr": "Ermiş'i avlarsan felaket olmaz, sadece can cezası.",
		"en": "Culling the Saint is no longer doom — only a health penalty.",
	},
	"passive_bereket_name": {"tr": "Bereket Boynuzu", "en": "Horn of Plenty"},
	"passive_bereket_desc": {
		"tr": "Maksimum can 10 → 12 (her köyde 12 ile başlarsın).",
		"en": "Max health 10 → 12 (you start every village at 12).",
	},
	"passive_cesaret_name": {"tr": "Cesaret Tılsımı", "en": "Courage Talisman"},
	"passive_cesaret_desc": {
		"tr": "Kurt avladığında o gün +1 sorgu hakkı.",
		"en": "+1 question that day whenever you cull a wolf.",
	},
	"passive_sadaka_name": {"tr": "Sadaka Kesesi", "en": "Alms Purse"},
	"passive_sadaka_desc": {
		"tr": "Dükkân fiyatları %25 ucuz.",
		"en": "Shop prices 25% cheaper.",
	},
	"passive_kanli_name": {"tr": "Kanlı Tılsım", "en": "Blood Talisman"},
	"passive_kanli_desc": {
		"tr": "LANETLİ: her gün +1 sorgu hakkı — ama maksimum can −2.",
		"en": "CURSED: +1 question every day — but max health −2.",
	},
	"passive_karakese_name": {"tr": "Kara Kese", "en": "Black Purse"},
	"passive_karakese_desc": {
		"tr": "LANETLİ: köy ödülü +25 para — ama her köye 1 can eksik başlarsın.",
		"en": "CURSED: +25 coins per village won — but you start each village 1 health short.",
	},

	# ---- Olay ekranı (event) ----
	"event_title": {"tr": "OLAY", "en": "EVENT"},
	"event_cant_afford": {"tr": "  (para yetmiyor)", "en": "  (not enough coin)"},
	"event_continue": {"tr": "Yola Devam (Enter)", "en": "Walk On (Enter)"},

	"event_yarali_gezgin_title": {"tr": "YARALI GEZGİN", "en": "WOUNDED WANDERER"},
	"event_yarali_gezgin_desc": {
		"tr": "Patikada bacağı kanayan bir gezgin oturuyor. Gözlerinde korku:\n\"Sürünün oradan geliyorum... İçlerinde KURT var, gördüm. Yaramı sararsan bildiklerimi anlatırım.\"",
		"en": "A wanderer sits on the trail, his leg bleeding, fear in his eyes:\n\"I came past your flock... There is a WOLF among them, I saw it. Bind my wound and I'll tell you what I know.\"",
	},
	"event_yarali_gezgin_c1": {"tr": "Yarasını sar (20 altın)", "en": "Bind his wound (20 gold)"},
	"event_yarali_gezgin_c2": {"tr": "Yoluna devam et", "en": "Walk on"},

	"event_eski_mezarlik_title": {"tr": "ESKİ MEZARLIK", "en": "OLD GRAVEYARD"},
	"event_eski_mezarlik_desc": {
		"tr": "Çalıların ardında çökük mezar taşları. Birinin dibi yeni kazılmış gibi...\nToprağın altından soluk bir parıltı vuruyor. Ama buranın nazarına bulaşmak hayra alamet değil.",
		"en": "Sunken gravestones behind the brush. One looks freshly dug at the base...\nA pale glimmer rises from under the soil. But meddling with this place's evil eye bodes no good.",
	},
	"event_eski_mezarlik_c1": {"tr": "Mezarı kaz", "en": "Dig the grave"},
	"event_eski_mezarlik_c2": {"tr": "Saygıyla geç, bir taş bırak", "en": "Pass with respect, leave a stone"},

	"event_kahin_cadiri_title": {"tr": "KÂHİNİN ÇADIRI", "en": "THE SEER'S TENT"},
	"event_kahin_cadiri_desc": {
		"tr": "Yol kenarında yamalı bir çadır; içeriden tütsü dumanı sızıyor. Yaşlı kadın boncuklarını sayıyor:\n\"Lanetin bir DÜZENİ var evlat. Gümüşünü ver, düzenini söyleyeyim.\"",
		"en": "A patched tent by the road; incense smoke seeps out. An old woman counts her beads:\n\"The curse has a PATTERN, child. Give me your silver and I will name it.\"",
	},
	"event_kahin_cadiri_c1": {"tr": "Fal baktır (15 altın)", "en": "Have your fortune read (15 gold)"},
	"event_kahin_cadiri_c2": {"tr": "\"Boncuğa inanmam\" de, geç", "en": "Say \"I trust no beads\" and pass"},

	"event_kayip_kuzu_title": {"tr": "KAYIP KUZU", "en": "LOST LAMB"},
	"event_kayip_kuzu_desc": {
		"tr": "Yol kenarında ağlayan bir çocuk: \"Kuzum kayboldu... Çalıların oradan kurt sesi geldi.\"\nHava kararmak üzere. Karar senin çoban.",
		"en": "A child weeps by the road: \"My lamb is gone... I heard a wolf in the brush.\"\nDark is falling. Your call, shepherd.",
	},
	"event_kayip_kuzu_c1": {"tr": "Kuzuyu aramaya çık", "en": "Go search for the lamb"},
	"event_kayip_kuzu_c2": {"tr": "\"Üzgünüm evlat\" de, yürü", "en": "Say \"I'm sorry, child\" and walk"},

	"event_degirmen_yangini_title": {"tr": "DEĞİRMEN YANGINI", "en": "MILL FIRE"},
	"event_degirmen_yangini_desc": {
		"tr": "Tepedeki değirmenden duman yükseliyor; değirmenci avazı çıktığı kadar bağırıyor.\nSöndürmek için köyden kova ve bez almak gerek — bedava değil.",
		"en": "Smoke rises from the mill on the hill; the miller is screaming his lungs out.\nDousing it needs buckets and cloth from the village — and they are not free.",
	},
	"event_degirmen_yangini_c1": {"tr": "Malzeme al, yangına koş (15 altın)", "en": "Buy supplies, run to the fire (15 gold)"},
	"event_degirmen_yangini_c2": {"tr": "Uzaktan izle", "en": "Watch from afar"},

	"event_bereket_sunagi_title": {"tr": "BEREKET SUNAĞI", "en": "ALTAR OF PLENTY"},
	"event_bereket_sunagi_desc": {
		"tr": "Dut ağacının altında yosun tutmuş eski bir sunak. Üzerinde kurumuş çiçekler,\nadak mumları... Buraya bir şey bırakanın eli boş dönmediği söylenir.",
		"en": "Beneath the mulberry tree, an old moss-grown altar. Dried flowers upon it,\nvotive candles... They say no one who leaves an offering here goes home empty-handed.",
	},
	"event_bereket_sunagi_c1": {"tr": "Adak sun (25 altın)", "en": "Make an offering (25 gold)"},
	"event_bereket_sunagi_c2": {"tr": "Sessizce dua et", "en": "Pray in silence"},

	# ---- Olay sonuç metinleri (_resolve) ----
	"res_gezgin_yardim": {
		"tr": "Gezgin yarasını sardığın için minnettar: \"Kurdun dilini bilirim — sorularını keskinleştir.\"\n→ Sonraki köyde her gün +1 SORGU hakkı.",
		"en": "The wanderer is grateful you bound his wound: \"I know the wolf's tongue — let me sharpen your questions.\"\n→ +1 QUESTION per day in the next village.",
	},
	"res_gezgin_gec": {
		"tr": "Geçerken patikada düşmüş küçük bir kese buldun.\n→ +10 altın.",
		"en": "Walking on, you found a small dropped purse on the trail.\n→ +10 gold.",
	},
	"res_mezar_kaz_win": {
		"tr": "Toprağın altından eski gümüş takılar çıktı. Mezarın sahibi sesini çıkarmadı...\n→ +40 altın.",
		"en": "Old silver trinkets rose from the soil. The grave's owner made no sound...\n→ +40 gold.",
	},
	"res_mezar_kaz_lose": {
		"tr": "Kazdıkça toprak soğudu, rüzgâr uğuldadı. Bir şey bulamadan elin boş döndün.\nEnsende hâlâ bir bakış hissediyorsun.",
		"en": "The deeper you dug, the colder the soil grew; the wind moaned. You left with nothing.\nYou still feel a gaze on the back of your neck.",
	},
	"res_mezar_gec": {
		"tr": "Taşı bırakırken mezarın dibinde parlayan bir sikke gördün — hediye sayılır.\n→ +5 altın.",
		"en": "As you laid the stone, a coin glinted at the grave's foot — call it a gift.\n→ +5 gold.",
	},
	"res_fal_bak": {
		"tr": "Kadın boncukları savurdu, gözleri kaydı: \"Gördüm... lanetin oturduğu deseni gördüm.\"\n→ Sonraki köyde GİZLİ KURAL baştan bilinir.",
		"en": "The woman cast her beads, her eyes rolled back: \"I saw it... I saw the pattern where the curse sits.\"\n→ The HIDDEN RULE is known from the start in the next village.",
	},
	"res_fal_gec": {
		"tr": "Çadırdan uzaklaşırken arkandan güldü: \"İnanmayanın yolu uzun olur evlat.\"",
		"en": "As you left the tent she laughed behind you: \"Long is the road of the unbeliever, child.\"",
	},
	"res_adak_full": {
		"tr": "Sunak adağını geri itti — sende zaten her muska var.\n→ Paran iade edildi.",
		"en": "The altar pushed your offering back — you already carry every charm.\n→ Your coin was returned.",
	},
	"res_adak_sun": {
		"tr": "Mumlar kendiliğinden yandı; sunağın üstünde bir muska belirdi:\n→ %s — %s",
		"en": "The candles lit themselves; a charm appeared upon the altar:\n→ %s — %s",
	},
	"res_dua_et": {
		"tr": "Dua bitince rüzgâr durdu; içine bir ferahlık yayıldı.\n→ Sonraki köyde +1 ŞAFAK (gün sınırı).",
		"en": "When the prayer ended the wind fell still; an ease spread through you.\n→ +1 DAWN (day limit) in the next village.",
	},
	"res_kuzu_ara_win": {
		"tr": "Kuzuyu bir çalının dibinde titrerken buldun. Çocuğun ailesi minnettar:\n→ +25 altın ödül.",
		"en": "You found the lamb shivering under a bush. The child's family is grateful:\n→ +25 gold reward.",
	},
	"res_kuzu_ara_lose": {
		"tr": "Çalıların arasında yalnız ısıran bir soğuk ve tüy yumakları buldun...\nKuzudan iz yok. Çocuğa bakamadan yürüdün.",
		"en": "In the brush you found only a biting cold and tufts of wool...\nNo trace of the lamb. You walked on, unable to face the child.",
	},
	"res_kuzu_gec": {
		"tr": "Yürürken yol üstünde birinin düşürdüğü birkaç sikke buldun.\n→ +8 altın. (Çocuğun ağlaması kulağında.)",
		"en": "On the road you found a few coins someone had dropped.\n→ +8 gold. (The child's crying stays in your ears.)",
	},
	"res_yangin_sondur": {
		"tr": "Alevleri birlikte söndürdünüz. Değirmenci soluk soluğa teşekkür etti:\n\"Ben her şeyi duyarım çoban — kurtların dedikodusunu sana taşırım.\"\n→ Sonraki köyde her gün +1 SORGU hakkı.",
		"en": "Together you beat down the flames. The miller thanked you, gasping:\n\"I hear everything, shepherd — I'll carry you the wolves' gossip.\"\n→ +1 QUESTION per day in the next village.",
	},
	"res_yangin_izle": {
		"tr": "Kalabalık yangına koşarken düşen bir kese senin oldu.\n→ +15 altın. (Değirmen artık kül.)",
		"en": "A purse dropped by the crowd rushing to the fire became yours.\n→ +15 gold. (The mill is ash now.)",
	},

	# ---- Sonuç ekranı (result) ----
	"result_village_won": {"tr": "SÜRÜ KURTARILDI", "en": "THE FLOCK IS SAVED"},
	"result_village_score": {"tr": "Sürü skoru: %d", "en": "Flock score: %d"},
	"result_coins_awarded": {"tr": "Kazanılan para: +%d", "en": "Coins earned: +%d"},
	"result_run_won": {"tr": "ALFA SÜRÜSÜ ALT EDİLDİ", "en": "THE ALPHA PACK IS SLAIN"},
	"result_last_village": {"tr": "Son köy skoru: +%d", "en": "Final village score: +%d"},
	"result_new_asc": {"tr": "Yeni çile açıldı: Çile %d", "en": "New ordeal unlocked: Ordeal %d"},
	"result_lost_line": {"tr": "Sürü kurtlara yem oldu.", "en": "The flock fell to the wolves."},
	"result_fallback": {"tr": "SONUÇ", "en": "RESULT"},
	"result_continue": {"tr": "Devam (Enter)", "en": "Continue (Enter)"},
	"result_copy": {"tr": "Skoru Kopyala", "en": "Copy Score"},
	"result_copied": {"tr": "Kopyalandı ✔", "en": "Copied ✔"},
	"result_share": {
		"tr": "Skorum: %d · Çile %d · Tohum: %d — Aynı tohumla dene!",
		"en": "My score: %d · Ordeal %d · Seed: %d — Try the same seed!",
	},

	# ---- Kurallar (rules — bbcode iki dilde de korunur) ----
	"rules_title": {"tr": "NASIL OYNANIR", "en": "HOW TO PLAY"},
	"rules_subtitle": {
		"tr": "— kurtlar yalan söyler; cesetler ve kanıt asla —",
		"en": "— wolves lie; the dead and the proof never do —",
	},
	"rules_quote": {
		"tr": "Kurtlar yalan söyler — ama cesetler ve kanıt asla.",
		"en": "Wolves lie — but the dead and the proof never do.",
	},
	"rules_s1_title": {"tr": "Amaç", "en": "The Task"},
	"rules_s1_body": {
		"tr": "Sürüye [color=#b3272d]kurtlar[/color] sızdı — koyun postuna büründüler, sahte rollerle aranızda dolaşıyorlar. Sen çobansın: [b]gündüz sorgula, geceden önce kurtları bul ve avla.[/b] Çünkü her gece kurt, sürüden [color=#b3272d]bir koyun avlar[/color]. [color=#b3272d]10 canın[/color] var; her yanlış av [color=#b3272d]−5 can[/color].",
		"en": "[color=#b3272d]Wolves[/color] have crept into the flock — wrapped in sheep's wool, walking among you under false roles. You are the shepherd: [b]question by day, find the wolves and cull them before nightfall.[/b] For every night the wolf [color=#b3272d]takes a sheep[/color] from the flock. You have [color=#b3272d]10 health[/color]; every wrong cull is [color=#b3272d]−5 health[/color].",
	},
	"rules_s2_title": {"tr": "Gün & Gece Döngüsü", "en": "Day & Night Cycle"},
	"rules_s2_body": {
		"tr": "• [b]GÜNDÜZ:[/b] Günde [color=#e4a72e]3 sorgu hakkın[/color] var. Bir karaktere tıkla → bir ifade verir. [b]Aynı kişiyi tekrar sorgulayabilirsin[/b] — herkesin söyleyecek 2 sözü var.\n• [b]GECE[/b] (GECE butonu ya da G): kurt avlanır, bir koyun ölür. Şafakta sorgu hakların tazelenir.\n• [b]Süre:[/b] Şafak sayısı sınırlı (sol panelde \"Gün X/Y\"). Sürü kurt sayısına inerse ya da şafaklar tükenirse [color=#b3272d]kaybedersin[/color].",
		"en": "• [b]DAY:[/b] You have [color=#e4a72e]3 questions[/color] a day. Click a character → they give one statement. [b]You may question the same one again[/b] — everyone has 2 things to say.\n• [b]NIGHT[/b] (NIGHT button or G): the wolf hunts, a sheep dies. Your questions refresh at dawn.\n• [b]Time:[/b] Dawns are numbered (\"Day X/Y\" on the left panel). If the flock shrinks to the wolves' count, or the dawns run out, [color=#b3272d]you lose[/color].",
	},
	"rules_s3_title": {"tr": "Temel Kural — Yalan & Kanıt", "en": "The Law — Lies & Proof"},
	"rules_s3_body": {
		"tr": "• [color=#8fe0a0]Koyunlar[/color] [b]DAİMA doğru[/b] söyler.\n• [color=#b3272d]Kurtlar[/color] [b]DAİMA yalan[/b] söyler — her ifadesinde! [b]Yalancıyı konuştur:[/b] kurt konuştukça kendini ele verir.\n• [b]Cesetler yalan söylemez:[/b] Av Düzeni bellidir — [i]kurt, kendine en yakın canlı koyunu avlar[/i] (eşitlikte küçük numara). Her ölüm, kurdun YERİ hakkında kesin bir kanıttır. Ölüm yerlerinden kurdu nirengi yap!\n[b]Kanıt her zaman tutar[/b] — her köy, sorgu bütçen içinde saf mantıkla çözülebilir; tahmine mecbur kalmazsın.",
		"en": "• [color=#8fe0a0]Sheep[/color] [b]ALWAYS tell the truth[/b].\n• [color=#b3272d]Wolves[/color] [b]ALWAYS lie[/b] — in every statement! [b]Make the liar talk:[/b] the more a wolf speaks, the more it gives itself away.\n• [b]The dead do not lie:[/b] the Hunt Pattern is known — [i]the wolf takes the living sheep nearest to itself[/i] (lowest seat on a tie). Every death is hard proof of WHERE the wolf sits. Triangulate the wolf from where the bodies fall!\n[b]The proof always holds[/b] — every village can be solved by pure logic within your question budget; you are never forced to guess.",
	},
	"rules_s4_title": {"tr": "Eylemler", "en": "Actions"},
	"rules_s4_body": {
		"tr": "• [b]Sorgula[/b] (sol tık): 1 hak harcar, bir ifade alırsın.\n• [b]İşaretle[/b] (sağ tık ya da 1–5): şüpheni karta not et. ▲iyi ◆şüpheli ✖kurt !soru.\n• [b]Ayıkla[/b] (E, sonra karta tık): kurt sandığını sürüden at. Doğruysa [color=#8fe0a0]✔[/color], yanlışsa [color=#b3272d]−5 can[/color]. Günün her anında yapabilirsin.\n• [b]Günü Bitir[/b] (GECE / G): İLK basış [color=#9db8e8]AĞIL[/color]'ı açar — bir kartı seçip o gece [b]korursun[/b] (kurt onu avlayamaz, en yakın BAŞKA koyunu arar). Korumasız gece için tekrar bas. Koruma da kanıttır: kimi koruduğun kayda geçer, ölümler yine iz bırakır.",
		"en": "• [b]Question[/b] (left click): spends 1 question, you get a statement.\n• [b]Mark[/b] (right click or 1–5): note your suspicion on a card. ▲good ◆suspect ✖wolf !question.\n• [b]Cull[/b] (E, then click a card): cast out the one you take for a wolf. Right: [color=#8fe0a0]✔[/color]; wrong: [color=#b3272d]−5 health[/color]. You can do it at any moment of the day.\n• [b]End Day[/b] (NIGHT / G): the FIRST press opens the [color=#9db8e8]PEN[/color] — pick a card to [b]guard[/b] that night (the wolf cannot take it and seeks the nearest OTHER sheep). Press again for an unguarded night. Guarding is proof too: who you shielded goes on record, and the deaths still leave a trail.",
	},
	"rules_s5_title": {"tr": "Kompozisyon", "en": "Composition"},
	"rules_s5_body": {
		"tr": "Sağ üstte köyde kaç [color=#a9713a]Koyun[/color] · [color=#e4a72e]Parya[/color] · [color=#b3272d]Kurt[/color] · Alfa olduğu baştan yazar. Sürpriz yok — adalet için sayılar bilinir. Kefilli (altın çerçeveli) kartlar [b]kesin iyidir[/b].",
		"en": "The top right shows from the start how many [color=#a9713a]Sheep[/color] · [color=#e4a72e]Outcasts[/color] · [color=#b3272d]Wolves[/color] · Alphas are in the village. No surprises — the numbers are known, for fairness' sake. Vouched (gold-framed) cards are [b]surely good[/b].",
	},
	"rules_s6_title": {"tr": "Özel Roller", "en": "Special Roles"},
	"rules_s6_body": {
		"tr": "• [color=#e4a72e]Müneccim[/color]: sorgularsan [b]Gizli Kural[/b]'ı öğrenirsin.\n• [color=#e4a72e]Kılıççı[/color] (aktif, tek kullanım): karta tıkla → hedef seç; [b]Alfa Kurt[/b] ise ölür, değilse boşa gider.\n• [color=#e4a72e]Avcı[/color] (aktif, tek kullanım): hedefi vurur — herhangi bir [b]kurt[/b] ise ölür, [b]koyun[/b] vurursan −3 can.",
		"en": "• [color=#e4a72e]Stargazer[/color]: question them and you learn the [b]Hidden Rule[/b].\n• [color=#e4a72e]Swordsman[/color] (active, one use): click the card → pick a target; if it is the [b]Alpha Wolf[/b] it dies, otherwise the blow is wasted.\n• [color=#e4a72e]Hunter[/color] (active, one use): shoots a target — any [b]wolf[/b] dies; shoot a [b]sheep[/b] and it is −3 health.",
	},
	"rules_s7_title": {"tr": "Paryalar (Tuzaklar)", "en": "Outcasts (Traps)"},
	"rules_s7_body": {
		"tr": "• [color=#b3272d]Ermiş[/color]: İYİdir ama [b]avlarsan felaket[/b] — anında kaybedersin. Sakın dokunma.\n• [color=#b3272d]Sarhoş[/color]: iyidir ama kendini köylü sanır; ifadeleri [b]yanlış olabilir[/b]. Köylü gibi görünür — kompozisyon + çelişkiden çöz.",
		"en": "• [color=#b3272d]Saint[/color]: GOOD, yet [b]cull them and it is doom[/b] — you lose at once. Never lay a hand on them.\n• [color=#b3272d]Drunk[/color]: good, but believes himself a villager; his statements [b]may be wrong[/b]. He looks like a villager — solve it from composition + contradiction.",
	},
	"rules_s8_title": {"tr": "Gizli Kural (Omen)", "en": "Hidden Rule (Omen)"},
	"rules_s8_body": {
		"tr": "Kurtların çemberdeki yerleşimi gizli bir desene uyar (tek/çift parite · aynalı · dağınık · bitişik yay). Kişiyi değil, [b]deseni[/b] çözersin. Müneccim'i sorgulayınca öğrenirsin.",
		"en": "The wolves' seats on the circle follow a hidden pattern (odd/even parity · mirrored · scattered · adjacent arc). You solve the [b]pattern[/b], not the person. Question the Stargazer to learn it.",
	},
	"rules_s9_title": {"tr": "Sefer & Dükkân", "en": "Journey & Shop"},
	"rules_s9_body": {
		"tr": "Köyleri geç, sonda [color=#b3272d]Alfa sürüsü[/color] boss köyünü yen (gecede [b]2 av[/b]!). Kazanınca [color=#ffd479]para[/color] → [b]dükkânda kalıcı muska[/b] al (Zırh, Pusula, Hafıza Taşı...). [b]Çile[/b] = her seferden sonra açılan zorluk katmanı (daha az sorgu, daha çok kurt, omen zorunlu...).",
		"en": "Pass through the villages, then beat the [color=#b3272d]alpha pack[/color] boss village at the end ([b]2 kills[/b] a night!). Winning earns [color=#ffd479]coin[/color] → buy [b]lasting charms at the shop[/b] (Armor, Compass, Memory Stone...). [b]Ordeal[/b] = the difficulty layer that opens after each journey (fewer questions, more wolves, omen guaranteed...).",
	},
	"rules_s10_title": {"tr": "Skor", "en": "Score"},
	"rules_s10_body": {
		"tr": "Kurt başına +100 · kalan can ×10 · [b]erken bitirme[/b] (kalan şafak ×25) · kurtarılan koyun ×5. Hız ödüllendirilir.",
		"en": "+100 per wolf · remaining health ×10 · [b]finishing early[/b] (remaining dawns ×25) · saved sheep ×5. Speed is rewarded.",
	},

	# ---- Kodeks (codex) ----
	"codex_title": {"tr": "KARAKTERLER", "en": "CHARACTERS"},
	"codex_group_flock": {
		"tr": "SÜRÜ — Bilgi Verenler (İYİ, daima doğru söyler)",
		"en": "THE FLOCK — Informants (GOOD, always truthful)",
	},
	"codex_group_special": {"tr": "ÖZEL & AKTİF", "en": "SPECIAL & ACTIVE"},
	"codex_group_outcasts": {
		"tr": "PARYALAR — İyi ama tuzak (kompozisyonda ilan edilir)",
		"en": "OUTCASTS — Good but treacherous (declared in the composition)",
	},
	"codex_group_wolves": {
		"tr": "KURTLAR — Kötü (koyun postunda, daima yalan)",
		"en": "WOLVES — Evil (in sheep's wool, always lying)",
	},
	"codex_locked_name": {"tr": "??? — Kilitli", "en": "??? — Locked"},
	"codex_locked_desc": {
		"tr": "Bu karakter Çile %d seferlerinde sürüye katılır. Alfa Kurt'u alt edip çileyi yükselt.",
		"en": "This character joins the flock in Ordeal %d journeys. Slay the Alpha Wolf and raise your ordeal.",
	},
	"codex_drunk_name": {"tr": "Sarhoş", "en": "Drunk"},
	"codex_drunk_desc": {
		"tr": "Kendini bir köylü sanır; köylü gibi görünür ama tanıklığı yanlış olabilir. Hangisi olduğu gizli.",
		"en": "Believes himself a villager; looks like one, but his testimony may be wrong. Which one he is stays hidden.",
	},
	"codex_foot": {
		"tr": "Yeni kartlar deste açıldıkça ve çile katmanlarında devreye girer.",
		"en": "New cards enter play as the deck opens and the ordeal layers rise.",
	},

	# ---- Ayarlar (settings) ----
	"settings_title": {"tr": "AYARLAR", "en": "SETTINGS"},
	"settings_master": {"tr": "Ana ses", "en": "Master volume"},
	"settings_music": {"tr": "Müzik", "en": "Music"},
	"settings_sfx": {"tr": "Efektler", "en": "Effects"},
	"settings_fullscreen": {"tr": "Tam ekran", "en": "Fullscreen"},
	"settings_lang_btn": {"tr": "Dil / Language: Türkçe", "en": "Dil / Language: English"},
	"settings_lang_note": {
		"tr": "Arayüz anında değişir; üretilmiş ifadeler yeni köyde İngilizceleşir.",
		"en": "UI changes instantly; generated testimony switches next village.",
	},

	# ---- Boot (açılış sekansı) ----
	# NOT: Uyarı ekranı el yazısı font (CasualHuman) kullanır ve ğ/ı/ş glyph'leri
	# fontta yok — fallback karışık görünüyor. Bu yüzden TR uyarı metinleri BİLEREK
	# ASCII yazılır (sadece bu 4 anahtar; oyun içi metinler normal Türkçe).
	"boot_health_title": {"tr": "SAGLIK UYARISI", "en": "HEALTH WARNING"},
	"boot_health_body": {
		"tr": "Bu oyun yanip sonen goruntuler ve ani isik degisimleri icerebilir.\nNadir de olsa bu goruntuler, isiga duyarli kisilerde epilepsi nobetlerini tetikleyebilir.\nBas donmesi, gorme bozuklugu ya da rahatsizlik hissederseniz oyunu hemen birakin\nve bir hekime danisin.",
		"en": "This game may contain flashing images and sudden changes of light.\nIn rare cases such images can trigger epileptic seizures in light-sensitive people.\nIf you feel dizziness, impaired vision or discomfort, stop playing at once\nand consult a physician.",
	},
	"boot_save_note": {
		"tr": "Bu oyun ilerlemenizi otomatik olarak kaydeder.\nKayit sirasinda uygulamayi kapatmayin.",
		"en": "This game saves your progress automatically.\nDo not close the application while it is saving.",
	},
	"boot_press_key": {
		"tr": "devam etmek icin bir tusa basin",
		"en": "press any key to continue",
	},
	"boot_copyright": {
		"tr": "© 2026 Codezu · Tüm hakları saklıdır",
		"en": "© 2026 Codezu · All rights reserved",
	},

	# ---- Duraklat menüsü (game_menu) ----
	"pause_title": {"tr": "DURAKLADI", "en": "PAUSED"},
	"pause_resume": {"tr": "Devam", "en": "Resume"},
	"pause_fullscreen": {"tr": "Tam Ekran (F11)", "en": "Fullscreen (F11)"},
	"pause_main": {"tr": "Ana Menü", "en": "Main Menu"},
	"pause_quit": {"tr": "Çıkış", "en": "Quit"},
}
