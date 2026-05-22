extends PanelContainer

signal powerup_selected(powerup: PowerUpData)

var _powerup: PowerUpData = null
@export var card_texture: Texture2D


#func _ready() -> void:
	#if card_texture:
		#var style := StyleBoxTexture.new()
		#style.texture = card_texture
		#style.content_margin_left = 30
		#style.content_margin_top = 40
		#style.content_margin_right = 30
		#style.content_margin_bottom = 40
		#add_theme_stylebox_override("panel", style)

func populate(powerup: PowerUpData, current_rank: int) -> void:
	_powerup = powerup

	%RarityLabel.text = PowerUpData.Rarity.keys()[powerup.rarity]
	%NameLabel.text = powerup.display_name
	%RankLabel.text = "Rank %d" % current_rank
	%SeparatorLabel.text = "/"
	%MaxRankLabel.text = str(powerup.max_stacks)

	if powerup.icon:
		%IconRect.texture = powerup.icon

	# Build description with optional combination hint
	var desc := powerup.description if powerup.description else "No description."
	var combo_hint := _get_combination_hint(powerup)
	if combo_hint != "":
		desc += "\n\n⚡ EQUIP TO UNLOCK\n%s" % combo_hint
	%DescriptionLabel.text = desc

	if current_rank >= powerup.max_stacks:
		%SelectButton.text = "MAXED"
		%SelectButton.disabled = true
	else:
		%SelectButton.text = "SELECT" if current_rank == 0 else "RANK UP"
		%SelectButton.disabled = false
		%SelectButton.pressed.connect(func(): powerup_selected.emit(_powerup))


func set_selected(was_chosen: bool) -> void:
	if was_chosen:
		%SelectButton.text = "✓ SELECTED"
		%SelectButton.disabled = true
	else:
		%SelectButton.disabled = true
		modulate = Color(0.5, 0.5, 0.5, 0.7)


## Checks whether equipping this powerup would unlock an elemental combination.
## Returns the combination name if so, empty string if not.
func _get_combination_hint(powerup: PowerUpData) -> String:
	if not "element_type" in powerup:
		return ""
	if powerup.element_type == PowerUpData.ElementType.NONE:
		return ""

	# Collect currently equipped element types
	var equipped_elements: Array = []
	for entry in PlayerInventory.get_equipped_powerups_with_ranks():
		var ep: PowerUpData = entry.powerup
		if "element_type" in ep and ep.element_type != PowerUpData.ElementType.NONE:
			if not equipped_elements.has(ep.element_type):
				equipped_elements.append(ep.element_type)

	# If player already has this element, no new combo to unlock
	if equipped_elements.has(powerup.element_type):
		return ""

	var new_el: int = powerup.element_type

	# Check each possible combination — does adding this element complete one?
	var combos: Array = [
		[PowerUpData.ElementType.FIRE,      PowerUpData.ElementType.ICE,       "SHATTER"],
		[PowerUpData.ElementType.FIRE,      PowerUpData.ElementType.LIGHTNING,  "SUPERHEATED ARC"],
		[PowerUpData.ElementType.FIRE,      PowerUpData.ElementType.POISON,     "ACID CLOUD"],
		[PowerUpData.ElementType.ICE,       PowerUpData.ElementType.LIGHTNING,  "MAGNETIC FREEZE"],
		[PowerUpData.ElementType.ICE,       PowerUpData.ElementType.POISON,     "CRYSTALLIZE"],
		[PowerUpData.ElementType.LIGHTNING, PowerUpData.ElementType.POISON,     "CONTAGION PULSE"],
	]

	for combo in combos:
		var el1: int    = combo[0]
		var el2: int    = combo[1]
		var combo_name: String = combo[2]

		if new_el == el1 and equipped_elements.has(el2):
			return combo_name
		if new_el == el2 and equipped_elements.has(el1):
			return combo_name

	return ""
