extends Node
## Payload-based death/drop queue.
## This does not store enemy nodes or captured lambdas.
## It prepares death payloads over multiple frames and forwards gold to GoldDropManager.

@export var max_payloads_per_frame: int = 2
@export var max_loot_spawns_per_frame: int = 3

var _payloads: Array[Dictionary] = []
var _loot_payloads: Array[Dictionary] = []


func enqueue_enemy_death(payload: Dictionary) -> void:
	if payload.is_empty():
		return

	_payloads.append(payload)


## Compatibility wrappers for older calls.
func enqueue(payload) -> void:
	if payload is Dictionary:
		enqueue_enemy_death(payload)

func get_pending_count() -> int:
	return _payloads.size() + _loot_payloads.size()
	
func enqueue_enemy(_enemy: Node) -> void:
	push_warning("DeathWorkQueue.enqueue_enemy(enemy) is deprecated. Use enqueue_enemy_death(payload).")


func clear() -> void:
	_payloads.clear()
	_loot_payloads.clear()

	var gold_manager := get_node_or_null("/root/GoldDropManager")

	if gold_manager != null and gold_manager.has_method("clear"):
		gold_manager.clear()


func _process(_delta: float) -> void:
	_process_death_payloads()
	_process_loot_payloads()


func _process_death_payloads() -> void:
	if _payloads.is_empty():
		return

	var count: int = mini(max_payloads_per_frame, _payloads.size())

	for i in count:
		var payload: Dictionary = _payloads.pop_front()
		_forward_gold_payload(payload)
		_prepare_loot_payload(payload)


func _forward_gold_payload(payload: Dictionary) -> void:
	var gold_pickup_scene: PackedScene = payload.get("gold_pickup_scene", null)

	if gold_pickup_scene == null:
		return

	var gold_amount: int = int(payload.get("gold_amount", 0))

	if gold_amount <= 0:
		return

	var gold_manager := get_node_or_null("/root/GoldDropManager")

	if gold_manager != null and gold_manager.has_method("enqueue_gold_drop"):
		gold_manager.enqueue_gold_drop(
			payload.get("position", Vector2.ZERO),
			gold_amount,
			gold_pickup_scene
		)
		return

	_spawn_gold_fallback(payload)


func _prepare_loot_payload(payload: Dictionary) -> void:
	var loot_table: PowerUpTable = payload.get("loot_table", null)
	var loot_item_scene: PackedScene = payload.get("loot_item_scene", null)

	if loot_table == null:
		return

	if loot_item_scene == null:
		return

	var force_powerup_drop: bool = bool(payload.get("force_powerup_drop", false))
	var powerup_drop_chance: float = float(payload.get("powerup_drop_chance", 0.0))

	if not force_powerup_drop and randf() > powerup_drop_chance:
		return

	var drop := loot_table.roll_drop()

	if drop == null:
		return

	_loot_payloads.append({
		"loot_item_scene": loot_item_scene,
		"drop": drop,
		"is_wave_temporary_drop": bool(payload.get("is_wave_temporary_drop", true)),
		"position": payload.get("position", Vector2.ZERO),
	})


func _process_loot_payloads() -> void:
	if _loot_payloads.is_empty():
		return

	var scene_root: Node = get_tree().current_scene

	if scene_root == null:
		_loot_payloads.clear()
		return

	var count: int = mini(max_loot_spawns_per_frame, _loot_payloads.size())

	for i in count:
		var payload: Dictionary = _loot_payloads.pop_front()
		_spawn_loot(scene_root, payload)


func _spawn_loot(scene_root: Node, payload: Dictionary) -> void:
	var loot_item_scene: PackedScene = payload.get("loot_item_scene", null)

	if loot_item_scene == null:
		return

	var powerup_pickup := loot_item_scene.instantiate() as PowerUpPickup

	if powerup_pickup == null:
		push_warning("DeathWorkQueue: loot_item_scene root is not a PowerUpPickup.")
		return

	powerup_pickup.powerup_data = payload.get("drop", null)
	powerup_pickup.is_wave_temporary = bool(payload.get("is_wave_temporary_drop", true))
	powerup_pickup.global_position = payload.get("position", Vector2.ZERO)

	scene_root.add_child(powerup_pickup)


func _spawn_gold_fallback(payload: Dictionary) -> void:
	var scene_root: Node = get_tree().current_scene

	if scene_root == null:
		return

	var gold_pickup_scene: PackedScene = payload.get("gold_pickup_scene", null)

	if gold_pickup_scene == null:
		return

	var gold_pickup := gold_pickup_scene.instantiate() as GoldPickup

	if gold_pickup == null:
		push_warning("DeathWorkQueue: gold_pickup_scene root is not a GoldPickup.")
		return

	gold_pickup.gold_amount = int(payload.get("gold_amount", 0))
	gold_pickup.global_position = payload.get("position", Vector2.ZERO) + Vector2(
		randf_range(-12.0, 12.0),
		randf_range(-12.0, 12.0)
	)

	scene_root.add_child(gold_pickup)
