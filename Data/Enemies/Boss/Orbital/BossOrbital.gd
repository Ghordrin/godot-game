extends CharacterBody2D
class_name OrbitalCannonBoss

## Orbital Strike Boss
## Identity:
## - Slow, heavy, artillery-style boss.
## - Controls space with delayed orbital warnings.
## - Escalates through phases by adding more strikes, more shards, and faster cadence.
## - Boss drops are injected by WaveManager through set_powerup_drop_context().

# ══════════════════════════════════════════════════════════════════════
# MOVEMENT / IDENTITY
# ══════════════════════════════════════════════════════════════════════

@export var move_speed: float = 22.0
@export var stop_distance: float = 220.0
@export var boss_name: String = "The Dreadnought"

# ══════════════════════════════════════════════════════════════════════
# PHASE / ATTACK CADENCE
# ══════════════════════════════════════════════════════════════════════

@export var cooldown_phase1: float = 6.0
@export var cooldown_phase2: float = 4.5
@export var cooldown_phase3: float = 3.0

@export var initial_cooldown: float = 3.0
@export var telegraph_duration: float = 2.35
@export var multi_strike_delay: float = 1.05

# ══════════════════════════════════════════════════════════════════════
# ORBITAL STRIKE
# ══════════════════════════════════════════════════════════════════════

@export var inner_radius: float = 60.0
@export var outer_radius: float = 140.0
@export var strike_damage: float = 120.0

@export var strike_lead_player: bool = true
@export var strike_lead_amount: float = 0.45

# ══════════════════════════════════════════════════════════════════════
# SHARDS / IMPACT
# ══════════════════════════════════════════════════════════════════════

@export var shard_count_phase1: int = 16
@export var shard_count_phase2: int = 24
@export var shard_count_phase3: int = 32

@export var shard_speed: float = 210.0
@export var shard_speed_phase3_mult: float = 1.4
@export var shard_damage: float = 35.0

@export var shard_spin_offset: bool = true

# ══════════════════════════════════════════════════════════════════════
# MULTI STRIKES
# ══════════════════════════════════════════════════════════════════════

@export var strikes_phase2: int = 2
@export var strikes_phase3: int = 3

@export var phase3_crossfire_enabled: bool = true
@export var phase3_crossfire_delay: float = 0.22
@export var phase3_crossfire_damage_mult: float = 0.55

# ══════════════════════════════════════════════════════════════════════
# LOOT
# ══════════════════════════════════════════════════════════════════════

@export var loot_table: PowerUpTable
@export var loot_item_scene: PackedScene
@export var gold_pickup_scene: PackedScene

@export var min_gold_drop := 20
@export var max_gold_drop := 45
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

var target: Node2D = null
var _phase: Phase = Phase.ONE
var _attacking: bool = false
var _cooldown: float = 0.0
var _charge_tween: Tween = null
var _is_dying: bool = false
var _last_target_position: Vector2 = Vector2.ZERO
var _target_velocity_estimate: Vector2 = Vector2.ZERO
var _boss_bar: BossHealthBarUI = null


func _ready() -> void:
	health_component.died.connect(_on_died)

	if health_component.has_signal("damaged"):
		health_component.damaged.connect(_on_damaged)

	_acquire_target()
	add_to_group("enemies")
	add_to_group("bosses")

	_cooldown = initial_cooldown

	_boss_bar = BossHealthBarUI.new()
	_boss_bar.setup(boss_name, health_component)
	get_tree().current_scene.add_child.call_deferred(_boss_bar)


func _physics_process(delta: float) -> void:
	if health_component.is_dead or _is_dying:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not is_instance_valid(target):
		_acquire_target()

	_update_target_velocity(delta)
	_update_phase()

	if not _attacking:
		_drift_toward_target()
		_cooldown -= delta

		if _cooldown <= 0.0:
			_start_attack_sequence()

	move_and_slide()


# ══════════════════════════════════════════════════════════════════════
# MANAGER API
# ══════════════════════════════════════════════════════════════════════

func set_target(new_target: Node2D) -> void:
	target = new_target

	if is_instance_valid(target):
		_last_target_position = target.global_position


func set_gold_multiplier(_mult: float) -> void:
	# Boss gold is controlled by boss-specific pile values.
	# Method exists so WaveManager can call it safely.
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

		if is_instance_valid(target):
			_last_target_position = target.global_position


func _update_target_velocity(delta: float) -> void:
	if not is_instance_valid(target):
		_target_velocity_estimate = Vector2.ZERO
		return

	if delta <= 0.0:
		return

	var current_position: Vector2 = target.global_position
	_target_velocity_estimate = (current_position - _last_target_position) / delta
	_last_target_position = current_position


func _drift_toward_target() -> void:
	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		return

	var dist: float = global_position.distance_to(target.global_position)

	if dist > stop_distance:
		velocity = global_position.direction_to(target.global_position) * move_speed
	else:
		velocity = Vector2.ZERO


# ══════════════════════════════════════════════════════════════════════
# PHASES
# ══════════════════════════════════════════════════════════════════════

func _update_phase() -> void:
	if health_component.max_health <= 0:
		return

	var pct: float = float(health_component.current_health) / float(health_component.max_health)
	var new_phase: Phase = Phase.ONE

	if pct > 0.66:
		new_phase = Phase.ONE
	elif pct > 0.33:
		new_phase = Phase.TWO
	else:
		new_phase = Phase.THREE

	if new_phase != _phase:
		_phase = new_phase
		_on_phase_changed()


func _on_phase_changed() -> void:
	if animated_sprite == null:
		return

	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", Color(2.0, 0.5, 0.5), 0.1)
	tween.tween_property(animated_sprite, "modulate", _phase_tint(), 0.4)


func _phase_tint() -> Color:
	match _phase:
		Phase.TWO:
			return Color(1.3, 0.8, 0.6)

		Phase.THREE:
			return Color(1.5, 0.5, 0.5)

		_:
			return Color.WHITE


func _current_cooldown() -> float:
	match _phase:
		Phase.TWO:
			return cooldown_phase2

		Phase.THREE:
			return cooldown_phase3

		_:
			return cooldown_phase1


func _current_strike_count() -> int:
	match _phase:
		Phase.TWO:
			return strikes_phase2

		Phase.THREE:
			return strikes_phase3

		_:
			return 1


func _current_shard_count() -> int:
	match _phase:
		Phase.TWO:
			return shard_count_phase2

		Phase.THREE:
			return shard_count_phase3

		_:
			return shard_count_phase1


func _current_shard_speed() -> float:
	if _phase == Phase.THREE:
		return shard_speed * shard_speed_phase3_mult

	return shard_speed


# ══════════════════════════════════════════════════════════════════════
# ATTACK FLOW
# ══════════════════════════════════════════════════════════════════════

func _start_attack_sequence() -> void:
	if _attacking:
		return

	_attacking = true
	velocity = Vector2.ZERO

	_play_charge_animation()

	await get_tree().create_timer(0.6).timeout

	var strike_count: int = _current_strike_count()

	for i in strike_count:
		if _is_dead_or_invalid():
			break

		await _fire_single_strike(i)

		if i < strike_count - 1:
			await get_tree().create_timer(multi_strike_delay).timeout

	_attacking = false
	_cooldown = _current_cooldown()


func _fire_single_strike(index: int = 0) -> void:
	if not is_instance_valid(target):
		return

	var strike_pos: Vector2 = _get_strike_position(index)

	var warning := OrbitalWarning.new()
	warning.global_position = strike_pos
	warning.duration = telegraph_duration
	warning.inner_radius = inner_radius
	warning.outer_radius = outer_radius
	warning.add_to_group("hazards")
	warning.add_to_group("wave_cleanup")

	get_tree().current_scene.add_child(warning)

	await warning.warning_complete

	if _is_dead_or_invalid():
		if is_instance_valid(warning):
			warning.queue_free()
		return

	_execute_strike(strike_pos)


func _get_strike_position(index: int) -> Vector2:
	if not is_instance_valid(target):
		return global_position

	var base_pos: Vector2 = target.global_position

	if strike_lead_player:
		base_pos += _target_velocity_estimate * strike_lead_amount

	if _phase == Phase.ONE:
		return base_pos

	if _phase == Phase.TWO:
		var offset_angle: float = float(index) * PI
		var offset := Vector2(cos(offset_angle), sin(offset_angle)) * 45.0
		return base_pos + offset

	var phase3_angle: float = (float(index) / float(maxi(1, _current_strike_count()))) * TAU + randf_range(-0.35, 0.35)
	var phase3_dist: float = randf_range(35.0, 85.0)

	return base_pos + Vector2(cos(phase3_angle), sin(phase3_angle)) * phase3_dist


func _execute_strike(pos: Vector2) -> void:
	_apply_strike_to_players(pos)
	_apply_strike_to_enemies(pos)
	_spawn_shards(pos)
	_play_impact_flash(pos)

	if _phase == Phase.THREE and phase3_crossfire_enabled:
		_spawn_phase3_crossfire(pos)


func _spawn_phase3_crossfire(pos: Vector2) -> void:
	await get_tree().create_timer(phase3_crossfire_delay).timeout

	if _is_dead_or_invalid():
		return

	var dirs: Array[Vector2] = [
		Vector2.RIGHT,
		Vector2.LEFT,
		Vector2.UP,
		Vector2.DOWN
	]

	for dir in dirs:
		var shard: OrbitalShard = OrbitalShard.create(
			dir,
			_current_shard_speed() * 1.15,
			shard_damage * phase3_crossfire_damage_mult
		)

		if shard == null:
			continue

		shard.global_position = pos
		_add_hazard_to_scene(shard)


# ══════════════════════════════════════════════════════════════════════
# DAMAGE
# ══════════════════════════════════════════════════════════════════════

func _apply_strike_to_players(pos: Vector2) -> void:
	for player in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(player):
			continue

		if not player is Node2D:
			continue

		var player_2d := player as Node2D
		var dmg: float = _calculate_strike_damage(pos, player_2d.global_position)

		if dmg <= 0.0:
			continue

		var hc := player.get_node_or_null("HealthComponent")

		if hc != null and hc.has_method("take_damage"):
			hc.take_damage(dmg, "physical")

		DamageNumberSpawner.spawn(
			player_2d.global_position,
			dmg,
			DamageVisuals.get_display_name("physical"),
			DamageVisuals.get_color("physical"),
			0,
			false
		)


func _apply_strike_to_enemies(pos: Vector2) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		if enemy == self:
			continue

		if not enemy is Node2D:
			continue

		var enemy_2d := enemy as Node2D
		var dmg: float = _calculate_strike_damage(pos, enemy_2d.global_position)

		if dmg <= 0.0:
			continue

		var hc := enemy.get_node_or_null("HealthComponent")

		if hc != null and hc.has_method("take_damage"):
			hc.take_damage(dmg, "combo")

		DamageNumberSpawner.spawn(
			enemy_2d.global_position,
			dmg,
			DamageVisuals.get_display_name("combo"),
			DamageVisuals.get_color("combo"),
			0,
			false
		)


func _calculate_strike_damage(strike_pos: Vector2, victim_pos: Vector2) -> float:
	var dist: float = strike_pos.distance_to(victim_pos)

	if dist <= inner_radius:
		return strike_damage

	if dist <= outer_radius:
		var falloff: float = 1.0 - ((dist - inner_radius) / (outer_radius - inner_radius))
		return strike_damage * falloff * 0.6

	return 0.0


# ══════════════════════════════════════════════════════════════════════
# SHARDS / VISUALS
# ══════════════════════════════════════════════════════════════════════

func _spawn_shards(pos: Vector2) -> void:
	var count: int = _current_shard_count()
	var spd: float = _current_shard_speed()

	if count <= 0:
		return

	var angle_step: float = TAU / float(count)
	var base_angle: float = 0.0

	if shard_spin_offset:
		base_angle = randf() * angle_step

	for i in count:
		var angle: float = base_angle + float(i) * angle_step
		var dir := Vector2(cos(angle), sin(angle))
		var shard: OrbitalShard = OrbitalShard.create(dir, spd, shard_damage)

		if shard == null:
			continue

		shard.global_position = pos
		_add_hazard_to_scene(shard)


func _add_hazard_to_scene(node: Node2D) -> void:
	node.add_to_group("enemy_projectiles")
	node.add_to_group("hazards")
	node.add_to_group("wave_cleanup")
	get_tree().current_scene.add_child(node)


func _play_charge_animation() -> void:
	if animated_sprite == null:
		return

	if _charge_tween != null and _charge_tween.is_valid():
		_charge_tween.kill()

	_charge_tween = create_tween().set_loops(3)
	_charge_tween.tween_property(animated_sprite, "modulate", Color(1.5, 1.0, 0.3), 0.2)
	_charge_tween.tween_property(animated_sprite, "modulate", _phase_tint(), 0.2)


func _play_impact_flash(pos: Vector2) -> void:
	var flash := Node2D.new()
	flash.global_position = pos
	flash.z_index = 10
	flash.add_to_group("hazards")
	flash.add_to_group("wave_cleanup")

	get_tree().current_scene.add_child(flash)

	var tween := flash.create_tween()
	tween.tween_interval(0.12)
	tween.tween_callback(flash.queue_free)


# ══════════════════════════════════════════════════════════════════════
# LOOT
# ══════════════════════════════════════════════════════════════════════

func drop_gold() -> void:
	if gold_pickup_scene == null:
		return

	var pile_count: int = randi_range(gold_pile_count_min, gold_pile_count_max)

	for _i in pile_count:
		var gold_pickup := gold_pickup_scene.instantiate() as GoldPickup

		if gold_pickup == null:
			continue

		gold_pickup.gold_amount = randi_range(min_gold_drop, max_gold_drop)
		gold_pickup.global_position = global_position + Vector2(
			randf_range(-32.0, 32.0),
			randf_range(-32.0, 32.0)
		)

		get_tree().current_scene.add_child(gold_pickup)


func drop_loot() -> void:
	if loot_table == null:
		return

	if loot_item_scene == null:
		return

	if not force_powerup_drop and randf() > powerup_drop_chance:
		return

	var drop_count: int = maxi(1, guaranteed_drops)
	var drops: Array[PowerUpData] = []

	var attempts: int = 0
	var max_attempts: int = drop_count * 12

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
		push_warning("OrbitalCannonBoss: loot_item_scene root is not a PowerUpPickup.")
		return

	powerup_pickup.powerup_data = powerup
	powerup_pickup.is_wave_temporary = is_wave_temporary_drop

	var angle: float = (float(index) / float(maxi(1, total_count))) * TAU
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
	tween.tween_property(animated_sprite, "modulate", Color(2.0, 0.4, 0.4), 0.05)
	tween.tween_property(animated_sprite, "modulate", _phase_tint(), 0.2)


func _on_died() -> void:
	target = null
	velocity = Vector2.ZERO

	collision.set_deferred("disabled", true)

	if has_node("Hurtbox"):
		$Hurtbox.set_deferred("monitoring", false)
		$Hurtbox.set_deferred("monitorable", false)

	var status_component := get_node_or_null("StatusEffectComponent") as StatusEffectComponent
	if status_component != null:
		status_component.on_enemy_death()

	drop_gold.call_deferred()
	drop_loot.call_deferred()
	#play_death_animation()

	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("death"):
		await animated_sprite.animation_finished

	queue_free()


# ══════════════════════════════════════════════════════════════════════
# UTILITY
# ══════════════════════════════════════════════════════════════════════

func _is_dead_or_invalid() -> bool:
	if not is_instance_valid(self):
		return true

	if health_component == null:
		return true

	if health_component.is_dead:
		return true

	if _is_dying:
		return true

	return false
