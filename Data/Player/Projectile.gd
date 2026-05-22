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
var bounces_remaining: int = 0
var homing_strength: float = 0.0
var nova_radius: float = 80.0
var nova_damage_ratio: float = 0.5

var secondary_type: int = PowerUpData.ProjectileType.NONE
var secondary_rank: int = 1

var sprite_frames_override: SpriteFrames = null

const DMG_PHYSICAL := Color(1.00, 1.00, 1.00)
const DMG_FIRE := Color(1.00, 0.42, 0.08)
const DMG_ICE := Color(0.40, 0.85, 1.00)
const DMG_LIGHTNING := Color(0.80, 0.55, 1.00)
const DMG_POISON := Color(0.35, 1.00, 0.30)
const DMG_COMBO := Color(1.00, 0.88, 0.15)

const CHAIN_RADIUS: float = 150.0
const CHAIN_DAMAGE_FALLOFF: float = 0.6

var _hit_tracker: Dictionary = {}


func _ready() -> void:
	add_to_group("projectiles")
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
	direction = new_direction.normalized()
	damage = new_damage
	base_damage = new_base_damage if new_base_damage >= 0.0 else float(new_damage)

	if sprite_frames_override != null and animated_sprite != null:
		animated_sprite.sprite_frames = sprite_frames_override

	if direction != Vector2.ZERO:
		rotation = direction.angle()


func apply_projectile_type(type: int, rank: int) -> void:
	projectile_type = type

	match type:
		PowerUpData.ProjectileType.PHASE:
			pierces_enemies = true
			set_meta("pierce_remaining", rank)

		PowerUpData.ProjectileType.BOULDER:
			var size_mult: float = 1.0 + float(rank) * 0.5
			speed *= 0.35
			lifetime = 6.0
			pierces_enemies = true

			if animated_sprite != null:
				animated_sprite.scale = Vector2(size_mult, size_mult)

			var col := get_node_or_null("CollisionShape2D")
			if col != null and col.shape != null:
				col.shape = col.shape.duplicate()
				if col.shape is CircleShape2D:
					col.shape.radius *= size_mult
				elif col.shape is RectangleShape2D:
					col.shape.size *= size_mult

		PowerUpData.ProjectileType.RICOCHET:
			bounces_remaining = rank + 1

		PowerUpData.ProjectileType.NOVA:
			nova_radius = 80.0 + float(rank) * 20.0
			nova_damage_ratio = 0.5 + float(rank) * 0.25
			pierces_enemies = false

		PowerUpData.ProjectileType.HOMING:
			homing_strength = 2.5 + float(rank) * 1.5
			lifetime = 6.0


func apply_secondary_type(type: int, rank: int) -> void:
	secondary_type = type
	secondary_rank = rank

	match type:
		PowerUpData.ProjectileType.PHASE:
			pierces_enemies = true
			set_meta("pierce_remaining", rank)

		PowerUpData.ProjectileType.NOVA:
			nova_radius = 80.0 + float(rank) * 20.0
			nova_damage_ratio = 0.5 + float(rank) * 0.25

		_:
			pass


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
	_try_damage(area)


func _try_damage(target: Node) -> void:
	var health_component := target.get_node_or_null("HealthComponent")
	var enemy_root: Node = target

	if health_component == null and target.get_parent() != null:
		health_component = target.get_parent().get_node_or_null("HealthComponent")
		if health_component != null:
			enemy_root = target.get_parent()

	if health_component == null:
		return

	var status_component := enemy_root.get_node_or_null("StatusEffectComponent") as StatusEffectComponent

	_hit_tracker.clear()

	if projectile_type == PowerUpData.ProjectileType.NOVA:
		_apply_nova(enemy_root)
		_flush_damage_numbers()
		queue_free()
		return

	var packet: DamagePacket = DamageResolver.build_projectile_packet(
		float(damage),
		PlayerInventory.get_equipped_powerups_with_ranks(),
		PlayerInventory.current_wave
	)

	packet.print_debug()

	_apply_damage_packet(enemy_root, health_component, packet)
	_apply_packet_status_effects(enemy_root, status_component, packet)

	if secondary_type == PowerUpData.ProjectileType.NOVA:
		_apply_nova(enemy_root)

	_flush_damage_numbers()
	_handle_pierce_or_destroy()


func _apply_damage_packet(enemy_root: Node, health_component: Node, packet: DamagePacket) -> void:
	if packet == null or packet.is_empty():
		return

	if health_component.has_method("take_damage_packet"):
		health_component.take_damage_packet(packet)
	else:
		health_component.take_damage(packet.get_total(), "physical")

	var id := enemy_root.get_instance_id()
	if not _hit_tracker.has(id):
		_hit_tracker[id] = {
			"root": enemy_root,
			"hits": []
		}

	for entry: Dictionary in packet.entries:
		var amount: float = float(entry.amount)
		var damage_type: String = String(entry.type)
		var color: Color = DamageVisuals.get_color(damage_type)

		_hit_tracker[id]["hits"].append({
			"amount": amount,
			"color": color,
			"type": damage_type
		})

		DamageMeter.record(amount, damage_type)


func _apply_packet_status_effects(
	enemy_root: Node,
	status_component: StatusEffectComponent,
	packet: DamagePacket
) -> void:
	if status_component == null:
		return
	if packet == null or packet.is_empty():
		return

	for entry: Dictionary in packet.entries:
		var amount: float = float(entry.amount)
		var damage_type: String = String(entry.type)

		match damage_type:
			"fire":
				status_component.apply_burn(amount / 8.0, 3.0, 0.5)

			"ice":
				status_component.apply_slow(0.25, 2.0)

			"lightning":
				status_component.apply_stun(0.35)
				_chain_lightning(enemy_root, amount, 1)

			"poison":
				status_component.apply_poison(amount / 10.0, 4.0, 0.5)

			"thermal", "magnetic", "corrosive", "viral", "plasma", "neurotoxin":
				status_component.apply_combo_effect(damage_type, amount)

			_:
				pass


func _handle_pierce_or_destroy() -> void:
	if projectile_type == PowerUpData.ProjectileType.PHASE or secondary_type == PowerUpData.ProjectileType.PHASE:
		var remaining: int = get_meta("pierce_remaining", 0)
		remaining -= 1
		set_meta("pierce_remaining", remaining)

		if remaining < 0:
			queue_free()

		return

	if not pierces_enemies:
		queue_free()


func _update_homing(delta: float) -> void:
	var nearest := _find_nearest_enemy()
	if nearest == null:
		return

	var target_dir: Vector2 = global_position.direction_to(nearest.global_position)
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


func _apply_nova(enemy_root: Node) -> void:
	var nova_damage: float = float(damage) * nova_damage_ratio

	for nearby in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(nearby):
			continue

		var dist: float = enemy_root.global_position.distance_to(nearby.global_position)
		if dist > nova_radius:
			continue

		var falloff: float = 1.0 - (dist / nova_radius) * 0.5
		var hc := nearby.get_node_or_null("HealthComponent")

		if hc != null and hc.has_method("take_damage"):
			_deal(nearby, hc, nova_damage * falloff, DMG_FIRE)

	_draw_nova_ring(enemy_root.global_position, nova_radius)


func _chain_lightning(source_enemy: Node, element_pool: float, rank: int) -> void:
	var current_damage: float = element_pool
	var hit_enemies: Array = [source_enemy]

	for _i in rank:
		var last_hit: Node = hit_enemies.back()
		if not is_instance_valid(last_hit):
			break

		var nearest_enemy: Node = null
		var nearest_dist: float = CHAIN_RADIUS

		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy in hit_enemies or not is_instance_valid(enemy):
				continue

			var dist: float = last_hit.global_position.distance_to(enemy.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_enemy = enemy

		if nearest_enemy == null:
			break

		current_damage *= CHAIN_DAMAGE_FALLOFF

		var hc := nearest_enemy.get_node_or_null("HealthComponent")
		if hc != null and hc.has_method("take_damage"):
			_deal(nearest_enemy, hc, current_damage, DMG_LIGHTNING)

		var chained_status := nearest_enemy.get_node_or_null("StatusEffectComponent") as StatusEffectComponent
		if chained_status != null:
			chained_status.apply_stun(0.35)

		_draw_chain_arc(last_hit.global_position, nearest_enemy.global_position)
		hit_enemies.append(nearest_enemy)


func _deal(enemy_root: Node, health_component: Node, amount: float, color: Color = DMG_PHYSICAL) -> void:
	if amount <= 0.0:
		return

	var damage_type: String = _color_to_type(color)

	if health_component.has_method("take_damage"):
		health_component.take_damage(amount, damage_type)

	var id := enemy_root.get_instance_id()
	if not _hit_tracker.has(id):
		_hit_tracker[id] = {
			"root": enemy_root,
			"hits": []
		}

	_hit_tracker[id]["hits"].append({
		"amount": amount,
		"color": DamageVisuals.get_color(damage_type),
		"type": damage_type
	})

	DamageMeter.record(amount, damage_type)


func _flush_damage_numbers() -> void:
	for id in _hit_tracker:
		var entry: Dictionary = _hit_tracker[id]

		var root: Node2D = entry.get("root", null) as Node2D
		if root == null:
			continue

		var spawn_pos: Vector2 = DamageNumberSpawner.get_anchor_position(root)
		var index: int = 0

		for hit: Dictionary in entry["hits"]:
			var amount: float = float(hit.amount)
			var damage_type: String = String(hit.get("type", "physical"))
			var color: Color = DamageVisuals.get_color(damage_type)

			DamageNumberSpawner.spawn(
				spawn_pos,
				amount,
				DamageVisuals.get_display_name(damage_type),
				color,
				index,
				false
			)

			index += 1

	_hit_tracker.clear()


func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = 9999.0

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		var dist: float = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy as Node2D

	return nearest


func _color_to_type(color: Color) -> String:
	if color == DMG_FIRE:
		return "fire"
	if color == DMG_ICE:
		return "ice"
	if color == DMG_LIGHTNING:
		return "lightning"
	if color == DMG_POISON:
		return "poison"
	if color == DMG_COMBO:
		return "combo"
	return "physical"


func _draw_chain_arc(from_pos: Vector2, to_pos: Vector2) -> void:
	var line := Line2D.new()
	line.z_index = 10

	for i in range(9):
		var t: float = float(i) / 8.0
		var point: Vector2 = from_pos.lerp(to_pos, t)

		if i > 0 and i < 8:
			var perp: Vector2 = (to_pos - from_pos).normalized().rotated(PI * 0.5)
			point += perp * randf_range(-12.0, 12.0)

		line.add_point(point)

	line.width = 2.0
	line.default_color = Color(0.7, 0.85, 1.0, 0.9)
	get_tree().current_scene.add_child(line)

	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.2)
	tween.tween_callback(line.queue_free)


func _draw_nova_ring(_pos: Vector2, _radius: float) -> void:
	pass
