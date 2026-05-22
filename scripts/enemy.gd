extends CharacterBody2D

@export var move_speed: float = 75.0
@export var stop_distance: float = 28.0
@export var attack_distance: float = 22.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var collision: CollisionShape2D = $CollisionShape2D

@export var loot_table: PowerUpTable
@export var loot_item_scene: PackedScene
@export var gold_pickup_scene: PackedScene
@export var min_gold_drop := 1
@export var max_gold_drop := 5


## Base chance (0.0 to 1.0) that this enemy drops a powerup at all.
@export var drop_chance: float = 0.015  # 15% chance

var target: Node2D = null
var last_direction: Vector2 = Vector2.DOWN
var gold_multiplier: float = 1.0

func _ready() -> void:
	health_component.died.connect(_on_died)
	# Automatically find and target the player when spawned.
	_acquire_target()

func _physics_process(_delta: float) -> void:
	if health_component.is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_instance_valid(target):
		follow_target()
	else:
		# If our target died or was freed, try to find them again.
		_acquire_target()
		velocity = Vector2.ZERO
		play_idle_animation()

	move_and_slide()

## Called by WaveManager after spawning to directly assign a target.
func set_target(new_target: Node2D) -> void:
	target = new_target

## Called by WaveManager to scale gold drops based on the current wave.
func set_gold_multiplier(multiplier: float) -> void:
	gold_multiplier = multiplier

## Fallback: searches the scene tree for any node in the "player" group.
func _acquire_target() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target = players[0] as Node2D

func drop_gold() -> void:
	if gold_pickup_scene == null:
		push_warning("No gold_pickup_scene assigned on enemy.")
		return

	var gold_pickup := gold_pickup_scene.instantiate() as GoldPickup
	if gold_pickup == null:
		push_warning("gold_pickup_scene is not a GoldPickup.")
		return

	# Apply the gold multiplier so later waves yield more gold.
	gold_pickup.gold_amount = int(randi_range(min_gold_drop, max_gold_drop) * gold_multiplier)
	gold_pickup.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-12, 12))
	get_tree().current_scene.add_child(gold_pickup)

func drop_loot() -> void:
	if loot_table == null:
		return
	if loot_item_scene == null:
		return

	# Roll the dice — most enemies won't drop anything.
	# This makes the drops that DO happen feel special and exciting.
	if randf() > drop_chance:
		return

	# If we passed the check, roll a single powerup from the loot table.
	var drop := loot_table.roll_drop()
	if drop == null:
		return

	var powerup_pickup := loot_item_scene.instantiate() as PowerUpPickup
	if powerup_pickup == null:
		push_warning("loot_item_scene root is not a PowerUpPickup.")
		return

	# Assign the powerup data to the pickup.
	powerup_pickup.powerup_data = drop
	
	# CRITICAL: Mark this as a wave-temporary powerup.
	# This tells the PowerUpPickup that when the player collects it,
	# it should apply immediately as a temporary buff that expires
	# when the wave ends, rather than adding it to the inventory.
	powerup_pickup.is_wave_temporary = true
	
	# Spawn the pickup at the enemy's death position.
	powerup_pickup.global_position = global_position
	get_tree().current_scene.add_child(powerup_pickup)


func follow_target() -> void:
	var direction: Vector2 = global_position.direction_to(target.global_position)
	var distance: float = global_position.distance_to(target.global_position)
	last_direction = direction

	if distance > stop_distance:
		velocity = direction * move_speed
		play_walk_animation(direction)
	else:
		velocity = Vector2.ZERO
		play_idle_animation()

func _on_died() -> void:
	target = null
	velocity = Vector2.ZERO

	collision.set_deferred("disabled", true)

	# Disable hurtbox so projectiles pass through the corpse.
	if has_node("Hurtbox"):
		$Hurtbox.set_deferred("monitoring", false)
		$Hurtbox.set_deferred("monitorable", false)

	drop_gold.call_deferred()
	drop_loot.call_deferred()
	play_death_animation()

	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("death"):
		await animated_sprite.animation_finished
	queue_free()

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
