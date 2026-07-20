class_name Enums
extends RefCounted

## Tek doğruluk kaynağı: tüm oyun genelindeki enum'lar.
## Bkz. CLAUDE.md §2 (Sözlük) ve §9 (Veri Modeli).
## Node'a bağımlı değil; motor ve UI ikisi de buradan okur.

enum Alignment { GOOD, EVIL }

enum Category { VILLAGER, OUTCAST, MINION, DEMON }

## Bir tanıklığın yapısal tipi. Bkz. CLAUDE.md §5.3.
enum TestimonyType {
	CLAIM_ROLE,             ## "Ben gerçek Baker'ım"
	ALIGNMENT_OF,           ## "#3 Evil"
	IS_ROLE,                ## "#5 İblis"
	COUNT_IN_SET,           ## "#1,#2 arasında tam N Evil var"
	EVIL_COUNT_IN_REGION,   ## "Sol taraf daha Evil"
	NEAREST_EVIL_DIRECTION, ## "En yakın Evil saat yönünün tersinde"
	NEAREST_EVIL_DISTANCE,  ## "En yakın Evil'e N kart uzaktayım"
	NEIGHBOR_HAS_EVIL,      ## "Komşularımdan biri Evil"
	ROLE_PRESENT,           ## "Oyunda bir Knight var"
	PAIR_RELATION,          ## "#1 ve #4 aynı alignment'ta"
	SELF_ANCHOR,            ## flavor / ankraj
	COUNT_PARITY_IN_SET,    ## "Şu kartlardaki kurt sayısı TEK/ÇİFT" (mod-2 kısıtı)
	NEAREST_EVIL_MIN_DIST,  ## "En yakın kurt bana K'dan UZAK/YAKIN" (eşitsizlik)
	WOLF_GAP,               ## "En yakın iki kurdun arası tam K adım" (kurtlar-arası yapı)
	OPPOSITE_ALIGNMENT,     ## "Tam karşımdaki koltuk kurt/temiz" (yalnız çift n)
}

## En yakın Evil'e yön. Seat index saat yönünde artar.
enum Direction { CLOCKWISE, COUNTER_CLOCKWISE, EQUIDISTANT }

## Gizli kural kategorileri. Bkz. CLAUDE.md §5.5.
enum OmenType { PARITY, CONTIGUOUS_ARC, DISPERSED, MIRROR, SUIT, DEMON_DISTANCE, SEAL_EQUIDISTANT, SAME_SIDE, NONE }

## Oyuncunun karta koyduğu renkli not. Bkz. CLAUDE.md §7.5.
enum MarkType { NONE, MARK_GOOD, MARK_SUSPECT, MARK_EVIL, MARK_QUESTION }

## Üst seviye durum makinesi. Bkz. CLAUDE.md §13.5.
enum GamePhase { SETUP, REVEAL_IDLE, ABILITY_TARGETING, EXECUTE_CONFIRM, RESOLVE, SPREAD, VILLAGE_END }

## Gece Av Düzeni varyantı: NEAREST = klasik (en yakın koyun),
## FARTHEST = sisli gece (kurt en uzağı avlar). Köyde İLAN edilir.
enum NightRule { NEAREST, FARTHEST }

## Karşılaştırma yönü (Architect / EVIL_COUNT_IN_REGION için).
enum Compare { LESS, EQUAL, GREATER }

## Sefer haritası düğüm tipleri. Bkz. CLAUDE.md §4. MVP: VILLAGE + BOSS.
enum NodeType { VILLAGE, ELITE, BOSS, SHOP, EVENT }

## Bir seferin son durumu (RunManager + UI için).
enum RunOutcome { NONE, VILLAGE_WON, RUN_WON, RUN_LOST }
