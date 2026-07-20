class_name NightEngine
extends RefCounted

## GECE AVI — V2 imza mekaniği. Bkz. CLAUDE.md §0.5.
## Av Düzeni (bilinen, deterministik): kurban = canlı İYİ karakterlerden, herhangi
## bir canlı KURDA çember mesafesi en küçük olan; eşitlikte küçük seat numarası.
## SİSLİ GECE (NightRule.FARTHEST): kurt görüşü bozulur — EN UZAK koyunu avlar
## (köyde İLAN edilir; adalet §7.3).
## TUZAK: Tuzakçı bir koltuğa kapan kurduysa ve av o koltuğa denk gelirse kurban
## ölmez; SALDIRAN kurt (kurbana en yakın kurt) yakalanıp gerçek yüzü açılır.
##
## TEK DOĞRULUK KAYNAĞI (§18): gerçek gece (GameState.end_day), solver'ın gece
## kısıtı VE üreticinin bot simülasyonu — üçü de pick_victim'i kullanır. Kural
## değişirse yalnız burası değişir.

## alignments: seat -> Enums.Alignment (aday dünya YA DA gerçek durum).
## alive: canlı seat listesi (kurban aday havuzu + avcı kurtlar bunun içinden).
## protected: AĞIL — çobanın o gece koruduğu seat (kurban havuzundan çıkar; -1 = yok).
## rule: Av Düzeni (NEAREST varsayılan; FARTHEST = sisli gece).
## Döndürür: kurban seat; av mümkün değilse (kurt ya da koyun kalmadıysa) -1.
static func pick_victim(alignments: Array, alive: Array, n: int, protected: int = -1,
		rule: int = Enums.NightRule.NEAREST) -> int:
	var wolves: Array = []
	var sheep: Array = []
	for s in alive:
		if alignments[s] == Enums.Alignment.EVIL:
			wolves.append(s)
		elif s != protected:
			sheep.append(s)
	if wolves.is_empty() or sheep.is_empty():
		return -1
	var best := -1
	var best_d := (n + 1) if rule == Enums.NightRule.NEAREST else -1
	for g in sheep:
		var d := n + 1
		for w in wolves:
			var dd := BoardTopology.distance(g, w, n)
			if dd < d:
				d = dd
		# eşitlikte küçük seat: sheep artan sırada gezilir, strict karşılaştırma yeter
		if rule == Enums.NightRule.NEAREST:
			if d < best_d:
				best_d = d
				best = g
		else:  # FARTHEST (sisli gece)
			if d > best_d:
				best_d = d
				best = g
	return best


## Kurbana saldıran kurt: kurbana çember mesafesi en küçük CANLI kurt; eşitlikte
## küçük seat. (Tuzak yakalaması + ileri analiz için.)
static func pick_attacker(alignments: Array, alive: Array, victim: int, n: int) -> int:
	var best := -1
	var best_d := n + 1
	for s in alive:
		if alignments[s] == Enums.Alignment.EVIL:
			var d := BoardTopology.distance(victim, s, n)
			if d < best_d:
				best_d = d
				best = s
	return best


## Gerçek durumda geceyi uygula: kurbanı seç; tuzağa denk geldiyse kurdu yakala,
## yoksa öldür. Gece olayını (kural + tuzak bilgisiyle) kaydet — solver kısıtı.
## Döndürür: kurban seat; -1 = av yok; -2 = TUZAK tetiklendi (ölüm yok, kurt açıldı).
static func apply(state: VillageState, protected: int = -1) -> int:
	var alive := state.alive_seats()
	var al: Array = []
	for c in state.characters:
		al.append(c.alignment)
	var trap := state.trap_seat
	var victim := pick_victim(al, alive, state.n, protected, state.night_rule)
	state.trap_seat = -1  # kapan tek geceliktir — tetiklenmese de sabah bozulur
	if victim < 0:
		return -1
	if trap >= 0 and victim == trap:
		# TUZAK: saldıran kurt yakalandı — postu düşer, gerçek yüz açılır (ölmez).
		var caught := pick_attacker(al, alive, victim, state.n)
		if caught >= 0:
			state.get_character(caught).revealed = true
		state.night_events.append({"alive": alive, "victim": -1, "day": state.day,
			"protected": protected, "rule": state.night_rule, "trapped": trap, "caught": caught})
		return -2
	var c := state.get_character(victim)
	c.night_killed = true
	c.revealed = true  # gerçek yüz (kesin İYİ) açığa çıkar
	state.night_events.append({"alive": alive, "victim": victim, "day": state.day,
		"protected": protected, "rule": state.night_rule, "trapped": trap})
	return victim


## Bir aday dünya (alignment ataması) kayıtlı gece olaylarıyla tutarlı mı?
## Her olay: o anki canlı kümede (korunan hariç), W'ye göre av kuralı TAM O sonucu
## üretmeliydi. Tuzaklı gecelerde: dünya avı kapana yolluyorsa gerçek sonuç da
## "yakalama" olmalı (ve saldıran kurt tutmalı); yollamıyorsa kurban tutmalı.
static func consistent_with_nights(alignments: Array, night_events: Array, n: int) -> bool:
	for ev in night_events:
		var rule := int(ev.get("rule", Enums.NightRule.NEAREST))
		var trapped := int(ev.get("trapped", -1))
		var expected := pick_victim(alignments, ev["alive"], n, int(ev.get("protected", -1)), rule)
		if trapped >= 0 and expected == trapped:
			# Dünya avı kapana yolluyor → gerçekte de tuzak tetiklenmiş olmalı.
			if int(ev["victim"]) != -1:
				return false
			var caught := int(ev.get("caught", -1))
			if caught >= 0 and pick_attacker(alignments, ev["alive"], trapped, n) != caught:
				return false
		elif expected != int(ev["victim"]):
			return false
	return true
