extends RefCounted
class_name DamageBuilder

const ComboLib := preload("res://Data/Damage/ElementComboLibrary.gd")


static func build_projectile_packet(base_damage: float, equipped_powerups: Array, current_wave: int) -> DamagePacket:
	var packet := DamagePacket.new()

	packet.add_damage(base_damage, "physical", "base")
	packet.add_debug("[DMG] base physical=%.1f" % base_damage)

	var elements: Dictionary = {}

	for entry in equipped_powerups:
		if not entry.has("powerup") or not entry.has("rank"):
			continue

		var powerup: PowerUpData = entry.powerup
		var rank: int = int(entry.rank)

		if powerup == null:
			continue

		if powerup.element_type == PowerUpData.ElementType.NONE:
			continue

		rank = max(1, rank)

		var element_damage: float = base_damage * powerup.amount * float(rank)

		if not elements.has(powerup.element_type):
			elements[powerup.element_type] = 0.0

		elements[powerup.element_type] += element_damage

		packet.add_debug(
			"[DMG] %s rank %d added %.1f elemental damage" %
			[element_to_damage_type(powerup.element_type), rank, element_damage]
		)

	if elements.is_empty():
		return packet

	_add_combined_element_damage(packet, elements)

	return packet


static func _add_combined_element_damage(packet: DamagePacket, elements: Dictionary) -> void:
	var remaining: Array[int] = []

	for element_type in elements.keys():
		remaining.append(int(element_type))

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
