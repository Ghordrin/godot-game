extends CanvasLayer

@export var player_path: NodePath

@onready var panel: Panel = $Panel
@onready var stats_label: Label = $Panel/StatsLabel

var player: Node
var stats: Node


func _ready() -> void:
	visible = false

	if player_path != NodePath(""):
		player = get_node(player_path)
	else:
		player = get_tree().get_first_node_in_group("player")

	if player != null and player.has_node("StatsComponent"):
		stats = player.get_node("StatsComponent")


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_debug_stats"):
		visible = not visible

	if not visible:
		return

	if stats == null:
		stats_label.text = "No StatsComponent found."
		return

	stats_label.text = _build_stats_text()


func _build_stats_text() -> String:
	return """DEBUG STATS

Gold: %s
Damage: %s
Move Speed: %s
Attack Speed: %s
Projectile Speed: %s

Pickup Range: %s
Gold Multiplier: %s
Luck: %s

Crit Chance: %s%%
Crit Multiplier: %sx

Powerup Stacks:
%s
""" % [
		stats.gold,
		stats.damage,
		stats.move_speed,
		stats.attack_speed,
		stats.projectile_speed,
		stats.pickup_range,
		stats.gold_multiplier,
		stats.luck,
		round(stats.crit_chance * 100.0),
		stats.crit_multiplier,
		_format_powerup_stacks()
	]


func _format_powerup_stacks() -> String:
	if stats.powerup_stacks.is_empty():
		return "None"

	var text := ""

	for powerup_id in stats.powerup_stacks.keys():
		text += "- %s: %s\n" % [powerup_id, stats.powerup_stacks[powerup_id]]

	return text
