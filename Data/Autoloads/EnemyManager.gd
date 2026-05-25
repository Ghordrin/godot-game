extends Node

## Phase 1 enemy manager:
## Tracks scene-based enemies and staggers enemy freeing.
##
## This is intentionally conservative:
## - existing enemy scenes still work
## - no pooling yet
## - no data-oriented rewrite yet
## - normal enemies can ask this manager to free them later

@export var max_enemy_frees_per_frame: int = 1

var _active_enemies: Array[Node] = []
var _free_queue: Array[Node] = []


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
	_free_queue.erase(enemy)


func queue_enemy_free(enemy: Node) -> void:
	if enemy == null:
		return

	if not is_instance_valid(enemy):
		return

	if enemy in _free_queue:
		return

	_free_queue.append(enemy)


func get_active_enemy_count() -> int:
	_cleanup_invalid_enemies()
	return _active_enemies.size()


func get_pending_free_count() -> int:
	_cleanup_invalid_free_queue()
	return _free_queue.size()


func clear() -> void:
	_active_enemies.clear()
	_free_queue.clear()
	
func get_pending_count() -> int:
	return get_pending_free_count()

func _process(_delta: float) -> void:
	_process_free_queue()


func _process_free_queue() -> void:
	if _free_queue.is_empty():
		return

	var count: int = mini(max_enemy_frees_per_frame, _free_queue.size())

	for i in count:
		if _free_queue.is_empty():
			return

		var enemy: Node = _free_queue.pop_front()

		if not is_instance_valid(enemy):
			continue

		unregister_enemy(enemy)
		enemy.queue_free()


func _cleanup_invalid_enemies() -> void:
	for i in range(_active_enemies.size() - 1, -1, -1):
		if not is_instance_valid(_active_enemies[i]):
			_active_enemies.remove_at(i)


func _cleanup_invalid_free_queue() -> void:
	for i in range(_free_queue.size() - 1, -1, -1):
		if not is_instance_valid(_free_queue[i]):
			_free_queue.remove_at(i)
