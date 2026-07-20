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
	&"Jinxed": "İYİdir ve hep DOĞRU söyler — ama nazarlıdır: onu her sorgulayışında sürü 1 can kaybeder. Bilgi mi, can mı?",
	&"Astrologer": "Yıldızlara bakar; kurtların Gizli Kural'ını (desenini) açıklar.",
	&"Slayer": "AKTİF (tek kullanım): bir karta kılıç saplar. Alfa Kurt ise ölür, değilse boşa gider.",
	&"Hunter": "AKTİF (tek kullanım): bir kartı vurur. Kurt/Alfa ise ölür; koyun vurursan -3 can.",
	&"Saint": "Kutsanmış masum. İYİdir ama ARINDIRIRSAN felaket olur — sakın dokunma!",
	&"Baker": "Sadık bir köylü; kimliğini doğrular.",
	&"Minion": "Sürüye sızmış bir kurt. Daima yalan söyler.",
	&"Demon": "Sürünün baş belası — Alfa Kurt. Yalan söyler, koyun postunda gizlenir.",
}

static func display(role: StringName) -> String:
	return TR.get(role, String(role))

static func ability(role: StringName) -> String:
	return ABILITY.get(role, "")
