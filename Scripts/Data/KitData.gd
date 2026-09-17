extends Resource
class_name KitData

@export var kit_id: String
@export var display_name: String
@export var description: String = ""

@export var required_items: Array[ItemData]

@export var sprite_frames: SpriteFrames

@export_group("Combat Stats")
@export var knockback_force: float = 0.0
@export_range(0.0, 1.0) var knockback_resistance: float = 0.0
