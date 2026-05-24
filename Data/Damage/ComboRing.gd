# scripts/ComboRing.gd
extends Node2D
class_name ComboRing

var ring_color: Color = Color.WHITE
var max_radius: float = 64.0
var _radius: float    = 0.0
var _alpha: float     = 0.85


func _ready() -> void:
	z_index = 12
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_method(
		func(r: float) -> void: _radius = r; queue_redraw(),
		0.0, max_radius, 0.35
	)
	tw.tween_method(
		func(a: float) -> void: _alpha = a; queue_redraw(),
		0.85, 0.0, 0.35
	)
	tw.chain().tween_callback(queue_free)


func _draw() -> void:
	if _radius <= 0.0:
		return

	# Stronger filled glow
	draw_circle(
		Vector2.ZERO,
		_radius,
		Color(ring_color.r, ring_color.g, ring_color.b, _alpha * 0.28)
	)

	# Main outer ring
	draw_arc(
		Vector2.ZERO,
		_radius,
		0.0,
		TAU,
		64,
		Color(ring_color.r, ring_color.g, ring_color.b, _alpha),
		6.0
	)

	# Inner ring
	draw_arc(
		Vector2.ZERO,
		_radius * 0.5,
		0.0,
		TAU,
		48,
		Color(ring_color.r, ring_color.g, ring_color.b, _alpha * 0.7),
		3.0
	)
