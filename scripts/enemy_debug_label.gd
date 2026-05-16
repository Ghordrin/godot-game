extends Label

## Attach this to a Label node inside the enemy scene.
## It reads the enemy's stats every frame and displays them overhead.
## Toggle visibility with the debug panel or just delete the node for release.

@onready var enemy: CharacterBody2D = get_parent()
@onready var health_comp: Node = enemy.get_node_or_null("HealthComponent")

func _ready() -> void:
	# Position it above the enemy's head.
	position = Vector2(-40, -55)
	size = Vector2(80, 40)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 8)
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 2)

func _process(_delta: float) -> void:
	if health_comp == null:
		return

	var hp: int = health_comp.health if "health" in health_comp else 0
	var max_hp: int = health_comp.max_health if "max_health" in health_comp else 0
	var spd: float = enemy.move_speed if "move_speed" in enemy else 0.0

	text = "HP: %d/%d\nSPD: %.0f" % [hp, max_hp, spd]
