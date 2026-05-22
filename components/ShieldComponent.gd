extends Node
class_name ShieldComponent

## Absorbs incoming damage before health takes any hit.
## Poison bypasses this entirely.
## Add as a child node of any enemy scene that should have a shield.

signal shield_changed(current: float, maximum: float)
signal shield_broken
signal shield_restored

## Total shield capacity
@export var max_shield: float = 50.0

## Shield points regenerated per second (after regen delay expires)
@export var regen_rate: float = 8.0

## Seconds after taking damage before regen begins
@export var regen_delay: float = 3.0

## How long shield stays fully broken before restarting regen
@export var break_duration: float = 4.0

var current_shield: float
var is_broken: bool = false

var _regen_timer: float   = 0.0
var _break_timer: float   = 0.0
var _sprite: Node         = null
var _bar: ColorRect       = null
var _bar_bg: ColorRect    = null


func _ready() -> void:
	current_shield = max_shield

	_sprite = get_parent().get_node_or_null("AnimatedSprite2D")
	if _sprite == null:
		_sprite = get_parent().get_node_or_null("Sprite2D")

	_build_shield_bar()


func _process(delta: float) -> void:
	if is_broken:
		_break_timer += delta
		if _break_timer >= break_duration:
			is_broken    = false
			_break_timer = 0.0
			_regen_timer = 0.0
			current_shield = 0.0  # Starts regenning from 0
			shield_restored.emit()
	else:
		if current_shield < max_shield:
			_regen_timer += delta
			if _regen_timer >= regen_delay:
				current_shield = min(current_shield + regen_rate * delta, max_shield)
				shield_changed.emit(current_shield, max_shield)

	_update_bar()


## Attempt to absorb incoming damage.
## Returns leftover damage that passes through to health.
func absorb(amount: float) -> float:
	if is_broken or current_shield <= 0.0:
		return amount

	_regen_timer = 0.0  # Reset regen on every hit

	if amount <= current_shield:
		current_shield -= amount
		shield_changed.emit(current_shield, max_shield)
		_flash(Color(0.5, 0.75, 1.5, 1.0))  # Blue flash = absorbed
		return 0.0
	else:
		var overflow: float = amount - current_shield
		current_shield = 0.0
		_break()
		return overflow


func _break() -> void:
	is_broken    = true
	_break_timer = 0.0
	shield_broken.emit()
	_flash(Color(2.0, 2.0, 2.0, 1.0))  # White flash = break


func _flash(color: Color) -> void:
	if _sprite == null:
		return
	var t := create_tween()
	t.tween_property(_sprite, "modulate", color, 0.05)
	t.tween_property(_sprite, "modulate", Color.WHITE, 0.25)


func _build_shield_bar() -> void:
	var parent := get_parent() as Node2D
	if parent == null:
		return

	# Bar sits above the enemy — z_index ensures it renders over the sprite
	var BAR_WIDTH: float  = 36.0
	var BAR_HEIGHT: float = 5.0
	var BAR_Y: float      = -32.0

	# Dark background behind the fill
	_bar_bg          = ColorRect.new()
	_bar_bg.color    = Color(0.08, 0.08, 0.15, 0.9)
	_bar_bg.size     = Vector2(BAR_WIDTH + 2.0, BAR_HEIGHT + 2.0)
	_bar_bg.position = Vector2(-(BAR_WIDTH + 2.0) / 2.0, BAR_Y - 1.0)
	_bar_bg.z_index  = 5   # Above sprite layer
	parent.add_child(_bar_bg)

	# Fill — starts full, shrinks left as shield absorbs damage
	_bar          = ColorRect.new()
	_bar.color    = Color(0.30, 0.70, 1.00, 0.95)
	_bar.size     = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bar.position = Vector2(-BAR_WIDTH / 2.0, BAR_Y)
	_bar.z_index  = 6   # On top of background
	parent.add_child(_bar)


func _update_bar() -> void:
	if _bar == null:
		return

	if is_broken:
		_bar.visible    = false
		_bar_bg.visible = false
		return

	_bar.visible    = true
	_bar_bg.visible = true

	var pct: float = clamp(current_shield / max_shield, 0.0, 1.0)
	var full_width: float = _bar_bg.size.x - 2.0  # Match bg minus padding

	# Full Vector2 assignment — avoids Godot copy-of-struct issues with .x/.y assignment
	_bar.size = Vector2(full_width * pct, _bar.size.y)

	# Shifts from shield blue → red as it depletes
	_bar.color = Color(0.30, 0.70, 1.00).lerp(Color(0.90, 0.25, 0.25), 1.0 - pct)
