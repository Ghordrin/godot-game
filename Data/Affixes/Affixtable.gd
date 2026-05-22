extends Node
class_name AffixTable

## Builds the full affix pool in code — no .tres files needed per affix.
## Use roll(count, wave) to get a randomised affix array.
## Add as AutoLoad if you want it globally accessible, or just use the static methods.

const FORBIDDEN_PAIRS: Array = [
	# Too tanky or too punishing if combined
	[AffixData.AffixType.COMBINATION_IMMUNE, AffixData.AffixType.REGENERATING],
	[AffixData.AffixType.NULLIFYING_AURA,    AffixData.AffixType.SHIELDED],
	[AffixData.AffixType.FRENZIED,           AffixData.AffixType.EXPLOSIVE_DEATH],
	[AffixData.AffixType.VAMPIRIC,           AffixData.AffixType.REGENERATING],
]

static func roll(count: int, wave: int) -> Array[AffixData]:
	## Roll `count` unique affixes for an enemy spawning at the given wave.
	## Returns an Array[AffixData] ready to pass to AffixComponent.apply_affixes().
	var pool := _build_pool()
	var available := pool.filter(func(a: AffixData) -> bool:
		return a.tier <= _max_tier_for_wave(wave)
	)
	available.shuffle()

	var result:     Array[AffixData] = []
	var used_types: Array[int]       = []

	for affix in available:
		if result.size() >= count:
			break
		if affix.affix_type in used_types:
			continue
		if _is_forbidden(result, affix):
			continue
		result.append(affix)
		used_types.append(affix.affix_type)

	return result

static func _max_tier_for_wave(wave: int) -> int:
	if wave >= 11: return 3
	if wave >= 6:  return 2
	return 1

static func _is_forbidden(existing: Array[AffixData], candidate: AffixData) -> bool:
	## Check if combining `candidate` with `existing` affixes is forbidden.
	for pair in FORBIDDEN_PAIRS:
		for existing_affix in existing:
			var a: int = existing_affix.affix_type
			var b: int = candidate.affix_type
			if (a == pair[0] and b == pair[1]) or (a == pair[1] and b == pair[0]):
				return true
	return false

static func _build_pool() -> Array[AffixData]:
	## Construct all affixes with their data. Names and colours can be adjusted here.
	return [
		# ── Tier 1 — early waves ──────────────────────────────────────
		_make(AffixData.AffixType.PLATED,
			"PLATED",     "High armour. Fire damage penetrates.",
			Color(0.75, 0.65, 0.40), 1),

		_make(AffixData.AffixType.SHIELDED,
			"SHIELDED",   "Regenerating shield. Poison bypasses it.",
			Color(0.30, 0.65, 1.00), 1),

		_make(AffixData.AffixType.FRENZIED,
			"FRENZIED",   "80% faster. 55% less health.",
			Color(1.00, 0.35, 0.25), 1),

		_make(AffixData.AffixType.CONDUCTIVE,
			"CONDUCTIVE", "Takes double lightning damage.",
			Color(0.80, 0.60, 1.00), 1),

		# ── Tier 2 — mid waves ────────────────────────────────────────
		_make(AffixData.AffixType.REGENERATING,
			"REGENERATING", "Recovers health over time.",
			Color(0.40, 1.00, 0.45), 2),

		_make(AffixData.AffixType.FROST_SHELL,
			"FROST SHELL",  "Immune to slow. Shatters on death.",
			Color(0.50, 0.90, 1.00), 2),

		_make(AffixData.AffixType.EXPLOSIVE_DEATH,
			"VOLATILE",     "Explodes for AOE damage on death.",
			Color(1.00, 0.65, 0.15), 2),

		_make(AffixData.AffixType.PACK_LEADER,
			"PACK LEADER",  "Nearby enemies gain speed while alive.",
			Color(1.00, 0.85, 0.25), 2),

		_make(AffixData.AffixType.FIRE_AURA,
			"FIRE AURA",    "Burns nearby players.",
			Color(1.00, 0.45, 0.10), 2),

		# ── Tier 3 — late waves ───────────────────────────────────────
		_make(AffixData.AffixType.VAMPIRIC,
			"VAMPIRIC",       "Heals when a nearby enemy dies.",
			Color(0.80, 0.20, 0.90), 3),

		_make(AffixData.AffixType.TOXIC_CLOUD,
			"TOXIC CLOUD",    "Leaves a lingering poison trail.",
			Color(0.45, 1.00, 0.35), 3),

		_make(AffixData.AffixType.COMBINATION_IMMUNE,
			"WARDED",         "Immune to elemental combinations.",
			Color(0.80, 0.80, 0.80), 3),

		_make(AffixData.AffixType.NULLIFYING_AURA,
			"NULLIFYING",     "Immune to slow and stun.",
			Color(0.65, 0.65, 1.00), 3),
	]

static func _make(type: AffixData.AffixType, display_name: String, desc: String,
				  color: Color, tier: int) -> AffixData:
	## Helper to build an AffixData instance.
	var a := AffixData.new()
	a.affix_type    = type
	a.display_name  = display_name
	a.description   = desc
	a.color         = color
	a.tier          = tier
	return a
