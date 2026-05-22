extends Node2D
class_name DamageNumber

@onready var amount_label: Label = $VBoxContainer/AmountLabel
@onready var type_label: Label = $VBoxContainer/TypeLabel

var _lifetime: float = 0.9
var _elapsed: float = 0.0
var _start_pos: Vector2


func setup(
	amount: float,
	damage_type: String,
	color: Color,
	is_dot: bool = false
) -> void:
	z_index = 4096
	z_as_relative = false

	_start_pos = global_position

	amount_label.text = str(int(round(amount)))
	type_label.text = damage_type.to_upper()

	amount_label.add_theme_color_override("font_color", color)
	type_label.add_theme_color_override("font_color", color)

	amount_label.add_theme_font_size_override("font_size", 48 if not is_dot else 28)
	type_label.add_theme_font_size_override("font_size", 18 if not is_dot else 12)

	amount_label.add_theme_constant_override("outline_size", 5)
	type_label.add_theme_constant_override("outline_size", 4)

	amount_label.add_theme_color_override("font_outline_color", Color.BLACK)
	type_label.add_theme_color_override("font_outline_color", Color.BLACK)


func _process(delta: float) -> void:
	_elapsed += delta
	var t: float = _elapsed / _lifetime

	global_position = _start_pos + Vector2(0, -70.0 * t)
	scale = Vector2.ONE * (1.0 + sin(t * PI) * 0.15)
	modulate.a = 1.0 - max(0.0, (t - 0.55) / 0.45)

	if _elapsed >= _lifetime:
		queue_free()
