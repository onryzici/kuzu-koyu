class_name PortraitMap
extends RefCounted

## Rol id -> portre görseli (şimdilik placeholder tarot-kedi kartları).
## Kurt teması: Kurt=The Moon (kurtlu tarot), Alfa Kurt=The Devil. Final sanat M5.
## Bkz. CLAUDE.md §10 — placeholder sanat, telifsiz üretimle değişecek.

const PATHS := {
	&"Judge": "res://assets/art/portraits/judge.png",  # final sanat (kullanıcı üretimi)
	&"Confessor": "res://assets/art/portraits/confessor.png",  # final sanat (kullanıcı üretimi)
	&"Oracle": "res://assets/art/portraits/oracle.png",  # final sanat (kullanıcı üretimi)
	&"Dreamer": "res://assets/art/portraits/dreamer.png",  # final sanat (kullanıcı üretimi)
	&"Knight": "res://assets/art/portraits/knight.png",  # final sanat (kullanıcı üretimi)
	&"Sentry": "res://assets/art/portraits/sentry.png",  # final sanat (kullanıcı üretimi)
	&"Scout": "res://assets/art/portraits/scout.png",  # final sanat (kullanıcı üretimi)
	&"Enlightened": "res://assets/art/portraits/enlightened.png",  # final sanat (kullanıcı üretimi)
	&"Architect": "res://assets/art/portraits/architect.png",  # final sanat (kullanıcı üretimi)
	&"Lover": "res://assets/art/portraits/lover.png",  # final sanat (kullanıcı üretimi)
	&"Gossip": "res://assets/art/portraits/gossip.png",  # final sanat (kullanıcı üretimi)
	# Yeni köylüler (placeholder portreler — final sanat gelene dek paylaşımlı).
	&"Healer": "res://assets/art/portraits/healer.png",  # final sanat (kullanıcı üretimi)
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
	# Boş kalan roller — paylaşımlı placeholder (kullanıcı isteği: "boş karakter
	# kalmasın"; final sanat M5'te hepsini değiştirecek).
	&"Sheepdog": "res://assets/art/portraits/strength.png",
	&"Shearer": "res://assets/art/portraits/wheel.png",
	&"Drummer": "res://assets/art/portraits/magician.png",
	&"Welldigger": "res://assets/art/portraits/hermit.png",
	&"Beadcounter": "res://assets/art/portraits/priestess.png",
	&"Skittish": "res://assets/art/portraits/star.png",
	&"Tailor": "res://assets/art/portraits/justice.png",
	&"Mirrorwright": "res://assets/art/portraits/lovers.png",
	&"Trapper": "res://assets/art/portraits/hierophant.png",
	&"Jinxed": "res://assets/art/portraits/moon.png",
	&"Herbalist": "res://assets/art/portraits/temperance.png",
	&"Watcher": "res://assets/art/portraits/priestess.png",
	&"Wanderer": "res://assets/art/portraits/hermit.png",
	&"Hound": "res://assets/art/portraits/chariot.png",
	&"Minion": "res://assets/art/portraits/minion.png",  # final sanat (kullanıcı üretimi)
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
