extends Node2D
class_name DamageNumber

var _lifetime: float = 1.0
var _elapsed: float = 0.0
var _drift: Vector2 = Vector2.ZERO


func setup(
	amount: float,
	color: Color = Color.WHITE,
	is_dot: bool = false,
	damage_type: String = ""
) -> void:
	var amount_text: String = str(int(round(amount)))
	var type_text: String = damage_type.to_upper()

	var text: String = amount_text
	if type_text != "" and type_text != "PHYSICAL":
		text = "%s %s" % [amount_text, type_text]

	var font_size: int = _font_size_for(amount)

	if is_dot:
		font_size = max(14, font_size - 8)

	var cx: float = -float(text.length()) * float(font_size) * 0.18

	var shadow := Label.new()
	shadow.text = text
	shadow.add_theme_font_size_override("font_size", font_size)
	shadow.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 0.9))
	shadow.position = Vector2(cx + 2.0, 2.0)
	add_child(shadow)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.position = Vector2(cx, 0.0)
	add_child(label)

	if is_dot:
		_lifetime = 0.65
		_drift = Vector2(randf_range(-12.0, 12.0), randf_range(-35.0, -22.0))
	else:
		_lifetime = 0.95
		_drift = Vector2(randf_range(-28.0, 28.0), randf_range(-65.0, -45.0))


func _process(delta: float) -> void:
	_elapsed += delta
	var progress: float = _elapsed / _lifetime

	position += _drift * delta
	_drift = _drift.lerp(Vector2.ZERO, delta * 3.5)

	modulate.a = 1.0 - max(0.0, (progress - 0.4) / 0.6)

	if _elapsed >= _lifetime:
		queue_free()


func _font_size_for(amount: float) -> int:
	if amount >= 200:
		return 46
	if amount >= 100:
		return 40
	if amount >= 40:
		return 34
	return 26


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
	dn.global_position = world_pos + Vector2(randf_range(-10.0, 10.0), -20.0)
	dn.setup(amount, color, is_dot, damage_type)
