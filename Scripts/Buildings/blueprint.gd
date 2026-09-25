extends Node2D
class_name Blueprint

# ========== VARIABLES ==========

var target_building_scene: PackedScene
var required_materials: Dictionary = {}
var current_materials: Dictionary = {}
var incoming_deliveries: Dictionary = {}
var is_preview: bool = false 
var interaction_point: Node2D = null
@onready var visual_root: Node2D = $VisualRoot

# ========== FUNCTIONS ==========

func setup(scene: PackedScene, materials: Dictionary):
	target_building_scene = scene
	required_materials = materials
	_setup_visual(scene)

func _setup_visual(scene: PackedScene) -> void:
	for child in visual_root.get_children():
		child.queue_free()
	
	if not scene:
		return
	
	var temp: Node = scene.instantiate()
	var source_sprite_root: Node = temp.get_node_or_null("SpriteRoot")
	
	if source_sprite_root:
		temp.remove_child(source_sprite_root)
		visual_root.add_child(source_sprite_root)
		source_sprite_root.modulate = Color(0.2, 0.6, 0.8, 0.5)
		
		var visual = source_sprite_root.get_child(0)
		if visual is AnimatedSprite2D and visual.sprite_frames and visual.sprite_frames.has_animation("filled"):
			visual.play("filled")

	var source_ip = temp.get_node_or_null("InteractionPoint")
	if source_ip:
		if interaction_point and is_instance_valid(interaction_point):
			interaction_point.queue_free()
		var ip = Node2D.new()
		ip.name = "InteractionPoint"
		ip.position = source_ip.position
		add_child(ip)
		interaction_point = ip
	
	temp.queue_free()

func _ready():
	add_to_group("crafting_buildings")
	current_materials = {}
	incoming_deliveries = {}
	
# ---------- LOGISTIC ----------

func get_needed_items() -> Dictionary:
	var needed = {}
	for item in required_materials:
		var current = current_materials.get(item, 0)
		if current == 0:
			for k in current_materials.keys():
				if k is ItemData and item is ItemData and (k.resource_path == item.resource_path or k.name == item.name):
					current = current_materials[k]
					break

		var incoming = incoming_deliveries.get(item, 0)
		if incoming == 0:
			for k in incoming_deliveries.keys():
				if k is ItemData and item is ItemData and (k.resource_path == item.resource_path or k.name == item.name):
					incoming = incoming_deliveries[k]
					break

		var target = required_materials[item]
		if current + incoming < target:
			needed[item] = target - (current + incoming)
	return needed

func receive_item(item: ItemData, amount: int):
	var incoming_key = item
	if not incoming_deliveries.has(incoming_key):
		for k in incoming_deliveries.keys():
			if k is ItemData and item is ItemData and (k.resource_path == item.resource_path or k.name == item.name):
				incoming_key = k
				break
	if incoming_deliveries.has(incoming_key):
		incoming_deliveries[incoming_key] -= amount
		if incoming_deliveries[incoming_key] <= 0:
			incoming_deliveries.erase(incoming_key)

	var mat_key = item
	if not current_materials.has(mat_key):
		for k in required_materials.keys():
			if k is ItemData and item is ItemData and (k.resource_path == item.resource_path or k.name == item.name):
				mat_key = k
				break
	current_materials[mat_key] = current_materials.get(mat_key, 0) + amount
	_check_completion()

func cancel_delivery(item: ItemData, amount: int):
	var incoming_key = item
	if not incoming_deliveries.has(incoming_key):
		for k in incoming_deliveries.keys():
			if k is ItemData and item is ItemData and (k.resource_path == item.resource_path or k.name == item.name):
				incoming_key = k
				break
	if incoming_deliveries.has(incoming_key):
		incoming_deliveries[incoming_key] -= amount
		if incoming_deliveries[incoming_key] <= 0:
			incoming_deliveries.erase(incoming_key)

# ---------- CONSTRUCTION ----------

func _check_completion():
	for item in required_materials:
		var current = current_materials.get(item, 0)
		if current == 0:
			for k in current_materials.keys():
				if k is ItemData and item is ItemData and (k.resource_path == item.resource_path or k.name == item.name):
					current = current_materials[k]
					break
		if current < required_materials[item]:
			return
	_build()

func _build():
	if target_building_scene:
		var real_building = target_building_scene.instantiate()
		real_building.global_position = global_position
		get_parent().add_child(real_building)
		queue_free()
