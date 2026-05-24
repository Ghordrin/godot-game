extends Label
class_name EnemyDebugLabel

@export var health_component: HealthComponent
@export var stats_component: Node

@export var show_health: bool = true
@export var show_damage: bool = true
@export var show_speed: bool = true
@export var show_affixes: bool = true
@export var always_visible: bool = true

var enemy_root: Node2D = null


func _ready() -> void:
	enemy_root = _find_enemy_root()

	if enemy_root == null:
		text = "DebugLabel: no enemy root"
		return

	_find_components()
	_connect_health_signals()

	visible = always_visible or OS.is_debug_build()

	_update_label()

	await get_tree().process_frame
	_update_label()


func _process(_delta: float) -> void:
	if visible:
		_update_label()


func _find_enemy_root() -> Node2D:
	var node: Node = get_parent()

	while node != null:
		if node is Node2D and node.has_node("HealthComponent"):
			return node as Node2D

		node = node.get_parent()

	return get_parent() as Node2D


func _find_components() -> void:
	if enemy_root == null:
		return

	if health_component == null:
		health_component = enemy_root.get_node_or_null("HealthComponent") as HealthComponent

	if stats_component == null:
		stats_component = enemy_root.get_node_or_null("StatsComponent")


func _connect_health_signals() -> void:
	if health_component == null:
		return

	if not health_component.health_changed.is_connected(_on_health_changed):
		health_component.health_changed.connect(_on_health_changed)

	if not health_component.died.is_connected(_on_died):
		health_component.died.connect(_on_died)


func _on_health_changed(_current_health: int, _max_health: int) -> void:
	_update_label()


func _on_died() -> void:
	_update_label()


func _update_label() -> void:
	if enemy_root == null:
		text = "DebugLabel: no root"
		return

	if health_component == null:
		_find_components()

	var lines: Array[String] = []

	if show_health:
		lines.append(_get_health_text())

	if show_damage:
		var damage_text := _get_damage_text()

		if damage_text != "":
			lines.append(damage_text)

	if show_speed:
		var speed_text := _get_speed_text()

		if speed_text != "":
			lines.append(speed_text)

	if show_affixes:
		var affix_text := _get_affix_text()

		if affix_text != "":
			lines.append(affix_text)

	text = "\n".join(lines)


func _get_health_text() -> String:
	if health_component == null:
		return "HP: missing HealthComponent"

	return "HP: %d / %d" % [
		health_component.current_health,
		health_component.max_health
	]


func _get_damage_text() -> String:
	if enemy_root == null:
		return ""

	if "damage" in enemy_root:
		return "DMG: %.1f" % float(enemy_root.damage)

	if stats_component != null and "damage" in stats_component:
		return "DMG: %.1f" % float(stats_component.damage)

	return ""


func _get_speed_text() -> String:
	if enemy_root == null:
		return ""

	if "move_speed" in enemy_root:
		return "SPD: %.1f" % float(enemy_root.move_speed)

	if stats_component != null and "move_speed" in stats_component:
		return "SPD: %.1f" % float(stats_component.move_speed)

	return ""


func _get_affix_text() -> String:
	if enemy_root == null:
		return ""

	var affix_component := enemy_root.get_node_or_null("AffixComponent")

	if affix_component == null:
		return ""

	if not "active_affixes" in affix_component:
		return ""

	var active_affixes: Array = affix_component.active_affixes

	if active_affixes.is_empty():
		return ""

	var names: Array[String] = []

	for affix in active_affixes:
		if affix == null:
			continue

		if "display_name" in affix:
			names.append(String(affix.display_name))
		else:
			names.append(str(affix))

	if names.is_empty():
		return ""

	return "AFFIX: " + ", ".join(names)
