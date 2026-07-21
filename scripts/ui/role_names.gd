class_name RoleNames
extends RefCounted

## Rol id -> oyuncuya görünen ad. Bkz. CLAUDE.md §5.4.
## Tema: sürü (iyi köylüler = koyunlar) vs kurtlar. Kötüler koyun postuna
## bürünür (Demon Bluff "Disguise" = koyun postundaki kurt). Motor tema-agnostik;
## yalnız bu görünen isim katmanı temaya bağlı. M4'te tr/en çeviri tablosuna taşınır.

const TR := {
	# Sürü (Villager) — iyi, doğru söyleyen köylüler.
	&"Judge": "Çoban",         # bir kartın alignment'ını söyler (kurdu koklar)
	&"Confessor": "Vaiz",      # Judge'ın ikizi (farklı ağız)
	&"Oracle": "Falcı Nine",   # iki kartta kaç kurt
	&"Dreamer": "Rüyacı",      # üç kartta kaç kurt
	&"Knight": "Bekçi Köpeği", # komşularında kaç kurt
	&"Sentry": "Nöbetçi",      # Knight ikizi
	&"Scout": "İzci",          # en yakın kurda mesafe
	&"Enlightened": "Yaşlı Koç", # en yakın kurdun yönü
	&"Architect": "Değirmenci", # yay kıyası
	&"Lover": "Âşık",          # iki komşu aynı saftan mı
	&"Gossip": "Dedikoducu",   # iki kart aynı saftan mı
	&"Healer": "Şifacı",       # Judge ailesi: bir kartın nabzını tutar (üçüncü ağız)
	&"Weaver": "Dokumacı",     # Gossip ikizi: iki kart aynı saftan mı
	&"Midwife": "Ebe",         # dört kartta kaç kurt (Oracle=2/Dreamer=3 ailesi)
	&"Milkmaid": "Sütçü Kız",  # ±1 ve ±2 komşuları (4 kart) sayar
	&"Crier": "Tellal",        # saat yönünde önündeki 3 kartı ilan eder
	&"Beekeeper": "Arıcı",     # iki adım ötesindeki iki kartı (±2) bilir
	&"Sheepdog": "Karabaş",    # komşularında kaç kurt (Bekçi ailesi, üçüncü ağız)
	&"Shearer": "Kırkıcı",     # yay kıyası (Değirmenci ailesi)
	&"Drummer": "Davulcu",     # en yakın kurda mesafe (İzci ailesi)
	&"Welldigger": "Kuyucu",   # iki kart aynı saftan mı (Dedikoducu ailesi)
	&"Beadcounter": "Tespihçi", # 4 kartta kurt sayısının PARİTESİ (tek/çift)
	&"Skittish": "Ürkek Kuzu",  # en yakın kurda eşitsizlik (K adımdan uzak/yakın)
	&"Tailor": "Terzi",         # en yakın iki kurdun arası (yerleşim kısıtı)
	&"Mirrorwright": "Aynacı",  # tam karşı koltuğun safı (yalnız çift n)
	&"Trapper": "Tuzakçı",     # aktif: bir koltuğa gecelik kapan kurar
	&"Herbalist": "Otacı",     # V3: gece son sorgulanana şifa taşır (av oradaysa kurtarır)
	&"Watcher": "Gözcü",       # V3: şafakta komşularının ziyaret sayısını raporlar
	&"Wanderer": "Seyyah",     # V3: gece saat yönündeki en yakın canlıya misafir olur
	&"Hound": "Tazı",          # V3.1: şafakta katilin geliş yönünü koklar
	&"Astrologer": "Müneccim", # Gizli Kural'ı (Omen) ifşa eder
	&"Slayer": "Kılıççı",      # aktif: bir karta kılıç saplar (İblis'i öldürür)
	&"Hunter": "Avcı",         # aktif: bir kurdu vurur (koyunu vurursan -3 can)
	# Outcast (parya) — iyi ama tuzak.
	&"Saint": "Ermiş",         # arındırırsan felaket
	&"Jinxed": "Uğursuz",      # İYİ ve doğru söyler; sorgulayana -1 can (nazar)
	&"Baker": "Ekmekçi",
	# Kurtlar (Evil).
	&"Minion": "Kurt",
	&"Demon": "Alfa Kurt",
}

## Bir rolün ne yaptığını anlatan kısa açıklama (kart tooltip'i için, Demon Bluff
## "More Info" kutusunun karşılığı). Oyuncu ilk kez gördüğü rolü anlasın diye.
const ABILITY := {
	&"Judge": "Bir kartın kurt mu koyun mu olduğunu koklayıp söyler.",
	&"Confessor": "Bir kartın içini okur: kurt mu, koyun mu.",
	&"Oracle": "İki kartı işaret eder, kaçının kurt olduğunu söyler.",
	&"Dreamer": "Rüyasında üç kartı görür; kaçının kurt olduğunu bildirir.",
	&"Knight": "İki komşusundan kaçının kurt olduğunu havlar.",
	&"Sentry": "Nöbette; iki komşusundaki kurt sayısını bildirir.",
	&"Scout": "En yakın kurda kaç adım olduğunu ölçer.",
	&"Enlightened": "En yakın kurdun hangi yönde olduğunu sezer.",
	&"Architect": "Çemberin iki yarısındaki kurt sayısını kıyaslar.",
	&"Lover": "İki komşusunun aynı saftan olup olmadığını hisseder.",
	&"Gossip": "İki köylünün aynı saftan olup olmadığını yayar.",
	&"Healer": "Bir kartın nabzını tutar: kurt mu, koyun mu.",
	&"Weaver": "İki köylünün ipliğini dokur: aynı saftan mı, değil mi.",
	&"Midwife": "Dört kartı işaret eder; içlerinden kaçının kurt olduğunu söyler.",
	&"Milkmaid": "Süt yolundaki dört komşusunu (iki yanında ikişer) tanır; kaçının kurt olduğunu söyler.",
	&"Crier": "Saat yönünde önündeki üç kartı ilan eder: kaçı kurt.",
	&"Beekeeper": "İki adım ötesindeki iki kartta kaç kurt olduğunu arılarından duyar.",
	&"Sheepdog": "İki komşusunu koklar; kaçının kurt olduğunu hırlayarak bildirir.",
	&"Shearer": "Yün tartar gibi: çemberin iki yarısındaki kurt sayısını kıyaslar.",
	&"Drummer": "Davulunun yankısından en yakın kurdun kaç adım ötede olduğunu duyar.",
	&"Welldigger": "İki köylünün kuyudaki yansımasına bakar: aynı saftan mı, değil mi.",
	&"Beadcounter": "Tespihini dört kart için çeker: içlerindeki kurt sayısı TEK mi ÇİFT mi, onu söyler (tam sayıyı değil).",
	&"Skittish": "Kurdu tam göremez ama titremesi ölçer: en yakın kurdun kaç adımdan UZAK ya da YAKIN olduğunu söyler.",
	&"Tailor": "Kurtların arasını arşınlar: en yakın iki kurdun çemberde tam kaç adım olduğunu bilir.",
	&"Mirrorwright": "Aynasında yalnız TAM KARŞISINDAKİ koltuğu görür: kurt mu, koyun mu.",
	&"Trapper": "AKTİF (tek kullanım): bir koltuğa gecelik KAPAN kurar. Av o koltuğa düşerse kurban ölmez; saldıran kurt yakalanıp yüzü açılır.",
	&"Herbalist": "GECE: o gün EN SON SORGULANAN kişinin evine şifa taşır. Kurt o eve saldırırsa kurban ÖLMEZ (sessiz şafak). Son sorgunu kime yaptığın artık bir silah.",
	&"Watcher": "ŞAFAK (bedava): iki kapı komşusunun o gece aldığı TOPLAM ziyaret sayısını söyler. Gerçek Gözcü doğru sayar; sahtesi yalan söylemek zorunda.",
	&"Wanderer": "GECE: saat yönündeki en yakın CANLI komşuya misafir olur. Gözcü sayımlarına iz bırakır — evde kalan 'Seyyah' kurttur.",
	&"Hound": "ŞAFAK (bedava): katilin kurbana HANGİ YÖNDEN geldiğini koklar. Ceset + yön = nirengi. Sahte Tazı yön uydurmak zorunda.",
	&"Jinxed": "İYİdir ve hep DOĞRU söyler — ama nazarlıdır: onu her sorgulayışında sürü 1 can kaybeder. Bilgi mi, can mı?",
	&"Astrologer": "Yıldızlara bakar; kurtların Gizli Kural'ını (desenini) açıklar.",
	&"Slayer": "AKTİF (tek kullanım): bir karta kılıç saplar. Alfa Kurt ise ölür, değilse boşa gider.",
	&"Hunter": "AKTİF (tek kullanım): bir kartı vurur. Kurt/Alfa ise ölür; koyun vurursan -3 can.",
	&"Saint": "Kutsanmış masum. İYİdir ama ARINDIRIRSAN felaket olur — sakın dokunma!",
	&"Baker": "Sadık bir köylü; kimliğini doğrular.",
	&"Minion": "Sürüye sızmış bir kurt. Daima yalan söyler.",
	&"Demon": "Sürünün baş belası — Alfa Kurt. Yalan söyler, koyun postunda gizlenir.",
}

# İngilizce tematik adlar (koyun/kurt/Anadolu köyü havası korunur).
const EN := {
	# Sürü (Villager) — iyi, doğru söyleyen köylüler.
	&"Judge": "Shepherd",
	&"Confessor": "Preacher",
	&"Oracle": "Fortune Granny",
	&"Dreamer": "Dreamer",
	&"Knight": "Watchdog",
	&"Sentry": "Night Watch",
	&"Scout": "Tracker",
	&"Enlightened": "Old Ram",
	&"Architect": "Miller",
	&"Lover": "Lovestruck",
	&"Gossip": "Gossip",
	&"Healer": "Healer",
	&"Weaver": "Weaver",
	&"Midwife": "Midwife",
	&"Milkmaid": "Milkmaid",
	&"Crier": "Town Crier",
	&"Beekeeper": "Beekeeper",
	&"Sheepdog": "Sheepdog",
	&"Shearer": "Shearer",
	&"Drummer": "Drummer",
	&"Welldigger": "Welldigger",
	&"Beadcounter": "Bead Counter",
	&"Skittish": "Skittish Lamb",
	&"Tailor": "Tailor",
	&"Mirrorwright": "Mirrorwright",
	&"Trapper": "Trapper",
	&"Herbalist": "Herbalist",
	&"Watcher": "Watcher",
	&"Wanderer": "Wayfarer",
	&"Hound": "Hound",
	&"Astrologer": "Stargazer",
	&"Slayer": "Swordsman",
	&"Hunter": "Hunter",
	# Outcast (parya) — iyi ama tuzak.
	&"Saint": "Saint",
	&"Jinxed": "Jinxed",
	&"Baker": "Baker",
	# Kurtlar (Evil).
	&"Minion": "Wolf",
	&"Demon": "Alpha Wolf",
}

# İngilizce yetenek açıklamaları (tooltip).
const ABILITY_EN := {
	&"Judge": "Sniffs a card and tells whether it is wolf or sheep.",
	&"Confessor": "Reads a card's soul: wolf or sheep.",
	&"Oracle": "Points at two cards and tells how many of them are wolves.",
	&"Dreamer": "Sees three cards in a dream; reports how many are wolves.",
	&"Knight": "Barks out how many of its two neighbors are wolves.",
	&"Sentry": "On watch; reports the wolf count among its two neighbors.",
	&"Scout": "Measures how many steps away the nearest wolf is.",
	&"Enlightened": "Senses which direction the nearest wolf lies in.",
	&"Architect": "Compares the wolf counts in the two halves of the circle.",
	&"Lover": "Feels whether its two neighbors stand on the same side.",
	&"Gossip": "Spreads word on whether two villagers share the same side.",
	&"Healer": "Takes a card's pulse: wolf or sheep.",
	&"Weaver": "Weaves the thread of two villagers: same side or not.",
	&"Midwife": "Points at four cards; tells how many of them are wolves.",
	&"Milkmaid": "Knows the four neighbors on her milk route (two on each side); tells how many are wolves.",
	&"Crier": "Announces the three cards ahead of him clockwise: how many are wolves.",
	&"Beekeeper": "Hears from his bees how many wolves sit among the two cards two steps away.",
	&"Sheepdog": "Sniffs its two neighbors; growls out how many are wolves.",
	&"Shearer": "Like weighing wool: compares the wolf counts in the two halves of the circle.",
	&"Drummer": "Hears from his drum's echo how many steps away the nearest wolf is.",
	&"Welldigger": "Looks at two villagers' reflections in the well: same side or not.",
	&"Beadcounter": "Counts his beads over four cards: says whether the wolf count among them is ODD or EVEN (not the exact number).",
	&"Skittish": "Can't quite see the wolf but its trembling measures: says whether the nearest wolf is FARTHER or CLOSER than K steps.",
	&"Tailor": "Paces out the wolves' gap: knows exactly how many steps apart the two nearest wolves sit on the circle.",
	&"Mirrorwright": "His mirror shows only the seat DIRECTLY OPPOSITE: wolf or sheep.",
	&"Trapper": "ACTIVE (one use): sets a TRAP on a seat for the night. If the hunt lands there, the victim lives; the attacking wolf is caught and unmasked.",
	&"Herbalist": "NIGHT: carries herbs to the house of whoever was QUESTIONED LAST that day. If the wolf strikes that house, the victim LIVES (quiet dawn). Your last question is now a weapon.",
	&"Watcher": "DAWN (free): reports the TOTAL number of visits their two door-neighbors received that night. A real Watcher counts true; a fake one must lie.",
	&"Wanderer": "NIGHT: guests at the nearest LIVING neighbor clockwise. Leaves a trace in the Watcher's counts — a 'Wayfarer' who stays home is a wolf.",
	&"Hound": "DAWN (free): sniffs out which DIRECTION the killer approached the victim from. Corpse + direction = triangulation. A fake Hound must invent a direction.",
	&"Jinxed": "GOOD and always TRUTHFUL — but hexed: every time you question them, the flock loses 1 heart. Knowledge or blood?",
	&"Astrologer": "Reads the stars; reveals the wolves' Hidden Rule (their pattern).",
	&"Slayer": "ACTIVE (one use): drives a sword into a card. If it's the Alpha Wolf, it dies; otherwise the blow is wasted.",
	&"Hunter": "ACTIVE (one use): shoots a card. A wolf/alpha dies; shoot a sheep and lose 3 hearts.",
	&"Saint": "A blessed innocent. GOOD, but CULLING them brings disaster — do not touch!",
	&"Baker": "A loyal villager; vouches for their own identity.",
	&"Minion": "A wolf slipped into the flock. Always lies.",
	&"Demon": "The bane of the flock — the Alpha Wolf. Lies, and hides in sheep's clothing.",
}

static func display(role: StringName) -> String:
	if Loc.lang == "en":
		return EN.get(role, TR.get(role, String(role)))
	return TR.get(role, String(role))

static func ability(role: StringName) -> String:
	if Loc.lang == "en":
		return ABILITY_EN.get(role, ABILITY.get(role, ""))
	return ABILITY.get(role, "")
