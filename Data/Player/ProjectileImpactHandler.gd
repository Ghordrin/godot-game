extends RefCounted
class_name ProjectileImpactHandler

const CHAIN_RADIUS: float = 150.0
const CHAIN_DAMAGE_FALLOFF: float = 0.6


var projectile: Projectile
var hit_tracker: Dictionary = {}


func _init(owner_projectile: Projectile) -> void:
	projectile = owner_projectile


func handle_hit(target: Node) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return

	var hit_info: Dictionary = _find_hit_info(target)
	var health_component: Node = hit_info.get("health_component", null)
	var enemy_root: Node = hit_info.get("enemy_root", null)

	if health_component == null or enemy_root == null:
		return

	var status_component := enemy_root.get_node_or_null("StatusEffectComponent") as StatusEffectComponent

	hit_tracker.clear()

	var packet: DamagePacket = _build_projectile_packet()

	if projectile.projectile_type == PowerUpData.ProjectileType.NOVA:
		_apply_nova(enemy_root, packet)
		_flush_damage_numbers()
		projectile.queue_free()
		return

	_apply_damage_packet(enemy_root, health_component, packet)
	_apply_packet_status_effects(enemy_root, status_component, packet)

	if projectile.secondary_type == PowerUpData.ProjectileType.NOVA:
		_apply_nova(enemy_root, packet)

	_flush_damage_numbers()
	projectile.handle_pierce_or_destroy()


func _find_hit_info(target: Node) -> Dictionary:
	var health_component := target.get_node_or_null("HealthComponent")
	var enemy_root: Node = target

	if health_component == null and target.get_parent() != null:
		health_component = target.get_parent().get_node_or_null("HealthComponent")

		if health_component != null:
			enemy_root = target.get_parent()

	return {
		"health_component": health_component,
		"enemy_root": enemy_root
	}


func _build_projectile_packet() -> DamagePacket:
	var active_powerups: Array[Dictionary] = []

	if PlayerInventory.has_method("get_active_damage_powerups_with_ranks"):
		active_powerups = PlayerInventory.get_active_damage_powerups_with_ranks()
	else:
		active_powerups = PlayerInventory.get_equipped_powerups_with_ranks()

	var packet: DamagePacket = DamageResolver.build_projectile_packet(
		float(projectile.damage),
		active_powerups,
		PlayerInventory.current_wave
	)

	return packet


func _apply_damage_packet(enemy_root: Node, health_component: Node, packet: DamagePacket) -> void:
	if packet == null or packet.is_empty():
		return

	if health_component.has_method("take_damage_packet"):
		health_component.take_damage_packet(packet)
	else:
		health_component.take_damage(packet.get_total(), "physical")

	_track_packet_hits(enemy_root, packet, 1.0)


func _track_packet_hits(enemy_root: Node, packet: DamagePacket, visual_scale: float = 1.0) -> void:
	if packet == null or packet.is_empty():
		return

	var id := enemy_root.get_instance_id()

	if not hit_tracker.has(id):
		hit_tracker[id] = {
			"root": enemy_root,
			"hits": []
		}

	for entry: Dictionary in packet.entries:
		var amount: float = float(entry.amount) * visual_scale
		var damage_type: String = String(entry.type)

		if amount <= 0.0:
			continue

		hit_tracker[id]["hits"].append({
			"amount": amount,
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
				status_component.apply_burn_from_element(amount)

			"ice":
				status_component.apply_slow(0.25, 2.0, amount)

			"lightning":
				status_component.apply_shock_from_element(amount)
				status_component.apply_stun(0.20)
				_chain_lightning(enemy_root, amount, 1)

			"poison":
				status_component.apply_poison_from_element(amount)

			"thermal", "magnetic", "corrosive", "viral", "plasma", "neurotoxin":
				status_component.apply_combo_effect(damage_type, amount)

			_:
				pass


func _apply_nova(source_enemy: Node, original_packet: DamagePacket) -> void:
	if original_packet == null or original_packet.is_empty():
		return

	if not source_enemy is Node2D:
		return

	for nearby in projectile.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(nearby):
			continue

		if not nearby is Node2D:
			continue

		var dist: float = source_enemy.global_position.distance_to(nearby.global_position)

		if dist > projectile.nova_radius:
			continue

		var falloff: float = 1.0 - (dist / projectile.nova_radius) * 0.5
		var nova_packet: DamagePacket = _make_scaled_packet(
			original_packet,
			projectile.nova_damage_ratio * falloff
		)

		var health_component := nearby.get_node_or_null("HealthComponent")

		if health_component != null and health_component.has_method("take_damage_packet"):
			health_component.take_damage_packet(nova_packet)
			_track_packet_hits(nearby, nova_packet, 1.0)

			var status_component := nearby.get_node_or_null("StatusEffectComponent") as StatusEffectComponent
			_apply_packet_status_effects(nearby, status_component, nova_packet)

	_draw_nova_ring(source_enemy.global_position, projectile.nova_radius)


func _make_scaled_packet(source_packet: DamagePacket, scale: float) -> DamagePacket:
	var packet := DamagePacket.new()

	if source_packet == null or source_packet.is_empty():
		return packet

	for entry: Dictionary in source_packet.entries:
		var amount: float = float(entry.amount) * scale
		var damage_type: String = String(entry.type)
		var source: String = String(entry.get("source", "nova"))

		if amount <= 0.0:
			continue

		packet.add_damage(amount, damage_type, source)

	return packet


func _chain_lightning(source_enemy: Node, element_pool: float, rank: int) -> void:
	var current_damage: float = element_pool
	var hit_enemies: Array = [source_enemy]

	for _i in rank:
		var last_hit: Node = hit_enemies.back()

		if not is_instance_valid(last_hit):
			break

		if not last_hit is Node2D:
			break

		var nearest_enemy: Node = null
		var nearest_dist: float = CHAIN_RADIUS

		for enemy in projectile.get_tree().get_nodes_in_group("enemies"):
			if enemy in hit_enemies or not is_instance_valid(enemy):
				continue

			if not enemy is Node2D:
				continue

			var dist: float = last_hit.global_position.distance_to(enemy.global_position)

			if dist < nearest_dist:
				nearest_dist = dist
				nearest_enemy = enemy

		if nearest_enemy == null:
			break

		current_damage *= CHAIN_DAMAGE_FALLOFF

		var packet := DamagePacket.new()
		packet.add_damage(current_damage, "lightning", "chain")

		var health_component := nearest_enemy.get_node_or_null("HealthComponent")

		if health_component != null and health_component.has_method("take_damage_packet"):
			health_component.take_damage_packet(packet)
			_track_packet_hits(nearest_enemy, packet, 1.0)

		var chained_status := nearest_enemy.get_node_or_null("StatusEffectComponent") as StatusEffectComponent

		if chained_status != null:
			chained_status.apply_shock_from_element(current_damage)
			chained_status.apply_stun(0.20)

		_draw_chain_arc(last_hit.global_position, nearest_enemy.global_position)
		hit_enemies.append(nearest_enemy)


func _flush_damage_numbers() -> void:
	for id in hit_tracker:
		var entry: Dictionary = hit_tracker[id]
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

	hit_tracker.clear()


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

	projectile.get_tree().current_scene.add_child(line)

	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.2)
	tween.tween_callback(line.queue_free)


func _draw_nova_ring(_pos: Vector2, _radius: float) -> void:
	pass
