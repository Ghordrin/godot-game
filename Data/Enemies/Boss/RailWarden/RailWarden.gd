extends CharacterBody2D
class_name RailWardenBoss

# ══════════════════════════════════════════════════════════════════════
# IDENTITY
# ══════════════════════════════════════════════════════════════════════

@export var boss_name: String = "Rail Warden"
@export var move_speed: float = 68.0
@export var stop_distance: float = 230.0

# ══════════════════════════════════════════════════════════════════════
# GENERAL ATTACK FLOW
# ══════════════════════════════════════════════════════════════════════

@export var boss_projectile_scene: PackedScene

@export var attack_range: float = 900.0
@export var attack_cooldown_phase1: float = 2.1
@export var attack_cooldown_phase2: float = 1.65
@export var attack_cooldown_phase3: float = 1.25

@export var initial_attack_delay: float = 1.0
@export var reposition_after_attack: bool = true
@export var reposition_distance: float = 280.0

# ══════════════════════════════════════════════════════════════════════
# ATTACK 1: RAIL GRID
# ══════════════════════════════════════════════════════════════════════

@export var grid_windup_phase1: float = 0.78
@export var grid_windup_phase2: float = 0.66
@export var grid_windup_phase3: float = 0.54

@export var grid_lane_count_phase1: int = 3
@export var grid_lane_count_phase2: int = 4
@export var grid_lane_count_phase3: int = 5

@export var grid_lane_length: float = 760.0
@export var grid_lane_width: float = 18.0
@export var grid_damage: float = 17.0
@export var grid_lane_spacing: float = 86.0

# ══════════════════════════════════════════════════════════════════════
# ATTACK 2: SPLIT SIGNAL
# ══════════════════════════════════════════════════════════════════════

@export var split_windup: float = 0.62
@export var split_lane_length: float = 820.0
@export var split_lane_width: float = 20.0
@export var split_damage: float = 20.0
@export var split_diagonal_in_phase2: bool = true
@export var split_double_in_phase3: bool = true
@export var split_second_delay: float = 0.26

# ══════════════════════════════════════════════════════════════════════
# ATTACK 3: SWEEP BEAM
# ══════════════════════════════════════════════════════════════════════

@export var sweep_windup: float = 0.46
@export var sweep_duration_phase1: float = 1.10
@export var sweep_duration_phase2: float = 0.95
@export var sweep_duration_phase3: float = 0.78
@export var sweep_length: float = 900.0
@export var sweep_width: float = 22.0
@export var sweep_damage: float = 13.0
@export var sweep_tick_rate: float = 0.12
@export var sweep_arc_degrees: float = 145.0

# ══════════════════════════════════════════════════════════════════════
# ATTACK 4: SIGNAL BURST
# ══════════════════════════════════════════════════════════════════════

@export var burst_windup: float = 0.38
@export var burst_projectiles_phase1: int = 10
@export var burst_projectiles_phase2: int = 14
@export var burst_projectiles_phase3: int = 18
@export var burst_speed: float = 230.0
@export var burst_damage: int = 10
@export var burst_followup_delay: float = 0.22

# ══════════════════════════════════════════════════════════════════════
# PHASE 3 OVERDRIVE
# ══════════════════════════════════════════════════════════════════════

@export var overdrive_enabled: bool = true
@export var overdrive_grid_then_split_chance: float = 0.45
@export var overdrive_between_patterns_delay: float = 0.22

# ══════════════════════════════════════════════════════════════════════
# LOOT
# ══════════════════════════════════════════════════════════════════════

@export var loot_table: PowerUpTable
@export var loot_item_scene: PackedScene
@export var gold_pickup_scene: PackedScene

@export var min_gold_drop: int = 20
@export var max_gold_drop: int = 40
@export var gold_pile_count_min: int = 4
@export var gold_pile_count_max: int = 7
@export var guaranteed_drops: int = 1

var powerup_drop_chance: float = 1.0
var force_powerup_drop: bool = true
var is_wave_temporary_drop: bool = true

# ══════════════════════════════════════════════════════════════════════
# NODE REFS
# ══════════════════════════════════════════════════════════════════════

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var collision: CollisionShape2D = $CollisionShape2D

# ══════════════════════════════════════════════════════════════════════
# STATE
# ══════════════════════════════════════════════════════════════════════

enum Phase {
	ONE,
	TWO,
	THREE
}

enum State {
	REPOSITIONING,
	CHARGING_PATTERN,
	COOLDOWN,
	DEAD
}

enum Attack {
	RAIL_GRID,
	SPLIT_SIGNAL,
	SWEEP_BEAM,
	SIGNAL_BURST,
	OVERDRIVE
}

var target: Node2D = null
var phase: Phase = Phase.ONE
var state: State = State.REPOSITIONING

var attack_timer: float = 0.0
var last_attack: int = -1
var last_direction: Vector2 = Vector2.DOWN

var active_telegraphs: Array[Node] = []
var active_sweeps: Array[Node] = []

var boss_bar: BossHealthBarUI = null
var is_dying: bool = false


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")

	if health_component != null:
		if not health_component.died.is_connected(_on_died):
			health_component.died.connect(_on_died)

		if health_component.has_signal("damaged") and not health_component.damaged.is_connected(_on_damaged):
			health_component.damaged.connect(_on_damaged)

	_acquire_target()

	boss_bar = BossHealthBarUI.new()
	boss_bar.setup(boss_name, health_component)
	get_tree().current_scene.add_child.call_deferred(boss_bar)

	attack_timer = initial_attack_delay


func _physics_process(delta: float) -> void:
	if is_dying or health_component.is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not is_instance_valid(target):
		_acquire_target()

	_update_phase()

	match state:
		State.REPOSITIONING:
			_process_repositioning(delta)

		State.CHARGING_PATTERN:
			velocity = Vector2.ZERO
			play_idle_animation()

		State.COOLDOWN:
			_process_cooldown(delta)

		State.DEAD:
			velocity = Vector2.ZERO

	move_and_slide()


# ══════════════════════════════════════════════════════════════════════
# MANAGER API
# ══════════════════════════════════════════════════════════════════════

func set_target(new_target: Node2D) -> void:
	target = new_target


func set_gold_multiplier(_multiplier: float) -> void:
	pass


func set_powerup_drop_context(
	new_loot_table: PowerUpTable,
	new_loot_item_scene: PackedScene,
	new_drop_chance: float,
	new_force_drop: bool = false,
	new_is_wave_temporary: bool = true
) -> void:
	loot_table = new_loot_table
	loot_item_scene = new_loot_item_scene
	powerup_drop_chance = clampf(new_drop_chance, 0.0, 1.0)
	force_powerup_drop = new_force_drop
	is_wave_temporary_drop = new_is_wave_temporary


# ══════════════════════════════════════════════════════════════════════
# TARGETING / MOVEMENT
# ══════════════════════════════════════════════════════════════════════

func _acquire_target() -> void:
	var players := get_tree().get_nodes_in_group("player")

	if not players.is_empty():
		target = players[0] as Node2D


func _process_repositioning(delta: float) -> void:
	attack_timer -= delta

	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		play_idle_animation()
		return

	var desired_position := _get_reposition_target()
	var direction := global_position.direction_to(desired_position)
	var distance := global_position.distance_to(desired_position)

	if direction != Vector2.ZERO:
		last_direction = direction

	if distance > 18.0:
		velocity = direction * move_speed
		play_walk_animation(direction)
	else:
		velocity = Vector2.ZERO
		play_idle_animation()

	if attack_timer <= 0.0:
		_start_attack()


func _process_cooldown(delta: float) -> void:
	attack_timer -= delta

	if reposition_after_attack:
		state = State.REPOSITIONING
		return

	velocity = Vector2.ZERO
	play_idle_animation()

	if attack_timer <= 0.0:
		state = State.REPOSITIONING


func _get_reposition_target() -> Vector2:
	if not is_instance_valid(target):
		return global_position

	var away_from_player := target.global_position.direction_to(global_position)

	if away_from_player == Vector2.ZERO:
		away_from_player = Vector2.RIGHT.rotated(randf() * TAU)

	var orbit_angle := sin(Time.get_ticks_msec() / 450.0) * 0.75
	var orbit_dir := away_from_player.rotated(orbit_angle)

	return target.global_position + orbit_dir * reposition_distance


# ══════════════════════════════════════════════════════════════════════
# PHASES
# ══════════════════════════════════════════════════════════════════════

func _update_phase() -> void:
	if health_component == null or health_component.max_health <= 0:
		return

	var hp_percent := float(health_component.current_health) / float(health_component.max_health)
	var next_phase := Phase.ONE

	if hp_percent <= 0.33:
		next_phase = Phase.THREE
	elif hp_percent <= 0.66:
		next_phase = Phase.TWO

	if next_phase == phase:
		return

	phase = next_phase
	_play_phase_flash()


func _current_attack_cooldown() -> float:
	match phase:
		Phase.THREE:
			return attack_cooldown_phase3
		Phase.TWO:
			return attack_cooldown_phase2
		_:
			return attack_cooldown_phase1


func _current_grid_windup() -> float:
	match phase:
		Phase.THREE:
			return grid_windup_phase3
		Phase.TWO:
			return grid_windup_phase2
		_:
			return grid_windup_phase1


func _current_grid_lane_count() -> int:
	match phase:
		Phase.THREE:
			return grid_lane_count_phase3
		Phase.TWO:
			return grid_lane_count_phase2
		_:
			return grid_lane_count_phase1


func _current_sweep_duration() -> float:
	match phase:
		Phase.THREE:
			return sweep_duration_phase3
		Phase.TWO:
			return sweep_duration_phase2
		_:
			return sweep_duration_phase1


func _current_burst_projectile_count() -> int:
	match phase:
		Phase.THREE:
			return burst_projectiles_phase3
		Phase.TWO:
			return burst_projectiles_phase2
		_:
			return burst_projectiles_phase1


func _phase_tint() -> Color:
	match phase:
		Phase.THREE:
			return Color(1.35, 0.45, 0.35)
		Phase.TWO:
			return Color(1.15, 0.85, 0.55)
		_:
			return Color.WHITE


func _play_phase_flash() -> void:
	if animated_sprite == null:
		return

	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", Color(1.8, 0.35, 0.22), 0.08)
	tween.tween_property(animated_sprite, "modulate", _phase_tint(), 0.35)


# ══════════════════════════════════════════════════════════════════════
# ATTACK SELECTION
# ══════════════════════════════════════════════════════════════════════

func _start_attack() -> void:
	if is_dying or health_component.is_dead:
		return

	state = State.CHARGING_PATTERN
	velocity = Vector2.ZERO

	var chosen := _pick_attack()
	last_attack = chosen

	match chosen:
		Attack.RAIL_GRID:
			_attack_rail_grid()
		Attack.SPLIT_SIGNAL:
			_attack_split_signal()
		Attack.SWEEP_BEAM:
			_attack_sweep_beam()
		Attack.SIGNAL_BURST:
			_attack_signal_burst()
		Attack.OVERDRIVE:
			_attack_overdrive()


func _pick_attack() -> int:
	var pool: Array[int] = [
		Attack.RAIL_GRID,
		Attack.RAIL_GRID,
		Attack.SPLIT_SIGNAL,
		Attack.SPLIT_SIGNAL,
		Attack.SWEEP_BEAM,
		Attack.SIGNAL_BURST,
	]

	if phase == Phase.THREE and overdrive_enabled:
		pool.append(Attack.OVERDRIVE)
		pool.append(Attack.OVERDRIVE)

	pool.erase(last_attack)

	if pool.is_empty():
		return Attack.RAIL_GRID

	return pool.pick_random()


func _enter_cooldown() -> void:
	if is_dying or health_component.is_dead:
		return

	_clear_telegraphs()

	state = State.COOLDOWN
	attack_timer = _current_attack_cooldown()
	velocity = Vector2.ZERO


# ══════════════════════════════════════════════════════════════════════
# ATTACK 1: RAIL GRID
# ══════════════════════════════════════════════════════════════════════

func _attack_rail_grid() -> void:
	var center := _get_target_center()
	var windup := _current_grid_windup()

	_spawn_grid_pattern(center)

	_flash_sprite(Color(1.35, 0.55, 0.16), windup)

	await get_tree().create_timer(windup).timeout

	if _is_dead_or_invalid():
		_clear_telegraphs()
		return

	_fire_active_lanes(grid_damage)
	_clear_telegraphs()
	_enter_cooldown()


func _spawn_grid_pattern(center: Vector2) -> void:
	var lane_count := _current_grid_lane_count()
	var base_angle := _get_grid_base_angle()

	var perpendicular := Vector2(cos(base_angle), sin(base_angle))
	var direction := perpendicular.rotated(PI * 0.5)

	var offset_start := -float(lane_count - 1) * 0.5 * grid_lane_spacing

	for i in lane_count:
		var offset := offset_start + float(i) * grid_lane_spacing
		var start := center + perpendicular * offset - direction * (grid_lane_length * 0.5)

		_spawn_lane_telegraph(
			start,
			direction,
			grid_lane_length,
			grid_lane_width,
			Color(1.0, 0.36, 0.08, 0.68)
		)

	# Phase 2+ occasionally creates a perpendicular grid layer.
	if phase != Phase.ONE and randf() < 0.55:
		var second_direction := direction.rotated(PI * 0.5)
		var second_perpendicular := perpendicular.rotated(PI * 0.5)
		var second_count := maxi(2, lane_count - 1)
		var second_offset_start := -float(second_count - 1) * 0.5 * grid_lane_spacing

		for j in second_count:
			var offset := second_offset_start + float(j) * grid_lane_spacing
			var start := center + second_perpendicular * offset - second_direction * (grid_lane_length * 0.5)

			_spawn_lane_telegraph(
				start,
				second_direction,
				grid_lane_length,
				grid_lane_width * 0.85,
				Color(1.0, 0.18, 0.08, 0.50)
			)


func _get_grid_base_angle() -> float:
	match phase:
		Phase.ONE:
			return [0.0, PI * 0.5, PI * 0.25, -PI * 0.25].pick_random()
		Phase.TWO:
			return randf() * PI
		Phase.THREE:
			return randf() * TAU
		_:
			return 0.0


# ══════════════════════════════════════════════════════════════════════
# ATTACK 2: SPLIT SIGNAL
# ══════════════════════════════════════════════════════════════════════

func _attack_split_signal() -> void:
	var center := _get_target_center()

	_spawn_split_pattern(center, false)

	_flash_sprite(Color(1.45, 0.30, 0.18), split_windup)

	await get_tree().create_timer(split_windup).timeout

	if _is_dead_or_invalid():
		_clear_telegraphs()
		return

	_fire_active_lanes(split_damage)
	_clear_telegraphs()

	if phase == Phase.THREE and split_double_in_phase3:
		await get_tree().create_timer(split_second_delay).timeout

		if _is_dead_or_invalid():
			return

		_spawn_split_pattern(_get_target_center(), true)

		await get_tree().create_timer(maxf(0.25, split_windup * 0.65)).timeout

		if _is_dead_or_invalid():
			_clear_telegraphs()
			return

		_fire_active_lanes(split_damage * 0.8)
		_clear_telegraphs()

	_enter_cooldown()


func _spawn_split_pattern(center: Vector2, rotated: bool) -> void:
	var base_rotation := PI * 0.25 if rotated else 0.0

	var directions: Array[Vector2] = [
		Vector2.RIGHT.rotated(base_rotation),
		Vector2.UP.rotated(base_rotation),
	]

	if phase != Phase.ONE and split_diagonal_in_phase2:
		directions.append(Vector2.RIGHT.rotated(PI * 0.25 + base_rotation))
		directions.append(Vector2.RIGHT.rotated(-PI * 0.25 + base_rotation))

	for dir in directions:
		var start := center - dir.normalized() * (split_lane_length * 0.5)

		_spawn_lane_telegraph(
			start,
			dir,
			split_lane_length,
			split_lane_width,
			Color(1.0, 0.12, 0.05, 0.72)
		)


# ══════════════════════════════════════════════════════════════════════
# ATTACK 3: SWEEP BEAM
# ══════════════════════════════════════════════════════════════════════

func _attack_sweep_beam() -> void:
	var center := _get_target_center()
	var start_angle := randf() * TAU
	var clockwise := randf() > 0.5
	var sweep := SweepBeam.new()

	sweep.center_position = center
	sweep.start_angle = start_angle
	sweep.arc_radians = deg_to_rad(sweep_arc_degrees) * (1.0 if clockwise else -1.0)
	sweep.length = sweep_length
	sweep.width = sweep_width
	sweep.duration = _current_sweep_duration()
	sweep.tick_rate = sweep_tick_rate
	sweep.damage = sweep_damage
	sweep.owner_boss = self
	sweep.line_color = Color(1.0, 0.25, 0.08, 0.76)
	sweep.add_to_group("hazards")
	sweep.add_to_group("wave_cleanup")

	get_tree().current_scene.add_child(sweep)
	active_sweeps.append(sweep)

	_flash_sprite(Color(1.25, 0.75, 0.25), sweep_windup)

	await get_tree().create_timer(sweep_windup).timeout

	if _is_dead_or_invalid():
		if is_instance_valid(sweep):
			sweep.queue_free()
		return

	sweep.activate()

	await sweep.finished

	active_sweeps.erase(sweep)
	_enter_cooldown()


# ══════════════════════════════════════════════════════════════════════
# ATTACK 4: SIGNAL BURST
# ══════════════════════════════════════════════════════════════════════

func _attack_signal_burst() -> void:
	_flash_sprite(Color(1.0, 0.95, 0.45), burst_windup)

	await get_tree().create_timer(burst_windup).timeout

	if _is_dead_or_invalid():
		return

	_fire_radial_burst(_current_burst_projectile_count(), randf() * TAU)

	if phase != Phase.ONE:
		await get_tree().create_timer(burst_followup_delay).timeout

		if _is_dead_or_invalid():
			return

		_fire_radial_burst(_current_burst_projectile_count(), randf() * TAU)

	_enter_cooldown()


func _fire_radial_burst(count: int, offset: float) -> void:
	if count <= 0:
		return

	for i in count:
		var angle := (float(i) / float(count)) * TAU + offset
		var dir := Vector2(cos(angle), sin(angle))

		_fire_projectile(dir, burst_speed, burst_damage)


# ══════════════════════════════════════════════════════════════════════
# ATTACK 5: OVERDRIVE
# ══════════════════════════════════════════════════════════════════════

func _attack_overdrive() -> void:
	if randf() < overdrive_grid_then_split_chance:
		var center := _get_target_center()

		_spawn_grid_pattern(center)
		await get_tree().create_timer(maxf(0.32, _current_grid_windup() * 0.75)).timeout

		if _is_dead_or_invalid():
			_clear_telegraphs()
			return

		_fire_active_lanes(grid_damage * 0.85)
		_clear_telegraphs()

		await get_tree().create_timer(overdrive_between_patterns_delay).timeout

		if _is_dead_or_invalid():
			return

		_spawn_split_pattern(_get_target_center(), randf() > 0.5)
		await get_tree().create_timer(maxf(0.30, split_windup * 0.65)).timeout

		if _is_dead_or_invalid():
			_clear_telegraphs()
			return

		_fire_active_lanes(split_damage * 0.8)
		_clear_telegraphs()
	else:
		_fire_radial_burst(_current_burst_projectile_count(), randf() * TAU)

		await get_tree().create_timer(overdrive_between_patterns_delay).timeout

		if _is_dead_or_invalid():
			return

		var sweep := SweepBeam.new()
		sweep.center_position = _get_target_center()
		sweep.start_angle = randf() * TAU
		sweep.arc_radians = deg_to_rad(sweep_arc_degrees * 0.7)
		sweep.length = sweep_length
		sweep.width = sweep_width
		sweep.duration = maxf(0.45, _current_sweep_duration() * 0.65)
		sweep.tick_rate = sweep_tick_rate
		sweep.damage = sweep_damage * 0.75
		sweep.owner_boss = self
		sweep.line_color = Color(1.0, 0.18, 0.06, 0.68)
		sweep.add_to_group("hazards")
		sweep.add_to_group("wave_cleanup")

		get_tree().current_scene.add_child(sweep)
		active_sweeps.append(sweep)

		sweep.activate()
		await sweep.finished
		active_sweeps.erase(sweep)

	_enter_cooldown()


# ══════════════════════════════════════════════════════════════════════
# LANES / DAMAGE
# ══════════════════════════════════════════════════════════════════════

func _spawn_lane_telegraph(start: Vector2, direction: Vector2, length: float, width: float, color: Color) -> RailTelegraph:
	var lane := RailTelegraph.new()
	lane.start_position = start
	lane.direction = direction.normalized()
	lane.length = length
	lane.width = width
	lane.line_color = color
	lane.global_position = Vector2.ZERO
	lane.add_to_group("hazards")
	lane.add_to_group("wave_cleanup")

	get_tree().current_scene.add_child(lane)
	active_telegraphs.append(lane)

	return lane


func _fire_active_lanes(damage: float) -> void:
	for telegraph in active_telegraphs:
		if not is_instance_valid(telegraph):
			continue

		if not telegraph is RailTelegraph:
			continue

		var lane := telegraph as RailTelegraph
		lane.flash_fire()
		_damage_players_in_lane(
			lane.start_position,
			lane.direction,
			lane.length,
			lane.width,
			damage
		)


func _clear_telegraphs() -> void:
	for telegraph in active_telegraphs:
		if is_instance_valid(telegraph):
			telegraph.queue_free()

	active_telegraphs.clear()


func _damage_players_in_lane(start: Vector2, direction: Vector2, length: float, width: float, damage: float) -> void:
	var dir := direction.normalized()
	var end := start + dir * length

	for player in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(player):
			continue

		if not player is Node2D:
			continue

		var player_2d := player as Node2D
		var distance := _distance_point_to_segment(player_2d.global_position, start, end)

		if distance > width:
			continue

		var hc := player.get_node_or_null("HealthComponent")

		if hc != null and hc.has_method("take_damage"):
			hc.take_damage(damage, "physical")

		DamageNumberSpawner.spawn(
			player_2d.global_position,
			damage,
			DamageVisuals.get_display_name("physical"),
			DamageVisuals.get_color("physical"),
			0,
			false
		)


func _distance_point_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var ab_len_sq := ab.length_squared()

	if ab_len_sq <= 0.001:
		return point.distance_to(a)

	var t := clampf((point - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	var closest := a + ab * t

	return point.distance_to(closest)


# ══════════════════════════════════════════════════════════════════════
# PROJECTILES
# ══════════════════════════════════════════════════════════════════════

func _fire_projectile(direction: Vector2, speed: float, damage: int) -> void:
	if boss_projectile_scene == null:
		return

	var projectile := boss_projectile_scene.instantiate() as Node2D

	if projectile == null:
		return

	var safe_dir := direction.normalized()

	if safe_dir == Vector2.ZERO:
		safe_dir = Vector2.DOWN

	projectile.global_position = global_position + safe_dir * 18.0
	projectile.add_to_group("enemy_projectiles")
	projectile.add_to_group("hazards")
	projectile.add_to_group("wave_cleanup")

	get_tree().current_scene.add_child(projectile)

	if projectile.has_method("setup"):
		projectile.setup(safe_dir, damage)

	if "speed" in projectile:
		projectile.speed = speed


# ══════════════════════════════════════════════════════════════════════
# VISUAL HELPERS
# ══════════════════════════════════════════════════════════════════════

func _get_target_center() -> Vector2:
	if is_instance_valid(target):
		return target.global_position

	return global_position


func _flash_sprite(color: Color, duration: float) -> void:
	if animated_sprite == null:
		return

	var original := animated_sprite.modulate
	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", color, duration * 0.45)
	tween.tween_property(animated_sprite, "modulate", original, duration * 0.55)


func _is_dead_or_invalid() -> bool:
	if is_dying:
		return true

	if health_component == null:
		return true

	if health_component.is_dead:
		return true

	return false


# ══════════════════════════════════════════════════════════════════════
# LOOT
# ══════════════════════════════════════════════════════════════════════

func drop_gold() -> void:
	if gold_pickup_scene == null:
		return

	var pile_count := randi_range(gold_pile_count_min, gold_pile_count_max)

	for _i in pile_count:
		var gold_pickup := gold_pickup_scene.instantiate() as GoldPickup

		if gold_pickup == null:
			continue

		gold_pickup.gold_amount = randi_range(min_gold_drop, max_gold_drop)
		gold_pickup.global_position = global_position + Vector2(
			randf_range(-34.0, 34.0),
			randf_range(-34.0, 34.0)
		)

		get_tree().current_scene.add_child(gold_pickup)


func drop_loot() -> void:
	if loot_table == null:
		return

	if loot_item_scene == null:
		return

	if not force_powerup_drop and randf() > powerup_drop_chance:
		return

	var drop_count := maxi(1, guaranteed_drops)
	var drops: Array[PowerUpData] = []
	var attempts := 0
	var max_attempts := drop_count * 12

	while drops.size() < drop_count and attempts < max_attempts:
		attempts += 1

		var drop := loot_table.roll_drop()

		if drop == null:
			continue

		drops.append(drop)

	for i in drops.size():
		_spawn_powerup_pickup(drops[i], i, drops.size())


func _spawn_powerup_pickup(powerup: PowerUpData, index: int, total_count: int) -> void:
	if powerup == null:
		return

	var powerup_pickup := loot_item_scene.instantiate() as PowerUpPickup

	if powerup_pickup == null:
		push_warning("RailWardenBoss: loot_item_scene root is not a PowerUpPickup.")
		return

	powerup_pickup.powerup_data = powerup
	powerup_pickup.is_wave_temporary = is_wave_temporary_drop

	var angle := (float(index) / float(maxi(1, total_count))) * TAU
	var offset := Vector2(cos(angle), sin(angle)) * 32.0

	powerup_pickup.global_position = global_position + offset

	get_tree().current_scene.add_child(powerup_pickup)


# ══════════════════════════════════════════════════════════════════════
# DAMAGE FEEDBACK / DEATH
# ══════════════════════════════════════════════════════════════════════

func _on_damaged(_amount: int) -> void:
	if animated_sprite == null:
		return

	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", Color(1.8, 0.35, 0.25), 0.05)
	tween.tween_property(animated_sprite, "modulate", _phase_tint(), 0.18)


func _on_died() -> void:
	if is_dying:
		return

	is_dying = true
	state = State.DEAD

	target = null
	velocity = Vector2.ZERO

	_clear_telegraphs()

	for sweep in active_sweeps:
		if is_instance_valid(sweep):
			sweep.queue_free()

	active_sweeps.clear()

	if collision != null:
		collision.set_deferred("disabled", true)

	if has_node("Hurtbox"):
		$Hurtbox.set_deferred("monitoring", false)
		$Hurtbox.set_deferred("monitorable", false)

	var status_component := get_node_or_null("StatusEffectComponent") as StatusEffectComponent

	if status_component != null:
		status_component.on_enemy_death()

	drop_gold.call_deferred()
	drop_loot.call_deferred()

	play_death_animation()

	if animated_sprite != null and animated_sprite.sprite_frames != null:
		if animated_sprite.sprite_frames.has_animation("death"):
			await animated_sprite.animation_finished

	queue_free()


# ══════════════════════════════════════════════════════════════════════
# ANIMATION
# ══════════════════════════════════════════════════════════════════════

func play_walk_animation(direction: Vector2) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return

	if abs(direction.x) > abs(direction.y):
		if direction.x > 0.0:
			AnimationHelper.play_if_exists(animated_sprite, "walk_right")
		else:
			AnimationHelper.play_if_exists(animated_sprite, "walk_left")
	else:
		if direction.y > 0.0:
			AnimationHelper.play_if_exists(animated_sprite, "walk_down")
		else:
			AnimationHelper.play_if_exists(animated_sprite, "walk_up")


func play_idle_animation() -> void:
	if animated_sprite == null:
		return

	AnimationHelper.play_if_exists(animated_sprite, "idle")


func play_death_animation() -> void:
	if animated_sprite == null:
		return

	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
	else:
		hide()


# ══════════════════════════════════════════════════════════════════════
# INNER CLASS: RAIL TELEGRAPH
# ══════════════════════════════════════════════════════════════════════

class RailTelegraph extends Node2D:
	var start_position: Vector2 = Vector2.ZERO
	var direction: Vector2 = Vector2.RIGHT
	var length: float = 300.0
	var width: float = 16.0
	var line_color: Color = Color(1.0, 0.2, 0.1, 0.65)
	var pulse_alpha: float = 1.0
	var fired_flash: float = 0.0

	func _ready() -> void:
		z_index = 7

		var tween := create_tween().set_loops()
		tween.tween_method(
			func(value: float) -> void:
				pulse_alpha = value
				queue_redraw(),
			0.35,
			1.0,
			0.09
		)
		tween.tween_method(
			func(value: float) -> void:
				pulse_alpha = value
				queue_redraw(),
			1.0,
			0.35,
			0.09
		)


	func flash_fire() -> void:
		fired_flash = 1.0
		queue_redraw()

		var tween := create_tween()
		tween.tween_method(
			func(value: float) -> void:
				fired_flash = value
				queue_redraw(),
			1.0,
			0.0,
			0.16
		)


	func _draw() -> void:
		var end := start_position + direction.normalized() * length
		var alpha := line_color.a * pulse_alpha
		var color := Color(line_color.r, line_color.g, line_color.b, alpha)

		draw_line(start_position, end, Color(color.r, color.g, color.b, alpha * 0.30), width * 2.2)
		draw_line(start_position, end, color, width)
		draw_line(start_position, end, Color(1.0, 1.0, 1.0, alpha * 0.65), maxf(2.0, width * 0.18))

		if fired_flash > 0.0:
			draw_line(
				start_position,
				end,
				Color(1.0, 1.0, 1.0, fired_flash),
				width * 1.35
			)


# ══════════════════════════════════════════════════════════════════════
# INNER CLASS: SWEEP BEAM
# ══════════════════════════════════════════════════════════════════════

class SweepBeam extends Node2D:
	signal finished

	var center_position: Vector2 = Vector2.ZERO
	var start_angle: float = 0.0
	var arc_radians: float = PI
	var length: float = 800.0
	var width: float = 22.0
	var duration: float = 1.0
	var tick_rate: float = 0.12
	var damage: float = 12.0
	var owner_boss: Node = null
	var line_color: Color = Color(1.0, 0.25, 0.08, 0.75)

	var _active: bool = false
	var _elapsed: float = 0.0
	var _tick_timer: float = 0.0
	var _current_angle: float = 0.0


	func _ready() -> void:
		z_index = 8
		_current_angle = start_angle
		queue_redraw()


	func activate() -> void:
		_active = true
		_elapsed = 0.0
		_tick_timer = 0.0


	func _process(delta: float) -> void:
		if not _active:
			queue_redraw()
			return

		_elapsed += delta
		_tick_timer += delta

		var t := clampf(_elapsed / maxf(0.01, duration), 0.0, 1.0)
		_current_angle = start_angle + arc_radians * t

		if _tick_timer >= tick_rate:
			_tick_timer = 0.0
			_damage_players()

		queue_redraw()

		if _elapsed >= duration:
			finished.emit()
			queue_free()


	func _damage_players() -> void:
		var dir := Vector2(cos(_current_angle), sin(_current_angle))
		var start := center_position - dir * (length * 0.5)
		var end := center_position + dir * (length * 0.5)

		var tree := get_tree()

		if tree == null:
			return

		for player in tree.get_nodes_in_group("player"):
			if not is_instance_valid(player):
				continue

			if not player is Node2D:
				continue

			var player_2d := player as Node2D
			var distance := _distance_point_to_segment(player_2d.global_position, start, end)

			if distance > width:
				continue

			var hc := player.get_node_or_null("HealthComponent")

			if hc != null and hc.has_method("take_damage"):
				hc.take_damage(damage, "physical")

			DamageNumberSpawner.spawn(
				player_2d.global_position,
				damage,
				DamageVisuals.get_display_name("physical"),
				DamageVisuals.get_color("physical"),
				0,
				false
			)


	func _distance_point_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
		var ab := b - a
		var ab_len_sq := ab.length_squared()

		if ab_len_sq <= 0.001:
			return point.distance_to(a)

		var t := clampf((point - a).dot(ab) / ab_len_sq, 0.0, 1.0)
		var closest := a + ab * t

		return point.distance_to(closest)


	func _draw() -> void:
		var dir := Vector2(cos(_current_angle), sin(_current_angle))
		var start := center_position - dir * (length * 0.5)
		var end := center_position + dir * (length * 0.5)

		var alpha := line_color.a

		if not _active:
			alpha *= 0.35

		draw_line(start, end, Color(line_color.r, line_color.g, line_color.b, alpha * 0.25), width * 2.4)
		draw_line(start, end, Color(line_color.r, line_color.g, line_color.b, alpha), width)
		draw_line(start, end, Color(1.0, 1.0, 1.0, alpha * 0.65), maxf(2.0, width * 0.18))
