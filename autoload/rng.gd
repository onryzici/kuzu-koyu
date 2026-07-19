extends Node

## Seed'li rastlantı sağlayıcısı. Kural (§13.6): randi()/randf() DOĞRUDAN
## kullanma; hep buradan al. Aynı seed = aynı sefer/köy (daily, test, bug-repro).

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

## Sefer/köy başında sabit tohum ata (reproducibility).
func seed_with(s: int) -> void:
	_rng.seed = s

func randomize_seed() -> int:
	_rng.randomize()
	return int(_rng.seed)

func rng() -> RandomNumberGenerator:
	return _rng

func current_seed() -> int:
	return int(_rng.seed)
