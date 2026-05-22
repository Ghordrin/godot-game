extends RefCounted
class_name DamageBuilder

const BASE_WAVE_ELEMENT_CAP: float = 0.80
const MID_WAVE_ELEMENT_CAP: float = 1.20
const LATE_WAVE_ELEMENT_CAP: float = 1.75
const ELEMENT_WAVE_SCALE_PER_WAVE: float = 0.12


static func build_projectile_packet(base_damage: float, equipped_powerups: Array, current_wave: int) -> DamagePacket:
	var packet := DamagePacket.new()
	var safe_wave: int = max(1, current_wave)
	var wave_scale: float = 1.0 + float(safe_wave - 1) * ELEMENT_WAVE_SCALE_PER_WAVE

	packet.add_damage(base_damage, "physical", "base")
	packet.add_debug("[DMG] base physical=%.1f" % base_damage)

	var raw_elements: Dictionary = {}

	for entry in equipped_powerups:
		if not entry.has("powerup") or not entry.has("rank"):
			continue

		var powerup: PowerUpData = entry.powerup
		var rank: int = int(entry.rank)

		if powerup == null:
			continue
		if not "element_type" in powerup:
			continue
		if powerup.element_type == PowerUpData.ElementType.NONE:
			continue

		var raw_pool: float = base_damage * powerup.amount * float(rank) * wave_scale

		if not raw_elements.has(powerup.element_type):
			raw_elements[powerup.element_type] = 0.0

		raw_elements[powerup.element_type] += raw_pool

		packet.add_debug("[DMG] raw %s=%.1f base=%.1f amount=%.2f rank=%d wave_scale=%.2f" % [PowerUpData.ElementType.keys()[powerup.element_type], raw_pool, base_damage, powerup.amount, rank, wave_scale])

	if raw_elements.is_empty():
		return packet

	var raw_total: float = 0.0
	for element_type in raw_elements:
		raw_total += float(raw_elements[element_type])

	var elemental_cap: float = base_damage * get_element_cap_multiplier(safe_wave)
	var cap_scale: float = 1.0

	if raw_total > elemental_cap:
		cap_scale = elemental_cap / raw_total

	packet.add_debug("[DMG] raw_element_total=%.1f cap=%.1f cap_scale=%.2f" % [raw_total, elemental_cap, cap_scale])

	for element_type in raw_elements:
		var capped_amount: float = float(raw_elements[element_type]) * cap_scale
		var damage_type: String = element_to_damage_type(int(element_type))

		packet.add_damage(capped_amount, damage_type, "element")
		packet.add_debug("[DMG] final %s=%.1f" % [PowerUpData.ElementType.keys()[element_type], capped_amount])

	return packet


static func get_element_cap_multiplier(wave: int) -> float:
	if wave <= 5:
		return BASE_WAVE_ELEMENT_CAP
	if wave <= 10:
		return MID_WAVE_ELEMENT_CAP
	return LATE_WAVE_ELEMENT_CAP


static func element_to_damage_type(element_type: int) -> String:
	match element_type:
		PowerUpData.ElementType.FIRE:
			return "fire"
		PowerUpData.ElementType.ICE:
			return "ice"
		PowerUpData.ElementType.LIGHTNING:
			return "lightning"
		PowerUpData.ElementType.POISON:
			return "poison"
		_:
			return "physical"
