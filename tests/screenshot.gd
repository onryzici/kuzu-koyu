extends Node
const SIZE := Vector2i(1600, 900)
const OUT := "user://board_shot.png"
var _t := 0.0
var _armed := false
var _sub: SubViewport
func _ready() -> void:
	get_window().size = SIZE
	_sub = SubViewport.new()
	_sub.size = SIZE
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sub)
	var r: Control = load("res://scenes/village_board.tscn").instantiate()
	_sub.add_child(r)
	r.size = SIZE
func _process(dt: float) -> void:
	_t += dt
	if not _armed and _t > 2.4:
		_armed = true
		RenderingServer.frame_post_draw.connect(_capture, CONNECT_ONE_SHOT)
	if _t > 7.0: get_tree().quit(2)
func _capture() -> void:
	_sub.get_texture().get_image().save_png(OUT)
	print("SHOT_SAVED"); get_tree().quit(0)
