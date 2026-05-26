extends CharacterBody2D
class_name ScrapMaw

## ScrapMaw Boss
## A salvaged war mech repurposed for hunting.
## Three phases — grows more erratic as it takes damage.
## Every attack has a clear dash window so the player is rewarded for reading tells.

# ══════════════════════════════════════════════════════════════════════
# IDENTITY / MOVEMENT
# ══════════════════════════════════════════════════════════════════════

@export var boss_name: String = "Scrapmaw"
@export var move_speed_phase1: float = 95.0
@export var move_speed_phase2: float = 125.0
@export var move_speed_phase3: float = 120.0
@export var stop_distance: float = 52.0

# ══════════════════════════════════════════════════════════════════════
# ATTACK TIMING
# ══════════════════════════════════════════════════════════════════════

@export var attack_cooldown_phase1: float = 1.6
@export var attack_cooldown_phase2: float = 1.25
@export var attack_cooldown_phase3: float = 1.4
@export var initial_attack_delay: float = 1.4

# ══════════════════════════════════════════════════════════════════════
# ATTACK: DRILL CHARGE (Phase 1+)
# ══════════════════════════════════════════════════════════════════════

@export var charge_windup: float = 0.75
@export var charge_speed: float = 440.0
@export var charge_distance: float = 360.0
@export var charge_damage: int = 22
@export var charge_impact_count: int = 8
@export var charge_impact_speed: float = 115.0

# ══════════════════════════════════════════════════════════════════════
# ATTACK: CLAW SWEEP (Phase 1+)
# ══════════════════════════════════════════════════════════════════════

@export var sweep_projectile_count: int = 22
@export var sweep_gap_degrees: float = 85.0
@export var sweep_speed: float = 155.0
@export var sweep_damage: int = 14

# ══════════════════════════════════════════════════════════════════════
# ATTACK: SHRAPNEL BURST (Phase 1+)
# ══════════════════════════════════════════════════════════════════════

@export var burst_count: int = 9
@export var burst_spread_deg: float = 60.0
@export var burst_speed: float = 205.0
@export var burst_damage: int = 12

# ══════════════════════════════════════════════════════════════════════
# ATTACK: BLADE SPIRAL (Phase 2+)
# ══════════════════════════════════════════════════════════════════════

@export var spiral_count: int = 30
@export var spiral_rotations: float = 2.2
@export var spiral_interval: float = 0.042
@export var spiral_speed: float = 148.0
@export var spiral_damage: int = 10
@export var spiral_gap_degrees: float = 58.0

# ══════════════════════════════════════════════════════════════════════
# ATTACK: MINE SCATTER (Phase 2+)
# ══════════════════════════════════════════════════════════════════════

@export var mine_count: int = 10
@export var mine_scatter_radius: float = 260.0
@export var mine_land_delay_min: float = 0.5
@export var mine_land_delay_max: float = 1.3
@export var debris_damage: int = 18
@export var debris_radius: float = 26.0
@export var debris_lifetime: float = 2.5

# ══════════════════════════════════════════════════════════════════════
# ATTACK: MAGNETIC PULL (Phase 3)
# ══════════════════════════════════════════════════════════════════════

@export var pull_duration: float = 0.38
@export var pull_strength: float = 290.0
@export var pull_blast_damage: int = 38
@export var pull_blast_radius: float = 85.0
@export var pull_blast_delay: float = 0.52

# ══════════════════════════════════════════════════════════════════════
# ATTACK: BLADE FRENZY (Phase 3)
# ══════════════════════════════════════════════════════════════════════

@export var frenzy_dash_count: int = 6
@export var frenzy_dash_speed: float = 540.0
@export var frenzy_trail_damage: int = 12
@export var frenzy_trail_radius: float = 26.0
@export var frenzy_trail_lifetime: float = 0.65
@export var frenzy_dash_interval: float = 0.16

# ══════════════════════════════════════════════════════════════════════
# ATTACK: SCRAP NOVA (Phase 3)
# ══════════════════════════════════════════════════════════════════════

@export var nova_count: int = 32
@export var nova_gap_count: int = 3
@export var nova_gap_degrees: float = 32.0
@export var nova_speed: float = 200.0
@export var nova_damage: int = 16

# ══════════════════════════════════════════════════════════════════════
# PROJECTILE
# ══════════════════════════════════════════════════════════════════════

@export var boss_projectile_scene: PackedScene

# ══════════════════════════════════════════════════════════════════════
# LOOT
# ══════════════════════════════════════════════════════════════════════

@export var loot_table: PowerUpTable
@export var loot_item_scene: PackedScene
@export var gold_pickup_scene: PackedScene

@export var min_gold_drop: int = 25
@export var max_gold_drop: int = 55
@export var gold_pile_count_min: int = 4
@export var gold_pile_count_max: int = 7
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
# STATE
# ══════════════════════════════════════════════════════════════════════

enum Phase { ONE, TWO, THREE }

var _phase: Phase = Phase.ONE
var _move_speed: float = 0.0
var target: Node2D = null
var _boss_bar: BossHealthBarUI = null
var _is_dying: bool = false
var _attacking: bool = false
var _phase_triggered: Dictionary = { Phase.TWO: false, Phase.THREE: false }
var _last_direction: Vector2 = Vector2.DOWN


func _ready() -> void:
	_move_speed = move_speed_phase1

	health_component.died.connect(_on_died)

	_acquire_target()
	add_to_group("enemies")
	add_to_group("bosses")

	_boss_bar = BossHealthBarUI.new()
	_boss_bar.setup(boss_name, health_component)
	get_tree().current_scene.add_child.call_deferred(_boss_bar)

	_start_fight_loop()


func _physics_process(_delta: float) -> void:
	if health_component.is_dead or _is_dying:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not is_instance_valid(target):
		_acquire_target()

	_check_phase_transition()

	if not _attacking:
		_chase_target()

	move_and_slide()


# ══════════════════════════════════════════════════════════════════════
# MANAGER API
# ══════════════════════════════════════════════════════════════════════

func set_target(new_target: Node2D) -> void:
	target = new_target


func set_gold_multiplier(_mult: float) -> void:
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


func _chase_target() -> void:
	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		return

	var dist := global_position.distance_to(target.global_position)

	if dist > stop_distance:
		var dir := global_position.direction_to(target.global_position)
		velocity = dir * _move_speed
		_update_animation(dir)
	else:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)


func _update_animation(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		_last_direction = direction

	animated_sprite.flip_h = false

	var anim: String
	if direction == Vector2.ZERO:
		anim = "idle_down" if _last_direction.y >= 0.0 else "idle_up"
	else:
		var walk_x := direction.x if direction.x != 0.0 else _last_direction.x
		anim = "walk_right" if walk_x >= 0.0 else "walk_left"

	_play_anim(anim)


func _play_attack_anim(direction: Vector2) -> void:
	if direction == Vector2.ZERO or animated_sprite == null:
		return

	if direction.y < 0.0 and absf(direction.y) >= absf(direction.x):
		animated_sprite.flip_h = false
		_play_anim("attack_up")
	else:
		animated_sprite.flip_h = direction.x > 0.0
		_play_anim("attack_left")


func _play_anim(anim: String) -> void:
	if animated_sprite == null:
		return
	if animated_sprite.animation == anim and animated_sprite.is_playing():
		return
	AnimationHelper.play_if_exists(animated_sprite, anim)


# ══════════════════════════════════════════════════════════════════════
# PHASE TRANSITIONS
# ══════════════════════════════════════════════════════════════════════

func _check_phase_transition() -> void:
	if health_component.max_health <= 0 or _is_dying:
		return

	var pct := float(health_component.current_health) / float(health_component.max_health)

	if pct <= 0.30 and not _phase_triggered[Phase.THREE]:
		_phase_triggered[Phase.THREE] = true
		_transition_to(Phase.THREE)
	elif pct <= 0.65 and not _phase_triggered[Phase.TWO]:
		_phase_triggered[Phase.TWO] = true
		_transition_to(Phase.TWO)


func _transition_to(new_phase: Phase) -> void:
	_phase = new_phase

	match new_phase:
		Phase.TWO:
			_move_speed = move_speed_phase2
			_flash_phase_change(Color(1.3, 0.6, 0.15))

		Phase.THREE:
			_move_speed = move_speed_phase3
			_expose_core()
			_flash_phase_change(Color(2.0, 0.25, 0.25))


func _expose_core() -> void:
	# Shrink and recolour the body sprite to signal the core-exposed state
	var tween := animated_sprite.create_tween().set_parallel(true)
	tween.tween_property(animated_sprite, "scale", Vector2(0.62, 0.62), 0.45)
	tween.tween_property(animated_sprite, "modulate", Color(1.65, 0.3, 0.3), 0.45)


func _flash_phase_change(color: Color) -> void:
	if not is_instance_valid(animated_sprite):
		return
	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", color, 0.07)
	tween.tween_interval(0.12)
	tween.tween_property(animated_sprite, "modulate", _phase_modulate(), 0.28)


func _phase_modulate() -> Color:
	match _phase:
		Phase.TWO:   return Color(1.2, 0.75, 0.4)
		Phase.THREE: return Color(1.65, 0.3, 0.3)
		_:           return Color.WHITE


# ══════════════════════════════════════════════════════════════════════
# FIGHT LOOP
# ══════════════════════════════════════════════════════════════════════

func _start_fight_loop() -> void:
	await get_tree().create_timer(initial_attack_delay).timeout
	_fight_loop()


func _fight_loop() -> void:
	while not health_component.is_dead and not _is_dying:
		if not is_instance_valid(target):
			_acquire_target()
			await get_tree().create_timer(0.2).timeout
			continue

		_attacking = true
		velocity = Vector2.ZERO

		await _execute_attack(_pick_attack())

		if _is_dead_or_dying():
			return

		_attacking = false

		await get_tree().create_timer(_current_cooldown()).timeout


func _pick_attack() -> int:
	match _phase:
		Phase.ONE:
			return [0, 1, 2].pick_random()       # Charge, Sweep, Burst
		Phase.TWO:
			return [0, 1, 3, 4].pick_random()    # + Spiral, Debris
		Phase.THREE:
			return [5, 6, 7].pick_random()        # Pull, Frenzy, Nova
		_:
			return 0


func _execute_attack(id: int) -> void:
	match id:
		0: await _attack_drill_charge()
		1: await _attack_claw_sweep()
		2: await _attack_shrapnel_burst()
		3: await _attack_blade_spiral()
		4: await _attack_debris_field()
		5: await _attack_magnetic_pull()
		6: await _attack_blade_frenzy()
		7: await _attack_scrap_nova()


func _current_cooldown() -> float:
	match _phase:
		Phase.TWO:   return attack_cooldown_phase2
		Phase.THREE: return attack_cooldown_phase3
		_:           return attack_cooldown_phase1


# ══════════════════════════════════════════════════════════════════════
# ATTACK: DRILL CHARGE
# Telegraphed straight lunge — dash sideways to avoid.
# ══════════════════════════════════════════════════════════════════════

func _attack_drill_charge() -> void:
	if not is_instance_valid(target):
		return

	# Lock direction at the start of the windup so the player can read it
	var aim_dir := global_position.direction_to(target.global_position).normalized()

	await _telegraph(Color(1.0, 0.48, 0.08), charge_windup)

	if _is_dead_or_dying():
		return

	var traveled := 0.0

	while traveled < charge_distance and not _is_dead_or_dying():
		var delta := get_physics_process_delta_time()
		traveled += charge_speed * delta
		velocity = aim_dir * charge_speed
		await get_tree().process_frame

	velocity = Vector2.ZERO
	_fire_ring(charge_impact_count, charge_impact_speed, charge_damage, 0.0)


# ══════════════════════════════════════════════════════════════════════
# ATTACK: CLAW SWEEP
# 270° arc with one gap facing the player — dash into the gap.
# ══════════════════════════════════════════════════════════════════════

func _attack_claw_sweep() -> void:
	await _telegraph(Color(0.9, 0.15, 0.15), 0.52)

	if _is_dead_or_dying():
		return

	# Gap always opens toward the player so there is a guaranteed escape route
	var gap_angle := global_position.angle_to_point(target.global_position) if is_instance_valid(target) else 0.0
	var gap_half := deg_to_rad(sweep_gap_degrees * 0.5)
	var angle_step := TAU / float(sweep_projectile_count)

	for i in sweep_projectile_count:
		var angle := float(i) * angle_step
		if absf(wrapf(angle - gap_angle, -PI, PI)) < gap_half:
			continue
		_fire_projectile(Vector2(cos(angle), sin(angle)), sweep_speed, sweep_damage)


# ══════════════════════════════════════════════════════════════════════
# ATTACK: SHRAPNEL BURST
# Wide spread aimed at the player — dash sideways through the gaps.
# ══════════════════════════════════════════════════════════════════════

func _attack_shrapnel_burst() -> void:
	if not is_instance_valid(target):
		return

	await _telegraph(Color(1.0, 0.75, 0.1), 0.42)

	if _is_dead_or_dying():
		return

	var aim_dir := global_position.direction_to(target.global_position)
	var half := deg_to_rad(burst_spread_deg * 0.5)
	var step := deg_to_rad(burst_spread_deg) / float(maxi(1, burst_count - 1))

	for i in burst_count:
		_fire_projectile(aim_dir.rotated(-half + step * float(i)), burst_speed, burst_damage)


# ══════════════════════════════════════════════════════════════════════
# ATTACK: BLADE SPIRAL (Phase 2)
# Rotating spiral with a moving gap — chase the gap with a dash.
# ══════════════════════════════════════════════════════════════════════

func _attack_blade_spiral() -> void:
	await _telegraph(Color(0.75, 0.2, 1.0), 0.48)

	if _is_dead_or_dying():
		return

	var gap_start := randf() * TAU
	var gap_half := deg_to_rad(spiral_gap_degrees * 0.5)

	for i in spiral_count:
		if _is_dead_or_dying():
			return

		var angle := (float(i) / float(spiral_count)) * TAU * spiral_rotations

		if absf(wrapf(angle - gap_start, -PI, PI)) > gap_half:
			_fire_projectile(Vector2(cos(angle), sin(angle)), spiral_speed, spiral_damage)

		await get_tree().create_timer(spiral_interval).timeout


# ══════════════════════════════════════════════════════════════════════
# ATTACK: MINE SCATTER (Phase 2)
# Fires a volley of mines outward — warning rings mark landing spots.
# Mines slam down and explode on contact or expire after their lifetime.
# ══════════════════════════════════════════════════════════════════════

func _attack_debris_field() -> void:
	await _telegraph(Color(0.9, 0.6, 0.05), 0.65)

	if _is_dead_or_dying():
		return

	for i in mine_count:
		if _is_dead_or_dying():
			return

		var angle := (float(i) / float(mine_count)) * TAU + randf_range(-0.28, 0.28)
		var dist := randf_range(mine_scatter_radius * 0.35, mine_scatter_radius)
		var landing := global_position + Vector2(cos(angle), sin(angle)) * dist
		var delay := randf_range(mine_land_delay_min, mine_land_delay_max)

		_spawn_scatter_mine(landing, delay)

		await get_tree().create_timer(0.07).timeout


func _spawn_scatter_mine(landing_pos: Vector2, delay: float) -> void:
	var warn := Node2D.new()
	warn.global_position = landing_pos
	get_tree().current_scene.add_child(warn)

	var warn_sprite := Sprite2D.new()
	warn_sprite.texture = _create_circle_texture(int(debris_radius * 1.5), Color(1.0, 0.3, 0.0, 0.55))
	warn.add_child(warn_sprite)

	var pulse := warn.create_tween().set_loops()
	pulse.tween_property(warn_sprite, "scale", Vector2(1.22, 1.22), 0.22)
	pulse.tween_property(warn_sprite, "scale", Vector2(0.82, 0.82), 0.22)

	await get_tree().create_timer(delay).timeout
	warn.queue_free()

	if _is_dead_or_dying():
		return

	_spawn_active_mine(landing_pos)


func _spawn_active_mine(pos: Vector2) -> void:
	var mine := Area2D.new()
	mine.global_position = pos
	mine.add_to_group("hazards")
	mine.add_to_group("wave_cleanup")
	mine.collision_layer = 0
	mine.collision_mask = 1

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = debris_radius
	shape.shape = circle
	mine.add_child(shape)

	var body_sprite := Sprite2D.new()
	body_sprite.texture = _create_circle_texture(int(debris_radius), Color(1.0, 0.55, 0.0, 1.0))
	mine.add_child(body_sprite)

	var label := Label.new()
	label.text = "M"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.BLACK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(debris_radius * 2.0, debris_radius * 2.0)
	label.position = Vector2(-debris_radius, -debris_radius)
	mine.add_child(label)

	get_tree().current_scene.add_child(mine)

	mine.scale = Vector2(0.05, 0.05)
	var land := mine.create_tween()
	land.tween_property(mine, "scale", Vector2(1.25, 1.25), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	land.tween_property(mine, "scale", Vector2(1.0, 1.0), 0.08)

	mine.body_entered.connect(func(body_node: Node) -> void:
		if not body_node.is_in_group("player"):
			return
		_detonate_mine(mine, pos)
	)

	var expire := mine.create_tween()
	expire.tween_interval(debris_lifetime - 0.5)
	expire.tween_property(body_sprite, "modulate:a", 0.0, 0.5)
	expire.tween_callback(mine.queue_free)


func _detonate_mine(mine: Node, pos: Vector2) -> void:
	if is_instance_valid(mine):
		mine.queue_free()

	for player in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(player):
			continue
		if (player as Node2D).global_position.distance_to(pos) > debris_radius * 2.5:
			continue
		var hc := player.get_node_or_null("HealthComponent")
		if hc and hc.has_method("take_damage"):
			hc.take_damage(debris_damage, "physical")

	var exp := Node2D.new()
	exp.global_position = pos
	get_tree().current_scene.add_child(exp)

	var ring := Sprite2D.new()
	ring.texture = _create_circle_texture(int(debris_radius), Color(1.0, 0.75, 0.1, 0.95))
	exp.add_child(ring)

	var exp_tween := exp.create_tween().set_parallel(true)
	exp_tween.tween_property(exp, "scale", Vector2(3.5, 3.5), 0.35).set_ease(Tween.EASE_OUT)
	exp_tween.tween_property(ring, "modulate:a", 0.0, 0.35)
	exp_tween.chain().tween_callback(exp.queue_free)


# ══════════════════════════════════════════════════════════════════════
# ATTACK: MAGNETIC PULL (Phase 3)
# Yanks the player in — a detonation fires at the pull origin shortly
# after, so the player must dash away immediately after being pulled.
# ══════════════════════════════════════════════════════════════════════

func _attack_magnetic_pull() -> void:
	if not is_instance_valid(target):
		return

	await _telegraph(Color(0.25, 0.65, 1.0), 0.55)

	if _is_dead_or_dying() or not is_instance_valid(target):
		return

	var blast_origin := target.global_position
	var elapsed := 0.0

	while elapsed < pull_duration and not _is_dead_or_dying() and is_instance_valid(target):
		var delta := get_physics_process_delta_time()
		elapsed += delta
		var pull_dir := target.global_position.direction_to(global_position)
		target.global_position += pull_dir * pull_strength * delta
		await get_tree().process_frame

	# Brief window for the player to dash before the blast
	await get_tree().create_timer(pull_blast_delay).timeout

	if _is_dead_or_dying():
		return

	_detonate_pull_blast(blast_origin)


func _detonate_pull_blast(pos: Vector2) -> void:
	for player in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(player) or not player is Node2D:
			continue
		if (player as Node2D).global_position.distance_to(pos) > pull_blast_radius:
			continue
		var hc := player.get_node_or_null("HealthComponent")
		if hc and hc.has_method("take_damage"):
			hc.take_damage(pull_blast_damage, "physical")

	# Outward shrapnel ring from the blast point
	_fire_ring_from(pos, 10, 170.0, pull_blast_damage / 2, 0.0)


# ══════════════════════════════════════════════════════════════════════
# ATTACK: BLADE FRENZY (Phase 3)
# Boss dashes around the arena rapidly, leaving brief hazard trails.
# Read the trajectory and dash away from each landing spot.
# ══════════════════════════════════════════════════════════════════════

func _attack_blade_frenzy() -> void:
	await _telegraph(Color(1.0, 0.08, 0.08), 0.32)

	if _is_dead_or_dying():
		return

	for _i in frenzy_dash_count:
		if _is_dead_or_dying():
			return

		_spawn_trail_hazard(global_position)

		var dest := _frenzy_pick_destination()
		var dist := global_position.distance_to(dest)
		var travel_time := dist / frenzy_dash_speed

		# Tween position directly — velocity stays zero so move_and_slide is a no-op
		var tween := create_tween()
		tween.tween_property(self, "global_position", dest, travel_time)
		await tween.finished

		_fire_ring(6, 135.0, frenzy_trail_damage, randf() * TAU)

		await get_tree().create_timer(frenzy_dash_interval).timeout


func _frenzy_pick_destination() -> Vector2:
	if is_instance_valid(target):
		var angle := randf() * TAU
		var dist := randf_range(55.0, 165.0)
		return target.global_position + Vector2(cos(angle), sin(angle)) * dist
	return global_position + Vector2(randf_range(-120.0, 120.0), randf_range(-120.0, 120.0))


func _spawn_trail_hazard(pos: Vector2) -> void:
	var trail := Area2D.new()
	trail.global_position = pos
	trail.add_to_group("hazards")
	trail.add_to_group("wave_cleanup")
	trail.collision_layer = 0
	trail.collision_mask = 1

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = frenzy_trail_radius
	shape.shape = circle
	trail.add_child(shape)

	var r := frenzy_trail_radius
	var visual := ColorRect.new()
	visual.size = Vector2(r * 2.0, r * 2.0)
	visual.position = Vector2(-r, -r)
	visual.color = Color(1.0, 0.15, 0.15, 0.65)
	trail.add_child(visual)

	get_tree().current_scene.add_child(trail)

	trail.body_entered.connect(func(body: Node) -> void:
		if not body.is_in_group("player"):
			return
		var hc := body.get_node_or_null("HealthComponent")
		if hc and hc.has_method("take_damage"):
			hc.take_damage(frenzy_trail_damage, "physical")
	)

	var tween := trail.create_tween()
	tween.tween_property(visual, "color:a", 0.0, frenzy_trail_lifetime)
	tween.tween_callback(trail.queue_free)


# ══════════════════════════════════════════════════════════════════════
# ATTACK: SCRAP NOVA (Phase 3)
# Full ring with 3 rotating gaps — pick a gap and dash through it.
# ══════════════════════════════════════════════════════════════════════

func _attack_scrap_nova() -> void:
	await _telegraph(Color(1.5, 0.82, 0.1), 0.72)

	if _is_dead_or_dying():
		return

	var gap_half := deg_to_rad(nova_gap_degrees * 0.5)
	var angle_step := TAU / float(nova_count)

	# Space gaps evenly around the ring
	var gap_centers: Array[float] = []
	for i in nova_gap_count:
		gap_centers.append((float(i) / float(nova_gap_count)) * TAU)

	for i in nova_count:
		var angle := float(i) * angle_step
		var in_gap := false

		for gap_angle in gap_centers:
			if absf(wrapf(angle - gap_angle, -PI, PI)) < gap_half:
				in_gap = true
				break

		if not in_gap:
			_fire_projectile(Vector2(cos(angle), sin(angle)), nova_speed, nova_damage)


# ══════════════════════════════════════════════════════════════════════
# SHARED HELPERS
# ══════════════════════════════════════════════════════════════════════

func _telegraph(color: Color, duration: float) -> void:
	if not is_instance_valid(animated_sprite):
		await get_tree().create_timer(duration).timeout
		return

	if is_instance_valid(target):
		_play_attack_anim(global_position.direction_to(target.global_position))

	var original_color := animated_sprite.modulate
	var original_scale := animated_sprite.scale

	var tween := create_tween().set_parallel(true)
	tween.tween_property(animated_sprite, "modulate", color, duration * 0.45)
	tween.tween_property(animated_sprite, "scale", original_scale * 1.18, duration * 0.5) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)

	await get_tree().create_timer(duration).timeout

	if is_instance_valid(animated_sprite):
		animated_sprite.modulate = original_color
		animated_sprite.scale = original_scale


func _fire_projectile(dir: Vector2, speed: float, damage: int, offset: float = 14.0) -> void:
	if boss_projectile_scene == null:
		return

	var proj := boss_projectile_scene.instantiate() as Node2D
	if proj == null:
		return

	var safe_dir := dir.normalized()
	if safe_dir == Vector2.ZERO:
		safe_dir = Vector2.DOWN

	proj.global_position = global_position + safe_dir * offset
	proj.add_to_group("enemy_projectiles")
	proj.add_to_group("wave_cleanup")
	get_tree().current_scene.add_child(proj)

	if proj.has_method("setup"):
		proj.setup(safe_dir, damage)
	if "speed" in proj:
		proj.speed = speed


func _fire_ring(count: int, speed: float, damage: int, offset: float) -> void:
	_fire_ring_from(global_position, count, speed, damage, offset)


func _fire_ring_from(pos: Vector2, count: int, speed: float, damage: int, offset: float) -> void:
	if count <= 0 or boss_projectile_scene == null:
		return

	for i in count:
		var angle := (float(i) / float(count)) * TAU + offset
		var dir := Vector2(cos(angle), sin(angle))

		var proj := boss_projectile_scene.instantiate() as Node2D
		if proj == null:
			continue

		proj.global_position = pos + dir * 14.0
		proj.add_to_group("enemy_projectiles")
		proj.add_to_group("wave_cleanup")
		get_tree().current_scene.add_child(proj)

		if proj.has_method("setup"):
			proj.setup(dir, damage)
		if "speed" in proj:
			proj.speed = speed


func _is_dead_or_dying() -> bool:
	return not is_instance_valid(self) \
		or health_component == null \
		or health_component.is_dead \
		or _is_dying


func _create_circle_texture(radius: int, color: Color) -> ImageTexture:
	var size := radius * 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(radius), float(radius))
	for x in size:
		for y in size:
			if Vector2(x, y).distance_to(center) < float(radius):
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


# ══════════════════════════════════════════════════════════════════════
# LOOT
# ══════════════════════════════════════════════════════════════════════

func drop_gold() -> void:
	if gold_pickup_scene == null:
		return

	for _i in randi_range(gold_pile_count_min, gold_pile_count_max):
		var pickup := gold_pickup_scene.instantiate() as GoldPickup
		if pickup == null:
			continue
		pickup.gold_amount = randi_range(min_gold_drop, max_gold_drop)
		pickup.global_position = global_position + Vector2(
			randf_range(-32.0, 32.0), randf_range(-32.0, 32.0))
		get_tree().current_scene.add_child(pickup)


func drop_loot() -> void:
	if loot_table == null or loot_item_scene == null:
		return
	if not force_powerup_drop and randf() > powerup_drop_chance:
		return

	var drops: Array[PowerUpData] = []
	var attempts := 0

	while drops.size() < maxi(1, guaranteed_drops) and attempts < guaranteed_drops * 12:
		attempts += 1
		var drop := loot_table.roll_drop()
		if drop != null:
			drops.append(drop)

	for i in drops.size():
		var pickup := loot_item_scene.instantiate() as PowerUpPickup
		if pickup == null:
			continue
		pickup.powerup_data = drops[i]
		pickup.is_wave_temporary = is_wave_temporary_drop
		var angle := (float(i) / float(maxi(1, drops.size()))) * TAU
		pickup.global_position = global_position + Vector2(cos(angle), sin(angle)) * 32.0
		get_tree().current_scene.add_child(pickup)


# ══════════════════════════════════════════════════════════════════════
# DEATH
# ══════════════════════════════════════════════════════════════════════

func _on_died() -> void:
	_is_dying = true
	target = null
	velocity = Vector2.ZERO

	collision.set_deferred("disabled", true)

	if has_node("Hurtbox"):
		$Hurtbox.set_deferred("monitoring", false)
		$Hurtbox.set_deferred("monitorable", false)

	var status := get_node_or_null("StatusEffectComponent") as StatusEffectComponent
	if status != null:
		status.on_enemy_death()

	drop_gold.call_deferred()
	drop_loot.call_deferred()

	if animated_sprite.sprite_frames != null \
			and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
		await animated_sprite.animation_finished

	queue_free()
