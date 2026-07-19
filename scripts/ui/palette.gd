class_name Palette
extends RefCounted

## NAZAR çekirdek renk paleti. Bkz. CLAUDE.md §10.2.
## Tek yerde; tüm UI buradan okur.

const NIGHT_INDIGO := Color("1B2A4A")
const TILE_BLUE := Color("2E6E8E")
const IVORY := Color("EDE3C8")
const SAFFRON := Color("E4A72E")
const COPPER := Color("C9743B")
const CRIMSON := Color("8E1B1B")
const BLOOD := Color("B3272D")
const SOOT := Color("0E0A0A")
const NAZAR := Color("0E5AA7")
const VIOLET := Color("7A5FB0")  ## (eski Villager rengi; artık sıcak temaya geçildi)
const BRONZE := Color("A9713A")  ## Villager çerçevesi — sıcak bronz (kart2 altınına uyumlu)

## Kategori çerçeve renkleri — HEPSİ SICAK TON (bronz→altın→kızıl), maroon/altın
## kart2 temasıyla aynı ailede. Villager bronz, Outcast altın-amber, Evil kızıl.
static func category_color(category: int) -> Color:
	match category:
		Enums.Category.VILLAGER:
			return BRONZE
		Enums.Category.OUTCAST:
			return SAFFRON
		Enums.Category.MINION, Enums.Category.DEMON:
			return BLOOD
		_:
			return COPPER


static func mark_color(mark: int) -> Color:
	match mark:
		Enums.MarkType.MARK_GOOD:
			return Color("3FBF6B")
		Enums.MarkType.MARK_SUSPECT:
			return SAFFRON
		Enums.MarkType.MARK_EVIL:
			return BLOOD
		Enums.MarkType.MARK_QUESTION:
			return Color("E8D44D")
		_:
			return Color(1, 1, 1, 0)


## Renk-körü erişilebilirliği için şekil farkı da taşınır (§11).
static func mark_glyph(mark: int) -> String:
	match mark:
		Enums.MarkType.MARK_GOOD:
			return "▲"
		Enums.MarkType.MARK_SUSPECT:
			return "◆"
		Enums.MarkType.MARK_EVIL:
			return "✖"
		Enums.MarkType.MARK_QUESTION:
			return "!"
		_:
			return ""
