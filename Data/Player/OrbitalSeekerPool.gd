extends Node2D
class_name OrbitalSeekerPool

const MAX_ORBITALS: int = 8
const ORBIT_RADIUS: float = 85.0
const ANGULAR_SPEED: float = 2.2  # radians per second
const FIRE_RANGE: float = 520.0
const FIRE_COOLDOWN: float = 0.35
const ORBITAL_COLOR: Color = Color(0.70, 1.0, 0.70, 0.90)
const PROJECTILE_SCENE: String = "res://Data/World/Resources/projectile.tscn"

var _orbitals: Array[Node2D] = []
var _fire_timer: float = 0.0
var _angle_offset: float = 0.0
var _swarm_rank: int = 1


func add_orbitals(count: int, rank: int) -> void:
	_swarm_rank = rank
	var to_add: int = mini(count, MAX_ORBITALS - _orbitals.size())
	for _i in to_add:
		var vis := _OrbitalVisual.new()
		add_child(vis)
		_orbitals.append(vis as Node2D)


func _process(delta: float) -> void:
	_cleanup_invalid()

	if _orbitals.is_empty():
		return

	_angle_offset += ANGULAR_SPEED * delta
	_update_positions()

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		if _try_fire():
			_fire_timer = FIRE_COOLDOWN


func _update_positions() -> void:
	var count: int = _orbitals.size()
	for i in count:
		if not is_instance_valid(_orbitals[i]):
			continue
		var angle: float = _angle_offset + float(i) / float(count) * TAU
		_orbitals[i].position = Vector2.RIGHT.rotated(angle) * ORBIT_RADIUS


func _cleanup_invalid() -> void:
	var i: int = _orbitals.size() - 1
	while i >= 0:
		if not is_instance_valid(_orbitals[i]):
			_orbitals.remove_at(i)
		i -= 1


func _try_fire() -> bool:
	var nearest := _find_nearest_enemy()
	if nearest == null:
		return false

	var vis: Node2D = _orbitals.pop_back()
	var launch_pos: Vector2 = vis.global_position
	vis.queue_free()

	_launch_at(launch_pos, nearest)
	return true


func _find_nearest_enemy() -> Node2D:
	var player_pos: Vector2 = global_position
	var nearest: Node2D = null
	var nearest_dist: float = FIRE_RANGE

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var hc := (enemy as Node).get_node_or_null("HealthComponent")
		if hc != null and bool(hc.get("is_dead")):
			continue
		var dist: float = player_pos.distance_to((enemy as Node2D).global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy as Node2D

	return nearest


func _get_player_damage() -> float:
	var stats := get_parent().get_node_or_null("StatsComponent") as StatsComponent
	if stats != null:
		return stats.damage
	return 10.0


func _launch_at(from_pos: Vector2, target: Node2D) -> void:
	var scene: PackedScene = load(PROJECTILE_SCENE)
	if scene == null:
		return

	var dmg_ratio: float = 0.40 + float(_swarm_rank - 1) * 0.08
	var seeker_dmg: int = maxi(1, int(round(_get_player_damage() * dmg_ratio)))
	var dir: Vector2 = from_pos.direction_to(target.global_position)
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	var proj := scene.instantiate() as Projectile
	proj.lifetime = 3.5
	get_tree().current_scene.add_child(proj)
	proj.global_position = from_pos
	proj.setup(dir, seeker_dmg, float(seeker_dmg))
	proj.projectile_type = PowerUpData.ProjectileType.HOMING
	proj.homing_strength = 18.0
	proj.homing_range = 600.0
	proj.set_meta("is_seeker_swarm_child", true)
	proj.set_meta("seeker_target_id", target.get_instance_id())

	var sprite := proj.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.modulate = ORBITAL_COLOR


class _OrbitalVisual extends Node2D:
	const CORE_RADIUS: float = 5.0
	const GLOW_RADIUS: float = 9.0
	const PULSE_SPEED: float = 3.0

	var _time: float = 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var pulse: float = 0.75 + 0.25 * sin(_time * PULSE_SPEED)
		draw_circle(Vector2.ZERO, GLOW_RADIUS, Color(0.70, 1.0, 0.70, 0.22 * pulse))
		draw_circle(Vector2.ZERO, CORE_RADIUS, Color(0.70, 1.0, 0.70, 0.90 * pulse))
		draw_circle(Vector2.ZERO, CORE_RADIUS * 0.4, Color(1.0, 1.0, 1.0, 0.85 * pulse))
