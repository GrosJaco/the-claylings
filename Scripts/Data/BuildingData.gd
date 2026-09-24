extends Resource
class_name BuildingData

@export var building_name: String
@export_enum("Production", "Storage", "Survival", "Decoration", "Agriculture", "Defense") var category: String
@export var icon: Texture2D
@export var scene: PackedScene
@export var cost: Dictionary[ItemData, int]
