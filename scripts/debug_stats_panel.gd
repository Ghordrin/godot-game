extends CanvasLayer

## HUD that displays wave information during gameplay.
## Shows wave number, enemy count, gold, and current build.
## No manual wave start button - waves auto-start now.

var wave_label: Label
var enemy_count_label: Label
var gold_label: Label
var build_label: Label

var wave_manager: WaveManager = null

const COLOR_TITLE := Color(0.85, 0.82, 0.7)
const COLOR_MUTED := Color(0.7, 0.68, 0.65)
const COLOR_GOLD := Color(1.0, 0.84, 0.0)
const COLOR_BG := Color(0.1, 0.1, 0.15, 0.8)


func _ready() -> void:
	_build_ui()
	_connect_signals()


func _build_ui() -> void:
	# Top-left panel with wave info
	var info_panel := PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", _make_panel_style())
	info_panel.position = Vector2(20, 20)
	add_child(info_panel)
	
	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 16)
	info_margin.add_theme_constant_override("margin_right", 16)
	info_margin.add_theme_constant_override("margin_top", 12)
	info_margin.add_theme_constant_override("margin_bottom", 12)
	info_panel.add_child(info_margin)
	
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 8)
	info_margin.add_child(info_vbox)
	
	# Wave number
	wave_label = Label.new()
	wave_label.text = "WAVE 1"
	wave_label.add_theme_font_size_override("font_size", 20)
	wave_label.add_theme_color_override("font_color", COLOR_TITLE)
	info_vbox.add_child(wave_label)
	
	# Enemy count
	enemy_count_label = Label.new()
	enemy_count_label.text = "Enemies: 0 / 0"
	enemy_count_label.add_theme_font_size_override("font_size", 14)
	enemy_count_label.add_theme_color_override("font_color", COLOR_MUTED)
	info_vbox.add_child(enemy_count_label)
	
	# Gold
	gold_label = Label.new()
	gold_label.text = "Gold: 0"
	gold_label.add_theme_font_size_override("font_size", 14)
	gold_label.add_theme_color_override("font_color", COLOR_GOLD)
	info_vbox.add_child(gold_label)
	
	# Current build display (compact, shows during gameplay)
	var build_panel := PanelContainer.new()
	build_panel.add_theme_stylebox_override("panel", _make_panel_style())
	build_panel.position = Vector2(20, 140)
	add_child(build_panel)
	
	var build_margin := MarginContainer.new()
	build_margin.add_theme_constant_override("margin_left", 16)
	build_margin.add_theme_constant_override("margin_right", 16)
	build_margin.add_theme_constant_override("margin_top", 8)
	build_margin.add_theme_constant_override("margin_bottom", 8)
	build_panel.add_child(build_margin)
	
	var build_vbox := VBoxContainer.new()
	build_vbox.add_theme_constant_override("separation", 4)
	build_margin.add_child(build_vbox)
	
	var build_title := Label.new()
	build_title.text = "BUILD"
	build_title.add_theme_font_size_override("font_size", 11)
	build_title.add_theme_color_override("font_color", COLOR_MUTED)
	build_vbox.add_child(build_title)
	
	build_label = Label.new()
	build_label.text = "Empty"
	build_label.add_theme_font_size_override("font_size", 12)
	build_label.add_theme_color_override("font_color", COLOR_TITLE)
	build_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	build_label.custom_minimum_size.x = 200
	build_vbox.add_child(build_label)


func _connect_signals() -> void:
	# Find WaveManager
	await get_tree().process_frame  # Wait for scene to be ready
	wave_manager = get_tree().current_scene.get_node_or_null("WaveManager")
	
	if wave_manager:
		wave_manager.wave_started.connect(_on_wave_started)
		wave_manager.enemy_count_changed.connect(_on_enemy_count_changed)
		
		# Find the shop UI and connect to its visibility changes
		if wave_manager.shop_ui:
			wave_manager.shop_ui.visibility_changed.connect(_on_shop_visibility_changed)
	else:
		push_warning("WaveHUD: Could not find WaveManager")
	
	# Connect to inventory signals
	if PlayerInventory.gold_changed.is_connected(_on_gold_changed):
		PlayerInventory.gold_changed.disconnect(_on_gold_changed)
	PlayerInventory.gold_changed.connect(_on_gold_changed)
	
	if PlayerInventory.equipment_changed.is_connected(_on_build_changed):
		PlayerInventory.equipment_changed.disconnect(_on_build_changed)
	PlayerInventory.equipment_changed.connect(_on_build_changed)
	
	# Initial updates
	_on_gold_changed(PlayerInventory.gold)
	_on_build_changed()


func _on_wave_started(wave_number: int) -> void:
	wave_label.text = "WAVE %d" % wave_number


func _on_enemy_count_changed(alive: int, total: int) -> void:
	enemy_count_label.text = "Enemies: %d / %d" % [alive, total]


func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = "Gold: %d" % new_gold


func _on_shop_visibility_changed() -> void:
	# Hide HUD when shop is visible, show HUD when shop is hidden
	if wave_manager and wave_manager.shop_ui:
		visible = not wave_manager.shop_ui.visible


func _on_build_changed() -> void:
	var equipped_entries := PlayerInventory.get_equipped_powerups_with_ranks()
	
	if equipped_entries.is_empty():
		build_label.text = "Empty"
		return
	
	var build_parts: Array[String] = []
	for entry in equipped_entries:
		var powerup: PowerUpData = entry.powerup
		var rank: int = entry.rank
		
		# Abbreviate name
		var abbrev := _abbreviate_powerup_name(powerup.display_name)
		build_parts.append("%s %d" % [abbrev, rank])
	
	build_label.text = "\n".join(build_parts)  # Stack vertically for HUD

	# Show all active combinations
	if not PlayerInventory.active_combinations.is_empty():
		var combo_names := PlayerInventory.get_combination_names()
		build_label.text += "\n\n" + "\n".join(combo_names)


func _abbreviate_powerup_name(full_name: String) -> String:
	var cleaned := full_name.to_upper()
	cleaned = cleaned.replace(" UP", "").replace(" DOWN", "")
	cleaned = cleaned.replace(" THE", "").replace(" OF", "")
	
	var words := cleaned.split(" ")
	
	if words.size() == 1:
		return words[0].substr(0, min(4, words[0].length()))
	elif words.size() == 2:
		var first := words[0].substr(0, min(3, words[0].length()))
		var second := words[1].substr(0, min(2, words[1].length()))
		return first + second.substr(0, 1)
	else:
		var abbrev := ""
		for word in words:
			if word.length() > 0:
				abbrev += word[0]
		return abbrev.substr(0, min(5, abbrev.length()))


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_color = Color(0.4, 0.35, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
