extends Building
class_name StorageBuilding

@onready var interaction_point: Node2D = $InteractionPoint

@export var capacity: int = 50
var inventory: Dictionary = {}
var current_fill: int = 0

func _ready() -> void:
	super._ready()
	add_to_group("storage")
	update_sprite()

func can_accept(data: ItemData) -> bool:
	if data == null or is_full() or Global.is_kit_item(data):
		return false
	return true

func store_item(item: Dictionary) -> int:
	return deposit(item)

func deposit(item: Dictionary) -> int:
	if item.is_empty():
		return 0
	var data: ItemData = item.get("item", null)
	var amount: int = int(item.get("count", 0))
	if data == null or amount <= 0 or Global.is_kit_item(data):
		return 0
	
	var room = max(0, capacity - current_fill)
	var taken = min(amount, room)
	if taken <= 0:
		return 0
	
	inventory[data] = inventory.get(data, 0) + taken
	current_fill += taken
	update_sprite()
	return taken

func get_stored_amount(data: ItemData) -> int:
	if data == null:
		return 0
	if inventory.has(data):
		return int(inventory[data])
	for k in inventory.keys():
		if k is ItemData and (k.resource_path == data.resource_path or k.name == data.name):
			return int(inventory[k])
	return 0

func withdraw(data: ItemData, amount: int) -> int:
	if data == null or amount <= 0:
		return 0
	var key = data
	if not inventory.has(key):
		for k in inventory.keys():
			if k is ItemData and (k.resource_path == data.resource_path or k.name == data.name):
				key = k
				break
	var stored = int(inventory.get(key, 0))
	var taken = min(stored, amount)
	inventory[key] = stored - taken
	if inventory[key] <= 0:
		inventory.erase(key)
	current_fill = max(0, current_fill - taken)
	update_sprite()
	return taken

func update_sprite():
	if not sprite:
		return
	var fill_ratio = 0.0
	if capacity > 0:
		fill_ratio = float(current_fill) / float(capacity)
	if fill_ratio == 0:
		sprite.frame = 0
	elif fill_ratio < 0.33:
		sprite.frame = 1
	elif fill_ratio < 0.66:
		sprite.frame = 2
	else:
		sprite.frame = 3

func is_full() -> bool:
	return current_fill >= capacity

func available_capacity() -> int:
	return max(0, capacity - current_fill)
