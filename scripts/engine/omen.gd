class_name Omen
extends RefCounted

## Omen (Gizli Kural) — Evil setinin çember üzerindeki gizli yapısal kısıtı.
## Bkz. CLAUDE.md §5.5. Tema-agnostik saf mantık; generator yerleşimi buna göre
## seçer, solver (kural bilinince) buna göre eler, Astrologer (Müneccim) ifşa eder.
##
## Bu ilk sürüm: PARITY, CONTIGUOUS_ARC, DISPERSED, MIRROR. (SUIT ve DEMON_DISTANCE
## ek veri gerektirir; sonra.) Tümü yalnız evil-seat KÜMESİNE bakar → saf ve test
## edilebilir. params şimdilik boş; MIRROR "bir eksen VARDIR" olarak kontrol edilir.


## evil_seats kümesi verili Omen kısıtını sağlıyor mu?
static func satisfies(otype: int, _params: Dictionary, evil_seats: Array, n: int) -> bool:
	if evil_seats.is_empty():
		return true
	match otype:
		Enums.OmenType.PARITY:
			var par: int = int(evil_seats[0]) % 2
			for s in evil_seats:
				if int(s) % 2 != par:
					return false
			return true

		Enums.OmenType.CONTIGUOUS_ARC:
			return _is_contiguous(evil_seats, n)

		Enums.OmenType.DISPERSED:
			for s in evil_seats:
				if BoardTopology.right(int(s), n) in evil_seats:
					return false
			return true

		Enums.OmenType.MIRROR:
			return _has_mirror_axis(evil_seats, n)

		_:  # NONE / desteklenmeyen
			return true


## Bu Omen'i sağlayan TÜM evil-seat kombinasyonları (generator seçer). n<=12,
## evil<=4 için C(n,evil) küçük; kaba kuvvet yeterli (§5.8).
static func valid_placements(otype: int, params: Dictionary, n: int, evil_count: int) -> Array:
	var out: Array = []
	for combo in _combinations(n, evil_count):
		if satisfies(otype, params, combo, n):
			out.append(combo)
	return out


## Astrologer (Müneccim) tanıklık metni — Omen kategorisini ifşa eder (kurt teması).
static func describe(otype: int) -> String:
	match otype:
		Enums.OmenType.PARITY:
			return "Yıldızlar diyor ki: kurtlar hep aynı pariteden koltukta — ya hepsi tek ya hepsi çift numara."
		Enums.OmenType.CONTIGUOUS_ARC:
			return "Yıldızlar diyor ki: kurtlar yan yana, kesintisiz bir yay oluşturur."
		Enums.OmenType.DISPERSED:
			return "Yıldızlar diyor ki: kurtlar dağınıktır — hiçbir ikisi komşu değil."
		Enums.OmenType.MIRROR:
			return "Yıldızlar diyor ki: kurt yerleşimi bir eksene göre aynalıdır (simetrik)."
		_:
			return ""


## Orta uzunluk ipucu (UI rozetinin alt satırı).
static func hint(otype: int) -> String:
	match otype:
		Enums.OmenType.PARITY: return "Kurtlar hep aynı pariteli koltukta (tek/çift)."
		Enums.OmenType.CONTIGUOUS_ARC: return "Kurtlar bitişik, kesintisiz bir yay."
		Enums.OmenType.DISPERSED: return "Hiçbir iki kurt komşu değil."
		Enums.OmenType.MIRROR: return "Kurt yerleşimi bir eksene göre simetrik."
		_: return ""


## Kısa etiket (UI rozeti için).
static func short_label(otype: int) -> String:
	match otype:
		Enums.OmenType.PARITY: return "Parite"
		Enums.OmenType.CONTIGUOUS_ARC: return "Bitişik Yay"
		Enums.OmenType.DISPERSED: return "Dağınık"
		Enums.OmenType.MIRROR: return "Aynalı"
		_: return ""


# --- iç yardımcılar ---

## Kümedeki seat'ler çember üzerinde kesintisiz bir yay mı (mod n)?
static func _is_contiguous(evil_seats: Array, n: int) -> bool:
	var k := evil_seats.size()
	if k <= 1:
		return true
	var set := {}
	for s in evil_seats:
		set[int(s)] = true
	# Bir başlangıçtan itibaren k ardışık seat tam olarak kümeyi kapsıyor mu?
	for start in range(n):
		var ok := true
		for j in range(k):
			if not set.has((start + j) % n):
				ok = false
				break
		if ok:
			return true
	return false


## Bir yansıma ekseni var mı: reflect(s) = (a - s) mod n kümeyi kendine götürsün.
static func _has_mirror_axis(evil_seats: Array, n: int) -> bool:
	var set := {}
	for s in evil_seats:
		set[int(s)] = true
	# Eksen a: 0..2n-1 (yarım-seat eksenleri dahil).
	for a in range(2 * n):
		var symmetric := true
		for s in evil_seats:
			var m := ((a - int(s)) % n + n) % n
			if not set.has(m):
				symmetric = false
				break
		if symmetric:
			return true
	return false


static func _combinations(n: int, k: int) -> Array:
	var result: Array = []
	_combo(0, n, k, [], result)
	return result


static func _combo(start: int, n: int, k: int, cur: Array, result: Array) -> void:
	if cur.size() == k:
		result.append(cur.duplicate())
		return
	for i in range(start, n - (k - cur.size()) + 1):
		cur.append(i)
		_combo(i + 1, n, k, cur, result)
		cur.pop_back()
