extends Area2D
class_name ThermalPatch

## Burning ground left behind by Thermal damage.
## Thermal identity:
## - persistent area damage
## - good against regenerating enemies
## - light pressure against armored enemies

var radius: float = 55.0
var duration: float = 3.0
var tick_rate: float = 0.5
var damage_per_tick: float = 2.0
var armor_pressure_fraction: float = 0.15
var armor_pressure_duration: float = 1.0

var _elapsed: float = 0.0
var _tick_timer: float = 0.0
var _targets_inside: Array[Node] = []


static func create(world_pos: Vector2, source_damage: float) -> Area2D:
	var patch := ThermalPatch.new()
	patch.global_position = world_pos
	patch.damage_per_tick = maxf(1.0, source_damage * 0.12)
	return patch


func _ready() -> void:
	z_index = 15

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
			health.take_damage(damage_per_tick, "fire")

		var armor := enemy_root.get_node_or_null("ArmorComponent")
		if armor != null and armor.has_method("apply_pressure"):
			armor.apply_pressure(
				armor_pressure_fraction,
				armor_pressure_duration
			)

		DamageNumberSpawner.spawn(
			DamageNumberSpawner.get_anchor_position(enemy_root),
			damage_per_tick,
			DamageVisuals.get_display_name("fire"),
			DamageVisuals.get_color("fire"),
			0,
			true
		)


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
	var color: Color = DamageVisuals.get_color("thermal")

	draw_circle(
		Vector2.ZERO,
		radius,
		Color(color.r, color.g, color.b, 0.18 * life_ratio)
	)

	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		48,
		Color(color.r, color.g, color.b, 0.85 * life_ratio),
		3.0
	)

	draw_arc(
		Vector2.ZERO,
		radius * 0.55,
		0.0,
		TAU,
		32,
		Color(1.0, 0.35, 0.05, 0.45 * life_ratio),
		2.0
	)
