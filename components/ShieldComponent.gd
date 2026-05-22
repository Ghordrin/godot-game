extends Node
class_name ShieldComponent

signal shield_changed(current: float, maximum: float)
signal shield_broken
signal shield_restored

@export var max_shield: float = 50.0
@export var regen_rate: float = 8.0
@export var regen_delay: float = 3.0
@export var break_duration: float = 4.0

var current_shield: float = 0.0
var is_broken: bool = false

var _regen_timer: float = 0.0
var _break_timer: float = 0.0

var _sprite: CanvasItem = null
var _bar_container: Node2D = null
var _bar_bg: ColorRect = null
var _bar: ColorRect = null

const BAR_WIDTH: float = 40.0
const BAR_HEIGHT: float = 5.0
const BAR_Y: float = -44.0


func _ready() -> void:
	current_shield = max_shield

	var parent := get_parent()
	if parent:
		_sprite = parent.get_node_or_null("AnimatedSprite2D") as CanvasItem
		if _sprite == null:
			_sprite = parent.get_node_or_null("Sprite2D") as CanvasItem

	_build_shield_bar()
	_update_bar()
	shield_changed.emit(current_shield, max_shield)


func _process(delta: float) -> void:
	if is_broken:
		_break_timer += delta
		if _break_timer >= break_duration:
			is_broken = false
			_break_timer = 0.0
			_regen_timer = regen_delay
			current_shield = 0.0
			shield_restored.emit()
	else:
		if current_shield < max_shield:
			_regen_timer += delta
			if _regen_timer >= regen_delay:
				current_shield = min(current_shield + regen_rate * delta, max_shield)
				shield_changed.emit(current_shield, max_shield)

	_update_bar()


func absorb(amount: float) -> float:
	if amount <= 0.0:
		return 0.0

	if is_broken or current_shield <= 0.0:
		return amount

	_regen_timer = 0.0

	if amount <= current_shield:
		current_shield -= amount
		shield_changed.emit(current_shield, max_shield)
		_flash(Color(0.5, 0.75, 1.5, 1.0))
		_update_bar()
		return 0.0

	var overflow: float = amount - current_shield
	current_shield = 0.0
	shield_changed.emit(current_shield, max_shield)
	_break()
	_update_bar()
	return overflow


func _break() -> void:
	is_broken = true
	_break_timer = 0.0
	shield_broken.emit()
	_flash(Color(2.0, 2.0, 2.0, 1.0))


func _flash(color: Color) -> void:
	if _sprite == null:
		return

	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", color, 0.05)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.25)


func _build_shield_bar() -> void:
	var parent: Node2D = get_parent() as Node2D
	if parent == null:
		return

	_bar_container = Node2D.new()
	_bar_container.name = "ShieldBar"
	_bar_container.position = Vector2(0.0, BAR_Y)
	_bar_container.z_index = 250
	parent.add_child(_bar_container)

	_bar_bg = ColorRect.new()
	_bar_bg.name = "ShieldBarBackground"
	_bar_bg.color = Color(0.03, 0.04, 0.08, 0.90)
	_bar_bg.size = Vector2(BAR_WIDTH + 2.0, BAR_HEIGHT + 2.0)
	_bar_bg.position = Vector2(-(BAR_WIDTH + 2.0) / 2.0, -1.0)
	_bar_container.add_child(_bar_bg)

	_bar = ColorRect.new()
	_bar.name = "ShieldBarFill"
	_bar.color = Color(0.30, 0.70, 1.00, 0.95)
	_bar.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bar.position = Vector2(-BAR_WIDTH / 2.0, 0.0)
	_bar_container.add_child(_bar)


func _update_bar() -> void:
	if _bar == null or _bar_bg == null:
		return

	if is_broken:
		_bar.visible = false
		_bar_bg.visible = false
		return

	_bar.visible = true
	_bar_bg.visible = true

	var pct: float = 0.0
	if max_shield > 0.0:
		pct = clamp(current_shield / max_shield, 0.0, 1.0)

	var visible_width: float = BAR_WIDTH * pct
	if current_shield > 0.0:
		visible_width = max(2.0, visible_width)

	_bar.size = Vector2(visible_width, BAR_HEIGHT)
	_bar.position = Vector2(-BAR_WIDTH / 2.0, 0.0)

	_bar.color = Color(0.30, 0.70, 1.00, 0.95).lerp(
		Color(0.95, 0.25, 0.25, 0.95),
		1.0 - pct
	)


func get_debug_string() -> String:
	if is_broken:
		return "Shield: BROKEN"
	return "Shield: %.0f / %.0f" % [current_shield, max_shield]
