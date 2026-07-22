# KARAKTER LİSTESİ — Asset Üretim Rehberi

> Kaynak: `scripts/ui/role_names.gd` (oyundaki güncel kadro) + `scripts/ui/portrait_map.gd`.
> Toplam **38 karakter**: 33 Sürü (iyi) · 3 Parya (iyi ama tuzak) · 2 Kurt (kötü).
> Şu an hepsi placeholder tarot kartlarını paylaşıyor; her rolün KENDİ portresi hedef.

## Teknik şartname

- **Boyut:** 1664×2880 px (mevcut placeholder'larla aynı; dikey portre ~1:1.73).
- **Format:** PNG. Kart çerçevesi/bandı oyun çiziyor — **sadece portre**, yazı/çerçeve ekleme.
- **Kadraj:** Bel üstü / büst portre, karakter merkezde, yüz okunur. Alt üçte-birlik alan rol bandının altında kalabilir — önemli detayı üst 2/3'te tut.
- **Dosya adı:** `assets/art/portraits/` altına küçük harf rol id'siyle: örn. `judge.png`, `herbalist.png`, `demon.png`. (Entegrasyonu ben yaparım, adlar birebir tutarsa tek seferde bağlanır.)

## Sanat yönü (özet — CLAUDE.md §10)

- **Tema:** Anadolu dağ köyü + sürü fantezisi ("koyun postundaki kurt"). Gece, dolunay, kandil ışığı.
- **Stil:** Anadolu minyatürü × modern çizgi roman; düz doygun renkler, ince kontur, hafif doku.
- **Palet:** gece indigo `#1B2A4A`, çini `#2E6E8E`, fildişi `#EDE3C8`, safran `#E4A72E`, bakır `#C9743B`; kötüler için kızıl `#8E1B1B` / kan `#B3272D` / is `#0E0A0A`.
- **Kostüm:** şalvar, cepken, yemeni, entari; bakır/gümüş takılar. Hayvan karakterler (köpek, koç, kuzu, tazı) sürünün doğal üyeleri — antropomorfik ama abartısız.
- **Kurtlar:** portrede İYİ ve masum görünmeli (bluff yapıyorlar!) ama dikkatli bakınca ele veren bir detay: postun altından taşan pençe, gölgede sarı göz, sivri diş ucu. Kızıl vurgu serbest.

---

## SÜRÜ (Villager — iyi, doğru söyler) — 33 adet

| # | id (dosya adı) | TR ad | EN ad | Yeteneği | Portre önerisi |
|---|---|---|---|---|---|
| 1 | `judge` | Çoban | Shepherd | Bir kartın kurt/koyun olduğunu koklar | Asalı, yağmurluklu çoban; keskin bakış |
| 2 | `confessor` | Vaiz | Preacher | Bir kartın içini okur (Çoban ikizi) | Yaşlı hoca/vaiz, tespih, kitap |
| 3 | `oracle` | Falcı Nine | Fortune Granny | 2 kartta kaç kurt olduğunu söyler | Başörtülü nine, fal fincanı/kurşun döküm |
| 4 | `dreamer` | Rüyacı | Dreamer | 3 kartı rüyasında görür | Uykulu genç, yıldızlı yorgan, kapalı gözler |
| 5 | `knight` | Bekçi Köpeği | Watchdog | 2 komşusundaki kurt sayısını havlar | İri çoban köpeği (kangal), çivili tasma |
| 6 | `sentry` | Nöbetçi | Night Watch | Komşu kurt sayısı (Bekçi ikizi) | Fenerli gece bekçisi, kalın aba |
| 7 | `scout` | İzci | Tracker | En yakın kurda mesafe ölçer | Genç izci, yerde iz okur, çarıklı |
| 8 | `enlightened` | Yaşlı Koç | Old Ram | En yakın kurdun yönünü sezer | Kıvrık boynuzlu ak koç, bilge duruş |
| 9 | `architect` | Değirmenci | Miller | Çemberin iki yarısını kıyaslar | Una bulanmış değirmenci, terazi/çuval |
| 10 | `lover` | Âşık | Lovestruck | 2 komşusu aynı saftan mı hisseder | Bağlamalı genç âşık, dalgın |
| 11 | `gossip` | Dedikoducu | Gossip | 2 kart aynı saftan mı yayar | Çene yapan orta yaşlı kadın, kulak kesilmiş |
| 12 | `healer` | Şifacı | Healer | Bir kartın nabzını tutar | Şifalı ot torbalı kadın/adam, el nabızda |
| 13 | `weaver` | Dokumacı | Weaver | 2 kartın ipliğini dokur (aynı saf mı) | Kilim tezgâhında dokumacı, renkli iplikler |
| 14 | `midwife` | Ebe | Midwife | 4 kartta kaç kurt olduğunu söyler | Tecrübeli ebe, kundak/leğen, kararlı yüz |
| 15 | `milkmaid` | Sütçü Kız | Milkmaid | ±1 ve ±2 komşularını (4 kart) tanır | Güğümlü genç kız, süt yolu |
| 16 | `crier` | Tellal | Town Crier | Önündeki 3 kartı ilan eder | Davul/çığırtkan tellal, eli ağzında megafon |
| 17 | `beekeeper` | Arıcı | Beekeeper | ±2'deki 2 kartı arılarından duyar | Peçeli arıcı, kovan ve arılar |
| 18 | `sheepdog` | Karabaş | Sheepdog | Komşularını koklar (Bekçi ailesi) | Kara başlı akbaş köpek, hırlayan |
| 19 | `shearer` | Kırkıcı | Shearer | İki yarıyı kıyaslar (Değirmenci ailesi) | Makaslı yün kırkıcısı, kucağında yün |
| 20 | `drummer` | Davulcu | Drummer | Yankıdan kurda mesafe duyar | Ramazan davulcusu, tokmak havada |
| 21 | `welldigger` | Kuyucu | Welldigger | Kuyu yansımasından 2 kartı okur | Kazmalı kuyucu, kuyu ağzında, yansıma |
| 22 | `beadcounter` | Tespihçi | Bead Counter | 4 karttaki kurt sayısının TEK/ÇİFT'ini söyler | Kehribar tespihli yaşlı, boncuk sayar |
| 23 | `skittish` | Ürkek Kuzu | Skittish Lamb | Kurda "K adımdan uzak/yakın" der | Titreyen minik kuzu, iri ıslak gözler |
| 24 | `tailor` | Terzi | Tailor | En yakın iki kurdun arasını arşınlar | Mezuralı terzi, iğne-iplik |
| 25 | `mirrorwright` | Aynacı | Mirrorwright | Tam karşı koltuğu aynasında görür | El aynalı usta, aynada sarı göz parıltısı |
| 26 | `trapper` | Tuzakçı | Trapper | AKTİF: bir koltuğa gecelik kapan kurar | Çelik kapanlı avcı-tuzakçı, kürk yelek |
| 27 | `herbalist` | Otacı | Herbalist | GECE: son sorgulanana şifa taşır, avı kurtarabilir | Ot demetli şifacı, gece feneri, sepet |
| 28 | `watcher` | Gözcü | Watcher | ŞAFAK: komşularının ziyaret sayısını raporlar | Pencere arkasında perde aralayan meraklı |
| 29 | `wanderer` | Seyyah | Wayfarer | GECE: saat yönündeki en yakın canlıya misafir olur | Heybeli, bastonlu gezgin derviş |
| 30 | `hound` | Tazı | Hound | ŞAFAK: katilin geliş yönünü koklar | İnce yapılı tazı, burnu yerde, iz sürüşte |
| 31 | `astrologer` | Müneccim | Stargazer | Kurtların Gizli Kural'ını (Omen) açıklar | Usturlaplı müneccim, yıldız haritası |
| 32 | `slayer` | Kılıççı | Swordsman | AKTİF: kılıç saplar — Alfa Kurt ise ölür | Kılıcını çekmiş yiğit, kararlı |
| 33 | `hunter` | Avcı | Hunter | AKTİF: bir kartı vurur (koyun vurursan −3 can) | Tüfekli/yaylı dağ avcısı, fişeklik |

## PARYA (Outcast — iyi ama tuzak) — 3 adet

| # | id (dosya adı) | TR ad | EN ad | Yeteneği | Portre önerisi |
|---|---|---|---|---|---|
| 34 | `saint` | Ermiş | Saint | İYİ ama ARINDIRIRSAN felaket | Hâleli, nur yüzlü evliya; dokunulmaz hava |
| 35 | `jinxed` | Uğursuz | Jinxed | Doğru söyler ama sorgulayana −1 can (nazar) | Nazar değmiş solgun köylü, mavi boncuklar, çatlak ayna |
| 36 | `baker` | Ekmekçi | Baker | Kimliğini doğrular (kimlik ankraji) | Una bulanmış fırıncı, taze ekmek, güven veren gülüş |

## KURTLAR (Evil — daima yalan söyler) — 2 adet

| # | id (dosya adı) | TR ad | EN ad | Yeteneği | Portre önerisi |
|---|---|---|---|---|---|
| 37 | `minion` | Kurt | Wolf | Sürüye sızmış kurt; iyi rol bluff'lar | Koyun postuna bürünmüş kurt — postun altından pençe/diş sızar, sarı göz |
| 38 | `demon` | Alfa Kurt | Alpha Wolf | Sürünün baş belası; boss | İri, yaralı-postlu alfa; dolunay fonu, kızıl aura, buğulu nefes |

---

## Notlar

- **Aileler tutarlı olsun:** Aynı yeteneğin "ikizleri" (Çoban/Vaiz/Şifacı · Bekçi Köpeği/Nöbetçi/Karabaş · Değirmenci/Kırkıcı · İzci/Davulcu · Dedikoducu/Dokumacı/Kuyucu) görsel olarak akraba durabilir (benzer renk şeridi vb.) ama karıştırılmayacak kadar farklı olmalı.
- **Kurt bluff'u:** Kurt ve Alfa Kurt portreleri oyunda hiç doğrudan görünmez — kurtlar kartta iyi rol portresiyle gezer; gerçek yüzleri ancak yakalanınca/öldürülünce açılır. Yani bu iki portre "ifşa anı" görselidir, dramatik olabilir.
- Bir portre teslim ettikçe `assets/art/portraits/` altına koyup bana söylemen yeterli — `portrait_map.gd`'yi güncelleyip bağlarım.
