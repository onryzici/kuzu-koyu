class_name BoardTopology
extends RefCounted

## Çember üzerindeki seat matematiğinin TEK doğruluk kaynağı.
## Mesafe / komşuluk / yön / region — hepsi burada; solver ve UI buradan sorar.
## Bkz. CLAUDE.md §5.1 ve §18 ("Topoloji matematiğini iki yerde yazma").
##
## Seat 0..N-1, saat yönünde artar. Tüm fonksiyonlar saf/static.
## Kural (§5.1): arındırılmış Evil kartlar sayımdan çıkar; çağıran taraf
## evil_seats listesine yalnız hâlâ tehdit olan Evil'leri koyarak bunu sağlar.

static func left(i: int, n: int) -> int:
	return (i - 1 + n) % n

static func right(i: int, n: int) -> int:
	return (i + 1) % n

## Saat yönünde (index artarak) from'dan to'ya adım sayısı.
static func cw_distance(from: int, to: int, n: int) -> int:
	return ((to - from) % n + n) % n

## Saat yönünün tersine (index azalarak) from'dan to'ya adım sayısı.
static func ccw_distance(from: int, to: int, n: int) -> int:
	return ((from - to) % n + n) % n

## İki seat arası çember mesafesi (yönden bağımsız).
static func distance(a: int, b: int, n: int) -> int:
	var d := ((a - b) % n + n) % n
	return min(d, n - d)

static func neighbors(i: int, n: int) -> Array:
	return [left(i, n), right(i, n)]

## start'tan başlayarak saat yönünde `length` seat'lik yay.
static func arc(start: int, length: int, n: int) -> Array:
	var out: Array = []
	for k in range(length):
		out.append((start + k) % n)
	return out

static func count_in(seats: Array, target_seats) -> int:
	var c := 0
	for s in seats:
		if s in target_seats:
			c += 1
	return c

## seat'ten en yakın Evil'e mesafe (kendini hariç tutar). Evil yoksa n döner.
static func nearest_evil_distance(seat: int, evil_seats, n: int) -> int:
	var min_d := n
	for e in evil_seats:
		if e == seat:
			continue
		var d := distance(seat, e, n)
		if d < min_d:
			min_d = d
	return min_d

## seat'ten en yakın Evil'in yönü. İki yönde eşit mesafede Evil varsa EQUIDISTANT.
static func nearest_evil_direction(seat: int, evil_seats, n: int) -> int:
	var min_d := nearest_evil_distance(seat, evil_seats, n)
	if min_d == n:
		return Enums.Direction.EQUIDISTANT
	var has_cw := false
	var has_ccw := false
	for e in evil_seats:
		if e == seat:
			continue
		if cw_distance(seat, e, n) == min_d:
			has_cw = true
		if ccw_distance(seat, e, n) == min_d:
			has_ccw = true
	if has_cw and has_ccw:
		return Enums.Direction.EQUIDISTANT
	if has_cw:
		return Enums.Direction.CLOCKWISE
	return Enums.Direction.COUNTER_CLOCKWISE
