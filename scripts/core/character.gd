class_name Character
extends Resource

## Bir Seat'teki karakterin gerçek kimliği + oyuncuya görünen durumu.
## Bkz. CLAUDE.md §0.5 (V2) ve §5.2. V2: kapalı kart YOK — herkes baştan iddia
## ettiği rolüyle (shown_role) görünür; gerçek yüz yalnız ayıklanınca ya da gece
## kurda yem olunca açığa çıkar.
##
## V2 ifade modeli: her karakterin birden çok ifadesi (claims) vardır; sorgulandıkça
## sırayla verir (given sayacı). Kurt HER ifadesinde yalan söyler → tekrar sorgu,
## yalancının kendini ele vermesidir.

@export var seat: int = 0
@export var role: StringName = &""              ## gerçek rol
@export var alignment: int = Enums.Alignment.GOOD
@export var category: int = Enums.Category.VILLAGER
@export var bluff_role: StringName = &""         ## yalnız EVIL'de; sahte görünen rol
@export var revealed: bool = false               ## GERÇEK yüz açık mı (ayıklandı/öldü)
@export var executed: bool = false               ## oyuncu ayıkladı
@export var night_killed: bool = false           ## gece kurda yem oldu (kesin İYİ)
@export var ability_used: bool = false           ## aktif yetenek harcandı mı (Kılıççı vb.)
@export var claims: Array = []                   ## Array[TestimonyClaim] — tüm ifadeler
@export var given: int = 0                       ## şimdiye dek verdiği ifade sayısı
@export var testimony: TestimonyClaim            ## SON verilen ifade (UI balonu; null=henüz yok)
@export var claim_days: Array = []               ## verilen her ifadenin GÜNÜ (İfade Defteri)

func is_evil() -> bool:
	return alignment == Enums.Alignment.EVIL

## Hayatta ve tahtada mı (sorgulanabilir/ayıklanabilir)?
func is_alive() -> bool:
	return not executed and not night_killed

## Oyuncuya gösterilecek rol: EVIL ise bluff, aksi halde gerçek rol.
func shown_role() -> StringName:
	if is_evil() and bluff_role != &"":
		return bluff_role
	return role

## Sorgulanacak yeni ifadesi kaldı mı?
func has_more_claims() -> bool:
	return given < claims.size()
