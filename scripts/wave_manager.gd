extends Node
class_name WaveManager

## How often the shop appears. Set to 5 to see a shop every 5 waves.
@export var shop_interval: int = 5

## Reference to the shop UI scene (assign ShopUI.tscn in Inspector).
@export var shop_scene: PackedScene

## Reference to the loot table for generating shop items.
@export var loot_table: PowerUpTable

var shop_ui: ShopUI = null

# ── Signals ───────────────────────────────────────────────────────────
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal boss_wave_started(wave_number: int)
signal enemy_count_changed(alive: int, total: int)
signal between_waves_started(wave_number: int)

# ── Enemy Configuration ───────────────────────────────────────────────
@export var enemy_scenes: Array[PackedScene] = []
@export var boss_scenes: Array[PackedScene] = []
@export var waves_per_unlock: int = 3

# ── Spawning ──────────────────────────────────────────────────────────
@export var spawn_radius: float = 160.0
@export var spawn_stagger: float = 0.35
@export var spawn_points: Array[Marker2D] = []

# ── Difficulty Curve ──────────────────────────────────────────────────
@export var base_enemy_count: int = 3
@export var enemies_per_wave: float = 1.8
@export var max_enemy_count: int = 40
@export var health_scale: float = 0.12
@export var speed_scale: float = 0.05
@export var boss_interval: int = 5
@export var boss_health_mult: float = 3.5
@export var boss_speed_mult: float = 0.7

# ── Internal State ────────────────────────────────────────────────────
enum State { WAITING, SPAWNING, WAVE_ACTIVE, WAVE_COMPLETE, BETWEEN_WAVES }
var state: State = State.WAITING
var current_wave: int = 0
var alive_enemies: Array[Node2D] = []
var total_spawned: int = 0

# ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Instantiate the shop UI, but use call_deferred to add it after _ready() finishes.
	# This prevents the "parent is busy" error that happens when adding children directly.
	if shop_scene:
		shop_ui = shop_scene.instantiate() as ShopUI
		get_tree().current_scene.add_child.call_deferred(shop_ui)
	else:
		push_warning("WaveManager: shop_scene not assigned")

# ── Public API ────────────────────────────────────────────────────────

## Call this when the player is ready to begin the next wave.
func start_next_wave() -> void:
	if state != State.WAITING and state != State.BETWEEN_WAVES:
		return

	current_wave += 1
	var wave_data := _generate_wave(current_wave)
	total_spawned = wave_data.total_count
	state = State.SPAWNING

	if wave_data.is_boss:
		boss_wave_started.emit(current_wave)
	wave_started.emit(current_wave)

	await _spawn_wave(wave_data)

	if alive_enemies.is_empty():
		_on_wave_cleared()
	else:
		state = State.WAVE_ACTIVE

## Returns a snapshot of the current state for UI or debugging.
func get_wave_info() -> Dictionary:
	return {
		"wave": current_wave,
		"alive": alive_enemies.size(),
		"total": total_spawned,
		"state": State.keys()[state],
		"is_boss_wave": current_wave > 0 and current_wave % boss_interval == 0,
	}

# ── Wave Generation ──────────────────────────────────────────────────

func _generate_wave(wave_num: int) -> Dictionary:
	var is_boss := wave_num % boss_interval == 0
	var count := mini(base_enemy_count + int(wave_num * enemies_per_wave), max_enemy_count)

	var h_mult := 1.0 + (wave_num - 1) * health_scale
	var s_mult := 1.0 + (wave_num - 1) * speed_scale

	var available := _get_unlocked_enemies(wave_num)

	return {
		"count": count,
		"total_count": count + (1 if is_boss else 0),
		"health_mult": h_mult,
		"speed_mult": s_mult,
		"is_boss": is_boss,
		"scenes": available,
	}

func _get_unlocked_enemies(wave_num: int) -> Array[PackedScene]:
	var unlocked: Array[PackedScene] = []
	for i in enemy_scenes.size():
		var unlock_at := i * waves_per_unlock + 1
		if wave_num >= unlock_at:
			unlocked.append(enemy_scenes[i])
	if unlocked.is_empty() and not enemy_scenes.is_empty():
		unlocked.append(enemy_scenes[0])
	return unlocked

# ── Spawning ──────────────────────────────────────────────────────────

func _spawn_wave(wave_data: Dictionary) -> void:
	for i in wave_data.count:
		if state == State.SPAWNING:
			_spawn_enemy(wave_data.scenes.pick_random(),
						wave_data.health_mult, wave_data.speed_mult)
			if spawn_stagger > 0 and i < wave_data.count - 1:
				await get_tree().create_timer(spawn_stagger).timeout

	if wave_data.is_boss and not boss_scenes.is_empty():
		if spawn_stagger > 0:
			await get_tree().create_timer(spawn_stagger * 2).timeout
		var chosen_boss: PackedScene = boss_scenes.pick_random()
		_spawn_enemy(chosen_boss,
					wave_data.health_mult * boss_health_mult,
					wave_data.speed_mult * boss_speed_mult)

func _spawn_enemy(scene: PackedScene, h_mult: float, s_mult: float) -> void:
	var enemy := scene.instantiate() as Node2D
	if enemy == null:
		push_warning("WaveManager: scene root is not Node2D.")
		return

	enemy.global_position = _random_spawn_pos()
	get_tree().current_scene.add_child(enemy)

	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and enemy.has_method("set_target"):
		enemy.set_target(players[0])

	# Calculate gold multiplier based on wave and pass it to the enemy
	var g_mult := 1.0 + (current_wave - 1) * 0.12  # 12% increase per wave
	if enemy.has_method("set_gold_multiplier"):
		enemy.set_gold_multiplier(g_mult)

	# Apply difficulty scaling
	if "move_speed" in enemy:
		enemy.move_speed *= s_mult

	var hc := enemy.get_node_or_null("HealthComponent") as Node
	if hc and "max_health" in hc:
		hc.max_health = int(hc.max_health * h_mult)
		if "current_health" in hc:
			hc.current_health = hc.max_health

	alive_enemies.append(enemy)
	enemy.tree_exiting.connect(_on_enemy_died.bind(enemy))
	enemy_count_changed.emit(alive_enemies.size(), total_spawned)

func _random_spawn_pos() -> Vector2:
	var center := Vector2.ZERO
	if not spawn_points.is_empty():
		var point: Marker2D = spawn_points.pick_random()
		if is_instance_valid(point):
			center = point.global_position

	var angle := randf() * TAU
	var dist := randf_range(spawn_radius * 0.6, spawn_radius)
	return center + Vector2(cos(angle), sin(angle)) * dist

# ── Enemy Tracking ────────────────────────────────────────────────────

func _on_enemy_died(enemy: Node2D) -> void:
	alive_enemies.erase(enemy)
	enemy_count_changed.emit(alive_enemies.size(), total_spawned)

	if alive_enemies.is_empty() and state == State.WAVE_ACTIVE:
		_on_wave_cleared()

func _on_wave_cleared() -> void:
	state = State.WAVE_COMPLETE
	wave_completed.emit(current_wave)

	await get_tree().create_timer(1.5).timeout

	if current_wave % shop_interval == 0 and shop_ui != null:
		await _open_shop(current_wave)

	state = State.BETWEEN_WAVES
	between_waves_started.emit(current_wave)

func _open_shop(wave_number: int) -> void:
	if not shop_ui or not loot_table:
		push_warning("WaveManager: Shop UI or Loot Table not assigned")
		return

	shop_ui.open_shop(wave_number, loot_table)
	await shop_ui.shop_closed
