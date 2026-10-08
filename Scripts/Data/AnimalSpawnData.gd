class_name AnimalSpawnData
extends Resource

@export var animal_name: String = "Animal"
@export var scene: PackedScene
@export var selection_weight: float = 1.0

@export_group("Group Size")
@export var min_group_size: int = 1
@export var max_group_size: int = 3

@export_group("Companions / Young")
@export var baby_scene: PackedScene = null
@export_range(0.0, 1.0) var baby_chance: float = 0.0
@export var min_babies: int = 0
@export var max_babies: int = 2

@export_group("Habitat")
@export_enum("Any", "Plains", "Forest") var preferred_habitat: String = "Any"
