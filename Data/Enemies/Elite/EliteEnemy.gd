extends CharacterBody2D

## Elite enemy — same as regular enemy but has an AffixComponent child.
## WaveManager spawns this and calls apply_affixes() on the AffixComponent.
## Alternatively, WaveManager can add an AffixComponent to any regular enemy.

@export var move_speed: float    = 70.0
@export var stop_distance: float = 28.0
@export var attack_distance: float = 22.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var collision: CollisionShape2D       = $CollisionShape2D
@onready var affix_component: AffixComponent   = $AffixComponent

@export var loot_table: PowerUpTable
@export var loot_item_scene: PackedScene
@export var gold_pickup_scene: PackedScene
@export var min_gold_drop := 3
@export var max_gold_drop := 8   # Elites drop more gold than regular enemies

var target: Node2D        = null
var last_direction: Vector2 = Vector2.DOWN
var gold_multiplier: float  = 1.0


func _ready() -> void:
	health_component.died.connect(_on_died)
	_acquire_target()
	add_to_group("enemies")


func _physics_process(_delta: float) -> void:
	if health_component.is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_instance_valid(target):
		follow_target()
	else:
		_acquire_target()
		velocity = Vector2.ZERO
		play_idle_animation()

	move_and_slide()


func set_target(new_target: Node2D) -> void:
	target = new_target


func set_gold_multiplier(multiplier: float) -> void:
	gold_multiplier = multiplier


func _acquire_target() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target = players[0] as Node2D


func follow_target() -> void:
	var direction: Vector2 = global_position.direction_to(target.global_position)
	var distance: float    = global_position.distance_to(target.global_position)
	last_direction = direction

	if distance > stop_distance:
		velocity = direction * move_speed
		play_walk_animation(direction)
	else:
		velocity = Vector2.ZERO
		play_idle_animation()


func drop_gold() -> void:
	if gold_pickup_scene == null:
		return
	var gold_pickup := gold_pickup_scene.instantiate() as GoldPickup
	if gold_pickup == null:
		return
	gold_pickup.gold_amount = int(randi_range(min_gold_drop, max_gold_drop) * gold_multiplier)
	gold_pickup.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-12, 12))
	get_tree().current_scene.add_child(gold_pickup)


func drop_loot() -> void:
	if loot_table == null or loot_item_scene == null:
		return
	# Elites always drop — no random roll
	var drop := loot_table.roll_drop()
	if drop == null:
		return
	var powerup_pickup := loot_item_scene.instantiate() as PowerUpPickup
	if powerup_pickup == null:
		return
	powerup_pickup.powerup_data  = drop
	powerup_pickup.is_wave_temporary = true
	powerup_pickup.global_position   = global_position
	get_tree().current_scene.add_child(powerup_pickup)


func _on_died() -> void:
	target   = null
	velocity = Vector2.ZERO

	collision.set_deferred("disabled", true)

	if has_node("Hurtbox"):
		$Hurtbox.set_deferred("monitoring",    false)
		$Hurtbox.set_deferred("monitorable",   false)

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
		AnimationHelper.play_if_exists(animated_sprite, "walk_right" if direction.x > 0 else "walk_left")
	else:
		AnimationHelper.play_if_exists(animated_sprite, "walk_down" if direction.y > 0 else "walk_up")


func play_idle_animation() -> void:
	AnimationHelper.play_if_exists(animated_sprite, "idle")


func play_death_animation() -> void:
	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
	else:
		hide()
