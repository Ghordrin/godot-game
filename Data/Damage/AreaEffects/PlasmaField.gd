extends Area2D
class_name PlasmaField

## Static field left behind by Plasma damage.
## Plasma identity:
## - lingering area control
## - repeated small shocks
## - short micro-stuns

var radius: float = 65.0
var duration: float = 2.5
var tick_rate: float = 0.6
var damage_per_tick: float = 2.0
var stun_duration: float = 0.12

var _elapsed: float = 0.0
var _tick_timer: float = 0.0
var _targets_inside: Array[Node] = []


static func create(world_pos: Vector2, source_damage: float) -> Area2D:
	var field := PlasmaField.new()
	field.global_position = world_pos
	field.damage_per_tick = maxf(1.0, source_damage * 0.10)
	return field


func _ready() -> void:
	z_index = 16

	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0

	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	collision.shape = circle
	add_child(collision)

	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	call_deferred("_enable_detection")

	queue_redraw()


func _enable_detection() -> void:
	set_deferred("monitoring", true)
	set_deferred("monitorable", false)


func _process(delta: float) -> void:
	_elapsed += delta
	_tick_timer += delta

	if _tick_timer >= tick_rate:
		_tick_timer -= tick_rate
		_tick()

	queue_redraw()

	if _elapsed >= duration:
		queue_free()


func _tick() -> void:
	for target in _targets_inside.duplicate():
		if not is_instance_valid(target):
			_targets_inside.erase(target)
			continue

		var enemy_root: Node = _resolve_enemy_root(target)
		if enemy_root == null:
			continue

		var health := enemy_root.get_node_or_null("HealthComponent")
		if health != null and health.has_method("take_damage"):
			health.take_damage(damage_per_tick, "plasma")

		var status := enemy_root.get_node_or_null("StatusEffectComponent") as StatusEffectComponent
		if status != null:
			status.apply_stun(stun_duration)

		DamageNumberSpawner.spawn(
			DamageNumberSpawner.get_anchor_position(enemy_root),
			damage_per_tick,
			DamageVisuals.get_display_name("plasma"),
			DamageVisuals.get_color("plasma"),
			0,
			true
		)

		_draw_mini_arc(enemy_root)


func _resolve_enemy_root(target: Node) -> Node:
	if target == null:
		return null

	if target.is_in_group("enemies"):
		return target

	if target.get_parent() != null and target.get_parent().is_in_group("enemies"):
		return target.get_parent()

	return null


func _on_area_entered(area: Area2D) -> void:
	_add_target(area)


func _on_area_exited(area: Area2D) -> void:
	_remove_target(area)


func _on_body_entered(body: Node2D) -> void:
	_add_target(body)


func _on_body_exited(body: Node2D) -> void:
	_remove_target(body)


func _add_target(target: Node) -> void:
	var enemy_root: Node = _resolve_enemy_root(target)
	if enemy_root == null:
		return

	if not _targets_inside.has(enemy_root):
		_targets_inside.append(enemy_root)


func _remove_target(target: Node) -> void:
	var enemy_root: Node = _resolve_enemy_root(target)
	if enemy_root == null:
		return

	_targets_inside.erase(enemy_root)


func _draw() -> void:
	var life_ratio: float = 1.0 - clampf(_elapsed / duration, 0.0, 1.0)
	var color: Color = DamageVisuals.get_color("plasma")

	draw_circle(
		Vector2.ZERO,
		radius,
		Color(color.r, color.g, color.b, 0.14 * life_ratio)
	)

	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		56,
		Color(color.r, color.g, color.b, 0.9 * life_ratio),
		3.0
	)

	draw_arc(
		Vector2.ZERO,
		radius * 0.45,
		0.0,
		TAU,
		32,
		Color(0.8, 0.9, 1.0, 0.6 * life_ratio),
		2.0
	)


func _draw_mini_arc(enemy_root: Node) -> void:
	if enemy_root == null:
		return
	if not enemy_root is Node2D:
		return

	var enemy_2d := enemy_root as Node2D

	var line := Line2D.new()
	line.z_index = 30
	line.width = 2.0
	line.default_color = DamageVisuals.get_color("plasma")

	line.add_point(global_position)
	line.add_point(enemy_2d.global_position)

	get_tree().current_scene.add_child(line)

	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.12)
	tween.tween_callback(line.queue_free)
