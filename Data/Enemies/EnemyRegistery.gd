extends Node

## Spatial hash registry for enemy lookup.
## Goal: avoid get_tree().get_nodes_in_group("enemies") during combat logic.
##
## Instead of scanning every enemy, systems can ask:
## EnemyRegistry.get_enemies_in_radius(position, radius)

@export var cell_size: float = 192.0
@export var update_interval: float = 0.15

var _enemies: Array[Node2D] = []
var _enemy_cells: Dictionary = {}
var _grid: Dictionary = {}

var _update_timer: float = 0.0


func _process(delta: float) -> void:
	_update_timer -= delta

	if _update_timer > 0.0:
		return

	_update_timer = update_interval
	_rebuild_grid()


func register_enemy(enemy: Node2D) -> void:
	if enemy == null:
		return

	if enemy in _enemies:
		return

	_enemies.append(enemy)


func unregister_enemy(enemy: Node2D) -> void:
	if enemy == null:
		return

	_enemies.erase(enemy)

	var old_cell: Vector2i = _enemy_cells.get(enemy, Vector2i(999999, 999999))

	if _grid.has(old_cell):
		_grid[old_cell].erase(enemy)

		if _grid[old_cell].is_empty():
			_grid.erase(old_cell)

	_enemy_cells.erase(enemy)


func get_all_enemies() -> Array[Node2D]:
	return _enemies


func get_enemy_count() -> int:
	return _enemies.size()


func get_enemies_in_radius(origin: Vector2, radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []

	if radius <= 0.0:
		return result

	var radius_sq: float = radius * radius
	var min_cell: Vector2i = _world_to_cell(origin - Vector2(radius, radius))
	var max_cell: Vector2i = _world_to_cell(origin + Vector2(radius, radius))

	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			var cell := Vector2i(x, y)

			if not _grid.has(cell):
				continue

			for enemy: Node2D in _grid[cell]:
				if not is_instance_valid(enemy):
					continue

				if origin.distance_squared_to(enemy.global_position) > radius_sq:
					continue

				result.append(enemy)

	return result


func get_nearest_enemy(origin: Vector2, radius: float) -> Node2D:
	var nearby: Array[Node2D] = get_enemies_in_radius(origin, radius)
	var nearest: Node2D = null
	var nearest_dist_sq: float = radius * radius

	for enemy: Node2D in nearby:
		var dist_sq: float = origin.distance_squared_to(enemy.global_position)

		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = enemy

	return nearest


func _rebuild_grid() -> void:
	_grid.clear()
	_enemy_cells.clear()

	for i in range(_enemies.size() - 1, -1, -1):
		var enemy: Node2D = _enemies[i]

		if not is_instance_valid(enemy):
			_enemies.remove_at(i)
			continue

		var cell: Vector2i = _world_to_cell(enemy.global_position)

		if not _grid.has(cell):
			_grid[cell] = []

		_grid[cell].append(enemy)
		_enemy_cells[enemy] = cell


func _world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_position.x / cell_size),
		floori(world_position.y / cell_size)
	)
