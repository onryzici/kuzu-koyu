extends Node

## YERELLEŞTİRME (tr/en). UI metinleri anahtar tablolarından geçer: Loc.t("key").
## Tablolar modüllere bölünmüştür (çakışmasız bakım): LocTableCore / LocTableBoard /
## LocTableMeta — her biri `const T := {key: {"tr": ..., "en": ...}}`.
## Rol adları/ifade metinleri gibi büyük katalog dosyaları (role_names,
## testimony_text, omen) kendi içlerinde Loc.lang'a bakar.
## NOT: Üretilmiş ifade metinleri (claim.text) köy üretiminde yazılır — dil
## değişikliği YENİ köyde tam etkinleşir (ayarlar ekranı bunu söyler).

var lang := "tr"
var _table := {}


func _ready() -> void:
	lang = String(SaveManager.settings.get("lang", "tr"))
	for src in [LocTableCore.T, LocTableBoard.T, LocTableMeta.T]:
		_table.merge(src)


## Anahtar → aktif dildeki metin. Anahtar yoksa (geliştirme hatası) anahtarın
## kendisi döner — eksik çeviri ekranda görünür olur, sessizce kaybolmaz.
func t(key: String) -> String:
	var e = _table.get(key)
	if e == null:
		return key
	return e.get(lang, e.get("tr", key))


func set_lang(l: String) -> void:
	lang = l
	SaveManager.settings["lang"] = l
	SaveManager.save_settings()
