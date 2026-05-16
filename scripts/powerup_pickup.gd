extends Area2D
class_name PowerUpPickup

## A pickup that adds a powerup to the player's inventory instead of
## applying it immediately. The powerup becomes active only when the
## player equips it in the shop.

@export var powerup_data: PowerUpData

@onready var sprite: Sprite2D = $Sprite2D
@onready var beam: LootBeam = $PowerupBeam
@onready var pickup_sound: AudioStreamPlayer2D = $PickupSound

func _ready() -> void:
	if powerup_data == null:
		push_warning("PowerUpPickup has no PowerUpData assigned.")
		return
	if powerup_data.icon:
		sprite.texture = powerup_data.icon
	_apply_rarity_visuals()
	pickup_sound.play()
	await pickup_sound.finished

func _on_body_entered(body: Node2D) -> void:
	# The player has picked up this powerup.
	# Instead of immediately applying it, add it to the inventory.
	# The player will equip it later in the shop if they want to use it.
	if body.is_in_group("player"):
		PlayerInventory.collect_powerup(powerup_data)
		sprite.visible = false
		beam.visible = false
		set_deferred("monitoring", false)
		queue_free()

func _apply_rarity_visuals() -> void:
	# Match the powerup's rarity to the visual beam effect.
	var loot_rarity: LootBeam.Rarity
	
	match powerup_data.rarity:
		PowerUpData.Rarity.COMMON:
			loot_rarity = LootBeam.Rarity.COMMON
		PowerUpData.Rarity.RARE:
			loot_rarity = LootBeam.Rarity.RARE
		PowerUpData.Rarity.EPIC:
			loot_rarity = LootBeam.Rarity.EPIC
		PowerUpData.Rarity.LEGENDARY:
			loot_rarity = LootBeam.Rarity.LEGENDARY
		_:
			loot_rarity = LootBeam.Rarity.COMMON
	
	beam.set_rarity(loot_rarity)
	beam.set_item_name(powerup_data.display_name)
