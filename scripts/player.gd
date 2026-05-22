extends CharacterBody2D

@export var projectile_scene: PackedScene

# ── Dash ──────────────────────────────────────────────────────────────

## Speed of the dash in pixels/s. Fast enough to cross a tight gap.
@export var dash_speed: float = 480.0

## How long the dash lasts in seconds. Short = snappy, Long = floaty.
@export var dash_duration: float = 0.30

## Seconds before dash can be used again.
@export var dash_cooldown_time: float = 1.5

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component                  = $HealthComponent
@onready var stats: StatsComponent             = $StatsComponent

var last_move_direction: Vector2 = Vector2.DOWN
var facing_direction: Vector2    = Vector2.DOWN
var can_move: bool    = true
var attack_cooldown: float = 0.0

## Dash state
var _dash_active: bool    = false
var _dash_elapsed: float  = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _dash_cooldown: float = 0.0   ## Remaining cooldown — 0 means ready

## How often ghost copies spawn during the dash (seconds between each)
const GHOST_INTERVAL: float = 0.045
var _ghost_timer: float = 0.0


func _ready() -> void:
	health_component.died.connect(_on_died)

	## Spawn the dash cooldown indicator
	var indicator_script = load("res://scripts/DashIndicator.gd")
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
		_ghost_timer   -= delta
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

	## Attack
	if Input.is_action_just_pressed("cast_projectile") and attack_cooldown <= 0.0:
		attack_towards_mouse()
		attack_cooldown = 1.0 / max(stats.attack_speed, 0.1)

	if Input.is_action_just_pressed("debug_dmg"):
		health_component.take_damage(10)

	if input_vector != Vector2.ZERO:
		velocity = input_vector.normalized() * stats.move_speed
		last_move_direction = input_vector
		facing_direction    = input_vector
		play_walk_animation(input_vector)
	else:
		velocity = Vector2.ZERO
		play_idle_animation()

	move_and_slide()


## ── Dash Functions ─────────────────────────────────────────────────────

func _start_dash(input_vector: Vector2) -> void:
	_dash_active   = true
	_dash_elapsed  = 0.0
	_ghost_timer   = 0.0

	## Dash toward movement input, or toward mouse if standing still
	if input_vector.length() > 0.1:
		_dash_direction = input_vector.normalized()
	else:
		_dash_direction = get_mouse_attack_direction()

	## iFrames — HealthComponent ignores all damage while this is true
	health_component.is_invincible = true

	## Brief sprite flash to show the dash started
	animated_sprite.modulate = Color(1.5, 1.5, 2.0)


func _end_dash() -> void:
	_dash_active   = false
	_dash_cooldown = dash_cooldown_time
	health_component.is_invincible = false
	animated_sprite.modulate = Color.WHITE


func _spawn_ghost() -> void:
	## Creates a faded duplicate of the current sprite frame at the player's position.
	## Fades out quickly to leave a motion trail.
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return

	var ghost := Node2D.new()
	ghost.global_position = global_position
	ghost.z_index = -1
	get_tree().current_scene.add_child(ghost)

	## Duplicate the sprite so it keeps the current frame frozen
	var ghost_sprite := animated_sprite.duplicate() as AnimatedSprite2D
	ghost_sprite.stop()
	ghost_sprite.modulate = Color(_dash_direction.x * 0.1 + 0.4, 0.55, 1.0, 0.55)
	ghost.add_child(ghost_sprite)

	var t := ghost.create_tween()
	t.tween_property(ghost, "modulate:a", 0.0, dash_duration * 1.2)
	t.tween_callback(ghost.queue_free)


## ── Combat ────────────────────────────────────────────────────────────

func attack_towards_mouse() -> void:
	var mouse_direction := get_mouse_attack_direction()
	facing_direction = screen_direction_to_cardinal(mouse_direction)
	play_cast_animation()
	cast_projectile(mouse_direction)


func get_mouse_attack_direction() -> Vector2:
	var mouse_direction: Vector2 = global_position.direction_to(get_global_mouse_position())
	if mouse_direction == Vector2.ZERO:
		return facing_direction
	return mouse_direction.normalized()


func screen_direction_to_cardinal(direction: Vector2) -> Vector2:
	if abs(direction.x) > abs(direction.y):
		return Vector2.RIGHT if direction.x > 0 else Vector2.LEFT
	else:
		return Vector2.DOWN if direction.y > 0 else Vector2.UP


func cast_projectile(shoot_direction: Vector2) -> void:
	if projectile_scene == null:
		push_warning("No projectile scene assigned.")
		return

	var count: int     = max(1, stats.projectile_count)
	var spread_angle   := deg_to_rad(12.0)
	var proj_powerups  := PlayerInventory.get_active_projectile_powerups()

	for i in count:
		var direction := shoot_direction.normalized()

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
			var rank := PlayerInventory.get_powerup_rank(proj_powerups[0])
			projectile.apply_projectile_type(proj_powerups[0].projectile_type, rank)
		else:
			projectile.pierces_enemies = stats.projectile_pierce > 0

		if proj_powerups.size() >= 2:
			var rank := PlayerInventory.get_powerup_rank(proj_powerups[1])
			projectile.apply_secondary_type(proj_powerups[1].projectile_type, rank)


## ── Death ─────────────────────────────────────────────────────────────

func _on_died() -> void:
	can_move = false
	velocity = Vector2.ZERO
	print("Player died.")
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()


## ── Animations ────────────────────────────────────────────────────────

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
