extends Resource
class_name ItemData

@export var name: String
@export var display_name: String
@export var icon: Texture2D
@export var stack_size: int = 1

@export_group("Hatching")
@export var can_hatch: bool = false
@export var hatch_scene: PackedScene = null
@export var hatch_chance: float = 0.125
@export var hatch_duration_min: float = 160.0
@export var hatch_duration_max: float = 200.0
