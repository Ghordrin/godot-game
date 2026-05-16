extends CharacterBody2D

@export var projectile_scene: PackedScene

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component = $HealthComponent
@onready var stats: StatsComponent = $StatsComponent

var applied_powerups: Array[PowerUpData] = []  ## Track which powerups are active
var base_stats: Dictionary = {}                ## Store base stat values for resetting

var last_move_direction: Vector2 = Vector2.DOWN
var facing_direction: Vector2 = Vector2.DOWN
var can_move: bool = true


func _ready() -> void:
	health_component.died.connect(_on_died)
	
	# Save the base stats so we can reset to them later when equipment changes.
	# These are the original values from the StatsComponent's @export variables.
	base_stats = {
		"damage": stats.damage,
		"move_speed": stats.move_speed,
		"attack_speed": stats.attack_speed,
		"projectile_speed": stats.projectile_speed,
		"pickup_range": stats.pickup_range,
		"gold_multiplier": stats.gold_multiplier,
		"luck": stats.luck,
		"crit_chance": stats.crit_chance,
		"crit_multiplier": stats.crit_multiplier,
		"projectile_count": stats.projectile_count,
		"projectile_pierce": stats.projectile_pierce
	}
	
	# Listen for equipment changes so we can update applied powerups.
	PlayerInventory.equipment_changed.connect(_on_equipment_changed)
	
	# Apply any powerups that start equipped (from a previous run or load).
	_on_equipment_changed()


func _physics_process(_delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input_vector := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	if Input.is_action_just_pressed("cast_projectile"):
		attack_towards_mouse()

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
		if direction.x > 0:
			return Vector2.RIGHT
		else:
			return Vector2.LEFT
	else:
		if direction.y > 0:
			return Vector2.DOWN
		else:
			return Vector2.UP


func cast_projectile(shoot_direction: Vector2) -> void:
	if projectile_scene == null:
		push_warning("No projectile scene assigned.")
		return

	var count: int = max(1, stats.projectile_count)
	var spread_angle := deg_to_rad(12.0)

	for i in count:
		var direction := shoot_direction.normalized()

		if count > 1:
			var offset := 0.0

			if count % 2 == 1:
				var middle := count / 2
				offset = float(i - middle) * spread_angle
			else:
				var middle := float(count - 1) / 2.0
				offset = (float(i) - middle) * spread_angle

			direction = direction.rotated(offset)

		var projectile := projectile_scene.instantiate() as Projectile
		get_tree().current_scene.add_child(projectile)

		projectile.global_position = global_position
		projectile.setup(direction, stats.damage)
		projectile.pierces_enemies = stats.projectile_pierce > 0
		print("Projectile pierce: ", projectile.pierces_enemies)


func _on_died() -> void:
	can_move = false
	velocity = Vector2.ZERO
	print("Player died.")

	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()


func play_cast_animation() -> void:
	play_directional_animation("attack", facing_direction)


func play_walk_animation(direction: Vector2) -> void:
	play_directional_animation("walk", direction)


func play_idle_animation() -> void:
	play_directional_animation("idle", facing_direction)
	

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		print("Space pressed")
		var wm = get_tree().current_scene.get_node_or_null("WaveManager")
		print("WaveManager found: ", wm)
		if wm:
			print("WaveManager state: ", wm.get_wave_info())
			print("Enemy scenes: ", wm.enemy_scenes.size())
			print("Spawn points: ", wm.spawn_points.size())
			wm.start_next_wave()


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


func _play_if_exists(animation_name: String) -> void:
	if animated_sprite.sprite_frames == null:
		return

	if animated_sprite.sprite_frames.has_animation(animation_name):
		if animated_sprite.animation != animation_name:
			animated_sprite.play(animation_name)


## Called whenever the player's equipment changes. This happens when the
## player equips or unequips powerups in the shop. We clear all previously
## applied powerups and then apply only the ones currently equipped.
func _on_equipment_changed() -> void:
	# Get the currently equipped powerups from the inventory.
	var equipped := PlayerInventory.get_equipped_powerups()
	
	# Clear all previously applied powerups by resetting stats to their base values.
	# This prevents stacking issues where a powerup applied twice would double its effect.
	_clear_powerups()
	
	# Now apply each equipped powerup from the inventory.
	for powerup in equipped:
		if powerup != null:
			stats.apply_powerup(powerup)
			applied_powerups.append(powerup)


## Resets all stats to their base values, removing the effects of all
## previously applied powerups. This is called before re-applying the
## currently equipped powerups, ensuring we never have overlapping or
## stacked powerup effects.
func _clear_powerups() -> void:
	# Clear the list of applied powerups.
	applied_powerups.clear()
	
	# Reset each stat back to its base export value. These base values
	# were saved in _ready() and represent the player's stats with no
	# powerups applied. By resetting to these values, we undo all the
	# modifications that previous powerups made.
	if stats:
		stats.damage = base_stats["damage"]
		stats.move_speed = base_stats["move_speed"]
		stats.attack_speed = base_stats["attack_speed"]
		stats.projectile_speed = base_stats["projectile_speed"]
		stats.pickup_range = base_stats["pickup_range"]
		stats.gold_multiplier = base_stats["gold_multiplier"]
		stats.luck = base_stats["luck"]
		stats.crit_chance = base_stats["crit_chance"]
		stats.crit_multiplier = base_stats["crit_multiplier"]
		stats.projectile_count = base_stats["projectile_count"]
		stats.projectile_pierce = base_stats["projectile_pierce"]
	
	# Clear the StatsComponent's internal powerup tracking so it doesn't
	# remember old powerups when we apply new ones.
	stats.powerup_stacks.clear()
	stats.temporary_powerups.clear()
