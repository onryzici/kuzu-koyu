class_name NightEngine
extends RefCounted

## GECE AVI — V2 imza mekaniği. Bkz. CLAUDE.md §0.5.
## Av Düzeni (bilinen, deterministik): kurban = canlı İYİ karakterlerden, herhangi
## bir canlı KURDA çember mesafesi en küçük olan; eşitlikte küçük seat numarası.
##
## TEK DOĞRULUK KAYNAĞI (§18): gerçek gece (GameState.end_day), solver'ın gece
## kısıtı VE üreticinin bot simülasyonu — üçü de pick_victim'i kullanır. Kural
## değişirse yalnız burası değişir.

## alignments: seat -> Enums.Alignment (aday dünya YA DA gerçek durum).
## alive: canlı seat listesi (kurban aday havuzu + avcı kurtlar bunun içinden).
## protected: AĞIL — çobanın o gece koruduğu seat (kurban havuzundan çıkar; -1 = yok).
## Döndürür: kurban seat; av mümkün değilse (kurt ya da koyun kalmadıysa) -1.
static func pick_victim(alignments: Array, alive: Array, n: int, protected: int = -1) -> int:
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
	var best_d := n + 1
	for g in sheep:
		var d := n + 1
		for w in wolves:
			var dd := BoardTopology.distance(g, w, n)
			if dd < d:
				d = dd
		# eşitlikte küçük seat: sheep zaten artan sırada gezilir, strict < yeter
		if d < best_d:
			best_d = d
			best = g
	return best


## Gerçek durumda geceyi uygula: kurbanı seç, öldür (gerçek yüz açılır), gece
## olayını kaydet (solver kısıtı için canlı-anlık-görüntü + korunan ile).
## Kurban seat döner; -1 = av yok.
static func apply(state: VillageState, protected: int = -1) -> int:
	var alive := state.alive_seats()
	var al: Array = []
	for c in state.characters:
		al.append(c.alignment)
	var victim := pick_victim(al, alive, state.n, protected)
	if victim < 0:
		return -1
	var c := state.get_character(victim)
	c.night_killed = true
	c.revealed = true  # gerçek yüz (kesin İYİ) açığa çıkar
	state.night_events.append({"alive": alive, "victim": victim, "day": state.day, "protected": protected})
	return victim


## Bir aday dünya (alignment ataması) kayıtlı gece olaylarıyla tutarlı mı?
## Her olay: o anki canlı kümede (korunan hariç), W'ye göre av kuralı TAM O kurbanı
## seçmeliydi. Koruma kaydedildiği için kanıt gücü bozulmaz.
static func consistent_with_nights(alignments: Array, night_events: Array, n: int) -> bool:
	for ev in night_events:
		if pick_victim(alignments, ev["alive"], n, int(ev.get("protected", -1))) != ev["victim"]:
			return false
	return true
