extends Resource
class_name PowerUpData

## Rarity levels for powerups
enum Rarity {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY
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
	FLAT,           # Adds a flat number (e.g., +5 damage)
	PERCENTAGE      # Adds a percentage (e.g., +100% damage = 1.0 multiplier)
}

# ══════════════════════════════════════════════════════════════════════
# BASIC PROPERTIES
# ══════════════════════════════════════════════════════════════════════

## Unique identifier for this powerup (e.g., "damage_up", "ignition_core")
@export var id: String = ""

## Display name shown in UI
@export var display_name: String = ""

## Description shown in shop and tooltips
@export_multiline var description: String = ""

@export var icon: Texture2D = null 

## Rarity determines drop chance and visual presentation
@export var rarity: Rarity = Rarity.COMMON

# ══════════════════════════════════════════════════════════════════════
# STACKING & RANKING
# ══════════════════════════════════════════════════════════════════════

## Maximum rank this powerup can reach (Duviri-style ranking system)
## Each time you acquire this powerup, its rank increases by 1 up to max_stacks
@export var max_stacks: int = 5

# ══════════════════════════════════════════════════════════════════════
# STAT MODIFICATION
# ══════════════════════════════════════════════════════════════════════

## Which stat this powerup modifies (e.g., "damage", "move_speed", "attack_speed")
## Leave empty if this powerup doesn't modify stats directly
@export var stat_to_modify: String = ""

## How the amount value is applied
@export var modifier_type: ModifierType = ModifierType.FLAT

## The value to apply to the stat
## For FLAT: adds directly (amount = 5 means +5 damage)
## For PERCENTAGE: adds as percentage (amount = 1.0 means +100%, amount = 0.5 means +50%)
@export var amount: float = 0.0

# ══════════════════════════════════════════════════════════════════════
# ELEMENTAL SYSTEM
# ══════════════════════════════════════════════════════════════════════

## Element type for combination system
## When you equip two different elements, they combine for special effects
@export var element_type: ElementType = ElementType.NONE

# ══════════════════════════════════════════════════════════════════════
# PROJECTILE TYPE SYSTEM
# ══════════════════════════════════════════════════════════════════════

enum ProjectileType {
	NONE,
	PHASE,      # Passes through enemies. Rank = pierce count.
	BOULDER,    # Large slow projectile. Rank = size + damage multiplier.
	RICOCHET,   # Bounces off walls. Rank = bounce count.
	NOVA,       # Explodes on impact. Rank = AOE radius + damage.
	HOMING,     # Curves toward nearest enemy. Rank = turn strength.
}

## Set this to give the powerup a projectile type behavior.
## Only one projectile type can be active at a time — equipping a second
## replaces the first. Leave NONE for non-projectile powerups.
@export var projectile_type: ProjectileType = ProjectileType.NONE

# ══════════════════════════════════════════════════════════════════════
# NOTES FOR CONFIGURATION
# ══════════════════════════════════════════════════════════════════════

## EXAMPLE CONFIGURATIONS:
##
## Basic Damage Powerup (Flat):
##   id = "damage_up"
##   display_name = "Damage Up"
##   stat_to_modify = "damage"
##   modifier_type = FLAT
##   amount = 5.0
##   Result: +5 damage per rank (Rank 3 = +15 total)
##
## Elemental Damage Powerup (Percentage):
##   id = "ignition_core"
##   display_name = "Ignition Core"
##   stat_to_modify = "damage"
##   modifier_type = PERCENTAGE
##   amount = 1.0
##   element_type = FIRE
##   Result: +100% damage per rank (Rank 2 = +200% total)
##
## Speed Boost (Percentage):
##   id = "speed_boost"
##   display_name = "Speed Boost"
##   stat_to_modify = "move_speed"
##   modifier_type = PERCENTAGE
##   amount = 0.15
##   Result: +15% speed per rank (Rank 3 = +45% total)
##
## Elemental with No Stat Bonus:
##   id = "cryo_lens"
##   display_name = "Cryo Lens"
##   stat_to_modify = ""  (empty - no stat modification)
##   element_type = ICE
##   Result: Only provides Ice element for combinations
