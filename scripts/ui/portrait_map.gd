class_name PortraitMap
extends RefCounted

## Rol id -> portre görseli (şimdilik placeholder tarot-kedi kartları).
## Kurt teması: Kurt=The Moon (kurtlu tarot), Alfa Kurt=The Devil. Final sanat M5.
## Bkz. CLAUDE.md §10 — placeholder sanat, telifsiz üretimle değişecek.

const PATHS := {
	&"Judge": "res://assets/art/portraits/justice.png",
	&"Confessor": "res://assets/art/portraits/judgement.png",
	&"Oracle": "res://assets/art/portraits/priestess.png",
	&"Dreamer": "res://assets/art/portraits/star.png",
	&"Knight": "res://assets/art/portraits/strength.png",
	&"Sentry": "res://assets/art/portraits/chariot.png",
	&"Scout": "res://assets/art/portraits/hermit.png",
	&"Enlightened": "res://assets/art/portraits/hierophant.png",
	&"Architect": "res://assets/art/portraits/wheel.png",
	&"Lover": "res://assets/art/portraits/lovers.png",
	&"Gossip": "res://assets/art/portraits/magician.png",
	# Yeni köylüler (placeholder portreler — final sanat gelene dek paylaşımlı).
	&"Healer": "res://assets/art/portraits/judgement.png",
	&"Weaver": "res://assets/art/portraits/wheel.png",
	&"Midwife": "res://assets/art/portraits/temperance.png",
	&"Milkmaid": "res://assets/art/portraits/star.png",
	&"Crier": "res://assets/art/portraits/magician.png",
	&"Beekeeper": "res://assets/art/portraits/hermit.png",
	&"Astrologer": "res://assets/art/portraits/emperor.png",
	&"Slayer": "res://assets/art/portraits/strength.png",
	&"Hunter": "res://assets/art/portraits/chariot.png",
	&"Saint": "res://assets/art/portraits/temperance.png",
	&"Baker": "res://assets/art/portraits/temperance.png",
	&"Minion": "res://assets/art/portraits/moon.png",
	&"Demon": "res://assets/art/portraits/devil.png",
}

static var _cache := {}

static func texture(role: StringName) -> Texture2D:
	if not PATHS.has(role):
		return null
	if _cache.has(role):
		return _cache[role]
	var tex := load(PATHS[role]) as Texture2D
	_cache[role] = tex
	return tex
