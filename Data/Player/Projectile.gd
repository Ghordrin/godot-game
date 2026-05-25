extends Area2D
class_name Projectile

@export var speed: float = 450.0
@export var damage: int = 10
@export var lifetime: float = 10.0
@export var animation_name: String = "default"

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var direction: Vector2 = Vector2.RIGHT
var pierces_enemies: bool = false
var base_damage: float = 10.0

var projectile_type: int = PowerUpData.ProjectileType.NONE

# Kept for compatibility. Ricochet is no longer a core projectile choice.
var bounces_remaining: int = 0

var homing_strength: float = 0.0
var homing_range: float = 780.0
var homing_retarget_interval: float = 0.15
var homing_target: Node2D = null
var homing_retarget_timer: float = 0.0

var nova_radius: float = 115.0
var nova_damage_ratio: float = 0.65

var secondary_type: int = PowerUpData.ProjectileType.NONE
var secondary_rank: int = 1

var sprite_frames_override: SpriteFrames = null

var impact_handler: ProjectileImpactHandler = null
var lifetime_remaining: float = 0.0

# Boulder drop mode
var is_boulder_drop: bool = false
var boulder_target_position: Vector2 = Vector2.ZERO
var boulder_fall_height: float = 260.0
var boulder_fall_speed: float = 500.0
var boulder_impact_radius: float = 38.0
var boulder_ground_shadow: Node2D = null


func _ready() -> void:
	impact_handler = ProjectileImpactHandler.new(self)
	lifetime_remaining = lifetime

	add_to_group("projectiles")
	add_to_group("wave_cleanup")

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	play_projectile_animation()


func _physics_process(delta: float) -> void:
	lifetime_remaining -= delta

	if lifetime_remaining <= 0.0:
		queue_free()
		return

	if is_boulder_drop:
		_process_boulder_drop(delta)
		return

	match projectile_type:
		PowerUpData.ProjectileType.HOMING:
			_update_homing(delta)

		PowerUpData.ProjectileType.RICOCHET:
			_check_ricochet(delta)

	global_position += direction.normalized() * speed * delta


func setup(new_direction: Vector2, new_damage: int = 10, new_base_damage: float = -1.0) -> void:
	direction = new_direction.normalized()

	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	damage = new_damage
	base_damage = new_base_damage if new_base_damage >= 0.0 else float(new_damage)

	if sprite_frames_override != null and animated_sprite != null:
		animated_sprite.sprite_frames = sprite_frames_override

	rotation = direction.angle()


func setup_boulder_drop(target_position: Vector2, fall_height: float = 260.0) -> void:
	is_boulder_drop = true
	boulder_target_position = target_position
	boulder_fall_height = fall_height
	direction = Vector2.DOWN
	rotation = 0.0
	global_position = target_position + Vector2(0.0, -boulder_fall_height)
	lifetime = 3.0
	lifetime_remaining = lifetime

	_create_boulder_shadow(target_position)


func apply_projectile_type(type: int, _rank: int = 1) -> void:
	projectile_type = type

	match type:
		PowerUpData.ProjectileType.PHASE:
			_apply_phase()

		PowerUpData.ProjectileType.BOULDER:
			_apply_boulder()

		PowerUpData.ProjectileType.RICOCHET:
			# Legacy / future modifier.
			# For now, if an old resource still gives Ricochet,
			# treat it as Phase so it does not break gameplay.
			projectile_type = PowerUpData.ProjectileType.PHASE
			_apply_phase()

		PowerUpData.ProjectileType.NOVA:
			_apply_nova()

		PowerUpData.ProjectileType.HOMING:
			_apply_homing()

		_:
			pass

	lifetime_remaining = lifetime


func apply_secondary_type(type: int, _rank: int = 1) -> void:
	secondary_type = type
	secondary_rank = 1

	match type:
		PowerUpData.ProjectileType.PHASE:
			pierces_enemies = true
			set_meta("pierce_remaining", maxi(int(get_meta("pierce_remaining", 0)), 3))

		PowerUpData.ProjectileType.BOULDER:
			damage = int(round(float(damage) * 1.20))
			set_meta("boulder_enabled", true)
			set_meta("boulder_rank", 1)

		PowerUpData.ProjectileType.RICOCHET:
			# Legacy / future modifier support.
			bounces_remaining = 2

		PowerUpData.ProjectileType.NOVA:
			nova_radius = maxf(nova_radius, 115.0)
			nova_damage_ratio = maxf(nova_damage_ratio, 0.65)

		PowerUpData.ProjectileType.HOMING:
			homing_strength = maxf(homing_strength, 5.0)
			homing_range = maxf(homing_range, 780.0)
			homing_retarget_interval = 0.15
			homing_retarget_timer = 0.0
			homing_target = null

		_:
			pass


func _apply_phase() -> void:
	pierces_enemies = true
	set_meta("pierce_remaining", 3)
	speed *= 1.12
	lifetime = maxf(lifetime, 8.0)


func _apply_boulder() -> void:
	var size_mult: float = 1.45

	damage = int(round(float(damage) * 1.35))
	speed *= 0.42
	lifetime = 6.0
	pierces_enemies = true
	set_meta("pierce_remaining", 2)
	set_meta("boulder_enabled", true)
	set_meta("boulder_rank", 1)

	if animated_sprite != null:
		animated_sprite.scale = Vector2(size_mult, size_mult)

	var collision_shape := get_node_or_null("CollisionShape2D")

	if collision_shape != null and collision_shape.shape != null:
		collision_shape.shape = collision_shape.shape.duplicate()

		if collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius *= size_mult
		elif collision_shape.shape is RectangleShape2D:
			collision_shape.shape.size *= size_mult


func _apply_nova() -> void:
	nova_radius = 115.0
	nova_damage_ratio = 0.65
	pierces_enemies = false


func _apply_homing() -> void:
	homing_strength = 5.0
	homing_range = 780.0
	homing_retarget_interval = 0.15
	homing_retarget_timer = 0.0
	homing_target = null
	lifetime = 6.0
	speed *= 0.95


func play_projectile_animation() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return

	if animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
		return

	var anims := animated_sprite.sprite_frames.get_animation_names()

	if anims.size() > 0:
		animated_sprite.play(anims[0])


func _on_body_entered(_body: Node2D) -> void:
	pass


func _on_area_entered(area: Area2D) -> void:
	if impact_handler == null:
		return

	if is_boulder_drop:
		return

	impact_handler.handle_hit(area)


func handle_pierce_or_destroy() -> void:
	if projectile_type == PowerUpData.ProjectileType.PHASE or secondary_type == PowerUpData.ProjectileType.PHASE:
		var remaining: int = int(get_meta("pierce_remaining", 0))
		remaining -= 1
		set_meta("pierce_remaining", remaining)

		if remaining < 0:
			queue_free()

		return

	if projectile_type == PowerUpData.ProjectileType.BOULDER or bool(get_meta("boulder_enabled", false)):
		var remaining: int = int(get_meta("pierce_remaining", 0))
		remaining -= 1
		set_meta("pierce_remaining", remaining)

		if remaining < 0:
			queue_free()

		return

	if not pierces_enemies:
		queue_free()


func _process_boulder_drop(delta: float) -> void:
	global_position = global_position.move_toward(
		boulder_target_position,
		boulder_fall_speed * delta
	)

	_update_boulder_shadow()

	if global_position.distance_to(boulder_target_position) <= 4.0:
		_impact_boulder_drop()


func _impact_boulder_drop() -> void:
	global_position = boulder_target_position

	if is_instance_valid(boulder_ground_shadow):
		boulder_ground_shadow.queue_free()

	boulder_ground_shadow = null

	var hit_anything := false

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		if not enemy is Node2D:
			continue

		var enemy_2d := enemy as Node2D
		var dist := boulder_target_position.distance_to(enemy_2d.global_position)

		if dist > boulder_impact_radius:
			continue

		var health_component := enemy.get_node_or_null("HealthComponent")

		if health_component == null:
			continue

		hit_anything = true

		if impact_handler != null:
			impact_handler.handle_hit(enemy)

	if not hit_anything:
		_draw_miss_impact_ring()

	queue_free()


func _create_boulder_shadow(target_position: Vector2) -> void:
	var shadow := BoulderShadowVisual.new()
	shadow.global_position = target_position
	shadow.max_radius = boulder_impact_radius
	shadow.add_to_group("wave_cleanup")
	get_tree().current_scene.add_child(shadow)
	boulder_ground_shadow = shadow


func _update_boulder_shadow() -> void:
	if not is_instance_valid(boulder_ground_shadow):
		return

	var travel_total := maxf(1.0, boulder_fall_height)
	var remaining := global_position.distance_to(boulder_target_position)
	var progress := clampf(1.0 - remaining / travel_total, 0.0, 1.0)

	if boulder_ground_shadow.has_method("set_progress"):
		boulder_ground_shadow.set_progress(progress)


func _draw_miss_impact_ring() -> void:
	var ring := BoulderImpactRing.new()
	ring.global_position = boulder_target_position
	ring.max_radius = boulder_impact_radius
	ring.ring_color = Color(0.65, 0.50, 0.34, 0.75)
	ring.add_to_group("wave_cleanup")
	get_tree().current_scene.add_child(ring)


func _update_homing(delta: float) -> void:
	homing_retarget_timer -= delta

	if homing_retarget_timer <= 0.0 or not is_instance_valid(homing_target):
		homing_retarget_timer = homing_retarget_interval
		homing_target = _find_best_homing_target()

	if homing_target == null:
		return

	var target_dir: Vector2 = global_position.direction_to(homing_target.global_position)

	if target_dir == Vector2.ZERO:
		return

	direction = direction.lerp(target_dir, homing_strength * delta).normalized()
	rotation = direction.angle()


func _check_ricochet(delta: float) -> void:
	if bounces_remaining <= 0:
		return

	var space := get_world_2d().direct_space_state

	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + direction * speed * delta * 3.0
	)

	query.exclude = [self]

	var result := space.intersect_ray(query)

	if result.is_empty():
		return

	var collider: Node = result.collider

	if collider.is_in_group("enemies") or collider.is_in_group("player"):
		return

	direction = direction.bounce(result.normal).normalized()
	rotation = direction.angle()
	bounces_remaining -= 1

	if animated_sprite != null:
		var tween := create_tween()
		tween.tween_property(animated_sprite, "modulate", Color(1.5, 1.5, 1.5), 0.05)
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.1)


func _find_best_homing_target() -> Node2D:
	var best_target: Node2D = null
	var best_score: float = INF

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		if not enemy is Node2D:
			continue

		var enemy_2d := enemy as Node2D
		var dist: float = global_position.distance_to(enemy_2d.global_position)

		if dist > homing_range:
			continue

		var score: float = dist

		if enemy.is_in_group("bosses"):
			score *= 0.30
		elif enemy.get_node_or_null("AffixComponent") != null:
			score *= 0.50

		var health := enemy.get_node_or_null("HealthComponent")

		if health != null and "current_health" in health and "max_health" in health:
			var hp_ratio: float = float(health.current_health) / maxf(1.0, float(health.max_health))
			score *= lerpf(0.75, 1.15, hp_ratio)

		if score < best_score:
			best_score = score
			best_target = enemy_2d

	return best_target


class BoulderShadowVisual extends Node2D:
	var max_radius: float = 38.0
	var progress: float = 0.0

	func _ready() -> void:
		z_index = 3
		queue_redraw()


	func set_progress(value: float) -> void:
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


	func _draw() -> void:
		var radius := lerpf(max_radius * 0.45, max_radius, progress)
		var alpha := lerpf(0.18, 0.55, progress)

		draw_circle(Vector2.ZERO, radius, Color(0.0, 0.0, 0.0, alpha))
		draw_arc(Vector2.ZERO, max_radius, 0.0, TAU, 40, Color(0.85, 0.55, 0.25, 0.65), 2.0)


class BoulderImpactRing extends Node2D:
	var max_radius: float = 40.0
	var ring_color: Color = Color(0.65, 0.50, 0.34, 0.75)

	var _radius: float = 0.0
	var _alpha: float = 0.8

	func _ready() -> void:
		z_index = 12

		var tween := create_tween().set_parallel(true)

		tween.tween_method(
			func(value: float) -> void:
				_radius = value
				queue_redraw(),
			0.0,
			max_radius,
			0.18
		)

		tween.tween_method(
			func(value: float) -> void:
				_alpha = value
				queue_redraw(),
			0.8,
			0.0,
			0.18
		)

		tween.chain().tween_callback(queue_free)


	func _draw() -> void:
		if _radius <= 0.0:
			return

		draw_circle(
			Vector2.ZERO,
			_radius,
			Color(ring_color.r, ring_color.g, ring_color.b, _alpha * 0.13)
		)

		draw_arc(
			Vector2.ZERO,
			_radius,
			0.0,
			TAU,
			40,
			Color(ring_color.r, ring_color.g, ring_color.b, _alpha),
			3.0
		)
