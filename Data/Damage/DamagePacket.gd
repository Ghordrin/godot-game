extends Resource
class_name DamagePacket

var entries: Array[Dictionary] = []
var source: Node = null
var target: Node = null
var debug_lines: Array[String] = []


func add_damage(amount: float, damage_type: String, source_label: String = "") -> void:
	if amount <= 0.0:
		return

	entries.append({
		"amount": amount,
		"type": damage_type,
		"source": source_label,
	})


func get_total() -> float:
	var total: float = 0.0
	for entry: Dictionary in entries:
		total += float(entry.amount)
	return total


func is_empty() -> bool:
	return entries.is_empty()


func add_debug(line: String) -> void:
	debug_lines.append(line)


func print_debug() -> void:
	for line: String in debug_lines:
		print(line)
