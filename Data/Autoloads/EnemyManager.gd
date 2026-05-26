extends Node

## Phase 2 enemy manager:
## Pools normal scene-based enemies.
##
## Bosses/elites can still be instantiated normally.
## Normal enemies are recycled instead of queue_free().

@export var enable_pooling: bool = true
@export var max_pool_size_per_scene: int = 1500
@export var spatial_grid_cell_size: float = 40.0

var _active_enemies: Array[Node] = []
var _pool_by_scene: Dictionary = {}
var _spatial_grid: Dictionary = {}


func spawn_enemy(
	scene: PackedScene,
	parent: Node,
	global_position: Vector2
) -> Node2D:
	if scene == null:
		return null

	if parent == null:
		return null

	var enemy: Node2D = null

	if enable_pooling:
		enemy = _take_from_pool(scene)

	if enemy == null:
		enemy = scene.instantiate() as Node2D

		if enemy == null:
			push_warning("EnemyManager: enemy scene root is not Node2D.")
			return null

		parent.add_child(enemy)
	else:
		if enemy.get_parent() == null:
			parent.add_child(enemy)

	enemy.global_position = global_position
	enemy.set_meta("pool_scene", scene)

	if enemy.has_method("revive_from_pool"):
		enemy.revive_from_pool(global_position)
	else:
		_default_enable_enemy(enemy)

	register_enemy(enemy)

	return enemy


func recycle_enemy(enemy: Node) -> void:
	if enemy == null:
		return

	if not is_instance_valid(enemy):
		return

	unregister_enemy(enemy)

	if not enable_pooling:
		enemy.queue_free()
		return

	var scene: PackedScene = enemy.get_meta("pool_scene", null)

	if scene == null:
		enemy.queue_free()
		return

	var key: String = _scene_key(scene)

	if not _pool_by_scene.has(key):
		_pool_by_scene[key] = []

	var pool: Array = _pool_by_scene[key]

	if pool.size() >= max_pool_size_per_scene:
		enemy.queue_free()
		return

	if enemy.has_method("prepare_for_pool"):
		enemy.prepare_for_pool()
	else:
		_default_disable_enemy(enemy)

	pool.append(enemy)


func register_enemy(enemy: Node) -> void:
	if enemy == null:
		return

	if not is_instance_valid(enemy):
		return

	if enemy in _active_enemies:
		return

	_active_enemies.append(enemy)


func unregister_enemy(enemy: Node) -> void:
	if enemy == null:
		return

	_active_enemies.erase(enemy)


func get_active_enemy_count() -> int:
	_cleanup_invalid_enemies()
	return _active_enemies.size()


func get_pool_count() -> int:
	var total: int = 0

	for pool in _pool_by_scene.values():
		total += pool.size()

	return total


func get_pending_free_count() -> int:
	## Kept for profiler compatibility.
	return 0


func get_pending_count() -> int:
	## Kept for profiler compatibility.
	return get_pending_free_count()


func clear() -> void:
	_active_enemies.clear()

	for pool in _pool_by_scene.values():
		for enemy in pool:
			if is_instance_valid(enemy):
				enemy.queue_free()

	_pool_by_scene.clear()


func _take_from_pool(scene: PackedScene) -> Node2D:
	var key: String = _scene_key(scene)

	if not _pool_by_scene.has(key):
		return null

	var pool: Array = _pool_by_scene[key]

	while not pool.is_empty():
		var enemy := pool.pop_back() as Node2D

		if is_instance_valid(enemy):
			return enemy

	return null


func _scene_key(scene: PackedScene) -> String:
	if scene == null:
		return ""

	var path: String = scene.resource_path

	if path != "":
		return path

	return str(scene.get_instance_id())


func _cleanup_invalid_enemies() -> void:
	for i in range(_active_enemies.size() - 1, -1, -1):
		if not is_instance_valid(_active_enemies[i]):
			_active_enemies.remove_at(i)


func _default_disable_enemy(enemy: Node) -> void:
	if enemy is CanvasItem:
		(enemy as CanvasItem).hide()

	enemy.set_process(false)
	enemy.set_physics_process(false)

	var collision := enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D

	if collision != null:
		collision.set_deferred("disabled", true)

	var hurtbox := enemy.get_node_or_null("Hurtbox") as Area2D

	if hurtbox != null:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)

	if enemy is Node2D:
		(enemy as Node2D).global_position = Vector2(-100000.0, -100000.0)


func _default_enable_enemy(enemy: Node) -> void:
	if enemy is CanvasItem:
		(enemy as CanvasItem).show()

	enemy.set_process(true)
	enemy.set_physics_process(true)

	var collision := enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D

	if collision != null:
		collision.set_deferred("disabled", false)

	var hurtbox := enemy.get_node_or_null("Hurtbox") as Area2D

	if hurtbox != null:
		hurtbox.set_deferred("monitoring", true)
		hurtbox.set_deferred("monitorable", true)


func _physics_process(_delta: float) -> void:
	_rebuild_spatial_grid()


func _rebuild_spatial_grid() -> void:
	_spatial_grid.clear()
	for enemy in _active_enemies:
		if not is_instance_valid(enemy):
			continue
		if not (enemy as Node).is_in_group("enemies"):
			continue
		var cell := _get_grid_cell((enemy as Node2D).global_position)
		if not _spatial_grid.has(cell):
			_spatial_grid[cell] = []
		_spatial_grid[cell].append(enemy)


func get_nearby_enemies(pos: Vector2, radius: float) -> Array:
	var result: Array = []
	var cell_radius := ceili(radius / spatial_grid_cell_size)
	var center := _get_grid_cell(pos)
	for dx in range(-cell_radius, cell_radius + 1):
		for dy in range(-cell_radius, cell_radius + 1):
			var cell := Vector2i(center.x + dx, center.y + dy)
			if _spatial_grid.has(cell):
				result.append_array(_spatial_grid[cell])
	return result


func _get_grid_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.x / spatial_grid_cell_size), int(pos.y / spatial_grid_cell_size))
