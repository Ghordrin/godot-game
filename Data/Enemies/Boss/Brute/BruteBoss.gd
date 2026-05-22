extends CharacterBody2D
class_name BossEnemy

# ── Movement ──────────────────────────────────────────────────────────

## Movement speed while chasing. Brute is slow but hits hard.
@export var move_speed: float = 55.0

## Distance at which the Brute stops and switches to melee idle.
@export var stop_distance: float = 36.0

# ── Visuals ───────────────────────────────────────────────────────────

## Name displayed on the boss health bar.
@export var boss_name: String = "The Brute"

# ── Attack 1: Layered Burst ───────────────────────────────────────────

## Seconds spent flickering before the burst fires.
## Three phases of increasing speed to telegraph urgency.
@export var burst_charge_duration: float = 1.6

## Projectiles in the first immediate ring.
@export var burst_ring1_count: int = 12

## Projectiles in the second delayed ring (offset half-step).
@export var burst_ring2_count: int = 10

## Aimed shots in the final volley (tracks player position at fire time).
@export var burst_volley_count: int = 4

## Speed of burst ring projectiles.
@export var burst_speed: float = 130.0

## Damage per burst projectile.
@export var burst_damage: int = 15

# ── Attack 2: Bull Rush ───────────────────────────────────────────────

## Windup time before the rush — gives the player a narrow window to reposition.
@export var rush_windup_time: float = 0.5

## Speed of the boss during the charge.
@export var rush_speed: float = 290.0

## Seconds between trail projectile spawns during the charge.
@export var rush_trail_interval: float = 0.02

## Speed of the perpendicular trail projectiles left during the charge.
@export var rush_trail_speed: float = 65.0

## Damage per trail projectile.
@export var rush_trail_damage: int = 10

## Projectiles in the impact ring fired when the charge ends.
@export var rush_impact_count: int = 8

## Speed of impact ring projectiles.
@export var rush_impact_speed: float = 100.0

## Damage per impact projectile.
@export var rush_impact_damage: int = 14

## Angle in radians for the converging pincer lines ahead of the rush.
@export var rush_pincer_angle: float = 0.35

# ── Attack 3: Stomp Waves with Deferred Explosions ────────────────────

## How many stomp rings fire in sequence.
@export var stomp_count: int = 3

## Projectiles per stomp ring.
@export var stomp_ring_size: int = 12

## Seconds between each stomp ring.
@export var stomp_delay: float = 0.55

## Speed of the first stomp ring. Each subsequent ring is faster.
@export var stomp_base_speed: float = 75.0

## Speed added to each successive stomp ring.
@export var stomp_speed_step: float = 28.0

## Damage per stomp projectile.
@export var stomp_damage: int = 10

## Stagger interval between projectiles within a ring (visual effect).
@export var stomp_fire_interval: float = 0.012

## Seconds after a stomp before the deferred secondary rings explode.
## Creates a second wave of danger the player thought they were safe from.
@export var stomp_deferred_delay: float = 1.2

## Projectiles in each deferred secondary ring.
@export var stomp_deferred_ring_size: int = 8

## Speed of secondary ring projectiles.
@export var stomp_deferred_speed: float = 95.0

# ── Attack 4: Spiral Sweep ────────────────────────────────────────────

## Total projectiles fired in the primary spiral.
@export var spiral_count: int = 24

## Total rotations the spiral makes — higher = tighter spiral.
@export var spiral_rotations: float = 2.5

## Seconds between each spiral projectile.
@export var spiral_interval: float = 0.03

## Speed of spiral projectiles.
@export var spiral_speed: float = 105.0

## Damage per spiral projectile.
@export var spiral_damage: int = 9

## Whether a second loose spiral fires in the opposite direction afterward.
## Creates a gap-threading challenge where both spirals are in play simultaneously.
@export var spiral_double: bool = true

## Delay between the first and second spiral.
@export var spiral_double_delay: float = 0.35

# ── General ───────────────────────────────────────────────────────────

## Projectile scene for all boss attacks.
@export var boss_projectile_scene: PackedScene

## Distance at which the Brute starts attacking.
## Higher than most enemies so it attacks before the player is on top of it.
@export var attack_range: float = 350.0

## Seconds between attack sequences.
@export var attack_cooldown: float = 2.5

# ── Loot ──────────────────────────────────────────────────────────────

@export var loot_table: PowerUpTable
@export var loot_item_scene: PackedScene
@export var gold_pickup_scene: PackedScene

## Minimum gold dropped per pile on death.
@export var min_gold_drop := 15

## Maximum gold dropped per pile on death.
@export var max_gold_drop := 30

## Guaranteed powerup drops on death.
@export var guaranteed_drops: int = 2

# ── Node Refs ─────────────────────────────────────────────────────────
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var collision: CollisionShape2D       = $CollisionShape2D

# ── Internal State ────────────────────────────────────────────────────
enum State  { CHASING, ATTACKING, RUSHING, COOLDOWN }
enum Attack { LAYERED_BURST, BULL_RUSH, STOMP_WAVES, SPIRAL_SWEEP }

var state:        State   = State.CHASING
var target:       Node2D  = null
var last_direction: Vector2 = Vector2.DOWN
var attack_timer: float   = 0.0
var last_attack:  int     = -1
var boss_bar: BossHealthBarUI = null
var rush_target_pos: Vector2  = Vector2.ZERO


func _ready() -> void:
	health_component.died.connect(_on_died)
	_acquire_target()
	add_to_group("enemies")

	boss_bar = BossHealthBarUI.new()
	boss_bar.setup(boss_name, health_component)
	get_tree().current_scene.add_child.call_deferred(boss_bar)

	# Start slightly early so the first attack comes quickly
	attack_timer = attack_cooldown * 0.5

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

	var options := [Attack.LAYERED_BURST, Attack.BULL_RUSH, Attack.STOMP_WAVES, Attack.SPIRAL_SWEEP]
	options.erase(last_attack)
	var chosen: int = options.pick_random()
	last_attack = chosen

	match chosen:
		Attack.LAYERED_BURST:
			state = State.ATTACKING
			_attack_layered_burst()
		Attack.BULL_RUSH:
			_attack_bull_rush()
		Attack.STOMP_WAVES:
			state = State.ATTACKING
			_attack_stomp_waves()
		Attack.SPIRAL_SWEEP:
			state = State.ATTACKING
			_attack_spiral_sweep()

# ══════════════════════════════════════════════════════════════════════
# ATTACK 1: LAYERED BURST
# ══════════════════════════════════════════════════════════════════════
# Three waves in rapid succession:
#   Ring 1 — immediate full ring
#   Ring 2 — half-step offset ring 0.2s later (fills the gaps)
#   Volley  — aimed shots tracking player 0.3s after ring 2
# The three-layer timing means there is no clean dodge window that avoids all three.

func _attack_layered_burst() -> void:
	if health_component.is_dead:
		return

	var original_color: Color  = animated_sprite.modulate
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

	# Ring 1 — immediate uniform ring
	for i in burst_ring1_count:
		if health_component.is_dead: return
		var angle := (float(i) / float(burst_ring1_count)) * TAU
		_fire_projectile(Vector2(cos(angle), sin(angle)), burst_speed, burst_damage)
		if i < burst_ring1_count - 1:
			await get_tree().create_timer(0.008).timeout

	await get_tree().create_timer(0.20).timeout
	if health_component.is_dead: return

	# Ring 2 — half-step offset to plug gaps from ring 1
	var half_step := TAU / float(burst_ring2_count * 2)
	for i in burst_ring2_count:
		if health_component.is_dead: return
		var angle := (float(i) / float(burst_ring2_count)) * TAU + half_step
		_fire_projectile(Vector2(cos(angle), sin(angle)), burst_speed * 1.15, burst_damage)
		if i < burst_ring2_count - 1:
			await get_tree().create_timer(0.008).timeout

	await get_tree().create_timer(0.25).timeout
	if health_component.is_dead: return

	# Aimed volley — tracks player at time of firing
	for i in burst_volley_count:
		if health_component.is_dead or not is_instance_valid(target): return
		var spread := (float(i) / float(burst_volley_count - 1) - 0.5) * deg_to_rad(40.0)
		var base_dir := global_position.direction_to(target.global_position)
		var dir      := base_dir.rotated(spread)
		_fire_projectile(dir, burst_speed * 1.3, burst_damage)
		await get_tree().create_timer(0.07).timeout

	_enter_cooldown()


func _flicker(duration: float, interval: float, color_a: Color, color_b: Color) -> void:
	var elapsed := 0.0
	var toggle  := false
	while elapsed < duration:
		if health_component.is_dead:
			return
		toggle = not toggle
		animated_sprite.modulate = color_b if toggle else color_a
		await get_tree().create_timer(interval).timeout
		elapsed += interval

# ══════════════════════════════════════════════════════════════════════
# ATTACK 2: BULL RUSH
# ══════════════════════════════════════════════════════════════════════

func _attack_bull_rush() -> void:
	if health_component.is_dead:
		return

	velocity = Vector2.ZERO
	state = State.ATTACKING
	rush_target_pos = target.global_position

	var original_scale: Vector2 = animated_sprite.scale
	var windup_tween := create_tween().set_parallel(true)
	windup_tween.tween_property(animated_sprite, "modulate", Color(1.0, 0.2, 0.1), rush_windup_time * 0.6)
	windup_tween.tween_property(animated_sprite, "scale", original_scale * 1.25, rush_windup_time * 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)

	await get_tree().create_timer(rush_windup_time).timeout
	if health_component.is_dead: return

	state = State.RUSHING
	var direction := global_position.direction_to(rush_target_pos)
	var distance  := global_position.distance_to(rush_target_pos)
	var total_dist: float = distance + 40.0
	var traveled:  float  = 0.0

	while traveled < total_dist:
		if health_component.is_dead: return
		var step: float = rush_speed * get_physics_process_delta_time()
		velocity = direction * rush_speed
		traveled += step
		global_position += direction * step

		# Outward trail lines (left and right)
		var perp := Vector2(-direction.y, direction.x)
		_fire_projectile(perp,  rush_trail_speed, rush_trail_damage)
		_fire_projectile(-perp, rush_trail_speed, rush_trail_damage)

		# Converging pincer lines fired ahead
		var ahead := global_position + direction * 30.0
		for dir_sign in [1.0, -1.0]:
			var pincer_dir := Vector2(
				cos(direction.angle() + rush_pincer_angle * dir_sign),
				sin(direction.angle() + rush_pincer_angle * dir_sign)
			)
			var proj := boss_projectile_scene.instantiate() as Node2D
			if proj:
				proj.global_position = ahead + pincer_dir * 8.0
				get_tree().current_scene.add_child(proj)
				if proj.has_method("setup"):
					proj.setup(pincer_dir, rush_trail_damage)
				if "speed" in proj:
					proj.speed = rush_trail_speed

		await get_tree().create_timer(rush_trail_interval).timeout

	velocity = Vector2.ZERO

	# Impact burst when charge ends
	for i in rush_impact_count:
		var angle := (float(i) / float(rush_impact_count)) * TAU
		_fire_projectile(Vector2(cos(angle), sin(angle)), rush_impact_speed, rush_impact_damage)

	var reset_tween := create_tween().set_parallel(true)
	reset_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)
	reset_tween.tween_property(animated_sprite, "scale",    original_scale, 0.3)

	_enter_cooldown()

# ══════════════════════════════════════════════════════════════════════
# ATTACK 3: STOMP WAVES with DEFERRED SECONDARY RINGS
# ══════════════════════════════════════════════════════════════════════
# Each stomp fires a ring AND plants deferred explosion markers.
# 1.2 seconds later those markers fire secondary rings where they stood,
# creating a second wave of danger the player thought they had cleared.

func _attack_stomp_waves() -> void:
	if health_component.is_dead:
		return

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
		var ring_offset: float = stomp * 0.3

		for i in stomp_ring_size:
			if health_component.is_dead: return
			var angle := (float(i) / float(stomp_ring_size)) * TAU + ring_offset
			_fire_projectile(Vector2(cos(angle), sin(angle)), ring_speed, stomp_damage)
			if i < stomp_ring_size - 1:
				await get_tree().create_timer(stomp_fire_interval).timeout

		# Plant 4 deferred explosion markers evenly around the boss.
		# They will fire secondary rings stomp_deferred_delay seconds later.
		_plant_deferred_rings(4, stomp_deferred_delay)

		if stomp < stomp_count - 1:
			await get_tree().create_timer(stomp_delay).timeout

	_enter_cooldown()


func _plant_deferred_rings(count: int, delay: float) -> void:
	## Spawns marker nodes at positions around the arena.
	## Each marker fires a secondary projectile ring after `delay` seconds.
	## The markers are static so the rings fire from where the fight is happening,
	## not from the boss itself — creating area denial rather than boss-centric danger.
	for i in count:
		var angle: float  = (float(i) / float(count)) * TAU + randf() * 0.5
		var dist: float   = randf_range(60.0, 130.0)
		var spawn_pos: Vector2 = global_position + Vector2(cos(angle), sin(angle)) * dist

		_fire_deferred_ring(spawn_pos, delay, stomp_deferred_ring_size, stomp_deferred_speed, stomp_damage - 2)


func _fire_deferred_ring(pos: Vector2, delay: float, ring_size: int, spd: float, dmg: int) -> void:
	## Waits `delay` seconds then fires a projectile ring from `pos`.
	## Runs as an async function so it doesn't block the attack sequence.
	var marker := Node2D.new()
	marker.global_position = pos
	get_tree().current_scene.add_child(marker)

	await get_tree().create_timer(delay).timeout

	if not is_instance_valid(marker) or health_component.is_dead:
		if is_instance_valid(marker):
			marker.queue_free()
		return

	var fire_pos: Vector2 = marker.global_position
	marker.queue_free()

	for i in ring_size:
		if boss_projectile_scene == null:
			break
		var angle := (float(i) / float(ring_size)) * TAU
		var proj  := boss_projectile_scene.instantiate() as Node2D
		if proj == null:
			continue
		proj.global_position = fire_pos
		get_tree().current_scene.add_child(proj)
		if proj.has_method("setup"):
			proj.setup(Vector2(cos(angle), sin(angle)), dmg)
		if "speed" in proj:
			proj.speed = spd

# ══════════════════════════════════════════════════════════════════════
# ATTACK 4: SPIRAL SWEEP
# ══════════════════════════════════════════════════════════════════════
# A tightening spiral of projectiles followed (optionally) by a second
# looser spiral in the opposite rotation. The two spirals interleave
# creating gaps the player must weave through while both are in flight.

func _attack_spiral_sweep() -> void:
	if health_component.is_dead:
		return

	animated_sprite.modulate = Color(0.9, 0.6, 0.2)

	# Primary spiral
	for i in spiral_count:
		if health_component.is_dead: return
		var angle := (float(i) / float(spiral_count)) * TAU * spiral_rotations
		_fire_projectile(Vector2(cos(angle), sin(angle)), spiral_speed, spiral_damage)
		if i % 3 == 0:
			animated_sprite.modulate = Color(1.0, 0.75, 0.25)
			await get_tree().create_timer(0.01).timeout
			animated_sprite.modulate = Color(0.9, 0.6, 0.2)
		await get_tree().create_timer(spiral_interval).timeout

	animated_sprite.modulate = Color.WHITE

	if spiral_double:
		await get_tree().create_timer(spiral_double_delay).timeout
		if health_component.is_dead: return

		# Second spiral rotates opposite direction, slightly wider spread
		animated_sprite.modulate = Color(0.8, 0.5, 0.9)
		var second_count: int = int(spiral_count * 0.75)
		for i in second_count:
			if health_component.is_dead: return
			# Negative rotations = opposite direction
			var angle := -(float(i) / float(second_count)) * TAU * (spiral_rotations - 0.5)
			_fire_projectile(Vector2(cos(angle), sin(angle)), spiral_speed * 0.85, spiral_damage)
			await get_tree().create_timer(spiral_interval * 1.2).timeout

		animated_sprite.modulate = Color.WHITE

	_enter_cooldown()

# ── Shared Helpers ────────────────────────────────────────────────────

func _enter_cooldown() -> void:
	state        = State.COOLDOWN
	attack_timer = attack_cooldown


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

# ── Movement ──────────────────────────────────────────────────────────

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

# ── Loot ──────────────────────────────────────────────────────────────

func drop_gold() -> void:
	if gold_pickup_scene == null:
		return
	for i in randi_range(3, 5):
		var gold_pickup := gold_pickup_scene.instantiate() as GoldPickup
		if gold_pickup == null:
			continue
		gold_pickup.gold_amount = randi_range(min_gold_drop, max_gold_drop)
		gold_pickup.global_position = global_position + Vector2(randf_range(-24, 24), randf_range(-24, 24))
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
		powerup_pickup.global_position = global_position + Vector2(cos(angle) * 20, sin(angle) * 20)
		get_tree().current_scene.add_child(powerup_pickup)

# ── Death ─────────────────────────────────────────────────────────────

func _on_died() -> void:
	target = null
	velocity = Vector2.ZERO
	collision.set_deferred("disabled", true)
	if has_node("Hurtbox"):
		$Hurtbox.set_deferred("monitoring",  false)
		$Hurtbox.set_deferred("monitorable", false)
	drop_gold.call_deferred()
	drop_loot.call_deferred()
	play_death_animation()
	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("death"):
		await animated_sprite.animation_finished
	queue_free()

# ── Animations ────────────────────────────────────────────────────────

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
