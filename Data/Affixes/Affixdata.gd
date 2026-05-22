extends Resource
class_name AffixData

## Data object describing a single elite affix.
## This resource stores type, display name, description, colour and tier.

enum AffixType {
	# ── Defensive ────────────────────────────────────────────────────
	PLATED,              ## High armor. Fire damage penetrates partially.
	SHIELDED,            ## Regenerating shield. Poison bypasses it.
	REGENERATING,        ## Recovers a portion of max health per second.

	# ── Elemental ────────────────────────────────────────────────────
	FIRE_AURA,           ## Burns nearby players on contact.
	FROST_SHELL,         ## Immune to slow. Shatters on death.
	CONDUCTIVE,          ## Takes double lightning damage.
	TOXIC_CLOUD,         ## Leaves lingering poison trail on movement.

	# ── Behavioral ──────────────────────────────────────────────────
	FRENZIED,            ## 80% faster. Reduced max health.
	VAMPIRIC,            ## Heals when nearby enemies die.
	EXPLOSIVE_DEATH,     ## Explodes for AOE damage on death.
	PACK_LEADER,         ## Boosts speed of nearby enemies.

	# ── Build‑punishing ─────────────────────────────────────────────
	COMBINATION_IMMUNE,  ## Combination effects deal no damage.
	NULLIFYING_AURA,     ## Immune to slow and stun.
}

@export var affix_type: AffixType = AffixType.PLATED
@export var display_name: String  = "UNNAMED"
@export var description: String   = ""
@export var color: Color          = Color.WHITE
@export var tier: int             = 1 ## 1 = early, 2 = mid, 3 = late waves
