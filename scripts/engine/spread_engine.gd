class_name SpreadEngine
extends RefCounted

## Spread (Yayılan Köy) — lanet her tetikte DETERMİNİSTİK bir kurala göre bir adım
## yayılır. Bkz. CLAUDE.md §5.6. Saf mantık; UI değil.
##
## Varsayılan kural (MOST_ADJACENT): tetikte, hâlâ İYİ olan (arındırılmamış, anchor
## olmayan) kartlar arasında EN ÇOK arındırılmamış Evil'e komşu olan kart lanetlenir.
## Beraberlik → saat yönünde ilk (en küçük seat). Hiçbir iyi kart Evil'e komşu değilse
## bu tur yayılma OLMAZ (-1 döner).
##
## Lanetlenen kart: alignment EVIL, category MINION, yeni bir bluff_role + YENİ yanlış
## tanıklık; eski (doğru) ifadesi geçersizleşir (yerine yalan gelir).


## Bu tetikte lanetlenecek seat (yoksa -1).
static func next_spread_target(state: VillageState) -> int:
	var n: int = state.n
	var best := -1
	var best_count := 0
	for i in range(n):
		var c: Character = state.get_character(i)
		if c.is_evil() or c.executed:
			continue
		if i in state.anchors:  # anchor = kesin GOOD, lanetlenemez (adalet)
			continue
		var cnt := 0
		for nb in BoardTopology.neighbors(i, n):
			var nc: Character = state.get_character(nb)
			if nc.is_evil() and not nc.executed:
				cnt += 1
		# `>` kullanımı -> beraberlikte en küçük seat (saat yönünde ilk) kalır.
		if cnt > best_count:
			best_count = cnt
			best = i
	return best


## Lanet bir adım yayılır: hedefi bul, MINION'a çevir, yeni yalan tanıklık ver.
## Döndürür: lanetlenen seat (yayılma olmadıysa -1). rng seed'li olmalı.
static func apply(state: VillageState, rng: RandomNumberGenerator) -> int:
	var seat := next_spread_target(state)
	if seat < 0:
		return -1
	var c: Character = state.get_character(seat)
	c.alignment = Enums.Alignment.EVIL
	c.category = Enums.Category.MINION
	c.role = &"Minion"
	c.bluff_role = VillageGenerator.GOOD_ROLES[rng.randi() % VillageGenerator.GOOD_ROLES.size()]

	state.evil_count += 1
	state.minion_count += 1

	# Yeni yalan: artık evil olduğu için ground truth'u ihlal eden bir claim.
	var world := state.ground_truth_world()
	c.testimony = VillageGenerator.make_false_claim(c.bluff_role, seat, world, state.n, rng)
	c.testimony.text = TestimonyText.phrase(c.bluff_role, c.testimony, rng)
	return seat


## Spread modu kayıp koşulu: arındırılmamış Evil sayısı köyün yarısını GEÇERSE.
static func spread_lost(state: VillageState) -> bool:
	var evil := 0
	for c in state.characters:
		if c.is_evil() and not c.executed:
			evil += 1
	return evil * 2 > state.n
