extends RefCounted
class_name DamageVisuals


static func get_color(damage_type: String) -> Color:
	match damage_type:
		"fire":
			return Color(1.00, 0.42, 0.08)
		"ice":
			return Color(0.40, 0.85, 1.00)
		"lightning":
			return Color(0.80, 0.55, 1.00)
		"poison":
			return Color(0.35, 1.00, 0.30)

		"thermal":
			return Color(1.00, 0.65, 0.25)
		"plasma":
			return Color(1.00, 0.25, 0.85)
		"corrosive":
			return Color(0.65, 1.00, 0.10)
		"magnetic":
			return Color(0.25, 1.00, 1.00)
		"viral":
			return Color(0.75, 0.25, 1.00)
		"neurotoxin":
			return Color(0.55, 1.00, 0.45)

		"combo":
			return Color(1.00, 0.88, 0.15)

		_:
			return Color.WHITE


static func get_display_name(damage_type: String) -> String:
	match damage_type:
		"fire":
			return "FIRE"
		"ice":
			return "ICE"
		"lightning":
			return "LIGHTNING"
		"poison":
			return "POISON"
		"thermal":
			return "THERMAL"
		"plasma":
			return "PLASMA"
		"corrosive":
			return "CORROSIVE"
		"magnetic":
			return "MAGNETIC"
		"viral":
			return "VIRAL"
		"neurotoxin":
			return "NEUROTOXIN"
		_:
			return ""
