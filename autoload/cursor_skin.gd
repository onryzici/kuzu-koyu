extends Node

## Özel imleç: koyun patisi (tema — çoban fantezisi). Tüm ekranlarda geçerli.
## Hotspot sol-üst parmak ucuna yakın: tıklama hissi pati ucundan gelsin.
## NOT: load() (preload değil) — asset import edilmemişken bile autoload derlensin
## (audio_manager.gd ile aynı tavuk-yumurta önlemi).

const CURSOR_PATH := "res://assets/art/ui/cursor_paw.png"
const HOTSPOT := Vector2(8, 5)


func _ready() -> void:
	var tex := load(CURSOR_PATH)
	if tex == null:
		return
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, HOTSPOT)
	# Buton/kart üstü el imleci de pati kalsın (form dili tek olsun).
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_POINTING_HAND, HOTSPOT)
