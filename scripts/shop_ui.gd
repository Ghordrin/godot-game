extends CanvasLayer
class_name ShopUI

signal shop_closed

@export var available_powerups_count: int = 6
@export var common_cost: int = 50
@export var rare_cost: int = 300
@export var epic_cost: int = 700
@export var legendary_cost: int = 1500

const COLOR_COMMON := Color(0.65, 0.65, 0.6)
const COLOR_RARE := Color(0.3, 0.55, 0.95)
const COLOR_EPIC := Color(0.7, 0.25, 0.95)
const COLOR_LEGENDARY := Color(1.0, 0.78, 0.15)

const COLOR_BG_DARK := Color(0.06, 0.06, 0.09, 0.95)
const COLOR_BG_PANEL := Color(0.09, 0.09, 0.13, 1.0)
const COLOR_BG_CARD := Color(0.11, 0.11, 0.16, 1.0)
const COLOR_BG_HEADER := Color(0.08, 0.07, 0.12, 1.0)
const COLOR_ACCENT := Color(0.4, 0.35, 0.55)
const COLOR_GOLD_TEXT := Color(1.0, 0.84, 0.0)
const COLOR_TITLE := Color(0.85, 0.82, 0.7)
const COLOR_MUTED := Color(0.5, 0.48, 0.45)
const COLOR_DISABLED := Color(0.3, 0.28, 0.26)

var loot_table: PowerUpTable = null
var available_powerups: Array[PowerUpData] = []
var current_wave: int = 0

var background: ColorRect
var main_panel: PanelContainer
var header_box: HBoxContainer
var wave_label: Label
var gold_label: Label
var content_box: HBoxContainer
var powerup_grid: GridContainer
var equip_vbox: VBoxContainer
var continue_btn: Button
var owned_list: VBoxContainer

var card_nodes: Array[PanelContainer] = []
var equip_slot_nodes: Array[PanelContainer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

	if not PlayerInventory.gold_changed.is_connected(_update_gold_display):
		PlayerInventory.gold_changed.connect(_update_gold_display)


func _build_ui() -> void:
	background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.75)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	main_panel = PanelContainer.new()
	main_panel.set_anchors_preset(Control.PRESET_CENTER)
	main_panel.offset_left = -520
	main_panel.offset_top = -310
	main_panel.offset_right = 520
	main_panel.offset_bottom = 310
	main_panel.add_theme_stylebox_override("panel", _make_stylebox(COLOR_BG_DARK, 2, COLOR_ACCENT, 6))
	add_child(main_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.name = "RootVBox"
	root_vbox.add_theme_constant_override("separation", 0)
	main_panel.add_child(root_vbox)

	_build_header(root_vbox)

	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", _make_flat_line(COLOR_ACCENT, 1))
	root_vbox.add_child(sep)

	var content_margin := MarginContainer.new()
	content_margin.name = "ContentMargin"
	content_margin.add_theme_constant_override("margin_left", 16)
	content_margin.add_theme_constant_override("margin_right", 16)
	content_margin.add_theme_constant_override("margin_top", 12)
	content_margin.add_theme_constant_override("margin_bottom", 8)
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(content_margin)

	content_box = HBoxContainer.new()
	content_box.name = "ContentBox"
	content_box.add_theme_constant_override("separation", 16)
	content_margin.add_child(content_box)

	_build_powerup_section(content_box)
	_build_equipment_section(content_box)

	var sep2 := HSeparator.new()
	sep2.add_theme_stylebox_override("separator", _make_flat_line(COLOR_ACCENT, 1))
	root_vbox.add_child(sep2)

	_build_footer(root_vbox)


func _build_header(parent: VBoxContainer) -> void:
	var header_panel := PanelContainer.new()
	header_panel.name = "HeaderPanel"
	header_panel.add_theme_stylebox_override("panel", _make_stylebox(COLOR_BG_HEADER, 0, Color.TRANSPARENT, 0))
	header_panel.custom_minimum_size.y = 56
	parent.add_child(header_panel)

	var margin := MarginContainer.new()
	margin.name = "HeaderMargin"
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	header_panel.add_child(margin)

	header_box = HBoxContainer.new()
	header_box.name = "HeaderBox"
	header_box.add_theme_constant_override("separation", 16)
	margin.add_child(header_box)

	wave_label = Label.new()
	wave_label.text = "ARMORY"
	wave_label.add_theme_font_size_override("font_size", 22)
	wave_label.add_theme_color_override("font_color", COLOR_TITLE)
	wave_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_child(wave_label)

	var gold_panel := PanelContainer.new()
	gold_panel.name = "GoldPanel"
	gold_panel.add_theme_stylebox_override("panel", _make_stylebox(Color(0.12, 0.1, 0.06), 1, Color(0.6, 0.5, 0.2), 4))
	gold_panel.custom_minimum_size = Vector2(160, 0)
	header_box.add_child(gold_panel)

	var gold_margin := MarginContainer.new()
	gold_margin.name = "GoldMargin"
	gold_margin.add_theme_constant_override("margin_left", 12)
	gold_margin.add_theme_constant_override("margin_right", 12)
	gold_margin.add_theme_constant_override("margin_top", 4)
	gold_margin.add_theme_constant_override("margin_bottom", 4)
	gold_panel.add_child(gold_margin)

	gold_label = Label.new()
	gold_label.name = "GoldLabel"
	gold_label.text = "0"
	gold_label.add_theme_font_size_override("font_size", 18)
	gold_label.add_theme_color_override("font_color", COLOR_GOLD_TEXT)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_margin.add_child(gold_label)


func _build_powerup_section(parent: HBoxContainer) -> void:
	var section := VBoxContainer.new()
	section.name = "PowerupSection"
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 8)
	parent.add_child(section)

	var title := Label.new()
	title.text = "AVAILABLE UPGRADES"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", COLOR_MUTED)
	section.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.name = "PowerupScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	section.add_child(scroll)

	powerup_grid = GridContainer.new()
	powerup_grid.name = "PowerupGrid"
	powerup_grid.columns = 2
	powerup_grid.add_theme_constant_override("h_separation", 8)
	powerup_grid.add_theme_constant_override("v_separation", 8)
	powerup_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(powerup_grid)


func _build_equipment_section(parent: HBoxContainer) -> void:
	var section := VBoxContainer.new()
	section.name = "EquipmentSection"
	section.custom_minimum_size.x = 200
	section.add_theme_constant_override("separation", 8)
	parent.add_child(section)

	var title := Label.new()
	title.text = "YOUR BUILD"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", COLOR_MUTED)
	section.add_child(title)

	equip_vbox = VBoxContainer.new()
	equip_vbox.name = "EquipVBox"
	equip_vbox.add_theme_constant_override("separation", 6)
	equip_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_child(equip_vbox)
	
	var owned_title := Label.new()
	owned_title.text = "OWNED"
	owned_title.add_theme_font_size_override("font_size", 12)
	owned_title.add_theme_color_override("font_color", COLOR_MUTED)
	section.add_child(owned_title)

	owned_list = VBoxContainer.new()
	owned_list.add_theme_constant_override("separation", 3)
	section.add_child(owned_list)

	for slot in PlayerInventory.EQUIPMENT_SLOTS:
		var slot_panel := _create_equip_slot(slot)
		equip_vbox.add_child(slot_panel)
		equip_slot_nodes.append(slot_panel)


func _build_footer(parent: VBoxContainer) -> void:
	var footer_margin := MarginContainer.new()
	footer_margin.name = "FooterMargin"
	footer_margin.add_theme_constant_override("margin_left", 16)
	footer_margin.add_theme_constant_override("margin_right", 16)
	footer_margin.add_theme_constant_override("margin_top", 8)
	footer_margin.add_theme_constant_override("margin_bottom", 12)
	parent.add_child(footer_margin)

	var footer_box := HBoxContainer.new()
	footer_box.name = "FooterBox"
	footer_margin.add_child(footer_box)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_box.add_child(spacer)

	continue_btn = Button.new()
	continue_btn.text = "CONTINUE  ▶"
	continue_btn.custom_minimum_size = Vector2(200, 44)
	continue_btn.add_theme_font_size_override("font_size", 14)
	continue_btn.add_theme_color_override("font_color", Color.WHITE)
	continue_btn.add_theme_color_override("font_hover_color", COLOR_GOLD_TEXT)
	continue_btn.add_theme_stylebox_override("normal", _make_stylebox(Color(0.15, 0.13, 0.22), 1, COLOR_ACCENT, 4))
	continue_btn.add_theme_stylebox_override("hover", _make_stylebox(Color(0.2, 0.17, 0.3), 2, COLOR_GOLD_TEXT, 4))
	continue_btn.add_theme_stylebox_override("pressed", _make_stylebox(Color(0.12, 0.1, 0.18), 2, COLOR_GOLD_TEXT, 4))
	continue_btn.pressed.connect(_on_continue_pressed)
	footer_box.add_child(continue_btn)


func _create_powerup_card(powerup: PowerUpData, cost: int) -> PanelContainer:
	var can_afford := PlayerInventory.gold >= cost
	var already_owned := false
	var rarity_color := _get_rarity_color(powerup.rarity)
	var rarity_name: String = PowerUpData.Rarity.keys()[powerup.rarity]

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 90)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var border_width := 1 if powerup.rarity == PowerUpData.Rarity.COMMON else 2
	card.add_theme_stylebox_override("panel", _make_stylebox(COLOR_BG_CARD, border_width, rarity_color.darkened(0.3), 4))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)

	var name_label := Label.new()
	name_label.text = powerup.display_name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", rarity_color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_label)

	var rarity_label := Label.new()
	rarity_label.text = rarity_name
	rarity_label.add_theme_font_size_override("font_size", 10)
	rarity_label.add_theme_color_override("font_color", rarity_color.darkened(0.2))
	top_row.add_child(rarity_label)

	var desc_label := Label.new()
	desc_label.text = powerup.description if powerup.description else "No description"
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", COLOR_MUTED)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 8)
	vbox.add_child(bottom_row)

	var cost_label := Label.new()
	cost_label.text = "%d" % cost
	cost_label.add_theme_font_size_override("font_size", 13)
	cost_label.add_theme_color_override("font_color", COLOR_GOLD_TEXT if can_afford else COLOR_DISABLED)
	cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(cost_label)

	var buy_btn := Button.new()
	buy_btn.text = "BUY"
	buy_btn.custom_minimum_size = Vector2(70, 28)
	buy_btn.add_theme_font_size_override("font_size", 11)

	if not can_afford:
		buy_btn.disabled = true

	if can_afford and not already_owned:
		buy_btn.add_theme_stylebox_override("normal", _make_stylebox(Color(0.15, 0.2, 0.12), 1, Color(0.3, 0.5, 0.2), 3))
		buy_btn.add_theme_stylebox_override("hover", _make_stylebox(Color(0.2, 0.28, 0.15), 1, Color(0.4, 0.65, 0.25), 3))
		buy_btn.add_theme_color_override("font_color", Color(0.7, 0.9, 0.5))
		buy_btn.pressed.connect(_on_powerup_bought.bind(powerup, cost))
	else:
		buy_btn.add_theme_stylebox_override("normal", _make_stylebox(Color(0.08, 0.08, 0.1), 1, COLOR_DISABLED, 3))
		buy_btn.add_theme_color_override("font_color", COLOR_DISABLED)

	bottom_row.add_child(buy_btn)

	return card


func _create_equip_slot(slot_index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "EquipSlot_%d" % slot_index
	panel.custom_minimum_size = Vector2(0, 52)
	panel.add_theme_stylebox_override("panel", _make_stylebox(COLOR_BG_CARD, 1, COLOR_ACCENT.darkened(0.3), 4))

	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.name = "HBoxContainer"
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	var slot_label := Label.new()
	slot_label.name = "SlotNumber"
	slot_label.text = str(slot_index + 1)
	slot_label.add_theme_font_size_override("font_size", 16)
	slot_label.add_theme_color_override("font_color", COLOR_MUTED)
	slot_label.custom_minimum_size.x = 20
	hbox.add_child(slot_label)

	var name_label := Label.new()
	name_label.name = "SlotName"
	name_label.text = "Empty"
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", COLOR_MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	var equip_btn := Button.new()
	equip_btn.name = "EquipBtn"
	equip_btn.text = "EQUIP"
	equip_btn.custom_minimum_size = Vector2(60, 28)
	equip_btn.add_theme_font_size_override("font_size", 10)
	equip_btn.add_theme_stylebox_override("normal", _make_stylebox(Color(0.12, 0.12, 0.18), 1, COLOR_ACCENT, 3))
	equip_btn.add_theme_stylebox_override("hover", _make_stylebox(Color(0.18, 0.16, 0.28), 1, Color(0.5, 0.45, 0.7), 3))
	equip_btn.add_theme_color_override("font_color", Color(0.7, 0.65, 0.85))
	equip_btn.pressed.connect(_on_equipment_slot_pressed.bind(slot_index))
	hbox.add_child(equip_btn)

	return panel


func open_shop(wave: int, table: PowerUpTable) -> void:
	current_wave = wave
	loot_table = table

	get_tree().paused = true
	visible = true

	available_powerups.clear()

	if loot_table:
		var attempts := 0
		var max_attempts := available_powerups_count * 20

		while available_powerups.size() < available_powerups_count and attempts < max_attempts:
			attempts += 1

			var pu := loot_table.roll_drop()

			if pu == null:
				continue

			if pu in available_powerups:
				continue

			available_powerups.append(pu)

	_update_display()


func _update_display() -> void:
	wave_label.text = "ARMORY — WAVE %d" % current_wave
	_update_gold_display()
	_refresh_powerup_cards()
	_refresh_equipment_display()


func _update_gold_display(_new_gold: int = 0) -> void:
	if gold_label == null:
		return

	gold_label.text = "%d" % PlayerInventory.gold


func _refresh_powerup_cards() -> void:
	for card in card_nodes:
		card.queue_free()

	card_nodes.clear()

	for pu in available_powerups:
		if pu == null:
			continue

		var cost := _get_cost_for_powerup(pu)
		var card := _create_powerup_card(pu, cost)
		powerup_grid.add_child(card)
		card_nodes.append(card)
		
func _slot_has_available_powerups(slot: int) -> bool:
	for pu in PlayerInventory.get_collected_powerups():
		if PlayerInventory.can_equip_powerup(pu, slot):
			return true

	return false

func _refresh_equipment_display() -> void:
	for i in PlayerInventory.EQUIPMENT_SLOTS:
		if i >= equip_slot_nodes.size():
			continue

		var panel: PanelContainer = equip_slot_nodes[i]
		var name_label := panel.get_node_or_null("MarginContainer/HBoxContainer/SlotName") as Label
		var equip_btn := panel.get_node_or_null("MarginContainer/HBoxContainer/EquipBtn") as Button

		if name_label == null or equip_btn == null:
			continue

		var pu: PowerUpData = PlayerInventory.equipped_powerups[i]

		if pu != null:
			var rarity_color := _get_rarity_color(pu.rarity)
			name_label.text = pu.display_name
			name_label.add_theme_color_override("font_color", rarity_color)
			panel.add_theme_stylebox_override("panel", _make_stylebox(COLOR_BG_CARD, 1, rarity_color.darkened(0.3), 4))
		else:
			name_label.text = "Empty"
			name_label.add_theme_color_override("font_color", COLOR_MUTED)
			panel.add_theme_stylebox_override("panel", _make_stylebox(COLOR_BG_CARD, 1, COLOR_ACCENT.darkened(0.3), 4))

		var has_available_powerups := _slot_has_available_powerups(i)

		equip_btn.disabled = not has_available_powerups and pu == null
		equip_btn.text = "CHANGE" if pu != null else "EQUIP"
		_refresh_owned_powerup_list()

func _refresh_owned_powerup_list() -> void:
	if owned_list == null:
		return

	for child in owned_list.get_children():
		child.queue_free()

	var unique_powerups: Array[PowerUpData] = []

	for pu in PlayerInventory.get_collected_powerups():
		if pu != null and pu not in unique_powerups:
			unique_powerups.append(pu)

	if unique_powerups.is_empty():
		var empty_label := Label.new()
		empty_label.text = "None"
		empty_label.add_theme_font_size_override("font_size", 11)
		empty_label.add_theme_color_override("font_color", COLOR_DISABLED)
		owned_list.add_child(empty_label)
		return

	for pu in unique_powerups:
		var owned_count := PlayerInventory.get_powerup_owned_count(pu)
		var equipped_count := PlayerInventory.get_powerup_equipped_count(pu)
		var rarity_color := _get_rarity_color(pu.rarity)

		var label := Label.new()
		label.text = "%s  %d/%d" % [pu.display_name, equipped_count, owned_count]
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", rarity_color)
		owned_list.add_child(label)
		
		
func _on_powerup_bought(powerup: PowerUpData, cost: int) -> void:
	if PlayerInventory.spend_gold(cost):
		PlayerInventory.collect_powerup(powerup)
		_refresh_powerup_cards()
		_update_gold_display()
		_refresh_equipment_display()


func _on_equipment_slot_pressed(slot: int) -> void:
	var available_to_equip: Array[PowerUpData] = []
	var current_powerup: PowerUpData = PlayerInventory.equipped_powerups[slot]

	for pu in PlayerInventory.get_collected_powerups():
		if pu == null:
			continue

		if pu in available_to_equip:
			continue

		var owned_count := PlayerInventory.get_powerup_owned_count(pu)
		var equipped_count := PlayerInventory.get_powerup_equipped_count(pu)

		# If this slot already has this powerup, allow it to show so it can remain selectable.
		if current_powerup == pu:
			available_to_equip.append(pu)
			continue

		# Only show if there is at least one unused copy.
		if equipped_count < owned_count:
			available_to_equip.append(pu)

	if available_to_equip.is_empty() and current_powerup == null:
		return

	var popup := PopupMenu.new()
	popup.add_item("— Empty —", -1)

	for i in available_to_equip.size():
		var pu := available_to_equip[i]
		var owned_count := PlayerInventory.get_powerup_owned_count(pu)
		var equipped_count := PlayerInventory.get_powerup_equipped_count(pu)

		popup.add_item("%s (%d/%d)" % [pu.display_name, equipped_count, owned_count], i)

	popup.index_pressed.connect(func(idx: int):
		if idx == 0:
			PlayerInventory.equip_powerup(null, slot)
		elif idx > 0 and (idx - 1) < available_to_equip.size():
			PlayerInventory.equip_powerup(available_to_equip[idx - 1], slot)

		_refresh_equipment_display()
		popup.queue_free()
	)

	var slot_panel := equip_slot_nodes[slot]
	var popup_pos := slot_panel.get_global_rect().position + Vector2(0, slot_panel.size.y + 4)

	add_child(popup)
	popup.position = Vector2i(int(popup_pos.x), int(popup_pos.y))
	popup.size = Vector2i(220, 0)
	popup.popup()


func _on_continue_pressed() -> void:
	visible = false
	get_tree().paused = false
	shop_closed.emit()


func _make_stylebox(bg_color: Color, border_width: int, border_color: Color, corner_radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(corner_radius)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


func _make_flat_line(color: Color, height: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.content_margin_top = height
	sb.content_margin_bottom = 0
	return sb


func _get_cost_for_powerup(powerup: PowerUpData) -> int:
	match powerup.rarity:
		PowerUpData.Rarity.COMMON:
			return common_cost
		PowerUpData.Rarity.RARE:
			return rare_cost
		PowerUpData.Rarity.EPIC:
			return epic_cost
		PowerUpData.Rarity.LEGENDARY:
			return legendary_cost

	return 0


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
