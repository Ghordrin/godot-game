extends Control
class_name MainMenu

## Main menu with New Game, Settings (Audio / Video / Controls).
## Controls are fully rebindable and all settings persist via ConfigFile.
##
## SETUP:
## 1. Create a new scene with a Control root node
## 2. Attach this script to the root
## 3. Set GAME_SCENE to your actual game scene path
## 4. Add this scene as your project's main scene (Project Settings → Run → Main Scene)

const GAME_SCENE    := "res://scenes/world.tscn"   # ← change to your game scene
const SETTINGS_PATH := "user://settings.cfg"

## Actions displayed in Controls settings. Key = action name, Value = display label.
const REBINDABLE_ACTIONS := {
	"move_up":         "Move Up",
	"move_down":       "Move Down",
	"move_left":       "Move Left",
	"move_right":      "Move Right",
	"cast_projectile": "Attack",
	"dash":            "Dash",
}

# ── Colors ────────────────────────────────────────────────────────────
const C_BG     := Color(0.04, 0.04, 0.07, 1.0)
const C_PANEL  := Color(0.08, 0.08, 0.13, 0.97)
const C_ACCENT := Color(0.40, 0.35, 0.55)
const C_GOLD   := Color(1.00, 0.84, 0.00)
const C_TITLE  := Color(0.90, 0.87, 0.75)
const C_MUTED  := Color(0.55, 0.53, 0.50)
const C_BTN    := Color(0.12, 0.10, 0.18)
const C_BTN_H  := Color(0.22, 0.18, 0.32)

# ── State ─────────────────────────────────────────────────────────────
var _settings_root: Control     = null
var _tab_content: Control       = null
var _active_tab: String         = "audio"
var _rebinding: bool            = false
var _rebind_action: String      = ""
var _rebind_btn: Button         = null

# ══════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_load_settings()
	_build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if not _rebinding:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_cancel_rebind()
		else:
			_apply_rebind(event as InputEventKey)
		get_viewport().set_input_as_handled()

# ══════════════════════════════════════════════════════════════════════
# UI CONSTRUCTION
# ══════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	# Full-screen background
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Subtle vignette overlay
	var vignette := ColorRect.new()
	vignette.color = Color(0.0, 0.0, 0.0, 0.35)
	vignette.set_anchors_preset(PRESET_FULL_RECT)
	add_child(vignette)

	# Centre column
	var centre := VBoxContainer.new()
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_theme_constant_override("separation", 32)
	centre.set_anchors_preset(PRESET_CENTER)
	centre.grow_horizontal = GROW_DIRECTION_BOTH
	centre.grow_vertical   = GROW_DIRECTION_BOTH
	centre.offset_left   = -200
	centre.offset_right  =  200
	centre.offset_top    = -200
	centre.offset_bottom =  200
	add_child(centre)

	_build_title(centre)
	_build_main_buttons(centre)

	# Settings overlay (hidden until Settings is clicked)
	_settings_root = _make_settings_root()
	add_child(_settings_root)
	_settings_root.visible = false


func _build_title(parent: Control) -> void:
	var title := Label.new()
	title.text = "UNNAMED GAME"     # ← replace with your game title
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", C_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(title)

	var sub := Label.new()
	sub.text = "A wave survival roguelike"
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", C_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(sub)


func _build_main_buttons(parent: Control) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(vbox)

	var new_game := _make_btn("NEW GAME", C_GOLD)
	new_game.pressed.connect(_on_new_game)
	vbox.add_child(new_game)

	var settings := _make_btn("SETTINGS", C_TITLE)
	settings.pressed.connect(_on_open_settings)
	vbox.add_child(settings)

	var quit := _make_btn("QUIT", C_MUTED)
	quit.pressed.connect(func(): get_tree().quit())
	vbox.add_child(quit)


func _make_settings_root() -> Control:
	# Dark overlay behind the panel
	var root := Control.new()
	root.set_anchors_preset(PRESET_FULL_RECT)
	root.mouse_filter = MOUSE_FILTER_STOP  # Block clicks behind

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.65)
	overlay.set_anchors_preset(PRESET_FULL_RECT)
	root.add_child(overlay)

	# Settings panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(PRESET_CENTER)
	panel.offset_left   = -360
	panel.offset_right  =  360
	panel.offset_top    = -260
	panel.offset_bottom =  260
	panel.add_theme_stylebox_override("panel", _make_sb(C_PANEL, 2, C_ACCENT, 8))
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)

	# Header
	var header := _make_settings_header()
	vbox.add_child(header)

	# Tab bar
	var tab_bar := _make_tab_bar()
	vbox.add_child(tab_bar)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", _make_flat_line(C_ACCENT))
	vbox.add_child(sep)

	# Content area
	_tab_content = MarginContainer.new()
	_tab_content.add_theme_constant_override("margin_left",   24)
	_tab_content.add_theme_constant_override("margin_right",  24)
	_tab_content.add_theme_constant_override("margin_top",    20)
	_tab_content.add_theme_constant_override("margin_bottom", 20)
	_tab_content.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(_tab_content)

	# Footer
	var footer_m := MarginContainer.new()
	footer_m.add_theme_constant_override("margin_left",  24)
	footer_m.add_theme_constant_override("margin_right", 24)
	footer_m.add_theme_constant_override("margin_bottom", 16)
	vbox.add_child(footer_m)

	var back := _make_btn("← BACK", C_MUTED)
	back.custom_minimum_size = Vector2(120, 40)
	back.add_theme_font_size_override("font_size", 13)
	back.pressed.connect(_on_close_settings)
	footer_m.add_child(back)

	_switch_tab("audio")
	return root


func _make_settings_header() -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left",  24)
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_top",   18)
	m.add_theme_constant_override("margin_bottom", 8)

	var lbl := Label.new()
	lbl.text = "SETTINGS"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", C_TITLE)
	m.add_child(lbl)
	return m


func _make_tab_bar() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)

	for tab_id in ["audio", "video", "controls"]:
		var btn := Button.new()
		btn.text = tab_id.to_upper()
		btn.custom_minimum_size = Vector2(120, 36)
		btn.add_theme_font_size_override("font_size", 13)
		btn.flat = true
		btn.add_theme_color_override("font_color", C_MUTED)
		btn.add_theme_color_override("font_hover_color", C_TITLE)
		btn.pressed.connect(_switch_tab.bind(tab_id))
		btn.name = "Tab_" + tab_id
		hbox.add_child(btn)

	return hbox


func _switch_tab(tab_id: String) -> void:
	_active_tab = tab_id

	# Clear content
	for child in _tab_content.get_children():
		child.queue_free()

	# Build selected tab
	var content: Control
	match tab_id:
		"audio":    content = _build_audio_tab()
		"video":    content = _build_video_tab()
		"controls": content = _build_controls_tab()
		_:          content = Control.new()

	_tab_content.add_child(content)


# ══════════════════════════════════════════════════════════════════════
# TAB: AUDIO
# ══════════════════════════════════════════════════════════════════════

func _build_audio_tab() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)

	_add_volume_row(vbox, "Master Volume", "Master")
	_add_volume_row(vbox, "Music Volume",  "Music")
	_add_volume_row(vbox, "SFX Volume",    "SFX")

	return vbox


func _add_volume_row(parent: Control, label: String, bus_name: String) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", C_TITLE)
	lbl.custom_minimum_size = Vector2(180, 0)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step      = 0.01
	slider.size_flags_horizontal = SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 24)

	if bus_idx >= 0:
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
	else:
		slider.value = 1.0
		slider.editable = false

	slider.value_changed.connect(func(v: float):
		if bus_idx >= 0:
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(v))
			_save_settings()
	)
	row.add_child(slider)

	var pct := Label.new()
	pct.add_theme_font_size_override("font_size", 13)
	pct.add_theme_color_override("font_color", C_MUTED)
	pct.custom_minimum_size = Vector2(40, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.text = "%d%%" % int(slider.value * 100)
	slider.value_changed.connect(func(v: float): pct.text = "%d%%" % int(v * 100))
	row.add_child(pct)

# ══════════════════════════════════════════════════════════════════════
# TAB: VIDEO
# ══════════════════════════════════════════════════════════════════════

func _build_video_tab() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)

	# Fullscreen
	_add_toggle_row(vbox, "Fullscreen",
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,
		func(on: bool):
			if on:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			_save_settings()
	)

	# VSync
	_add_toggle_row(vbox, "VSync",
		DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED,
		func(on: bool):
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED
			)
			_save_settings()
	)

	return vbox


func _add_toggle_row(parent: Control, label: String, current: bool, callback: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", C_TITLE)
	lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(lbl)

	var chk := CheckButton.new()
	chk.button_pressed = current
	chk.toggled.connect(callback)
	row.add_child(chk)

# ══════════════════════════════════════════════════════════════════════
# TAB: CONTROLS
# ══════════════════════════════════════════════════════════════════════

func _build_controls_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 180)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	for action in REBINDABLE_ACTIONS:
		_add_control_row(vbox, action, REBINDABLE_ACTIONS[action])

	return scroll


func _add_control_row(parent: Control, action: String, label: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", C_TITLE)
	lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(lbl)

	var btn := Button.new()
	btn.text = _get_action_key_label(action)
	btn.custom_minimum_size = Vector2(120, 34)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_stylebox_override("normal", _make_sb(C_BTN, 2, C_ACCENT, 4))
	btn.add_theme_stylebox_override("hover",  _make_sb(C_BTN_H, 2, C_GOLD, 4))
	btn.add_theme_color_override("font_color", C_TITLE)
	btn.pressed.connect(_start_rebind.bind(action, btn))
	row.add_child(btn)


func _get_action_key_label(action: String) -> String:
	if not InputMap.has_action(action):
		return "UNBOUND"
	var events := InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey:
			return OS.get_keycode_string((event as InputEventKey).keycode)
	return "UNBOUND"

# ══════════════════════════════════════════════════════════════════════
# KEY REBINDING
# ══════════════════════════════════════════════════════════════════════

func _start_rebind(action: String, btn: Button) -> void:
	if _rebinding:
		return
	_rebinding     = true
	_rebind_action = action
	_rebind_btn    = btn
	btn.text = "PRESS A KEY..."
	btn.add_theme_color_override("font_color", C_GOLD)


func _apply_rebind(event: InputEventKey) -> void:
	InputMap.action_erase_events(_rebind_action)
	InputMap.action_add_event(_rebind_action, event)
	_rebind_btn.text = OS.get_keycode_string(event.keycode)
	_rebind_btn.add_theme_color_override("font_color", C_TITLE)
	_rebinding  = false
	_rebind_btn = null
	_save_settings()


func _cancel_rebind() -> void:
	if _rebind_btn:
		_rebind_btn.text = _get_action_key_label(_rebind_action)
		_rebind_btn.add_theme_color_override("font_color", C_TITLE)
	_rebinding  = false
	_rebind_btn = null

# ══════════════════════════════════════════════════════════════════════
# SETTINGS PERSISTENCE
# ══════════════════════════════════════════════════════════════════════

func _save_settings() -> void:
	var cfg := ConfigFile.new()

	# Audio — save linear volume per bus
	for bus_name in ["Master", "Music", "SFX"]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			cfg.set_value("audio", bus_name.to_lower() + "_volume",
				db_to_linear(AudioServer.get_bus_volume_db(idx)))

	# Video
	cfg.set_value("video", "fullscreen",
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	cfg.set_value("video", "vsync",
		DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED)

	# Controls — save keycode per action
	for action in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				cfg.set_value("controls", action, (event as InputEventKey).keycode)
				break

	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return  # No saved settings yet — use defaults

	# Audio
	for bus_name in ["Master", "Music", "SFX"]:
		var key: String = bus_name.to_lower() + "_volume"
		if cfg.has_section_key("audio", key):
			var idx := AudioServer.get_bus_index(bus_name)
			if idx >= 0:
				AudioServer.set_bus_volume_db(idx, linear_to_db(cfg.get_value("audio", key, 1.0)))

	# Video
	if cfg.has_section_key("video", "fullscreen") and cfg.get_value("video", "fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	if cfg.has_section("video") and not cfg.get_value("video", "vsync", true):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	# Controls — only apply if we have a valid non-zero keycode
	if cfg.has_section("controls"):
		for action in REBINDABLE_ACTIONS:
			if not cfg.has_section_key("controls", action):
				continue
			var keycode: int = cfg.get_value("controls", action, 0)
			if keycode <= 0:
				continue  # Skip invalid — keep the project default binding
			var event: InputEventKey = InputEventKey.new()
			event.keycode = keycode
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, event)

# ══════════════════════════════════════════════════════════════════════
# BUTTON CALLBACKS
# ══════════════════════════════════════════════════════════════════════

func _on_new_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_open_settings() -> void:
	_settings_root.visible = true
	_switch_tab("audio")


func _on_close_settings() -> void:
	if _rebinding:
		_cancel_rebind()
	_settings_root.visible = false

# ══════════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════════

func _make_btn(label: String, text_color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(260, 52)
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color",       text_color)
	btn.add_theme_color_override("font_hover_color", C_GOLD)
	btn.add_theme_stylebox_override("normal", _make_sb(C_BTN,   2, C_ACCENT, 6))
	btn.add_theme_stylebox_override("hover",  _make_sb(C_BTN_H, 2, C_GOLD,   6))
	btn.add_theme_stylebox_override("pressed",_make_sb(C_BTN,   2, C_GOLD,   6))
	return btn


func _make_sb(bg: Color, border: int, border_col: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color     = bg
	sb.border_color = border_col
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left   = 8
	sb.content_margin_right  = 8
	sb.content_margin_top    = 8
	sb.content_margin_bottom = 8
	return sb


func _make_flat_line(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color        = color
	sb.content_margin_top    = 1
	sb.content_margin_bottom = 0
	return sb
