extends Node
class_name StatsComponent

# ══════════════════════════════════════════════════════════════════════
# BASE STATS (never modified - these are your starting values)
# ══════════════════════════════════════════════════════════════════════

@export var base_damage: float = 10.0
@export var base_move_speed: float = 300.0
@export var base_attack_speed: float = 1.0
@export var base_projectile_speed: float = 500.0
@export var base_projectile_count: int = 1
@export var base_projectile_pierce: int = 0
@export var base_pickup_range: float = 48.0
@export var base_gold_multiplier: float = 1.0
@export var base_luck: float = 0.0
@export var base_crit_chance: float = 0.05
@export var base_crit_multiplier: float = 2.0

# ══════════════════════════════════════════════════════════════════════
# CURRENT STATS (modified by powerups - what the game actually uses)
# ══════════════════════════════════════════════════════════════════════

var damage: float = 10.0
var move_speed: float = 300.0
var attack_speed: float = 1.0
var projectile_speed: float = 500.0
var projectile_count: int = 1
var projectile_pierce: int = 0
var pickup_range: float = 48.0
var gold_multiplier: float = 1.0
var luck: float = 0.0
var crit_chance: float = 0.05
var crit_multiplier: float = 2.0

var gold: int = 0

# ══════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ══════════════════════════════════════════════════════════════════════

func _ready() -> void:
	if not PlayerInventory.equipment_changed.is_connected(_on_equipment_changed):
		PlayerInventory.equipment_changed.connect(_on_equipment_changed)

	# Also recalculate when wave-temporary pickups are collected or cleared
	if not PlayerInventory.wave_temporary_powerups_changed.is_connected(_on_equipment_changed):
		PlayerInventory.wave_temporary_powerups_changed.connect(_on_equipment_changed)

	recalculate_stats()


func _on_equipment_changed() -> void:
	recalculate_stats()


func recalculate_stats() -> void:
	# Reset all stats to base values
	damage = base_damage
	move_speed = base_move_speed
	attack_speed = base_attack_speed
	projectile_speed = base_projectile_speed
	projectile_count = base_projectile_count
	projectile_pierce = base_projectile_pierce
	pickup_range = base_pickup_range
	gold_multiplier = base_gold_multiplier
	luck = base_luck
	crit_chance = base_crit_chance
	crit_multiplier = base_crit_multiplier
	
	# Get all equipped powerups with their ranks from PlayerInventory
	var equipped := PlayerInventory.get_equipped_powerups_with_ranks()

	# Collect modifiers by stat and type
	# Structure: { "damage": { flat: 15.0, percentage: 2.5 }, ... }
	var modifiers := {}

	# Process each equipped powerup
	for entry in equipped:
		var powerup: PowerUpData = entry.powerup
		var rank: int = entry.rank

		if powerup.stat_to_modify == "":
			continue

		if not modifiers.has(powerup.stat_to_modify):
			modifiers[powerup.stat_to_modify] = { "flat": 0.0, "percentage": 0.0 }

		var total_amount := powerup.amount * rank

		if powerup.modifier_type == PowerUpData.ModifierType.FLAT:
			modifiers[powerup.stat_to_modify].flat += total_amount
		else:
			modifiers[powerup.stat_to_modify].percentage += total_amount

	# Apply wave-temporary powerups at rank 1 on top of equipped stats.
	# These are combat drops that expire at wave end.
	for powerup in PlayerInventory.get_wave_temporary_powerups():
		if powerup == null or powerup.stat_to_modify == "":
			continue

		if not modifiers.has(powerup.stat_to_modify):
			modifiers[powerup.stat_to_modify] = { "flat": 0.0, "percentage": 0.0 }

		if powerup.modifier_type == PowerUpData.ModifierType.FLAT:
			modifiers[powerup.stat_to_modify].flat += powerup.amount
		else:
			modifiers[powerup.stat_to_modify].percentage += powerup.amount
	
	# Apply all modifiers using Warframe formula:
	# final_stat = base_stat × (1 + sum_of_percentages) + sum_of_flats
	
	if modifiers.has("damage"):
		damage = base_damage * (1.0 + modifiers.damage.percentage) + modifiers.damage.flat
	
	if modifiers.has("move_speed"):
		move_speed = base_move_speed * (1.0 + modifiers.move_speed.percentage) + modifiers.move_speed.flat
	
	if modifiers.has("attack_speed"):
		attack_speed = base_attack_speed * (1.0 + modifiers.attack_speed.percentage) + modifiers.attack_speed.flat
	
	if modifiers.has("projectile_speed"):
		projectile_speed = base_projectile_speed * (1.0 + modifiers.projectile_speed.percentage) + modifiers.projectile_speed.flat
	
	if modifiers.has("pickup_range"):
		pickup_range = base_pickup_range * (1.0 + modifiers.pickup_range.percentage) + modifiers.pickup_range.flat
	
	if modifiers.has("gold_multiplier"):
		gold_multiplier = base_gold_multiplier * (1.0 + modifiers.gold_multiplier.percentage) + modifiers.gold_multiplier.flat
	
	if modifiers.has("luck"):
		luck = base_luck * (1.0 + modifiers.luck.percentage) + modifiers.luck.flat
	
	if modifiers.has("crit_chance"):
		crit_chance = base_crit_chance * (1.0 + modifiers.crit_chance.percentage) + modifiers.crit_chance.flat
		crit_chance = clamp(crit_chance, 0.0, 1.0)  # Cap at 100%
	
	if modifiers.has("crit_multiplier"):
		crit_multiplier = base_crit_multiplier * (1.0 + modifiers.crit_multiplier.percentage) + modifiers.crit_multiplier.flat
	
	if modifiers.has("projectile_count"):
		var count_value: float = float(base_projectile_count) * (1.0 + modifiers.projectile_count.percentage) + modifiers.projectile_count.flat
		projectile_count = int(count_value)
	
	if modifiers.has("projectile_pierce"):
		var pierce_value: float = float(base_projectile_pierce) * (1.0 + modifiers.projectile_pierce.percentage) + modifiers.projectile_pierce.flat
		projectile_pierce = int(pierce_value)

# ══════════════════════════════════════════════════════════════════════
# GOLD MANAGEMENT
# ══════════════════════════════════════════════════════════════════════

func add_gold(amount: int) -> void:
	var final_amount := int(round(amount * gold_multiplier))
	gold += final_amount
	PlayerInventory.add_gold(final_amount)

# ══════════════════════════════════════════════════════════════════════
# DEBUG HELPERS
# ══════════════════════════════════════════════════════════════════════

func get_stat_summary() -> String:
	return """Damage: %.1f (base: %.1f)
Move Speed: %.1f (base: %.1f)
Attack Speed: %.2f (base: %.2f)
Projectile Speed: %.1f (base: %.1f)
Projectile Count: %d (base: %d)
Projectile Pierce: %d (base: %d)
Pickup Range: %.1f (base: %.1f)
Gold Mult: %.2f (base: %.2f)
Crit Chance: %.1f%% (base: %.1f%%)
Crit Mult: %.2fx (base: %.2fx)""" % [
		damage, base_damage,
		move_speed, base_move_speed,
		attack_speed, base_attack_speed,
		projectile_speed, base_projectile_speed,
		projectile_count, base_projectile_count,
		projectile_pierce, base_projectile_pierce,
		pickup_range, base_pickup_range,
		gold_multiplier, base_gold_multiplier,
		crit_chance * 100, base_crit_chance * 100,
		crit_multiplier, base_crit_multiplier
	]
