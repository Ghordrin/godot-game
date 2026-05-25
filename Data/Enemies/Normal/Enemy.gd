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

var target: Node2D = null
var last_direction: Vector2 = Vector2.DOWN
var gold_multiplier: float = 1.0

var powerup_drop_chance: float = 0.0
var force_powerup_drop: bool = false
var is_wave_temporary_drop: bool = true

var _is_dying: bool = false
var _is_pooled: bool = false
var _base_move_speed: float = 75.0


func _ready() -> void:
	add_to_group("enemies")
	_base_move_speed = move_speed

	if health_component != null and not health_component.died.is_connected(_on_died):
		health_component.died.connect(_on_died)

	_acquire_target()


func _physics_process(_delta: float) -> void:
	if _is_pooled:
		return

	if _is_dying or health_component.is_dead:
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


func revive_from_pool(spawn_position: Vector2) -> void:
	_is_pooled = false
	_is_dying = false

	global_position = spawn_position
	velocity = Vector2.ZERO
	last_direction = Vector2.DOWN
	target = null

	show()
	set_process(true)
	set_physics_process(true)

	move_speed = _base_move_speed

	if collision != null:
		collision.set_deferred("disabled", false)

	if has_node("Hurtbox"):
		$Hurtbox.set_deferred("monitoring", true)
		$Hurtbox.set_deferred("monitorable", true)

	if health_component != null:
		health_component.revive()

	var status_component := get_node_or_null("StatusEffectComponent") as StatusEffectComponent

	if status_component != null:
		status_component.clear_all()

	if animated_sprite != null:
		animated_sprite.modulate = Color.WHITE
		play_idle_animation()


func prepare_for_pool() -> void:
	_is_pooled = true
	_is_dying = false

	target = null
	velocity = Vector2.ZERO

	hide()
	set_process(false)
	set_physics_process(false)

	if collision != null:
		collision.set_deferred("disabled", true)

	if has_node("Hurtbox"):
		$Hurtbox.set_deferred("monitoring", false)
		$Hurtbox.set_deferred("monitorable", false)

	var status_component := get_node_or_null("StatusEffectComponent") as StatusEffectComponent

	if status_component != null:
		status_component.clear_all()

	global_position = Vector2(-100000.0, -100000.0)


func _acquire_target() -> void:
	var players := get_tree().get_nodes_in_group("player")

	if not players.is_empty():
		target = players[0] as Node2D


func follow_target() -> void:
	if not is_instance_valid(target):
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


func drop_gold() -> void:
	var payload := _build_death_payload()
	_spawn_gold_from_payload(payload)


func drop_loot() -> void:
	var payload := _build_death_payload()
	_spawn_loot_from_payload(payload)


func _on_died() -> void:
	if _is_dying:
		return

	_is_dying = true
	target = null
	velocity = Vector2.ZERO

	set_physics_process(false)
	set_process(false)

	if collision != null:
		collision.set_deferred("disabled", true)

	if has_node("Hurtbox"):
		$Hurtbox.set_deferred("monitoring", false)
		$Hurtbox.set_deferred("monitorable", false)

	var status_component := get_node_or_null("StatusEffectComponent") as StatusEffectComponent

	if status_component != null:
		status_component.on_enemy_death()

	var payload := _build_death_payload()
	var death_queue := get_node_or_null("/root/DeathQueue")

	if death_queue != null and death_queue.has_method("enqueue_enemy_death"):
		death_queue.enqueue_enemy_death(payload)
	else:
		_spawn_gold_from_payload(payload)
		_spawn_loot_from_payload(payload)

	## For pooled swarm enemies, hide immediately.
	## A pooled death effect can be added later.
	hide()

	var enemy_manager := get_node_or_null("/root/EnemyManager")

	if enemy_manager != null and enemy_manager.has_method("recycle_enemy"):
		enemy_manager.recycle_enemy(self)
	else:
		queue_free()


func _build_death_payload() -> Dictionary:
	var gold_amount: int = 0

	if gold_pickup_scene != null:
		gold_amount = int(round(float(randi_range(min_gold_drop, max_gold_drop)) * gold_multiplier))

	return {
		"position": global_position,
		"gold_pickup_scene": gold_pickup_scene,
		"gold_amount": gold_amount,
		"loot_table": loot_table,
		"loot_item_scene": loot_item_scene,
		"powerup_drop_chance": powerup_drop_chance,
		"force_powerup_drop": force_powerup_drop,
		"is_wave_temporary_drop": is_wave_temporary_drop,
	}


func _spawn_gold_from_payload(payload: Dictionary) -> void:
	var scene: PackedScene = payload.get("gold_pickup_scene", null)

	if scene == null:
		return

	var gold_amount: int = int(payload.get("gold_amount", 0))

	if gold_amount <= 0:
		return

	var gold_pickup := scene.instantiate() as GoldPickup

	if gold_pickup == null:
		push_warning("gold_pickup_scene is not a GoldPickup.")
		return

	gold_pickup.gold_amount = gold_amount
	gold_pickup.global_position = payload.get("position", global_position) + Vector2(
		randf_range(-12.0, 12.0),
		randf_range(-12.0, 12.0)
	)

	get_tree().current_scene.add_child(gold_pickup)


func _spawn_loot_from_payload(payload: Dictionary) -> void:
	var table: PowerUpTable = payload.get("loot_table", null)
	var scene: PackedScene = payload.get("loot_item_scene", null)

	if table == null:
		return

	if scene == null:
		return

	var force_drop: bool = bool(payload.get("force_powerup_drop", false))
	var drop_chance: float = float(payload.get("powerup_drop_chance", 0.0))

	if not force_drop and randf() > drop_chance:
		return

	var drop := table.roll_drop()

	if drop == null:
		return

	var powerup_pickup := scene.instantiate() as PowerUpPickup

	if powerup_pickup == null:
		push_warning("loot_item_scene root is not a PowerUpPickup.")
		return

	powerup_pickup.powerup_data = drop
	powerup_pickup.is_wave_temporary = bool(payload.get("is_wave_temporary_drop", true))
	powerup_pickup.global_position = payload.get("position", global_position)

	get_tree().current_scene.add_child(powerup_pickup)


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
		hide()
		return

	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
	else:
		hide()
