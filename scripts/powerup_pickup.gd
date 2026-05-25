extends Area2D
class_name PowerUpPickup

## A pickup that can behave in two different ways depending on context:
## - If is_wave_temporary = false: adds powerup to inventory
## - If is_wave_temporary = true: applies powerup immediately, expires at wave end

@export var powerup_data: PowerUpData

## Enemies should set this to true when dropping combat powerups.
@export var is_wave_temporary: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var beam: LootBeam = $PowerupBeam
@onready var pickup_sound: AudioStreamPlayer2D = $PickupSound

var _collected: bool = false


func _ready() -> void:
	if powerup_data == null:
		push_warning("PowerUpPickup has no PowerUpData assigned.")
		return

	if powerup_data.icon:
		sprite.texture = powerup_data.icon

	_apply_rarity_visuals()

	if pickup_sound != null:
		pickup_sound.play()
		
	add_to_group("powerup_pickups")


func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return

	if not body.is_in_group("player"):
		return

	_collected = true

	if powerup_data == null:
		queue_free()
		return

	if is_wave_temporary:
		PlayerInventory.apply_wave_temporary_powerup(powerup_data)
		_debug_print_temporary_pickup(body)
	else:
		PlayerInventory.collect_powerup(powerup_data)

	sprite.visible = false
	beam.visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	if pickup_sound != null and pickup_sound.stream != null:
		pickup_sound.play()
		await pickup_sound.finished

	queue_free()


func _debug_print_temporary_pickup(player: Node2D) -> void:
	var stats := player.get_node_or_null("StatsComponent") as StatsComponent

	if stats == null:
		print("[PowerUpPickup] Temporary pickup collected: ", powerup_data.display_name)
		return

	await get_tree().process_frame

	print(
		"[PowerUpPickup] Temporary pickup collected: ",
		powerup_data.display_name,
		" stat=",
		powerup_data.stat_to_modify,
		" amount=",
		powerup_data.amount,
		" damage_now=",
		stats.damage
	)


func _apply_rarity_visuals() -> void:
	if beam == null or powerup_data == null:
		return

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
