extends Node
class_name WaveManager

# ── Shop ──────────────────────────────────────────────────────────────

## How many waves pass between each shop visit.
## Default 5 means the shop opens after waves 5, 10, 15, etc.
@export var shop_interval: int = 5

## The ShopUI scene to instantiate. Must be assigned or the shop will not open.
@export var shop_scene: PackedScene

## The PowerUpTable resource that the shop and enemy drops roll from.
@export var loot_table: PowerUpTable

## Seconds shown on the countdown timer after a wave is cleared.
## Set to 3 for a "3… 2… 1…" countdown before the next wave or shop.
@export var countdown_seconds: int = 3

var shop_ui: ShopUI       = null
var countdown_ui: CanvasLayer = null

# ── Signals ───────────────────────────────────────────────────────────
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal boss_wave_started(wave_number: int)
signal enemy_count_changed(alive: int, total: int)
signal between_waves_started(wave_number: int)

# ── Enemy Configuration ───────────────────────────────────────────────

## Regular enemy scenes unlocked progressively as waves advance.
## The first scene is always available. Each additional scene unlocks
## every `waves_per_unlock` waves (e.g. scene 2 at wave 4 if unlock = 3).
@export var enemy_scenes: Array[PackedScene] = []

## Boss scenes used exclusively on boss waves (every `boss_interval` waves).
## A random boss is picked from this array each boss wave.
@export var boss_scenes: Array[PackedScene] = []

## Elite enemy scenes. When an enemy rolls as elite, one of these scenes
## is spawned instead of the regular enemy. Add EliteEnemy.tscn here.
@export var elite_scenes: Array[PackedScene] = []

## How many waves must pass before the next enemy type unlocks.
## Example: 3 means scene[1] unlocks at wave 4, scene[2] at wave 7, etc.
@export var waves_per_unlock: int = 3

# ── Elite Settings ─────────────────────────────────────────────────────

## Base probability that any regular enemy spawns as elite at wave `elite_start_wave`.
## Increases each wave by `elite_wave_scaling`. Capped at 40%.
## Example: 0.02 = 2% base chance.
@export var elite_base_chance: float = 0.02

## How much the elite chance increases per wave past `elite_start_wave`.
## Example: 0.015 means +1.5% per wave. At wave 10 with base 0.02: ~11.5% chance.
@export var elite_wave_scaling: float = 0.015

## No elites spawn before this wave number. Gives the player time to
## learn the basic loop before elite modifiers are introduced.
@export var elite_start_wave: int = 3

## Maximum number of affixes rolled on a single elite enemy.
## 1 = always one affix. 2 = one or two affixes randomly.
@export var elite_max_affixes: int = 2

# ── Spawning ──────────────────────────────────────────────────────────

## Enemies spawn in a ring around spawn points at this radius (pixels).
## Increase for larger maps so enemies don't appear on top of the player.
@export var spawn_radius: float = 160.0

## Seconds between each enemy spawn within a wave.
## Lower = enemies arrive as a rush. Higher = staggered trickle.
## Optional fixed spawn point markers. If empty, enemies spawn around (0,0).
## Add Marker2D nodes to your scene and assign them here for controlled spawns.
@export var spawn_points: Array[Marker2D] = []

# ── Difficulty Curve ──────────────────────────────────────────────────

## Number of enemies on wave 1. Grows by `enemies_per_wave` each wave.
@export var base_enemy_count: int = 3

## How many additional enemies spawn per wave.
## Example: 2.5 means wave 1 = 3, wave 2 = ~5, wave 3 = ~8, etc.
@export var enemies_per_wave: float = 2.5

## Hard cap on enemies per wave regardless of scaling.
## Raise this to support massive waves. Default 300 is enough for most runs.
## Note: very high counts (500+) may affect performance depending on enemy complexity.
@export var max_enemy_count: int = 300

## Base time in seconds between enemy spawns at low wave counts.
## Scales down automatically as enemy count grows so large waves rush in fast.
## See min_spawn_stagger for the floor.
@export var spawn_stagger: float = 0.08

## Minimum seconds between spawns regardless of wave size.
## Prevents spawn stagger from reaching zero on very large waves.
## Lower = more aggressive rush. 0.03 is about as fast as feels intentional.
@export var min_spawn_stagger: float = 0.01

## Enemy health exponential growth factor per wave.
## Each wave multiplies enemy health by (1 + health_scale) compounding.
## 0.20 = wave 5 enemies have ~2x health, wave 10 = ~5x, wave 20 = ~32x.
## Lower toward 0.10 for a gentler curve, raise toward 0.25 for brutal scaling.
@export var health_scale: float = 0.20

## Enemy damage multiplier increase per wave.
## 0.15 = enemies deal 15% more damage each wave.
@export var damage_scale: float = 0.15

## Enemy move speed multiplier increase per wave.
## 0.08 = enemies move 8% faster each wave. Keeps late waves feeling dangerous.
@export var speed_scale: float = 0.08

## A boss wave spawns every N waves. Default 5 = waves 5, 10, 15, etc.
## Boss waves spawn a regular wave PLUS one boss from `boss_scenes`.
@export var boss_interval: int = 5

## Boss health multiplier applied on top of the wave's normal health scaling.
## 3.5 = boss has 3.5× the health of a regular enemy that wave.
@export var boss_health_mult: float = 3.5

## Boss damage multiplier applied on top of normal damage scaling.
@export var boss_damage_mult: float = 2.0

## Boss speed multiplier. Less than 1.0 makes bosses slower than regular enemies
## so they feel heavy and deliberate rather than just a fast regular enemy.
@export var boss_speed_mult: float = 0.7

# ── Internal State ────────────────────────────────────────────────────
enum State { WAITING, SPAWNING, WAVE_ACTIVE, WAVE_COMPLETE, COUNTDOWN, BETWEEN_WAVES }
var state: State          = State.WAITING
var current_wave: int     = 0
var alive_enemies: Array[Node2D] = []
var total_spawned: int    = 0

# ══════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════

func _ready() -> void:
	if shop_scene:
		shop_ui = shop_scene.instantiate() as ShopUI
		get_tree().current_scene.add_child.call_deferred(shop_ui)
	else:
		push_warning("WaveManager: shop_scene not assigned")

	_create_countdown_ui()

	# Short delay so the scene fully loads before wave 1 starts
	await get_tree().create_timer(3.0).timeout
	start_next_wave()


func _create_countdown_ui() -> void:
	var countdown_script := load("res://scripts/wave_countdown_ui.gd")
	if countdown_script:
		countdown_ui = countdown_script.new() as CanvasLayer
		get_tree().current_scene.add_child.call_deferred(countdown_ui)
		countdown_ui.countdown_finished.connect(_on_countdown_finished)
	else:
		push_warning("WaveManager: Could not load wave_countdown_ui.gd")

# ══════════════════════════════════════════════════════════════════════
# WAVE CONTROL
# ══════════════════════════════════════════════════════════════════════

func start_next_wave() -> void:
	if state != State.WAITING and state != State.BETWEEN_WAVES:
		return

	current_wave += 1
	var wave_data := _generate_wave(current_wave)
	total_spawned = wave_data.total_count
	state         = State.SPAWNING

	if wave_data.is_boss:
		boss_wave_started.emit(current_wave)
	wave_started.emit(current_wave)

	# Sync wave number to PlayerInventory so Projectile can read it
	# for elemental damage scaling without a direct WaveManager reference
	PlayerInventory.current_wave = current_wave

	# Reset damage meter so wave breakdown starts fresh
	DamageMeter.reset()

	await _spawn_wave(wave_data)

	if alive_enemies.is_empty():
		_on_wave_cleared()
	else:
		state = State.WAVE_ACTIVE


func get_wave_info() -> Dictionary:
	return {
		"wave":         current_wave,
		"alive":        alive_enemies.size(),
		"total":        total_spawned,
		"state":        State.keys()[state],
		"is_boss_wave": current_wave > 0 and current_wave % boss_interval == 0,
	}

# ══════════════════════════════════════════════════════════════════════
# WAVE GENERATION
# ══════════════════════════════════════════════════════════════════════

func _generate_wave(wave_num: int) -> Dictionary:
	var is_boss := wave_num % boss_interval == 0
	var count   := mini(base_enemy_count + int(wave_num * enemies_per_wave), max_enemy_count)

	# Exponential health scaling — each wave multiplies health by (1 + health_scale).
	# Wave 5 with 0.20 = 2.07x base health. Wave 10 = 5.16x. Wave 20 = 31.9x.
	# Lower health_scale (e.g. 0.12) for a gentler curve, higher for brutal late waves.
	var h_mult := pow(1.0 + health_scale, wave_num - 1)

	# Damage and speed stay linear — only health scales exponentially.
	# This keeps late-wave enemies feeling tanky without becoming instant-kill machines.
	var d_mult := 1.0 + (wave_num - 1) * damage_scale
	var s_mult := 1.0 + (wave_num - 1) * speed_scale

	return {
		"count":       count,
		"total_count": count + (1 if is_boss else 0),
		"health_mult": h_mult,
		"damage_mult": d_mult,
		"speed_mult":  s_mult,
		"is_boss":     is_boss,
		"scenes":      _get_unlocked_enemies(wave_num),
	}


func _get_unlocked_enemies(wave_num: int) -> Array[PackedScene]:
	var unlocked: Array[PackedScene] = []
	for i in enemy_scenes.size():
		# Each additional enemy type unlocks after waves_per_unlock more waves
		var unlock_at := i * waves_per_unlock + 1
		if wave_num >= unlock_at:
			unlocked.append(enemy_scenes[i])
	# Always fall back to the first enemy type if nothing else is available
	if unlocked.is_empty() and not enemy_scenes.is_empty():
		unlocked.append(enemy_scenes[0])
	return unlocked

# ══════════════════════════════════════════════════════════════════════
# SPAWNING
# ══════════════════════════════════════════════════════════════════════

func _spawn_wave(wave_data: Dictionary) -> void:
	# Dynamic stagger — shrinks as enemy count grows so large waves rush in.
	# Formula: base stagger divided by a factor that grows with enemy count.
	# 10 enemies ≈ 0.05s gap, 50+ enemies hits min_spawn_stagger (0.01s) — near-instant.
	var dynamic_stagger: float = max(
		min_spawn_stagger,
		spawn_stagger / (1.0 + wave_data.count * 0.15)
	)

	for i in wave_data.count:
		if state == State.SPAWNING:
			_spawn_enemy(
				wave_data.scenes.pick_random(),
				wave_data.health_mult,
				wave_data.damage_mult,
				wave_data.speed_mult,
				false
			)
			# Stagger spawns so enemies don't all arrive simultaneously
			if dynamic_stagger > 0 and i < wave_data.count - 1:
				await get_tree().create_timer(dynamic_stagger).timeout

	if wave_data.is_boss and not boss_scenes.is_empty():
		# Extra pause before the boss arrives for dramatic effect
		if dynamic_stagger > 0:
			await get_tree().create_timer(dynamic_stagger * 2).timeout
		_spawn_enemy(
			boss_scenes.pick_random(),
			wave_data.health_mult * boss_health_mult,
			wave_data.damage_mult * boss_damage_mult,
			wave_data.speed_mult  * boss_speed_mult,
			true
		)


func _spawn_enemy(
	scene: PackedScene,
	h_mult: float,
	d_mult: float,
	s_mult: float,
	is_boss: bool
) -> void:
	# Roll to see if this regular enemy upgrades to an elite
	if not is_boss and current_wave >= elite_start_wave and not elite_scenes.is_empty():
		var elite_chance: float = clamp(
			elite_base_chance + elite_wave_scaling * (current_wave - elite_start_wave),
			0.0, 0.40
		)
		if randf() < elite_chance:
			# Swap the scene for a random elite variant
			scene = elite_scenes.pick_random()

	var enemy := scene.instantiate() as Node2D
	if enemy == null:
		push_warning("WaveManager: scene root is not Node2D.")
		return

	enemy.global_position = _random_spawn_pos()
	get_tree().current_scene.add_child(enemy)

	# Assign player as the movement target
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and enemy.has_method("set_target"):
		enemy.set_target(players[0])

	# Gold drops scale with wave so later waves feel more rewarding
	var g_mult := 1.0 + (current_wave - 1) * 0.12
	if enemy.has_method("set_gold_multiplier"):
		enemy.set_gold_multiplier(g_mult)

	# Apply speed scaling directly to move_speed if the property exists
	if "move_speed" in enemy:
		enemy.move_speed *= s_mult

	# Scale HealthComponent values if present
	var hc := enemy.get_node_or_null("HealthComponent") as Node
	if hc and "max_health" in hc:
		hc.max_health = int(hc.max_health * h_mult)
		if "current_health" in hc:
			hc.current_health = hc.max_health

	# Scale damage — check root node first, then StatsComponent as fallback
	if "damage" in enemy:
		enemy.damage *= d_mult
	else:
		var stats := enemy.get_node_or_null("StatsComponent") as Node
		if stats and "damage" in stats:
			stats.damage *= d_mult

	# Give bosses a red tint so players immediately recognise them
	if is_boss and enemy.has_node("AnimatedSprite2D"):
		var sprite := enemy.get_node("AnimatedSprite2D")
		if sprite is AnimatedSprite2D:
			(sprite as AnimatedSprite2D).modulate = Color(1.2, 0.8, 0.8)

	alive_enemies.append(enemy)
	enemy.tree_exiting.connect(_on_enemy_died.bind(enemy))
	enemy_count_changed.emit(alive_enemies.size(), total_spawned)

	# If the spawned scene has an AffixComponent, roll and apply affixes
	var affix_comp := enemy.get_node_or_null("AffixComponent") as AffixComponent
	if affix_comp != null:
		var affix_count: int    = randi_range(1, elite_max_affixes)
		var rolled: Array[AffixData] = AffixTable.roll(affix_count, current_wave)
		if not rolled.is_empty():
			affix_comp.apply_affixes(rolled)
			print("[ELITE] Spawned with: ",
				rolled.map(func(a: AffixData) -> String: return a.display_name))


func _random_spawn_pos() -> Vector2:
	var center := Vector2.ZERO
	if not spawn_points.is_empty():
		var point: Marker2D = spawn_points.pick_random()
		if is_instance_valid(point):
			center = point.global_position

	# Spawn within a ring (not a filled circle) so enemies don't appear directly on top of the player
	var angle := randf() * TAU
	var dist  := randf_range(spawn_radius * 0.6, spawn_radius)
	return center + Vector2(cos(angle), sin(angle)) * dist

# ══════════════════════════════════════════════════════════════════════
# WAVE STATE TRANSITIONS
# ══════════════════════════════════════════════════════════════════════

func _on_enemy_died(enemy: Node2D) -> void:
	alive_enemies.erase(enemy)
	enemy_count_changed.emit(alive_enemies.size(), total_spawned)

	# Last enemy died during an active wave — trigger wave clear
	if alive_enemies.is_empty() and state == State.WAVE_ACTIVE:
		_on_wave_cleared()


func _on_wave_cleared() -> void:
	state = State.WAVE_COMPLETE
	wave_completed.emit(current_wave)

	# Destroy all in-flight projectiles so the player can't die
	# from a stray shot after the last enemy is gone
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		if is_instance_valid(projectile):
			projectile.queue_free()

	state = State.COUNTDOWN
	if countdown_ui:
		countdown_ui.start_countdown(countdown_seconds)
	else:
		# Fallback if countdown UI failed to load
		await get_tree().create_timer(countdown_seconds).timeout
		_on_countdown_finished()


func _on_countdown_finished() -> void:
	# Remove loaned elements before the shop so combinations reset cleanly
	PlayerInventory.clear_wave_temporary_powerups()

	# Open the shop on shop waves
	if current_wave % shop_interval == 0 and shop_ui != null:
		await _open_shop(current_wave)

	state = State.BETWEEN_WAVES
	between_waves_started.emit(current_wave)

	# Short pause before the next wave starts automatically
	await get_tree().create_timer(2.0).timeout
	start_next_wave()


func _open_shop(wave_number: int) -> void:
	if not shop_ui or not loot_table:
		push_warning("WaveManager: Shop UI or Loot Table not assigned")
		return
	shop_ui.open_shop(wave_number, loot_table)
	await shop_ui.shop_closed
