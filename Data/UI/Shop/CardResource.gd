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

	var active_elements: Array[int] = _get_active_element_types_in_order()

	# Ranking up an already owned element should not show a new combo unlock.
	if active_elements.has(powerup.element_type):
		return ""

	var preview_elements: Array[int] = active_elements.duplicate()
	preview_elements.append(powerup.element_type)

	var combo_name: String = _get_new_combo_created_by_last_element(active_elements, preview_elements)

	return combo_name


func _get_active_element_types_in_order() -> Array[int]:
	var result: Array[int] = []

	for entry in PlayerInventory.get_equipped_powerups_with_ranks():
		if not entry.has("powerup"):
			continue

		var powerup: PowerUpData = entry.powerup

		_add_element_if_valid(result, powerup)

	for powerup in PlayerInventory.get_wave_temporary_powerups():
		_add_element_if_valid(result, powerup)

	return result


func _add_element_if_valid(result: Array[int], powerup: PowerUpData) -> void:
	if powerup == null:
		return

	if not "element_type" in powerup:
		return

	if powerup.element_type == PowerUpData.ElementType.NONE:
		return

	if result.has(powerup.element_type):
		return

	result.append(powerup.element_type)


func _get_new_combo_created_by_last_element(
	old_elements: Array[int],
	preview_elements: Array[int]
) -> String:
	var old_combos: Array[String] = _build_combo_names_from_order(old_elements)
	var preview_combos: Array[String] = _build_combo_names_from_order(preview_elements)

	for combo_name in preview_combos:
		if not old_combos.has(combo_name):
			return combo_name

	return ""


func _build_combo_names_from_order(elements: Array[int]) -> Array[String]:
	var remaining: Array[int] = elements.duplicate()
	var combos: Array[String] = []

	while remaining.size() >= 2:
		var first: int = remaining[0]
		var second: int = remaining[1]
		var combo_name: String = _get_combo_name(first, second)

		if combo_name == "":
			break

		combos.append(combo_name)
		remaining.remove_at(1)
		remaining.remove_at(0)

	return combos


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
