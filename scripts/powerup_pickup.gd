extends Area2D
class_name PowerUpPickup

## A pickup that can behave in two different ways depending on context:
## - If is_wave_temporary = false: adds powerup to inventory (permanent, shop-style)
## - If is_wave_temporary = true: applies powerup immediately, expires at wave end

@export var powerup_data: PowerUpData

## When true, this powerup applies immediately and expires when the wave ends.
## When false, this powerup goes into the inventory for later equipping.
## Enemies should set this to true when dropping powerups during combat.
@export var is_wave_temporary: bool = false

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
	if body.is_in_group("player"):
		if is_wave_temporary:
			# This is a combat drop - apply it immediately as a temporary buff.
			# It will be cleared when the wave ends.
			PlayerInventory.apply_wave_temporary_powerup(powerup_data)
		else:
			# This is a permanent pickup (from shop or special event).
			# Add it to the inventory so the player can equip it later.
			PlayerInventory.collect_powerup(powerup_data)
		
		# Clean up the visual pickup regardless of which path we took.
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
