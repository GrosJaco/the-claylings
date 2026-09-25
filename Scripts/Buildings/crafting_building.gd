extends Building
class_name CraftingBuilding

# ========== VARIABLES ==========

@export_group("Crafting")
@export var available_recipes: Array[RecipeData] = []
@export var max_queue_size: int = 10

@export_group("Fuel Settings")
@export var requires_fuel: bool = false
@export var accepted_fuels: Array[FuelInput] = []

@export_group("Worker")
@export var worker_animation: String = "interacting_up"
@export var worker_sprite_offset: Vector2 = Vector2(0, 0)
@export var worker_hit_sound: String = ""
@export var worker_hit_interval: float = 0.0
@export var worker_flip_h: bool = false

@export_group("UI Settings")
@export var menu_offset: Vector2 = Vector2(0, -5)

var recipe_queue: Array[RecipeData] = []
var repeat_infinite: bool = false
var active_recipe: RecipeData = null

var input_inventory: Dictionary = {}
var output_inventory: Dictionary = {}
var fuel_inventory: Dictionary = {}
var incoming_deliveries: Dictionary = {}

var is_crafting: bool = false
var craft_timer: float = 0.0
var worker_present: bool = false
var current_burn_time: float = 0.0

signal queue_changed

# ========== FUNCTIONS ==========

func _ready():
	super._ready()
	add_to_group("crafting_buildings")
	
	recipe_queue = []
	input_inventory = {}
	output_inventory = {}
	fuel_inventory = {}
	incoming_deliveries = {}
	active_recipe = null

func _process(delta: float):
	if is_preview: return
	
	if is_crafting:
		if active_recipe and active_recipe.need_clayling and not worker_present:
			return 

		if requires_fuel:
			if current_burn_time <= 0.0:
				if not _try_consume_fuel():
					_on_crafting_stopped()
					return 
			current_burn_time -= delta

		craft_timer -= delta
		if craft_timer <= 0.0:
			_finish_crafting()
	else:
		if not recipe_queue.is_empty():
			_try_start_crafting()

# ---------- CRAFTING LOGIC ----------

func _try_start_crafting():
	if recipe_queue.size() > 0:
		active_recipe = recipe_queue[0]
	else:
		active_recipe = null
		is_crafting = false
		_on_crafting_stopped()
		return 

	if not _has_required_inputs(active_recipe):
		return 
		
	if requires_fuel and current_burn_time <= 0.0:
		if not _try_consume_fuel():
			return
		
	_consume_inputs(active_recipe)
	is_crafting = true
	craft_timer = active_recipe.get("craft_time") 
	_on_crafting_started()


func _finish_crafting():
	is_crafting = false
	
	_produce_output(active_recipe)
	
	if not recipe_queue.is_empty():
		var finished_recipe = recipe_queue.pop_front()
		if repeat_infinite:
			recipe_queue.append(finished_recipe)
	
	active_recipe = null 
	
	_on_crafting_stopped() 
	
	if has_signal("queue_changed"):
		emit_signal("queue_changed")
	
	_try_start_crafting()

# ---------- INVENTORY HELPERS ----------

func _has_required_inputs(recipe: RecipeData) -> bool:
	if recipe == null: return false
	
	for item in recipe.inputs:
		var required_amount = recipe.inputs[item]
		if input_inventory.get(item, 0) < required_amount:
			return false
	return true

func _consume_inputs(recipe: RecipeData):
	for item in recipe.inputs:
		var required_amount = recipe.inputs[item]
		input_inventory[item] -= required_amount
		if input_inventory[item] <= 0:
			input_inventory.erase(item)

func _produce_output(recipe: RecipeData):
	var item = recipe.output_item
	var amount = recipe.output_amount
	output_inventory[item] = output_inventory.get(item, 0) + amount

# ---------- FUEL HELPERS ----------

func _has_available_fuel() -> bool:
	for fuel in accepted_fuels:
		if fuel_inventory.get(fuel.item, 0) > 0:
			return true
	return false

func _try_consume_fuel() -> bool:
	for fuel in accepted_fuels:
		if fuel_inventory.get(fuel.item, 0) > 0:
			fuel_inventory[fuel.item] -= 1
			if fuel_inventory[fuel.item] <= 0:
				fuel_inventory.erase(fuel.item)
			
			current_burn_time += fuel.burn_time
			_on_crafting_started() 
			return true
	return false

# ---------- LOGISTICS ----------

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
			
	var is_fuel = false
	for fuel_input in accepted_fuels:
		if fuel_input.item == item:
			fuel_inventory[item] = fuel_inventory.get(item, 0) + amount
			is_fuel = true
			break
			
	if not is_fuel:
		input_inventory[item] = input_inventory.get(item, 0) + amount
	
	if not is_crafting:
		_try_start_crafting()

func cancel_delivery(item: ItemData, amount: int):
	if item == null or amount <= 0:
		return
	var incoming_key = item
	if not incoming_deliveries.has(incoming_key):
		for k in incoming_deliveries.keys():
			if k is ItemData and (k.resource_path == item.resource_path or k.name == item.name):
				incoming_key = k
				break
	if incoming_deliveries.has(incoming_key):
		incoming_deliveries[incoming_key] -= amount
		if incoming_deliveries[incoming_key] <= 0:
			incoming_deliveries.erase(incoming_key)

func get_needed_items() -> Dictionary:
	var needed = {}
	var desired_inputs = {}

	if repeat_infinite and recipe_queue.size() > 0:
		var r = recipe_queue[0]
		for item in r.inputs:
			desired_inputs[item] = r.inputs[item] * 2
	else:
		var start_idx = 1 if is_crafting else 0
		var end_idx = min(start_idx + 2, recipe_queue.size()) 

		for i in range(start_idx, end_idx):
			var r = recipe_queue[i]
			for item in r.inputs:
				desired_inputs[item] = desired_inputs.get(item, 0) + r.inputs[item]

	for item in desired_inputs:
		var incoming = incoming_deliveries.get(item, 0)
		if incoming == 0:
			for k in incoming_deliveries.keys():
				if k is ItemData and item is ItemData and (k.resource_path == item.resource_path or k.name == item.name):
					incoming = incoming_deliveries[k]
					break
		var current_input = input_inventory.get(item, 0)
		if current_input == 0:
			for k in input_inventory.keys():
				if k is ItemData and item is ItemData and (k.resource_path == item.resource_path or k.name == item.name):
					current_input = input_inventory[k]
					break
		var current_amount = current_input + incoming
		if current_amount < desired_inputs[item]:
			needed[item] = desired_inputs[item] - current_amount

	if requires_fuel and accepted_fuels.size() > 0:
		var preferred_fuel = accepted_fuels[0].item
		var current_fuel_amount = fuel_inventory.get(preferred_fuel, 0) + incoming_deliveries.get(preferred_fuel, 0)
		var target_fuel_amount = 5
		
		if current_fuel_amount < target_fuel_amount:
			needed[preferred_fuel] = target_fuel_amount - current_fuel_amount

	return needed

# ---------- VISUAL HOOKS ----------

func _on_crafting_started():
	pass

func _on_crafting_stopped():
	pass

# ---------- INTERACTION ----------

func interact(clayling):
	super.interact(clayling)
	
	if not clayling or not is_instance_valid(clayling):
		return

	var carried_item = clayling.inventory.get("item", null) if "inventory" in clayling else null
	var carried_amount = clayling.inventory.get("count", 0) if "inventory" in clayling else 0

	if carried_item != null and carried_amount > 0:
		var item = carried_item
		var amount = carried_amount
		var item_accepted = false
		
		for fuel_input in accepted_fuels:
			if fuel_input.item == item:
				fuel_inventory[item] = fuel_inventory.get(item, 0) + amount
				item_accepted = true
				break
				
		if not item_accepted and active_recipe and active_recipe.inputs.has(item):
			input_inventory[item] = input_inventory.get(item, 0) + amount
			item_accepted = true
					
		if item_accepted:
			if clayling.has_method("drop_item"):
				clayling.drop_item(amount, false)
			clayling.change_state("Idle")

func take_output() -> Dictionary:
	if output_inventory.is_empty():
		return {}
		
	var item = output_inventory.keys()[0]
	var amount = output_inventory[item]
	
	output_inventory.erase(item)
	
	return {"item": item, "count": amount}
