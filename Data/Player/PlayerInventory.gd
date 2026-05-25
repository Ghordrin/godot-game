extends Node

## Elemental combination enum
enum ElementalCombo {
	NONE,
	THERMAL,      # Fire + Ice
	PLASMA,       # Fire + Lightning
	CORROSIVE,    # Fire + Poison
	MAGNETIC,     # Ice + Lightning
	VIRAL,        # Ice + Poison
	NEUROTOXIN,   # Lightning + Poison
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
		var max_rank: int = powerup.max_stacks

		if current_rank < max_rank:
			entry.rank += 1
			print("Ranked up %s: %d → %d" % [powerup.display_name, current_rank, entry.rank])
			powerup_collected.emit(powerup, entry.rank)
			_detect_elemental_combination()
			equipment_changed.emit()
		else:
			print("%s is already at max rank (%d)" % [powerup.display_name, max_rank])
	else:
		collected_powerups[id] = {
			"powerup": powerup,
			"rank": 1
		}

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

	var index := equipped_powerups.find(powerup.id)

	if index == -1:
		return false

	equipped_powerups.remove_at(index)
	_detect_elemental_combination()
	equipment_changed.emit()

	return true


func get_equipped_powerups_with_ranks() -> Array[Dictionary]:
	var equipped: Array[Dictionary] = []

	for powerup_id in equipped_powerups:
		if powerup_id in collected_powerups:
			equipped.append(collected_powerups[powerup_id])

	return equipped


func get_active_damage_powerups_with_ranks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for entry: Dictionary in get_equipped_powerups_with_ranks():
		result.append(entry)

	for powerup: PowerUpData in wave_temporary_powerups:
		if powerup == null:
			continue

		result.append({
			"powerup": powerup,
			"rank": 1,
			"temporary": true
		})

	return result


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


func get_equipped_projectile_count() -> int:
	var count := 0

	for powerup_id in equipped_powerups:
		if powerup_id in collected_powerups:
			var powerup: PowerUpData = collected_powerups[powerup_id].powerup

			if _is_projectile_powerup(powerup):
				count += 1

	return count


func get_active_projectile_powerups() -> Array[PowerUpData]:
	var result: Array[PowerUpData] = []

	# Permanent equipped projectile comes first.
	for powerup_id in equipped_powerups:
		if not powerup_id in collected_powerups:
			continue

		var powerup: PowerUpData = collected_powerups[powerup_id].powerup

		if not _is_projectile_powerup(powerup):
			continue

		result.append(powerup)

		if result.size() >= 2:
			return result

	# Wave-temporary projectile pickups also count as active projectile behavior.
	# This fixes combat drops like Boulder Shot not applying after pickup.
	for powerup: PowerUpData in wave_temporary_powerups:
		if powerup == null:
			continue

		if not _is_projectile_powerup(powerup):
			continue

		# Avoid duplicate projectile type stacking for now.
		if _has_projectile_type(result, powerup.projectile_type):
			continue

		result.append(powerup)

		if result.size() >= 2:
			break

	return result


func get_active_projectile_powerups_with_ranks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for powerup_id in equipped_powerups:
		if not powerup_id in collected_powerups:
			continue

		var entry: Dictionary = collected_powerups[powerup_id]
		var powerup: PowerUpData = entry.powerup

		if not _is_projectile_powerup(powerup):
			continue

		result.append(entry)

		if result.size() >= 2:
			return result

	for powerup: PowerUpData in wave_temporary_powerups:
		if powerup == null:
			continue

		if not _is_projectile_powerup(powerup):
			continue

		if _has_projectile_type_from_entries(result, powerup.projectile_type):
			continue

		result.append({
			"powerup": powerup,
			"rank": 1,
			"temporary": true
		})

		if result.size() >= 2:
			break

	return result


func _is_projectile_powerup(powerup: PowerUpData) -> bool:
	if powerup == null:
		return false

	if not "projectile_type" in powerup:
		return false

	return powerup.projectile_type != PowerUpData.ProjectileType.NONE


func _has_projectile_type(powerups: Array[PowerUpData], projectile_type: int) -> bool:
	for powerup in powerups:
		if powerup == null:
			continue

		if powerup.projectile_type == projectile_type:
			return true

	return false


func _has_projectile_type_from_entries(entries: Array[Dictionary], projectile_type: int) -> bool:
	for entry in entries:
		if not entry.has("powerup"):
			continue

		var powerup: PowerUpData = entry.powerup

		if powerup == null:
			continue

		if powerup.projectile_type == projectile_type:
			return true

	return false


# ══════════════════════════════════════════════════════════════════════
# WAVE-TEMPORARY POWERUPS
# ══════════════════════════════════════════════════════════════════════

func apply_wave_temporary_powerup(powerup: PowerUpData) -> void:
	if powerup == null:
		return

	# Avoid duplicate temporary projectile types.
	# Example: picking up Boulder Shot twice should not silently create weird secondary behavior.
	if _is_projectile_powerup(powerup):
		for existing in wave_temporary_powerups:
			if existing == null:
				continue

			if _is_projectile_powerup(existing) and existing.projectile_type == powerup.projectile_type:
				print("Wave-temporary projectile already active: ", powerup.display_name)
				return

	wave_temporary_powerups.append(powerup)
	_detect_elemental_combination()
	wave_temporary_powerups_changed.emit()
	equipment_changed.emit()

	print("Applied wave-temporary powerup: ", powerup.display_name)


func get_wave_temporary_powerups() -> Array[PowerUpData]:
	return wave_temporary_powerups


func clear_wave_temporary_powerups() -> void:
	if wave_temporary_powerups.is_empty():
		return

	print("Clearing ", wave_temporary_powerups.size(), " wave-temporary powerups")

	wave_temporary_powerups.clear()
	_detect_elemental_combination()
	wave_temporary_powerups_changed.emit()
	equipment_changed.emit()


# ══════════════════════════════════════════════════════════════════════
# ELEMENTAL COMBINATION DETECTION
# ══════════════════════════════════════════════════════════════════════

func _detect_elemental_combination() -> void:
	active_combinations.clear()

	var available_elements: Array[int] = _get_active_element_types_in_order()

	while available_elements.size() >= 2:
		var first: int = available_elements[0]
		var second: int = available_elements[1]
		var combo: ElementalCombo = _get_combo_for_elements(first, second)

		if combo == ElementalCombo.NONE:
			break

		active_combinations.append(combo)
		available_elements.remove_at(1)
		available_elements.remove_at(0)


func _get_active_element_types_in_order() -> Array[int]:
	var result: Array[int] = []

	for powerup_id in equipped_powerups:
		if not powerup_id in collected_powerups:
			continue

		var powerup: PowerUpData = collected_powerups[powerup_id].powerup
		_add_element_if_valid(result, powerup)

	for powerup: PowerUpData in wave_temporary_powerups:
		_add_element_if_valid(result, powerup)

	return result


func _add_element_if_valid(result: Array[int], powerup: PowerUpData) -> void:
	if powerup == null:
		return

	if not "element_type" in powerup:
		return

	if powerup.element_type == PowerUpData.ElementType.NONE:
		return

	if result.has(powerup.element_type):
		return

	result.append(powerup.element_type)


func _get_combo_for_elements(a: int, b: int) -> ElementalCombo:
	if _same_element_pair(a, b, PowerUpData.ElementType.FIRE, PowerUpData.ElementType.ICE):
		return ElementalCombo.THERMAL

	if _same_element_pair(a, b, PowerUpData.ElementType.FIRE, PowerUpData.ElementType.LIGHTNING):
		return ElementalCombo.PLASMA

	if _same_element_pair(a, b, PowerUpData.ElementType.FIRE, PowerUpData.ElementType.POISON):
		return ElementalCombo.CORROSIVE

	if _same_element_pair(a, b, PowerUpData.ElementType.ICE, PowerUpData.ElementType.LIGHTNING):
		return ElementalCombo.MAGNETIC

	if _same_element_pair(a, b, PowerUpData.ElementType.ICE, PowerUpData.ElementType.POISON):
		return ElementalCombo.VIRAL

	if _same_element_pair(a, b, PowerUpData.ElementType.LIGHTNING, PowerUpData.ElementType.POISON):
		return ElementalCombo.NEUROTOXIN

	return ElementalCombo.NONE


func _same_element_pair(a: int, b: int, x: int, y: int) -> bool:
	return (a == x and b == y) or (a == y and b == x)


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
		ElementalCombo.THERMAL:
			return "THERMAL"
		ElementalCombo.PLASMA:
			return "PLASMA"
		ElementalCombo.CORROSIVE:
			return "CORROSIVE"
		ElementalCombo.MAGNETIC:
			return "MAGNETIC"
		ElementalCombo.VIRAL:
			return "VIRAL"
		ElementalCombo.NEUROTOXIN:
			return "NEUROTOXIN"
		_:
			return ""


func _combo_to_elements(combo: ElementalCombo) -> String:
	match combo:
		ElementalCombo.THERMAL:
			return "FIRE + ICE"
		ElementalCombo.PLASMA:
			return "FIRE + LIGHTNING"
		ElementalCombo.CORROSIVE:
			return "FIRE + POISON"
		ElementalCombo.MAGNETIC:
			return "ICE + LIGHTNING"
		ElementalCombo.VIRAL:
			return "ICE + POISON"
		ElementalCombo.NEUROTOXIN:
			return "LIGHTNING + POISON"
		_:
			return ""


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
	equipment_changed.emit()
