extends CanvasLayer

## HUD that displays wave information during gameplay.

var wave_label: Label
var gold_label: Label
var build_label: Label
var meter_total_label: Label
var meter_breakdown_panel: PanelContainer
var _meter_hovering: bool = false

## Enemy kill bar — bottom of screen, fills as enemies die
var enemy_bar_fill: ColorRect
var enemy_bar_label: Label
var _bar_full_width: float = 0.0
var _wave_total: int       = 0
var _wave_killed: int      = 0

var wave_manager: WaveManager = null

const COLOR_TITLE := Color(0.85, 0.82, 0.7)
const COLOR_MUTED := Color(0.7, 0.68, 0.65)
const COLOR_GOLD  := Color(1.0, 0.84, 0.0)
const COLOR_BG    := Color(0.1, 0.1, 0.15, 0.8)


func _ready() -> void:
	_build_ui()
	_connect_signals()

# ══════════════════════════════════════════════════════════════════════
# UI CONSTRUCTION
# ══════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	# Top-left info panel — wave, gold
	var info_panel := PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", _make_panel_style())
	info_panel.position = Vector2(20, 20)
	add_child(info_panel)

	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left",   16)
	info_margin.add_theme_constant_override("margin_right",  16)
	info_margin.add_theme_constant_override("margin_top",    12)
	info_margin.add_theme_constant_override("margin_bottom", 12)
	info_panel.add_child(info_margin)

	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 8)
	info_margin.add_child(info_vbox)

	wave_label = Label.new()
	wave_label.text = "SWEEP 1"
	wave_label.add_theme_font_size_override("font_size", 20)
	wave_label.add_theme_color_override("font_color", COLOR_TITLE)
	info_vbox.add_child(wave_label)

	gold_label = Label.new()
	gold_label.text = "Scrap: 0"
	gold_label.add_theme_font_size_override("font_size", 14)
	gold_label.add_theme_color_override("font_color", COLOR_GOLD)
	info_vbox.add_child(gold_label)

	# Top-left build panel
	var build_panel := PanelContainer.new()
	build_panel.add_theme_stylebox_override("panel", _make_panel_style())
	build_panel.position = Vector2(20, 108)
	add_child(build_panel)

	var build_margin := MarginContainer.new()
	build_margin.add_theme_constant_override("margin_left",   16)
	build_margin.add_theme_constant_override("margin_right",  16)
	build_margin.add_theme_constant_override("margin_top",     8)
	build_margin.add_theme_constant_override("margin_bottom",  8)
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

	# Damage meter panel
	_build_damage_meter()

	# Bottom enemy progress bar — built last so viewport size is available
	_build_enemy_bar()


func _build_enemy_bar() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	_bar_full_width = vp_size.x * 0.6

	var bar_h:    float = 8.0
	var bar_x:    float = (vp_size.x - _bar_full_width) / 2.0
	var bar_y:    float = vp_size.y - 36.0

	# Outer container positions everything
	var root := Control.new()
	root.position = Vector2(bar_x, bar_y)
	add_child(root)

	# Dark background with slight padding for a framed look
	var pad:    float = 2.0
	var bar_bg := ColorRect.new()
	bar_bg.color    = Color(0.06, 0.06, 0.1, 0.88)
	bar_bg.position = Vector2(-pad, -pad)
	bar_bg.size     = Vector2(_bar_full_width + pad * 2, bar_h + pad * 2)
	root.add_child(bar_bg)

	# Subtle inner shadow strip (top edge)
	var shadow := ColorRect.new()
	shadow.color    = Color(0.0, 0.0, 0.0, 0.3)
	shadow.position = Vector2(0, 0)
	shadow.size     = Vector2(_bar_full_width, 2)
	root.add_child(shadow)

	# Fill — starts empty, grows right as enemies are killed
	enemy_bar_fill          = ColorRect.new()
	enemy_bar_fill.color    = Color(0.25, 0.65, 1.0)
	enemy_bar_fill.position = Vector2.ZERO
	enemy_bar_fill.size     = Vector2(0.0, bar_h)
	root.add_child(enemy_bar_fill)

	# Kill count label centered above the bar
	enemy_bar_label = Label.new()
	enemy_bar_label.text = ""
	enemy_bar_label.add_theme_font_size_override("font_size", 10)
	enemy_bar_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 0.85))
	enemy_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_bar_label.position             = Vector2(0, -16)
	enemy_bar_label.custom_minimum_size  = Vector2(_bar_full_width, 14)
	root.add_child(enemy_bar_label)


func _build_damage_meter() -> void:
	var meter_panel := PanelContainer.new()
	meter_panel.add_theme_stylebox_override("panel", _make_panel_style())
	meter_panel.position = Vector2(20, 260)
	meter_panel.custom_minimum_size = Vector2(200, 0)
	meter_panel.mouse_entered.connect(_on_meter_hover.bind(true))
	meter_panel.mouse_exited.connect(_on_meter_hover.bind(false))
	add_child(meter_panel)

	var mm := MarginContainer.new()
	mm.add_theme_constant_override("margin_left",   12)
	mm.add_theme_constant_override("margin_right",  12)
	mm.add_theme_constant_override("margin_top",     8)
	mm.add_theme_constant_override("margin_bottom",  8)
	meter_panel.add_child(mm)

	var mvbox := VBoxContainer.new()
	mvbox.add_theme_constant_override("separation", 3)
	mm.add_child(mvbox)

	var meter_title := Label.new()
	meter_title.text = "SWEEP DAMAGE"
	meter_title.add_theme_font_size_override("font_size", 10)
	meter_title.add_theme_color_override("font_color", COLOR_MUTED)
	mvbox.add_child(meter_title)

	meter_total_label = Label.new()
	meter_total_label.text = "0"
	meter_total_label.add_theme_font_size_override("font_size", 16)
	meter_total_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	mvbox.add_child(meter_total_label)

	meter_breakdown_panel = PanelContainer.new()
	meter_breakdown_panel.add_theme_stylebox_override("panel", _make_panel_style())
	meter_breakdown_panel.position = Vector2(20, 320)
	meter_breakdown_panel.custom_minimum_size = Vector2(200, 0)
	meter_breakdown_panel.visible = false
	meter_breakdown_panel.mouse_entered.connect(_on_meter_hover.bind(true))
	meter_breakdown_panel.mouse_exited.connect(_on_meter_hover.bind(false))
	add_child(meter_breakdown_panel)

# ══════════════════════════════════════════════════════════════════════
# SIGNALS
# ══════════════════════════════════════════════════════════════════════

func _connect_signals() -> void:
	await get_tree().process_frame
	wave_manager = get_tree().current_scene.get_node_or_null("WaveManager")

	if wave_manager:
		wave_manager.wave_started.connect(_on_wave_started)
		wave_manager.enemy_count_changed.connect(_on_enemy_count_changed)
		if wave_manager.shop_ui:
			wave_manager.shop_ui.visibility_changed.connect(_on_shop_visibility_changed)
	else:
		push_warning("WaveHUD: Could not find WaveManager")

	if PlayerInventory.gold_changed.is_connected(_on_gold_changed):
		PlayerInventory.gold_changed.disconnect(_on_gold_changed)
	PlayerInventory.gold_changed.connect(_on_gold_changed)

	if PlayerInventory.equipment_changed.is_connected(_on_build_changed):
		PlayerInventory.equipment_changed.disconnect(_on_build_changed)
	PlayerInventory.equipment_changed.connect(_on_build_changed)

	DamageMeter.damage_recorded.connect(_update_damage_meter)

	_on_gold_changed(PlayerInventory.gold)
	_on_build_changed()
	_update_damage_meter()

# ══════════════════════════════════════════════════════════════════════
# CALLBACKS
# ══════════════════════════════════════════════════════════════════════

func _on_wave_started(wave_number: int) -> void:
	wave_label.text = "SWEEP %d" % wave_number
	# Reset bar for new wave
	_wave_total  = 0
	_wave_killed = 0
	if enemy_bar_fill:
		enemy_bar_fill.size.x = 0.0
	if enemy_bar_label:
		enemy_bar_label.text = ""


func _on_enemy_count_changed(alive: int, total: int) -> void:
	if enemy_bar_fill == null or enemy_bar_label == null:
		return

	_wave_total  = total
	_wave_killed = max(0, total - alive)

	var pct: float = float(_wave_killed) / float(max(_wave_total, 1))

	# Smooth width update
	enemy_bar_fill.size.x = _bar_full_width * pct

	# Color sweeps from cool blue → warm gold as the wave clears
	enemy_bar_fill.color = Color(0.25, 0.65, 1.00).lerp(Color(1.00, 0.82, 0.20), pct)

	# Label shows kills / total
	if _wave_total > 0:
		enemy_bar_label.text = "%d / %d" % [_wave_killed, _wave_total]


func _on_gold_changed(new_gold: int) -> void:
	if gold_label:
		gold_label.text = "Scrap: %d" % new_gold


func _on_shop_visibility_changed() -> void:
	if wave_manager and wave_manager.shop_ui:
		visible = not wave_manager.shop_ui.visible


func _on_build_changed() -> void:
	var equipped_entries: Array = PlayerInventory.get_equipped_powerups_with_ranks()

	if equipped_entries.is_empty():
		build_label.text = "Empty"
		return

	var build_parts: Array[String] = []
	for entry in equipped_entries:
		var powerup: PowerUpData = entry.powerup
		var rank: int            = entry.rank
		build_parts.append("%s %d" % [_abbreviate(powerup.display_name), rank])

	build_label.text = "\n".join(build_parts)

	if not PlayerInventory.active_combinations.is_empty():
		var combo_names: Array = PlayerInventory.get_combination_names()
		build_label.text += "\n\n" + "\n".join(combo_names)

# ══════════════════════════════════════════════════════════════════════
# DAMAGE METER
# ══════════════════════════════════════════════════════════════════════

func _on_meter_hover(hovering: bool) -> void:
	_meter_hovering = hovering
	meter_breakdown_panel.visible = hovering
	if hovering:
		_refresh_breakdown_panel()


func _update_damage_meter() -> void:
	if meter_total_label == null:
		return
	meter_total_label.text = DamageMeter.get_total_formatted()
	if _meter_hovering:
		_refresh_breakdown_panel()


func _refresh_breakdown_panel() -> void:
	for child in meter_breakdown_panel.get_children():
		child.queue_free()

	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_left",   12)
	bm.add_theme_constant_override("margin_right",  12)
	bm.add_theme_constant_override("margin_top",     8)
	bm.add_theme_constant_override("margin_bottom",  8)
	meter_breakdown_panel.add_child(bm)

	var bvbox := VBoxContainer.new()
	bvbox.add_theme_constant_override("separation", 4)
	bm.add_child(bvbox)



# ══════════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════════

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
		for word in words:
			if word.length() > 0:
				abbrev += word[0]
		return abbrev.substr(0, 5)


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_color = Color(0.4, 0.35, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left   = 8
	style.content_margin_right  = 8
	style.content_margin_top    = 8
	style.content_margin_bottom = 8
	return style
