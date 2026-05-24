extends Node
class_name WaveManager

# ══════════════════════════════════════════════════════════════════════
# SHOP / BETWEEN-WAVE CONFIG
# ══════════════════════════════════════════════════════════════════════

@export var shop_interval: int = 5
@export var shop_scene: PackedScene
@export var loot_table: PowerUpTable
@export var countdown_seconds: int = 3
@export var start_delay_seconds: float = 3.0
@export var between_wave_delay_seconds: float = 2.0

var shop_ui: ShopUI = null
var countdown_ui: CanvasLayer = null

# ══════════════════════════════════════════════════════════════════════
# ENEMY CONFIG
# ══════════════════════════════════════════════════════════════════════

@export var enemy_scenes: Array[PackedScene] = []
@export var boss_scenes: Array[PackedScene] = []
@export var elite_scenes: Array[PackedScene] = []

@export var waves_per_unlock: int = 3

# ══════════════════════════════════════════════════════════════════════
# ELITE CONFIG
# ══════════════════════════════════════════════════════════════════════

@export var elite_start_wave: int = 7
@export var elite_base_chance: float = 0.025
@export var elite_wave_scaling: float = 0.007
@export var elite_max_chance: float = 0.15
@export var elite_max_affixes: int = 2
@export var max_elites_per_wave: int = 4

@export var elite_health_mult: float = 1.35
@export var elite_damage_mult: float = 1.20
@export var elite_speed_mult: float = 1.20
@export var elite_gold_mult: float = 2.0

# ══════════════════════════════════════════════════════════════════════
# SPAWN CONFIG
# ══════════════════════════════════════════════════════════════════════

@export var spawn_radius: float = 160.0
@export var spawn_points: Array[Marker2D] = []

@export var spawn_stagger: float = 0.08
@export var min_spawn_stagger: float = 0.01

# ══════════════════════════════════════════════════════════════════════
# DIFFICULTY CONFIG
# ══════════════════════════════════════════════════════════════════════

@export var base_enemy_count: int = 3
@export var enemies_per_wave: float = 2.5
@export var max_enemy_count: int = 300

@export var health_scale: float = 0.10
@export var damage_scale: float = 0.08
@export var speed_scale: float = 0.025
@export var gold_scale: float = 0.12

# ══════════════════════════════════════════════════════════════════════
# BOSS CONFIG
# ══════════════════════════════════════════════════════════════════════

@export var boss_interval: int = 5
@export var boss_health_mult: float = 3.5
@export var boss_damage_mult: float = 2.0
@export var boss_speed_mult: float = 0.7

# ══════════════════════════════════════════════════════════════════════
# SIGNALS
# ══════════════════════════════════════════════════════════════════════

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal boss_wave_started(wave_number: int)
signal enemy_count_changed(alive: int, total: int)
signal between_waves_started(wave_number: int)

# ══════════════════════════════════════════════════════════════════════
# STATE
# ══════════════════════════════════════════════════════════════════════

enum State {
	WAITING,
	SPAWNING,
	WAVE_ACTIVE,
	WAVE_COMPLETE,
	COUNTDOWN,
	BETWEEN_WAVES
}

var state: State = State.WAITING
var current_wave: int = 0
var alive_enemies: Array[Node2D] = []
var total_spawned: int = 0
var elites_spawned_this_wave: int = 0

# ══════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_setup_shop_ui()
	_setup_countdown_ui()

	await get_tree().create_timer(start_delay_seconds).timeout
	start_next_wave()


func _setup_shop_ui() -> void:
	if shop_scene == null:
		push_warning("WaveManager: shop_scene not assigned.")
		return

	shop_ui = shop_scene.instantiate() as ShopUI

	if shop_ui == null:
		push_warning("WaveManager: shop_scene root is not ShopUI.")
		return

	get_tree().current_scene.add_child.call_deferred(shop_ui)


func _setup_countdown_ui() -> void:
	var countdown_script := load("res://scripts/wave_countdown_ui.gd")

	if countdown_script == null:
		push_warning("WaveManager: Could not load wave_countdown_ui.gd.")
		return

	countdown_ui = countdown_script.new() as CanvasLayer

	if countdown_ui == null:
		push_warning("WaveManager: countdown script did not create a CanvasLayer.")
		return

	get_tree().current_scene.add_child.call_deferred(countdown_ui)

	if not countdown_ui.countdown_finished.is_connected(_on_countdown_finished):
		countdown_ui.countdown_finished.connect(_on_countdown_finished)

# ══════════════════════════════════════════════════════════════════════
# PUBLIC API
# ══════════════════════════════════════════════════════════════════════

func start_next_wave() -> void:
	if not _can_start_next_wave():
		return

	current_wave += 1

	var wave_data: Dictionary = _build_wave_data(current_wave)

	_prepare_wave_start(wave_data)
	await _spawn_wave(wave_data)
	_finish_wave_spawn_phase()


func get_wave_info() -> Dictionary:
	return {
		"wave": current_wave,
		"alive": alive_enemies.size(),
		"total": total_spawned,
		"state": State.keys()[state],
		"is_boss_wave": _is_boss_wave(current_wave),
		"elites_spawned": elites_spawned_this_wave,
	}

# ══════════════════════════════════════════════════════════════════════
# WAVE FLOW
# ══════════════════════════════════════════════════════════════════════

func _can_start_next_wave() -> bool:
	return state == State.WAITING or state == State.BETWEEN_WAVES


func _prepare_wave_start(wave_data: Dictionary) -> void:
	state = State.SPAWNING
	total_spawned = int(wave_data.total_count)
	elites_spawned_this_wave = 0

	PlayerInventory.current_wave = current_wave
	DamageMeter.reset()

	if bool(wave_data.is_boss):
		boss_wave_started.emit(current_wave)

	wave_started.emit(current_wave)
	enemy_count_changed.emit(alive_enemies.size(), total_spawned)


func _finish_wave_spawn_phase() -> void:
	if alive_enemies.is_empty():
		_on_wave_cleared()
		return

	state = State.WAVE_ACTIVE


func _on_wave_cleared() -> void:
	state = State.WAVE_COMPLETE
	wave_completed.emit(current_wave)

	_clear_projectiles()

	state = State.COUNTDOWN

	if countdown_ui != null:
		countdown_ui.start_countdown(countdown_seconds)
	else:
		await get_tree().create_timer(float(countdown_seconds)).timeout
		_on_countdown_finished()


func _on_countdown_finished() -> void:
	PlayerInventory.clear_wave_temporary_powerups()

	if _should_open_shop():
		await _open_shop(current_wave)

	state = State.BETWEEN_WAVES
	between_waves_started.emit(current_wave)

	await get_tree().create_timer(between_wave_delay_seconds).timeout
	start_next_wave()


func _should_open_shop() -> bool:
	if shop_interval <= 0:
		return false

	if shop_ui == null:
		return false

	return current_wave % shop_interval == 0


func _open_shop(wave_number: int) -> void:
	if shop_ui == null:
		return

	if loot_table == null:
		push_warning("WaveManager: loot_table not assigned, shop cannot open correctly.")
		return

	shop_ui.open_shop(wave_number, loot_table)
	await shop_ui.shop_closed


func _clear_projectiles() -> void:
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		if is_instance_valid(projectile):
			projectile.queue_free()

# ══════════════════════════════════════════════════════════════════════
# WAVE DATA
# ══════════════════════════════════════════════════════════════════════

func _build_wave_data(wave_num: int) -> Dictionary:
	var enemy_count: int = _get_enemy_count(wave_num)
	var is_boss: bool = _is_boss_wave(wave_num)

	return {
		"wave": wave_num,
		"count": enemy_count,
		"total_count": enemy_count + (1 if is_boss else 0),
		"health_mult": _get_health_multiplier(wave_num),
		"damage_mult": _get_damage_multiplier(wave_num),
		"speed_mult": _get_speed_multiplier(wave_num),
		"gold_mult": _get_gold_multiplier(wave_num),
		"is_boss": is_boss,
		"enemy_scenes": _get_unlocked_enemy_scenes(wave_num),
	}


func _get_enemy_count(wave_num: int) -> int:
	var scaled_count: int = base_enemy_count + int(float(wave_num - 1) * enemies_per_wave)
	return mini(scaled_count, max_enemy_count)


func _get_health_multiplier(wave_num: int) -> float:
	return pow(1.0 + health_scale, wave_num - 1)


func _get_damage_multiplier(wave_num: int) -> float:
	return 1.0 + float(wave_num - 1) * damage_scale


func _get_speed_multiplier(wave_num: int) -> float:
	return 1.0 + float(wave_num - 1) * speed_scale


func _get_gold_multiplier(wave_num: int) -> float:
	return 1.0 + float(wave_num - 1) * gold_scale


func _is_boss_wave(wave_num: int) -> bool:
	if boss_interval <= 0:
		return false

	return wave_num > 0 and wave_num % boss_interval == 0


func _get_unlocked_enemy_scenes(wave_num: int) -> Array[PackedScene]:
	var unlocked: Array[PackedScene] = []

	for i in enemy_scenes.size():
		var unlock_at: int = i * waves_per_unlock + 1

		if wave_num >= unlock_at:
			unlocked.append(enemy_scenes[i])

	if unlocked.is_empty() and not enemy_scenes.is_empty():
		unlocked.append(enemy_scenes[0])

	return unlocked

# ══════════════════════════════════════════════════════════════════════
# SPAWNING
# ══════════════════════════════════════════════════════════════════════

func _spawn_wave(wave_data: Dictionary) -> void:
	var enemy_scenes_for_wave: Array[PackedScene] = wave_data.enemy_scenes

	if enemy_scenes_for_wave.is_empty():
		push_warning("WaveManager: no enemy scenes available for wave %d." % current_wave)
		return

	var count: int = int(wave_data.count)
	var dynamic_stagger: float = _get_dynamic_spawn_stagger(count)

	for i in count:
		if state != State.SPAWNING:
			return

		var scene: PackedScene = enemy_scenes_for_wave.pick_random()

		_spawn_regular_or_elite_enemy(
			scene,
			float(wave_data.health_mult),
			float(wave_data.damage_mult),
			float(wave_data.speed_mult),
			float(wave_data.gold_mult)
		)

		if dynamic_stagger > 0.0 and i < count - 1:
			await get_tree().create_timer(dynamic_stagger).timeout

	if bool(wave_data.is_boss):
		await _spawn_boss_enemy(wave_data, dynamic_stagger)


func _get_dynamic_spawn_stagger(enemy_count: int) -> float:
	return max(
		min_spawn_stagger,
		spawn_stagger / (1.0 + float(enemy_count) * 0.15)
	)


func _spawn_regular_or_elite_enemy(
	base_scene: PackedScene,
	health_mult: float,
	damage_mult: float,
	speed_mult: float,
	gold_mult: float
) -> void:
	var spawn_data: Dictionary = _choose_regular_or_elite_scene(base_scene)
	var is_elite: bool = bool(spawn_data.is_elite)

	if is_elite:
		elites_spawned_this_wave += 1
		health_mult *= elite_health_mult
		damage_mult *= elite_damage_mult
		speed_mult *= elite_speed_mult
		gold_mult *= elite_gold_mult

	_spawn_enemy(
		spawn_data.scene,
		health_mult,
		damage_mult,
		speed_mult,
		gold_mult,
		false,
		is_elite
	)


func _spawn_boss_enemy(wave_data: Dictionary, dynamic_stagger: float) -> void:
	if boss_scenes.is_empty():
		return

	if dynamic_stagger > 0.0:
		await get_tree().create_timer(dynamic_stagger * 2.0).timeout

	_spawn_enemy(
		boss_scenes.pick_random(),
		float(wave_data.health_mult) * boss_health_mult,
		float(wave_data.damage_mult) * boss_damage_mult,
		float(wave_data.speed_mult) * boss_speed_mult,
		float(wave_data.gold_mult),
		true,
		false
	)


func _spawn_enemy(
	scene: PackedScene,
	health_mult: float,
	damage_mult: float,
	speed_mult: float,
	gold_mult: float,
	is_boss: bool,
	is_elite: bool
) -> void:
	if scene == null:
		push_warning("WaveManager: tried to spawn a null enemy scene.")
		return

	var enemy := scene.instantiate() as Node2D

	if enemy == null:
		push_warning("WaveManager: enemy scene root is not Node2D.")
		return

	enemy.global_position = _get_random_spawn_position()
	get_tree().current_scene.add_child(enemy)

	_apply_spawn_setup(enemy)
	_apply_enemy_scaling(enemy, health_mult, damage_mult, speed_mult, gold_mult)
	_apply_enemy_visuals(enemy, is_boss, is_elite)

	if is_elite:
		_apply_elite_affixes(enemy)

	_track_enemy(enemy)


func _choose_regular_or_elite_scene(base_scene: PackedScene) -> Dictionary:
	if not _can_spawn_elite():
		return {
			"scene": base_scene,
			"is_elite": false
		}

	var chance: float = _get_elite_chance(current_wave)

	if randf() >= chance:
		return {
			"scene": base_scene,
			"is_elite": false
		}

	return {
		"scene": elite_scenes.pick_random(),
		"is_elite": true
	}


func _can_spawn_elite() -> bool:
	if current_wave < elite_start_wave:
		return false

	if elite_scenes.is_empty():
		return false

	if elites_spawned_this_wave >= max_elites_per_wave:
		return false

	if _is_boss_wave(current_wave):
		return false

	return true


func _get_elite_chance(wave_num: int) -> float:
	var waves_since_elites_started: int = max(0, wave_num - elite_start_wave)

	return clamp(
		elite_base_chance + elite_wave_scaling * float(waves_since_elites_started),
		0.0,
		elite_max_chance
	)


func _apply_spawn_setup(enemy: Node2D) -> void:
	var players := get_tree().get_nodes_in_group("player")

	if not players.is_empty() and enemy.has_method("set_target"):
		enemy.set_target(players[0])


func _apply_enemy_scaling(
	enemy: Node2D,
	health_mult: float,
	damage_mult: float,
	speed_mult: float,
	gold_mult: float
) -> void:
	_apply_health_scaling(enemy, health_mult)
	_apply_damage_scaling(enemy, damage_mult)
	_apply_speed_scaling(enemy, speed_mult)
	_apply_gold_scaling(enemy, gold_mult)


func _apply_health_scaling(enemy: Node2D, health_mult: float) -> void:
	var health_component := enemy.get_node_or_null("HealthComponent") as HealthComponent

	if health_component == null:
		return

	if health_component.has_method("scale_max_health"):
		health_component.scale_max_health(health_mult, true)
	else:
		health_component.max_health = max(1, int(round(float(health_component.max_health) * health_mult)))
		health_component.current_health = health_component.max_health
		health_component.health_changed.emit(health_component.current_health, health_component.max_health)


func _apply_damage_scaling(enemy: Node2D, damage_mult: float) -> void:
	if "damage" in enemy:
		enemy.damage *= damage_mult
		return

	var stats := enemy.get_node_or_null("StatsComponent") as Node

	if stats != null and "damage" in stats:
		stats.damage *= damage_mult


func _apply_speed_scaling(enemy: Node2D, speed_mult: float) -> void:
	if "move_speed" in enemy:
		enemy.move_speed *= speed_mult


func _apply_gold_scaling(enemy: Node2D, gold_mult: float) -> void:
	if enemy.has_method("set_gold_multiplier"):
		enemy.set_gold_multiplier(gold_mult)


func _apply_enemy_visuals(enemy: Node2D, is_boss: bool, is_elite: bool) -> void:
	if not enemy.has_node("AnimatedSprite2D"):
		return

	var sprite := enemy.get_node("AnimatedSprite2D")

	if not sprite is AnimatedSprite2D:
		return

	if is_boss:
		(sprite as AnimatedSprite2D).modulate = Color(1.2, 0.8, 0.8)
	elif is_elite:
		(sprite as AnimatedSprite2D).modulate = Color(1.15, 1.0, 0.65)


func _apply_elite_affixes(enemy: Node2D) -> void:
	var affix_component := enemy.get_node_or_null("AffixComponent") as AffixComponent

	if affix_component == null:
		return

	var affix_count: int = _get_elite_affix_count()
	var rolled: Array[AffixData] = AffixTable.roll(affix_count, current_wave)

	if rolled.is_empty():
		return

	affix_component.apply_affixes(rolled)

	print(
		"[ELITE] Spawned with: ",
		rolled.map(func(a: AffixData) -> String: return a.display_name)
	)


func _get_elite_affix_count() -> int:
	if current_wave < 15:
		return 1

	return randi_range(1, elite_max_affixes)


func _track_enemy(enemy: Node2D) -> void:
	alive_enemies.append(enemy)
	enemy.tree_exiting.connect(_on_enemy_died.bind(enemy))
	enemy_count_changed.emit(alive_enemies.size(), total_spawned)


func _get_random_spawn_position() -> Vector2:
	var center := Vector2.ZERO

	if not spawn_points.is_empty():
		var point: Marker2D = spawn_points.pick_random()

		if is_instance_valid(point):
			center = point.global_position

	var angle := randf() * TAU
	var dist := randf_range(spawn_radius * 0.6, spawn_radius)

	return center + Vector2(cos(angle), sin(angle)) * dist

# ══════════════════════════════════════════════════════════════════════
# ENEMY DEATH
# ══════════════════════════════════════════════════════════════════════

func _on_enemy_died(enemy: Node2D) -> void:
	alive_enemies.erase(enemy)
	enemy_count_changed.emit(alive_enemies.size(), total_spawned)

	if alive_enemies.is_empty() and state == State.WAVE_ACTIVE:
		_on_wave_cleared()
