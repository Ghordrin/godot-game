extends CharacterBody2D

## Orbital Strike Boss

@export var move_speed: float = 22.0
@export var stop_distance: float = 220.0

@export var cooldown_phase1: float = 6.0
@export var cooldown_phase2: float = 4.5
@export var cooldown_phase3: float = 3.0
@export var telegraph_duration: float = 2.5

@export var inner_radius: float = 60.0
@export var outer_radius: float = 140.0
@export var strike_damage: float = 120.0

@export var shard_count_phase1: int = 16
@export var shard_count_phase2: int = 24
@export var shard_count_phase3: int = 32
@export var shard_speed: float = 210.0
@export var shard_speed_phase3_mult: float = 1.4
@export var shard_damage: float = 35.0

@export var strikes_phase2: int = 2
@export var strikes_phase3: int = 3
@export var multi_strike_delay: float = 1.2

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var collision: CollisionShape2D = $CollisionShape2D

enum Phase { ONE, TWO, THREE }

var target: Node2D = null
var _phase: Phase = Phase.ONE
var _attacking: bool = false
var _cooldown: float = 0.0
var _charge_tween: Tween = null


func _ready() -> void:
	health_component.died.connect(_on_died)
	health_component.damaged.connect(_on_damaged)
	_acquire_target()
	add_to_group("enemies")
	_cooldown = 3.0

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
	if animated_sprite:
		var t := create_tween()
		t.tween_property(animated_sprite, "modulate", Color(2.0, 0.5, 0.5), 0.1)
		t.tween_property(animated_sprite, "modulate", _phase_tint(), 0.4)


func _phase_tint() -> Color:
	match _phase:
		Phase.TWO:
			return Color(1.3, 0.8, 0.6)
		Phase.THREE:
			return Color(1.5, 0.5, 0.5)
		_:
			return Color.WHITE


func _current_cooldown() -> float:
	match _phase:
		Phase.TWO:
			return cooldown_phase2
		Phase.THREE:
			return cooldown_phase3
		_:
			return cooldown_phase1


func _current_strike_count() -> int:
	match _phase:
		Phase.TWO:
			return strikes_phase2
		Phase.THREE:
			return strikes_phase3
		_:
			return 1


func _current_shard_count() -> int:
	match _phase:
		Phase.TWO:
			return shard_count_phase2
		Phase.THREE:
			return shard_count_phase3
		_:
			return shard_count_phase1


func _current_shard_speed() -> float:
	if _phase == Phase.THREE:
		return shard_speed * shard_speed_phase3_mult
	return shard_speed


func _drift_toward_target() -> void:
	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		return

	var dist: float = global_position.distance_to(target.global_position)

	if dist > stop_distance:
		velocity = global_position.direction_to(target.global_position) * move_speed
	else:
		velocity = Vector2.ZERO


func _start_attack_sequence() -> void:
	if _attacking:
		return

	_attacking = true
	velocity = Vector2.ZERO

	_play_charge_animation()

	await get_tree().create_timer(0.6).timeout

	var strike_count: int = _current_strike_count()

	for i in strike_count:
		if not is_instance_valid(self) or health_component.is_dead:
			break

		await _fire_single_strike()

		if i < strike_count - 1:
			await get_tree().create_timer(multi_strike_delay).timeout

	_attacking = false
	_cooldown = _current_cooldown()


func _fire_single_strike() -> void:
	if not is_instance_valid(target):
		return

	var strike_pos: Vector2 = target.global_position

	var warning := OrbitalWarning.new()
	warning.global_position = strike_pos
	warning.duration = telegraph_duration
	warning.inner_radius = inner_radius
	warning.outer_radius = outer_radius
	get_tree().current_scene.add_child(warning)

	await warning.warning_complete

	if not is_instance_valid(self):
		return

	_execute_strike(strike_pos)


func _execute_strike(pos: Vector2) -> void:
	_apply_strike_to_players(pos)
	_apply_strike_to_enemies(pos)
	_spawn_shards(pos)
	_play_impact_flash(pos)


func _apply_strike_to_players(pos: Vector2) -> void:
	for player in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(player):
			continue

		var dmg: float = _calculate_strike_damage(pos, player.global_position)
		if dmg <= 0.0:
			continue

		var hc := player.get_node_or_null("HealthComponent")
		if hc and hc.has_method("take_damage"):
			hc.take_damage(dmg, "physical")

		DamageNumberSpawner.spawn(
			player.global_position,
			dmg,
			DamageVisuals.get_display_name("physical"),
			DamageVisuals.get_color("physical"),
			0,
			false
		)


func _apply_strike_to_enemies(pos: Vector2) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy == self:
			continue

		var dmg: float = _calculate_strike_damage(pos, enemy.global_position)
		if dmg <= 0.0:
			continue

		var hc := enemy.get_node_or_null("HealthComponent")
		if hc and hc.has_method("take_damage"):
			hc.take_damage(dmg, "combo")

		DamageNumberSpawner.spawn(
			enemy.global_position,
			dmg,
			DamageVisuals.get_display_name("combo"),
			DamageVisuals.get_color("combo"),
			0,
			false
		)


func _calculate_strike_damage(strike_pos: Vector2, victim_pos: Vector2) -> float:
	var dist: float = strike_pos.distance_to(victim_pos)

	if dist <= inner_radius:
		return strike_damage

	if dist <= outer_radius:
		var falloff: float = 1.0 - ((dist - inner_radius) / (outer_radius - inner_radius))
		return strike_damage * falloff * 0.6

	return 0.0


func _spawn_shards(pos: Vector2) -> void:
	var count: int = _current_shard_count()
	var spd: float = _current_shard_speed()
	var angle_step: float = TAU / float(count)
	var base_angle: float = randf() * angle_step

	for i in count:
		var angle: float = base_angle + i * angle_step
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		var shard: OrbitalShard = OrbitalShard.create(dir, spd, shard_damage)
		shard.global_position = pos
		get_tree().current_scene.add_child(shard)


func _play_charge_animation() -> void:
	if animated_sprite == null:
		return

	if _charge_tween and _charge_tween.is_valid():
		_charge_tween.kill()

	_charge_tween = create_tween().set_loops(3)
	_charge_tween.tween_property(animated_sprite, "modulate", Color(1.5, 1.0, 0.3), 0.2)
	_charge_tween.tween_property(animated_sprite, "modulate", _phase_tint(), 0.2)


func _play_impact_flash(pos: Vector2) -> void:
	var flash := Node2D.new()
	flash.global_position = pos
	flash.z_index = 10
	get_tree().current_scene.add_child(flash)

	var t := flash.create_tween()
	t.tween_interval(0.1)
	t.tween_callback(flash.queue_free)


func _on_damaged(_amount: int) -> void:
	if animated_sprite:
		var t := create_tween()
		t.tween_property(animated_sprite, "modulate", Color(2.0, 0.4, 0.4), 0.05)
		t.tween_property(animated_sprite, "modulate", _phase_tint(), 0.2)


func _on_died() -> void:
	target = null
	velocity = Vector2.ZERO
	collision.set_deferred("disabled", true)

	if has_node("Hurtbox"):
		$Hurtbox.set_deferred("monitoring", false)
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


func set_target(new_target: Node2D) -> void:
	target = new_target


func set_gold_multiplier(_mult: float) -> void:
	pass
