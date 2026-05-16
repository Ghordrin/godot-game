extends CharacterBody2D
class_name PhantomBoss

# ── Movement ──────────────────────────────────────────────────────────
@export var move_speed: float = 40.0
@export var stop_distance: float = 100.0

# ── Visuals ───────────────────────────────────────────────────────────
@export var boss_name: String = "The Phantom"
@export var phantom_tint: Color = Color(0.6, 0.3, 0.9, 1.0)

# ── Teleport Settings ─────────────────────────────────────────────────
@export var teleport_min_dist: float = 120.0
@export var teleport_max_dist: float = 180.0
@export var shadow_warn_time: float = 0.8
@export var materialize_time: float = 0.4

# ── Attack: Aimed Salvo ───────────────────────────────────────────────
@export var salvo_count: int = 5
@export var salvo_interval: float = 0.15
@export var salvo_speed: float = 180.0
@export var salvo_damage: int = 12

# ── Attack: Spiral Barrage ────────────────────────────────────────────
@export var spiral_count: int = 28
@export var spiral_rotations: float = 3.0
@export var spiral_fire_interval: float = 0.055
@export var spiral_speed: float = 100.0
@export var spiral_damage: int = 8

# ── Attack: Cross Burst ───────────────────────────────────────────────
@export var cross_projectiles_per_arm: int = 3
@export var cross_base_speed: float = 80.0
@export var cross_speed_step: float = 35.0
@export var cross_delay: float = 0.5
@export var cross_damage: int = 10

# ── General Attack Settings ───────────────────────────────────────────
@export var boss_projectile_scene: PackedScene
@export var attack_cooldown: float = 1.5

# ── Loot ──────────────────────────────────────────────────────────────
@export var loot_table: LootTable
@export var loot_item_scene: PackedScene
@export var gold_pickup_scene: PackedScene
@export var min_gold_drop := 20
@export var max_gold_drop := 40
@export var guaranteed_drops: int = 3

# ── Node Refs ─────────────────────────────────────────────────────────
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var collision: CollisionShape2D = $CollisionShape2D

# ── Internal State ────────────────────────────────────────────────────
enum State { CHASING, TELEPORTING, MATERIALIZING, ATTACKING, POST_ATTACK }
enum Attack { SALVO, SPIRAL, CROSS }

var state: State = State.CHASING
var target: Node2D = null
var last_direction: Vector2 = Vector2.DOWN
var shadow_marker: Node2D = null
var last_attack: int = Attack.SALVO
var boss_bar: BossHealthBarUI = null

func _ready() -> void:
	health_component.died.connect(_on_died)
	animated_sprite.modulate = phantom_tint
	_acquire_target()

	# Spawn the screen-wide boss health bar.
	boss_bar = BossHealthBarUI.new()
	boss_bar.setup(boss_name, health_component)
	get_tree().current_scene.add_child.call_deferred(boss_bar)

	# Start the fight loop after a brief delay.
	_start_fight_loop()

# ── Target Acquisition ────────────────────────────────────────────────

func set_target(new_target: Node2D) -> void:
	target = new_target

func _acquire_target() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target = players[0] as Node2D

# ── Main Loop ─────────────────────────────────────────────────────────

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
				var distance := global_position.distance_to(target.global_position)
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

# ── Fight Loop ────────────────────────────────────────────────────────

func _start_fight_loop() -> void:
	await get_tree().create_timer(1.5).timeout
	_fight_loop()

func _fight_loop() -> void:
	while not health_component.is_dead:
		if not is_instance_valid(target):
			_acquire_target()
			await get_tree().create_timer(0.5).timeout
			continue

		# Teleport near the player.
		await _teleport_near_player()
		if health_component.is_dead:
			return

		# Brief pause after arriving — player's window to orient.
		state = State.MATERIALIZING
		await get_tree().create_timer(materialize_time).timeout
		if health_component.is_dead:
			return

		# Pick and execute a random attack.
		state = State.ATTACKING
		var attack := _pick_attack()
		await _execute_attack(attack)
		if health_component.is_dead:
			return

		# Pause before next teleport.
		state = State.POST_ATTACK
		await get_tree().create_timer(attack_cooldown).timeout

# ── Teleportation ─────────────────────────────────────────────────────

func _teleport_near_player() -> void:
	state = State.TELEPORTING

	var angle := randf() * TAU
	var dist := randf_range(teleport_min_dist, teleport_max_dist)
	var destination := target.global_position + Vector2(cos(angle), sin(angle)) * dist

	# Show the shadow warning at the destination.
	_spawn_shadow_marker(destination)

	# Fade the boss out.
	var fade_out := create_tween()
	fade_out.tween_property(animated_sprite, "modulate:a", 0.0, shadow_warn_time * 0.4)
	await get_tree().create_timer(shadow_warn_time).timeout

	if health_component.is_dead:
		_remove_shadow_marker()
		return

	# Blink to the destination.
	global_position = destination
	_remove_shadow_marker()

	# Fade back in.
	animated_sprite.modulate = Color(phantom_tint.r, phantom_tint.g, phantom_tint.b, 0.0)
	var fade_in := create_tween()
	fade_in.tween_property(animated_sprite, "modulate:a", 1.0, materialize_time * 0.8)

func _spawn_shadow_marker(pos: Vector2) -> void:
	shadow_marker = Node2D.new()
	shadow_marker.global_position = pos
	shadow_marker.z_index = -1
	get_tree().current_scene.add_child(shadow_marker)

	# Draw a soft purple circle as a warning marker.
	var sprite := Sprite2D.new()
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var center := Vector2(16, 16)
	for x in 32:
		for y in 32:
			var d := Vector2(x, y).distance_to(center)
			if d < 14.0:
				var alpha := clampf(1.0 - (d / 14.0), 0.0, 1.0) * 0.6
				img.set_pixel(x, y, Color(0.3, 0.1, 0.5, alpha))
	sprite.texture = ImageTexture.create_from_image(img)
	shadow_marker.add_child(sprite)

	# Pulse the shadow to draw the player's attention.
	var pulse := shadow_marker.create_tween().set_loops()
	pulse.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.3)
	pulse.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.3)

func _remove_shadow_marker() -> void:
	if is_instance_valid(shadow_marker):
		shadow_marker.queue_free()
		shadow_marker = null

# ── Attack Selection ──────────────────────────────────────────────────

func _pick_attack() -> int:
	var options := [Attack.SALVO, Attack.SPIRAL, Attack.CROSS]
	options.erase(last_attack)
	var chosen: int = options.pick_random()
	last_attack = chosen
	return chosen

func _execute_attack(attack: int) -> void:
	match attack:
		Attack.SALVO:
			await _attack_aimed_salvo()
		Attack.SPIRAL:
			await _attack_spiral_barrage()
		Attack.CROSS:
			await _attack_cross_burst()

# ── Attack 1: Aimed Salvo ─────────────────────────────────────────────

func _attack_aimed_salvo() -> void:
	for i in salvo_count:
		if health_component.is_dead or not is_instance_valid(target):
			return

		var dir := global_position.direction_to(target.global_position)
		_fire_projectile(dir, salvo_speed, salvo_damage)

		animated_sprite.modulate = Color.WHITE
		await get_tree().create_timer(0.05).timeout
		animated_sprite.modulate = phantom_tint

		if i < salvo_count - 1:
			await get_tree().create_timer(salvo_interval).timeout

# ── Attack 2: Spiral Barrage ──────────────────────────────────────────

func _attack_spiral_barrage() -> void:
	for i in spiral_count:
		if health_component.is_dead:
			return

		var angle := (float(i) / float(spiral_count)) * TAU * spiral_rotations
		var dir := Vector2(cos(angle), sin(angle))
		_fire_projectile(dir, spiral_speed, spiral_damage)

		if i % 4 == 0:
			animated_sprite.modulate = Color(0.8, 0.5, 1.0)
			await get_tree().create_timer(0.02).timeout
			animated_sprite.modulate = phantom_tint

		await get_tree().create_timer(spiral_fire_interval).timeout

# ── Attack 3: Cross Burst ─────────────────────────────────────────────

func _attack_cross_burst() -> void:
	if health_component.is_dead:
		return

	# Phase 1: + shape (cardinal directions)
	_fire_burst_pattern([0.0, PI * 0.5, PI, PI * 1.5])

	animated_sprite.modulate = Color.WHITE
	await get_tree().create_timer(0.1).timeout
	animated_sprite.modulate = phantom_tint

	# Pause — player's window to reposition.
	await get_tree().create_timer(cross_delay).timeout
	if health_component.is_dead:
		return

	# Phase 2: X shape (diagonal directions)
	_fire_burst_pattern([PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75])

	animated_sprite.modulate = Color.WHITE
	await get_tree().create_timer(0.1).timeout
	animated_sprite.modulate = phantom_tint

func _fire_burst_pattern(angles: Array) -> void:
	for angle in angles:
		var dir := Vector2(cos(angle), sin(angle))
		for j in cross_projectiles_per_arm:
			var spd := cross_base_speed + j * cross_speed_step
			_fire_projectile(dir, spd, cross_damage)

# ── Projectile Spawning ──────────────────────────────────────────────

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

# ── Loot ──────────────────────────────────────────────────────────────

func drop_gold() -> void:
	if gold_pickup_scene == null:
		return
	var gold_piles := randi_range(4, 6)
	for i in gold_piles:
		var gold_pickup := gold_pickup_scene.instantiate() as GoldPickup
		if gold_pickup == null:
			continue
		gold_pickup.gold_amount = randi_range(min_gold_drop, max_gold_drop)
		gold_pickup.global_position = global_position + Vector2(
			randf_range(-28, 28), randf_range(-28, 28)
		)
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
		powerup_pickup.global_position = global_position + Vector2(
			cos(angle) * 24, sin(angle) * 24
		)
		get_tree().current_scene.add_child(powerup_pickup)

# ── Death ─────────────────────────────────────────────────────────────

func _on_died() -> void:
	target = null
	velocity = Vector2.ZERO
	_remove_shadow_marker()

	collision.set_deferred("disabled", true)
	if has_node("Hurtbox"):
		$Hurtbox.set_deferred("monitoring", false)
		$Hurtbox.set_deferred("monitorable", false)

	# Dramatic death flash and fade.
	animated_sprite.modulate = Color.WHITE
	var death_fade := create_tween()
	death_fade.tween_property(animated_sprite, "modulate:a", 0.0, 0.6)

	drop_gold.call_deferred()
	drop_loot.call_deferred()

	await get_tree().create_timer(0.8).timeout
	queue_free()

# ── Animations ────────────────────────────────────────────────────────

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
