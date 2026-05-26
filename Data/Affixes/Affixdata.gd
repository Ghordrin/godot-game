extends Resource
class_name AffixData

## Data object describing a single elite affix.

enum AffixType {
	SHIELDED,      ## Regenerating shield.
	REGENERATING,  ## Recovers 1% max health per second.
	FRENZIED,      ## Half HP, moves and attacks very fast.
	GUARDIAN,      ## Grants shields to nearby enemies while alive.
}

@export var affix_type: AffixType = AffixType.SHIELDED
@export var display_name: String  = "UNNAMED"
@export var description: String   = ""
@export var color: Color          = Color.WHITE
@export var tier: int             = 1
