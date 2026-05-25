extends Node


const LOG_PATH: String = "user://combat_debug_log.txt"

@export var enabled: bool = true
@export var also_print_to_console: bool = false

var _file: FileAccess = null
var _start_time_msec: int = 0


func _ready() -> void:
	_start_time_msec = Time.get_ticks_msec()
	_clear_log_file()
	log_line("=== NEW GAME SESSION STARTED ===")
	log_line("Log path: %s" % ProjectSettings.globalize_path(LOG_PATH))


func _exit_tree() -> void:
	if _file != null:
		_file.flush()
		_file.close()
		_file = null


func log_line(message: String) -> void:
	if not enabled:
		return

	if _file == null:
		_open_log_file()

	var elapsed: float = float(Time.get_ticks_msec() - _start_time_msec) / 1000.0
	var line := "[%08.3f] %s" % [elapsed, message]

	_file.store_line(line)
	_file.flush()

	if also_print_to_console:
		print(line)


func log_damage(
	victim: Node,
	raw_total: float,
	final_damage: int,
	damage_breakdown: Array,
	current_health_before: int,
	current_health_after: int,
	max_health: int
) -> void:
	if not enabled:
		return

	var victim_name := _describe_node(victim)
	var victim_groups := _get_group_string(victim)

	log_line(
		"DAMAGE victim=%s groups=[%s] raw_total=%.2f final=%d hp=%d/%d -> %d/%d breakdown=%s"
		% [
			victim_name,
			victim_groups,
			raw_total,
			final_damage,
			current_health_before,
			max_health,
			current_health_after,
			max_health,
			_format_breakdown(damage_breakdown),
		]
	)


func log_damage_ignored(victim: Node, reason: String, packet_summary: String = "") -> void:
	if not enabled:
		return

	log_line(
		"DAMAGE_IGNORED victim=%s reason=%s packet=%s"
		% [
			_describe_node(victim),
			reason,
			packet_summary,
		]
	)


func log_death(victim: Node, max_health: int) -> void:
	if not enabled:
		return

	log_line(
		"DEATH victim=%s groups=[%s] max_health=%d"
		% [
			_describe_node(victim),
			_get_group_string(victim),
			max_health,
		]
	)


func log_health_set(victim: Node, old_health: int, new_health: int, max_health: int) -> void:
	if not enabled:
		return

	log_line(
		"HEALTH_SET victim=%s hp=%d/%d -> %d/%d"
		% [
			_describe_node(victim),
			old_health,
			max_health,
			new_health,
			max_health,
		]
	)


func log_heal(victim: Node, amount: int, old_health: int, new_health: int, max_health: int) -> void:
	if not enabled:
		return

	log_line(
		"HEAL victim=%s amount=%d hp=%d/%d -> %d/%d"
		% [
			_describe_node(victim),
			amount,
			old_health,
			max_health,
			new_health,
			max_health,
		]
	)


func _clear_log_file() -> void:
	if _file != null:
		_file.close()
		_file = null

	_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)

	if _file == null:
		push_warning("CombatDebugLogger: Could not open log file at %s" % LOG_PATH)


func _open_log_file() -> void:
	if _file != null:
		return

	_file = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)

	if _file == null:
		push_warning("CombatDebugLogger: Could not open log file at %s" % LOG_PATH)
		return

	_file.seek_end()


func _describe_node(node: Node) -> String:
	if node == null:
		return "<null>"

	var parts: Array[String] = []

	parts.append("name=%s" % node.name)
	parts.append("class=%s" % node.get_class())
	parts.append("id=%s" % str(node.get_instance_id()))

	if node.scene_file_path != "":
		parts.append("scene=%s" % node.scene_file_path)

	if node is Node2D:
		parts.append("pos=%s" % str((node as Node2D).global_position))

	return "{%s}" % ", ".join(parts)


func _get_group_string(node: Node) -> String:
	if node == null:
		return ""

	var names: Array[String] = []

	for group_name in node.get_groups():
		names.append(String(group_name))

	return ", ".join(names)


func _format_breakdown(damage_breakdown: Array) -> String:
	if damage_breakdown.is_empty():
		return "[]"

	var parts: Array[String] = []

	for entry in damage_breakdown:
		if entry is Dictionary:
			var amount: float = float(entry.get("amount", 0.0))
			var damage_type: String = String(entry.get("type", "unknown"))
			var source: String = String(entry.get("source", "unknown"))
			parts.append("{type=%s amount=%.2f source=%s}" % [damage_type, amount, source])
		else:
			parts.append(str(entry))

	return "[%s]" % ", ".join(parts)


func summarize_packet(packet: DamagePacket) -> String:
	if packet == null:
		return "<null>"

	if packet.is_empty():
		return "<empty>"

	return _format_breakdown(packet.entries)
