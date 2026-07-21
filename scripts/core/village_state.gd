class_name VillageState
extends Resource

## Seri hale getirilebilir tüm köy durumu. Bkz. CLAUDE.md §0.5 (V2) ve §13.3.
## Motor (solver/generator/night) ve UI bu tek state üzerinden çalışır.

@export var n: int = 0
@export var characters: Array[Character] = []
@export var evil_count: int = 0
@export var minion_count: int = 0
@export var demon_count: int = 0
@export var outcast_count: int = 0           ## toplam parya (kompozisyon rozeti)
@export var drunk_count: int = 0              ## kaç parya SARHOŞ (solver: tanıklığı serbest)
@export var anchors: Array = []                    ## kesin GOOD bilinen seat'ler
@export var omen_type: int = Enums.OmenType.NONE   ## GERÇEK Omen (ground truth)
@export var omen_params: Dictionary = {}           ## Omen parametreleri (varsa)
@export var known_omen: int = Enums.OmenType.NONE  ## oyuncunun BİLDİĞİ Omen (Müneccim ifşa edince)
@export var spread_active: bool = false            ## legacy (v2 akışında kullanılmaz)
@export var seed: int = 0
@export var marks: Array = []                      ## seat -> Enums.MarkType

# --- V2: Sorgu & Gece (bkz. §0.5) ---
@export var day: int = 1                     ## 1'den başlar
@export var q_per_day: int = 3               ## günlük sorgu hakkı
@export var questions_left: int = 3          ## bugün kalan sorgu
@export var max_days: int = 5                ## bu şafak sayısı dolunca köy düşer
@export var kills_per_night: int = 1         ## gece başına kurban (boss: 2)
@export var night_rule: int = Enums.NightRule.NEAREST  ## av düzeni (İLAN edilir)
@export var cull_damage: int = 5             ## yanlış avlama can cezası (Kuraklık: 7)
@export var modifiers: Array = []            ## köy kuralları ("silent"...) — İLAN edilir (§7.3)
@export var trap_seat: int = -1              ## Tuzakçı kapanı (bu gece; -1 = yok)
@export var night_events: Array = []         ## [{alive: Array[int], victim: int, day: int}]
@export var last_questioned: int = -1        ## V3: bugün EN SON sorgulanan (Otacı hedefi; şafakta -1)
@export var alternating_rule: bool = false   ## V3.1: Dönek Alfa — kural gece gece değişir (İLAN)
@export var confronted: Dictionary = {}      ## V3.1: yapılan yüzleştirmeler ("a:b" -> true)


## Ground truth: gerçek alignment + rol. Generator doğrulaması ve testler için.
func ground_truth_world() -> Dictionary:
	var al: Array = []
	var rl: Array = []
	var evil_seats: Array = []
	for c in characters:
		al.append(c.alignment)
		rl.append(c.role)
		if c.is_evil() and not c.executed:
			evil_seats.append(c.seat)
	return {"n": n, "alignment": al, "role": rl, "evil_seats": evil_seats}


## Canlı (tahtada) seat'ler — gece avı ve sorgu havuzu.
func alive_seats() -> Array:
	var out: Array = []
	for c in characters:
		if c.is_alive():
			out.append(c.seat)
	return out


func alive_good_count() -> int:
	var k := 0
	for c in characters:
		if c.is_alive() and not c.is_evil():
			k += 1
	return k


func alive_evil_count() -> int:
	var k := 0
	for c in characters:
		if c.is_alive() and c.is_evil():
			k += 1
	return k


## Solver'ın gördüğü durum (V2): VERİLMİŞ tüm ifadeler (ölülerinki dahil — geçmiş
## ifadeler geçerli kalır), kesinleşmiş kimlikler (ayıklanan/gece ölen) ve gece
## olayları. Bkz. §0.5 ve §5.8.
func visible_for_solver() -> Dictionary:
	var claims_out: Array = []
	var known: Array = []
	for c in characters:
		for k in range(c.given):
			claims_out.append({"seat": c.seat, "testimony": c.claims[k]})
		if c.executed or c.night_killed:
			# Ayıklanan: gerçek yüzü açıldı. Gece ölen: kurt yalnız koyun yer → kesin İYİ.
			known.append({"seat": c.seat, "alignment": c.alignment})
	return {
		"n": n,
		"evil_count": evil_count,
		"anchors": anchors.duplicate(),
		"revealed": claims_out,
		"known": known,
		"nights": night_events.duplicate(true),
		"known_omen": known_omen,
		"omen_params": omen_params.duplicate(),
		"drunk_count": drunk_count,
	}


func get_character(seat: int) -> Character:
	return characters[seat]
