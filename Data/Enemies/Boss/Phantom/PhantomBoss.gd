extends CharacterBody2D
class_name PhantomBoss

# ── Movement ──────────────────────────────────────────────────────────

## How fast the boss drifts between attacks. Low — it mostly teleports.
@export var move_speed: float = 40.0

## Distance at which the boss stops drifting toward the player.
@export var stop_distance: float = 100.0

# ── Visuals ───────────────────────────────────────────────────────────

## Name shown on the boss health bar UI.
@export var boss_name: String = "The Phantom"

## Purple tint applied to the sprite to distinguish it from regular enemies.
@export var phantom_tint: Color = Color(0.6, 0.3, 0.9, 1.0)

# ── Teleport Settings ─────────────────────────────────────────────────

## Minimum distance from the player the boss can teleport to.
@export var teleport_min_dist: float = 120.0

## Maximum distance from the player the boss can teleport to.
@export var teleport_max_dist: float = 180.0

## How long the shadow warning marker shows before the boss appears.
## Reduced from 0.8 — boss arrives faster, less predictable.
@export var shadow_warn_time: float = 0.45

## How long the boss takes to fade back in after teleporting.
@export var materialize_time: float = 0.2

## How many attacks the boss fires before teleporting again.
## Higher = longer burst phases, less breathing room for the player.
@export var attacks_before_teleport: int = 2

# ── Attack: Aimed Salvo ───────────────────────────────────────────────

## Number of aimed shots per salvo burst.
@export var salvo_count: int = 6

## Seconds between each shot in a salvo.
@export var salvo_interval: float = 0.10

## Speed of aimed salvo projectiles.
@export var salvo_speed: float = 200.0

## Damage per aimed salvo projectile.
@export var salvo_damage: int = 12

# ── Attack: Spiral Barrage ────────────────────────────────────────────

## Total projectiles in one spiral barrage.
@export var spiral_count: int = 36

## How many full rotations the spiral makes.
@export var spiral_rotations: float = 3.5

## Seconds between each spiral projectile.
@export var spiral_fire_interval: float = 0.04

## Speed of spiral projectiles.
@export var spiral_speed: float = 110.0

## Damage per spiral projectile.
@export var spiral_damage: int = 8

# ── Attack: Cross Burst ───────────────────────────────────────────────

## Projectiles per arm of the cross pattern.
@export var cross_projectiles_per_arm: int = 4

## Base speed of the innermost cross projectile.
@export var cross_base_speed: float = 90.0

## Speed added per projectile outward along each arm.
@export var cross_speed_step: float = 40.0

## Seconds between the + and x phases of the cross burst.
@export var cross_delay: float = 0.35

## Damage per cross projectile.
@export var cross_damage: int = 10

# ── Attack: Fan Burst ─────────────────────────────────────────────────

## Projectiles in each fan spread.
@export var fan_count: int = 7

## Spread angle of the fan in degrees.
@export var fan_spread_deg: float = 75.0

## Speed of fan projectiles.
@export var fan_speed: float = 190.0

## Damage per fan projectile.
@export var fan_damage: int = 14

## How many fan bursts fire in sequence with a small delay.
@export var fan_burst_count: int = 3

## Seconds between each fan burst in a sequence.
@export var fan_burst_interval: float = 0.3

# ── General Attack Settings ───────────────────────────────────────────

## Projectile scene used for all boss attacks.
@export var boss_projectile_scene: PackedScene

## Seconds between attack sequences. Lower = more relentless.
@export var attack_cooldown: float = 0.8

# ── Loot ──────────────────────────────────────────────────────────────

@export var loot_table: PowerUpTable
@export var loot_item_scene: PackedScene
@export var gold_pickup_scene: PackedScene

## Minimum gold dropped per pile when the boss dies.
@export var min_gold_drop := 20

## Maximum gold dropped per pile when the boss dies.
@export var max_gold_drop := 40

## How many guaranteed powerup drops the boss gives on death.
@export var guaranteed_drops: int = 3

# ── Node Refs ─────────────────────────────────────────────────────────
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var collision: CollisionShape2D       = $CollisionShape2D

# ── Internal State ────────────────────────────────────────────────────
enum State { CHASING, TELEPORTING, MATERIALIZING, ATTACKING, POST_ATTACK }
enum Attack { SALVO, SPIRAL, CROSS, FAN }

var state: State      = State.CHASING
var target: Node2D    = null
var last_direction: Vector2 = Vector2.DOWN
var shadow_marker: Node2D   = null
var last_attack: int  = Attack.SALVO
var boss_bar: BossHealthBarUI = null
var _attacks_this_burst: int = 0


func _ready() -> void:
	health_component.died.connect(_on_died)
	animated_sprite.modulate = phantom_tint
	_acquire_target()
	add_to_group("enemies")
	boss_bar = BossHealthBarUI.new()
	boss_bar.setup(boss_name, health_component)
	get_tree().current_scene.add_child.call_deferred(boss_bar)
	_start_fight_loop()

func set_target(new_target: Node2D) -> void:
	target = new_target

func _acquire_target() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target = players[0] as Node2D

func _physics_process(_delta: float) -> void:
	if health_component.is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if not is_instance_valid(target):
		_acquire_target()
	match state:
		State.CHASING:
			if is_instance_valid(target):
				var direction := global_position.direction_to(target.global_position)
				var distance  := global_position.distance_to(target.global_position)
				last_direction = direction
				if distance > stop_distance:
					velocity = direction * move_speed
					play_walk_animation(direction)
				else:
					velocity = Vector2.ZERO
					play_idle_animation()
			else:
				velocity = Vector2.ZERO
				play_idle_animation()
		_:
			velocity = Vector2.ZERO
	move_and_slide()

func _start_fight_loop() -> void:
	await get_tree().create_timer(1.2).timeout
	_fight_loop()

func _fight_loop() -> void:
	while not health_component.is_dead:
		if not is_instance_valid(target):
			_acquire_target()
			await get_tree().create_timer(0.3).timeout
			continue

		if _attacks_this_burst == 0:
			await _teleport_near_player()
			if health_component.is_dead:
				return
			state = State.MATERIALIZING
			await get_tree().create_timer(materialize_time).timeout
			if health_component.is_dead:
				return

		state = State.ATTACKING
		var attack := _pick_attack()
		await _execute_attack(attack)
		if health_component.is_dead:
			return

		_attacks_this_burst += 1
		state = State.POST_ATTACK
		await get_tree().create_timer(attack_cooldown).timeout

		if _attacks_this_burst >= attacks_before_teleport:
			_attacks_this_burst = 0

func _teleport_near_player() -> void:
	state = State.TELEPORTING
	var angle       := randf() * TAU
	var dist        := randf_range(teleport_min_dist, teleport_max_dist)
	var destination := target.global_position + Vector2(cos(angle), sin(angle)) * dist
	_spawn_shadow_marker(destination)
	var fade_out := create_tween()
	fade_out.tween_property(animated_sprite, "modulate:a", 0.0, shadow_warn_time * 0.4)
	await get_tree().create_timer(shadow_warn_time).timeout
	if health_component.is_dead:
		_remove_shadow_marker()
		return
	global_position = destination
	_remove_shadow_marker()
	animated_sprite.modulate = Color(phantom_tint.r, phantom_tint.g, phantom_tint.b, 0.0)
	var fade_in := create_tween()
	fade_in.tween_property(animated_sprite, "modulate:a", 1.0, materialize_time * 0.8)

func _spawn_shadow_marker(pos: Vector2) -> void:
	shadow_marker = Node2D.new()
	shadow_marker.global_position = pos
	shadow_marker.z_index = -1
	get_tree().current_scene.add_child(shadow_marker)
	var sprite := Sprite2D.new()
	var img    := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var center := Vector2(16, 16)
	for x in 32:
		for y in 32:
			var d := Vector2(x, y).distance_to(center)
			if d < 14.0:
				var alpha := clampf(1.0 - (d / 14.0), 0.0, 1.0) * 0.6
				img.set_pixel(x, y, Color(0.3, 0.1, 0.5, alpha))
	sprite.texture = ImageTexture.create_from_image(img)
	shadow_marker.add_child(sprite)
	var pulse := shadow_marker.create_tween().set_loops()
	pulse.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.2)
	pulse.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.2)

func _remove_shadow_marker() -> void:
	if is_instance_valid(shadow_marker):
		shadow_marker.queue_free()
		shadow_marker = null

func _pick_attack() -> int:
	## Weighted pool — fan and salvo appear more for higher pace
	var pool := [
		Attack.SALVO, Attack.SALVO,
		Attack.FAN,   Attack.FAN,
		Attack.SPIRAL,
		Attack.CROSS,
	]
	pool.erase(last_attack)
	var chosen: int = pool.pick_random()
	last_attack = chosen
	return chosen

func _execute_attack(attack: int) -> void:
	match attack:
		Attack.SALVO:  await _attack_aimed_salvo()
		Attack.SPIRAL: await _attack_spiral_barrage()
		Attack.CROSS:  await _attack_cross_burst()
		Attack.FAN:    await _attack_fan_burst()

func _attack_aimed_salvo() -> void:
	for i in salvo_count:
		if health_component.is_dead or not is_instance_valid(target):
			return
		var dir := global_position.direction_to(target.global_position)
		_fire_projectile(dir, salvo_speed, salvo_damage)
		animated_sprite.modulate = Color.WHITE
		await get_tree().create_timer(0.04).timeout
		animated_sprite.modulate = phantom_tint
		if i < salvo_count - 1:
			await get_tree().create_timer(salvo_interval).timeout

func _attack_spiral_barrage() -> void:
	for i in spiral_count:
		if health_component.is_dead:
			return
		var angle := (float(i) / float(spiral_count)) * TAU * spiral_rotations
		_fire_projectile(Vector2(cos(angle), sin(angle)), spiral_speed, spiral_damage)
		if i % 4 == 0:
			animated_sprite.modulate = Color(0.8, 0.5, 1.0)
			await get_tree().create_timer(0.02).timeout
			animated_sprite.modulate = phantom_tint
		await get_tree().create_timer(spiral_fire_interval).timeout

func _attack_cross_burst() -> void:
	if health_component.is_dead:
		return
	_fire_burst_pattern([0.0, PI * 0.5, PI, PI * 1.5])
	animated_sprite.modulate = Color.WHITE
	await get_tree().create_timer(0.08).timeout
	animated_sprite.modulate = phantom_tint
	await get_tree().create_timer(cross_delay).timeout
	if health_component.is_dead:
		return
	_fire_burst_pattern([PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75])
	animated_sprite.modulate = Color.WHITE
	await get_tree().create_timer(0.08).timeout
	animated_sprite.modulate = phantom_tint

func _fire_burst_pattern(angles: Array) -> void:
	for angle in angles:
		var dir := Vector2(cos(angle), sin(angle))
		for j in cross_projectiles_per_arm:
			_fire_projectile(dir, cross_base_speed + j * cross_speed_step, cross_damage)

func _attack_fan_burst() -> void:
	for burst in fan_burst_count:
		if health_component.is_dead or not is_instance_valid(target):
			return
		var aim_dir  := global_position.direction_to(target.global_position)
		var half_deg := fan_spread_deg / 2.0
		var step_deg := fan_spread_deg / float(fan_count - 1)
		for i in fan_count:
			var offset_deg := -half_deg + step_deg * i
			_fire_projectile(aim_dir.rotated(deg_to_rad(offset_deg)), fan_speed, fan_damage)
		animated_sprite.modulate = Color(1.0, 0.7, 1.0)
		await get_tree().create_timer(0.06).timeout
		animated_sprite.modulate = phantom_tint
		if burst < fan_burst_count - 1:
			await get_tree().create_timer(fan_burst_interval).timeout

func _fire_projectile(dir: Vector2, spd: float, dmg: int) -> void:
	if boss_projectile_scene == null:
		return
	var proj := boss_projectile_scene.instantiate() as Node2D
	if proj == null:
		return
	proj.global_position = global_position + dir * 16.0
	get_tree().current_scene.add_child(proj)
	if proj.has_method("setup"):
		proj.setup(dir, dmg)
	if "speed" in proj:
		proj.speed = spd

func drop_gold() -> void:
	if gold_pickup_scene == null:
		return
	for i in randi_range(4, 6):
		var gold_pickup := gold_pickup_scene.instantiate() as GoldPickup
		if gold_pickup == null:
			continue
		gold_pickup.gold_amount = randi_range(min_gold_drop, max_gold_drop)
		gold_pickup.global_position = global_position + Vector2(randf_range(-28, 28), randf_range(-28, 28))
		get_tree().current_scene.add_child(gold_pickup)

func drop_loot() -> void:
	if loot_table == null or loot_item_scene == null:
		return
	var drops: Array[PowerUpData] = loot_table.roll_drops()
	var attempts := 0
	while drops.size() < guaranteed_drops and attempts < 10:
		var extra := loot_table.roll_drops()
		for d in extra:
			if d != null and drops.size() < guaranteed_drops:
				drops.append(d)
		attempts += 1
	for i in drops.size():
		if drops[i] == null:
			continue
		var powerup_pickup := loot_item_scene.instantiate() as PowerUpPickup
		if powerup_pickup == null:
			continue
		powerup_pickup.powerup_data = drops[i]
		var angle := (float(i) / drops.size()) * TAU
		powerup_pickup.global_position = global_position + Vector2(cos(angle) * 24, sin(angle) * 24)
		get_tree().current_scene.add_child(powerup_pickup)

func _on_died() -> void:
	target = null
	velocity = Vector2.ZERO
	_remove_shadow_marker()
	collision.set_deferred("disabled", true)
	if has_node("Hurtbox"):
		$Hurtbox.set_deferred("monitoring",  false)
		$Hurtbox.set_deferred("monitorable", false)
	animated_sprite.modulate = Color.WHITE
	var death_fade := create_tween()
	death_fade.tween_property(animated_sprite, "modulate:a", 0.0, 0.6)
	drop_gold.call_deferred()
	drop_loot.call_deferred()
	await get_tree().create_timer(0.8).timeout
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
