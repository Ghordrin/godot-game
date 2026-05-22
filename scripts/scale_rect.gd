extends ColorRect

func _ready():
	_update_size()
	get_viewport().size_changed.connect(_update_size)

func _update_size():
	size = get_viewport_rect().size
	position = Vector2.ZERO
