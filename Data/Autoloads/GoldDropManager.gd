extends Node

## Handles gold drop aggregation and spawn throttling.
## DeathWorkQueue should forward gold payloads here instead of spawning gold itself.

@export var enabled: bool = true

## Limits how many gold pickup scenes are instantiated per frame.
@export var max_gold_spawns_per_frame: int = 4

## Nearby gold drops get merged into one larger pickup.
@export var merge_gold_drops: bool = true
@export var gold_merge_radius: float = 96.0
@export var max_gold_payloads_per_pickup: int = 12

var _gold_payloads: Array[Dictionary] = []


func enqueue_gold_drop(
	position: Vector2,
	gold_amount: int,
	gold_pickup_scene: PackedScene
) -> void:
	if not enabled:
		return

	if gold_pickup_scene == null:
		return

	if gold_amount <= 0:
		return

	var payload := {
		"position": position,
		"gold_amount": gold_amount,
		"gold_pickup_scene": gold_pickup_scene,
		"merged_count": 1,
	}

	if merge_gold_drops and _try_merge_gold_payload(payload):
		return

	_gold_payloads.append(payload)


func clear() -> void:
	_gold_payloads.clear()


func _process(_delta: float) -> void:
	_process_gold_payloads()

func get_pending_count() -> int:
	return _gold_payloads.size()

func _process_gold_payloads() -> void:
	if _gold_payloads.is_empty():
		return

	var scene_root: Node = get_tree().current_scene

	if scene_root == null:
		_gold_payloads.clear()
		return

	var count: int = mini(max_gold_spawns_per_frame, _gold_payloads.size())

	for i in count:
		var payload: Dictionary = _gold_payloads.pop_front()
		_spawn_gold(scene_root, payload)


func _try_merge_gold_payload(new_payload: Dictionary) -> bool:
	var new_position: Vector2 = new_payload.get("position", Vector2.ZERO)
	var new_scene: PackedScene = new_payload.get("gold_pickup_scene", null)

	for payload: Dictionary in _gold_payloads:
		if payload.get("gold_pickup_scene", null) != new_scene:
			continue

		var merged_count: int = int(payload.get("merged_count", 1))

		if merged_count >= max_gold_payloads_per_pickup:
			continue

		var old_position: Vector2 = payload.get("position", Vector2.ZERO)

		if old_position.distance_to(new_position) > gold_merge_radius:
			continue

		var old_amount: int = int(payload.get("gold_amount", 0))
		var new_amount: int = int(new_payload.get("gold_amount", 0))

		payload["gold_amount"] = old_amount + new_amount
		payload["merged_count"] = merged_count + 1
		payload["position"] = old_position.lerp(new_position, 0.25)

		return true

	return false


func _spawn_gold(scene_root: Node, payload: Dictionary) -> void:
	var gold_pickup_scene: PackedScene = payload.get("gold_pickup_scene", null)

	if gold_pickup_scene == null:
		return

	var gold_pickup := gold_pickup_scene.instantiate() as GoldPickup

	if gold_pickup == null:
		push_warning("GoldDropManager: gold_pickup_scene root is not a GoldPickup.")
		return

	gold_pickup.gold_amount = int(payload.get("gold_amount", 0))
	gold_pickup.global_position = payload.get("position", Vector2.ZERO) + Vector2(
		randf_range(-12.0, 12.0),
		randf_range(-12.0, 12.0)
	)

	scene_root.add_child(gold_pickup)
