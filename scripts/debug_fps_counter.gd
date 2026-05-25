extends CanvasLayer

@export var update_interval: float = 0.25
@export var show_by_default: bool = true

var _label: Label = null
var _update_timer: float = 0.0


func _ready() -> void:
	layer = 128
	visible = show_by_default
	_create_label()
	_update_label()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_debug_stats"):
		visible = not visible

	if not visible:
		return

	_update_timer -= delta

	if _update_timer > 0.0:
		return

	_update_timer = update_interval
	_update_label()


func _create_label() -> void:
	_label = Label.new()
	_label.name = "FPSLabel"
	_label.position = Vector2(12.0, 12.0)
	_label.z_index = 4096
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85, 1.0))
	_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_label)


func _update_label() -> void:
	if _label == null:
		return

	_label.text = "FPS: %d" % Engine.get_frames_per_second()
