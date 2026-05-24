extends TextureProgressBar
class_name WorldHealthBar

@export var health_component: HealthComponent
@export var hide_when_full: bool = true
@export var hide_when_dead: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if health_component == null:
		health_component = get_parent().get_node_or_null("HealthComponent")

	if health_component == null:
		push_warning("WorldHealthBar could not find a HealthComponent.")
		return

	if not health_component.health_changed.is_connected(_on_health_changed):
		health_component.health_changed.connect(_on_health_changed)

	if not health_component.died.is_connected(_on_died):
		health_component.died.connect(_on_died)

	_refresh()

	await get_tree().process_frame
	_refresh()


func _on_health_changed(current_health: int, max_health: int) -> void:
	max_value = max_health
	value = current_health
	_update_visibility()


func _on_died() -> void:
	if hide_when_dead:
		hide()


func _refresh() -> void:
	if health_component == null:
		return

	min_value = 0
	max_value = health_component.max_health
	value = health_component.current_health

	_update_visibility()


func _update_visibility() -> void:
	if hide_when_dead and value <= 0:
		hide()
		return

	if hide_when_full and value >= max_value:
		hide()
		return

	show()
