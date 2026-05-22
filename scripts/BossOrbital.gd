extends CharacterBody2D

## Orbital Strike Boss
## ──────────────────
## A slow, armored boss that stays at range and bombards the arena
## with telegraphed orbital strikes. Becomes more aggressive as its
## health drops, firing multiple strikes in quick succession.
##
## SETUP:
## 1. Add this script to a CharacterBody2D scene
## 2. Add children: AnimatedSprite2D, CollisionShape2D, HealthComponent,
##    StatusEffectComponent, ArmorComponent
## 3. Assign the scene to WaveManager's boss_scenes array

# ── Movement ──────────────────────────────────────────────────────────

## How slowly the boss drifts toward the player between attacks.
## Kept intentionally low so the boss feels like an artillery platform.
@export var move_speed: float = 22.0

## The boss stops moving when this close to the player.
## Stays at range so orbital strikes remain threatening.
@export var stop_distance: float = 220.0

# ── Attack Timing ─────────────────────────────────────────────────────

## Seconds between attack sequences at full health (phase 1).
@export var cooldown_phase1: float = 6.0

## Seconds between attack sequences at phase 2 (below 66% HP).
@export var cooldown_phase2: float = 4.5

## Seconds between attack sequences at phase 3 (below 33% HP).
@export var cooldown_phase3: float = 3.0

## How long the floor telegraph warning displays before the strike fires.
## Players have this long to move out of the inner zone.
@export var telegraph_duration: float = 2.5

# ── Strike Configuration ───────────────────────────────────────────────

## Instant-kill zone radius at the center of the strike.
@export var inner_radius: float = 60.0

## Full danger area radius. Damage falls off from inner to outer edge.
@export var outer_radius: float = 140.0

## Maximum damage dealt at the very center of the strike.
@export var strike_damage: float = 120.0

## Number of radial shards fired after impact in phase 1.
@export var shard_count_phase1: int = 16

## Shard count in phase 2.
@export var shard_count_phase2: int = 24

## Shard count in phase 3 — fills the arena with danger.
@export var shard_count_phase3: int = 32

## How fast shards travel in pixels per second.
@export var shard_speed: float = 210.0

## Shard speed multiplier in phase 3. Makes final phase feel desperate.
@export var shard_speed_phase3_mult: float = 1.4

## Damage each shard deals on contact with the player.
@export var shard_damage: float = 35.0

## How many strikes fire in sequence in phase 2.
@export var strikes_phase2: int = 2

## How many strikes fire in sequence in phase 3.
@export var strikes_phase3: int = 3

## Delay between individual strikes in a multi-strike sequence.
@export var multi_strike_delay: float = 1.2

# ── Node References ────────────────────────────────────────────────────

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var collision: CollisionShape2D       = $CollisionShape2D

# ── Internal State ─────────────────────────────────────────────────────
enum Phase { ONE, TWO, THREE }

var target: Node2D   = null
var _phase: Phase    = Phase.ONE
var _attacking: bool = false
var _cooldown: float = 0.0
var _charge_tween: Tween = null


func _ready() -> void:
	health_component.died.connect(_on_died)
	health_component.damaged.connect(_on_damaged)
	_acquire_target()
	add_to_group("enemies")
	_cooldown = 3.0

	# Spawn the same screen-wide boss health bar used by PhantomBoss
	var boss_bar := BossHealthBarUI.new()
	boss_bar.setup("Orbital Cannon", health_component)
	get_tree().current_scene.add_child.call_deferred(boss_bar)


func _physics_process(delta: float) -> void:
	if health_component.is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not is_instance_valid(target):
		_acquire_target()

	_update_phase()

	if not _attacking:
		_drift_toward_target()
		_cooldown -= delta
		if _cooldown <= 0.0:
			_start_attack_sequence()

	move_and_slide()

# ══════════════════════════════════════════════════════════════════════
# PHASE MANAGEMENT
# ══════════════════════════════════════════════════════════════════════

func _update_phase() -> void:
	var pct: float = float(health_component.current_health) / float(health_component.max_health)
	var new_phase: Phase

	if pct > 0.66:
		new_phase = Phase.ONE
	elif pct > 0.33:
		new_phase = Phase.TWO
	else:
		new_phase = Phase.THREE

	if new_phase != _phase:
		_phase = new_phase
		_on_phase_changed()


func _on_phase_changed() -> void:
	## Visual flash when the boss enters a new phase
	if animated_sprite:
		var t := create_tween()
		t.tween_property(animated_sprite, "modulate", Color(2.0, 0.5, 0.5), 0.1)
		t.tween_property(animated_sprite, "modulate", _phase_tint(), 0.4)


func _phase_tint() -> Color:
	match _phase:
		Phase.TWO:   return Color(1.3, 0.8, 0.6)   # Warm orange — getting angry
		Phase.THREE: return Color(1.5, 0.5, 0.5)   # Red — enraged
		_:           return Color.WHITE


func _current_cooldown() -> float:
	match _phase:
		Phase.TWO:   return cooldown_phase2
		Phase.THREE: return cooldown_phase3
		_:           return cooldown_phase1


func _current_strike_count() -> int:
	match _phase:
		Phase.TWO:   return strikes_phase2
		Phase.THREE: return strikes_phase3
		_:           return 1


func _current_shard_count() -> int:
	match _phase:
		Phase.TWO:   return shard_count_phase2
		Phase.THREE: return shard_count_phase3
		_:           return shard_count_phase1


func _current_shard_speed() -> float:
	if _phase == Phase.THREE:
		return shard_speed * shard_speed_phase3_mult
	return shard_speed

# ══════════════════════════════════════════════════════════════════════
# MOVEMENT
# ══════════════════════════════════════════════════════════════════════

func _drift_toward_target() -> void:
	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		return
	var dist: float = global_position.distance_to(target.global_position)
	if dist > stop_distance:
		velocity = global_position.direction_to(target.global_position) * move_speed
	else:
		velocity = Vector2.ZERO

# ══════════════════════════════════════════════════════════════════════
# ATTACK SEQUENCE
# ══════════════════════════════════════════════════════════════════════

func _start_attack_sequence() -> void:
	if _attacking:
		return
	_attacking = true
	velocity   = Vector2.ZERO

	# Charge-up visual on the boss itself
	_play_charge_animation()

	# Brief pause so the charge animation reads before the warning appears
	await get_tree().create_timer(0.6).timeout

	# Fire N strikes depending on phase
	var strike_count: int = _current_strike_count()
	for i in strike_count:
		if not is_instance_valid(self) or health_component.is_dead:
			break
		await _fire_single_strike()
		if i < strike_count - 1:
			await get_tree().create_timer(multi_strike_delay).timeout

	_attacking = false
	_cooldown  = _current_cooldown()


func _fire_single_strike() -> void:
	if not is_instance_valid(target):
		return

	## Pick the target position now — player must move before the ring closes
	var strike_pos: Vector2 = target.global_position

	# Spawn the floor telegraph
	var warning := OrbitalWarning.new()
	warning.global_position    = strike_pos
	warning.duration           = telegraph_duration
	warning.inner_radius       = inner_radius
	warning.outer_radius       = outer_radius
	get_tree().current_scene.add_child(warning)

	# Wait for the telegraph to complete, then execute damage
	await warning.warning_complete

	if not is_instance_valid(self):
		return

	_execute_strike(strike_pos)


func _execute_strike(pos: Vector2) -> void:
	## Deal radial damage to the player and nearby enemies at the impact point

	# ── Player damage ──────────────────────────────────────────────────
	var players := get_tree().get_nodes_in_group("player")
	for player in players:
		if not is_instance_valid(player):
			continue
		var dist: float = pos.distance_to(player.global_position)
		var dmg: float = 0.0
		if dist <= inner_radius:
			dmg = strike_damage
		elif dist <= outer_radius:
			var falloff: float = 1.0 - ((dist - inner_radius) / (outer_radius - inner_radius))
			dmg = strike_damage * falloff * 0.6
		if dmg > 0.0:
			var hc := player.get_node_or_null("HealthComponent")
			if hc and hc.has_method("take_damage"):
				hc.take_damage(dmg, "physical")
			DamageNumber.spawn(get_tree().current_scene, player.global_position, dmg, Color(1.0, 0.3, 0.1))

	# ── Enemy damage — orbital strike doesn't discriminate ─────────────
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy == self:
			continue
		var dist: float = pos.distance_to(enemy.global_position)
		var dmg: float = 0.0
		if dist <= inner_radius:
			dmg = strike_damage
		elif dist <= outer_radius:
			var falloff: float = 1.0 - ((dist - inner_radius) / (outer_radius - inner_radius))
			dmg = strike_damage * falloff * 0.6
		if dmg > 0.0:
			var hc := enemy.get_node_or_null("HealthComponent")
			if hc and hc.has_method("take_damage"):
				hc.take_damage(dmg, "combo")  # Combo bypasses shields on enemies
			DamageNumber.spawn(get_tree().current_scene, enemy.global_position, dmg, Color(1.0, 0.5, 0.1))

	_spawn_shards(pos)
	_play_impact_flash(pos)


func _spawn_shards(pos: Vector2) -> void:
	## Fire shards evenly distributed around 360 degrees
	var count: int    = _current_shard_count()
	var spd: float    = _current_shard_speed()
	var angle_step: float = TAU / float(count)

	## Slight random rotation so shards don't always align with axes
	var base_angle: float = randf() * angle_step

	for i in count:
		var angle: float   = base_angle + i * angle_step
		var dir: Vector2   = Vector2(cos(angle), sin(angle))
		var shard: OrbitalShard = OrbitalShard.create(dir, spd, shard_damage)
		shard.global_position   = pos
		get_tree().current_scene.add_child(shard)

# ══════════════════════════════════════════════════════════════════════
# VISUALS
# ══════════════════════════════════════════════════════════════════════

func _play_charge_animation() -> void:
	if animated_sprite == null:
		return
	if _charge_tween and _charge_tween.is_valid():
		_charge_tween.kill()
	_charge_tween = create_tween().set_loops(3)
	_charge_tween.tween_property(animated_sprite, "modulate", Color(1.5, 1.0, 0.3), 0.2)
	_charge_tween.tween_property(animated_sprite, "modulate", _phase_tint(),         0.2)


func _play_impact_flash(pos: Vector2) -> void:
	## Spawn a brief white flash at the impact point
	var flash := Node2D.new()
	flash.global_position = pos
	flash.z_index         = 10
	get_tree().current_scene.add_child(flash)
	var t := flash.create_tween()
	t.tween_interval(0.1)
	t.tween_callback(flash.queue_free)

# ══════════════════════════════════════════════════════════════════════
# DEATH
# ══════════════════════════════════════════════════════════════════════

func _on_damaged(_amount: int) -> void:
	## Brief red flash when hit — gives hit confirmation feedback
	if animated_sprite:
		var t := create_tween()
		t.tween_property(animated_sprite, "modulate", Color(2.0, 0.4, 0.4), 0.05)
		t.tween_property(animated_sprite, "modulate", _phase_tint(),         0.2)


func _on_died() -> void:
	target   = null
	velocity = Vector2.ZERO
	collision.set_deferred("disabled", true)

	if has_node("Hurtbox"):
		$Hurtbox.set_deferred("monitoring",  false)
		$Hurtbox.set_deferred("monitorable", false)

	if animated_sprite and animated_sprite.sprite_frames != null:
		if animated_sprite.sprite_frames.has_animation("death"):
			animated_sprite.play("death")
			await animated_sprite.animation_finished
		else:
			hide()
	else:
		hide()

	queue_free()


func _acquire_target() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target = players[0] as Node2D


## Called by WaveManager to assign the player target directly
func set_target(new_target: Node2D) -> void:
	target = new_target


## Called by WaveManager to scale gold drops with wave number
func set_gold_multiplier(_mult: float) -> void:
	pass  # Boss drops handled separately — override if needed
