extends CharacterBody2D
class_name BossEnemy

# ── Movement ──────────────────────────────────────────────────────────
@export var move_speed: float = 55.0
@export var stop_distance: float = 36.0

# ── Visuals ───────────────────────────────────────────────────────────
@export var boss_name: String = "The Brute"

# ── Attack 1: Charge Burst ────────────────────────────────────────────
@export var burst_charge_duration: float = 2.0
@export var burst_projectile_count: int = 14
@export var burst_speed: float = 120.0
@export var burst_damage: int = 15

# ── Attack 2: Bull Rush ───────────────────────────────────────────────
@export var rush_windup_time: float = 0.6
@export var rush_speed: float = 280.0
@export var rush_trail_interval: float = 0.02      ## Faster trail (was 0.04)
@export var rush_trail_speed: float = 60.0
@export var rush_trail_damage: int = 10
@export var rush_impact_count: int = 6
@export var rush_impact_speed: float = 90.0
@export var rush_impact_damage: int = 12
@export var rush_pincer_angle: float = 0.35        ## Angle of convergent lines

# ── Attack 3: Stomp Waves ─────────────────────────────────────────────
@export var stomp_count: int = 3
@export var stomp_ring_size: int = 10
@export var stomp_delay: float = 0.6
@export var stomp_base_speed: float = 70.0
@export var stomp_speed_step: float = 25.0
@export var stomp_damage: int = 10
@export var stomp_fire_interval: float = 0.015    ## Stagger projectiles (was instant)

# ── General ───────────────────────────────────────────────────────────
@export var boss_projectile_scene: PackedScene
@export var attack_cooldown: float = 3.0
@export var attack_range: float = 220.0

# ── Loot ──────────────────────────────────────────────────────────────
@export var loot_table: LootTable
@export var loot_item_scene: PackedScene
@export var gold_pickup_scene: PackedScene
@export var min_gold_drop := 15
@export var max_gold_drop := 30
@export var guaranteed_drops: int = 2

# ── Node Refs ─────────────────────────────────────────────────────────
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var collision: CollisionShape2D = $CollisionShape2D

# ── Internal State ────────────────────────────────────────────────────
enum State { CHASING, ATTACKING, RUSHING, COOLDOWN }
enum Attack { CHARGE_BURST, BULL_RUSH, STOMP_WAVES }

var state: State = State.CHASING
var target: Node2D = null
var last_direction: Vector2 = Vector2.DOWN
var attack_timer: float = 0.0
var last_attack: int = -1
var boss_bar: BossHealthBarUI = null
var rush_target_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	health_component.died.connect(_on_died)
	_acquire_target()

	boss_bar = BossHealthBarUI.new()
	boss_bar.setup(boss_name, health_component)
	get_tree().current_scene.add_child.call_deferred(boss_bar)

	attack_timer = attack_cooldown * 0.6

# ── Target Acquisition ────────────────────────────────────────────────

func set_target(new_target: Node2D) -> void:
	target = new_target

func _acquire_target() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target = players[0] as Node2D

# ── Main Loop ─────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if health_component.is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not is_instance_valid(target):
		_acquire_target()
		velocity = Vector2.ZERO
		play_idle_animation()
		move_and_slide()
		return

	match state:
		State.CHASING:
			_state_chasing(delta)
		State.ATTACKING:
			velocity = Vector2.ZERO
			play_idle_animation()
		State.RUSHING:
			move_and_slide()
			return
		State.COOLDOWN:
			follow_target()
			attack_timer -= delta
			if attack_timer <= 0.0:
				state = State.CHASING

	move_and_slide()

func _state_chasing(delta: float) -> void:
	follow_target()
	attack_timer -= delta
	if attack_timer <= 0.0:
		var dist := global_position.distance_to(target.global_position)
		if dist <= attack_range:
			_start_attack()

# ── Attack Selection ──────────────────────────────────────────────────

func _start_attack() -> void:
	if boss_projectile_scene == null:
		push_warning("BossEnemy: No boss_projectile_scene assigned.")
		attack_timer = attack_cooldown
		return

	var options := [Attack.CHARGE_BURST, Attack.BULL_RUSH, Attack.STOMP_WAVES]
	options.erase(last_attack)
	var chosen: int = options.pick_random()
	last_attack = chosen

	match chosen:
		Attack.CHARGE_BURST:
			state = State.ATTACKING
			_attack_charge_burst()
		Attack.BULL_RUSH:
			_attack_bull_rush()
		Attack.STOMP_WAVES:
			state = State.ATTACKING
			_attack_stomp_waves()

# ══════════════════════════════════════════════════════════════════════
# ATTACK 1: CHARGE BURST
# ══════════════════════════════════════════════════════════════════════

func _attack_charge_burst() -> void:
	if health_component.is_dead: return

	var original_color: Color = animated_sprite.modulate
	var warning_color := Color(1.0, 0.2, 0.1)

	var p1 := burst_charge_duration * 0.45
	var p2 := burst_charge_duration * 0.30
	var p3 := burst_charge_duration * 0.25

	await _flicker(p1, 0.25, original_color, warning_color)
	if health_component.is_dead: return
	await _flicker(p2, 0.12, original_color, warning_color)
	if health_component.is_dead: return
	await _flicker(p3, 0.05, original_color, warning_color)
	if health_component.is_dead: return

	animated_sprite.modulate = original_color

	# Stagger the projectile fire slightly for visual intensity.
	for i in burst_projectile_count:
		if health_component.is_dead: return
		var angle := (float(i) / float(burst_projectile_count)) * TAU
		_fire_projectile(Vector2(cos(angle), sin(angle)), burst_speed, burst_damage)
		if i < burst_projectile_count - 1:
			await get_tree().create_timer(0.01).timeout

	_enter_cooldown()

func _flicker(duration: float, interval: float, color_a: Color, color_b: Color) -> void:
	var elapsed := 0.0
	var toggle := false
	while elapsed < duration:
		if health_component.is_dead: return
		toggle = !toggle
		animated_sprite.modulate = color_b if toggle else color_a
		await get_tree().create_timer(interval).timeout
		elapsed += interval

# ══════════════════════════════════════════════════════════════════════
# ATTACK 2: BULL RUSH with 4 LINES (outward trails + inward pincer)
# ══════════════════════════════════════════════════════════════════════
# As the boss charges, it leaves 2 outward trail lines (left/right)
# AND fires 2 convergent inward lines ahead of itself. The player must
# thread through the narrowing gauntlet created by these crossing lines.
# ══════════════════════════════════════════════════════════════════════

func _attack_bull_rush() -> void:
	if health_component.is_dead: return

	# ── TELEGRAPH ─────────────────────────────────────────────────
	velocity = Vector2.ZERO
	state = State.ATTACKING
	rush_target_pos = target.global_position

	var original_scale: Vector2 = animated_sprite.scale
	var windup_tween := create_tween().set_parallel(true)
	windup_tween.tween_property(animated_sprite, "modulate", Color(1.0, 0.2, 0.1), rush_windup_time * 0.6)
	windup_tween.tween_property(animated_sprite, "scale", original_scale * 1.25, rush_windup_time * 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)

	await get_tree().create_timer(rush_windup_time).timeout
	if health_component.is_dead: return

	# ── CHARGE with 4-LINE PATTERN ────────────────────────────────
	state = State.RUSHING
	var direction := global_position.direction_to(rush_target_pos)
	var distance := global_position.distance_to(rush_target_pos)
	var total_dist := distance + 40.0
	var traveled := 0.0

	while traveled < total_dist:
		if health_component.is_dead: return

		var step := rush_speed * get_physics_process_delta_time()
		velocity = direction * rush_speed
		traveled += step
		global_position += direction * step

		# LINES 1 & 2: Outward trails (left and right perpendicular)
		# These are projectiles left behind as the boss passes, spreading outward.
		var perp := Vector2(-direction.y, direction.x)
		_fire_projectile(perp, rush_trail_speed, rush_trail_damage)
		_fire_projectile(-perp, rush_trail_speed, rush_trail_damage)

		# LINES 3 & 4: Inward pincer lines (ahead and converging)
		# These fire from ahead of the boss's current position at angles
		# that converge back toward the center line, creating a narrowing
		# corridor the player must thread through.
		var pincer_ahead := global_position + direction * 30.0
		var pincer_left := Vector2(cos(direction.angle() + rush_pincer_angle), sin(direction.angle() + rush_pincer_angle))
		var pincer_right := Vector2(cos(direction.angle() - rush_pincer_angle), sin(direction.angle() - rush_pincer_angle))

		# Fire the pincer projectiles from ahead of the boss, angled inward.
		var proj_left := boss_projectile_scene.instantiate() as Node2D
		if proj_left:
			proj_left.global_position = pincer_ahead + pincer_left * 8.0
			get_tree().current_scene.add_child(proj_left)
			if proj_left.has_method("setup"):
				proj_left.setup(pincer_left, rush_trail_damage)
			if "speed" in proj_left:
				proj_left.speed = rush_trail_speed

		var proj_right := boss_projectile_scene.instantiate() as Node2D
		if proj_right:
			proj_right.global_position = pincer_ahead + pincer_right * 8.0
			get_tree().current_scene.add_child(proj_right)
			if proj_right.has_method("setup"):
				proj_right.setup(pincer_right, rush_trail_damage)
			if "speed" in proj_right:
				proj_right.speed = rush_trail_speed

		await get_tree().create_timer(rush_trail_interval).timeout

	velocity = Vector2.ZERO

	# ── IMPACT BURST ──────────────────────────────────────────────
	for i in rush_impact_count:
		var angle := (float(i) / float(rush_impact_count)) * TAU
		_fire_projectile(Vector2(cos(angle), sin(angle)), rush_impact_speed, rush_impact_damage)

	var reset_tween := create_tween().set_parallel(true)
	reset_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)
	reset_tween.tween_property(animated_sprite, "scale", original_scale, 0.3)

	_enter_cooldown()

# ══════════════════════════════════════════════════════════════════════
# ATTACK 3: STOMP WAVES
# ══════════════════════════════════════════════════════════════════════

func _attack_stomp_waves() -> void:
	if health_component.is_dead: return

	for stomp in stomp_count:
		if health_component.is_dead: return

		var original_scale: Vector2 = animated_sprite.scale
		var punch := create_tween()
		punch.tween_property(animated_sprite, "scale", original_scale * 1.3, 0.06)
		punch.tween_property(animated_sprite, "scale", original_scale, 0.15)

		animated_sprite.modulate = Color(1.0, 0.6, 0.2)
		await get_tree().create_timer(0.06).timeout
		animated_sprite.modulate = Color.WHITE

		var ring_speed := stomp_base_speed + stomp * stomp_speed_step
		var ring_offset := stomp * 0.3

		# Stagger the ring projectiles for a more aggressive feel.
		for i in stomp_ring_size:
			if health_component.is_dead: return
			var angle := (float(i) / float(stomp_ring_size)) * TAU + ring_offset
			_fire_projectile(Vector2(cos(angle), sin(angle)), ring_speed, stomp_damage)
			if i < stomp_ring_size - 1:
				await get_tree().create_timer(stomp_fire_interval).timeout

		if stomp < stomp_count - 1:
			await get_tree().create_timer(stomp_delay).timeout

	_enter_cooldown()

# ── Shared Helpers ────────────────────────────────────────────────────

func _enter_cooldown() -> void:
	state = State.COOLDOWN
	attack_timer = attack_cooldown

func _fire_projectile(dir: Vector2, spd: float, dmg: int) -> void:
	if boss_projectile_scene == null: return
	var proj := boss_projectile_scene.instantiate() as Node2D
	if proj == null: return
	proj.global_position = global_position + dir * 16.0
	get_tree().current_scene.add_child(proj)
	if proj.has_method("setup"):
		proj.setup(dir, dmg)
	if "speed" in proj:
		proj.speed = spd

# ── Movement ──────────────────────────────────────────────────────────

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

# ── Loot ──────────────────────────────────────────────────────────────

func drop_gold() -> void:
	if gold_pickup_scene == null: return
	var gold_piles := randi_range(3, 5)
	for i in gold_piles:
		var gold_pickup := gold_pickup_scene.instantiate() as GoldPickup
		if gold_pickup == null: continue
		gold_pickup.gold_amount = randi_range(min_gold_drop, max_gold_drop)
		gold_pickup.global_position = global_position + Vector2(
			randf_range(-24, 24), randf_range(-24, 24)
		)
		get_tree().current_scene.add_child(gold_pickup)

func drop_loot() -> void:
	if loot_table == null or loot_item_scene == null: return
	var drops: Array[PowerUpData] = loot_table.roll_drops()
	var attempts := 0
	while drops.size() < guaranteed_drops and attempts < 10:
		var extra := loot_table.roll_drops()
		for d in extra:
			if d != null and drops.size() < guaranteed_drops:
				drops.append(d)
		attempts += 1
	for i in drops.size():
		if drops[i] == null: continue
		var powerup_pickup := loot_item_scene.instantiate() as PowerUpPickup
		if powerup_pickup == null: continue
		powerup_pickup.powerup_data = drops[i]
		var angle := (float(i) / drops.size()) * TAU
		powerup_pickup.global_position = global_position + Vector2(
			cos(angle) * 20, sin(angle) * 20
		)
		get_tree().current_scene.add_child(powerup_pickup)

# ── Death ─────────────────────────────────────────────────────────────

func _on_died() -> void:
	target = null
	velocity = Vector2.ZERO
	collision.set_deferred("disabled", true)
	if has_node("Hurtbox"):
		$Hurtbox.set_deferred("monitoring", false)
		$Hurtbox.set_deferred("monitorable", false)
	drop_gold.call_deferred()
	drop_loot.call_deferred()
	play_death_animation()
	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("death"):
		await animated_sprite.animation_finished
	queue_free()

# ── Animations ────────────────────────────────────────────────────────

func play_walk_animation(direction: Vector2) -> void:
	if animated_sprite.sprite_frames == null: return
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
