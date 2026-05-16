extends Node

func play_if_exists(sprite: AnimatedSprite2D, animation_name: String) -> void:
	if sprite == null:
		return
	if sprite.sprite_frames == null:
		return
	if sprite.sprite_frames.has_animation(animation_name):
		if sprite.animation != animation_name:
			sprite.play(animation_name)
