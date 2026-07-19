extends Node

## user://save.json — meta ilerleme + aktif sefer (seed + ilerleme). Bkz. §13.6.
## Şema versiyonlu JSON. Köy state kaydedilmez; seed'den yeniden üretilir.

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const SCHEMA_VERSION := 1

## Oyuncu ayarları (sefer kaydından bağımsız; her zaman diske yazılır).
## Ses seviyeleri 0..1 doğrusal; AudioManager bunları dB'ye çevirip bus'lara uygular.
var settings := {
	"vol_master": 0.9,
	"vol_music": 0.6,
	"vol_sfx": 1.0,
	"fullscreen": true,
}


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for k in settings.keys():
		if parsed.has(k):
			settings[k] = parsed[k]


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(settings, "\t"))
	f.close()


func save_game() -> void:
	var data := RunManager.to_save_dict()
	data["version"] = SCHEMA_VERSION
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: kayıt açılamadı: %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: bozuk kayıt")
		return false
	RunManager.restore(parsed)
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
