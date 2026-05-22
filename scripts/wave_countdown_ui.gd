extends CanvasLayer

## Simple countdown overlay that appears between waves.
## Shows "NEXT WAVE IN 3... 2... 1..." then disappears.

signal countdown_finished

var countdown_label: Label
var background: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func _build_ui() -> void:
	# Semi-transparent dark background
	background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.5)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	
	# Large centered countdown text
	countdown_label = Label.new()
	countdown_label.text = "WAVE COMPLETE"
	countdown_label.add_theme_font_size_override("font_size", 48)
	countdown_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7))
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(countdown_label)


## Start a countdown from the given number of seconds.
## Shows "WAVE COMPLETE" briefly, then counts down.
func start_countdown(seconds: int) -> void:
	visible = true
	countdown_label.text = "WAVE COMPLETE"
	
	# Show "WAVE COMPLETE" for 1.5 seconds
	await get_tree().create_timer(1.5).timeout
	
	# Count down
	for i in range(seconds, 0, -1):
		countdown_label.text = "NEXT WAVE IN %d" % i
		await get_tree().create_timer(1.0).timeout
	
	# Hide and signal completion
	visible = false
	countdown_finished.emit()
