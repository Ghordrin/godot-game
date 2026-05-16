extends Resource
class_name LootTable

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

# Rarity distribution weights. Adjust these to control drop rates.
# Higher values = more common. The code automatically normalizes them.
@export var weight_common: int = 50      ## 50% of drops
@export var weight_rare: int = 30        ## 30% of drops
@export var weight_epic: int = 15        ## 15% of drops
@export var weight_legendary: int = 5    ## 5% of drops

# ─────────────────────────────────────────────────────────────────────

## Roll a single powerup drop. Uses weighted rarity selection to pick a
## tier, then randomly picks from that tier. Returns null if all tiers
## are empty (unlikely, but possible).
func roll_drop() -> PowerUpData:
	var rarity := _roll_rarity()
	
	match rarity:
		PowerUpData.Rarity.COMMON:
			if not common_powerups.is_empty():
				return common_powerups.pick_random()
		PowerUpData.Rarity.RARE:
			if not rare_powerups.is_empty():
				return rare_powerups.pick_random()
		PowerUpData.Rarity.EPIC:
			if not epic_powerups.is_empty():
				return epic_powerups.pick_random()
		PowerUpData.Rarity.LEGENDARY:
			if not legendary_powerups.is_empty():
				return legendary_powerups.pick_random()
	
	return null

## Roll multiple drops at once. Useful for bosses or special events that
## should drop multiple powerups. Each roll is independent and uses the
## full weighted distribution.
func roll_drops(count: int = 3) -> Array[PowerUpData]:
	var drops: Array[PowerUpData] = []
	for i in count:
		var drop := roll_drop()
		if drop != null:
			drops.append(drop)
	return drops

# ── Internal: Weighted Rarity Rolling ─────────────────────────────────

## Picks a rarity tier based on the configured weights. Normalizes the
## weights so they don't need to sum to 100, then uses a weighted random
## selection to pick a tier.
func _roll_rarity() -> int:
	# Normalize the weights so they sum to 100 for easier probability math.
	var total := weight_common + weight_rare + weight_epic + weight_legendary
	if total == 0:
		return PowerUpData.Rarity.COMMON  # Fallback if all weights are 0
	
	# Generate a random number 0-99 and see which tier it falls into.
	var roll := randi() % 100
	
	# Calculate the cumulative percentages for each tier.
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
