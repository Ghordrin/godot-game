extends CharacterBody2D
class_name BossEnemy

# ══════════════════════════════════════════════════════════════════════
# MOVEMENT / IDENTITY
# ══════════════════════════════════════════════════════════════════════

@export var move_speed: float = 58.0
@export var stop_distance: float = 44.0
@export var boss_name: String = "The Brute"

# ══════════════════════════════════════════════════════════════════════
# GENERAL ATTACK CONFIG
# ══════════════════════════════════════════════════════════════════════

@export var boss_projectile_scene: PackedScene
@export var attack_range: float = 360.0
@export var attack_cooldown: float = 2.4

# ══════════════════════════════════════════════════════════════════════
# ATTACK 1: CRUSHING CHARGE
# ══════════════════════════════════════════════════════════════════════

@export var charge_windup_time: float = 0.65
@export var charge_speed: float = 330.0
@export var charge_overshoot_distance: float = 72.0
@export var charge_damage: int = 18

@export var charge_debris_interval: float = 0.055
@export var charge_debris_speed: float = 85.0
@export var charge_debris_damage: int = 9

@export var charge_impact_projectiles: int = 14
@export var charge_impact_speed: float = 130.0
@export var charge_impact_damage: int = 14

# ══════════════════════════════════════════════════════════════════════
# ATTACK 2: GROUND SLAM COMBO
# ══════════════════════════════════════════════════════════════════════

@export var slam_count: int = 3
@export var slam_windup_time: float = 0.35
@export var slam_delay: float = 0.42

@export var slam_ring_size: int = 16
@export var slam_base_speed: float = 95.0
@export var slam_speed_step: float = 22.0
@export var slam_damage: int = 12

@export var slam_cross_enabled: bool = true
@export var slam_cross_speed: float = 145.0
@export var slam_cross_damage: int = 13

# ══════════════════════════════════════════════════════════════════════
# ATTACK 3: BOULDER TOSS
# ══════════════════════════════════════════════════════════════════════

@export var boulder_windup_time: float = 0.7
@export var boulder_count: int = 3
@export var boulder_delay: float = 0.18
@export var boulder_speed: float = 175.0
@export var boulder_damage: int = 20

@export var boulder_fragment_count: int = 6
@export var boulder_fragment_speed: float = 95.0
@export var boulder_fragment_damage: int = 8

# ══════════════════════════════════════════════════════════════════════
# ATTACK 4: ENRAGE ROAR
# ══════════════════════════════════════════════════════════════════════

@export var roar_windup_time: float = 0.45
@export var roar_projectile_count: int = 20
@export var roar_projectile_speed: float = 115.0
@export var roar_damage: int = 10

@export var roar_self_speed_mult: float = 1.35
@export var roar_buff_duration: float = 2.2

# ══════════════════════════════════════════════════════════════════════
# LOOT
# ══════════════════════════════════════════════════════════════════════

@export var loot_table: PowerUpTable
@export var loot_item_scene: PackedScene
@export var gold_pickup_scene: PackedScene

@export var min_gold_drop := 15
@export var max_gold_drop := 30
@export var gold_pile_count_min: int = 3
@export var gold_pile_count_max: int = 5

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

enum State {
	CHASING,
	ATTACKING,
	CHARGING,
	COOLDOWN
}

enum Attack {
	CRUSHING_CHARGE,
	GROUND_SLAM,
	BOULDER_TOSS,
	ENRAGE_ROAR
}

var state: State = State.CHASING
var target: Node2D = null
var last_direction: Vector2 = Vector2.DOWN
var attack_timer: float = 0.0
var last_attack: int = -1
var boss_bar: BossHealthBarUI = null
var base_move_speed: float = 0.0
var is_enraged: bool = false


func _ready() -> void:
	base_move_speed = move_speed

	health_component.died.connect(_on_died)

	_acquire_target()
	add_to_group("enemies")
	add_to_group("bosses")

	boss_bar = BossHealthBarUI.new()
	boss_bar.setup(boss_name, health_component)
	get_tree().current_scene.add_child.call_deferred(boss_bar)

	attack_timer = attack_cooldown * 0.45


func _physics_process(delta: float) -> void:
	if health_component.is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not is_instance_valid(target):
		_acquire_target()
		velocity = Vector2.ZERO
		play_idle_animation()
		move_and_slide()
		return

	match state:
		State.CHASING:
			_state_chasing(delta)

		State.ATTACKING:
			velocity = Vector2.ZERO
			play_idle_animation()

		State.CHARGING:
			move_and_slide()
			return

		State.COOLDOWN:
			follow_target()
			attack_timer -= delta

			if attack_timer <= 0.0:
				state = State.CHASING

	move_and_slide()


# ══════════════════════════════════════════════════════════════════════
# MANAGER API
# ══════════════════════════════════════════════════════════════════════

func set_target(new_target: Node2D) -> void:
	target = new_target


func set_gold_multiplier(_multiplier: float) -> void:
	# Boss gold is controlled through min/max pile values.
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


func _state_chasing(delta: float) -> void:
	follow_target()
	attack_timer -= delta

	if attack_timer > 0.0:
		return

	if not is_instance_valid(target):
		return

	var dist := global_position.distance_to(target.global_position)

	if dist <= attack_range:
		_start_attack()


func follow_target() -> void:
	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		play_idle_animation()
		return

	var direction: Vector2 = global_position.direction_to(target.global_position)
	var distance: float = global_position.distance_to(target.global_position)

	last_direction = direction

	if distance > stop_distance:
		velocity = direction * move_speed
		play_walk_animation(direction)
	else:
		velocity = Vector2.ZERO
		play_idle_animation()


# ══════════════════════════════════════════════════════════════════════
# ATTACK SELECTION
# ══════════════════════════════════════════════════════════════════════

func _start_attack() -> void:
	if boss_projectile_scene == null:
		push_warning("BruteBoss: boss_projectile_scene not assigned.")
		attack_timer = attack_cooldown
		return

	var options: Array[int] = [
		Attack.CRUSHING_CHARGE,
		Attack.GROUND_SLAM,
		Attack.BOULDER_TOSS,
		Attack.ENRAGE_ROAR
	]

	options.erase(last_attack)

	var chosen: int = options.pick_random()
	last_attack = chosen

	match chosen:
		Attack.CRUSHING_CHARGE:
			state = State.ATTACKING
			_attack_crushing_charge()

		Attack.GROUND_SLAM:
			state = State.ATTACKING
			_attack_ground_slam_combo()

		Attack.BOULDER_TOSS:
			state = State.ATTACKING
			_attack_boulder_toss()

		Attack.ENRAGE_ROAR:
			state = State.ATTACKING
			_attack_enrage_roar()


# ══════════════════════════════════════════════════════════════════════
# ATTACK 1: CRUSHING CHARGE
# ══════════════════════════════════════════════════════════════════════

func _attack_crushing_charge() -> void:
	if health_component.is_dead:
		return

	if not is_instance_valid(target):
		_enter_cooldown()
		return

	velocity = Vector2.ZERO

	var original_color: Color = animated_sprite.modulate
	var original_scale: Vector2 = animated_sprite.scale
	var charge_target: Vector2 = target.global_position

	await _telegraph(Color(1.0, 0.18, 0.08), original_scale * 1.22, charge_windup_time)

	if health_component.is_dead:
		return

	var direction: Vector2 = global_position.direction_to(charge_target)
	var distance: float = global_position.distance_to(charge_target) + charge_overshoot_distance
	var traveled: float = 0.0
	var debris_timer: float = 0.0

	state = State.CHARGING

	while traveled < distance:
		if health_component.is_dead:
			return

		var delta: float = get_physics_process_delta_time()
		var step: float = charge_speed * delta

		velocity = direction * charge_speed
		global_position += direction * step
		traveled += step
		debris_timer += delta

		if debris_timer >= charge_debris_interval:
			debris_timer = 0.0
			_spawn_charge_debris(direction)

		await get_tree().process_frame

	velocity = Vector2.ZERO
	state = State.ATTACKING

	_spawn_impact_ring(charge_impact_projectiles, charge_impact_speed, charge_impact_damage)

	animated_sprite.modulate = original_color
	animated_sprite.scale = original_scale

	_enter_cooldown()


func _spawn_charge_debris(direction: Vector2) -> void:
	var perpendicular := Vector2(-direction.y, direction.x)

	_fire_projectile(perpendicular, charge_debris_speed, charge_debris_damage, 8.0)
	_fire_projectile(-perpendicular, charge_debris_speed, charge_debris_damage, 8.0)


# ══════════════════════════════════════════════════════════════════════
# ATTACK 2: GROUND SLAM COMBO
# ══════════════════════════════════════════════════════════════════════

func _attack_ground_slam_combo() -> void:
	if health_component.is_dead:
		return

	var original_color: Color = animated_sprite.modulate
	var original_scale: Vector2 = animated_sprite.scale

	for slam_index in slam_count:
		if health_component.is_dead:
			return

		await _telegraph(Color(1.0, 0.55, 0.12), original_scale * 1.18, slam_windup_time)

		if health_component.is_dead:
			return

		_do_slam_visual(original_scale)

		var ring_speed: float = slam_base_speed + float(slam_index) * slam_speed_step
		var ring_offset: float = float(slam_index) * 0.18

		_spawn_projectile_ring(
			slam_ring_size,
			ring_speed,
			slam_damage,
			ring_offset
		)

		if slam_cross_enabled:
			_spawn_slam_cross(slam_cross_speed, slam_cross_damage)

		if slam_index < slam_count - 1:
			await get_tree().create_timer(slam_delay).timeout

	animated_sprite.modulate = original_color
	animated_sprite.scale = original_scale

	_enter_cooldown()


func _do_slam_visual(original_scale: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(animated_sprite, "scale", original_scale * 1.35, 0.06)
	tween.tween_property(animated_sprite, "scale", original_scale, 0.16)


func _spawn_slam_cross(speed: float, damage: int) -> void:
	var dirs: Array[Vector2] = [
		Vector2.RIGHT,
		Vector2.LEFT,
		Vector2.UP,
		Vector2.DOWN
	]

	for dir in dirs:
		_fire_projectile(dir, speed, damage, 16.0)


# ══════════════════════════════════════════════════════════════════════
# ATTACK 3: BOULDER TOSS
# ══════════════════════════════════════════════════════════════════════

func _attack_boulder_toss() -> void:
	if health_component.is_dead:
		return

	var original_scale: Vector2 = animated_sprite.scale

	await _telegraph(Color(0.9, 0.35, 0.15), original_scale * 1.25, boulder_windup_time)

	if health_component.is_dead:
		return

	for i in boulder_count:
		if health_component.is_dead:
			return

		if not is_instance_valid(target):
			break

		var base_dir: Vector2 = global_position.direction_to(target.global_position)
		var spread: float = 0.0

		if boulder_count > 1:
			spread = (float(i) / float(boulder_count - 1) - 0.5) * deg_to_rad(24.0)

		var dir: Vector2 = base_dir.rotated(spread)

		_fire_projectile(dir, boulder_speed, boulder_damage, 18.0)
		_spawn_boulder_fragments(dir)

		if i < boulder_count - 1:
			await get_tree().create_timer(boulder_delay).timeout

	animated_sprite.scale = original_scale
	_enter_cooldown()


func _spawn_boulder_fragments(forward_dir: Vector2) -> void:
	for i in boulder_fragment_count:
		var spread: float = (float(i) / float(maxi(1, boulder_fragment_count - 1)) - 0.5) * deg_to_rad(90.0)
		var dir: Vector2 = forward_dir.rotated(spread)

		_fire_projectile(dir, boulder_fragment_speed, boulder_fragment_damage, 12.0)


# ══════════════════════════════════════════════════════════════════════
# ATTACK 4: ENRAGE ROAR
# ══════════════════════════════════════════════════════════════════════

func _attack_enrage_roar() -> void:
	if health_component.is_dead:
		return

	var original_scale: Vector2 = animated_sprite.scale

	await _telegraph(Color(1.0, 0.08, 0.04), original_scale * 1.35, roar_windup_time)

	if health_component.is_dead:
		return

	_spawn_projectile_ring(roar_projectile_count, roar_projectile_speed, roar_damage, randf() * 0.2)

	_apply_temporary_enrage()

	animated_sprite.scale = original_scale

	_enter_cooldown()


func _apply_temporary_enrage() -> void:
	if is_enraged:
		return

	is_enraged = true
	move_speed = base_move_speed * roar_self_speed_mult

	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", Color(1.25, 0.55, 0.45), 0.12)
	tween.tween_interval(roar_buff_duration)
	tween.tween_callback(_clear_temporary_enrage)


func _clear_temporary_enrage() -> void:
	is_enraged = false
	move_speed = base_move_speed

	if is_instance_valid(animated_sprite):
		animated_sprite.modulate = Color.WHITE


# ══════════════════════════════════════════════════════════════════════
# SHARED ATTACK HELPERS
# ══════════════════════════════════════════════════════════════════════

func _telegraph(color: Color, target_scale: Vector2, duration: float) -> void:
	if animated_sprite == null:
		await get_tree().create_timer(duration).timeout
		return

	var original_color: Color = animated_sprite.modulate
	var original_scale: Vector2 = animated_sprite.scale

	var tween := create_tween().set_parallel(true)
	tween.tween_property(animated_sprite, "modulate", color, duration * 0.5)
	tween.tween_property(animated_sprite, "scale", target_scale, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)

	await get_tree().create_timer(duration).timeout

	if is_instance_valid(animated_sprite):
		animated_sprite.modulate = original_color
		animated_sprite.scale = original_scale


func _enter_cooldown() -> void:
	if health_component.is_dead:
		return

	state = State.COOLDOWN
	attack_timer = attack_cooldown


func _spawn_impact_ring(count: int, speed: float, damage: int) -> void:
	_spawn_projectile_ring(count, speed, damage, randf() * TAU)


func _spawn_projectile_ring(count: int, speed: float, damage: int, offset: float = 0.0) -> void:
	if count <= 0:
		return

	for i in count:
		var angle: float = (float(i) / float(count)) * TAU + offset
		var dir := Vector2(cos(angle), sin(angle))

		_fire_projectile(dir, speed, damage, 16.0)


func _fire_projectile(dir: Vector2, speed: float, damage: int, spawn_offset: float = 16.0) -> void:
	if boss_projectile_scene == null:
		return

	var proj := boss_projectile_scene.instantiate() as Node2D

	if proj == null:
		return

	var safe_dir: Vector2 = dir.normalized()

	if safe_dir == Vector2.ZERO:
		safe_dir = Vector2.DOWN

	proj.global_position = global_position + safe_dir * spawn_offset
	proj.add_to_group("enemy_projectiles")
	proj.add_to_group("wave_cleanup")

	get_tree().current_scene.add_child(proj)

	if proj.has_method("setup"):
		proj.setup(safe_dir, damage)

	if "speed" in proj:
		proj.speed = speed


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
			randf_range(-28.0, 28.0),
			randf_range(-28.0, 28.0)
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
		push_warning("BruteBoss: loot_item_scene root is not a PowerUpPickup.")
		return

	powerup_pickup.powerup_data = powerup
	powerup_pickup.is_wave_temporary = is_wave_temporary_drop

	var angle: float = (float(index) / float(maxi(1, total_count))) * TAU
	var offset := Vector2(cos(angle), sin(angle)) * 28.0

	powerup_pickup.global_position = global_position + offset

	get_tree().current_scene.add_child(powerup_pickup)


# ══════════════════════════════════════════════════════════════════════
# DEATH
# ══════════════════════════════════════════════════════════════════════

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
	play_death_animation()

	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("death"):
		await animated_sprite.animation_finished

	queue_free()


# ══════════════════════════════════════════════════════════════════════
# ANIMATION
# ══════════════════════════════════════════════════════════════════════

func play_walk_animation(direction: Vector2) -> void:
	if animated_sprite.sprite_frames == null:
		return

	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			AnimationHelper.play_if_exists(animated_sprite, "walk_right")
		else:
			AnimationHelper.play_if_exists(animated_sprite, "walk_left")
	else:
		if direction.y > 0:
			AnimationHelper.play_if_exists(animated_sprite, "walk_down")
		else:
			AnimationHelper.play_if_exists(animated_sprite, "walk_up")


func play_idle_animation() -> void:
	AnimationHelper.play_if_exists(animated_sprite, "idle")


func play_death_animation() -> void:
	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
	else:
		hide()
