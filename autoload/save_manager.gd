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
	"tutorial_done": false,  # sefer başı rehber bir kez gösterilir
	"lang": "tr",            # arayüz dili (tr/en); yeni köyde tam etkinleşir
	"hints_seen": [],        # bağlam ipuçları (H/Y/Otacı) — bir kez gösterilir
	"achievements": [],      # açılan başarım id'leri
	"stat_confronts": 0,     # kalıcı istatistik: yapılan yüzleştirme
	"stat_quiet_dawns": 0,   # kalıcı istatistik: tanık olunan sessiz şafak
}

## Başarım kataloğu (sıra = gösterim sırası). Adlar Loc'ta: "<id>_name".
const ACH_IDS: Array[String] = [
	"ach_first_wolf", "ach_flawless", "ach_quiet_dawn", "ach_hypo_proof",
	"ach_confront", "ach_trap", "ach_run_won", "ach_case",
]


## Test koşumları diske yazmasın (headless test runner false yapar) — başarım/
## istatistik tetikleri gerçek oyuncu kaydını kirletmesin.
var persist_enabled := true


func _ready() -> void:
	load_settings()


## Bağlam ipucu bir kez gösterilir (kalıcı). true = ilk kez, göster.
func first_hint(id: String) -> bool:
	var seen: Array = settings.get("hints_seen", [])
	if id in seen:
		return false
	seen.append(id)
	settings["hints_seen"] = seen
	save_settings()
	return true


## Kalıcı sayaç artır (settings'te yaşar — sefer kaydından bağımsız).
func bump_stat(key: String) -> void:
	settings[key] = int(settings.get(key, 0)) + 1
	save_settings()


## Başarım aç (idempotent). Yeni açıldıysa sinyal yayar (banner UI'da).
func unlock_achievement(id: String) -> void:
	var arr: Array = settings.get("achievements", [])
	if id in arr:
		return
	arr.append(id)
	settings["achievements"] = arr
	save_settings()
	EventBus.achievement_unlocked.emit(id)


func achievement_count() -> int:
	return (settings.get("achievements", []) as Array).size()


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
	if not persist_enabled:
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(settings, "\t"))
	f.close()


func save_game() -> void:
	if not persist_enabled:
		return
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
