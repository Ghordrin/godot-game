extends Node

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://Data/UI/DamageNumber.tscn")


func get_anchor_position(target: Node) -> Vector2:
	if target == null:
		return Vector2.ZERO

	var anchor := target.get_node_or_null("DamageNumberAnchor") as Node2D
	if anchor != null:
		return anchor.global_position

	if target is Node2D:
		return (target as Node2D).global_position

	return Vector2.ZERO

func spawn(
	world_pos: Vector2,
	amount: float,
	damage_type: String,
	color: Color,
	index: int = 0,
	is_dot: bool = false
) -> void:
	if amount <= 0.0:
		return

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	var damage_number := DAMAGE_NUMBER_SCENE.instantiate() as DamageNumber
	if damage_number == null:
		return

	scene_root.add_child(damage_number)

	damage_number.global_position = world_pos + Vector2(0.0, -36.0 - float(index) * 28.0)

	damage_number.setup(
		amount,
		damage_type,
		color,
		is_dot
	)
