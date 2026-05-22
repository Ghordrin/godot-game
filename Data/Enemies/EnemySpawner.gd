extends Marker2D
class_name EnemySpawner

@export var spawn_scenes: Array[PackedScene] = []
@export var spawn_interval: float = 3.0
@export var max_alive: int = 15
@export var spawn_radius: float = 32.0
@export var spawn_on_start: bool = true

var alive_spawns: Array[Node2D] = []

func _ready() -> void:
	if spawn_on_start:
		spawn_one()
	spawn_loop()

func spawn_loop() -> void:
	while true:
		await get_tree().create_timer(spawn_interval).timeout
		spawn_one()

func spawn_one() -> void:
	cleanup_invalid_spawns()

	if spawn_scenes.is_empty():
		push_warning("EnemySpawner has no spawn scenes assigned.")
		return

	if alive_spawns.size() >= max_alive:
		return

	var scene: PackedScene = spawn_scenes.pick_random() as PackedScene
	var spawned_node := scene.instantiate() as Node2D

	if spawned_node == null:
		push_warning("Spawned scene root must be Node2D or inherit from Node2D.")
		return

	get_tree().current_scene.add_child.call_deferred(spawned_node)
	spawned_node.global_position = get_random_spawn_position()
	alive_spawns.append(spawned_node)

func get_random_spawn_position() -> Vector2:
	var random_offset := Vector2(
		randf_range(-spawn_radius, spawn_radius),
		randf_range(-spawn_radius, spawn_radius)
	)
	return global_position + random_offset

func cleanup_invalid_spawns() -> void:
	# Walk backwards through the array removing dead entries in place.
	# This avoids .filter() which returns an untyped Array that Godot
	# refuses to assign back into a typed Array[Node2D].
	var i := alive_spawns.size() - 1
	while i >= 0:
		if not is_instance_valid(alive_spawns[i]):
			alive_spawns.remove_at(i)
		i -= 1
