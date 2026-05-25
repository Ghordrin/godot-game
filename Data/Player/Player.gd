extends CharacterBody2D

@export var projectile_scene: PackedScene

# ── Dash ──────────────────────────────────────────────────────────────

## Speed of the dash in pixels/s. Fast enough to cross a tight gap.
@export var dash_speed: float = 480.0

## How long the dash lasts in seconds. Short = snappy, Long = floaty.
@export var dash_duration: float = 0.30

## Seconds before dash can be used again.
@export var dash_cooldown_time: float = 1.5

# ── Homing Autocast ───────────────────────────────────────────────────

## If true, Homing projectile type fires automatically when off cooldown.
@export var homing_autocast_enabled: bool = true

## Homing only autocasts if an enemy is within this range.
@export var homing_autocast_range: float = 780.0

## If false, Homing fully replaces manual casting.
@export var allow_manual_cast_with_homing: bool = true

# ── Boulder Targeting ─────────────────────────────────────────────────

## Maximum distance from the player where Boulder can be dropped.
@export var boulder_cast_range: float = 420.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component = $HealthComponent
@onready var stats: StatsComponent = $StatsComponent

var last_move_direction: Vector2 = Vector2.DOWN
var facing_direction: Vector2 = Vector2.DOWN
var can_move: bool = true
var attack_cooldown: float = 0.0

## Dash state
var _dash_active: bool = false
var _dash_elapsed: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _dash_cooldown: float = 0.0

## How often ghost copies spawn during the dash (seconds between each)
const GHOST_INTERVAL: float = 0.045
var _ghost_timer: float = 0.0


func _ready() -> void:
	health_component.died.connect(_on_died)

	## Spawn the dash cooldown indicator
	var indicator_script = load("res://Data/DashIndicator.gd")
	if indicator_script:
		var indicator = indicator_script.new()
		indicator.player = self
		get_tree().current_scene.add_child.call_deferred(indicator)


func _physics_process(delta: float) -> void:
	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	if not can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	## ── Dash is active — override all normal movement ─────────────────
	if _dash_active:
		_dash_elapsed += delta
		_ghost_timer -= delta
		velocity = _dash_direction * dash_speed

		## Spawn ghost trail
		if _ghost_timer <= 0.0:
			_ghost_timer = GHOST_INTERVAL
			_spawn_ghost()

		if _dash_elapsed >= dash_duration:
			_end_dash()

		move_and_slide()
		return

	## ── Normal frame ──────────────────────────────────────────────────
	if _dash_cooldown > 0.0:
		_dash_cooldown -= delta

	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	## Dash input — only when cooldown is ready and not already dashing
	if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0.0:
		_start_dash(input_vector)
		return

	_handle_attack_input()

	if Input.is_action_just_pressed("debug_dmg"):
		health_component.take_damage(10)

	if input_vector != Vector2.ZERO:
		velocity = input_vector.normalized() * stats.move_speed
		last_move_direction = input_vector
		facing_direction = input_vector
		play_walk_animation(input_vector)
	else:
		velocity = Vector2.ZERO
		play_idle_animation()

	move_and_slide()


func _handle_attack_input() -> void:
	if attack_cooldown > 0.0:
		return

	if _has_homing_projectile() and homing_autocast_enabled:
		var target := _find_homing_autocast_target()

		if target != null:
			attack_towards_target(target)
			attack_cooldown = 1.0 / max(stats.attack_speed, 0.1)
			return

	if Input.is_action_just_pressed("cast_projectile"):
		if _has_homing_projectile() and not allow_manual_cast_with_homing:
			return

		attack_towards_mouse()
		attack_cooldown = 1.0 / max(stats.attack_speed, 0.1)


func _has_homing_projectile() -> bool:
	var proj_powerups: Array[PowerUpData] = PlayerInventory.get_active_projectile_powerups()

	for powerup in proj_powerups:
		if powerup == null:
			continue

		if powerup.projectile_type == PowerUpData.ProjectileType.HOMING:
			return true

	return false


func _has_boulder_projectile() -> bool:
	var proj_powerups: Array[PowerUpData] = PlayerInventory.get_active_projectile_powerups()

	for powerup in proj_powerups:
		if powerup == null:
			continue

		if powerup.projectile_type == PowerUpData.ProjectileType.BOULDER:
			return true

	return false


func _find_homing_autocast_target() -> Node2D:
	var best_target: Node2D = null
	var best_score: float = INF

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		if not enemy is Node2D:
			continue

		var enemy_2d := enemy as Node2D
		var distance: float = global_position.distance_to(enemy_2d.global_position)

		if distance > homing_autocast_range:
			continue

		var score: float = distance

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


# ── Dash Functions ─────────────────────────────────────────────────────

func _start_dash(input_vector: Vector2) -> void:
	_dash_active = true
	_dash_elapsed = 0.0
	_ghost_timer = 0.0

	if input_vector.length() > 0.1:
		_dash_direction = input_vector.normalized()
	else:
		_dash_direction = get_mouse_attack_direction()

	health_component.is_invincible = true
	animated_sprite.modulate = Color(1.5, 1.5, 2.0)


func _end_dash() -> void:
	_dash_active = false
	_dash_cooldown = dash_cooldown_time
	health_component.is_invincible = false
	animated_sprite.modulate = Color.WHITE


func _spawn_ghost() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return

	var ghost := Node2D.new()
	ghost.global_position = global_position
	ghost.z_index = -1
	ghost.add_to_group("wave_cleanup")
	get_tree().current_scene.add_child(ghost)

	var ghost_sprite := animated_sprite.duplicate() as AnimatedSprite2D
	ghost_sprite.stop()
	ghost_sprite.modulate = Color(_dash_direction.x * 0.1 + 0.4, 0.55, 1.0, 0.55)
	ghost.add_child(ghost_sprite)

	var t := ghost.create_tween()
	t.tween_property(ghost, "modulate:a", 0.0, dash_duration * 1.2)
	t.tween_callback(ghost.queue_free)


# ── Combat ────────────────────────────────────────────────────────────

func attack_towards_mouse() -> void:
	var mouse_direction := get_mouse_attack_direction()
	facing_direction = screen_direction_to_cardinal(mouse_direction)
	play_cast_animation()

	if _has_boulder_projectile():
		cast_boulder_at_mouse()
	else:
		cast_projectile(mouse_direction)


func attack_towards_target(target_node: Node2D) -> void:
	if target_node == null or not is_instance_valid(target_node):
		return

	var target_direction := global_position.direction_to(target_node.global_position)

	if target_direction == Vector2.ZERO:
		target_direction = facing_direction

	facing_direction = screen_direction_to_cardinal(target_direction)
	play_cast_animation()

	if _has_boulder_projectile():
		cast_boulder_at_position(target_node.global_position)
	else:
		cast_projectile(target_direction)


func get_mouse_attack_direction() -> Vector2:
	var mouse_direction: Vector2 = global_position.direction_to(get_global_mouse_position())

	if mouse_direction == Vector2.ZERO:
		return facing_direction

	return mouse_direction.normalized()


func get_clamped_boulder_target(raw_target: Vector2) -> Vector2:
	var offset := raw_target - global_position

	if offset.length() <= boulder_cast_range:
		return raw_target

	return global_position + offset.normalized() * boulder_cast_range


func screen_direction_to_cardinal(direction: Vector2) -> Vector2:
	if abs(direction.x) > abs(direction.y):
		return Vector2.RIGHT if direction.x > 0 else Vector2.LEFT
	else:
		return Vector2.DOWN if direction.y > 0 else Vector2.UP


func cast_boulder_at_mouse() -> void:
	cast_boulder_at_position(get_global_mouse_position())


func cast_boulder_at_position(raw_target_position: Vector2) -> void:
	if projectile_scene == null:
		push_warning("No projectile scene assigned.")
		return

	var target_position := get_clamped_boulder_target(raw_target_position)
	var proj_powerups: Array[PowerUpData] = PlayerInventory.get_active_projectile_powerups()

	var projectile := projectile_scene.instantiate() as Projectile
	get_tree().current_scene.add_child(projectile)

	projectile.setup(Vector2.DOWN, stats.damage, stats.base_damage)

	if proj_powerups.size() >= 1:
		projectile.apply_projectile_type(proj_powerups[0].projectile_type, 1)

	if proj_powerups.size() >= 2:
		projectile.apply_secondary_type(proj_powerups[1].projectile_type, 1)

	projectile.setup_boulder_drop(target_position, 260.0)


func cast_projectile(shoot_direction: Vector2) -> void:
	if projectile_scene == null:
		push_warning("No projectile scene assigned.")
		return

	var count: int = max(1, stats.projectile_count)
	var spread_angle := deg_to_rad(12.0)
	var proj_powerups: Array[PowerUpData] = PlayerInventory.get_active_projectile_powerups()

	for i in count:
		var direction := shoot_direction.normalized()

		if direction == Vector2.ZERO:
			direction = facing_direction

		if count > 1:
			var offset := 0.0

			if count % 2 == 1:
				var middle := count / 2.0
				offset = float(i - middle) * spread_angle
			else:
				var middle := float(count - 1) / 2.0
				offset = (float(i) - middle) * spread_angle

			direction = direction.rotated(offset)

		var projectile := projectile_scene.instantiate() as Projectile
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = global_position
		projectile.setup(direction, stats.damage, stats.base_damage)

		if proj_powerups.size() >= 1:
			projectile.apply_projectile_type(proj_powerups[0].projectile_type, 1)

		if proj_powerups.size() >= 2:
			projectile.apply_secondary_type(proj_powerups[1].projectile_type, 1)


# ── Death ─────────────────────────────────────────────────────────────

func _on_died() -> void:
	can_move = false
	velocity = Vector2.ZERO
	print("Player died.")
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()


# ── Animations ────────────────────────────────────────────────────────

func play_cast_animation() -> void:
	play_directional_animation("attack", facing_direction)


func play_walk_animation(direction: Vector2) -> void:
	play_directional_animation("walk", direction)


func play_idle_animation() -> void:
	play_directional_animation("idle", facing_direction)


func play_directional_animation(prefix: String, direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			AnimationHelper.play_if_exists(animated_sprite, prefix + "_right")
		else:
			AnimationHelper.play_if_exists(animated_sprite, prefix + "_left")
	else:
		if direction.y > 0:
			AnimationHelper.play_if_exists(animated_sprite, prefix + "_down")
		else:
			AnimationHelper.play_if_exists(animated_sprite, prefix + "_right")
