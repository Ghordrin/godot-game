extends CharacterBody2D
class_name PhantomBoss

# ══════════════════════════════════════════════════════════════════════
# MOVEMENT / IDENTITY
# ══════════════════════════════════════════════════════════════════════

@export var move_speed: float = 42.0
@export var stop_distance: float = 115.0
@export var boss_name: String = "The Phantom"
@export var phantom_tint: Color = Color(0.6, 0.3, 0.9, 1.0)

# ══════════════════════════════════════════════════════════════════════
# TELEPORT SETTINGS
# ══════════════════════════════════════════════════════════════════════

@export var teleport_min_dist: float = 125.0
@export var teleport_max_dist: float = 190.0
@export var shadow_warn_time: float = 0.45
@export var materialize_time: float = 0.20
@export var attacks_before_teleport: int = 2

# ══════════════════════════════════════════════════════════════════════
# ATTACK 1: HAUNTING SALVO
# ══════════════════════════════════════════════════════════════════════

@export var salvo_count: int = 7
@export var salvo_interval: float = 0.08
@export var salvo_speed: float = 215.0
@export var salvo_damage: int = 12
@export var salvo_spread_deg: float = 16.0

# ══════════════════════════════════════════════════════════════════════
# ATTACK 2: PHASE SPIRAL
# ══════════════════════════════════════════════════════════════════════

@export var spiral_count: int = 42
@export var spiral_rotations: float = 3.4
@export var spiral_fire_interval: float = 0.032
@export var spiral_speed: float = 118.0
@export var spiral_damage: int = 8
@export var spiral_reverse_second_wave: bool = true
@export var spiral_second_wave_delay: float = 0.20

# ══════════════════════════════════════════════════════════════════════
# ATTACK 3: SHADOW CROSS
# ══════════════════════════════════════════════════════════════════════

@export var cross_projectiles_per_arm: int = 5
@export var cross_base_speed: float = 92.0
@export var cross_speed_step: float = 38.0
@export var cross_delay: float = 0.28
@export var cross_damage: int = 10

# ══════════════════════════════════════════════════════════════════════
# ATTACK 4: SPECTRAL FAN AMBUSH
# ══════════════════════════════════════════════════════════════════════

@export var fan_count: int = 9
@export var fan_spread_deg: float = 85.0
@export var fan_speed: float = 195.0
@export var fan_damage: int = 14
@export var fan_burst_count: int = 3
@export var fan_burst_interval: float = 0.25

# ══════════════════════════════════════════════════════════════════════
# ATTACK 5: MIRROR PHANTOMS
# ══════════════════════════════════════════════════════════════════════

@export var clone_count: int = 3
@export var clone_warning_time: float = 0.35
@export var clone_projectiles: int = 5
@export var clone_projectile_speed: float = 175.0
@export var clone_damage: int = 10
@export var clone_radius: float = 145.0

# ══════════════════════════════════════════════════════════════════════
# GENERAL ATTACK SETTINGS
# ══════════════════════════════════════════════════════════════════════

@export var boss_projectile_scene: PackedScene
@export var attack_cooldown: float = 0.75

# ══════════════════════════════════════════════════════════════════════
# ICE SLOW SUPPORT
# ══════════════════════════════════════════════════════════════════════

var ice_slow_speed_properties: Array[String] = [
	"move_speed",
	"salvo_speed",
	"spiral_speed",
	"cross_base_speed",
	"cross_speed_step",
	"fan_speed",
	"clone_projectile_speed",
]

var ice_slow_interval_properties: Array[String] = [
	"attack_cooldown",
	"shadow_warn_time",
	"materialize_time",
	"salvo_interval",
	"spiral_fire_interval",
	"cross_delay",
	"fan_burst_interval",
	"clone_warning_time",
]

# ══════════════════════════════════════════════════════════════════════
# LOOT
# ══════════════════════════════════════════════════════════════════════

@export var loot_table: PowerUpTable
@export var loot_item_scene: PackedScene
@export var gold_pickup_scene: PackedScene

@export var min_gold_drop := 20
@export var max_gold_drop := 40
@export var gold_pile_count_min: int = 4
@export var gold_pile_count_max: int = 6

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
# INTERNAL STATE
# ══════════════════════════════════════════════════════════════════════

enum State {
	CHASING,
	TELEPORTING,
	MATERIALIZING,
	ATTACKING,
	POST_ATTACK
}

enum Attack {
	SALVO,
	SPIRAL,
	CROSS,
	FAN,
	CLONES
}

var state: State = State.CHASING
var target: Node2D = null
var last_direction: Vector2 = Vector2.DOWN
var shadow_marker: Node2D = null
var last_attack: int = Attack.SALVO
var boss_bar: BossHealthBarUI = null
var _attacks_this_burst: int = 0
var _is_dying: bool = false


func _ready() -> void:
	health_component.died.connect(_on_died)

	animated_sprite.modulate = phantom_tint

	_acquire_target()
	add_to_group("enemies")
	add_to_group("bosses")

	boss_bar = BossHealthBarUI.new()
	boss_bar.setup(boss_name, health_component)
	get_tree().current_scene.add_child.call_deferred(boss_bar)

	_start_fight_loop()


func _physics_process(_delta: float) -> void:
	if health_component.is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not is_instance_valid(target):
		_acquire_target()

	match state:
		State.CHASING:
			_process_chasing_state()

		_:
			velocity = Vector2.ZERO

	move_and_slide()


# ══════════════════════════════════════════════════════════════════════
# MANAGER API
# ══════════════════════════════════════════════════════════════════════

func set_target(new_target: Node2D) -> void:
	target = new_target


func set_gold_multiplier(_multiplier: float) -> void:
	# Boss gold is controlled through boss-specific pile values.
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


func _process_chasing_state() -> void:
	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		play_idle_animation()
		return

	var direction := global_position.direction_to(target.global_position)
	var distance := global_position.distance_to(target.global_position)

	last_direction = direction

	if distance > stop_distance:
		velocity = direction * move_speed
		play_walk_animation(direction)
	else:
		velocity = Vector2.ZERO
		play_idle_animation()


# ══════════════════════════════════════════════════════════════════════
# FIGHT LOOP
# ══════════════════════════════════════════════════════════════════════

func _start_fight_loop() -> void:
	await get_tree().create_timer(1.1).timeout
	_fight_loop()


func _fight_loop() -> void:
	while not health_component.is_dead and not _is_dying:
		if not is_instance_valid(target):
			_acquire_target()
			await get_tree().create_timer(0.3).timeout
			continue

		if _attacks_this_burst == 0:
			await _teleport_near_player()

			if health_component.is_dead or _is_dying:
				return

			state = State.MATERIALIZING
			await get_tree().create_timer(materialize_time).timeout

			if health_component.is_dead or _is_dying:
				return

		state = State.ATTACKING

		var attack := _pick_attack()
		await _execute_attack(attack)

		if health_component.is_dead or _is_dying:
			return

		_attacks_this_burst += 1
		state = State.POST_ATTACK

		await get_tree().create_timer(attack_cooldown).timeout

		if _attacks_this_burst >= attacks_before_teleport:
			_attacks_this_burst = 0


# ══════════════════════════════════════════════════════════════════════
# TELEPORT
# ══════════════════════════════════════════════════════════════════════

func _teleport_near_player() -> void:
	if not is_instance_valid(target):
		return

	state = State.TELEPORTING

	var angle := randf() * TAU
	var dist := randf_range(teleport_min_dist, teleport_max_dist)
	var destination := target.global_position + Vector2(cos(angle), sin(angle)) * dist

	_spawn_shadow_marker(destination)

	var fade_out := create_tween()
	fade_out.tween_property(animated_sprite, "modulate:a", 0.0, shadow_warn_time * 0.4)

	await get_tree().create_timer(shadow_warn_time).timeout

	if health_component.is_dead or _is_dying:
		_remove_shadow_marker()
		return

	global_position = destination
	_remove_shadow_marker()

	animated_sprite.modulate = Color(phantom_tint.r, phantom_tint.g, phantom_tint.b, 0.0)

	var fade_in := create_tween()
	fade_in.tween_property(animated_sprite, "modulate:a", 1.0, materialize_time * 0.8)


func _spawn_shadow_marker(pos: Vector2) -> void:
	_remove_shadow_marker()

	shadow_marker = Node2D.new()
	shadow_marker.global_position = pos
	shadow_marker.z_index = -1
	shadow_marker.add_to_group("hazards")
	shadow_marker.add_to_group("wave_cleanup")

	get_tree().current_scene.add_child(shadow_marker)

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

	var pulse := shadow_marker.create_tween().set_loops()
	pulse.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.2)
	pulse.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.2)


func _remove_shadow_marker() -> void:
	if is_instance_valid(shadow_marker):
		shadow_marker.queue_free()

	shadow_marker = null


# ══════════════════════════════════════════════════════════════════════
# ATTACK SELECTION
# ══════════════════════════════════════════════════════════════════════

func _pick_attack() -> int:
	var pool: Array[int] = [
		Attack.SALVO,
		Attack.SALVO,
		Attack.FAN,
		Attack.FAN,
		Attack.SPIRAL,
		Attack.CROSS,
		Attack.CLONES,
	]

	pool.erase(last_attack)

	var chosen: int = pool.pick_random()
	last_attack = chosen

	return chosen


func _execute_attack(attack: int) -> void:
	match attack:
		Attack.SALVO:
			await _attack_haunting_salvo()

		Attack.SPIRAL:
			await _attack_phase_spiral()

		Attack.CROSS:
			await _attack_shadow_cross()

		Attack.FAN:
			await _attack_spectral_fan()

		Attack.CLONES:
			await _attack_mirror_phantoms()


# ══════════════════════════════════════════════════════════════════════
# ATTACK 1: HAUNTING SALVO
# ══════════════════════════════════════════════════════════════════════

func _attack_haunting_salvo() -> void:
	for i in salvo_count:
		if health_component.is_dead or _is_dying or not is_instance_valid(target):
			return

		var aim_dir := global_position.direction_to(target.global_position)
		var offset := 0.0

		if salvo_count > 1:
			offset = (float(i) / float(salvo_count - 1) - 0.5) * deg_to_rad(salvo_spread_deg)

		_fire_projectile(aim_dir.rotated(offset), salvo_speed, salvo_damage)

		await _flash(Color.WHITE, 0.035)

		if i < salvo_count - 1:
			await get_tree().create_timer(salvo_interval).timeout


# ══════════════════════════════════════════════════════════════════════
# ATTACK 2: PHASE SPIRAL
# ══════════════════════════════════════════════════════════════════════

func _attack_phase_spiral() -> void:
	for i in spiral_count:
		if health_component.is_dead or _is_dying:
			return

		var angle := (float(i) / float(spiral_count)) * TAU * spiral_rotations
		_fire_projectile(Vector2(cos(angle), sin(angle)), spiral_speed, spiral_damage)

		if i % 4 == 0:
			await _flash(Color(0.8, 0.5, 1.0), 0.015)

		await get_tree().create_timer(spiral_fire_interval).timeout

	if not spiral_reverse_second_wave:
		return

	await get_tree().create_timer(spiral_second_wave_delay).timeout

	var second_count := int(float(spiral_count) * 0.65)

	for i in second_count:
		if health_component.is_dead or _is_dying:
			return

		var angle := -(float(i) / float(second_count)) * TAU * (spiral_rotations - 0.8)
		_fire_projectile(Vector2(cos(angle), sin(angle)), spiral_speed * 0.9, spiral_damage)

		await get_tree().create_timer(spiral_fire_interval * 1.2).timeout


# ══════════════════════════════════════════════════════════════════════
# ATTACK 3: SHADOW CROSS
# ══════════════════════════════════════════════════════════════════════

func _attack_shadow_cross() -> void:
	if health_component.is_dead or _is_dying:
		return

	_fire_burst_pattern([0.0, PI * 0.5, PI, PI * 1.5])
	await _flash(Color.WHITE, 0.08)

	await get_tree().create_timer(cross_delay).timeout

	if health_component.is_dead or _is_dying:
		return

	_fire_burst_pattern([PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75])
	await _flash(Color.WHITE, 0.08)


func _fire_burst_pattern(angles: Array) -> void:
	for angle in angles:
		var dir := Vector2(cos(angle), sin(angle))

		for j in cross_projectiles_per_arm:
			_fire_projectile(dir, cross_base_speed + float(j) * cross_speed_step, cross_damage)


# ══════════════════════════════════════════════════════════════════════
# ATTACK 4: SPECTRAL FAN
# ══════════════════════════════════════════════════════════════════════

func _attack_spectral_fan() -> void:
	for burst in fan_burst_count:
		if health_component.is_dead or _is_dying or not is_instance_valid(target):
			return

		var aim_dir := global_position.direction_to(target.global_position)
		var half_deg := fan_spread_deg / 2.0
		var step_deg := fan_spread_deg / float(maxi(1, fan_count - 1))

		for i in fan_count:
			var offset_deg := -half_deg + step_deg * float(i)
			_fire_projectile(aim_dir.rotated(deg_to_rad(offset_deg)), fan_speed, fan_damage)

		await _flash(Color(1.0, 0.7, 1.0), 0.06)

		if burst < fan_burst_count - 1:
			await get_tree().create_timer(fan_burst_interval).timeout


# ══════════════════════════════════════════════════════════════════════
# ATTACK 5: MIRROR PHANTOMS
# ══════════════════════════════════════════════════════════════════════

func _attack_mirror_phantoms() -> void:
	if not is_instance_valid(target):
		return

	var clone_positions: Array[Vector2] = []

	for i in clone_count:
		var angle := (float(i) / float(clone_count)) * TAU + randf_range(-0.25, 0.25)
		var pos := target.global_position + Vector2(cos(angle), sin(angle)) * clone_radius
		clone_positions.append(pos)
		_spawn_clone_marker(pos)

	await get_tree().create_timer(clone_warning_time).timeout

	for pos in clone_positions:
		if health_component.is_dead or _is_dying:
			return

		_fire_clone_volley(pos)


func _spawn_clone_marker(pos: Vector2) -> void:
	var marker := Node2D.new()
	marker.global_position = pos
	marker.z_index = -1
	marker.add_to_group("hazards")
	marker.add_to_group("wave_cleanup")

	get_tree().current_scene.add_child(marker)

	var sprite := Sprite2D.new()
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	var center := Vector2(12, 12)

	for x in 24:
		for y in 24:
			var d := Vector2(x, y).distance_to(center)

			if d < 10.0:
				var alpha := clampf(1.0 - (d / 10.0), 0.0, 1.0) * 0.45
				img.set_pixel(x, y, Color(0.7, 0.25, 1.0, alpha))

	sprite.texture = ImageTexture.create_from_image(img)
	marker.add_child(sprite)

	var tween := marker.create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.6, 1.6), clone_warning_time)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.12)
	tween.tween_callback(marker.queue_free)


func _fire_clone_volley(origin: Vector2) -> void:
	if not is_instance_valid(target):
		return

	var aim_dir := origin.direction_to(target.global_position)
	var spread_deg := 45.0
	var step_deg := spread_deg / float(maxi(1, clone_projectiles - 1))

	for i in clone_projectiles:
		var offset_deg := -spread_deg * 0.5 + step_deg * float(i)
		_fire_projectile_from(origin, aim_dir.rotated(deg_to_rad(offset_deg)), clone_projectile_speed, clone_damage)


# ══════════════════════════════════════════════════════════════════════
# PROJECTILES / VISUALS
# ══════════════════════════════════════════════════════════════════════

func _fire_projectile(dir: Vector2, speed: float, damage: int) -> void:
	_fire_projectile_from(global_position + dir.normalized() * 16.0, dir, speed, damage)


func _fire_projectile_from(origin: Vector2, dir: Vector2, speed: float, damage: int) -> void:
	if boss_projectile_scene == null:
		return

	var proj := boss_projectile_scene.instantiate() as Node2D

	if proj == null:
		return

	var safe_dir := dir.normalized()

	if safe_dir == Vector2.ZERO:
		safe_dir = Vector2.DOWN

	proj.global_position = origin
	proj.add_to_group("enemy_projectiles")
	proj.add_to_group("wave_cleanup")

	get_tree().current_scene.add_child(proj)

	if proj.has_method("setup"):
		proj.setup(safe_dir, damage)

	if "speed" in proj:
		proj.speed = speed


func _flash(color: Color, duration: float) -> void:
	if animated_sprite == null:
		await get_tree().create_timer(duration).timeout
		return

	var original := animated_sprite.modulate
	animated_sprite.modulate = color

	await get_tree().create_timer(duration).timeout

	if is_instance_valid(animated_sprite):
		animated_sprite.modulate = original


# ══════════════════════════════════════════════════════════════════════
# LOOT
# ══════════════════════════════════════════════════════════════════════

func drop_gold() -> void:
	if gold_pickup_scene == null:
		return

	var pile_count := randi_range(gold_pile_count_min, gold_pile_count_max)

	for _i in pile_count:
		var gold_pickup := gold_pickup_scene.instantiate() as GoldPickup

		if gold_pickup == null:
			continue

		gold_pickup.gold_amount = randi_range(min_gold_drop, max_gold_drop)
		gold_pickup.global_position = global_position + Vector2(
			randf_range(-30.0, 30.0),
			randf_range(-30.0, 30.0)
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

	var attempts := 0
	var max_attempts := drop_count * 12

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
		push_warning("PhantomBoss: loot_item_scene root is not a PowerUpPickup.")
		return

	powerup_pickup.powerup_data = powerup
	powerup_pickup.is_wave_temporary = is_wave_temporary_drop

	var angle := (float(index) / float(maxi(1, total_count))) * TAU
	var offset := Vector2(cos(angle), sin(angle)) * 30.0

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
	#play_death_animation()

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
