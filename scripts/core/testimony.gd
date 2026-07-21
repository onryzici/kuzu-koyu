class_name TestimonyClaim
extends Resource

## Bir kartın açılınca verdiği ifade: yapısal veri + (opsiyonel) doğal dil metni.
## evaluate(world) -> bool  bir claim'in verili dünyada doğruluğunu döndürür.
## Solver ve generator İKİSİ de bunu kullanır (DRY: yalan üretimi = doğruyu bul,
## sonra ihlal et). Bkz. CLAUDE.md §5.3, §13.3, §18.
##
## world sözlüğü:
##   n: int
##   alignment: Array[int]      (Enums.Alignment, seat -> alignment)
##   role: Array (opsiyonel)     (seat -> StringName; rol tabanlı claim'ler için)
##   evil_seats: Array (opsiyonel, yoksa alignment'tan türetilir)

@export var type: int = Enums.TestimonyType.SELF_ANCHOR
@export var speaker: int = -1
@export var targets: Array = []          ## hedef seat listesi
@export var region_a: Array = []         ## EVIL_COUNT_IN_REGION: birinci yay
@export var region_b: Array = []         ## EVIL_COUNT_IN_REGION: ikinci yay
@export var role: StringName = &""
@export var alignment: int = Enums.Alignment.GOOD
@export var number: int = 0
@export var direction: int = Enums.Direction.CLOCKWISE
@export var compare: int = Enums.Compare.EQUAL
@export var bool_val: bool = true
@export var day: int = -1                ## V3: VISITOR_COUNT — raporun ait olduğu GECE (gün no)
@export_multiline var text: String = ""


func _evil_seats(world: Dictionary) -> Array:
	if world.has("evil_seats"):
		return world["evil_seats"]
	var out: Array = []
	var al: Array = world["alignment"]
	for i in range(al.size()):
		if al[i] == Enums.Alignment.EVIL:
			out.append(i)
	return out


func evaluate(world: Dictionary) -> bool:
	var n: int = world["n"]
	var al: Array = world["alignment"]
	match type:
		Enums.TestimonyType.ALIGNMENT_OF:
			return al[targets[0]] == alignment

		Enums.TestimonyType.COUNT_IN_SET:
			var c := 0
			for s in targets:
				if al[s] == Enums.Alignment.EVIL:
					c += 1
			return c == number

		Enums.TestimonyType.NEIGHBOR_HAS_EVIL:
			var c := 0
			for s in BoardTopology.neighbors(speaker, n):
				if al[s] == Enums.Alignment.EVIL:
					c += 1
			return c == number

		Enums.TestimonyType.NEAREST_EVIL_DISTANCE:
			return BoardTopology.nearest_evil_distance(speaker, _evil_seats(world), n) == number

		Enums.TestimonyType.NEAREST_EVIL_DIRECTION:
			return BoardTopology.nearest_evil_direction(speaker, _evil_seats(world), n) == direction

		Enums.TestimonyType.EVIL_COUNT_IN_REGION:
			var ca := 0
			var cb := 0
			for s in region_a:
				if al[s] == Enums.Alignment.EVIL:
					ca += 1
			for s in region_b:
				if al[s] == Enums.Alignment.EVIL:
					cb += 1
			match compare:
				Enums.Compare.GREATER:
					return ca > cb
				Enums.Compare.LESS:
					return ca < cb
				_:
					return ca == cb

		Enums.TestimonyType.PAIR_RELATION:
			return (al[targets[0]] == al[targets[1]]) == bool_val

		Enums.TestimonyType.ROLE_PRESENT:
			var present := false
			if world.has("role"):
				for r in world["role"]:
					if r == role:
						present = true
						break
			return present == bool_val

		Enums.TestimonyType.IS_ROLE:
			if world.has("role"):
				return world["role"][targets[0]] == role
			return false

		Enums.TestimonyType.CLAIM_ROLE:
			if world.has("role"):
				return world["role"][speaker] == role
			return true

		Enums.TestimonyType.COUNT_PARITY_IN_SET:
			# bool_val = true → "ÇİFT sayıda kurt" iddiası (0 dahil).
			var cp := 0
			for s in targets:
				if al[s] == Enums.Alignment.EVIL:
					cp += 1
			return (cp % 2 == 0) == bool_val

		Enums.TestimonyType.NEAREST_EVIL_MIN_DIST:
			# GREATER: en yakın kurt number'dan UZAK (d > number).
			# LESS: number'dan YAKIN (d < number). Eşitlik kullanılmaz.
			var dm := BoardTopology.nearest_evil_distance(speaker, _evil_seats(world), n)
			if compare == Enums.Compare.GREATER:
				return dm > number
			return dm < number

		Enums.TestimonyType.WOLF_GAP:
			# En yakın iki kurdun çember mesafesi tam number. Tek kurtla anlamsız → yanlış.
			var ev := _evil_seats(world)
			if ev.size() < 2:
				return false
			var best := n
			for i2 in range(ev.size()):
				for j2 in range(i2 + 1, ev.size()):
					best = mini(best, BoardTopology.distance(int(ev[i2]), int(ev[j2]), n))
			return best == number

		Enums.TestimonyType.OPPOSITE_ALIGNMENT:
			# Tam karşı koltuk (speaker + n/2). Üretici yalnız çift n'de kullanır.
			if n % 2 != 0:
				return false
			return al[(speaker + n / 2) % n] == alignment

		Enums.TestimonyType.VISITOR_COUNT:
			# V3 Gözcü şafak raporu: hedef evlerin (iki kapı komşusu) `day` gecesi
			# aldığı TOPLAM ziyaret sayısı. Gece trafiği aday dünyaya göre yeniden
			# hesaplanır (NightEngine.visitors_by_house — tek doğruluk kaynağı §18).
			# world'de gece kaydı yoksa kısıt üretmez (üretim-anı taban teklik testi).
			if not world.has("nights"):
				return true
			var day_events: Array = []
			for ev in world["nights"]:
				if int(ev.get("day", -1)) == day:
					day_events.append(ev)
			if day_events.is_empty():
				return true
			var houses: Dictionary = NightEngine.visitors_by_house(al, day_events, n)
			var total := 0
			for h in targets:
				total += (houses[h] as Dictionary).size() if houses.has(h) else 0
			return total == number

		Enums.TestimonyType.ATTACKER_DIRECTION:
			# V3.1 Tazı şafak raporu: `day` gecesi `targets[0]` kurbanına saldıran
			# kurdun geliş yönü. Saldıran, aday dünyaya göre yeniden hesaplanır.
			if not world.has("nights"):
				return true
			for ev in world["nights"]:
				if int(ev.get("day", -1)) == day and int(ev.get("victim", -1)) == targets[0]:
					var atk := NightEngine.pick_attacker(al, ev["alive"], targets[0], n)
					if atk < 0:
						return false
					return NightEngine.attack_direction(targets[0], atk, n) == direction
			return true

		_:  ## SELF_ANCHOR / flavor: kısıt üretmez
			return true
