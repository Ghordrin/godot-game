extends Node
class_name DamageResolver

## Resolves damage against target-side combat rules.
##
## This class temporarily keeps build_projectile_packet() as a compatibility
## wrapper while callers migrate to DamageBuilder directly.


static func build_projectile_packet(
	base_damage: float,
	equipped_powerups: Array,
	current_wave: int
) -> DamagePacket:
	return DamageBuilder.build_projectile_packet(
		base_damage,
		equipped_powerups,
		current_wave
	)
