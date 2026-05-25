extends Node
class_name WaveManager

# ══════════════════════════════════════════════════════════════════════
# SHOP / BETWEEN-CHAPTER CONFIG
# ══════════════════════════════════════════════════════════════════════

@export var shop_scene: PackedScene
@export var loot_table: PowerUpTable
@export var loot_item_scene: PackedScene
@export var countdown_seconds: int = 3
@export var start_delay_seconds: float = 3.0
@export var between_chapter_delay_seconds: float = 2.0
@export var open_starting_shop: bool = true

var shop_ui: ShopUI = null
var countdown_ui: CanvasLayer = null

# ══════════════════════════════════════════════════════════════════════
# TEMPORARY POWERUP DROP CONFIG
# ══════════════════════════════════════════════════════════════════════

@export_range(0.0, 1.0, 0.001) var regular_powerup_drop_chance: float = 0.003
@export_range(0.0, 1.0, 0.001) var elite_powerup_drop_chance: float = 0.05
@export_range(0.0, 1.0, 0.001) var boss_powerup_drop_chance: float = 1.0

# ══════════════════════════════════════════════════════════════════════
# CHAPTER CONFIG
# ══════════════════════════════════════════════════════════════════════

@export var segments_per_chapter: int = 4
@export var segment_delay_seconds: float = 4.0
@export var virtual_waves_per_chapter: int = 5

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
@export var max_elites_per_chapter: int = 4

@export var elite_health_mult: float = 1.25
@export var elite_damage_mult: float = 1.15
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
@export var max_enemy_count_per_segment: int = 120

@export var health_scale: float = 0.045
@export var damage_scale: float = 0.055
@export var speed_scale: float = 0.012
@export var gold_scale: float = 0.12

# ══════════════════════════════════════════════════════════════════════
# BOSS CONFIG
# ══════════════════════════════════════════════════════════════════════

@export var boss_health_mult: float = 1.65
@export var first_boss_health_mult: float = 1.15
@export var boss_damage_mult: float = 1.45
@export var boss_speed_mult: float = 0.75

# ══════════════════════════════════════════════════════════════════════
# SIGNALS
# Keeping old signal names for compatibility with existing UI.
# ══════════════════════════════════════════════════════════════════════

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal boss_wave_started(wave_number: int)
signal enemy_count_changed(alive: int, total: int)
signal between_waves_started(wave_number: int)

signal chapter_started(chapter_number: int)
signal chapter_completed(chapter_number: int)
signal chapter_progress_changed(progress: float)

# ══════════════════════════════════════════════════════════════════════
# STATE
# ══════════════════════════════════════════════════════════════════════

enum State {
	WAITING,
	SPAWNING,
	CHAPTER_ACTIVE,
	CHAPTER_COMPLETE,
	COUNTDOWN,
	BETWEEN_CHAPTERS
}

var state: State = State.WAITING

var current_chapter: int = 0
var current_segment: int = 0
var current_wave: int = 0
var alive_enemies: Array[Node2D] = []
var total_spawned: int = 0
var elites_spawned_this_chapter: int = 0
var boss_spawned_this_chapter: bool = false
var chapter_spawn_flow_finished: bool = false

# ══════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_setup_shop_ui()
	_setup_countdown_ui()

	await get_tree().create_timer(start_delay_seconds).timeout

	if open_starting_shop and shop_ui != null and loot_table != null:
		await _open_starting_shop()

	start_next_chapter()


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
	start_next_chapter()


func start_next_chapter() -> void:
	if not _can_start_next_chapter():
		return

	current_chapter += 1
	current_segment = 0
	elites_spawned_this_chapter = 0
	boss_spawned_this_chapter = false
	chapter_spawn_flow_finished = false

	current_wave = _get_virtual_wave_for_segment(1)
	PlayerInventory.current_wave = current_wave
	DamageMeter.reset()

	state = State.SPAWNING

	chapter_started.emit(current_chapter)
	wave_started.emit(current_wave)

	await _run_chapter()


func get_wave_info() -> Dictionary:
	return {
		"wave": current_wave,
		"chapter": current_chapter,
		"segment": current_segment,
		"alive": alive_enemies.size(),
		"total": total_spawned,
		"state": State.keys()[state],
		"is_boss_wave": boss_spawned_this_chapter,
		"elites_spawned": elites_spawned_this_chapter,
		"chapter_progress": _get_chapter_progress(),
	}

# ══════════════════════════════════════════════════════════════════════
# CHAPTER FLOW
# ══════════════════════════════════════════════════════════════════════

func _can_start_next_chapter() -> bool:
	return state == State.WAITING or state == State.BETWEEN_CHAPTERS


func _run_chapter() -> void:
	total_spawned = 0
	enemy_count_changed.emit(alive_enemies.size(), total_spawned)

	for segment_index in range(1, segments_per_chapter + 1):
		current_segment = segment_index
		current_wave = _get_virtual_wave_for_segment(segment_index)
		PlayerInventory.current_wave = current_wave

		var wave_data: Dictionary = _build_segment_data(current_wave, false)

		await _spawn_segment(wave_data)
		chapter_progress_changed.emit(_get_chapter_progress())

		if segment_index < segments_per_chapter:
			await get_tree().create_timer(segment_delay_seconds).timeout

	current_segment = segments_per_chapter + 1
	current_wave = _get_virtual_wave_for_boss()
	PlayerInventory.current_wave = current_wave

	await _spawn_boss_segment(current_wave)

	chapter_spawn_flow_finished = true
	state = State.CHAPTER_ACTIVE

	_finish_chapter_if_ready()


func _finish_chapter_if_ready() -> void:
	if state != State.CHAPTER_ACTIVE:
		return

	if not chapter_spawn_flow_finished:
		return

	if not alive_enemies.is_empty():
		return

	_on_chapter_cleared()


func _on_chapter_cleared() -> void:
	state = State.CHAPTER_COMPLETE

	chapter_completed.emit(current_chapter)
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

	if shop_ui != null:
		if current_chapter == 1:
			await _open_element_unlock_shop(current_wave)
		else:
			await _open_shop(current_wave)

	state = State.BETWEEN_CHAPTERS
	between_waves_started.emit(current_wave)

	await get_tree().create_timer(between_chapter_delay_seconds).timeout
	start_next_chapter()


func _open_starting_shop() -> void:
	if shop_ui == null:
		return

	if loot_table == null:
		push_warning("WaveManager: loot_table not assigned, starting projectile shop cannot open correctly.")
		return

	shop_ui.open_shop(0, loot_table, "starter_projectile")
	await shop_ui.shop_closed


func _open_element_unlock_shop(wave_number: int) -> void:
	if shop_ui == null:
		return

	if loot_table == null:
		push_warning("WaveManager: loot_table not assigned, element shop cannot open correctly.")
		return

	shop_ui.open_shop(wave_number, loot_table, "starter_element")
	await shop_ui.shop_closed


func _open_projectile_unlock_shop(wave_number: int) -> void:
	if shop_ui == null:
		return

	if loot_table == null:
		push_warning("WaveManager: loot_table not assigned, projectile shop cannot open correctly.")
		return

	shop_ui.open_shop(wave_number, loot_table, "starter_projectile")
	await shop_ui.shop_closed


func _open_shop(wave_number: int) -> void:
	if shop_ui == null:
		return

	if loot_table == null:
		push_warning("WaveManager: loot_table not assigned, shop cannot open correctly.")
		return

	shop_ui.open_shop(wave_number, loot_table, false)
	await shop_ui.shop_closed


func _clear_projectiles() -> void:
	var cleanup_groups: Array[String] = [
		"projectiles",
		"enemy_projectiles",
		"hazards",
		"area_effects",
		"wave_cleanup"
	]

	var cleared_nodes: Array[Node] = []

	for group_name in cleanup_groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(node):
				continue

			if cleared_nodes.has(node):
				continue

			cleared_nodes.append(node)
			node.queue_free()

	print("[WaveManager] Cleared wave hazards/projectiles: ", cleared_nodes.size())


func _get_chapter_progress() -> float:
	if segments_per_chapter <= 0:
		return 0.0

	var boss_part: float = 1.0 if boss_spawned_this_chapter else 0.0
	var total_steps: float = float(segments_per_chapter + 1)
	var completed_steps: float = clampf(float(current_segment - 1) + boss_part, 0.0, total_steps)

	return completed_steps / total_steps

# ══════════════════════════════════════════════════════════════════════
# CHAPTER / VIRTUAL WAVE DATA
# ══════════════════════════════════════════════════════════════════════

func _get_virtual_wave_for_segment(segment_index: int) -> int:
	var chapter_start_wave: int = ((current_chapter - 1) * virtual_waves_per_chapter) + 1
	return chapter_start_wave + segment_index - 1


func _get_virtual_wave_for_boss() -> int:
	var chapter_start_wave: int = ((current_chapter - 1) * virtual_waves_per_chapter) + 1

	return chapter_start_wave + maxi(0, virtual_waves_per_chapter - 2)


func _build_segment_data(wave_num: int, is_boss: bool) -> Dictionary:
	var enemy_count: int = _get_enemy_count(wave_num)

	return {
		"wave": wave_num,
		"count": enemy_count,
		"health_mult": _get_health_multiplier(wave_num),
		"damage_mult": _get_damage_multiplier(wave_num),
		"speed_mult": _get_speed_multiplier(wave_num),
		"gold_mult": _get_gold_multiplier(wave_num),
		"is_boss": is_boss,
		"enemy_scenes": _get_unlocked_enemy_scenes(wave_num),
	}


func _get_enemy_count(wave_num: int) -> int:
	var scaled_count: int = base_enemy_count + int(float(wave_num - 1) * enemies_per_wave)
	return mini(scaled_count, max_enemy_count_per_segment)


func _get_health_multiplier(wave_num: int) -> float:
	return pow(1.0 + health_scale, wave_num - 1)


func _get_damage_multiplier(wave_num: int) -> float:
	return 1.0 + float(wave_num - 1) * damage_scale


func _get_speed_multiplier(wave_num: int) -> float:
	return 1.0 + float(wave_num - 1) * speed_scale


func _get_gold_multiplier(wave_num: int) -> float:
	return 1.0 + float(wave_num - 1) * gold_scale


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

func _spawn_segment(segment_data: Dictionary) -> void:
	state = State.SPAWNING

	var enemy_scenes_for_segment: Array[PackedScene] = segment_data.enemy_scenes

	if enemy_scenes_for_segment.is_empty():
		push_warning("WaveManager: no enemy scenes available for virtual wave %d." % current_wave)
		return

	var count: int = int(segment_data.count)
	var dynamic_stagger: float = _get_dynamic_spawn_stagger(count)

	total_spawned += count
	enemy_count_changed.emit(alive_enemies.size(), total_spawned)

	for i in count:
		if state != State.SPAWNING:
			return

		var scene: PackedScene = enemy_scenes_for_segment.pick_random()

		_spawn_regular_or_elite_enemy(
			scene,
			float(segment_data.health_mult),
			float(segment_data.damage_mult),
			float(segment_data.speed_mult),
			float(segment_data.gold_mult)
		)

		if dynamic_stagger > 0.0 and i < count - 1:
			await get_tree().create_timer(dynamic_stagger).timeout

	state = State.CHAPTER_ACTIVE


func _spawn_boss_segment(wave_num: int) -> void:
	if boss_scenes.is_empty():
		push_warning("WaveManager: boss_scenes is empty; chapter has no boss.")
		boss_spawned_this_chapter = true
		return

	state = State.SPAWNING
	boss_spawned_this_chapter = true
	boss_wave_started.emit(wave_num)
	chapter_progress_changed.emit(_get_chapter_progress())

	var boss_data: Dictionary = _build_segment_data(wave_num, true)
	var boss_mult: float = boss_health_mult

	if current_chapter == 1:
		boss_mult = first_boss_health_mult

	total_spawned += 1
	enemy_count_changed.emit(alive_enemies.size(), total_spawned)

	_spawn_enemy(
		boss_scenes.pick_random(),
		float(boss_data.health_mult) * boss_mult,
		float(boss_data.damage_mult) * boss_damage_mult,
		float(boss_data.speed_mult) * boss_speed_mult,
		float(boss_data.gold_mult),
		true,
		false
	)

	state = State.CHAPTER_ACTIVE


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
		elites_spawned_this_chapter += 1
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
	_apply_enemy_drop_context(enemy, is_boss, is_elite)

	if is_elite:
		_apply_elite_affixes(enemy)

	_track_enemy(enemy)


func _apply_enemy_drop_context(enemy: Node2D, is_boss: bool, is_elite: bool) -> void:
	if not enemy.has_method("set_powerup_drop_context"):
		return

	var drop_chance: float = regular_powerup_drop_chance
	var force_drop: bool = false

	if is_boss:
		drop_chance = boss_powerup_drop_chance
		force_drop = boss_powerup_drop_chance >= 1.0
	elif is_elite:
		drop_chance = elite_powerup_drop_chance

	enemy.set_powerup_drop_context(
		loot_table,
		loot_item_scene,
		drop_chance,
		force_drop,
		true
	)


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

	if elites_spawned_this_chapter >= max_elites_per_chapter:
		return false

	if boss_spawned_this_chapter:
		return false

	return true


func _get_elite_chance(wave_num: int) -> float:
	var waves_since_elites_started: int = max(0, wave_num - elite_start_wave)

	return clamp(
		elite_base_chance + elite_wave_scaling * float(waves_since_elites_started),
		0.0,
		elite_max_chance
	)

# ══════════════════════════════════════════════════════════════════════
# ENEMY SETUP / SCALING
# ══════════════════════════════════════════════════════════════════════

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

	_finish_chapter_if_ready()
