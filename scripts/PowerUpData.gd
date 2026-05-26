extends Resource
class_name PowerUpData

## Rarity levels for powerups
enum Rarity {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY
}

## What role this powerup has in the shop/build system.
## Rarity answers "how rare is it?"
## Category answers "what kind of upgrade is it?"
enum Category {
	GENERAL,
	ELEMENT,
	PROJECTILE,
	UTILITY,
	DEFENSIVE,
	PROJECTILE_UPGRADE
}

## Element types for combination system
enum ElementType {
	NONE,
	FIRE,
	ICE,
	LIGHTNING,
	POISON,
}

## How the powerup's amount is applied to stats
enum ModifierType {
	FLAT,
	PERCENTAGE
}

## Projectile type system
enum ProjectileType {
	NONE,
	PHASE,
	BOULDER,
	RICOCHET, # Legacy / future modifier. Do not offer as a core projectile.
	NOVA,
	HOMING,
}

## Projectile-specific upgrade behavior.
enum ProjectileUpgradeType {
	NONE,
	BOULDER_METEOR,      ## Drop-from-sky evolution: dramatically increases damage and AoE.
	NOVA_PRESSURE_WAVE,  ## Detonation leaves a persistent damage zone.
	HOMING_SEEKER_SWARM, ## On kill, spawns mini-seekers toward nearby enemies.
	PHASE_PIERCE,
	PHASE_SPEED,
	PHASE_WIDTH,
}

# ══════════════════════════════════════════════════════════════════════
# BASIC PROPERTIES
# ══════════════════════════════════════════════════════════════════════

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null

@export var rarity: Rarity = Rarity.COMMON
@export var category: Category = Category.GENERAL

# ══════════════════════════════════════════════════════════════════════
# STACKING & RANKING
# ══════════════════════════════════════════════════════════════════════

@export var max_stacks: int = 5

# ══════════════════════════════════════════════════════════════════════
# STAT MODIFICATION
# ══════════════════════════════════════════════════════════════════════

@export var stat_to_modify: String = ""
@export var modifier_type: ModifierType = ModifierType.FLAT
@export var amount: float = 0.0

# ══════════════════════════════════════════════════════════════════════
# ELEMENTAL SYSTEM
# ══════════════════════════════════════════════════════════════════════

@export var element_type: ElementType = ElementType.NONE
## Second element for combo powerups (e.g. a Thermal powerup grants Fire + Ice at once).
@export var element_type_b: ElementType = ElementType.NONE

# ══════════════════════════════════════════════════════════════════════
# PROJECTILE TYPE SYSTEM
# ══════════════════════════════════════════════════════════════════════

@export var projectile_type: ProjectileType = ProjectileType.NONE

# ══════════════════════════════════════════════════════════════════════
# PROJECTILE UPGRADE SYSTEM
# ══════════════════════════════════════════════════════════════════════

## Set category to PROJECTILE_UPGRADE for upgrade resources.
## Example:
## - target_projectile_type = BOULDER
## - projectile_upgrade_type = BOULDER_SIZE
@export var target_projectile_type: ProjectileType = ProjectileType.NONE
@export var projectile_upgrade_type: ProjectileUpgradeType = ProjectileUpgradeType.NONE

## Minimum wave before this powerup may appear in normal shops.
@export var min_wave: int = 1

## If true, this powerup only appears when target_projectile_type is active.
@export var requires_active_projectile: bool = false


func get_inferred_category() -> Category:
	if category != Category.GENERAL:
		return category

	if projectile_upgrade_type != ProjectileUpgradeType.NONE:
		return Category.PROJECTILE_UPGRADE

	if element_type != ElementType.NONE:
		return Category.ELEMENT

	if projectile_type != ProjectileType.NONE:
		return Category.PROJECTILE

	return category


func is_element_powerup() -> bool:
	return get_inferred_category() == Category.ELEMENT or element_type != ElementType.NONE


func is_projectile_powerup() -> bool:
	return get_inferred_category() == Category.PROJECTILE or projectile_type != ProjectileType.NONE


func is_projectile_upgrade() -> bool:
	return get_inferred_category() == Category.PROJECTILE_UPGRADE or projectile_upgrade_type != ProjectileUpgradeType.NONE
