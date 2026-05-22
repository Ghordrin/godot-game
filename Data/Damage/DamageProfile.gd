extends Resource
class_name DamageProfile

const ComboLib := preload("res://Data/Damage/ElementComboLibrary.gd")

var base_elements: Array[int] = []
var combined_elements: Array[int] = []
var loose_elements: Array[int] = []


static func from_inventory(equipped: Array) -> DamageProfile:
	var profile := DamageProfile.new()

	for entry in equipped:
		if not entry.has("powerup"):
			continue

		var powerup: PowerUpData = entry.powerup

		if powerup == null:
			continue
		if not "element_type" in powerup:
			continue
		if powerup.element_type == PowerUpData.ElementType.NONE:
			continue

		if not profile.base_elements.has(powerup.element_type):
			profile.base_elements.append(powerup.element_type)

	profile._resolve_combinations()
	return profile


func _resolve_combinations() -> void:
	var remaining: Array[int] = base_elements.duplicate()

	while remaining.size() >= 2:
		var combo: int = ComboLib.get_combo(remaining[0], remaining[1])

		if combo == ComboLib.CombinedElement.NONE:
			break

		combined_elements.append(combo)
		remaining.remove_at(1)
		remaining.remove_at(0)

	loose_elements = remaining


func has_combined_element(combo: int) -> bool:
	return combined_elements.has(combo)


func has_loose_element(element: int) -> bool:
	return loose_elements.has(element)


func get_debug_string() -> String:
	var parts: Array[String] = []

	for combo: int in combined_elements:
		parts.append(ComboLib.get_combo_name(combo))

	for element: int in loose_elements:
		parts.append(PowerUpData.ElementType.keys()[element])

	return " + ".join(parts)
