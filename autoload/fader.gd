extends CanvasLayer

## Global sahne geçişi: karart → sahne değiştir → aç. Oyunda HİÇBİR sahne artık
## "pat" diye değişmez; her geçiş kısa bir siyah fade'den geçer. Geçiş sırasında
## tıklamalar yutulur (yarım geçişte çift tık kazası olmasın).

var _rect: ColorRect
var _busy := false


func _ready() -> void:
	layer = 500  # her şeyin üstü (duraklat menüsü dahil)
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)


## Fade'li sahne değişimi. Geçiş sürerken gelen ikinci istek yok sayılır.
func change_scene(path: String, dur := 0.28) -> void:
	if _busy:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_rect, "color:a", 1.0, dur).set_trans(Tween.TRANS_SINE)
	await t.finished
	get_tree().change_scene_to_file(path)
	# Yeni sahnenin ilk karesi otursun, sonra aç.
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property(_rect, "color:a", 0.0, dur * 1.25).set_trans(Tween.TRANS_SINE)
	await t2.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
