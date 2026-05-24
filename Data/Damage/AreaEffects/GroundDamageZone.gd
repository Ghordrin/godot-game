extends Node2D
class_name GroundDamageZone

@export var radius: float = 80.0
@export var duration: float = 3.0
@export var tick_rate: float = 0.5
@export var damage_per_tick: float = 2.0
@export var damage_type: String = "fire"
@export var visual_color: Color = Color(1.0, 0.35, 0.1, 0.35)

@export var apply_burn: bool = false
@export var burn_duration: float = 2.0
@export var burn_tick_rate: float = 0.5

var elapsed: float = 0.0
var tick_timer: float = 0.0


func _ready() -> void:
	add_to_group("ground_damage_zones")
	z_index = 4


func configure(
	new_radius: float,
	new_duration: float,
	new_tick_rate: float,
	new_damage_per_tick: float,
	new_damage_type: String,
	new_visual_color: Color,
	should_apply_burn: bool = false
) -> void:
	radius = new_radius
	duration = new_duration
	tick_rate = new_tick_rate
	damage_per_tick = new_damage_per_tick
	damage_type = new_damage_type
	visual_color = new_visual_color
	apply_burn = should_apply_burn


func _process(delta: float) -> void:
	elapsed += delta
	tick_timer += delta

	if tick_timer >= tick_rate:
		tick_timer -= tick_rate
		_tick_damage()

	if elapsed >= duration:
		queue_free()

	queue_redraw()


func _tick_damage() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		if not enemy is Node2D:
			continue

		var enemy_2d := enemy as Node2D
		var distance := global_position.distance_to(enemy_2d.global_position)

		if distance > radius:
			continue

		_damage_enemy(enemy_2d)


func _damage_enemy(enemy: Node2D) -> void:
	var health_component := enemy.get_node_or_null("HealthComponent") as HealthComponent

	if health_component == null:
		return

	health_component.take_damage(damage_per_tick, damage_type)

	DamageMeter.record(damage_per_tick, damage_type)

	DamageNumberSpawner.spawn(
		DamageNumberSpawner.get_anchor_position(enemy),
		damage_per_tick,
		DamageVisuals.get_display_name(damage_type),
		DamageVisuals.get_color(damage_type),
		0,
		true
	)

	if apply_burn:
		var status_component := enemy.get_node_or_null("StatusEffectComponent") as StatusEffectComponent

		if status_component != null:
			status_component.apply_burn(
				damage_per_tick * 0.4,
				burn_duration,
				burn_tick_rate
			)


func _draw() -> void:
	var life_ratio: float = 1.0 - clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0)
	var alpha: float = visual_color.a * life_ratio

	draw_circle(
		Vector2.ZERO,
		radius,
		Color(visual_color.r, visual_color.g, visual_color.b, alpha * 0.35)
	)

	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		48,
		Color(visual_color.r, visual_color.g, visual_color.b, alpha),
		3.0
	)

	draw_arc(
		Vector2.ZERO,
		radius * 0.55,
		0.0,
		TAU,
		32,
		Color(visual_color.r, visual_color.g, visual_color.b, alpha * 0.5),
		1.5
	)
