extends Resource
class_name PowerUpTable

## Weighted rarity-based loot table. Organizes powerups into four rarity
## tiers matching your PowerUpData.Rarity enum: COMMON, RARE, EPIC, LEGENDARY.
##
## When a powerup drops, the table first picks a rarity tier based on weights,
## then randomly selects a powerup from that tier's pool. This ensures that
## legendary powerups are both rare AND chosen only from your legendary pool,
## not mixed with everything else.
##
## Adjust the weight percentages in the Inspector to tune how often each
## rarity feels. They don't need to sum to 100 — the code normalizes them.

@export var common_powerups: Array[PowerUpData] = []
@export var rare_powerups: Array[PowerUpData] = []
@export var epic_powerups: Array[PowerUpData] = []
@export var legendary_powerups: Array[PowerUpData] = []

## Rarity distribution weights. Adjust these to control drop rates.
## Higher values = more common. The code automatically normalizes them.
@export var weight_common: int = 50      ## 50% of drops
@export var weight_rare: int = 30        ## 30% of drops
@export var weight_epic: int = 15        ## 15% of drops
@export var weight_legendary: int = 5    ## 5% of drops

# ══════════════════════════════════════════════════════════════════════
# PUBLIC API
# ══════════════════════════════════════════════════════════════════════

## Roll a single powerup drop. Uses weighted rarity selection to pick a
## tier, then randomly picks from that tier. Returns null if all tiers
## are empty.
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


## Roll multiple drops at once. Each roll is independent and uses the
## full weighted distribution.
func roll_drops(count: int = 3) -> Array[PowerUpData]:
	var drops: Array[PowerUpData] = []
	for i in count:
		var drop := roll_drop()
		if drop != null:
			drops.append(drop)
	return drops


## Roll exactly count distinct powerups for a shop offer.
## Guarantees no duplicate IDs in the same offer.
## Blocks projectile type powerups if player already has two equipped.
func roll_shop_offer(count: int) -> Array[PowerUpData]:
	var offer: Array[PowerUpData] = []
	var attempts := 0
	var projectile_slots_full: bool = PlayerInventory.get_equipped_projectile_count() >= 2

	while offer.size() < count and attempts < count * 10:
		attempts += 1
		var candidate := roll_drop()
		if candidate == null:
			break

		# Block projectile types if player already has two
		if projectile_slots_full:
			if "projectile_type" in candidate and candidate.projectile_type != PowerUpData.ProjectileType.NONE:
				continue

		# Skip maxed powerups
		if PlayerInventory.get_powerup_rank(candidate) >= candidate.max_stacks:
			continue

		# Skip duplicates in same offer
		var already_in := false
		for existing in offer:
			if existing.id == candidate.id:
				already_in = true
				break
		if not already_in:
			offer.append(candidate)

	return offer

# ══════════════════════════════════════════════════════════════════════
# INTERNAL
# ══════════════════════════════════════════════════════════════════════

func _roll_available_rarity(available_rarities: Array[int]) -> int:
	var total_weight := 0

	for rarity in available_rarities:
		match rarity:
			PowerUpData.Rarity.COMMON:    total_weight += weight_common
			PowerUpData.Rarity.RARE:      total_weight += weight_rare
			PowerUpData.Rarity.EPIC:      total_weight += weight_epic
			PowerUpData.Rarity.LEGENDARY: total_weight += weight_legendary

	var roll := randi() % total_weight
	var current := 0

	for rarity in available_rarities:
		match rarity:
			PowerUpData.Rarity.COMMON:    current += weight_common
			PowerUpData.Rarity.RARE:      current += weight_rare
			PowerUpData.Rarity.EPIC:      current += weight_epic
			PowerUpData.Rarity.LEGENDARY: current += weight_legendary

		if roll < current:
			return rarity

	return available_rarities[0]


func _roll_rarity() -> int:
	var total := weight_common + weight_rare + weight_epic + weight_legendary
	if total == 0:
		return PowerUpData.Rarity.COMMON

	var roll := randi() % 100
	var common_pct := (weight_common * 100) / total
	var rare_pct := common_pct + (weight_rare * 100) / total
	var epic_pct := rare_pct + (weight_epic * 100) / total

	if roll < common_pct:
		return PowerUpData.Rarity.COMMON
	elif roll < rare_pct:
		return PowerUpData.Rarity.RARE
	elif roll < epic_pct:
		return PowerUpData.Rarity.EPIC
	else:
		return PowerUpData.Rarity.LEGENDARY
