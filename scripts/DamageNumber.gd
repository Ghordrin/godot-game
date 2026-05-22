extends Node2D
class_name DamageNumber

@onready var label: Label = $Label

var _lifetime: float = 0.9
var _elapsed: float = 0.0
var _start_pos: Vector2 = Vector2.ZERO


func setup(amount: float, damage_type: String, color: Color, is_dot: bool = false) -> void:
	z_index = 4096
	z_as_relative = false

	_start_pos = global_position
	_elapsed = 0.0

	var text: String = str(int(round(amount)))
	if damage_type != "" and damage_type.to_upper() != "PHYSICAL":
		text += " " + damage_type.to_upper()

	var font_size: int = 42
	if amount >= 75.0:
		font_size = 52
	if amount >= 150.0:
		font_size = 62
	if is_dot:
		font_size = 28

	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color.BLACK)

	var width: float = float(text.length()) * float(font_size) * 0.45
	label.position = Vector2(-width * 0.5, -font_size * 0.5)


func _process(delta: float) -> void:
	_elapsed += delta
	var t: float = clamp(_elapsed / _lifetime, 0.0, 1.0)

	global_position = _start_pos + Vector2(0.0, -70.0 * t)
	scale = Vector2.ONE * (1.0 + sin(t * PI) * 0.12)
	modulate.a = 1.0 - max(0.0, (t - 0.55) / 0.45)

	if _elapsed >= _lifetime:
		queue_free()
