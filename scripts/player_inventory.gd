extends Node

## Elemental combination enum
enum ElementalCombo {
	NONE,
	THERMAL_SHOCK,      # Fire + Ice
	PLASMA_CASCADE,     # Fire + Lightning
	CORROSIVE_MELT,     # Fire + Poison
	FROST_PULSE,        # Ice + Lightning
	WITHERING_TOUCH,    # Ice + Poison
	VIRAL_SPREAD        # Lightning + Poison
}

# ── Signals ───────────────────────────────────────────────────────────
signal gold_changed(new_amount: int)
signal powerup_collected(powerup: PowerUpData, new_rank: int)
signal equipment_changed
signal wave_temporary_powerups_changed

# ── Gold ──────────────────────────────────────────────────────────────
var gold: int = 0

# ── Elemental Combination ─────────────────────────────────────────────
var active_combinations: Array[ElementalCombo] = []

# ── Wave Tracking ─────────────────────────────────────────────────────
var current_wave: int = 1

# ── Permanent Powerups ────────────────────────────────────────────────
var collected_powerups: Dictionary = {}
var equipped_powerups: Array[String] = []

# ── Wave-Temporary Powerups ───────────────────────────────────────────
var wave_temporary_powerups: Array[PowerUpData] = []

# ══════════════════════════════════════════════════════════════════════
# GOLD
# ══════════════════════════════════════════════════════════════════════

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		return true
	return false


func set_gold(amount: int) -> void:
	gold = amount
	gold_changed.emit(gold)

# ══════════════════════════════════════════════════════════════════════
# RANK-BASED POWERUP MANAGEMENT
# ══════════════════════════════════════════════════════════════════════

func collect_powerup(powerup: PowerUpData) -> void:
	if powerup == null:
		return

	var id := powerup.id

	if id in collected_powerups:
		var entry: Dictionary = collected_powerups[id]
		var current_rank: int = entry.rank
		var max_rank: int     = powerup.max_stacks

		if current_rank < max_rank:
			entry.rank += 1
			print("Ranked up %s: %d → %d" % [powerup.display_name, current_rank, entry.rank])
			powerup_collected.emit(powerup, entry.rank)
			_detect_elemental_combination()
			equipment_changed.emit()
		else:
			print("%s is already at max rank (%d)" % [powerup.display_name, max_rank])
	else:
		collected_powerups[id] = { "powerup": powerup, "rank": 1 }
		print("Acquired %s at Rank 1" % powerup.display_name)
		powerup_collected.emit(powerup, 1)


func get_powerup_rank(powerup: PowerUpData) -> int:
	if powerup == null:
		return 0
	if powerup.id in collected_powerups:
		return collected_powerups[powerup.id].rank
	return 0


func has_powerup(powerup: PowerUpData) -> bool:
	if powerup == null:
		return false
	return powerup.id in collected_powerups


func get_collected_powerups() -> Array[PowerUpData]:
	var powerups: Array[PowerUpData] = []
	for entry in collected_powerups.values():
		powerups.append(entry.powerup)
	return powerups


func get_powerup_entry(powerup_id: String) -> Dictionary:
	if powerup_id in collected_powerups:
		return collected_powerups[powerup_id]
	return {}

# ══════════════════════════════════════════════════════════════════════
# EQUIPMENT
# ══════════════════════════════════════════════════════════════════════

func equip_powerup(powerup: PowerUpData) -> bool:
	if powerup == null:
		return false
	if not has_powerup(powerup):
		print("Cannot equip %s: not in collection" % powerup.display_name)
		return false
	if is_equipped(powerup):
		return false

	equipped_powerups.append(powerup.id)
	_detect_elemental_combination()
	equipment_changed.emit()
	return true


func unequip_powerup(powerup: PowerUpData) -> bool:
	if powerup == null:
		return false

	var idx := equipped_powerups.find(powerup.id)
	if idx == -1:
		return false

	equipped_powerups.remove_at(idx)
	_detect_elemental_combination()
	equipment_changed.emit()
	return true


func get_equipped_powerups_with_ranks() -> Array[Dictionary]:
	var equipped: Array[Dictionary] = []
	for powerup_id in equipped_powerups:
		if powerup_id in collected_powerups:
			equipped.append(collected_powerups[powerup_id])
	return equipped


func get_equipped_powerups() -> Array[PowerUpData]:
	var powerups: Array[PowerUpData] = []
	for entry in get_equipped_powerups_with_ranks():
		powerups.append(entry.powerup)
	return powerups


func is_equipped(powerup: PowerUpData) -> bool:
	if powerup == null:
		return false
	return powerup.id in equipped_powerups


func clear_equipment() -> void:
	equipped_powerups.clear()
	_detect_elemental_combination()
	equipment_changed.emit()


## Returns how many projectile type powerups are currently equipped.
func get_equipped_projectile_count() -> int:
	var count := 0
	for powerup_id in equipped_powerups:
		if powerup_id in collected_powerups:
			var powerup: PowerUpData = collected_powerups[powerup_id].powerup
			if "projectile_type" in powerup and powerup.projectile_type != PowerUpData.ProjectileType.NONE:
				count += 1
	return count


## Returns up to two equipped projectile type powerups.
## First = primary (movement). Second = secondary (impact).
func get_active_projectile_powerups() -> Array[PowerUpData]:
	var result: Array[PowerUpData] = []
	for powerup_id in equipped_powerups:
		if powerup_id in collected_powerups:
			var powerup: PowerUpData = collected_powerups[powerup_id].powerup
			if "projectile_type" in powerup and powerup.projectile_type != PowerUpData.ProjectileType.NONE:
				result.append(powerup)
				if result.size() >= 2:
					break
	return result

# ══════════════════════════════════════════════════════════════════════
# WAVE-TEMPORARY POWERUPS
# ══════════════════════════════════════════════════════════════════════

func apply_wave_temporary_powerup(powerup: PowerUpData) -> void:
	if powerup == null:
		return
	wave_temporary_powerups.append(powerup)
	# Detect combinations immediately — a loaned element may complete a combo
	_detect_elemental_combination()
	wave_temporary_powerups_changed.emit()
	print("Applied wave-temporary powerup: ", powerup.display_name)


func get_wave_temporary_powerups() -> Array[PowerUpData]:
	return wave_temporary_powerups


func clear_wave_temporary_powerups() -> void:
	if wave_temporary_powerups.is_empty():
		return
	print("Clearing ", wave_temporary_powerups.size(), " wave-temporary powerups")
	wave_temporary_powerups.clear()
	# Re-detect so any loaned combinations are removed
	_detect_elemental_combination()
	wave_temporary_powerups_changed.emit()

# ══════════════════════════════════════════════════════════════════════
# ELEMENTAL COMBINATION DETECTION
# ══════════════════════════════════════════════════════════════════════

func _detect_elemental_combination() -> void:
	active_combinations.clear()

	var available: Array = []

	# Scan permanently equipped powerups
	for powerup_id in equipped_powerups:
		if powerup_id in collected_powerups:
			var powerup: PowerUpData = collected_powerups[powerup_id].powerup
			if powerup and "element_type" in powerup and powerup.element_type != 0:
				if not available.has(powerup.element_type):
					available.append(powerup.element_type)

	# Also scan wave-temporary powerups — loaned elements count toward combinations.
	# This is the mechanic that lets "borrowing" Fire while having Ice trigger Shatter.
	for powerup in wave_temporary_powerups:
		if powerup and "element_type" in powerup and powerup.element_type != 0:
			if not available.has(powerup.element_type):
				available.append(powerup.element_type)

	if available.size() < 2:
		return

	var priority: Array = [
		[ElementalCombo.THERMAL_SHOCK,   1, 2],
		[ElementalCombo.VIRAL_SPREAD,    3, 4],
		[ElementalCombo.PLASMA_CASCADE,  1, 3],
		[ElementalCombo.WITHERING_TOUCH, 2, 4],
		[ElementalCombo.CORROSIVE_MELT,  1, 4],
		[ElementalCombo.FROST_PULSE,     2, 3],
	]

	var remaining: Array = available.duplicate()

	for combo_def in priority:
		var combo: ElementalCombo = combo_def[0]
		var el1: int              = combo_def[1]
		var el2: int              = combo_def[2]

		if remaining.has(el1) and remaining.has(el2):
			active_combinations.append(combo)
			remaining.erase(el1)
			remaining.erase(el2)
			if remaining.size() < 2:
				break


func get_combination_names() -> Array[String]:
	var names: Array[String] = []
	for combo in active_combinations:
		names.append(_combo_to_name(combo))
	return names


func get_combination_elements_list() -> Array[String]:
	var list: Array[String] = []
	for combo in active_combinations:
		list.append(_combo_to_elements(combo))
	return list


func get_combination_name() -> String:
	if active_combinations.is_empty():
		return ""
	return _combo_to_name(active_combinations[0])


func get_combination_elements() -> String:
	if active_combinations.is_empty():
		return ""
	return _combo_to_elements(active_combinations[0])


func _combo_to_name(combo: ElementalCombo) -> String:
	match combo:
		ElementalCombo.THERMAL_SHOCK:   return "SHATTER"
		ElementalCombo.PLASMA_CASCADE:  return "SUPERHEATED ARC"
		ElementalCombo.CORROSIVE_MELT:  return "ACID CLOUD"
		ElementalCombo.FROST_PULSE:     return "MAGNETIC FREEZE"
		ElementalCombo.WITHERING_TOUCH: return "CRYSTALLIZE"
		ElementalCombo.VIRAL_SPREAD:    return "CONTAGION PULSE"
		_: return ""


func _combo_to_elements(combo: ElementalCombo) -> String:
	match combo:
		ElementalCombo.THERMAL_SHOCK:   return "FIRE + ICE"
		ElementalCombo.PLASMA_CASCADE:  return "FIRE + LIGHTNING"
		ElementalCombo.CORROSIVE_MELT:  return "FIRE + POISON"
		ElementalCombo.FROST_PULSE:     return "ICE + LIGHTNING"
		ElementalCombo.WITHERING_TOUCH: return "ICE + POISON"
		ElementalCombo.VIRAL_SPREAD:    return "LIGHTNING + POISON"
		_: return ""

# ══════════════════════════════════════════════════════════════════════
# BUILD MANAGEMENT
# ══════════════════════════════════════════════════════════════════════

func save_equipment_build() -> Array:
	return equipped_powerups.duplicate()


func load_equipment_build(build: Array) -> void:
	equipped_powerups.clear()
	for powerup_id in build:
		if powerup_id in collected_powerups:
			equipped_powerups.append(powerup_id)
	_detect_elemental_combination()
	equipment_changed.emit()


func reset_for_new_run() -> void:
	gold = 0
	current_wave = 1
	collected_powerups.clear()
	wave_temporary_powerups.clear()
	active_combinations.clear()
	clear_equipment()
	gold_changed.emit(0)
	wave_temporary_powerups_changed.emit()
