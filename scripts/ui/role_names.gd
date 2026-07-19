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
	&"Astrologer": "Müneccim", # Gizli Kural'ı (Omen) ifşa eder
	&"Slayer": "Kılıççı",      # aktif: bir karta kılıç saplar (İblis'i öldürür)
	&"Hunter": "Avcı",         # aktif: bir kurdu vurur (koyunu vurursan -3 can)
	# Outcast (parya) — iyi ama tuzak.
	&"Saint": "Ermiş",         # arındırırsan felaket
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
