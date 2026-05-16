extends Area2D
class_name GoldPickup

@export var gold_amount := 1

@onready var label: Label = $Label

func _ready() -> void:
	label.text = str(gold_amount) + " gold"

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	# Add gold to the central PlayerInventory so the shop can see it.
	PlayerInventory.add_gold(gold_amount)

	queue_free()
