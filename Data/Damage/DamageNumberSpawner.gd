extends Node

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://Data/UI/DamageNumber.tscn")

@export var enabled: bool = true
@export var max_active_numbers: int = 80
@export var max_spawns_per_frame: int = 10
@export var max_pending_requests: int = 160
@export var hide_small_numbers_when_busy: bool = true
@export var busy_threshold: int = 55
@export var small_number_cutoff: float = 1.0

var _pending_requests: Array[Dictionary] = []
var _active_numbers: Array[DamageNumber] = []


func _process(_delta: float) -> void:
	_cleanup_invalid_active_numbers()
	_flush_pending_requests()


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
	if not enabled:
		return

	if amount <= 0.0:
		return

	if hide_small_numbers_when_busy:
		if _active_numbers.size() >= busy_threshold and amount <= small_number_cutoff:
			return

	var request := {
		"world_pos": world_pos,
		"amount": amount,
		"damage_type": damage_type,
		"color": color,
		"index": index,
		"is_dot": is_dot,
	}

	if _pending_requests.size() >= max_pending_requests:
		_pending_requests.pop_front()

	_pending_requests.append(request)


func clear_all() -> void:
	_pending_requests.clear()

	for number: DamageNumber in _active_numbers:
		if is_instance_valid(number):
			number.queue_free()

	_active_numbers.clear()


func _flush_pending_requests() -> void:
	if _pending_requests.is_empty():
		return

	var scene_root: Node = get_tree().current_scene

	if scene_root == null:
		_pending_requests.clear()
		return

	var free_slots: int = max_active_numbers - _active_numbers.size()

	if free_slots <= 0:
		_pending_requests.clear()
		return

	var spawn_count: int = mini(
		max_spawns_per_frame,
		mini(free_slots, _pending_requests.size())
	)

	for i in spawn_count:
		var request: Dictionary = _pending_requests.pop_front()
		_spawn_now(scene_root, request)


func _spawn_now(scene_root: Node, request: Dictionary) -> void:
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate() as DamageNumber

	if damage_number == null:
		return

	scene_root.add_child(damage_number)

	var world_pos: Vector2 = request.get("world_pos", Vector2.ZERO)
	var index: int = int(request.get("index", 0))

	damage_number.global_position = world_pos + Vector2(
		0.0,
		-36.0 - float(index) * 28.0
	)

	damage_number.setup(
		float(request.get("amount", 0.0)),
		String(request.get("damage_type", "")),
		request.get("color", Color.WHITE),
		bool(request.get("is_dot", false))
	)

	_active_numbers.append(damage_number)


func _cleanup_invalid_active_numbers() -> void:
	for i in range(_active_numbers.size() - 1, -1, -1):
		if not is_instance_valid(_active_numbers[i]):
			_active_numbers.remove_at(i)
