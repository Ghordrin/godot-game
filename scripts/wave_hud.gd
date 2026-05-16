extends CanvasLayer
class_name WaveHUD

# ── Node Refs ─────────────────────────────────────────────────────────
@onready var wave_label: Label   = $MarginContainer/VBoxContainer/WaveLabel
@onready var enemy_label: Label  = $MarginContainer/VBoxContainer/EnemyLabel
@onready var boss_warning: Label = $MarginContainer/VBoxContainer/BossWarning
@onready var wave_message: Label = $MarginContainer/VBoxContainer/WaveMessage
@onready var start_button: Button = $MarginContainer/VBoxContainer/StartButton

# ── WaveManager reference ─────────────────────────────────────────────
# Assigned automatically in _ready() by searching the scene tree.
var wave_manager: WaveManager

func _ready() -> void:
	wave_manager = _find_wave_manager()
	print("WaveHUD _ready ran")
	print("WaveHUD found manager: ", wave_manager)
	if wave_manager == null:
		push_warning("WaveHUD: No WaveManager found in scene tree.")
		return
	print("WaveHUD connecting signals...")
	
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_completed.connect(_on_wave_completed)
	wave_manager.boss_wave_started.connect(_on_boss_wave_started)
	wave_manager.enemy_count_changed.connect(_on_enemy_count_changed)
	wave_manager.between_waves_started.connect(_on_between_waves)

	start_button.pressed.connect(_on_start_pressed)
	print("WaveHUD button connected: ", start_button)

	_show_waiting_state()
	print("WaveHUD setup complete")

# ── Signal Handlers ───────────────────────────────────────────────────

func _on_wave_started(wave_number: int) -> void:
	wave_label.text = "Wave " + str(wave_number)
	enemy_label.visible = true
	start_button.visible = false
	wave_message.visible = false

	# Boss warning fades after a couple of seconds if it's showing.
	if boss_warning.visible:
		await get_tree().create_timer(2.5).timeout
		boss_warning.visible = false

func _on_wave_completed(wave_number: int) -> void:
	wave_message.text = "Wave " + str(wave_number) + " Complete!"
	wave_message.visible = true
	enemy_label.visible = false

func _on_boss_wave_started(wave_number: int) -> void:
	boss_warning.visible = true

func _on_enemy_count_changed(alive: int, total: int) -> void:
	enemy_label.text = "Enemies: " + str(alive) + " / " + str(total)

func _on_between_waves(wave_number: int) -> void:
	# This fires after the brief celebration pause in WaveManager.
	# Show the button so the player can start when they're ready.
	start_button.visible = true
	start_button.text = "Start Wave " + str(wave_number + 1)

func _on_start_pressed() -> void:
	start_button.visible = false
	wave_message.visible = false
	boss_warning.visible = false
	wave_manager.start_next_wave()

# ── Helpers ───────────────────────────────────────────────────────────

func _show_waiting_state() -> void:
	wave_label.text = "Wave 1"
	enemy_label.text = ""
	enemy_label.visible = false
	boss_warning.visible = false
	wave_message.visible = false
	start_button.visible = true
	start_button.text = "Start Wave 1"

func _find_wave_manager() -> WaveManager:
	# Try the direct path first since we know the scene structure.
	var root := get_tree().current_scene
	var wm := root.get_node_or_null("WaveManager")
	if wm is WaveManager:
		return wm

	# Fallback: search by group in case the tree structure changes.
	var nodes := get_tree().get_nodes_in_group("wave_manager")
	if not nodes.is_empty():
		return nodes[0] as WaveManager

	# Last resort: check all children of the root scene.
	for child in root.get_children():
		if child is WaveManager:
			return child

	return null
