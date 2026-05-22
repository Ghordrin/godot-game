extends Node

const DAMAGE_NUMBER_SCENE := preload("res://Data/UI/DamageNumber.tscn")


func spawn(
	world_pos: Vector2,
	amount: float,
	damage_type: String,
	color: Color,
	index: int = 0,
	is_dot: bool = false
) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return

	var dn := DAMAGE_NUMBER_SCENE.instantiate() as DamageNumber
	scene_root.add_child(dn)

	dn.global_position = world_pos + Vector2(0.0, -28.0 - float(index) * 34.0)
	dn.setup(
		amount,
		damage_type,
		color,
		is_dot
	)
