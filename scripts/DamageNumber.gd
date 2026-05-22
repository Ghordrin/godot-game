extends Node2D
class_name DamageNumber

@onready var box: VBoxContainer = $VBoxContainer
@onready var amount_label: Label = $VBoxContainer/AmountLabel
@onready var type_label: Label = $VBoxContainer/TypeLabel

var _lifetime: float = 0.9
var _elapsed: float = 0.0
var _start_pos: Vector2 = Vector2.ZERO
var _centered: bool = false


func setup(
	amount: float,
	damage_type: String,
	color: Color,
	is_dot: bool = false
) -> void:
	z_index = 4096
	z_as_relative = false

	_start_pos = global_position
	_elapsed = 0.0
	_centered = false

	box.position = Vector2.ZERO
	box.size = Vector2.ZERO
	box.custom_minimum_size = Vector2.ZERO

	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	amount_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	type_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

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

	call_deferred("_center_box")


func _center_box() -> void:
	if not is_instance_valid(box):
		return

	var box_size: Vector2 = box.get_combined_minimum_size()

	if box_size.x <= 0.0:
		box_size.x = 120.0
	if box_size.y <= 0.0:
		box_size.y = 70.0

	box.size = box_size
	box.position = -box_size * 0.5
	_centered = true


func _process(delta: float) -> void:
	_elapsed += delta
	var t: float = clamp(_elapsed / _lifetime, 0.0, 1.0)

	global_position = _start_pos + Vector2(0.0, -70.0 * t)

	var pop: float = 1.0 + sin(t * PI) * 0.15
	scale = Vector2.ONE * pop

	modulate.a = 1.0 - max(0.0, (t - 0.55) / 0.45)

	if _elapsed >= _lifetime:
		queue_free()
