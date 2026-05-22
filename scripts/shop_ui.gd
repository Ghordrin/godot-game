extends CanvasLayer
class_name ShopUI

signal shop_closed

const OFFER_SIZE: int = 3

## Card scenes per rarity. Assign in the Inspector.
## Until you design Rare/Epic/Legendary cards, CommonCard is used as fallback.
@export var common_card_scene: PackedScene
@export var rare_card_scene: PackedScene
@export var epic_card_scene: PackedScene
@export var legendary_card_scene: PackedScene

const COLOR_COMMON    := Color(0.65, 0.65, 0.6)
const COLOR_RARE      := Color(0.3, 0.55, 0.95)
const COLOR_EPIC      := Color(0.7, 0.25, 0.95)
const COLOR_LEGENDARY := Color(1.0, 0.78, 0.15)
const COLOR_BG_DARK   := Color(0.06, 0.06, 0.09, 0.95)
const COLOR_BG_PANEL  := Color(0.09, 0.09, 0.13, 1.0)
const COLOR_BG_CARD   := Color(0.11, 0.11, 0.16, 1.0)
const COLOR_BG_HEADER := Color(0.08, 0.07, 0.12, 1.0)
const COLOR_ACCENT    := Color(0.4, 0.35, 0.55)
const COLOR_GOLD_TEXT := Color(1.0, 0.84, 0.0)
const COLOR_TITLE     := Color(0.85, 0.82, 0.7)
const COLOR_MUTED     := Color(0.5, 0.48, 0.45)
const COLOR_DISABLED  := Color(0.3, 0.28, 0.26)

var loot_table: PowerUpTable = null
var offer: Array[PowerUpData] = []
var current_wave: int = 0
var selection_made: bool = false

var background: ColorRect
var main_panel: PanelContainer
var wave_label: Label
var gold_label: Label
var current_build_label: Label
var powerup_container: HBoxContainer
var continue_btn: Button
## Stored directly so _update_reroll_button can update it without fragile tree search
var reroll_btn: Button = null
## Heal button — stored for enable/disable toggling
var heal_btn: Button   = null
var card_nodes: Array[PanelContainer] = []

# ══════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	PlayerInventory.gold_changed.connect(_update_gold_display)
	PlayerInventory.equipment_changed.connect(_update_current_build_display)

# ══════════════════════════════════════════════════════════════════════
# UI CONSTRUCTION
# ══════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.8)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	main_panel = PanelContainer.new()
	main_panel.set_anchors_preset(Control.PRESET_CENTER)
	main_panel.offset_left   = -620
	main_panel.offset_top    = -300
	main_panel.offset_right  =  620
	main_panel.offset_bottom =  300
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

	var m := _margin(panel, 24, 12)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	m.add_child(hbox)

	wave_label = Label.new()
	wave_label.add_theme_font_size_override("font_size", 24)
	wave_label.add_theme_color_override("font_color", COLOR_TITLE)
	wave_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(wave_label)

	var gold_panel := PanelContainer.new()
	gold_panel.add_theme_stylebox_override("panel", _make_stylebox(Color(0.12, 0.1, 0.06), 2, Color(0.6, 0.5, 0.2), 6))
	gold_panel.custom_minimum_size = Vector2(160, 0)
	hbox.add_child(gold_panel)

	var gm := _margin(gold_panel, 16, 6)
	gold_label = Label.new()
	gold_label.add_theme_font_size_override("font_size", 18)
	gold_label.add_theme_color_override("font_color", COLOR_GOLD_TEXT)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gm.add_child(gold_label)


func _build_build_section(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_stylebox(
		COLOR_BG_PANEL.lightened(0.05), 1, COLOR_ACCENT.darkened(0.3), 4
	))
	parent.add_child(panel)

	var m := _margin(panel, 20, 10)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	m.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "CURRENT BUILD"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", COLOR_MUTED)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	current_build_label = Label.new()
	current_build_label.add_theme_font_size_override("font_size", 13)
	current_build_label.add_theme_color_override("font_color", COLOR_TITLE)
	current_build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_build_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(current_build_label)


func _build_title(parent: Control) -> void:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 14)
	m.add_theme_constant_override("margin_bottom", 8)
	parent.add_child(m)

	var lbl := Label.new()
	lbl.text = "CHOOSE YOUR UPGRADE"
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", COLOR_TITLE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.add_child(lbl)


func _build_cards(parent: Control) -> void:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left",   20)
	m.add_theme_constant_override("margin_right",  20)
	m.add_theme_constant_override("margin_top",     8)
	m.add_theme_constant_override("margin_bottom", 12)
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(m)

	powerup_container = HBoxContainer.new()
	powerup_container.add_theme_constant_override("separation", 16)
	powerup_container.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(powerup_container)


func _build_footer(parent: Control) -> void:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left",   24)
	m.add_theme_constant_override("margin_right",  24)
	m.add_theme_constant_override("margin_top",    12)
	m.add_theme_constant_override("margin_bottom", 16)
	parent.add_child(m)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	m.add_child(hbox)

	# Reroll button — costs gold, refreshes the three options
	reroll_btn = Button.new()
	reroll_btn.name = "RerollButton"
	reroll_btn.custom_minimum_size = Vector2(160, 48)
	reroll_btn.add_theme_font_size_override("font_size", 13)
	reroll_btn.add_theme_color_override("font_color", COLOR_GOLD_TEXT)
	reroll_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	reroll_btn.add_theme_color_override("font_disabled_color", COLOR_DISABLED)
	reroll_btn.add_theme_stylebox_override("normal",   _make_stylebox(Color(0.12, 0.10, 0.05), 2, Color(0.5, 0.4, 0.1), 6))
	reroll_btn.add_theme_stylebox_override("hover",    _make_stylebox(Color(0.18, 0.15, 0.06), 2, COLOR_GOLD_TEXT, 6))
	reroll_btn.add_theme_stylebox_override("disabled", _make_stylebox(Color(0.08, 0.08, 0.1),  1, COLOR_DISABLED,  6))
	reroll_btn.pressed.connect(_on_reroll_pressed)
	hbox.add_child(reroll_btn)

	# Heal button — restores player to full HP for a gold cost
	heal_btn = Button.new()
	heal_btn.name = "HealButton"
	heal_btn.text = "♥ HEAL FULL"
	heal_btn.custom_minimum_size = Vector2(140, 48)
	heal_btn.add_theme_font_size_override("font_size", 13)
	heal_btn.add_theme_color_override("font_color",          Color(0.85, 0.30, 0.30))
	heal_btn.add_theme_color_override("font_hover_color",    Color.WHITE)
	heal_btn.add_theme_color_override("font_disabled_color", COLOR_DISABLED)
	heal_btn.add_theme_stylebox_override("normal",   _make_stylebox(Color(0.14, 0.06, 0.06), 2, Color(0.55, 0.15, 0.15), 6))
	heal_btn.add_theme_stylebox_override("hover",    _make_stylebox(Color(0.20, 0.08, 0.08), 2, Color(0.85, 0.30, 0.30), 6))
	heal_btn.add_theme_stylebox_override("disabled", _make_stylebox(Color(0.08, 0.08, 0.10), 1, COLOR_DISABLED,          6))
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
	continue_btn.add_theme_stylebox_override("hover",  _make_stylebox(Color(0.2, 0.17, 0.3), 2, COLOR_GOLD_TEXT, 6))
	continue_btn.pressed.connect(_on_continue_pressed)
	hbox.add_child(continue_btn)


## Reroll cost scales with wave so gold stays valuable throughout the run.
## Wave 1 = 40 gold, Wave 10 = 130 gold, Wave 20 = 230 gold.
func _get_reroll_cost() -> int:
	return 40 + current_wave * 9


func _on_reroll_pressed() -> void:
	var cost := _get_reroll_cost()
	if not PlayerInventory.spend_gold(cost):
		return

	# Don't allow reroll if a selection was already made this shop visit
	if selection_made:
		return

	# Roll a fresh offer
	if loot_table:
		offer = loot_table.roll_shop_offer(OFFER_SIZE)

	_refresh_cards()
	_update_gold_display()
	_update_reroll_button()

# ══════════════════════════════════════════════════════════════════════
# CARD CREATION
# ══════════════════════════════════════════════════════════════════════

func _create_card(powerup: PowerUpData) -> PanelContainer:
	var current_rank := PlayerInventory.get_powerup_rank(powerup)

	# Pick the correct scene based on rarity.
	# Falls back to common_card_scene until other rarity scenes are designed.
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

# ══════════════════════════════════════════════════════════════════════
# SHOP LOGIC
# ══════════════════════════════════════════════════════════════════════

func open_shop(wave: int, table: PowerUpTable) -> void:
	current_wave = wave
	loot_table   = table
	selection_made = false

	get_tree().paused = true
	visible = true

	offer.clear()
	if loot_table:
		offer = loot_table.roll_shop_offer(OFFER_SIZE)

	_update_display()


func _update_display() -> void:
	wave_label.text = "WAVE %d" % current_wave
	_update_gold_display()
	_update_current_build_display()
	_refresh_cards()
	_update_reroll_button()


## Cost of a full heal. Scales with wave so it stays meaningful.
func _get_heal_cost() -> int:
	return 50 + current_wave * 8


func _update_reroll_button() -> void:
	## Uses stored reference directly — no fragile tree search
	if reroll_btn == null:
		return
	var cost := _get_reroll_cost()
	var can_afford := PlayerInventory.gold >= cost
	reroll_btn.text = "↺ REROLL  %d" % cost
	reroll_btn.disabled = not can_afford or selection_made
	reroll_btn.add_theme_color_override("font_color",
		COLOR_GOLD_TEXT if (can_afford and not selection_made) else COLOR_DISABLED)

	## Also update heal button
	if heal_btn == null:
		return
	var heal_cost := _get_heal_cost()
	var player_hc := _find_player_health()
	var already_full := player_hc != null and player_hc.current_health >= player_hc.max_health
	var can_afford_heal := PlayerInventory.gold >= heal_cost
	heal_btn.disabled = not can_afford_heal or already_full
	heal_btn.add_theme_color_override("font_color",
		Color(0.85, 0.30, 0.30) if (can_afford_heal and not already_full) else COLOR_DISABLED)


func _find_player_health() -> HealthComponent:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0].get_node_or_null("HealthComponent") as HealthComponent


func _on_heal_pressed() -> void:
	var cost := _get_heal_cost()
	if not PlayerInventory.spend_gold(cost):
		return
	var hc := _find_player_health()
	if hc:
		hc.heal(hc.max_health)  # Heal to full
	_update_gold_display()


func _update_gold_display(_val: int = 0) -> void:
	if gold_label:
		gold_label.text = "%d GOLD" % PlayerInventory.gold
	_update_reroll_button()


func _update_current_build_display() -> void:
	if current_build_label == null:
		return

	var equipped := PlayerInventory.get_equipped_powerups_with_ranks()
	if equipped.is_empty():
		current_build_label.text = "EMPTY"
		current_build_label.add_theme_color_override("font_color", COLOR_MUTED)
		return

	var parts: Array[String] = []
	for entry in equipped:
		parts.append("%s %d" % [_abbreviate(entry.powerup.display_name), entry.rank])

	if not PlayerInventory.active_combinations.is_empty():
		for combo_name in PlayerInventory.get_combination_names():
			parts.append("— %s" % combo_name)

	current_build_label.text = " | ".join(parts)
	current_build_label.add_theme_color_override("font_color", COLOR_TITLE)


func _refresh_cards() -> void:
	for card in card_nodes:
		card.queue_free()
	card_nodes.clear()

	for powerup in offer:
		var card := _create_card(powerup)
		powerup_container.add_child(card)
		card_nodes.append(card)


func _on_powerup_selected(powerup: PowerUpData) -> void:
	if selection_made:
		return
	selection_made = true

	PlayerInventory.collect_powerup(powerup)
	if not PlayerInventory.is_equipped(powerup):
		PlayerInventory.equip_powerup(powerup)

	# Tell each card whether it was chosen or not
	for card in card_nodes:
		if card.has_method("set_selected"):
			var was_chosen: bool = card._powerup == powerup
			card.set_selected(was_chosen)

	_update_current_build_display()
	_update_reroll_button()


func _on_continue_pressed() -> void:
	visible = false
	get_tree().paused = false
	shop_closed.emit()

# ══════════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════════

func _get_all_buttons(node: Node) -> Array:
	var result := []
	for child in node.get_children():
		if child is Button:
			result.append(child)
		result.append_array(_get_all_buttons(child))
	return result


func _abbreviate(full_name: String) -> String:
	var cleaned := full_name.to_upper()
	cleaned = cleaned.replace(" UP", "").replace(" DOWN", "")
	cleaned = cleaned.replace(" THE", "").replace(" OF", "")
	var words := cleaned.split(" ")
	if words.size() == 1:
		return words[0].substr(0, min(4, words[0].length()))
	elif words.size() == 2:
		return words[0].substr(0, 3) + words[1].substr(0, 1)
	else:
		var abbrev := ""
		for w in words:
			if w.length() > 0:
				abbrev += w[0]
		return abbrev.substr(0, 5)


func _margin(parent: Node, h: int, v: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left",   h)
	m.add_theme_constant_override("margin_right",  h)
	m.add_theme_constant_override("margin_top",    v)
	m.add_theme_constant_override("margin_bottom", v)
	parent.add_child(m)
	return m


func _make_separator(color: Color) -> HSeparator:
	var sep := HSeparator.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.content_margin_top = 2
	sep.add_theme_stylebox_override("separator", sb)
	return sep


func _make_thin_sep(color: Color) -> HSeparator:
	var sep := HSeparator.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.5)
	sb.content_margin_top = 1
	sep.add_theme_stylebox_override("separator", sb)
	return sep


func _make_stylebox(bg: Color, border: int, border_color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color     = bg
	sb.border_color = border_color
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left   = 4
	sb.content_margin_right  = 4
	sb.content_margin_top    = 4
	sb.content_margin_bottom = 4
	return sb


func _get_rarity_color(rarity: int) -> Color:
	match rarity:
		PowerUpData.Rarity.COMMON:    return COLOR_COMMON
		PowerUpData.Rarity.RARE:      return COLOR_RARE
		PowerUpData.Rarity.EPIC:      return COLOR_EPIC
		PowerUpData.Rarity.LEGENDARY: return COLOR_LEGENDARY
	return COLOR_COMMON
