extends CanvasLayer
class_name BossHealthBarUI

## A screen-wide boss health bar anchored to the TOP of the viewport.
## Styled after Diablo/PoE boss bars: dark panel, large bar, boss name.
##
## Usage from any boss script:
##   var bar_ui := BossHealthBarUI.new()
##   bar_ui.setup("The Phantom", health_component)
##   get_tree().current_scene.add_child(bar_ui)

var panel: PanelContainer
var bar: ProgressBar
var name_label: Label
var hp_label: Label
var bar_tween: Tween
var health_comp: Node = null
var target_value: float = 0.0

func setup(boss_name: String, hc: Node) -> void:
	health_comp = hc

	if hc.has_signal("health_changed"):
		hc.health_changed.connect(_on_health_changed)
	if hc.has_signal("died"):
		hc.died.connect(_on_boss_died)

	# ── Root Control: anchored to the TOP of the screen ───────────
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.offset_top = 0.0
	root.offset_bottom = 80.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ── Dark panel backdrop ───────────────────────────────────────
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.05, 0.08, 0.88)
	panel_style.border_color = Color(0.35, 0.25, 0.15, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(4)
	panel_style.content_margin_left = 24.0
	panel_style.content_margin_right = 24.0
	panel_style.content_margin_top = 8.0
	panel_style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(panel)

	# ── Side margins so the bar spans about 70% of viewport ───────
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_right", 120)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	# ── Boss Name ─────────────────────────────────────────────────
	name_label = Label.new()
	name_label.text = boss_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	name_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	# ── Health Bar ────────────────────────────────────────────────
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 18)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.10, 0.08, 1.0)
	bg_style.set_border_width_all(1)
	bg_style.border_color = Color(0.25, 0.2, 0.15, 0.8)
	bg_style.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.15, 0.75, 0.2, 1.0)
	fill_style.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill_style)

	vbox.add_child(bar)

	# ── HP Text ───────────────────────────────────────────────────
	hp_label = Label.new()
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 11)
	hp_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.82, 0.9))
	hp_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	hp_label.add_theme_constant_override("outline_size", 2)
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hp_label)

	# ── Initialize ────────────────────────────────────────────────
	var max_hp: int = hc.max_health if "max_health" in hc else 100
	var cur_hp: int = hc.current_health if "current_health" in hc else max_hp
	bar.max_value = max_hp
	bar.value = cur_hp
	target_value = cur_hp
	_update_labels(cur_hp, max_hp)
	_update_bar_color(float(cur_hp) / float(max_hp) if max_hp > 0 else 1.0)

	# ── Entrance animation: slide down from above ─────────────────
	root.modulate.a = 0.0
	root.offset_top -= 30.0
	root.offset_bottom -= 30.0
	var intro := create_tween()
	intro.set_parallel(true)
	intro.tween_property(root, "modulate:a", 1.0, 0.5)
	intro.tween_property(root, "offset_top", 0.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	intro.tween_property(root, "offset_bottom", 80.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_health_changed(current_hp: int, max_hp: int) -> void:
	bar.max_value = max_hp
	target_value = current_hp
	_update_labels(current_hp, max_hp)

	if bar_tween and bar_tween.is_running():
		bar_tween.kill()
	bar_tween = create_tween()
	bar_tween.tween_property(bar, "value", float(current_hp), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	var ratio: float = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
	_update_bar_color(ratio)

func _on_boss_died() -> void:
	await get_tree().create_timer(0.5).timeout
	queue_free()

func _update_labels(current_hp: int, max_hp: int) -> void:
	hp_label.text = "%d / %d" % [max(current_hp, 0), max_hp]

func _update_bar_color(ratio: float) -> void:
	var fill_style := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style == null:
		return

	var color: Color
	if ratio > 0.5:
		var t := (ratio - 0.5) / 0.5
		color = Color(0.15, 0.75, 0.2).lerp(Color(0.9, 0.8, 0.1), 1.0 - t)
	else:
		var t := ratio / 0.5
		color = Color(0.9, 0.8, 0.1).lerp(Color(0.85, 0.12, 0.08), 1.0 - t)

	fill_style.bg_color = color
