extends Node2D
class_name DamageNumber

const FONT_PATH := "res://assets/fonts/damage_font.ttf"

var _lifetime: float = 1.05
var _elapsed: float = 0.0
var _drift: Vector2 = Vector2.ZERO


func setup(
	amount: float,
	color: Color = Color.WHITE,
	is_dot: bool = false,
	damage_type: String = ""
) -> void:
	z_index = 4096
	z_as_relative = false

	var amount_text: String = str(int(round(amount)))
	var type_text: String = damage_type.to_upper()

	var text: String = amount_text
	if type_text != "" and type_text != "PHYSICAL":
		text = "%s %s" % [amount_text, type_text]

	var font_size: int = _font_size_for(amount)

	if is_dot:
		font_size = max(22, font_size - 10)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)

	# Strong outline so it reads over enemies, floor, effects, etc.
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))

	# Optional custom font.
	# Put a font here: res://assets/fonts/damage_font.ttf
	if ResourceLoader.exists(FONT_PATH):
		var font := load(FONT_PATH) as Font
		if font != null:
			label.add_theme_font_override("font", font)

	var estimated_width: float = float(text.length()) * float(font_size) * 0.45
	label.position = Vector2(-estimated_width * 0.5, -font_size * 0.5)

	add_child(label)

	if is_dot:
		_lifetime = 0.7
		_drift = Vector2(randf_range(-14.0, 14.0), randf_range(-42.0, -28.0))
	else:
		_lifetime = 1.05
		_drift = Vector2(randf_range(-32.0, 32.0), randf_range(-85.0, -60.0))


func _process(delta: float) -> void:
	_elapsed += delta
	var progress: float = _elapsed / _lifetime

	position += _drift * delta
	_drift = _drift.lerp(Vector2.ZERO, delta * 3.0)

	scale = Vector2.ONE * (1.0 + sin(progress * PI) * 0.18)
	modulate.a = 1.0 - max(0.0, (progress - 0.55) / 0.45)

	if _elapsed >= _lifetime:
		queue_free()


func _font_size_for(amount: float) -> int:
	if amount >= 300:
		return 72
	if amount >= 150:
		return 62
	if amount >= 75:
		return 52
	if amount >= 30:
		return 44
	return 36


static func spawn(
	scene_root: Node,
	world_pos: Vector2,
	amount: float,
	color: Color = Color.WHITE,
	is_dot: bool = false,
	damage_type: String = ""
) -> void:
	if amount <= 0.0:
		return

	var dn := DamageNumber.new()
	scene_root.add_child(dn)

	dn.z_index = 4096
	dn.z_as_relative = false
	dn.global_position = world_pos + Vector2(randf_range(-14.0, 14.0), -32.0)

	dn.setup(amount, color, is_dot, damage_type)
