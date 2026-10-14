extends Resource
class_name ItemData

@export var name: String
@export var display_name: String
@export var icon: Texture2D
@export var stack_size: int = 1

@export_group("Equipment")
@export var is_equipment: bool = false

@export_group("Hatching")
@export var can_hatch: bool = false
@export var hatch_scene: PackedScene = null
@export var hatch_chance: float = 0.125
@export var hatch_duration_min: float = 160.0
@export var hatch_duration_max: float = 200.0

@export_group("Food")
@export var is_food: bool = false
@export var nutrition: float = 50.0
@export var heal_amount: float = 0.0

func is_equipment_item() -> bool:
	if is_equipment:
		return true
	if resource_path != "" and "equipment" in resource_path.to_lower():
		return true
	if name in ["archer_cap", "bow", "knight_helmet", "pot_helmet", "quiver", "shield", "spear", "sword"]:
		return true
	if Global and Global.has_method("is_kit_item") and Global.is_kit_item(self):
		return true
	return false
