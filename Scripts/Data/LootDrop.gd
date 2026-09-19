extends Resource
class_name LootDrop

@export var item: ItemData
@export var min_count: int = 1
@export var max_count: int = 1
@export_range(0.0, 1.0) var chance: float = 1.0
