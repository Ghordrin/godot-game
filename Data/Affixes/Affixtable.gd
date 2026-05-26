extends Node
class_name AffixTable

## Builds the full affix pool in code — no .tres files needed per affix.
## Use roll(count, wave) to get a randomised affix array.

const FORBIDDEN_PAIRS: Array = [
	[AffixData.AffixType.FRENZIED, AffixData.AffixType.GUARDIAN],
]

static func roll(count: int, wave: int) -> Array[AffixData]:
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
	for pair in FORBIDDEN_PAIRS:
		for existing_affix in existing:
			var a: int = existing_affix.affix_type
			var b: int = candidate.affix_type
			if (a == pair[0] and b == pair[1]) or (a == pair[1] and b == pair[0]):
				return true
	return false


static func _build_pool() -> Array[AffixData]:
	return [
		_make(AffixData.AffixType.SHIELDED,
			"SHIELDED",     "Regenerating shield.",
			Color(0.30, 0.65, 1.00), 1),

		_make(AffixData.AffixType.FRENZIED,
			"OVERCLOCKED",  "Half HP. Moves and attacks very fast.",
			Color(1.00, 0.35, 0.25), 1),

		_make(AffixData.AffixType.REGENERATING,
			"SELF-REPAIR",  "Recovers 1% max health per second.",
			Color(0.40, 1.00, 0.45), 2),

		_make(AffixData.AffixType.GUARDIAN,
			"GUARDIAN",     "Grants shields to nearby enemies while alive.",
			Color(1.00, 0.85, 0.25), 2),
	]


static func _make(type: AffixData.AffixType, display_name: String, desc: String,
				  color: Color, tier: int) -> AffixData:
	var a := AffixData.new()
	a.affix_type    = type
	a.display_name  = display_name
	a.description   = desc
	a.color         = color
	a.tier          = tier
	return a
