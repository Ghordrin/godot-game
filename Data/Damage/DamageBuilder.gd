extends RefCounted
class_name DamageBuilder

const ComboLib := preload("res://Data/Damage/ElementComboLibrary.gd")

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
		if powerup.element_type == PowerUpData.ElementType.NONE:
			continue

		var raw_pool: float = base_damage * powerup.amount * float(rank) * wave_scale

		if not raw_elements.has(powerup.element_type):
			raw_elements[powerup.element_type] = 0.0

		raw_elements[powerup.element_type] += raw_pool

	if raw_elements.is_empty():
		return packet

	var raw_total: float = 0.0
	for element_type in raw_elements:
		raw_total += float(raw_elements[element_type])

	var elemental_cap: float = base_damage * get_element_cap_multiplier(safe_wave)
	var cap_scale: float = 1.0

	if raw_total > elemental_cap:
		cap_scale = elemental_cap / raw_total

	var capped_elements: Dictionary = {}
	for element_type in raw_elements:
		capped_elements[element_type] = float(raw_elements[element_type]) * cap_scale

	_add_combined_element_damage(packet, capped_elements)

	return packet


static func _add_combined_element_damage(packet: DamagePacket, elements: Dictionary) -> void:
	var ordered: Array[int] = [
		PowerUpData.ElementType.FIRE,
		PowerUpData.ElementType.ICE,
		PowerUpData.ElementType.LIGHTNING,
		PowerUpData.ElementType.POISON,
	]

	var remaining: Array[int] = []

	for element_type in ordered:
		if elements.has(element_type):
			remaining.append(element_type)

	while remaining.size() >= 2:
		var a: int = remaining[0]
		var b: int = remaining[1]
		var combo: int = ComboLib.get_combo(a, b)

		if combo == ComboLib.CombinedElement.NONE:
			break

		var combo_amount: float = float(elements[a]) + float(elements[b])
		var combo_type: String = combo_to_damage_type(combo)

		packet.add_damage(combo_amount, combo_type, "combo")
		packet.add_debug("[DMG] combo %s=%.1f" % [combo_type, combo_amount])

		remaining.remove_at(1)
		remaining.remove_at(0)

	for element_type in remaining:
		var amount: float = float(elements[element_type])
		var damage_type: String = element_to_damage_type(element_type)

		packet.add_damage(amount, damage_type, "element")
		packet.add_debug("[DMG] loose %s=%.1f" % [damage_type, amount])


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


static func combo_to_damage_type(combo: int) -> String:
	match combo:
		ComboLib.CombinedElement.THERMAL:
			return "thermal"
		ComboLib.CombinedElement.PLASMA:
			return "plasma"
		ComboLib.CombinedElement.CORROSIVE:
			return "corrosive"
		ComboLib.CombinedElement.MAGNETIC:
			return "magnetic"
		ComboLib.CombinedElement.VIRAL:
			return "viral"
		ComboLib.CombinedElement.NEUROTOXIN:
			return "neurotoxin"
		_:
			return "physical"
