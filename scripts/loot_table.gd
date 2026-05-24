extends Resource
class_name PowerUpTable

@export var common_powerups: Array[PowerUpData] = []
@export var rare_powerups: Array[PowerUpData] = []
@export var epic_powerups: Array[PowerUpData] = []
@export var legendary_powerups: Array[PowerUpData] = []

@export var weight_common: int = 50
@export var weight_rare: int = 30
@export var weight_epic: int = 15
@export var weight_legendary: int = 5

# ══════════════════════════════════════════════════════════════════════
# PUBLIC API
# ══════════════════════════════════════════════════════════════════════

func roll_drop() -> PowerUpData:
	var available_rarities: Array[int] = []

	if not common_powerups.is_empty() and weight_common > 0:
		available_rarities.append(PowerUpData.Rarity.COMMON)
	if not rare_powerups.is_empty() and weight_rare > 0:
		available_rarities.append(PowerUpData.Rarity.RARE)
	if not epic_powerups.is_empty() and weight_epic > 0:
		available_rarities.append(PowerUpData.Rarity.EPIC)
	if not legendary_powerups.is_empty() and weight_legendary > 0:
		available_rarities.append(PowerUpData.Rarity.LEGENDARY)

	if available_rarities.is_empty():
		return null

	var rarity := _roll_available_rarity(available_rarities)

	match rarity:
		PowerUpData.Rarity.COMMON:
			return common_powerups.pick_random()
		PowerUpData.Rarity.RARE:
			return rare_powerups.pick_random()
		PowerUpData.Rarity.EPIC:
			return epic_powerups.pick_random()
		PowerUpData.Rarity.LEGENDARY:
			return legendary_powerups.pick_random()

	return null


func roll_drops(count: int = 3) -> Array[PowerUpData]:
	var drops: Array[PowerUpData] = []

	for i in count:
		var drop := roll_drop()

		if drop != null:
			drops.append(drop)

	return drops


func roll_shop_offer(count: int) -> Array[PowerUpData]:
	var offer: Array[PowerUpData] = []
	var attempts := 0
	var projectile_slots_full: bool = PlayerInventory.get_equipped_projectile_count() >= 2

	while offer.size() < count and attempts < count * 20:
		attempts += 1

		var candidate := roll_drop()

		if candidate == null:
			break

		if not _can_offer_powerup(candidate, projectile_slots_full):
			continue

		if _offer_contains_id(offer, candidate.id):
			continue

		offer.append(candidate)

	return offer


func get_powerups_by_category(category: PowerUpData.Category) -> Array[PowerUpData]:
	var result: Array[PowerUpData] = []

	for powerup in get_all_powerups():
		if powerup == null:
			continue

		if powerup.get_inferred_category() == category:
			result.append(powerup)

	return result


func get_available_powerups_by_category(category: PowerUpData.Category) -> Array[PowerUpData]:
	var result: Array[PowerUpData] = []
	var projectile_slots_full: bool = PlayerInventory.get_equipped_projectile_count() >= 2

	for powerup in get_powerups_by_category(category):
		if not _can_offer_powerup(powerup, projectile_slots_full):
			continue

		result.append(powerup)

	return result


func roll_category_offer(category: PowerUpData.Category, count: int) -> Array[PowerUpData]:
	var pool: Array[PowerUpData] = get_available_powerups_by_category(category)
	var offer: Array[PowerUpData] = []

	pool.shuffle()

	for powerup in pool:
		if offer.size() >= count:
			break

		if _offer_contains_id(offer, powerup.id):
			continue

		offer.append(powerup)

	return offer


func get_all_powerups() -> Array[PowerUpData]:
	var result: Array[PowerUpData] = []

	for powerup in common_powerups:
		_add_unique_powerup(result, powerup)

	for powerup in rare_powerups:
		_add_unique_powerup(result, powerup)

	for powerup in epic_powerups:
		_add_unique_powerup(result, powerup)

	for powerup in legendary_powerups:
		_add_unique_powerup(result, powerup)

	return result

# ══════════════════════════════════════════════════════════════════════
# FILTERING
# ══════════════════════════════════════════════════════════════════════

func _can_offer_powerup(powerup: PowerUpData, projectile_slots_full: bool) -> bool:
	if powerup == null:
		return false

	if PlayerInventory.get_powerup_rank(powerup) >= powerup.max_stacks:
		return false

	if projectile_slots_full and powerup.is_projectile_powerup():
		return false

	return true


func _offer_contains_id(offer: Array[PowerUpData], id: String) -> bool:
	for existing in offer:
		if existing != null and existing.id == id:
			return true

	return false


func _add_unique_powerup(result: Array[PowerUpData], powerup: PowerUpData) -> void:
	if powerup == null:
		return

	for existing in result:
		if existing != null and existing.id == powerup.id:
			return

	result.append(powerup)

# ══════════════════════════════════════════════════════════════════════
# RARITY
# ══════════════════════════════════════════════════════════════════════

func _roll_available_rarity(available_rarities: Array[int]) -> int:
	var total_weight := 0

	for rarity in available_rarities:
		match rarity:
			PowerUpData.Rarity.COMMON:
				total_weight += weight_common
			PowerUpData.Rarity.RARE:
				total_weight += weight_rare
			PowerUpData.Rarity.EPIC:
				total_weight += weight_epic
			PowerUpData.Rarity.LEGENDARY:
				total_weight += weight_legendary

	if total_weight <= 0:
		return available_rarities[0]

	var roll := randi() % total_weight
	var current := 0

	for rarity in available_rarities:
		match rarity:
			PowerUpData.Rarity.COMMON:
				current += weight_common
			PowerUpData.Rarity.RARE:
				current += weight_rare
			PowerUpData.Rarity.EPIC:
				current += weight_epic
			PowerUpData.Rarity.LEGENDARY:
				current += weight_legendary

		if roll < current:
			return rarity

	return available_rarities[0]
