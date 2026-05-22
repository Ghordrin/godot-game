extends Node2D
class_name DamageNumber

## Floating damage number using Label nodes for reliable rendering.
## Labels are children of this Node2D so they follow world-space position.

var _lifetime: float = 1.0
var _elapsed: float  = 0.0
var _drift: Vector2  = Vector2.ZERO


func setup(amount: float, color: Color = Color.WHITE, is_dot: bool = false) -> void:
	var text      := str(int(round(amount)))
	var font_size := _font_size_for(amount)

	# DOT ticks are smaller and more transparent so they don't crowd the screen
	if is_dot:
		font_size = max(14, font_size - 8)

	var cx: float = -float(text.length()) * float(font_size) * 0.28

	var shadow := Label.new()
	shadow.text = text
	shadow.add_theme_font_size_override("font_size", font_size)
	shadow.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 0.85))
	shadow.position = Vector2(cx + 2.0, 2.0)
	add_child(shadow)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.position = Vector2(cx, 0.0)
	add_child(label)

	# DOT ticks drift less and fade faster
	if is_dot:
		_lifetime = 0.6
		_drift = Vector2(randf_range(-15.0, 15.0), randf_range(-40.0, -25.0))
	else:
		_drift = Vector2(randf_range(-35.0, 35.0), randf_range(-70.0, -50.0))


func _process(delta: float) -> void:
	_elapsed += delta
	var progress: float = _elapsed / _lifetime

	# Move upward along drift, slowing down over time
	position  += _drift * delta
	_drift    = _drift.lerp(Vector2.ZERO, delta * 3.5)

	# Fade out in the second half of lifetime
	modulate.a = 1.0 - max(0.0, (progress - 0.4) / 0.6)

	if _elapsed >= _lifetime:
		queue_free()


func _font_size_for(amount: float) -> int:
	if amount >= 200: return 52
	if amount >= 100: return 44
	if amount >= 40:  return 36
	return 28


## Spawn a damage number at a world position.
static func spawn(
	scene_root: Node,
	world_pos: Vector2,
	amount: float,
	color: Color = Color.WHITE,
	is_dot: bool = false
) -> void:
	if amount <= 0.0:
		return
	var dn := DamageNumber.new()
	scene_root.add_child(dn)
	dn.global_position = world_pos + Vector2(randf_range(-8.0, 8.0), -15.0)
	dn.setup(amount, color, is_dot)
