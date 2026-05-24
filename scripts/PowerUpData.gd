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
	DEFENSIVE
}

## Element types for combination system
enum ElementType {
	NONE,
	FIRE,
	ICE,
	LIGHTNING,
	POISON
}

## How the powerup's amount is applied to stats
enum ModifierType {
	FLAT,
	PERCENTAGE
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

# ══════════════════════════════════════════════════════════════════════
# PROJECTILE TYPE SYSTEM
# ══════════════════════════════════════════════════════════════════════

enum ProjectileType {
	NONE,
	PHASE,
	BOULDER,
	RICOCHET,
	NOVA,
	HOMING,
}

@export var projectile_type: ProjectileType = ProjectileType.NONE


func get_inferred_category() -> Category:
	if category != Category.GENERAL:
		return category

	if element_type != ElementType.NONE:
		return Category.ELEMENT

	if projectile_type != ProjectileType.NONE:
		return Category.PROJECTILE

	return category


func is_element_powerup() -> bool:
	return get_inferred_category() == Category.ELEMENT or element_type != ElementType.NONE


func is_projectile_powerup() -> bool:
	return get_inferred_category() == Category.PROJECTILE or projectile_type != ProjectileType.NONE
