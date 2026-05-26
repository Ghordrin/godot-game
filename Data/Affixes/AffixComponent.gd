extends Node
class_name AffixComponent

const ShieldComponentScript := preload("res://components/ShieldComponent.gd")

var active_affixes: Array[AffixData] = []

var is_cc_immune: bool = false
var is_combo_immune: bool = false

var _regen_timer: float = 0.0
var _guardian_shielded: Array[Node] = []

var _sprite: AnimatedSprite2D = null
var _label_node: Node2D = null

const REGEN_RATE: float = 0.01
const GUARDIAN_RADIUS: float = 140.0
const GUARDIAN_MAX_ALLIES: int = 4


func _ready() -> void:
	var parent := get_parent()
	if parent:
		_sprite = parent.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	set_process(true)


func apply_affixes(affixes: Array[AffixData]) -> void:
	active_affixes = affixes.duplicate()

	for affix: AffixData in active_affixes:
		_setup_affix(affix)

	_build_visual_labels()
	_apply_elite_tint()


func has_affix(type: AffixData.AffixType) -> bool:
	for affix: AffixData in active_affixes:
		if affix.affix_type == type:
			return true
	return false


func modify_incoming_damage(amount: float, _damage_type: String) -> float:
	return amount


func _setup_affix(affix: AffixData) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return

	match affix.affix_type:
		AffixData.AffixType.SHIELDED:
			_add_shield(parent, 80.0, 12.0, 3.5)

		AffixData.AffixType.REGENERATING:
			_regen_timer = 0.0

		AffixData.AffixType.FRENZIED:
			if "move_speed" in parent:
				parent.move_speed *= 2.2

			var health := parent.get_node_or_null("HealthComponent") as HealthComponent
			if health != null:
				var new_max: int = maxi(1, int(round(float(health.max_health) * 0.5)))
				health.max_health = new_max
				health.current_health = new_max
				health.health_changed.emit(health.current_health, health.max_health)

			if "damage" in parent:
				parent.damage *= 1.5

		AffixData.AffixType.GUARDIAN:
			_guardian_shielded = []
			var hc := parent.get_node_or_null("HealthComponent") as HealthComponent
			if hc != null and not hc.died.is_connected(_on_guardian_died):
				hc.died.connect(_on_guardian_died)
			call_deferred("_apply_guardian_aura_once", parent)


func _process(delta: float) -> void:
	var parent: Node2D = get_parent() as Node2D
	if parent == null:
		return

	if has_affix(AffixData.AffixType.REGENERATING):
		var health := parent.get_node_or_null("HealthComponent") as HealthComponent
		if health != null and not health.is_dead:
			_regen_timer += delta
			if _regen_timer >= 1.0:
				_regen_timer -= 1.0
				var heal_amount: int = maxi(1, int(round(float(health.max_health) * REGEN_RATE)))
				health.heal(heal_amount)

func _apply_guardian_aura_once(parent: Node2D) -> void:
	if parent == null or not is_instance_valid(parent):
		return

	var candidates: Array = []
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if node == parent or not is_instance_valid(node) or not node is Node2D:
			continue
		var dist: float = (node as Node2D).global_position.distance_to(parent.global_position)
		if dist <= GUARDIAN_RADIUS:
			candidates.append({"node": node, "dist": dist})

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.dist < b.dist)

	var count: int = 0
	for c: Dictionary in candidates:
		if count >= GUARDIAN_MAX_ALLIES:
			break
		var enemy: Node = c.node
		if not is_instance_valid(enemy):
			continue
		if enemy.get_node_or_null("ShieldComponent") != null:
			continue
		_add_guardian_shield(enemy)
		_guardian_shielded.append(enemy)
		count += 1


func _add_guardian_shield(enemy: Node) -> void:
	var shield := _add_shield(enemy, 60.0, 8.0, 4.5)
	if shield != null:
		shield.set_meta("guardian_granted", true)


func _add_shield(target: Node, max_shield: float, regen_rate: float, regen_delay: float) -> ShieldComponent:
	if target.get_node_or_null("ShieldComponent") != null:
		return null
	var shield := ShieldComponentScript.new()
	shield.name = "ShieldComponent"
	shield.max_shield = max_shield
	shield.regen_rate = regen_rate
	shield.regen_delay = regen_delay
	shield.break_duration = 5.0
	target.add_child(shield)
	return shield


func _remove_guardian_shield_from(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	var shield := enemy.get_node_or_null("ShieldComponent")
	if shield != null and shield.get_meta("guardian_granted", false):
		shield.queue_free()


func _on_guardian_died() -> void:
	for enemy in _guardian_shielded:
		_remove_guardian_shield_from(enemy)
	_guardian_shielded.clear()


func _build_visual_labels() -> void:
	var parent: Node2D = get_parent() as Node2D
	if parent == null or active_affixes.is_empty():
		return

	if _label_node != null and is_instance_valid(_label_node):
		_label_node.queue_free()

	_label_node = Node2D.new()
	_label_node.name = "AffixLabels"
	_label_node.position = Vector2(0.0, -56.0)
	_label_node.z_index = 200
	parent.add_child(_label_node)

	var x_offset: float = 0.0

	for affix: AffixData in active_affixes:
		var label := Label.new()
		label.text = affix.display_name
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", affix.color)
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.custom_minimum_size = Vector2(76.0, 14.0)
		label.position = Vector2(x_offset, 0.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label_node.add_child(label)
		x_offset += 78.0

	_label_node.position.x = -(x_offset / 2.0) + 39.0


func _apply_elite_tint() -> void:
	if _sprite == null:
		return

	var tween := create_tween().set_loops()
	tween.tween_property(_sprite, "modulate", Color(1.35, 1.20, 0.75), 1.1)
	tween.tween_property(_sprite, "modulate", Color(1.05, 1.00, 0.80), 1.1)
