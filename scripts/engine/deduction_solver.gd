class_name DeductionSolver
extends RefCounted

## Motorun kalbi. Girdi: köyün oyuncuya görünür durumu (visible_for_solver).
## Çıktı: tutarlı tüm alignment atamalarının kümesi (her biri Array[int]).
## Bkz. CLAUDE.md §0.5 (V2), §5.8 (sözleşme) ve §18.
##
## Bir aday dünya W geçerlidir ⇔
##   - |Evil(W)| == evil_count
##   - Her Anchor W'de GOOD
##   - Kesinleşmiş kimlikler (known: ayıklanan/gece ölen) W ile uyuşur
##   - Bilinen Omen (varsa) W'de sağlanır
##   - GECE OLAYLARI: her kayıtlı avda, W'ye göre Av Düzeni tam o kurbanı seçmeliydi
##     (NightEngine.consistent_with_nights — cesetler yalan söylemez)
##   - VERİLMİŞ her ifade için:
##       konuşan W'de EVIL  → ifade YANLIŞ (kurt hep yalan)
##       konuşan W'de GOOD  → ifade DOĞRU; yanlışsa o karakter SARHOŞ olmalı —
##         yanlış-konuşan-iyi KARAKTER sayısı <= drunk_count (anchor sarhoş olamaz)
##
## Performans: N<=12, evil<=4 için C(N,evil) kombinasyonu küçük (§5.8).

## visible: VillageState.visible_for_solver() çıktısı.
## Döndürür: Array[Array[int]] — geçerli alignment dünyaları.
static func solve(visible: Dictionary) -> Array:
	var n: int = visible["n"]
	var evil_count: int = visible["evil_count"]
	var anchors: Array = visible["anchors"]
	var revealed: Array = visible["revealed"]
	var known: Array = visible.get("known", [])
	var nights: Array = visible.get("nights", [])
	var known_omen: int = visible.get("known_omen", Enums.OmenType.NONE)
	var omen_params: Dictionary = visible.get("omen_params", {})
	var drunk_count: int = visible.get("drunk_count", 0)

	var solutions: Array = []
	for evil_set in _combinations(n, evil_count):
		# Anchor'lar Evil olamaz.
		var ok := true
		for a in anchors:
			if a in evil_set:
				ok = false
				break
		if not ok:
			continue

		# Kesinleşmiş kimlikler (ayıklanan → gerçek yüzü; gece ölen → kesin İYİ).
		for kv in known:
			var want_evil: bool = kv["alignment"] == Enums.Alignment.EVIL
			if (kv["seat"] in evil_set) != want_evil:
				ok = false
				break
		if not ok:
			continue

		# Bilinen Omen kısıtı (§5.5): evil yerleşimi kuralı sağlamalı.
		if known_omen != Enums.OmenType.NONE:
			if not Omen.satisfies(known_omen, omen_params, evil_set, n):
				continue

		var al: Array = []
		al.resize(n)
		al.fill(Enums.Alignment.GOOD)
		for s in evil_set:
			al[s] = Enums.Alignment.EVIL

		# Gece kısıtı: cesetler yalan söylemez (Av Düzeni tek yerde — NightEngine).
		if not nights.is_empty():
			if not NightEngine.consistent_with_nights(al, nights, n):
				continue

		var world := {"n": n, "alignment": al, "evil_seats": evil_set}

		# İfade kontrolü. Sarhoş gevşetmesi KARAKTER bazlı: bir iyi karakterin
		# HERHANGİ bir ifadesi yanlışsa o karakter sarhoş adayıdır; bu tür
		# karakter sayısı <= drunk_count. Bkz. §5.4, §5.8.
		var bad_good_seats := {}
		for entry in revealed:
			var seat: int = entry["seat"]
			var t: TestimonyClaim = entry["testimony"]
			var truth: bool = t.evaluate(world)
			if al[seat] == Enums.Alignment.GOOD:
				if not truth:
					if seat in anchors:
						ok = false
						break
					bad_good_seats[seat] = true
					if bad_good_seats.size() > drunk_count:
						ok = false
						break
			else:
				if truth:
					ok = false
					break

		if ok:
			solutions.append(al.duplicate())

	return solutions


static func is_determined(visible: Dictionary) -> bool:
	return solve(visible).size() == 1


## Tüm çözümlerde EVIL olan seat'ler = kesin arındırılabilir (güvenli execute).
## Bkz. §5.8 safe_moves.
static func certain_evil(visible: Dictionary) -> Array:
	var worlds := solve(visible)
	if worlds.is_empty():
		return []
	var n: int = visible["n"]
	var out: Array = []
	for seat in range(n):
		var always_evil := true
		for w in worlds:
			if w[seat] != Enums.Alignment.EVIL:
				always_evil = false
				break
		if always_evil:
			out.append(seat)
	return out


static func _combinations(n: int, k: int) -> Array:
	var result: Array = []
	_combo_helper(0, n, k, [], result)
	return result


static func _combo_helper(start: int, n: int, k: int, combo: Array, result: Array) -> void:
	if combo.size() == k:
		result.append(combo.duplicate())
		return
	# Kalan eleman yetmiyorsa erken kes.
	for i in range(start, n - (k - combo.size()) + 1):
		combo.append(i)
		_combo_helper(i + 1, n, k, combo, result)
		combo.pop_back()
