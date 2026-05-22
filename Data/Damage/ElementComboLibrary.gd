extends RefCounted
class_name ElementComboLibrary

enum CombinedElement {
	NONE,
	THERMAL,
	PLASMA,
	CORROSIVE,
	MAGNETIC,
	VIRAL,
	NEUROTOXIN,
}


static func get_combo(a: int, b: int) -> CombinedElement:
	var fire: int = PowerUpData.ElementType.FIRE
	var ice: int = PowerUpData.ElementType.ICE
	var lightning: int = PowerUpData.ElementType.LIGHTNING
	var poison: int = PowerUpData.ElementType.POISON

	if _pair(a, b, fire, ice):
		return CombinedElement.THERMAL
	if _pair(a, b, fire, lightning):
		return CombinedElement.PLASMA
	if _pair(a, b, fire, poison):
		return CombinedElement.CORROSIVE
	if _pair(a, b, ice, lightning):
		return CombinedElement.MAGNETIC
	if _pair(a, b, ice, poison):
		return CombinedElement.VIRAL
	if _pair(a, b, lightning, poison):
		return CombinedElement.NEUROTOXIN

	return CombinedElement.NONE


static func get_combo_name(combo: CombinedElement) -> String:
	match combo:
		CombinedElement.THERMAL:
			return "THERMAL"
		CombinedElement.PLASMA:
			return "PLASMA"
		CombinedElement.CORROSIVE:
			return "CORROSIVE"
		CombinedElement.MAGNETIC:
			return "MAGNETIC"
		CombinedElement.VIRAL:
			return "VIRAL"
		CombinedElement.NEUROTOXIN:
			return "NEUROTOXIN"
		_:
			return "NONE"


static func _pair(a: int, b: int, x: int, y: int) -> bool:
	return (a == x and b == y) or (a == y and b == x)
