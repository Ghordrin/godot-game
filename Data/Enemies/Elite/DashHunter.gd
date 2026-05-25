extends CharacterBody2D
class_name DashHunter

# ══════════════════════════════════════════════════════════════════════
# IDENTITY
# ══════════════════════════════════════════════════════════════════════

@export var move_speed: float = 112.0
@export var stop_distance: float = 92.0
@export var attack_range: float = 285.0

# ══════════════════════════════════════════════════════════════════════
# CHAIN DASH ATTACK
# ══════════════════════════════════════════════════════════════════════

@export var dash_chain_count: int = 3

@export var dash_windup_time: float = 0.22
@export var dash_relock_time: float = 0.16
@export var dash_speed: float = 560.0
@export var dash_distance: float = 300.0
@export var dash_damage: float = 12.0
@export var dash_cooldown: float = 1.35
@export var dash_hit_radius: float = 22.0
@export var dash_overshoot_player: float = 56.0

## Small delay after the final dash before it resumes chasing.
@export var recovery_time: float = 0.18

# ══════════════════════════════════════════════════════════════════════
# TELEGRAPH
# ══════════════════════════════════════════════════════════════════════

@export var telegraph_width: float = 16.0
@export var telegraph_color: Color = Color(1.0, 0.18, 0.08, 0.65)
@export var relock_telegraph_color: Color = Color(1.0, 0.45, 0.12, 0.62)

# ══════════════════════════════════════════════════════════════════════
# LOOT
# These are normally injected by WaveManager through set_powerup_drop_context().
# ══════════════════════════════════════════════════════════════════════

@export var loot_table: PowerUpTable
@export var loot_item_scene: PackedScene
@export var gold_pickup_scene: PackedScene
@export var min_gold_drop: int = 1
@export var max_gold_drop: int = 4

var powerup_drop_chance: float = 0.0
var force_powerup_drop: bool = false
var is_wave_temporary_drop: bool = true
var gold_multiplier: float = 1.0

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
	LOCKING_ON,
	DASHING,
	RECOVERING,
	DEAD
}

var state: State = State.CHASING
var target: Node2D = null
var last_direction: Vector2 = Vector2.DOWN

var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var dash_remaining_distance: float = 0.0
var chain_dashes_remaining: int = 0
var hit_targets_this_dash: Array[Node] = []

var telegraph_line: Line2D = null
var is_dying: bool = false
var _attack_sequence_id: int = 0


func _ready() -> void:
	add_to_group("enemies")

	if health_component != null and not health_component.died.is_connected(_on_died):
		health_component.died.connect(_on_died)

	_acquire_target()


func _physics_process(delta: float) -> void:
	if is_dying or health_component.is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not is_instance_valid(target):
		_acquire_target()

	match state:
		State.CHASING:
			_process_chasing(delta)

		State.LOCKING_ON:
			velocity = Vector2.ZERO
			play_idle_animation()

		State.DASHING:
			_process_dash(delta)

		State.RECOVERING:
			velocity = Vector2.ZERO
			play_idle_animation()

		State.DEAD:
			velocity = Vector2.ZERO

	move_and_slide()


# ══════════════════════════════════════════════════════════════════════
# MANAGER API
# ══════════════════════════════════════════════════════════════════════

func set_target(new_target: Node2D) -> void:
	target = new_target


func set_gold_multiplier(multiplier: float) -> void:
	gold_multiplier = multiplier


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


func _process_chasing(delta: float) -> void:
	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		play_idle_animation()
		return

	dash_cooldown_timer -= delta

	var to_target: Vector2 = target.global_position - global_position
	var distance: float = to_target.length()
	var direction: Vector2 = to_target.normalized()

	if direction != Vector2.ZERO:
		last_direction = direction

	if dash_cooldown_timer <= 0.0 and distance <= attack_range:
		_start_dash_chain()
		return

	if distance > stop_distance:
		velocity = direction * move_speed
		play_walk_animation(direction)
	else:
		velocity = Vector2.ZERO
		play_idle_animation()


# ══════════════════════════════════════════════════════════════════════
# CHAIN DASH ATTACK
# ══════════════════════════════════════════════════════════════════════

func _start_dash_chain() -> void:
	if not is_instance_valid(target):
		return

	_attack_sequence_id += 1
	chain_dashes_remaining = max(1, dash_chain_count)
	hit_targets_this_dash.clear()

	_lock_on_then_dash(_attack_sequence_id, dash_windup_time, telegraph_color)


func _lock_on_then_dash(sequence_id: int, lock_time: float, color: Color) -> void:
	if is_dying or health_component.is_dead:
		return

	if sequence_id != _attack_sequence_id:
		return

	if not is_instance_valid(target):
		_end_dash_chain()
		return

	state = State.LOCKING_ON
	velocity = Vector2.ZERO
	hit_targets_this_dash.clear()

	var target_pos: Vector2 = target.global_position
	dash_direction = global_position.direction_to(target_pos)

	if dash_direction == Vector2.ZERO:
		dash_direction = last_direction

	last_direction = dash_direction

	var desired_distance: float = global_position.distance_to(target_pos) + dash_overshoot_player
	dash_remaining_distance = minf(dash_distance, desired_distance)

	_spawn_dash_telegraph(dash_direction, dash_remaining_distance, color)
	_play_windup_flash(lock_time)

	await get_tree().create_timer(lock_time).timeout

	if is_dying or health_component.is_dead:
		_clear_telegraph()
		return

	if sequence_id != _attack_sequence_id:
		_clear_telegraph()
		return

	_clear_telegraph()

	state = State.DASHING


func _process_dash(delta: float) -> void:
	if dash_remaining_distance <= 0.0:
		_finish_single_dash()
		return

	var step: float = dash_speed * delta
	step = minf(step, dash_remaining_distance)

	global_position += dash_direction * step
	dash_remaining_distance -= step

	velocity = Vector2.ZERO

	_check_dash_hits()

	if dash_remaining_distance <= 0.0:
		_finish_single_dash()


func _finish_single_dash() -> void:
	chain_dashes_remaining -= 1

	if chain_dashes_remaining > 0:
		_lock_on_then_dash(_attack_sequence_id, dash_relock_time, relock_telegraph_color)
	else:
		_end_dash_chain()


func _end_dash_chain() -> void:
	state = State.RECOVERING
	velocity = Vector2.ZERO
	dash_cooldown_timer = dash_cooldown

	var sequence_id := _attack_sequence_id

	await get_tree().create_timer(recovery_time).timeout

	if is_dying or health_component.is_dead:
		return

	if sequence_id != _attack_sequence_id:
		return

	state = State.CHASING


func _check_dash_hits() -> void:
	for player in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(player):
			continue

		if player in hit_targets_this_dash:
			continue

		if not player is Node2D:
			continue

		var player_2d := player as Node2D
		var distance: float = global_position.distance_to(player_2d.global_position)

		if distance > dash_hit_radius:
			continue

		var health := player.get_node_or_null("HealthComponent")

		if health != null and health.has_method("take_damage"):
			health.take_damage(dash_damage, "physical")

		DamageNumberSpawner.spawn(
			player_2d.global_position,
			dash_damage,
			DamageVisuals.get_display_name("physical"),
			DamageVisuals.get_color("physical"),
			0,
			false
		)

		hit_targets_this_dash.append(player)


# ══════════════════════════════════════════════════════════════════════
# TELEGRAPH / VISUALS
# ══════════════════════════════════════════════════════════════════════

func _spawn_dash_telegraph(direction: Vector2, distance: float, color: Color) -> void:
	_clear_telegraph()

	telegraph_line = Line2D.new()
	telegraph_line.z_index = 8
	telegraph_line.width = telegraph_width
	telegraph_line.default_color = color
	telegraph_line.add_to_group("hazards")
	telegraph_line.add_to_group("wave_cleanup")

	telegraph_line.add_point(Vector2.ZERO)
	telegraph_line.add_point(direction.normalized() * distance)

	add_child(telegraph_line)

	var tween := telegraph_line.create_tween().set_loops()
	tween.tween_property(telegraph_line, "modulate:a", 0.20, 0.055)
	tween.tween_property(telegraph_line, "modulate:a", 0.95, 0.055)


func _clear_telegraph() -> void:
	if is_instance_valid(telegraph_line):
		telegraph_line.queue_free()

	telegraph_line = null


func _play_windup_flash(duration: float) -> void:
	if animated_sprite == null:
		return

	var original_color: Color = animated_sprite.modulate
	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", Color(1.5, 0.35, 0.2), duration * 0.45)
	tween.tween_property(animated_sprite, "modulate", original_color, duration * 0.45)


# ══════════════════════════════════════════════════════════════════════
# LOOT
# ══════════════════════════════════════════════════════════════════════

func drop_gold() -> void:
	if gold_pickup_scene == null:
		return

	var gold_pickup := gold_pickup_scene.instantiate() as GoldPickup

	if gold_pickup == null:
		return

	gold_pickup.gold_amount = int(round(float(randi_range(min_gold_drop, max_gold_drop)) * gold_multiplier))
	gold_pickup.global_position = global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))

	get_tree().current_scene.add_child(gold_pickup)


func drop_loot() -> void:
	if loot_table == null:
		return

	if loot_item_scene == null:
		return

	if not force_powerup_drop and randf() > powerup_drop_chance:
		return

	var drop := loot_table.roll_drop()

	if drop == null:
		return

	var powerup_pickup := loot_item_scene.instantiate() as PowerUpPickup

	if powerup_pickup == null:
		push_warning("DashHunter: loot_item_scene root is not a PowerUpPickup.")
		return

	powerup_pickup.powerup_data = drop
	powerup_pickup.is_wave_temporary = is_wave_temporary_drop
	powerup_pickup.global_position = global_position

	get_tree().current_scene.add_child(powerup_pickup)


# ══════════════════════════════════════════════════════════════════════
# DEATH
# ══════════════════════════════════════════════════════════════════════

func _on_died() -> void:
	if is_dying:
		return

	is_dying = true
	state = State.DEAD
	_attack_sequence_id += 1

	target = null
	velocity = Vector2.ZERO
	_clear_telegraph()

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
