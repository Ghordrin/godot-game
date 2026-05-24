extends CanvasLayer
class_name ShopUI

signal shop_closed

const OFFER_SIZE: int = 3

@export var common_card_scene: PackedScene
@export var rare_card_scene: PackedScene
@export var epic_card_scene: PackedScene
@export var legendary_card_scene: PackedScene

const COLOR_COMMON := Color(0.65, 0.65, 0.6)
const COLOR_RARE := Color(0.3, 0.55, 0.95)
const COLOR_EPIC := Color(0.7, 0.25, 0.95)
const COLOR_LEGENDARY := Color(1.0, 0.78, 0.15)
const COLOR_BG_DARK := Color(0.06, 0.06, 0.09, 0.95)
const COLOR_BG_PANEL := Color(0.09, 0.09, 0.13, 1.0)
const COLOR_BG_HEADER := Color(0.08, 0.07, 0.12, 1.0)
const COLOR_ACCENT := Color(0.4, 0.35, 0.55)
const COLOR_GOLD_TEXT := Color(1.0, 0.84, 0.0)
const COLOR_TITLE := Color(0.85, 0.82, 0.7)
const COLOR_MUTED := Color(0.5, 0.48, 0.45)
const COLOR_DISABLED := Color(0.3, 0.28, 0.26)

var loot_table: PowerUpTable = null
var offer: Array[PowerUpData] = []
var current_wave: int = 0

var selected_powerup: PowerUpData = null
var selection_confirmed: bool = false

var background: ColorRect
var main_panel: PanelContainer
var wave_label: Label
var gold_label: Label
var current_build_label: Label
var powerup_container: HBoxContainer
var continue_btn: Button
var reroll_btn: Button = null
var heal_btn: Button = null
var card_nodes: Array[PanelContainer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

	if not PlayerInventory.gold_changed.is_connected(_update_gold_display):
		PlayerInventory.gold_changed.connect(_update_gold_display)

	if not PlayerInventory.equipment_changed.is_connected(_update_current_build_display):
		PlayerInventory.equipment_changed.connect(_update_current_build_display)

	visible = false


func _build_ui() -> void:
	background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.8)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	main_panel = PanelContainer.new()
	main_panel.set_anchors_preset(Control.PRESET_CENTER)
	main_panel.offset_left = -620
	main_panel.offset_top = -300
	main_panel.offset_right = 620
	main_panel.offset_bottom = 300
	main_panel.add_theme_stylebox_override("panel", _make_stylebox(COLOR_BG_DARK, 2, COLOR_ACCENT, 8))
	add_child(main_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	main_panel.add_child(root)

	_build_header(root)
	root.add_child(_make_separator(COLOR_ACCENT))
	_build_build_section(root)
	_build_title(root)
	_build_cards(root)
	root.add_child(_make_separator(COLOR_ACCENT))
	_build_footer(root)


func _build_header(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_stylebox(COLOR_BG_HEADER, 0, Color.TRANSPARENT, 0))
	panel.custom_minimum_size.y = 60
	parent.add_child(panel)

	var margin := _margin(panel, 24, 12)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)

	wave_label = Label.new()
	wave_label.add_theme_font_size_override("font_size", 24)
	wave_label.add_theme_color_override("font_color", COLOR_TITLE)
	wave_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(wave_label)

	var gold_panel := PanelContainer.new()
	gold_panel.add_theme_stylebox_override("panel", _make_stylebox(Color(0.12, 0.1, 0.06), 2, Color(0.6, 0.5, 0.2), 6))
	gold_panel.custom_minimum_size = Vector2(160, 0)
	hbox.add_child(gold_panel)

	var gold_margin := _margin(gold_panel, 16, 6)

	gold_label = Label.new()
	gold_label.add_theme_font_size_override("font_size", 18)
	gold_label.add_theme_color_override("font_color", COLOR_GOLD_TEXT)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_margin.add_child(gold_label)


func _build_build_section(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(COLOR_BG_PANEL.lightened(0.05), 1, COLOR_ACCENT.darkened(0.3), 4)
	)
	parent.add_child(panel)

	var margin := _margin(panel, 20, 10)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var label := Label.new()
	label.text = "CURRENT BUILD"
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", COLOR_MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	current_build_label = Label.new()
	current_build_label.add_theme_font_size_override("font_size", 13)
	current_build_label.add_theme_color_override("font_color", COLOR_TITLE)
	current_build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_build_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(current_build_label)


func _build_title(parent: Control) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 8)
	parent.add_child(margin)

	var label := Label.new()
	label.text = "CHOOSE YOUR UPGRADE"
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", COLOR_TITLE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	margin.add_child(label)


func _build_cards(parent: Control) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(margin)

	powerup_container = HBoxContainer.new()
	powerup_container.add_theme_constant_override("separation", 16)
	powerup_container.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(powerup_container)


func _build_footer(parent: Control) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 16)
	parent.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	reroll_btn = Button.new()
	reroll_btn.name = "RerollButton"
	reroll_btn.custom_minimum_size = Vector2(160, 48)
	reroll_btn.add_theme_font_size_override("font_size", 13)
	reroll_btn.add_theme_color_override("font_color", COLOR_GOLD_TEXT)
	reroll_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	reroll_btn.add_theme_color_override("font_disabled_color", COLOR_DISABLED)
	reroll_btn.add_theme_stylebox_override("normal", _make_stylebox(Color(0.12, 0.10, 0.05), 2, Color(0.5, 0.4, 0.1), 6))
	reroll_btn.add_theme_stylebox_override("hover", _make_stylebox(Color(0.18, 0.15, 0.06), 2, COLOR_GOLD_TEXT, 6))
	reroll_btn.add_theme_stylebox_override("disabled", _make_stylebox(Color(0.08, 0.08, 0.1), 1, COLOR_DISABLED, 6))
	reroll_btn.pressed.connect(_on_reroll_pressed)
	hbox.add_child(reroll_btn)

	heal_btn = Button.new()
	heal_btn.name = "HealButton"
	heal_btn.text = "♥ HEAL FULL"
	heal_btn.custom_minimum_size = Vector2(140, 48)
	heal_btn.add_theme_font_size_override("font_size", 13)
	heal_btn.add_theme_color_override("font_color", Color(0.85, 0.30, 0.30))
	heal_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	heal_btn.add_theme_color_override("font_disabled_color", COLOR_DISABLED)
	heal_btn.add_theme_stylebox_override("normal", _make_stylebox(Color(0.14, 0.06, 0.06), 2, Color(0.55, 0.15, 0.15), 6))
	heal_btn.add_theme_stylebox_override("hover", _make_stylebox(Color(0.20, 0.08, 0.08), 2, Color(0.85, 0.30, 0.30), 6))
	heal_btn.add_theme_stylebox_override("disabled", _make_stylebox(Color(0.08, 0.08, 0.10), 1, COLOR_DISABLED, 6))
	heal_btn.pressed.connect(_on_heal_pressed)
	hbox.add_child(heal_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	continue_btn = Button.new()
	continue_btn.text = "CONTINUE  ▶"
	continue_btn.custom_minimum_size = Vector2(200, 48)
	continue_btn.add_theme_font_size_override("font_size", 15)
	continue_btn.add_theme_color_override("font_color", Color.WHITE)
	continue_btn.add_theme_color_override("font_hover_color", COLOR_GOLD_TEXT)
	continue_btn.add_theme_stylebox_override("normal", _make_stylebox(Color(0.15, 0.13, 0.22), 2, COLOR_ACCENT, 6))
	continue_btn.add_theme_stylebox_override("hover", _make_stylebox(Color(0.2, 0.17, 0.3), 2, COLOR_GOLD_TEXT, 6))
	continue_btn.pressed.connect(_on_continue_pressed)
	hbox.add_child(continue_btn)


func open_shop(wave: int, table: PowerUpTable) -> void:
	current_wave = wave
	loot_table = table
	selected_powerup = null
	selection_confirmed = false

	get_tree().paused = true
	visible = true

	_roll_new_offer()
	_update_display()


func _roll_new_offer() -> void:
	offer.clear()

	if loot_table != null:
		offer = loot_table.roll_shop_offer(OFFER_SIZE)


func _update_display() -> void:
	wave_label.text = "WAVE %d" % current_wave
	_update_gold_display()
	_update_current_build_display()
	_refresh_cards()
	_update_reroll_button()
	_update_continue_button()


func _refresh_cards() -> void:
	for card in card_nodes:
		card.queue_free()

	card_nodes.clear()

	for powerup in offer:
		var card := _create_card(powerup)
		powerup_container.add_child(card)
		card_nodes.append(card)


func _create_card(powerup: PowerUpData) -> PanelContainer:
	var current_rank: int = PlayerInventory.get_powerup_rank(powerup)
	var scene := _get_card_scene(powerup.rarity)

	if scene == null:
		push_warning("ShopUI: no card scene assigned for rarity %d" % powerup.rarity)
		return PanelContainer.new()

	var card := scene.instantiate() as PanelContainer
	card.populate(powerup, current_rank)
	card.powerup_selected.connect(_on_powerup_selected)
	return card


func _get_card_scene(rarity: int) -> PackedScene:
	match rarity:
		PowerUpData.Rarity.LEGENDARY:
			return legendary_card_scene if legendary_card_scene else common_card_scene
		PowerUpData.Rarity.EPIC:
			return epic_card_scene if epic_card_scene else common_card_scene
		PowerUpData.Rarity.RARE:
			return rare_card_scene if rare_card_scene else common_card_scene
		_:
			return common_card_scene


func _on_powerup_selected(powerup: PowerUpData) -> void:
	if selection_confirmed:
		return

	selected_powerup = powerup

	for card in card_nodes:
		if card.has_method("set_selected"):
			var was_chosen: bool = false

			if "_powerup" in card:
				was_chosen = card._powerup == selected_powerup

			card.set_selected(was_chosen, false)

	_update_continue_button()


func _on_continue_pressed() -> void:
	if selected_powerup != null and not selection_confirmed:
		_confirm_selected_powerup()

	visible = false
	get_tree().paused = false
	shop_closed.emit()


func _confirm_selected_powerup() -> void:
	if selected_powerup == null:
		return

	selection_confirmed = true

	PlayerInventory.collect_powerup(selected_powerup)

	if not PlayerInventory.is_equipped(selected_powerup):
		PlayerInventory.equip_powerup(selected_powerup)

	_update_current_build_display()
	_update_reroll_button()
	_update_continue_button()


func _on_reroll_pressed() -> void:
	if selection_confirmed:
		return

	var cost := _get_reroll_cost()

	if not PlayerInventory.spend_gold(cost):
		return

	selected_powerup = null
	_roll_new_offer()
	_refresh_cards()
	_update_gold_display()
	_update_reroll_button()
	_update_continue_button()


func _on_heal_pressed() -> void:
	var cost := _get_heal_cost()

	if not PlayerInventory.spend_gold(cost):
		return

	var health_component := _find_player_health()

	if health_component != null:
		health_component.heal(health_component.max_health)

	_update_gold_display()
	_update_reroll_button()


func _update_gold_display(_val: int = 0) -> void:
	if gold_label != null:
		gold_label.text = "%d GOLD" % PlayerInventory.gold

	_update_reroll_button()


func _update_current_build_display() -> void:
	if current_build_label == null:
		return

	var equipped: Array = PlayerInventory.get_equipped_powerups_with_ranks()

	if equipped.is_empty():
		current_build_label.text = "EMPTY"
		current_build_label.add_theme_color_override("font_color", COLOR_MUTED)
		return

	var parts: Array[String] = []

	for entry in equipped:
		parts.append("%s %d" % [_abbreviate(entry.powerup.display_name), entry.rank])

	var combo_names: Array[String] = PlayerInventory.get_combination_names()

	for combo_name in combo_names:
		parts.append("— %s" % combo_name)

	current_build_label.text = " | ".join(parts)
	current_build_label.add_theme_color_override("font_color", COLOR_TITLE)


func _update_reroll_button() -> void:
	if reroll_btn == null:
		return

	var cost := _get_reroll_cost()
	var can_afford: bool = PlayerInventory.gold >= cost

	reroll_btn.text = "↺ REROLL  %d" % cost
	reroll_btn.disabled = not can_afford or selection_confirmed
	reroll_btn.add_theme_color_override(
		"font_color",
		COLOR_GOLD_TEXT if can_afford and not selection_confirmed else COLOR_DISABLED
	)

	if heal_btn == null:
		return

	var heal_cost := _get_heal_cost()
	var player_health := _find_player_health()
	var already_full: bool = player_health != null and player_health.current_health >= player_health.max_health
	var can_afford_heal: bool = PlayerInventory.gold >= heal_cost

	heal_btn.text = "♥ HEAL  %d" % heal_cost
	heal_btn.disabled = not can_afford_heal or already_full
	heal_btn.add_theme_color_override(
		"font_color",
		Color(0.85, 0.30, 0.30) if can_afford_heal and not already_full else COLOR_DISABLED
	)


func _update_continue_button() -> void:
	if continue_btn == null:
		return

	if selected_powerup == null:
		continue_btn.text = "SKIP  ▶"
	else:
		continue_btn.text = "CONFIRM  ▶"


func _get_reroll_cost() -> int:
	return 40 + current_wave * 9


func _get_heal_cost() -> int:
	return 50 + current_wave * 8


func _find_player_health() -> HealthComponent:
	var players := get_tree().get_nodes_in_group("player")

	if players.is_empty():
		return null

	return players[0].get_node_or_null("HealthComponent") as HealthComponent


func _abbreviate(full_name: String) -> String:
	var cleaned := full_name.to_upper()
	cleaned = cleaned.replace(" UP", "").replace(" DOWN", "")
	cleaned = cleaned.replace(" THE", "").replace(" OF", "")

	var words := cleaned.split(" ")

	if words.size() == 1:
		return words[0].substr(0, min(4, words[0].length()))

	if words.size() == 2:
		return words[0].substr(0, 3) + words[1].substr(0, 1)

	var abbrev := ""

	for word in words:
		if word.length() > 0:
			abbrev += word[0]

	return abbrev.substr(0, 5)


func _margin(parent: Node, horizontal: int, vertical: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_right", horizontal)
	margin.add_theme_constant_override("margin_top", vertical)
	margin.add_theme_constant_override("margin_bottom", vertical)
	parent.add_child(margin)
	return margin


func _make_separator(color: Color) -> HSeparator:
	var separator := HSeparator.new()
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = color
	stylebox.content_margin_top = 2
	separator.add_theme_stylebox_override("separator", stylebox)
	return separator


func _make_stylebox(bg: Color, border: int, border_color: Color, radius: int) -> StyleBoxFlat:
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = bg
	stylebox.border_color = border_color
	stylebox.set_border_width_all(border)
	stylebox.set_corner_radius_all(radius)
	stylebox.content_margin_left = 4
	stylebox.content_margin_right = 4
	stylebox.content_margin_top = 4
	stylebox.content_margin_bottom = 4
	return stylebox


func _get_rarity_color(rarity: int) -> Color:
	match rarity:
		PowerUpData.Rarity.COMMON:
			return COLOR_COMMON
		PowerUpData.Rarity.RARE:
			return COLOR_RARE
		PowerUpData.Rarity.EPIC:
			return COLOR_EPIC
		PowerUpData.Rarity.LEGENDARY:
			return COLOR_LEGENDARY

	return COLOR_COMMON
