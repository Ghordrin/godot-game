extends Area2D
class_name Projectile

@export var speed: float = 450.0
@export var damage: int = 10
@export var lifetime: float = 10.0
@export var animation_name: String = "default"

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var direction: Vector2 = Vector2.RIGHT
var pierces_enemies: bool = false
var infinite_pierce: bool = false
var base_damage: float = 10.0

var projectile_type: int = PowerUpData.ProjectileType.NONE

# Kept for compatibility. Ricochet is no longer a core projectile choice.
var bounces_remaining: int = 0

var homing_strength: float = 0.0
var homing_range: float = 780.0

var nova_radius: float = 115.0
var nova_damage_ratio: float = 0.65

var secondary_type: int = PowerUpData.ProjectileType.NONE
var secondary_rank: int = 1

var sprite_frames_override: SpriteFrames = null

var impact_handler: ProjectileImpactHandler = null

var _base_speed: float = 450.0
var _base_lifetime: float = 10.0
var _base_sprite_scale: Vector2 = Vector2.ONE
var _has_cached_base_values: bool = false


func _ready() -> void:
	_cache_base_values()

	impact_handler = ProjectileImpactHandler.new(self)

	add_to_group("projectiles")
	add_to_group("wave_cleanup")

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	play_projectile_animation()

	await get_tree().create_timer(lifetime).timeout

	if is_inside_tree():
		queue_free()


func _physics_process(delta: float) -> void:
	match projectile_type:
		PowerUpData.ProjectileType.HOMING:
			_update_homing(delta)

		PowerUpData.ProjectileType.RICOCHET:
			_check_ricochet(delta)

	global_position += direction.normalized() * speed * delta


func setup(new_direction: Vector2, new_damage: int = 10, new_base_damage: float = -1.0) -> void:
	_cache_base_values()

	direction = new_direction.normalized()

	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	damage = new_damage
	base_damage = new_base_damage if new_base_damage >= 0.0 else float(new_damage)

	if sprite_frames_override != null and animated_sprite != null:
		animated_sprite.sprite_frames = sprite_frames_override

	rotation = direction.angle()


func apply_projectile_type(type: int, rank: int = 1) -> void:
	projectile_type = type

	match type:
		PowerUpData.ProjectileType.PHASE:
			_apply_phase(rank)

		PowerUpData.ProjectileType.BOULDER:
			_apply_boulder(rank)

		PowerUpData.ProjectileType.RICOCHET:
			projectile_type = PowerUpData.ProjectileType.PHASE
			_apply_phase(rank)

		PowerUpData.ProjectileType.NOVA:
			_apply_nova(rank)

		PowerUpData.ProjectileType.HOMING:
			_apply_homing(rank)

		_:
			pass


func apply_secondary_type(type: int, rank: int = 1) -> void:
	secondary_type = type
	secondary_rank = rank

	match type:
		PowerUpData.ProjectileType.PHASE:
			pierces_enemies = true
			set_meta("pierce_remaining", maxi(int(get_meta("pierce_remaining", 0)), 3 + rank))

		PowerUpData.ProjectileType.BOULDER:
			damage = int(round(float(damage) * (1.15 + float(rank) * 0.05)))
			set_meta("boulder_enabled", true)
			set_meta("boulder_rank", rank)

		PowerUpData.ProjectileType.RICOCHET:
			bounces_remaining = 2 + rank

		PowerUpData.ProjectileType.NOVA:
			nova_radius = maxf(nova_radius, 115.0 + float(rank) * 8.0)
			nova_damage_ratio = maxf(nova_damage_ratio, 0.65 + float(rank) * 0.03)

		PowerUpData.ProjectileType.HOMING:
			homing_strength = maxf(homing_strength, 5.0 + float(rank) * 0.6)
			homing_range = maxf(homing_range, 780.0 + float(rank) * 30.0)

		_:
			pass


func _apply_phase(rank: int) -> void:
	var pierce_rank: int = PlayerInventory.get_projectile_upgrade_rank(
		PowerUpData.ProjectileUpgradeType.PHASE_PIERCE,
		PowerUpData.ProjectileType.PHASE
	)
	var speed_rank: int = PlayerInventory.get_projectile_upgrade_rank(
		PowerUpData.ProjectileUpgradeType.PHASE_SPEED,
		PowerUpData.ProjectileType.PHASE
	)
	var width_rank: int = PlayerInventory.get_projectile_upgrade_rank(
		PowerUpData.ProjectileUpgradeType.PHASE_WIDTH,
		PowerUpData.ProjectileType.PHASE
	)

	pierces_enemies = true

	if pierce_rank >= 5:
		infinite_pierce = true
	else:
		set_meta("pierce_remaining", 3 + rank + pierce_rank * 2)

	speed *= 1.12 + float(speed_rank) * 0.06
	lifetime = maxf(lifetime, 8.0 + float(pierce_rank) * 0.5)

	var width_mult: float = 1.0 + float(width_rank) * 0.12
	_apply_visual_and_collision_scale(Vector2(width_mult, 1.0))


func _apply_boulder(rank: int) -> void:
	var size_rank: int = PlayerInventory.get_projectile_upgrade_rank(
		PowerUpData.ProjectileUpgradeType.BOULDER_SIZE,
		PowerUpData.ProjectileType.BOULDER
	)
	var impact_rank: int = PlayerInventory.get_projectile_upgrade_rank(
		PowerUpData.ProjectileUpgradeType.BOULDER_IMPACT,
		PowerUpData.ProjectileType.BOULDER
	)
	var meteor_rank: int = PlayerInventory.get_projectile_upgrade_rank(
		PowerUpData.ProjectileUpgradeType.BOULDER_METEOR,
		PowerUpData.ProjectileType.BOULDER
	)

	var size_mult: float = 1.45 + float(rank - 1) * 0.10 + float(size_rank) * 0.18 + float(meteor_rank) * 0.30
	var damage_mult: float = 1.35 + float(size_rank) * 0.12 + float(impact_rank) * 0.10 + float(meteor_rank) * 0.25

	damage = int(round(float(damage) * damage_mult))
	speed *= maxf(0.20, 0.42 - float(size_rank) * 0.015 - float(meteor_rank) * 0.03)
	lifetime = 6.0 + float(meteor_rank) * 0.4

	pierces_enemies = true
	set_meta("pierce_remaining", 2 + impact_rank + meteor_rank)
	set_meta("boulder_enabled", true)
	set_meta("boulder_rank", rank)
	set_meta("boulder_size_rank", size_rank)
	set_meta("boulder_impact_rank", impact_rank)
	set_meta("boulder_meteor_rank", meteor_rank)
	set_meta("boulder_size_mult", size_mult)

	_apply_visual_and_collision_scale(Vector2(size_mult, size_mult))


func _apply_nova(rank: int) -> void:
	var radius_rank: int = PlayerInventory.get_projectile_upgrade_rank(
		PowerUpData.ProjectileUpgradeType.NOVA_RADIUS,
		PowerUpData.ProjectileType.NOVA
	)
	var patch_rank: int = PlayerInventory.get_projectile_upgrade_rank(
		PowerUpData.ProjectileUpgradeType.NOVA_PATCH_COUNT,
		PowerUpData.ProjectileType.NOVA
	)
	var damage_rank: int = PlayerInventory.get_projectile_upgrade_rank(
		PowerUpData.ProjectileUpgradeType.NOVA_DAMAGE,
		PowerUpData.ProjectileType.NOVA
	)

	nova_radius = 115.0 + float(rank - 1) * 8.0 + float(radius_rank) * 16.0
	nova_damage_ratio = 0.65 + float(damage_rank) * 0.08

	set_meta("nova_patch_bonus", patch_rank)
	set_meta("nova_rank", rank)

	pierces_enemies = false


func _apply_homing(rank: int) -> void:
	var extra_rank: int = PlayerInventory.get_projectile_upgrade_rank(
		PowerUpData.ProjectileUpgradeType.HOMING_EXTRA_PROJECTILES,
		PowerUpData.ProjectileType.HOMING
	)
	var speed_rank: int = PlayerInventory.get_projectile_upgrade_rank(
		PowerUpData.ProjectileUpgradeType.HOMING_SPEED,
		PowerUpData.ProjectileType.HOMING
	)
	var turn_rank: int = PlayerInventory.get_projectile_upgrade_rank(
		PowerUpData.ProjectileUpgradeType.HOMING_TURN_RATE,
		PowerUpData.ProjectileType.HOMING
	)

	homing_strength = 5.0 + float(rank - 1) * 0.4 + float(turn_rank) * 0.8
	homing_range = 780.0 + float(turn_rank) * 35.0
	lifetime = 6.0 + float(extra_rank) * 0.25
	speed *= 0.95 + float(speed_rank) * 0.08

	set_meta("homing_extra_projectiles", extra_rank)


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

	impact_handler.handle_hit(area)


func handle_pierce_or_destroy() -> void:
	if infinite_pierce:
		return

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


func _update_homing(delta: float) -> void:
	var nearest := _find_best_homing_target()

	if nearest == null:
		return

	var target_dir: Vector2 = global_position.direction_to(nearest.global_position)

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


func _cache_base_values() -> void:
	if _has_cached_base_values:
		return

	_has_cached_base_values = true
	_base_speed = speed
	_base_lifetime = lifetime

	if animated_sprite != null:
		_base_sprite_scale = animated_sprite.scale


func _apply_visual_and_collision_scale(scale_mult: Vector2) -> void:
	if animated_sprite != null:
		animated_sprite.scale = _base_sprite_scale * scale_mult

	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D

	if collision_shape == null:
		return

	if collision_shape.shape == null:
		return

	collision_shape.shape = collision_shape.shape.duplicate()

	if collision_shape.shape is CircleShape2D:
		var circle := collision_shape.shape as CircleShape2D
		circle.radius *= maxf(scale_mult.x, scale_mult.y)
	elif collision_shape.shape is RectangleShape2D:
		var rect := collision_shape.shape as RectangleShape2D
		rect.size *= scale_mult
