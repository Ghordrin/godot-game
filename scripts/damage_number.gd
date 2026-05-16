extends Node2D
class_name DamageNumber

@onready var label: Label = $Label

var velocity := Vector2(0, -35)
var lifetime := 0.65


func setup(amount: int) -> void:
	label.text = str(amount)


func _process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta

	modulate.a = lifetime / 0.65

	if lifetime <= 0.0:
		queue_free()
