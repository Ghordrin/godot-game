extends PanelContainer

signal powerup_selected(powerup: PowerUpData)

var _powerup: PowerUpData = null
@export var card_texture: Texture2D


func populate(powerup: PowerUpData, current_rank: int) -> void:
	_powerup = powerup
	modulate = Color.WHITE

	%RarityLabel.text = PowerUpData.Rarity.keys()[powerup.rarity]
	%NameLabel.text = powerup.display_name
	%RankLabel.text = "Rank %d" % current_rank
	%SeparatorLabel.text = "/"
	%MaxRankLabel.text = str(powerup.max_stacks)

	if powerup.icon:
		%IconRect.texture = powerup.icon

	var desc := powerup.description if powerup.description else "No description."
	var combo_hint := _get_combination_hint(powerup)

	if combo_hint != "":
		desc += "\n\n⚡ EQUIP TO UNLOCK\n%s" % combo_hint

	%DescriptionLabel.text = desc

	if current_rank >= powerup.max_stacks:
		%SelectButton.text = "MAXED"
		%SelectButton.disabled = true
		return

	%SelectButton.text = "SELECT" if current_rank == 0 else "RANK UP"
	%SelectButton.disabled = false

	if not %SelectButton.pressed.is_connected(_on_select_pressed):
		%SelectButton.pressed.connect(_on_select_pressed)


func _on_select_pressed() -> void:
	if _powerup == null:
		return

	powerup_selected.emit(_powerup)


func set_selected(was_chosen: bool, lock_choice: bool = false) -> void:
	if _powerup == null:
		return

	if was_chosen:
		%SelectButton.text = "✓ SELECTED"
		%SelectButton.disabled = false
		modulate = Color(1.15, 1.15, 1.15, 1.0)
		return

	var current_rank: int = PlayerInventory.get_powerup_rank(_powerup)

	if current_rank >= _powerup.max_stacks:
		%SelectButton.text = "MAXED"
		%SelectButton.disabled = true
	else:
		%SelectButton.text = "SELECT" if current_rank == 0 else "RANK UP"
		%SelectButton.disabled = lock_choice
		modulate = Color.WHITE if not lock_choice else Color(0.5, 0.5, 0.5, 0.7)


func _get_combination_hint(powerup: PowerUpData) -> String:
	if powerup == null:
		return ""

	if not "element_type" in powerup:
		return ""

	if powerup.element_type == PowerUpData.ElementType.NONE:
		return ""

	var equipped_elements: Array[int] = _get_equipped_element_types()

	if equipped_elements.has(powerup.element_type):
		return ""

	var combo_names: Array[String] = []

	for equipped_element in equipped_elements:
		var combo_name: String = _get_combo_name(equipped_element, powerup.element_type)

		if combo_name != "":
			combo_names.append(combo_name)

	if combo_names.is_empty():
		return ""

	return "\n".join(combo_names)


func _get_equipped_element_types() -> Array[int]:
	var result: Array[int] = []

	for entry in PlayerInventory.get_equipped_powerups_with_ranks():
		if not entry.has("powerup"):
			continue

		var powerup: PowerUpData = entry.powerup

		if powerup == null:
			continue

		if powerup.element_type == PowerUpData.ElementType.NONE:
			continue

		if not result.has(powerup.element_type):
			result.append(powerup.element_type)

	return result


func _get_combo_name(a: int, b: int) -> String:
	if _same_pair(a, b, PowerUpData.ElementType.FIRE, PowerUpData.ElementType.ICE):
		return "THERMAL"

	if _same_pair(a, b, PowerUpData.ElementType.FIRE, PowerUpData.ElementType.LIGHTNING):
		return "PLASMA"

	if _same_pair(a, b, PowerUpData.ElementType.FIRE, PowerUpData.ElementType.POISON):
		return "CORROSIVE"

	if _same_pair(a, b, PowerUpData.ElementType.ICE, PowerUpData.ElementType.LIGHTNING):
		return "MAGNETIC"

	if _same_pair(a, b, PowerUpData.ElementType.ICE, PowerUpData.ElementType.POISON):
		return "VIRAL"

	if _same_pair(a, b, PowerUpData.ElementType.LIGHTNING, PowerUpData.ElementType.POISON):
		return "NEUROTOXIN"

	return ""


func _same_pair(a: int, b: int, x: int, y: int) -> bool:
	return (a == x and b == y) or (a == y and b == x)
