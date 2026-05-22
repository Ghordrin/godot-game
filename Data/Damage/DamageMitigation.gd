extends RefCounted
class_name DamageMitigation


static func resolve(
	target_root: Node,
	amount: float,
	damage_type: String
) -> float:

	var actual: float = amount

	var affix := target_root.get_node_or_null("AffixComponent") as AffixComponent
	var shield := target_root.get_node_or_null("ShieldComponent") as ShieldComponent
	var armor := target_root.get_node_or_null("ArmorComponent") as ArmorComponent

	# Affixes modify incoming damage first
	if affix != null:
		actual = affix.modify_incoming_damage(actual, damage_type)

		if actual <= 0.0:
			return 0.0

	# Shields absorb before armor
	if shield != null and not shield.is_broken:
		if damage_type != "poison" and damage_type != "combo":

			actual = shield.absorb(actual)

			if actual <= 0.0:
				return 0.0

	# Armor reduces remaining damage
	if armor != null:
		actual = armor.reduce(actual, damage_type)

	return actual
	
static func resolve_packet(target_root: Node, packet: DamagePacket) -> int:
	if packet == null or packet.is_empty():
		return 0

	var total_final_damage: int = 0

	for entry: Dictionary in packet.entries:
		var amount: float = float(entry.amount)
		var damage_type: String = String(entry.type)

		if amount <= 0.0:
			continue

		var final_amount: float = resolve(target_root, amount, damage_type)

		if final_amount <= 0.0:
			continue

		total_final_damage += max(1, int(round(final_amount)))

	return total_final_damage
