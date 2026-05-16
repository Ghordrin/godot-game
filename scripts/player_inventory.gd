extends Node

const EQUIPMENT_SLOTS: int = 5

signal gold_changed(new_amount: int)
signal powerup_collected(powerup: PowerUpData)
signal equipment_changed

var gold: int = 0
var collected_powerups: Array[PowerUpData] = []
var equipped_powerups: Array[PowerUpData] = []


func _ready() -> void:
	equipped_powerups.resize(EQUIPMENT_SLOTS)

	for i in EQUIPMENT_SLOTS:
		equipped_powerups[i] = null


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


func collect_powerup(powerup: PowerUpData) -> void:
	if powerup == null:
		return

	collected_powerups.append(powerup)
	powerup_collected.emit(powerup)


func get_collected_powerups() -> Array[PowerUpData]:
	return collected_powerups


func has_powerup(powerup: PowerUpData) -> bool:
	return powerup in collected_powerups


func get_powerup_owned_count(powerup: PowerUpData) -> int:
	var count := 0

	for pu in collected_powerups:
		if pu == powerup:
			count += 1

	return count


func get_powerup_equipped_count(powerup: PowerUpData) -> int:
	var count := 0

	for pu in equipped_powerups:
		if pu == powerup:
			count += 1

	return count


func can_equip_powerup(powerup: PowerUpData, target_slot: int) -> bool:
	if powerup == null:
		return true

	var owned_count := get_powerup_owned_count(powerup)
	var equipped_count := get_powerup_equipped_count(powerup)

	if target_slot >= 0 and target_slot < EQUIPMENT_SLOTS:
		if equipped_powerups[target_slot] == powerup:
			equipped_count -= 1

	return equipped_count < owned_count


func equip_powerup(powerup: PowerUpData, slot: int) -> bool:
	if slot < 0 or slot >= EQUIPMENT_SLOTS:
		return false

	if powerup != null:
		if powerup not in collected_powerups:
			return false

		if not can_equip_powerup(powerup, slot):
			print("Cannot equip ", powerup.display_name, ": not enough copies owned.")
			return false

	equipped_powerups[slot] = powerup
	equipment_changed.emit()
	return true


func get_equipped_powerups() -> Array[PowerUpData]:
	var active: Array[PowerUpData] = []

	for pu in equipped_powerups:
		if pu != null:
			active.append(pu)

	return active


func is_equipped(powerup: PowerUpData) -> bool:
	return powerup in equipped_powerups


func clear_equipment() -> void:
	for i in EQUIPMENT_SLOTS:
		equipped_powerups[i] = null

	equipment_changed.emit()


func save_equipment_build() -> Array:
	return equipped_powerups.duplicate()


func load_equipment_build(build: Array) -> void:
	if build.size() != EQUIPMENT_SLOTS:
		return

	equipped_powerups.clear()
	equipped_powerups.resize(EQUIPMENT_SLOTS)

	for i in EQUIPMENT_SLOTS:
		var pu: PowerUpData = build[i]

		if pu != null and can_equip_powerup(pu, i):
			equipped_powerups[i] = pu
		else:
			equipped_powerups[i] = null

	equipment_changed.emit()


func reset_for_new_run() -> void:
	gold = 0
	collected_powerups.clear()
	clear_equipment()
	gold_changed.emit(0)
