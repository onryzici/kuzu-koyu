# Güncelleme Notları

## 2026-07-20 (2) — WOLF IN WOOL + İngilizce Dil Desteği

- Oyunun adı artık **WOLF IN WOOL** (proje adı, pencere başlığı, çalıştırılabilir
  adları `WolfInWool.exe` / `WolfInWool-mac.zip`).
- **Tam İngilizce yerelleştirme:** yeni `Loc` altyapısı (tr/en anahtar tabloları,
  ~250 anahtar) + rol adları/yetenekleri, üretilen ifade cümleleri (tüm tipler),
  omen metinleri, HUD/defter/tooltip/tutorial, harita/dükkân/olaylar/sonuç/
  kurallar/codex/açılış uyarısı/duraklat menüsü ve muskalar iki dilde.
- **Ayarlar ekranına Dil / Language seçimi** eklendi (Türkçe ↔ English; arayüz
  anında, üretilmiş ifadeler yeni köyde değişir; tercih kayda yazılır).
- Muska adları/açıklamaları ve boss adları yerelleştirme üzerinden çözülür
  (`RunManager.passive_name/desc`).

## 2026-07-20 — Büyük İçerik & Cila Güncellemesi

### Oynanış — yeni mekanikler
- **Tuzakçı** (yeni aktif rol): bir koltuğa gecelik kapan kurar; av o koltuğa
  düşerse kurban ölmez, saldıran kurt yakalanıp gerçek yüzü açılır. Kapan da
  ceset gibi yalan söylemeyen bir solver kısıtıdır.
- **Sisli Gece** (av düzeni varyantı): bazı köylerde kurt en yakını değil
  EN UZAK koyunu avlar — köyde ilan edilir; önizleme/defter/solver uyumlu.
- **Uğursuz** (yeni parya): İYİdir ve hep doğru söyler ama her sorgusunda
  sürüden 1 can alır. Bilgi mi, can mı?
- **4 yeni ifade tipi (yeni matematik):** parite sayımı (Tespihçi), mesafe
  eşitsizliği (Ürkek Kuzu), kurtlar-arası mesafe (Terzi), karşı koltuk (Aynacı).
- **8 yeni rol** toplamda (Karabaş, Kırkıcı, Davulcu, Kuyucu + üstteki 4).
- **2 yeni Gizli Kural:** Mühür Terazisi (kurtlar mühre eşit uzak) ve
  Tek Yaka (kurtlar eksenin tek tarafında).
- **3 Alfa Kurt varyantı:** Aç Alfa, Gölge Sürüsü, Sabırsız Alfa — sefer
  tohumuna göre final değişir.
- **Rol açılımları:** ileri roller Çile 2+ seferlerinde havuza girer;
  Karakterler ekranında kilitli kartlar görünür.

### Dedüksiyon yardımcıları
- **İfade Defteri** (TAB): tüm ifadeler + gece kurbanları + avlar güne göre tek panelde.
- **Çelişki vurgusu:** aynı anda dürüst olamayan ifade çiftleri kartlarda işaretlenir;
  hover'da aralarında kızıl kesikli bağ çizilir.
- **Av Düzeni önizlemesi:** GECE butonuna hover — bu gece ölebilecekler vurgulanır.
- Gizli Kural artık varlığıyla baştan ilan edilir ("???"), Müneccim çözer.

### Sefer & meta
- Harita yeniden yapılandı: köyler arasına **OLAY** ve **DÜKKÂN** durakları eklendi.
- 6 olay (Yaralı Gezgin, Eski Mezarlık, Kâhinin Çadırı, Kayıp Kuzu,
  Değirmen Yangını, Bereket Sunağı) — seed'li sonuçlar, köyler-arası ödüller.
- 2 yeni muska: Cesaret Tılsımı, Sadaka Kesesi.
- **Skor paylaşımı:** sonuç ekranından skor+tohum kopyala; menüden tohumla
  birebir aynı seferi başlat (arkadaş yarışı).
- Sefer başında **Çoban Rehberi** (oyun olaylarına bağlı tutorial).
- "Ascension" → **Çile**; "Ayıkla" → **Avla** (tüm metinler Türkçeleşti).

### Görsel & his
- Yeni ritüel arka planı + arka planla renk-eşlenmiş, rüzgârda salınan,
  imlece tepki veren **çim tutamları** (spritesheet + özel shader).
- Alçak sis, mum parıltıları, gece rüzgârı, kurban çevresinde solan çimler.
- Merkez gözün kolları uzayıp **kartları yokluyor** (Balatro-vari dokunma tepkisi).
- Gece sekansı sahnelendi: yavaş alacakaranlık → letterbox → ay doğuşu →
  tek tek yanan yıldızlar; gece daha karanlık, HUD geceyle birlikte çekiliyor.
- Pençe saldırısı yeniden: iki savuruş, savuruş başına 3 paralel yara,
  yırtık kâğıt kenarları, kart sarsıntısı.
- Kurt avı sinematiği: yerinde iki fazlı yırtılma + kan patlaması + kalıcı
  kan izi + kurdun son repliği. Kaybedişte kurtların postu atma sinematiği.
- Tüm sahne geçişleri fade'li (Fader); duyurular açılır **şerit-banner**da.
- Avla/Gece/Defter butonları yeniden tasarlandı (nişangâh, hilal, tomar ikonları,
  hover parıltısı); bilgi kartları bordersız + gölgeli.
- Yaşayan menü: haritada sis + çalılarda göz kırpan kurt gözleri.
- Profesyonel açılış: sağlık uyarısı + CODEZU stüdyo kartı; pati imleci;
  pati uygulama ikonu.

### Ses
- Yeni müzik (Crimson Moon Waltz); sorgu sesi (perde oynamalı hayvan sesi).
- Gün/gece müzik dinamiği; sentezlenmiş gece ambiyansı (rüzgâr + cırcır) ve
  uzak kurt uluması.
- Kurt avı sesi yumuşatıldı; işaretleme sesi kaldırıldı.

### Teknik
- Windows (tek exe) ve macOS (universal, ad-hoc imzalı) export preset'leri.
- ETC2 ASTC doku desteği; çözünürlük stretch doğrulandı.
- Test paketi 574 → **614** (yeni mekaniklerin tamamı üretim-teklik ve
  bot-bütçe garantileriyle birlikte test ediliyor).
