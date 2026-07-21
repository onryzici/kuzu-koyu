# CLAUDE.md — NAZAR

> **Çalışma adı:** NAZAR · **Kod adı:** `nazar` · **Motor:** Godot 4.3+ (GDScript) · **Tür:** Tek oyunculu sosyal çıkarım / roguelike dedüksiyon kart oyunu
>
> Bu doküman Claude Code'un projeyi **mekaniğinden sanat yönetimine kadar** eksiksiz anlaması için yazıldı. Prose Türkçe, tüm kod/dosya/sınıf isimleri İngilizce. Bir şeyi değiştirmeden önce bu dosyayı oku; kararların gerekçeleri burada.

---

## 0. TL;DR (30 saniyede oyun)

Bir Anadolu köyü bir **çember** (ritüel halkası) üzerinde dizili kartlarla temsil edilir. Her kart bir **karakter**tir. Kartı açınca (tıklayınca) karakterin rolü ortaya çıkar ve bir **tanıklık** (ifade) verir. Köylüler doğru söyler; **Lanetliler** (Uşak + İblis) hem iyi bir rol taklidi yapar (bluff) hem de **yalan** söyler. Amacın: kanıtları birleştirip tüm Lanetlileri bulup **arındırmak** (execute). 10 canın var, her yanlış arındırma 5 hasar. 

Demon Bluff'tan **iki büyük eklemeyle** ayrışıyoruz:
1. **Omen (Gizli Kural):** Lanetlilerin çember üzerindeki yerleşimi gizli bir yapısal desene uyar. Bazı roller bu deseni ele verir. Kişiyi değil, **deseni** çözersin.
2. **Spread (Yayılan Köy):** Yeterince hızlı arındırmazsan lanet her turda bir iyi köylüye bulaşır; tahta canlıdır, önceki çıkarımların değişebilir.

Bunların üstüne roguelike bir sefer yapısı (köy→köy→İblis boss), deste kurma, para, açılabilir kartlar, ascension zorluk katmanları oturur.

---

## 0.5 ⚡ V2 PİVOT — "SORGU & GECE" (2026-07-20, GEÇERLİ ÇEKİRDEK)

> **Bu bölüm §3 (döngü), §5.6 (Spread) ve reveal ekonomisini (§7.4) GEÇERSİZ KILAR.**
> Gerekçe: oyun Demon Bluff'a fazla benziyordu (kapalı kart çevir → statik bulmaca).
> Yalan mantığı korunur; moment-to-moment döngü tamamen değişir. Tema: çoban fantezisi —
> gündüz sürüyü sorgula, gece kurt avlanır.

### Yeni çekirdek döngü
1. **Kapalı kart YOK.** Tüm karakterler baştan açık: portre + iddia ettiği rol görünür
   (kurtlar iyi bir rol bluff'lar). Demon Bluff'un flip döngüsü tamamen kaldırıldı.
2. **SORGU ekonomisi.** Günde `q_per_day` (vars. 3) sorgu hakkın var. Bir karakteri
   sorgula → sıradaki ifadesini verir (her karakterin 2 ifadesi var). Aynı karakteri
   tekrar sorgulayabilirsin: kurt HER ifadesinde yalan söyler → **konuştukça kendini
   ele verir** ("yalancıyı konuştur" stratejisi motor kuralından doğar).
3. **GECE: av.** "Günü Bitir" → yaşayan kurt(lar), bilinen deterministik **Av Düzeni**ne
   göre bir koyunu öldürür: *canlı kurtlardan birine çember mesafesi en küçük canlı iyi
   karakter; eşitlikte küçük seat.* Kurban ölür, gerçek rolü açığa çıkar (kesin İYİ).
4. **Cesetler kanıttır.** Av Düzeni bilindiği için her ölüm, kurt konumları üzerine
   YALAN SÖYLEMEYEN bir kısıttır (solver'a `nights` kısıtı) → ölüm yerlerinden kurt
   nirengi yapılır. İki bilgi kanalı: yalan söyleyebilen ifadeler + asla yalan
   söylemeyen cesetler.
5. **Yarış/kayıp:** canlı iyi ≤ canlı kurt olursa VEYA `max_days` şafak dolarsa köy
   düşer. Ayıklama (cull) gün içinde her an yapılabilir; yanlışsa can cezası (aynen).
   Kazanma: tüm kurtlar ayıklandı.

### Matematik garantisi (adalet, §7.3'ün v2 hali)
- Üretici her köyü İKİ kez doğrular:
  a) **Taban teklik:** tüm ifadeler verilmiş sayılırken solver tam 1 dünya bulmalı.
  b) **Bütçe garantisi (bot):** basit bir bot günde `q_per_day` sorguyla (en az
     sorgulanandan başlayarak) oynar, geceler işler; bot `max_days` içinde tekliğe
     ulaşamıyorsa köy REDDEDİLİR. Yani her köy, sorgu bütçesi + gün sınırı içinde
     kesin çözülebilir. Şanssızlıkla kaybedilen köy yoktur.
- Av kuralı TEK yerde: `NightEngine.pick_victim` — hem gerçek gece hem solver kısıtı
  hem bot aynı fonksiyonu kullanır (§18 tek-doğruluk-kaynağı kuralı).

### Korunanlar
Omen (gizli yerleşim kuralı + Müneccim), Anchor, Ermiş/Sarhoş, Kılıççı/Avcı,
kompozisyon ilanı, mark sistemi, sefer/ascension/dükkân/muskalar, solver CSP çekirdeği.
Spread motoru kodda durur ama akışta kullanılmaz (ileride boss varyantı olabilir).

### V2 terimleri
| Terim | Anlam |
|---|---|
| `question(seat)` | 1 sorgu hakkı harca → karakter sıradaki ifadesini verir. |
| `end_day()` | Günü kapat: gece avı çözülür, gün sayacı ilerler, sorgu hakkı tazelenir. |
| `claims` / `given` | Karakterin tüm ifadeleri / şimdiye dek verdiği ifade sayısı. |
| `night_killed` | Gece kurda yem oldu (kesin İYİ; gerçek rolü açık). |
| `Av Düzeni` | Gece kurbanını belirleyen bilinen deterministik kural. |
| `kills_per_night` | Gece başına kurban sayısı (boss: 2). |

---

## 0.7 ⚡ V3 KATMANI — "GECE TRAFİĞİ" (2026-07-21)

> §0.5'in ÜSTÜNE eklenen opsiyonel katman (config bayraklarıyla köy bazında açılır).
> İlham: Feign'in gece ziyaretleri. Bazı karakterler gece başka evlere gider; ziyaret
> kuralları BİLİNEN ve DETERMİNİSTİKTİR (adalet §7.3 — Av Düzeni gibi İLAN edilir).
> Böylece gece hareketliliği, cesetler gibi YALAN SÖYLEMEYEN ikinci bir kanıt kanalıdır.

### Ziyaret modeli (bağımsızlık ilkesi)
Gece TEK anlık görüntüden (akşam çöktüğü andaki durum) çözülür; kimsenin kararı bir
başkasının O geceki kararına bakmaz. Faz sırası sabittir:
1. Herkes hedefini akşam durumundan hesaplar (aşağıdaki kurallar).
2. Kurt avlanır (`pick_victim` — aynen). Saldıran kurt, kurbanın evini ZİYARET etmiş sayılır.
3. TUZAK > ŞİFA önceliği: av kapana denk geldiyse tuzak çalışır; değilse Otacı'nın
   hedefi kurbanla aynıysa kurban KURTULUR (sessiz şafak, ceset yok).
4. Gözcüler sayım yapar; şafakta raporlar düşer.

### Yeni roller
| Rol (id) | Gece kuralı (İLAN edilir) | Kanıt değeri |
|---|---|---|
| Otacı (`Herbalist`) | O gün EN SON SORGULANAN canlı karaktere şifa taşır (kimse yoksa / kendisiyse evde kalır). | Sessiz şafak = "Otacı kurbanın evindeydi" → hem Otacı'nın gerçekliği hem kurt konumu kısıtı. Sorgu SIRASI oyuncunun gece aracına dönüşür (son sorguyla Otacı'yı yönlendir). |
| Gözcü (`Watcher`) | Her şafak, sorgu harcamadan, İKİ kapı komşusunun o gece aldığı TOPLAM ziyaret sayısını raporlar (`VISITOR_COUNT` claim; gün damgalı). | Gerçek Gözcü doğru sayar; kurt-Gözcü raporu YALAN olmak zorunda → her şafak kendini biraz daha ele verir. |
| Seyyah (`Wanderer`) | Her gece saat yönündeki en yakın CANLI karaktere misafir olur. | Gürültü kanalı: sayımları zenginleştirir. Kurt-Seyyah gece evde kalır (kurt avlanır) → sayım açığı onu ele verir. |

### Motor kuralları
- Ziyaretçi kümesi (aday dünya W'de): saldıran kurt(lar) + W'de İYİ olan iddialı
  Otacılar + W'de İYİ olan iddialı Seyyahlar. `NightEngine.visitors_by_house` TEK
  doğruluk kaynağı: gerçek gece, Gözcü raporu üretimi ve solver değerlendirmesi
  ÜÇÜ de bunu kullanır (§18).
- Gece olayı kaydı YALNIZ kamusal girdiler taşır: alive, last_q (o günün son
  sorgusu), iddialı Otacı/Seyyah seat'leri (shown_role kamusaldır), kurban (-1 =
  sessiz), tuzak alanları. Kurtarılan kurbanın KİM olduğu kaydedilmez (sızıntı olmaz).
- `consistent_with_nights` genişler: W'ye göre beklenen sonuç (kurban / tuzak /
  şifa-kurtuluşu) kayıtla birebir örtüşmeli. Sessiz şafak ⇔ W'de iyi bir iddialı
  Otacı'nın hedefi beklenen kurbandı.
- Gözcü raporu `TestimonyType.VISITOR_COUNT` claim'idir (day alanıyla): solver'da
  iyi konuşan → doğru, kurt → yanlış (mevcut simetri). Sahte rapor sayısı kamusal
  aralıktan seçilir (inandırıcılık kuralı) ve seed+gün+seat'ten deterministiktir.
- Sarhoş, ziyaretçi rolleri İDDİA EDEMEZ (Otacı/Gözcü/Seyyah sanamaz) — ziyaret
  çözümü net kalır. Kurtlar bu rolleri bluff'layabilir (bluff havuzuna girerler).
- Bütçe botu gerçek akışı birebir simüle eder: last_q'yu işler, şafak raporlarını
  üretir — üretici garantisi (§0.5) bu katmanla birlikte doğrulanır.

### V3.1 genişlemesi (2026-07-21, ikinci dalga)
- **Tazı (`Hound`, iyi):** şafakta bedava rapor — saldıran kurdun kurbana HANGİ
  YÖNDEN geldiğini söyler (`ATTACKER_DIRECTION` claim; kurban+gün damgalı).
  Ceset konumu + yön = nirengi. Sahte Tazı yön uydurmak zorunda (yalan simetrisi).
- **Sinsi Kurt (`prowler` köy kuralı, İLAN edilir):** sürü davranışı — en küçük
  seat'li CANLI kurt her gece EN ÇOK SORGULANAN canlıya sürtünür (öldürmez, iz
  bırakır). Gözcü sayımlarını gerçek bulmacaya çevirir; kimlik değil hizalama
  bazlı olduğu için solver aday dünyadan hesaplayabilir.
- **Dönek Alfa (`alternating_rule`, İLAN edilir):** av kuralı gece gece değişir —
  TEK günler NEAREST, ÇİFT günler FARTHEST. Olay kaydı geceye işlenen kuralı taşır;
  solver otomatik uyar. Boss varyantı `boss_moody`.
- **Yüzleştirme (`GameState.confront`):** 2 sorgu hakkına, seçilen karakter
  SEÇİLEN HEDEF hakkında konuşur (dinamik `ALIGNMENT_OF`; iyi→doğru, kurt→ters,
  Sarhoş→seed'li %50). Çift başına 1 kez. Bütçe botu KULLANMAZ — adalet garantisi
  yüzleştirmesiz sağlanır, yüzleştirme saf oyuncu avantajıdır. UI: Y + hedef tık.
- **Hipotez modu (UI, board):** H ile bir kart "farz et kurt" işaretlenir; solver
  dünyaları bu varsayımla süzülür, kesinleşen koltuklar kart çevresinde renkli
  halkayla gösterilir (kızıl=kesin kurt, yeşil=kesin koyun). Varsayım hiçbir
  dünyada tutmuyorsa "imkânsız" ilan edilir (bu da kanıttır). Motor değişmez.
- **Vakalar (el yapımı seed'li senaryolar):** harita ekranından seçilen, isimli,
  sabit seed+config bağımsız köyler (`GameState.case_config`). Testler üretilebilirliği doğrular.

---

## 1. Vizyon ve Farklılaşma

### 1.1 Referans: Demon Bluff (ne alıyoruz)
İlham kaynağımız Demon Bluff. Ondan **iskeleti** alıyoruz, taklidini değil:
- Çember dizilim; konumsal bilgi (saat yönü / karşı yön / mesafe / komşuluk).
- Rol taksonomisi: **Villager** (iyi, güvenilir), **Outcast** (iyi ama sorunlu/yanıltıcı), **Minion** (kötü), **Demon** (kötü).
- Kart açma → tanıklık; Lanetli = yalan + bluff.
- Bilinen kompozisyon (kaç köylü/parya/uşak/iblis olduğu baştan bilinir).
- 10 can, hata başına hasar; arındırma (execute) ile kötüyü ele.
- Roguelike sefer: harita, köyler, İblis boss, ascension, skor, para, 100+ açılabilir kart, kozmetikler.
- Oyuncu not/işaret (mark) sistemi.

### 1.2 Bizim iki imza mekaniğimiz (ne ekliyoruz)
- **Omen / Gizli Kural (yapısal meta-kısıt):** Her köyde Lanetlilerin *nerede* oturduğunu bağlayan gizli bir desen vardır (parite, bitişik yay, simetri, gizli renk vb.). Demon Bluff'ta kötünün yeri rastgele; bizde **kural var** ve onu çözmek çekirdek zevk. Tek tek kişiyi değil, tüm veriyi tutarlı kılan tek *deseni* buluyorsun.
- **Spread / Yayılan Köy (dinamik tahta):** Demon Bluff köyleri statiktir. Bizde lanet **deterministik bir kurala göre** her tur bir adım yayılır (örn. en çok Lanetli'ye komşu olan iyi köylü sonraki şafakta lanetlenir). Bu, yarışa dönüştürür, tek köyün oynanışını uzatır ve tekrar oynanabilirliği artırır. Erken köylerde kapalı, ileri köyler/ascension'larda açılır.

> **Tasarım ilkesi (kritik):** Bu iki katman ilk turdan aynı anda açık gelmez; yeni oyuncuyu boğar. **Katmanlı öğretim**: ilk köyler sade (itham + doğrulanmış kart), sonra Omen, en sonda Spread devreye girer. Bkz. §12 Onboarding.

### 1.3 Tema ve kimlik: Anadolu folk-horror ("NAZAR")
Demon Bluff'un cadı-tarot estetiğinden ayrışmak ve kültürel bir kimlik kazanmak için tema **Anadolu halk korkusu**. "Nazar" (kem göz) hem oyunun adı hem lanetin motifi; Demon Bluff'taki kart arkasındaki "göz" bizde **nazar boncuğu**na dönüşür. Köy bir dağ köyü, karakterler halk arketipleri, kötüler Türk folklorundan yaratıklar (Gulyabani, Cin, Alkarısı, Karakoncolos...). Ayrıntı §10 Sanat Yönetimi'nde.

> **Not:** Tema, mekanikten bağımsızdır. Tüm kural motoru tema-agnostiktir; sadece flavor/görsel katmanı "NAZAR"a bağlıdır. Tema değişirse yalnızca §10 ve içerik metinleri değişir, motor değişmez. Bu doküman Anadolu temasını **önerilen** yön olarak alır; kolayca swap edilebilir.

### 1.4 Tasarım sütunları (design pillars)
1. **"Kanıt tutar" hissi:** Her köy saf mantıkla, tahmin olmadan çözülebilir olmalı. Rastlantı asla oyuncuyu cezalandırmamalı.
2. **Yalanı tersine mühendislik:** Yalan rastgele değil sistematik; oyuncu yalandan geriye doğru gerçeği söker.
3. **Desen avı (Omen):** Tekil ipuçlarının üstünde bir üst-katman zekâsı.
4. **Canlı tehdit (Spread):** Zaman baskısı; "çöz" değil "yetiş."
5. **Roguelike derinlik:** Her sefer yeni deste, yeni kural kombinasyonları, kalıcı ilerleme.

---

## 2. Sözlük (Glossary) — tek doğruluk kaynağı

Kod ve dokümanda bu terimleri **birebir** kullan.

| Terim | Anlam |
|---|---|
| `Village` | Tek bir bulmaca/tahta. Bir sefer birden çok köyden oluşur. |
| `Run` | Bir roguelike sefer: sırayla köyler + son İblis boss. |
| `Seat` | Çemberdeki konum (0..N-1, saat yönünde artar). |
| `Card` | Bir Seat'teki karakterin görsel/etkileşim birimi. |
| `Character` | Bir kartın altındaki gerçek kimlik (rol + alignment). |
| `Role` | Karakterin tipi (Oracle, Baker, Gulyabani...). Yeteneği belirler. |
| `Alignment` | `GOOD` veya `EVIL`. |
| `Category` | `VILLAGER` \| `OUTCAST` \| `MINION` \| `DEMON`. |
| `Evil` | `MINION` ∪ `DEMON`. Arındırılması gereken set. |
| `Testimony` | Bir kartın açılınca verdiği ifade (yapısal veri + metin). |
| `Bluff` | Bir Evil'in taklit ettiği görünürdeki (sahte) iyi rol. |
| `Omen` | Evil setinin çember üzerindeki gizli yapısal kuralı. |
| `Spread` | Lanetin her tur deterministik yayılması. |
| `Anchor` | Doğruluğu baştan mühürlü kart (simetriyi kırar). |
| `Reveal` | Kartı açıp rolünü + tanıklığını görmek (bedava). |
| `Execute` / `Cleanse` | Bir kartı arındırmak (commit; yanlışsa hasar). |
| `Mark` | Oyuncunun karta koyduğu renkli not/etiket. |
| `Ascension` | Sefer zorluk katmanı. |
| `Composition` | Köydeki kategori sayıları (örn. 6 villager, 1 outcast, 1 minion, 1 demon). |

---

## 3. Çekirdek Oyun Döngüsü (moment-to-moment)

1. **Köy açılır.** Görev metni: "Find and Execute K Evil Characters (X Minions, 1 Demon)". Kompozisyon rozetleri üstte. Bazı kartlar başta açık (Anchor) olabilir.
2. **Reveal fazı:** Oyuncu kapalı kartlara tıklar → rol + tanıklık görünür. Reveal bedavadır; istediğini açabilir. (İleri modlarda reveal sınırı/etkileşim maliyeti olabilir — bkz. §7.4.)
3. **Dedüksiyon:** Oyuncu tanıklıkları, Anchor'ları, kompozisyonu ve (deşifre edebildiyse) Omen'i birleştirir. Mark sistemiyle hipotez tutar.
4. **Execute fazı:** Oyuncu bir kartı arındırır (dagger/ritüel UI). Kart Evil ise ✔ (Evils killed +1, kartın gerçek yüzü açılır). Good ise ✘ (–5 can, "Ouch!").
5. **(İleri) Spread:** Belirli tetikte (tur sonu / her arındırma sonrası — moda göre) lanet bir adım yayılır; bir iyi kart Evil'e döner, tanıklıkları geçersizleşir/güncellenir.
6. **Köy sonucu:** Tüm Evil arındırıldıysa köy kazanılır (skor + para). Can biterse ya da (Spread modunda) köy tamamen lanetlenirse sefer biter.
7. Harita ekranına dön → sonraki köy / dükkan / olay → en sonda **İblis boss** köyü.

---

## 4. Sefer ve Meta Yapı (macro loop)

- **Run haritası** (bkz. görsel 3): soldan sağa köy düğümleri, sonda İblis boss. Bazı düğümler dükkan/olay/elit olabilir. Doğrusal + hafif dallanma (Slay the Spire benzeri ama daha sade başlayabilir; MVP'de tamamen doğrusal).
- **Ascension:** Sefer bitince bir üst ascension açılır. Her seviye bir zorluk çarpanı ekler (daha büyük köy, daha çok Evil, Omen zorunlu, Spread aktif, daha az Anchor, yanıltıcı Outcast sayısı artışı). Bkz. §7.5 tablo.
- **Deck (deste):** Sefer boyunca hangi karakter rollerinin havuzda olduğunu belirleyen kart destesi (görsel 4 "YOUR DECK"). Köyler bu desteden örneklenir. Köyler arası **draft/upgrade** ile deste büyür/güçlenir.
- **Para (coin) & dükkan:** Köy kazanınca para. Dükkanda yeni kartlar, kart yükseltmeleri, can iksiri, mark yükseltmesi vb.
- **Skor & "All Saved Villages":** Kalıcı istatistik/leaderboard verisi.
- **Meta açılımlar:** 100+ karakter kartı, kozmetikler (kart arkası, çerçeve, portre varyantları), yeni İblisler, yeni Omen tipleri. Görsel 6'daki "Unlocked Cards" koleksiyon ekranı.
- **Modlar:** 
  - **Story/Ascension** (ana): sefer + zorluk tırmanışı.
  - **Daily/Seed:** sabit tohum, herkes aynı bulmaca.
  - **Deckbuilder:** kendi desteni kur, çok aşamalı.
  - **Endless:** sonu olmayan köy zinciri.
  - **Challenges:** özel kısıt senaryoları.
  - MVP yalnızca tek köy + tek kısa sefer içerir; modlar sonraki milestone.

---

## 5. Dedüksiyon Sistemi (oyunun motoru) — DETAY

Bu bölüm **en kritik** bölüm. Kural motoru tema-agnostik, saf GDScript, node'suz ve **headless test edilebilir** olmalı.

### 5.1 Çember ve konumsal kavramlar
- `N` kart, `Seat` 0..N-1, saat yönünde artan. Komşuluk moduler: `left(i) = (i-1) mod N`, `right(i) = (i+1) mod N`.
- **Distance:** iki seat arası çember mesafesi = `min((a-b) mod N, (b-a) mod N)`.
- **Direction:** bir seat'ten en yakın Evil'e yön: `CLOCKWISE` / `COUNTER_CLOCKWISE` / `EQUIDISTANT`.
- **Region:** çember bir eksenle iki yaya bölünebilir ("left side / right side"); Architect gibi roller yaylardaki Evil sayısını karşılaştırır.
- Ölü/arındırılmış kartlar mesafe/komşuluk sayımında **atlanır mı, sayılır mı** — sabit karar: **arındırılmış Evil kartlar sayımdan çıkar; hâlâ kapalı/iyi kartlar sayılır.** (Tutarlılık için tek yerde `BoardTopology` sınıfında.)

### 5.2 Karakter modeli
```
Character:
  seat: int
  role: RoleId              # gerçek rol
  alignment: GOOD | EVIL
  category: VILLAGER | OUTCAST | MINION | DEMON
  bluff_role: RoleId | null # yalnız EVIL'de; oyuncuya görünen sahte rol
  revealed: bool
  executed: bool
```
Oyuncuya kart açılınca **EVIL ise `bluff_role`** görünür (örn. arkada Minion ama kartta "Druid" yazar). Doğru yüz yalnız arındırınca ya da başka bir yetenek ifşa edince görünür.

### 5.3 Tanıklık (Testimony) vocabulary
Her tanıklık hem **yapısal veri** (motorun/çözücünün kullandığı) hem **doğal dil metni** (oyuncuya) taşır. Tanıklık üreten atomik yüklemler (`TestimonyClaim`):

| Claim tipi | Parametre | Örnek metin |
|---|---|---|
| `CLAIM_ROLE` | role | "I am the original Baker" |
| `ALIGNMENT_OF` | target seat, GOOD/EVIL | "#3 is Evil" |
| `IS_ROLE` | target, role | "#5 is the Demon" |
| `COUNT_IN_SET` | seat set, category, n | "Among #1,#2 exactly one is a Demon" |
| `EVIL_COUNT_IN_REGION` | region, cmp | "Left side is more Evil" |
| `NEAREST_EVIL_DIRECTION` | — | "Closest Evil is Counter-clockwise" |
| `NEAREST_EVIL_DISTANCE` | k | "I am 4 cards away from closest Evil" |
| `NEIGHBOR_HAS_EVIL` | count | "One of my neighbors is Evil" |
| `ROLE_PRESENT` | role, bool | "There is a Knight in play" |
| `PAIR_RELATION` | a,b, same/diff | "#1 and #4 share alignment" |
| `SELF_ANCHOR` | — | "As long as you don't die, you win" (flavor/anchor) |

**Doğruluk kuralı:**
- `GOOD` + `VILLAGER` → tanıklık **daima doğru** (ground truth'a göre üretilir).
- `EVIL` → tanıklık **daima yanlış** (ground truth'u ihlal edecek bir claim seçilir) ve bluff_role'a uygun tipte olur.
- `OUTCAST` → role'e özel kuralla (aşağıda). Genelde "iyi ama güvenilmez."

### 5.4 Rol Kataloğu (başlangıç seti)
Roller = **yetenek şablonları**. Aşağıdakiler Demon Bluff'tan uyarlanmış + bizim eklerimiz. Her rol bir `RoleData` Resource'u (§9). Tema isimleri parantez içinde (Anadolu reskin).

**VILLAGER (Good, güvenilir) — bilgi verenler:**
- `Oracle` (Falcı): iki seat söyler, "biri İblis" ya da "birinde Evil var". → `COUNT_IN_SET`.
- `Enlightened` (Derviş): en yakın Evil yönü (CW/CCW/equidistant). → `NEAREST_EVIL_DIRECTION`.
- `Architect` (Mimar): iki yayı kıyaslar, "sol taraf daha Evil". → `EVIL_COUNT_IN_REGION`.
- `Baker` (Ekmekçi): kimlik ankraji; "ben gerçek Baker'ım" (Doppelganger/duplike mekaniği için). → `CLAIM_ROLE`.
- `Hunter` (Avcı / Nişancı): bir seat'i işaretler; o Evil ise sonraki tur otomatik vurur (aktif yetenek). 
- `Knight` (Bekçi): iki komşusundan söz eder; "komşularımdan biri Evil" veya "ikisi de temiz". → `NEIGHBOR_HAS_EVIL`.
- `Witness` (Tanık): bir seat'in **rolünü** doğrular. → `IS_ROLE`.
- `Judge` (Kadı): bir seat'in alignment'ını söyler. → `ALIGNMENT_OF`.
- `Scout` (İzci): mesafe verir; "en yakın Evil'e N kart uzaktayım". → `NEAREST_EVIL_DISTANCE`.
- `Fortune Teller` (Falcı-2): iki seat sorar, "aralarında Evil var mı" (ama bir "Red Herring" iyi kartı ona Evil gibi görünür — klasik BotC twist). 
- `Confessor`, `Dreamer`, `Empress`, `Gemcrafter`, `Knitter`, `Lover`, `Medium`, `Poet`, `Bard`, `Bishop`, `Slayer`, `Rambler`, `Druid`, `Alchemist`, `Jester` — genişleme; her biri yukarıdaki claim tiplerinden birine/kombinasyonuna bağlanır. (İçerik pipeline'ı §9 + §14.)
  - `Slayer` (Kılıççı): aktif — bir seat'e "İblis misin?" der; İblis ise onu öldürür, değilse boşa gider (tek kullanım).
  - `Rambler` (Geveze): çoğu zaman **alakasız/flavor doğru** cümleler ("kanepeyi taksitsiz aldım"); bilgi düşük ama Evil'in bluff'layabileceği güvenli bir rol.
  - `Lover` (Âşık): komşularının alignment'ına dair ilişki bilgisi. → `PAIR_RELATION`.

**VILLAGER — bizim Omen-okur eklerimiz (yeni):**
- `Astrologer` (Müneccim): **Omen kategorisini** ifşa eder ("Lanet parite izler" / "Lanet bitişik yay oluşturur"). Güçlü, o yüzden nadir. → Omen hint.
- `Surveyor` (Kâhya): Omen'in bir parametresini kısmen verir (örn. "eksen #1-#6 arasından geçiyor").

**OUTCAST (Good ama güvenilmez / tuzak):**
- `Drunk` (Sarhoş): kendini bir Villager rolü sanır ama tanıklığı **yanlış olabilir** (aslında Villager değildir). Çözücü için: GOOD ama "doğru söyler" varsayımı **tutmaz**. Kompozisyonda Outcast olduğunun bilinmesi belirsizlik ekler.
- `Mutant` (Uğursuz): açıkça kendi rolünü iddia ederse ceza/patlama tetikler (davranışsal tuzak) — ileri mekanik.
- `Saint` (Ermiş/Evliya): **arındırırsan büyük ceza** (örn. anında sefer sonu ya da ağır hasar). Onu Evil sanıp infaz etmek felakettir; iyi ama "dokunma."

**MINION (Evil):**
- `Twin Minion` (İkiz Cin): iki kopya; biri arındırılınca diğeri hakkında ipucu. 
- `Poisoner` (Zehirci / Alkarısı): komşusundaki iyi kartın tanıklığını **bozar** (o kart iyi olsa da yanlış söyler) — Spread'in mini versiyonu.
- `Minion` (Cin): temel yalancı; iyi rol bluff'lar.

**DEMON (Evil, boss/hedef):**
- `Demon` (Şeytan): temel iblis; yalan + bluff.
- `Pooka` (Congolos): arındırıldığında bir kez "geri teper" (Ouch! — görsel 7): ilk vuruş öldürmez, ekstra bilgi/twist verir.
- `Baa` (Gulyabani, boss): sefer sonu özel iblis; çevresini pasif lanetler (Spread hızlandırıcı).

> Yeni oyuncu için başlangıç köylerinde sadece: Oracle, Judge, Knight, Scout, Enlightened, Architect, Baker (villager) + Minion + Demon + 1 Anchor. Kalanlar deste açıldıkça girer.

### 5.5 Omen (Gizli Kural) — tam spec
Omen, **ground truth Evil setinin** uyduğu yapısal kısıt. Üretici Evil yerleşimini bu kısıta göre seçer; bazı roller (Astrologer/Surveyor) kısmen ifşa eder; oyuncu deşifre edince ekstra bir çözüm kısıtı kazanır.

Omen kategorileri (`OmenType`):
| OmenType | Kısıt | Astrologer metni |
|---|---|---|
| `PARITY` | Tüm Evil aynı pariteli seat'te (hepsi tek ya da hepsi çift). | "Lanet tek/çift seçer." |
| `CONTIGUOUS_ARC` | Tüm Evil kesintisiz bir yay oluşturur. | "Lanet bitişik yayılır." |
| `DISPERSED` | Hiçbir iki Evil komşu değil. | "Lanet dağınıktır." |
| `MIRROR` | Evil seat'leri bir eksene göre simetrik. | "Lanet aynalıdır." |
| `SUIT` | Tüm Evil gizli bir "suit"i paylaşır (açınca görünür renk/sembol). | "Lanet tek renkten gelir." |
| `DEMON_DISTANCE` | İblis, bir landmark'tan (örn. çember üstündeki mühür) tam K seat uzakta. | "İblis mühre K adım." |
| `NONE` | Omen yok (giriş köyleri). | — |

Kurallar:
- Omen **her zaman** ground truth'ta doğrudur (üretim kısıtı).
- Omen gizlidir; oyuncu ancak Astrologer/Surveyor ya da tümdengelimle bulur. Bulunca çözüm uzayını daraltır.
- Zorluk: Omen'i bir role vermek yerine sadece "vardır, bul" da yapılabilir (ileri ascension). MVP'de Omen kapalı; sonra `NONE`→tek tip→çeşitli.

### 5.6 Spread (Yayılan Köy) — tam spec
Deterministik, oyuncunun öngörebileceği kural. Tetik moda göre: `ON_TURN_END` (her execute bir "turn") veya `ON_PASS`.
- Varsayılan kural (`SpreadRule.MOST_ADJACENT`): tetikte, henüz iyi olan kartlar arasında **en çok arındırılmamış Evil'e komşu** olan kart Lanetlenir (beraberlik → saat yönünde ilk). Yeni Lanetli: alignment `EVIL`, category `MINION`, yeni bir bluff + **yeni yanlış tanıklık** üretir; eski (doğru) ifadesi artık geçersiz işaretlenir.
- Alternatif kurallar (ileri): `SPREAD_FROM_DEMON` (İblis'e komşu), `SPREAD_BY_OMEN` (Omen desenini büyütür).
- **Solvability garantisi:** Spread deterministik olduğu için oyuncu geleceği hesaplayabilir; üretici, Spread'i de simüle ederek her tur köyün çözülebilir kaldığını doğrular.
- Kaybetme koşulu (Spread modu): Evil sayısı köyün yarısını geçerse ya da tüm iyi kartlar tükenirse sefer düşer.

### 5.7 Anchor (mühürlü kart)
Simetriyi kırmak ve tek çözüm garantisi için 0..2 kart baştan **doğrulanmış** gelir: "bu kart kesin GOOD" (nadiren "kesin rolü X"). Görsel örneklerdeki gibi bir "confirmed" tohum. Üretici tek çözüm sağlayamıyorsa önce Anchor ekler, sonra yeniden üretir.

### 5.8 Çözülebilirlik (solver) — sözleşme
Motorun kalbi `DeductionSolver`. Girdi: köyün **oyuncuya görünür** durumu (açık roller, tanıklıklar, kompozisyon, Anchor'lar, bilinen Omen). Çıktı: tutarlı tüm alignment atamalarının kümesi.

Çözücü, olası "gizli dünya" atamaları üzerinde kısıt-tatmin (CSP) yapar:
```
Bir aday dünya W geçerlidir ⇔
  - |Evil(W)| == composition.evil_count ve minion/demon dağılımı doğru
  - Her Anchor W'de sağlanır
  - Bilinen Omen (varsa) W'de sağlanır
  - Açılmış her kart için:
      GOOD+VILLAGER  → tanıklığı W'de DOĞRU
      EVIL           → tanıklığı W'de YANLIŞ
      OUTCAST(Drunk) → tanıklık kısıtı UYGULANMAZ (serbest)
      OUTCAST(Saint) → GOOD (Evil olamaz)
  - Kapalı kartlar: rolü bilinmez; alignment serbest (kompozisyon kısıtı altında)
```
- **Tek çözüm:** `solve()` tam olarak 1 geçerli dünya döndürüyorsa köy "belirlenmiş"tir.
- Üretici, üretilen her köyü bu çözücüden geçirir; ≠1 ise Anchor ekler / tanıklık değiştirir / yeniden üretir (bkz. §8).
- Çözücü **oyuncu yardımına** da hizmet eder (opsiyonel "hint" ve "bu hamle güvenli mi" uyarısı — ayarlanabilir zorluk asistanı).

> Performans: N≤12, evil≤4 için kaba kuvvet C(N, evil) kombinasyonları yeterince küçük (≤ birkaç bin). Kapalı kart belirsizliği için: yalnız açık kartlar kısıt üretir; kapalılar kompozisyon kısıtına tabi serbest değişken. Gerekirse bitmask + erken budama.

---

## 6. Can, Hata, Kazanma/Kaybetme
- Başlangıç can: **10/10**. Yanlış execute (Good arındırma) = **−5**. Yani köy başına ~1 hata toleransı.
- Bazı roller/olaylar can iksiri verir; ascension'da max can düşebilir.
- **Köy kazanma:** tüm Evil arındırıldı.
- **Köy kaybetme:** can ≤ 0 **veya** (Spread modu) köy lanetle düştü **veya** Saint'i arındırdın (anında ceza).
- **Sefer kaybetme:** herhangi köyde kaybetmek (veya can havuzu sefer geneli ise havuz bitince).
- Skor: kalan can, hız (kaç turda), kullanılmayan reveal, ascension çarpanı.

---

## 7. Zorluk, Denge, Parametreler

### 7.1 Köy boyutu / kompozisyon (öneri tablosu)
| Aşama | N (kart) | Villager | Outcast | Minion | Demon | Omen | Spread |
|---|---|---|---|---|---|---|---|
| Tutorial | 5 | 4 | 0 | 0 | 1 | NONE | off |
| Erken | 7 | 5 | 0-1 | 1 | 1 | NONE | off |
| Orta | 9 | 6 | 1 | 1 | 1 | tek tip | off |
| Geç | 9-10 | 5-6 | 1-2 | 2 | 1 | çeşitli | on |
| Boss | 10-12 | 6-7 | 1-2 | 2 | 1 (Baa) | çeşitli | on (hızlı) |

### 7.2 Ascension katmanları (öneri)
A1 temel · A2 +1 Outcast · A3 Omen zorunlu · A4 −1 Anchor · A5 Spread on · A6 +1 Minion · A7 Poisoner garantili · A8 daha az reveal ipucu · A9 boss pasifi güçlü · A10 hepsi.

### 7.3 Adalet kuralları (asla ihlal etme)
- Her köy **tümdengelimle tek çözümlü** olmalı (üretici garanti eder).
- Oyuncu, ölmeden önce **her zaman güvenli en az bir bilgi kazanma yolu** bulabilmeli.
- Outcast belirsizliği kompozisyonda **her zaman ilan edilir** (gizli sürpriz Outcast yok — aksi haksız olur).

### 7.4 Reveal ekonomisi
- MVP: tüm kapalı kartlar bedava açılabilir; zorluk yalan/desende.
- İleri: bazı kartlar "kilitli" (komşu açılınca açılır) veya reveal başına küçük risk (ör. Mutant'a dokunma). Opsiyonel.

### 7.5 Mark (işaretleme) sistemi
Görsel 7/8'deki gibi oyuncu kartlara renkli işaret koyar (klavye 1-5): `MARK_GOOD` (yeşil ok), `MARK_SUSPECT` (turuncu), `MARK_EVIL` (kırmızı), `REMOVE`, `MARK_QUESTION` (!). Tamamen oyuncu notu; mekaniğe etkisi yok ama UX için kritik. Kaydedilir (köy state'inde).

---

## 8. Bulmaca Üretici (Generator) — algoritma
`VillageGenerator.generate(config, rng) -> VillageState`:
```
1. Seçim: N, composition (config + ascension'dan), Omen tipi, Anchor sayısı.
2. Alignment yerleşimi:
   - Omen kısıtını sağlayan tüm Evil-seat kombinasyonlarından rng ile bir tanesini seç.
   - Demon ve Minion'ları bu seat'lere ata.
3. Rol ataması:
   - GOOD seat'lere villager/outcast rolleri (config havuzundan, çeşitlilik kuralıyla).
   - EVIL seat'lere gerçek minion/demon rolü + bir bluff_role (bir villager rolü) ata.
4. Tanıklık üretimi (her açılabilir kart için):
   - GOOD villager → ground truth'a göre DOĞRU bir claim (rol tipine uygun).
   - EVIL → ground truth'u ihlal eden YANLIŞ bir claim (bluff_role tipine uygun; "iyi görünsün").
   - Outcast → role kuralına göre (Drunk: rastgele, muhtemelen yanlış; Saint: nötr).
5. Anchor seç: birkaç GOOD kartı "confirmed" işaretle (tercihen çözümü kilitleyecek olanı).
6. Doğrulama: DeductionSolver.solve(görünür durum) çalıştır.
   - Tam 1 çözüm → OK, döndür.
   - >1 çözüm → Anchor ekle veya bir tanıklığı daha bağlayıcı yap → 6'ya dön (max K deneme).
   - 0 çözüm (bug) → assert/log, yeniden üret.
7. (Spread modu) Spread'i sona kadar simüle et; her ara durumda çözülebilirliği doğrula.
8. Seed'i state'e yaz (reproducibility).
```
**Determinizm:** Tüm rastlantı tek bir `RandomNumberGenerator` (seed'li) üzerinden. Aynı seed = aynı köy. Daily mode ve tekrar-oynanabilir testler bunu gerektirir.

---

## 9. Veri Modeli (Godot Resources)
İçerik **type-safe Custom Resource**larla tanımlanır (JSON yerine; editörde düzenlenebilir, `@export`'lu). Her biri `res://data/...` altında `.tres`.

```gdscript
# res://scripts/data/role_data.gd
class_name RoleData
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var flavor: String
@export var category: Category           # enum
@export var claim_type: TestimonyType    # üreteceği tanıklık tipi
@export var is_active: bool = false      # aktif yetenek mi (Hunter/Slayer)
@export var rarity: int = 0
@export var art_portrait: Texture2D
@export var art_frame: FrameStyle
@export var can_be_bluffed: bool = true  # Evil bunu taklit edebilir mi
@export var solver_hook: StringName      # çözücüde hangi kısıt fonksiyonu
```
Diğer Resource'lar: `VillageConfig` (N, composition aralıkları, izinli roller, omen olasılıkları), `OmenData`, `SpreadRuleData`, `AscensionData`, `DeckData` (RoleData listesi), `RunConfig`, `CosmeticData`.

Enum'lar tek dosyada: `res://scripts/core/enums.gd` (`Alignment`, `Category`, `TestimonyType`, `OmenType`, `MarkType`, `GamePhase`).

---

## 10. SANAT YÖNETİMİ (Art Direction) — DETAY

> Bu bölüm Claude Code'un görsel üretim/entegrasyon kararlarını yönlendirir. Tema **önerilen**; motor bağımsız.

### 10.1 Genel dünya
**Anadolu folk-horror.** Bir dağ köyü, gece, dolunay. Sıcak yağ-kandili ışığı vs. soğuk gece indigosu kontrastı. Yerde bir **ritüel mührü** (Demon Bluff'taki pentagram yerine bizde bir **nazar/mühr-ü Süleyman / kilim göbeği** motifi). Kartlar bu mührün çevresinde çemberde. Arka planda vinyet: taş duvarlar, kuru dut ağaçları, kem-göz taşı heykel (Demon Bluff'taki dev göz canavarının bizim versiyonu: **dev bir nazar boncuğu / kem göz**, çatlamış, içinden kızıl sızan).

### 10.2 Renk paleti (çekirdek)
- **İyi/köy (nötr):** gece indigo `#1B2A4A`, çini mavisi `#2E6E8E`, fildişi `#EDE3C8`.
- **Sıcak vurgu (kandil/umut):** safran/zerdeçal `#E4A72E`, bakır `#C9743B`.
- **Kötü/lanet:** kızıl `#8E1B1B`, kan `#B3272D`, is-siyahı `#0E0A0A`.
- **Nazar (imza):** derin mavi-turkuaz `#0E5AA7` + beyaz + siyah halka (nazar boncuğu). Kem göz parıltısı kızıl.
- Roller kategoriye göre çerçeve rengi: Villager = mor/çini, Outcast = amber/sarı, Evil = kızıl (Demon Bluff kodlamasıyla uyumlu, tanıdık okunur).

### 10.3 Kart tasarımı
- Oran: tarot benzeri ~2:3, köşeleri hafif yuvarlak.
- **Kart arkası (kapalı):** ortada stilize **nazar boncuğu göz**; kenarda kilim/çini bordür. (Demon Bluff'taki turuncu göz → bizim nazar.)
- **Kart önü (açık):** üstte `# seat` numarası, ortada portre, altta rol adı bandı (kategori renginde). Aktif yeteneklilerde köşede küçük simge (Demon Bluff'taki "yıldırım/geri-dön" ikonu gibi).
- **Durum katmanları:** `facedown`, `revealed(good/outcast/evil)`, `executed` (üzerine ritüel mührü/çarpı), `marked` (üstte renkli ok), `anchor` (altın hâle), `selected` (parlak çerçeve).
- **Tanıklık balonu:** karttan çıkan koyu, okunur konuşma balonu (görsellerdeki gibi), kısa metin.

### 10.4 Karakter tasarımı (art bible)
- Stil: **Anadolu minyatürü × modern çizgi-roman** hibriti. Düz, doygun renkler; ince kontur; hafif dokusal gölge. Anime-bitişik ama folk kostüm detaylı. (Demon Bluff'un stilize portre kalitesini hedefle, ama minyatür/kilim dokusuyla ayrış.)
- Köylü arketipleri (portre yönergesi): Falcı (kâğıt/boncuk), Derviş (sikke/tespih), Mimar, Ekmekçi (un/ekmek), Avcı (yay), Bekçi (fener/asa), Kadı (terazi), İzci, Âşık (bağlama), Kılıççı, Geveze, Müneccim (usturlap). Kostüm: şalvar, cepken, yemeni, entari; tokalar bakır/gümüş.
- Kötüler (Türk folkloru): **Cin** (Minion, mavi-gri, boynuzlu genç), **Alkarısı/Al Bastı** (Poisoner, kızıl saçlı), **Karakoncolos** (kışsal, tüylü), **Congolos/Pooka** (geri-tepen), **Gulyabani** (Demon boss "Baa", dev, boynuzlu, postlu — görsel 3'teki kırmızı boss kartı gibi). Kızıl aura + is dumanı.
- Outcast: Sarhoş (şarap tulumu, sersem), Ermiş (hâle, masum), Uğursuz.

### 10.5 Ortam / arka plan
- İki tema varyantı (görsellerde kırmızı "lanetli" ve yeşil "orman" gibi): bizde **"temiz köy" (indigo-yeşil gece)** ve **"lanet ilerledi" (kızıl)** — Spread ilerledikçe arka plan kızıla kayar (dinamik tint). Bu, tehdit hissini görselleştirir.
- Çevre süsleri: kırık kağnı, kemik yığını, dut ağacı, nazar heykeli, kandiller (mührün köşelerinde yanan mumlar).

### 10.6 Tipografi
- Başlık/display: Selçuklu/Osmanlı esintili ama **Latin** okunur bir display font (örn. ağır serifli, hafif süslü). 
- Gövde/tanıklık: temiz, yüksek okunur bir sans (Türkçe diakritikleri — ç ğ ı İ ö ş ü — tam desteklemeli). **Font seçiminde Türkçe glyph desteği zorunlu.**
- Rakamlar (seat, can, skor): net tabular font.

### 10.7 VFX ve animasyon
- Kart açılma: 3B benzeri flip + toz/kıvılcım. Küçük "önce ve sonra" frame'leriyle yumuşat.
- Execute/arındırma: ritüel — kandil alevi büyür, kart üstüne mühür yanar, Evil ise is-dumanı dağılır ("gerçek yüz" reveal); Good ise kızıl "Ouch!" + can kırılması.
- Spread: is/kara mürekkep çemberde bir seat'e sürünür; hedef kart kızıla döner, tanıklık balonu titreyip değişir.
- Nazar boncuğu boss: yavaş nefes/parıltı; can azaldıkça kızıl pulse.
- **Kural:** GIF/kayıt için aksiyon öncesi-sonrası ekstra frame; dialog/alert tetikleyen native modal YOK (Godot içi UI kullan).

### 10.8 Ses
- Enstrümanlar: bağlama/saz, ney, kaval, def/darbuka, kopuz; atmosfer drone + fısıltı.
- Olay sesleri: kart flip (tahta/kağıt), doğru arındırma (temiz çan/def vuruşu), yanlış (boğuk gong + kalp kırılışı), Spread (uğultu/fısıltı yükselişi), boss reveal (derin ney + koro).
- Müzik: gerilim düşükken sakin bağlama; Spread ilerledikçe ritim/tempo artar (dinamik katman).

---

## 11. UI / UX Spesifikasyonu
Ekranlar (her biri bir Scene):
- **MainMenu:** Yeni sefer, Devam, Koleksiyon, Ayarlar, Daily.
- **RunMap:** düğüm zinciri + boss (görsel 3). "Next".
- **VillageBoard (ana):** çember kartlar + merkez mühür/boss + HUD.
  - Sol-üst: görev metni + "Evils killed X/K" + "Village i/n" + Ascension + Score.
  - Sağ-üst: kompozisyon rozetleri (villager/outcast/minion/demon sayıları) + deste ikonu; arındırılan Evil'ler mini kart şeridi (görsel 7/8).
  - Sağ: "peek/reveal all" göz ikonu; sağ-alt: execute (dagger/ritüel) butonu + Mark lejantı (1-5).
  - Sol-alt: Can rozeti (10/10) + can kalpleri.
- **DeckView:** "YOUR DECK" (görsel 4) — havuzdaki roller, Evil kompozisyon.
- **Shop / Event:** köyler arası.
- **Collection:** "Unlocked Cards" grid + sayfa (görsel 6), tamamlanma %.
- **Result:** köy/sefer sonu skor kırılımı.

Etkileşim:
- Sol tık: kapalı kartı reveal; açık kartın yeteneği aktifse hedef seçtir ("Pick 3 characters" / "Cancel" modali — görsel 5).
- Sağ tık / 1-5: mark koy/çıkar.
- Execute: dagger'ı sürükle/karta bas → onay → sonuç.
- Erişilebilirlik: renk-körü için mark'larda şekil farkı (ok/çarpı/soru), yüksek kontrast modu, metin ölçek.

---

## 12. Onboarding (katmanlı öğretim)
1. **Köy 1 (tutorial):** 5 kart, 1 Demon, Omen yok, Spread yok, 1 Anchor. Sadece "kötü yalan söyler" + doğrudan alignment ipuçları (Judge/Oracle). Elle yönlendirme.
2. **Köy 2-3:** Outcast (Drunk) tanıtımı; "iyi ama yanlış söyleyebilir."
3. **Orta sefer:** Omen ve Astrologer tanıtımı ("desen var").
4. **Geç sefer:** Spread tanıtımı ("yetiş").
5. Boss: hepsi bir arada. Her yeni mekanik ilk kez tek başına, izole tanıtılır.

---

## 13. Teknik Mimari (Godot 4.3+)

### 13.1 Proje yapısı
```
res://
  project.godot
  autoload/            # singletons
    EventBus.gd        # global signal hub
    GameState.gd       # aktif köy/sefer state
    RunManager.gd      # sefer akışı, harita, ascension
    SaveManager.gd     # user:// json save
    AudioManager.gd
    Rng.gd             # seed'li RandomNumberGenerator sağlayıcı
  scripts/
    core/
      enums.gd
      board_topology.gd     # mesafe/komşuluk/yön/region — saf mantık
      character.gd
      testimony.gd          # TestimonyClaim veri + değerlendirme
      village_state.gd
    engine/
      deduction_solver.gd   # CSP çözücü (node'suz, test edilebilir)
      village_generator.gd  # üretici
      spread_engine.gd      # yayılma simülasyonu
      omen.gd
    data/                   # class_name'li Resource script'leri
      role_data.gd
      village_config.gd
      omen_data.gd
      deck_data.gd
      ascension_data.gd
    ui/                     # scene controller script'leri
  scenes/
    main_menu.tscn
    run_map.tscn
    village_board.tscn
    card.tscn
    testimony_bubble.tscn
    hud.tscn
    deck_view.tscn
    shop.tscn
    collection.tscn
    result.tscn
  data/                     # .tres içerik
    roles/  omens/  decks/  ascensions/  configs/
  assets/
    art/ (portraits, frames, backs, bg, vfx)
    audio/ (music, sfx)
    fonts/
  tests/                    # GUT (Godot Unit Test) headless
    test_solver.gd
    test_generator.gd
    test_topology.gd
    test_spread.gd
```

### 13.2 Sahne ağacı (VillageBoard örneği)
```
VillageBoard (Node2D)                 # controller: village_board.gd
├─ Background (ParallaxBackground/Sprite2D)   # Spread tint burada
├─ RitualCircle (Node2D)              # merkez mühür + boss art
├─ CardRing (Node2D)                  # kartları çember üzerinde konumlar
│  └─ Card (x N)  [scenes/card.tscn]
│     ├─ Frame, Portrait, RoleBand, SeatLabel
│     ├─ TestimonyBubble
│     ├─ MarkOverlay, StateOverlay (executed/anchor/selected)
│     └─ Area2D (tık algısı)
├─ HUD (CanvasLayer) [scenes/hud.tscn]
│  ├─ QuestPanel, CompositionBadges, KilledStrip
│  ├─ HealthWidget, ScorePanel
│  └─ ExecuteButton, MarkLegend, PeekButton
└─ FSM (Node)                         # GamePhase state machine
```

### 13.3 Ana sınıflar ve sorumluluklar
- `BoardTopology` (saf): seat matematiği (distance/direction/neighbor/region). **Tek doğruluk kaynağı**; UI ve solver ikisi de buradan sorar.
- `TestimonyClaim` (saf): `evaluate(world) -> bool` — bir claim'in verili dünyada doğruluğu. Solver ve generator ikisi de kullanır (DRY: yalan üretimi = doğruyu bul, sonra ihlal et).
- `DeductionSolver` (saf): §5.8 sözleşmesi. `solve(visible_state) -> Array[World]`, `is_determined()`, `safe_moves()`, `hint()`.
- `VillageGenerator` (saf): §8. `generate(config, rng) -> VillageState`.
- `SpreadEngine` (saf): §5.6. `next_spread_target(state) -> seat`, `apply(state)`.
- `VillageState`: seri hale getirilebilir tüm köy durumu (karakterler, açık/işaret, faz, seed, marks).
- `GameState` (autoload): aktif VillageState + oyuncu can/score.
- `RunManager` (autoload): harita, köy sırası, ascension, deck, para.
- `EventBus` (autoload): sinyaller (aşağıda). Node'lar birbirine doğrudan bağımlı olmamalı.

### 13.4 Sinyaller (EventBus)
```
signal card_revealed(seat)
signal card_executed(seat, was_evil)
signal player_damaged(amount, current_hp)
signal mark_changed(seat, mark_type)
signal spread_occurred(seat)
signal village_won(score)
signal village_lost(reason)
signal omen_hint_learned(omen_type_partial)
signal phase_changed(new_phase)
```

### 13.5 State machine (GamePhase)
`SETUP → REVEAL_IDLE → (ABILITY_TARGETING) → EXECUTE_CONFIRM → RESOLVE → (SPREAD) → REVEAL_IDLE ... → VILLAGE_END`.
FSM ayrı bir Node; UI sadece faz sinyaline tepki verir.

### 13.6 Kayıt & determinizm
- `SaveManager`: `user://save.json` — meta ilerleme (açık kartlar, kozmetik, ayar), aktif sefer (seed + ilerleme). JSON; şema versiyonu ile.
- Tüm rastlantı `Rng` autoload üzerinden seed'li. Köy state seed taşır → tam reprodüksiyon (daily, bug-repro, test).
- **Kural:** `randi()`/`randf()` doğrudan kullanma; hep `Rng.get(stream)`.

### 13.7 Test stratejisi (headless, önce motor)
- GUT ile `tests/`:
  - `test_topology`: distance/direction/region kenar durumları (wrap-around, çift/tek N).
  - `test_solver`: elle kurulmuş köyler için tek/çok çözüm doğrulaması; simetri-kıran Anchor senaryoları dahil (bkz. §5.7-§5.8).
  - `test_generator`: 10⁴ seed üret → hepsi `is_determined()` mı? Outcast/Omen/Spread kombinasyonları.
  - `test_spread`: yayılma sonrası çözülebilirlik korunuyor mu.
- CI: `godot --headless --script run_tests` benzeri. Motor UI'dan önce yeşil olmalı.
- **Altın kural:** Üretilen hiçbir köy tek-çözümsüz canlıya çıkmamalı; generator bunu assert eder, testler garanti eder.

---

## 14. İçerik Pipeline (yeni rol/omen ekleme)
Yeni bir rol eklemek = kod değil, veri + küçük hook:
1. `data/roles/<id>.tres` (RoleData) oluştur; `claim_type` ve `solver_hook` ata.
2. Gerekirse `TestimonyClaim.evaluate` içine yeni claim tipi ekle (nadiren).
3. Portre/çerçeve asset'i bağla (§10).
4. `DeckData`'ya ekle; hangi ascension'da havuza gireceğini işaretle.
5. `test_generator`'a rolü içeren köyler ekle → solvability yeşil.
Aynı şablon Omen (`OmenData` + `omen.gd` kısıt fonksiyonu) ve Spread kuralı için de geçerli.

---

## 15. Yol Haritası / Build Sırası (milestones)

**M0 — Motor iskeleti (UI yok, testler yeşil):**
`enums`, `BoardTopology`, `TestimonyClaim`, `Character`, `VillageState`, `DeductionSolver`, basit `VillageGenerator` (Omen/Spread yok), GUT testleri. **Çıktı: headless tek-çözümlü köy üretimi + doğrulama.**

**M1 — Oynanabilir tek köy (MVP):**
`village_board` + `card` + `hud`, reveal/execute/can/kazan-kaybet, 5-7 kart, temel roller (Oracle/Judge/Knight/Scout/Enlightened/Architect/Baker + Minion + Demon), Anchor, mark sistemi, temel VFX/ses placeholder. **Bu, ilk "hissedilebilir" sürüm.**

**M2 — Sefer & meta:**
`RunManager`, `run_map`, köy zinciri + boss, skor/para, `result`, save. Ascension A1-A3.

**M3 — İmza mekanikler:**
Omen (Astrologer/Surveyor + solver kısıtı), Spread (SpreadEngine + dinamik arka plan tint). Onboarding katmanları.

**M4 — Derinlik & içerik:**
Deste kurma, dükkan, 30→100 rol, Outcast çeşitleri (Poisoner/Saint/Mutant), boss çeşitleri, collection ekranı, kozmetikler.

**M5 — Cila:**
Sanat geçişi (placeholder→final Anadolu art bible), ses, dinamik müzik, daily/endless/challenge modları, denge, erişilebilirlik.

> Her milestone sonunda: solvability test suite yeşil + oynanabilir bir dikey dilim.

---

## 16. Kodlama Konvansiyonları (GDScript)
- `class_name` PascalCase; dosya adı snake_case (`deduction_solver.gd` → `class_name DeductionSolver`).
- Değişken/fonksiyon snake_case; sabitler UPPER_SNAKE; enum değerleri UPPER_SNAKE.
- `signal` isimleri geçmiş zaman/olay (`card_executed`).
- Saf mantık (core/engine) **Node'a bağımlı olmasın**; `RefCounted`/`Resource` tabanlı, headless test edilebilir.
- UI ↔ mantık iletişimi **yalnız EventBus sinyalleri** ve GameState üzerinden; UI iş mantığı içermez.
- `@export` ile veri; magic number yok — dengeler `data/configs/*.tres`.
- Tüm oyuncuya görünen metinler bir çeviri tablosundan (`tr`/`en`); Türkçe birincil, İngilizce ikincil (Steam için).
- Rastlantı yalnız `Rng` üzerinden; global state mutasyonu tek yerden.
- Yorum: neden'i yaz, ne'yi değil. Kural gerekçeleri bu CLAUDE.md'ye referans versin.

---

## 17. Açık Kararlar / Sorulacaklar (design backlog)
- İblis boss'un pasif yeteneği tam ne olmalı (Spread hızlandırıcı mı, bilgi bozucu mu)?
- Reveal tamamen bedava mı yoksa geç oyunda maliyetli mi (denge testi gerekiyor)?
- Execute "arındırma" mı yoksa "kovma/banish" mi — ton (grim vs folk) kararı.
- Mark sistemi yükseltmeleri (dükkanda ek mark rengi) meta olarak var mı?
- Tema kesinleşmesi: Anadolu folk-horror onaylanırsa §10 finalize; değilse reskin.

---

## 18. Sık Yapılan Hatalar (Claude Code için uyarılar)
- ❌ Yalanı rastgele üretme. ✅ Önce doğruyu hesapla, sonra onu **ihlal eden** claim seç; böylece çözücüyle tutarlı kalır.
- ❌ Solvability'yi UI'da kontrol etme. ✅ Üretim anında headless doğrula; canlıya asla belirsiz köy çıkmaz.
- ❌ Topoloji matematiğini iki yerde yazma. ✅ Sadece `BoardTopology`.
- ❌ `randi()` serpiştirme. ✅ Seed'li `Rng`.
- ❌ Outcast'ı gizli sürpriz yapma. ✅ Kompozisyonda ilan et (adalet).
- ❌ Omen+Spread'i tutorial'da açma. ✅ Katmanlı öğretim (§12).
- ❌ Native OS dialog/alert. ✅ Godot içi UI.
- ❌ Türkçe karaktersiz font. ✅ ç ğ ı İ ö ş ü tam destek.

---

*Son not: Bu doküman yaşayan bir sözleşmedir. Mekanik bir karar değişince önce burayı güncelle, sonra kodu. Çekirdek vaat: **kartlar yalan söyler ama kanıt her zaman tutar.***
