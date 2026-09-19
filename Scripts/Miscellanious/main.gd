extends Node2D

# ========== REFERENCES ==========
# For BUILDING and CROPS, 16BitDev

@onready var building_manager: Node2D = $BuildingManager
@onready var radial_menu = $BuildingRadialMenu
@onready var rts_controller: RTSController = $RTSController

@onready var ground: TileMapLayer = $Terrain/Ground
@onready var crops: TileMapLayer = $Terrain/Crops
@onready var buildings: TileMapLayer = $Terrain/Buildings

@onready var clayling_scene: PackedScene = preload("res://Scenes/clayling.tscn")
@onready var chicken_scene: PackedScene = preload("res://Scenes/Animals/chicken.tscn")
@onready var blue_spider_scene: PackedScene = preload("res://Scenes/Enemies/BlueSpider.tscn")
@onready var purple_spider_scene: PackedScene = preload("res://Scenes/Enemies/PurpleSpider.tscn")

@onready var zone_scene: PackedScene = preload("res://Scenes/zone.tscn")

@export var item_scene: PackedScene = preload("res://Scenes/item.tscn")
@export var carrot_item: ItemData = preload("res://Resources/Item Resources/Crops & Foods/carrot_item.tres")


# ========== VARIABLES ==========

# ---------- CLAYLINGS ----------

var active_claylings: Array = [] # claylings cache
var assign_cooldown: float = 0.0
const ASSIGN_INTERVAL: float = 0.2

var reserved_harvest: Dictionary = {}
var reserved_water: Dictionary = {}
var reserved_plant: Dictionary = {}
var reserved_pickups: Dictionary = {}
var reserved_trees: Dictionary = {}
var reserved_rocks: Dictionary = {}
var reserved_forages: Dictionary = {}
var reserved_outputs: Dictionary = {}
var reserved_work: Dictionary = {}

# ---------- TASK PRIORITY ----------

var task_quotas: Dictionary = {
	"Haul": 5,
	"Deliver": 5,
	"Construct": 5,
	"CollectOutput": 5,
	"Work": 5,
	"Harvest": 5,
	"Pick up": 5,
	"Chop": 5,
	"Mine": 5,
	"Forage": 5,
	"Plant": 5,
	"Water": 5,
}

# ---------- BUILDINGS ----------

var ghost_preview: Node2D = null
var current_build_data: Dictionary = {}
@export var blueprint_scene: PackedScene

# ---------- CROPS ----------

# Store each crop and their water levels
var water_level : Dictionary
var crops_dic : Dictionary

# Export dictionary for every type of tile/crop
@export var custom_tile : Dictionary[String, TileCustomData]

# ---------- HOVER & HIGHLIGHT ----------

signal hovered_entity_changed(entity: Node2D)

var _outline_shader: Shader = preload("res://Shaders/outline.gdshader")
var _outline_material: ShaderMaterial = null
var _hovered_entity: Node2D = null
var _hovered_sprite: CanvasItem = null
var _previous_material: Material = null
var _last_mouse_pos: Vector2 = Vector2(-99999, -99999)
var _hover_refresh_timer: float = 0.0
var _sprite_cache: Dictionary = {}

# ========== FUNCTIONS ==========

# ---------- CLAYLINGS ----------

func spawn_clayling(pos, mob):
	if mob == "clayling":
		if clayling_scene:
			var clayling = clayling_scene.instantiate()
			clayling.global_position = pos
			add_child(clayling)
			active_claylings.append(clayling)
			return clayling
	if mob == "chicken":
		if chicken_scene:
			var chicken = chicken_scene.instantiate()
			chicken.global_position = pos
			add_child(chicken)
			return chicken
	return null

func spawn_enemy(pos: Vector2, enemy_type: String = "blue_spider") -> void:
	var enemy_scene: PackedScene = null
	if enemy_type == "blue_spider":
		enemy_scene = blue_spider_scene
	elif enemy_type == "purple_spider":
		enemy_scene = purple_spider_scene

	if enemy_scene:
		var enemy = enemy_scene.instantiate()
		enemy.global_position = pos
		add_child(enemy)

func _count_active_states() -> Dictionary:
	var counts: Dictionary = {}
	for c in active_claylings:
		if not is_instance_valid(c):
			continue
		for state_name in c.states:
			if c.current_state == c.states[state_name]:
				counts[state_name] = counts.get(state_name, 0) + 1
				break
	return counts

func _on_quota_changed(task_name: String, value: int) -> void:
	task_quotas[task_name] = value

func assign_tasks_to_claylings():
	_cleanup_reservations()
	_handle_clayling_needs()

	var free_claylings = []
	for clayling in active_claylings:
		if not is_instance_valid(clayling):
			continue
		if clayling.is_combat_ready or clayling.role != "villager":
			continue
		if clayling.current_state == clayling.states["Idle"] or clayling.current_state == clayling.states["Wander"]:
			free_claylings.append(clayling)

	var active_counts = _count_active_states()

	# ---------- HAUL ----------
	var haul_active = active_counts.get("Haul", 0)
	var haul_quota = task_quotas.get("Haul", 999)

	for c in free_claylings.duplicate():
		if haul_active >= haul_quota:
			break
		if c.is_inventory_empty():
			continue
		var nearest_storage = find_nearest_storage_with_space(c.global_position)
		if nearest_storage:
			c.assign_task("Haul", {"storage": nearest_storage})
			free_claylings.erase(c)
			haul_active += 1
		else:
			c.drop_item(-1, true) # drop if no storage

	# ---------- LOGISTICS (DELIVER TO CRAFTING BUILDINGS) ----------
	var crafting_buildings = get_tree().get_nodes_in_group("crafting_buildings")

	var deliver_active = active_counts.get("Deliver", 0)
	var deliver_quota = task_quotas.get("Deliver", 999)

	for b in crafting_buildings:
		if free_claylings.is_empty() or deliver_active >= deliver_quota:
			break
		if b.get("is_preview") or b is Blueprint:
			continue
		if _try_assign_delivery(b, "Deliver", free_claylings):
			deliver_active += 1

	# ---------- CONSTRUCTION (DELIVER TO BLUEPRINTS) ----------
	var construct_active = active_counts.get("Construct", 0)
	var construct_quota = task_quotas.get("Construct", 999)

	var assigned_blueprints: Array = []

	for b in crafting_buildings:
		if free_claylings.is_empty() or construct_active >= construct_quota:
			break
		if not (b is Blueprint):
			continue
		if assigned_blueprints.has(b):
			continue
		if _try_assign_delivery(b, "Construct", free_claylings):
			construct_active += 1
			assigned_blueprints.append(b)

	# ---------- COLLECT OUTPUTS ----------
	var collect_active = active_counts.get("CollectOutput", 0)
	var collect_quota = task_quotas.get("CollectOutput", 999)

	for b in crafting_buildings:
		if free_claylings.is_empty() or collect_active >= collect_quota:
			break
		if b is Blueprint:
			continue
		if b.get("is_preview") or b.output_inventory.is_empty():
			continue
		if reserved_outputs.has(b):
			continue
		if find_nearest_storage_with_space(b.global_position) == null:
			continue

		var chosen = get_nearest_clayling(get_grid_position(b.global_position), free_claylings, true)
		if chosen:
			reserved_outputs[b] = chosen
			chosen.assign_task("CollectOutput", {"building": b})
			free_claylings.erase(chosen)
			collect_active += 1

	# ---------- WORK (ARTISAN) ----------
	var work_active = active_counts.get("Work", 0)
	var work_quota = task_quotas.get("Work", 999)

	for b in crafting_buildings:
		if free_claylings.is_empty() or work_active >= work_quota:
			break
		if b.get("is_preview"):
			continue

		if b.get("is_crafting") and b.get("active_recipe") and b.active_recipe.get("need_clayling"):
			if not b.get("worker_present") and not reserved_work.has(b):
				var chosen = get_nearest_clayling(get_grid_position(b.global_position), free_claylings, true)
				if chosen:
					reserved_work[b] = chosen
					chosen.assign_task("Work", {"building": b})
					free_claylings.erase(chosen)
					work_active += 1

	# ---------- HARVEST ----------
	var harvest_active = active_counts.get("Harvest", 0)
	var harvest_quota = task_quotas.get("Harvest", 999)

	for pos in crops_dic.keys():
		if free_claylings.is_empty() or harvest_active >= harvest_quota:
			break
		if crops.get_cell_source_id(pos) != -1 and crops_dic[pos]["duration"] < 0:
			if reserved_harvest.has(pos):
				continue
			var chosen = get_nearest_clayling(pos, free_claylings, true)
			if chosen:
				reserved_harvest[pos] = chosen
				chosen.assign_task("Harvest", {"pos": pos})
				free_claylings.erase(chosen)
				harvest_active += 1

	# ---------- PICK UP ----------
	var pickup_active = active_counts.get("Pick up", 0)
	var pickup_quota = task_quotas.get("Pick up", 999)

	var ground_items = get_tree().get_nodes_in_group("ground_items")
	for item in ground_items:
		if pickup_active >= pickup_quota:
			break
		if item == null or !is_instance_valid(item):
			continue
		if reserved_pickups.has(item):
			continue
		if item.quantity <= 0:
			continue

		var best = null
		var best_dist = INF
		for c in free_claylings:
			if !c.is_inventory_empty():
				continue
			if find_nearest_storage_with_space(c.global_position) == null:
				continue
			if c._carry_capacity_for(item.data) <= 0:
				continue
			var d = c.global_position.distance_to(item.global_position)
			if d < 250.0 and d < best_dist:
				best_dist = d
				best = c

		if best:
			reserved_pickups[item] = best
			best.assign_task("Pick up", {"node": item})
			free_claylings.erase(best)
			pickup_active += 1
			if free_claylings.is_empty():
				break

	# ---------- CHOP TREES ----------
	var chop_active = active_counts.get("Chop", 0)
	var chop_quota = task_quotas.get("Chop", 999)

	var trees = get_tree().get_nodes_in_group("trees")
	for tree in trees:
		if free_claylings.is_empty() or chop_active >= chop_quota:
			break
		if not is_instance_valid(tree) or tree.is_in_group("saplings"):
			continue
		if not tree.get("is_marked_for_harvest"):
			continue
		if reserved_trees.has(tree):
			continue

		var chosen = get_nearest_clayling(get_grid_position(tree.global_position), free_claylings)
		if chosen:
			reserved_trees[tree] = chosen
			chosen.assign_task("Chop", {"target": tree})
			free_claylings.erase(chosen)
			chop_active += 1

	# ---------- MINE ROCKS & ORES ----------
	var mine_active = active_counts.get("Mine", 0)
	var mine_quota = task_quotas.get("Mine", 999)

	var rocks_and_ores = get_tree().get_nodes_in_group("rocks") + get_tree().get_nodes_in_group("ores")
	for rock in rocks_and_ores:
		if free_claylings.is_empty() or mine_active >= mine_quota:
			break
		if not is_instance_valid(rock):
			continue
		if not rock.get("is_marked_for_harvest"):
			continue
		if reserved_rocks.has(rock):
			continue

		var chosen = get_nearest_clayling(get_grid_position(rock.global_position), free_claylings)
		if chosen:
			reserved_rocks[rock] = chosen
			chosen.assign_task("Mine", {"target": rock})
			free_claylings.erase(chosen)
			mine_active += 1

	# ---------- FORAGE PLANTS ----------
	var forage_active = active_counts.get("Forage", 0)
	var forage_quota = task_quotas.get("Forage", 999)

	var wild_plants = get_tree().get_nodes_in_group("plants")
	for plant in wild_plants:
		if free_claylings.is_empty() or forage_active >= forage_quota:
			break
		if not is_instance_valid(plant):
			continue
		if not plant.get("is_marked_for_harvest"):
			continue
		if reserved_forages.has(plant):
			continue

		var chosen = get_nearest_clayling(get_grid_position(plant.global_position), free_claylings)
		if chosen:
			reserved_forages[plant] = chosen
			chosen.assign_task("Forage", {"target": plant})
			free_claylings.erase(chosen)
			forage_active += 1

	# ---------- PLANT ----------
	var plant_active = active_counts.get("Plant", 0)
	var plant_quota = task_quotas.get("Plant", 999)

	for pos in water_level.keys():
		if free_claylings.is_empty() or plant_active >= plant_quota:
			break
		if water_level[pos] > 1.0 and not crops_dic.has(pos):
			if reserved_plant.has(pos):
				continue
			var chosen = get_nearest_clayling(pos, free_claylings, true)
			if chosen:
				reserved_plant[pos] = chosen
				chosen.assign_task("Plant", {"pos": pos})
				free_claylings.erase(chosen)
				plant_active += 1

	# ---------- WATER ----------
	var water_task_active = active_counts.get("Water", 0)
	var water_task_quota = task_quotas.get("Water", 999)

	for pos in water_level.keys():
		if free_claylings.is_empty() or water_task_active >= water_task_quota:
			break
		if water_level[pos] < 5.0:
			if reserved_water.has(pos):
				continue
			var chosen = get_nearest_clayling(pos, free_claylings, true)
			if chosen:
				reserved_water[pos] = chosen
				chosen.assign_task("Water", {"pos": pos})
				free_claylings.erase(chosen)
				water_task_active += 1

# ---------- SURVIVAL ----------

func _handle_clayling_needs():
	for c in active_claylings:
		if not is_instance_valid(c):
			continue
		if c.is_combat_ready or c.role != "villager":
			continue
		if c.states.has("Eat") and c.current_state == c.states["Eat"]:
			continue
		if c.hunger < 25.0:
			var food_data = _find_available_food()
			if food_data != null:
				c.assign_task("Eat", {
					"storage": food_data["storage"],
					"food": food_data["item"]
				})

func _find_available_food():
	var storages = get_tree().get_nodes_in_group("storage")
	for s in storages:
		if s.get("is_preview"): continue

		for item in s.inventory:
			if s.inventory[item] > 0:
				var cat = item.category if "category" in item else ""
				if cat == "Consommables" or "food" in item.resource_path.to_lower() or "crop" in item.resource_path.to_lower():
					return {"storage": s, "item": item}
	return null

# ---------- LOGISTICS ----------

func _try_assign_delivery(b: Node, task_name: String, free_claylings: Array) -> bool:
	var needs = b.get_needed_items() if b.has_method("get_needed_items") else {}

	for item in needs.keys():
		var amount_needed = needs[item]
		if amount_needed <= 0:
			continue

		# ---------- 1. TRY STORAGE FIRST ----------
		var best_storage = null
		var available_in_storage = 0

		for s in get_tree().get_nodes_in_group("storage"):
			if s.get("is_preview"):
				continue
			var stored = s.inventory.get(item, 0)
			if stored > 0:
				best_storage = s
				available_in_storage = stored
				break

		var chosen = get_nearest_clayling(get_grid_position(b.global_position), free_claylings, true)
		if not chosen:
			continue

		var amount_to_take = min(amount_needed, available_in_storage)
		if chosen.has_method("_carry_capacity_for"):
			amount_to_take = min(amount_to_take, chosen._carry_capacity_for(item))

		if amount_to_take > 0:
			b.incoming_deliveries[item] = b.incoming_deliveries.get(item, 0) + amount_to_take
			chosen.assign_task(task_name, {
				"building": b,
				"storage": best_storage,
				"item": item,
				"amount": amount_to_take
			})
			free_claylings.erase(chosen)
			return true

		# ---------- 2. FALLBACK: CHECK GROUND ITEMS (FOR BLUEPRINTS) ----------
		if task_name == "Construct" and amount_to_take <= 0:
			var ground_item = _find_ground_item(item, amount_needed, chosen.global_position)
			if ground_item:
				var take_amount = min(amount_needed, ground_item.quantity)
				if chosen.has_method("_carry_capacity_for"):
					take_amount = min(take_amount, chosen._carry_capacity_for(item))

				if take_amount > 0:
					b.incoming_deliveries[item] = b.incoming_deliveries.get(item, 0) + take_amount
					chosen.assign_task("ConstructDelivery", {
						"building": b,
						"ground_item": ground_item,
						"item": item,
						"amount": take_amount
					})
					free_claylings.erase(chosen)
					return true

	return false

func _find_ground_item(item_type: ItemData, amount_needed: int, from_pos: Vector2) -> Node:
	var best_item = null
	var best_dist = INF

	for ground_item in get_tree().get_nodes_in_group("ground_items"):
		if ground_item == null or !is_instance_valid(ground_item):
			continue
		if ground_item.data != item_type:
			continue
		if reserved_pickups.has(ground_item):
			continue
		if ground_item.quantity <= 0:
			continue

		var dist = ground_item.global_position.distance_to(from_pos)
		if dist < best_dist:
			best_dist = dist
			best_item = ground_item

	return best_item

func get_nearest_clayling(pos: Vector2i, candidates: Array, require_empty: bool=false) -> Node:
	var world_pos = get_world_position(pos)
	var nearest = null
	var best_dist = INF
	for clayling in candidates:
		if require_empty and not clayling.is_inventory_empty():
			continue
		var d = clayling.global_position.distance_to(world_pos)
		if d < best_dist:
			best_dist = d
			nearest = clayling
	return nearest

func _get_nearest_node(target_pos: Vector2, node_list: Array) -> Node:
	var nearest = null
	var min_dist = INF
	for node in node_list:
		var d = node.global_position.distance_to(target_pos)
		if d < min_dist:
			min_dist = d
			nearest = node
	return nearest

func _cleanup_reservations():
	for pos in reserved_harvest.keys().duplicate():
		var c = reserved_harvest[pos]
		if c == null or !is_instance_valid(c) or c.is_combat_ready or c.current_state in [c.states["Idle"], c.states["Wander"], c.states.get("Flee"), c.states.get("Equip")]:
			reserved_harvest.erase(pos)

	for pos in reserved_water.keys().duplicate():
		var c = reserved_water[pos]
		if c == null or !is_instance_valid(c) or c.is_combat_ready or c.current_state in [c.states["Idle"], c.states["Wander"], c.states.get("Flee"), c.states.get("Equip")]:
			reserved_water.erase(pos)

	for pos in reserved_plant.keys().duplicate():
		var c = reserved_plant[pos]
		if c == null or !is_instance_valid(c) or c.is_combat_ready or c.current_state in [c.states["Idle"], c.states["Wander"], c.states.get("Flee"), c.states.get("Equip")]:
			reserved_plant.erase(pos)

	for item in reserved_pickups.keys().duplicate():
		var c = reserved_pickups[item]
		if item == null or !is_instance_valid(item) or c == null or !is_instance_valid(c) or c.is_combat_ready or c.current_state in [c.states["Idle"], c.states["Wander"], c.states.get("Flee"), c.states.get("Equip")]:
			reserved_pickups.erase(item)

	for tree in reserved_trees.keys().duplicate():
		var c = reserved_trees[tree]
		if tree == null or !is_instance_valid(tree) or c == null or !is_instance_valid(c) or c.is_combat_ready or c.current_state in [c.states["Idle"], c.states["Wander"], c.states.get("Flee"), c.states.get("Equip")]:
			reserved_trees.erase(tree)

	for rock in reserved_rocks.keys().duplicate():
		var c = reserved_rocks[rock]
		if rock == null or !is_instance_valid(rock) or c == null or !is_instance_valid(c) or c.is_combat_ready or c.current_state in [c.states["Idle"], c.states["Wander"], c.states.get("Flee"), c.states.get("Equip")]:
			reserved_rocks.erase(rock)

	for plant in reserved_forages.keys().duplicate():
		var c = reserved_forages[plant]
		if plant == null or !is_instance_valid(plant) or c == null or !is_instance_valid(c) or c.is_combat_ready or c.current_state in [c.states["Idle"], c.states["Wander"], c.states.get("Flee"), c.states.get("Equip")]:
			reserved_forages.erase(plant)

	for b in reserved_outputs.keys().duplicate():
		var c = reserved_outputs[b]
		if b == null or !is_instance_valid(b) or c == null or !is_instance_valid(c) or c.is_combat_ready or c.current_state in [c.states["Idle"], c.states["Wander"], c.states.get("Flee"), c.states.get("Equip")]:
			reserved_outputs.erase(b)

	for b in reserved_work.keys().duplicate():
		var c = reserved_work[b]
		if b == null or !is_instance_valid(b) or c == null or !is_instance_valid(c) or c.is_combat_ready or c.current_state in [c.states["Idle"], c.states["Wander"], c.states.get("Flee"), c.states.get("Equip")]:
			reserved_work.erase(b)

func reserve_pickup(item: Node, c: Node) -> bool:
	if item == null or !is_instance_valid(item):
		return false
	if reserved_pickups.has(item):
		return false
	reserved_pickups[item] = c
	return true

func release_pickup(item: Node) -> void:
	if reserved_pickups.has(item):
		reserved_pickups.erase(item)

func find_nearest_storage_with_space(pos: Vector2) -> StorageBuilding:
	var nearest: StorageBuilding = null
	var nearest_d = INF
	for s in get_tree().get_nodes_in_group("storage"):
		if not is_instance_valid(s):
			continue
		if s.is_preview:
			continue
		if s.is_full():
			continue
		var d = pos.distance_to(s.global_position)
		if d < nearest_d:
			nearest = s
			nearest_d = d
	return nearest


# ---------- COMBAT LOGIC (Call to Arms & Call to Work) ----------

func trigger_call_to_arms() -> void:
	if rts_controller:
		rts_controller.trigger_call_to_arms()

func trigger_call_to_work() -> void:
	if rts_controller:
		rts_controller.trigger_call_to_work()


# ---------- CROPS ----------

func set_tile(tile_name: String, cell_pos: Vector2i, layer : TileMapLayer, coord : int = 0):
	if custom_tile.has(tile_name):
		layer.set_cell(cell_pos, custom_tile[tile_name].source_id, custom_tile[tile_name].atlas_coords[coord])

func watering_tile(tile_name : String, pos : Vector2i, amount : float = 1.0):
	if ground.get_cell_tile_data(pos).get_custom_data("tile_name") == "soil":
		water_level[pos] = amount
		set_tile(tile_name, pos, ground, 1)
		reserved_water.erase(pos)

func drying_tile(pos):
	var data = ground.get_cell_tile_data(pos)
	var tile_name
	if data:
		tile_name = data.get_custom_data("tile_name")
		set_tile(tile_name, pos, ground)

func harvesting(pos):
	if crops.get_cell_source_id(pos) != -1 and crops_dic.has(pos) and crops_dic[pos]["duration"] < 0:
		crops.erase_cell(pos)

		var crop_name = crops_dic[pos]["name"]
		var tile_crop_data = custom_tile[crop_name]
		var quantity = 1
		var harvested_item = crop_name

		if tile_crop_data is CropData and tile_crop_data.harvest_item:
			quantity = randi_range(tile_crop_data.harvest_min, tile_crop_data.harvest_max)
			harvested_item = tile_crop_data.harvest_item
			drop_item(harvested_item, quantity, pos)

		crops_dic.erase(pos)
		reserved_harvest.erase(pos)
		return {"item": harvested_item, "count": quantity}

	return null

func planting(pos):
	set_tile("carrot", pos, crops)
	crops_dic[pos] = {
		"name" : "carrot",
		"duration" : 0
	}

# --------- ITEM MANAGMENT ----------

func drop_item(data: ItemData, quantity: int, grid_pos: Vector2i) -> void:
	if !item_scene or !data:
		return

	var world_pos = get_world_position(grid_pos) + Vector2(8, 8) + Vector2(randi_range(-3,3), randi_range(-3,3))
	var remainder = quantity

	for child in get_tree().get_nodes_in_group("ground_items"):
		if child.data == data and child.global_position.distance_to(world_pos) < 12.0:
			remainder = child.add_quantity(remainder)
			if remainder <= 0:
				return

	while remainder > 0:
		var inst: WorldItem = item_scene.instantiate()
		inst.data = data
		var stack = max(1, data.stack_size)
		var take = min(remainder, stack)
		inst.quantity = take
		inst.position = world_pos + Vector2(randi_range(-3,3), randi_range(-3,3))
		add_child(inst)
		remainder -= take

# ---------- BUILDINGS ----------

func _on_build_menu_start_building(data):
	building_manager.start_preview(data["scene"], data["cost"])

# ---------- GENERAL ----------

func _ready():
	add_to_group("main")

	if _outline_shader:
		_outline_material = ShaderMaterial.new()
		_outline_material.shader = _outline_shader
		_outline_material.set_shader_parameter("line_color", Color(1.0, 1.0, 1.0, 1.0))
		_outline_material.set_shader_parameter("line_thickness", 1.0)

	var build_menu = get_node_or_null("CanvasLayer/BuildMenu")
	if build_menu:
		build_menu.start_building.connect(_on_build_menu_start_building)

	var plant_menu = get_node_or_null("CanvasLayer/PlantMenu")
	if plant_menu:
		plant_menu.start_building.connect(_on_build_menu_start_building)

	var task_menu = get_node_or_null("CanvasLayer/TaskPriorityMenu")
	if task_menu:
		task_menu.quota_changed.connect(_on_quota_changed)

	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("has_pending_load") and save_mgr.has_pending_load():
		save_mgr.apply_pending_load(self)


func get_active_clayling_count() -> int:
	var count = 0
	for c in active_claylings:
		if is_instance_valid(c):
			count += 1
	return count

func debug_all_claylings_to_spearmen() -> void:
	var claylings = get_tree().get_nodes_in_group("claylings")
	var count = 0
	for c in claylings:
		if is_instance_valid(c) and not c.is_dead and c.has_method("debug_become_spearman"):
			c.debug_become_spearman()
			count += 1
	print("[DevMode] Equipped %d clayling(s) as spearmen." % count)

func debug_kill_all_claylings() -> void:
	var claylings = get_tree().get_nodes_in_group("claylings")
	for c in claylings:
		if is_instance_valid(c) and c.has_method("die"):
			c.die()

func debug_kill_all_chickens() -> void:
	var chickens = get_tree().get_nodes_in_group("animals")
	for ch in chickens:
		if is_instance_valid(ch) and ch.has_method("die"):
			ch.die()

func debug_trigger_next_wave() -> void:
	var wm = get_tree().get_first_node_in_group("wave_manager")
	if wm and wm.has_method("trigger_next_wave"):
		wm.trigger_next_wave()

func create_harvest_zone() -> void:
	for z in get_tree().get_nodes_in_group("harvest_zones"):
		if is_instance_valid(z) and z.get("is_placing"):
			z.queue_free()
			return

	if zone_scene:
		var zone = zone_scene.instantiate()
		zone.global_position = get_global_mouse_position()
		add_child(zone)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var is_dev = Global.dev_mode if ("dev_mode" in Global) else false
		if is_dev:
			var is_j = event.keycode == KEY_J or event.physical_keycode == KEY_J or event.key_label == KEY_J
			var is_ctrl_s = (event.keycode == KEY_S or event.physical_keycode == KEY_S or event.key_label == KEY_S) and event.ctrl_pressed
			if is_j or is_ctrl_s:
				debug_all_claylings_to_spearmen()
				get_viewport().set_input_as_handled()
				return

		if event.keycode == KEY_C:
			spawn_clayling(get_global_mouse_position(), "clayling")
		if event.keycode == KEY_P:
			spawn_clayling(get_global_mouse_position(), "chicken")
		if event.keycode == KEY_O:
			debug_kill_all_chickens()
		if event.keycode == KEY_M:
			create_harvest_zone()
		if event.keycode == KEY_Y:
			get_tree().call_group("weapon_racks", "debug_fill_random_kit")
		if event.keycode == KEY_K:
			debug_kill_all_claylings()
		if event.keycode == KEY_N:
			spawn_enemy(get_global_mouse_position(), "blue_spider")
		if event.keycode == KEY_V:
			spawn_enemy(get_global_mouse_position(), "purple_spider")
		if event.keycode == KEY_L:
			debug_trigger_next_wave()

var _tab_clayling_index: int = -1

func cycle_next_clayling(reverse: bool = false) -> void:
	var valid_claylings: Array[CharacterBody2D] = []
	for c in active_claylings:
		if is_instance_valid(c) and not c.is_dead:
			valid_claylings.append(c)

	if valid_claylings.is_empty():
		return

	if reverse:
		_tab_clayling_index -= 1
		if _tab_clayling_index < 0:
			_tab_clayling_index = valid_claylings.size() - 1
	else:
		_tab_clayling_index = (_tab_clayling_index + 1) % valid_claylings.size()

	var chosen = valid_claylings[_tab_clayling_index]

	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("focus_on_position"):
		camera.focus_on_position(chosen.global_position)

	var clayling_ui = get_tree().get_first_node_in_group("clayling_info_panel")
	if clayling_ui and clayling_ui.has_method("show_clayling"):
		clayling_ui.show_clayling(chosen)

	for c in valid_claylings:
		c.set_selected(c == chosen)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			cycle_next_clayling(event.shift_pressed)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if building_manager and building_manager.is_mandatory_placement:
			return
		var defeat = get_tree().get_first_node_in_group("defeat_ui")
		if defeat and defeat.get("_is_active"):
			return

		var mouse_pos = get_global_mouse_position()

		# Check clicked regular villager (only if no soldier was clicked)
		var clicked_villager = null
		for c in active_claylings:
			if is_instance_valid(c) and not c.is_dead and not c.is_combat_ready and c.global_position.distance_to(mouse_pos) < 18.0:
				clicked_villager = c
				break

		if clicked_villager:
			var clayling_ui = get_tree().get_first_node_in_group("clayling_info_panel")
			if clayling_ui and clayling_ui.has_method("show_clayling"):
				clayling_ui.show_clayling(clicked_villager)
			get_viewport().set_input_as_handled()
			return

		# Check building interaction / radial menu
		if radial_menu.visible and radial_menu.is_mouse_over_menu():
			return

		var is_placing_zone = false
		for zone in get_tree().get_nodes_in_group("harvest_zones"):
			if zone.is_placing: is_placing_zone = true

		if not is_placing_zone:
			var clicked_building = null
			for b in get_tree().get_nodes_in_group("crafting_buildings"):
				if not b.is_preview and b.global_position.distance_to(mouse_pos) < 20.0:
					clicked_building = b
					break

			if clicked_building and clicked_building is not Blueprint:
				radial_menu.open(clicked_building)
				get_viewport().set_input_as_handled()
			else:
				if radial_menu.visible:
					radial_menu.hide()

func get_grid_position(global_pos: Vector2) -> Vector2i:
	var local_pos = buildings.to_local(global_pos)
	var tile_pos = buildings.local_to_map(local_pos)
	return tile_pos

func get_world_position(pos: Vector2i) -> Vector2:
	var global_pos = Vector2(pos.x * 16, pos.y * 16)
	return global_pos

func _physics_process(delta: float) -> void:
	assign_cooldown -= delta
	if assign_cooldown <= 0.0:
		assign_tasks_to_claylings()
		assign_cooldown = ASSIGN_INTERVAL

	for pos in water_level.keys():
		var i = randi_range(1, 2)
		if i == 1:
			water_level[pos] = max(water_level[pos] - delta, 0)
			if water_level[pos] <= 0:
				drying_tile(pos)

	for pos in crops_dic.keys():
		var i = randi_range(1, 2)
		if water_level.get(pos, 0) > 0 and i == 1:
			crops_dic[pos]["duration"] += delta
			var duration = crops_dic[pos]["duration"]
			var crop_name = crops_dic[pos]["name"]
			if duration >= custom_tile[crop_name].duration:
				set_tile(crop_name, pos, crops, custom_tile[crop_name].atlas_coords.size() - 1)
				crops_dic[pos]["duration"] = -INF
			elif duration > 0:
				var index = custom_tile[crop_name].growth_index(duration)
				set_tile(crop_name, pos, crops, index)

func _process(delta: float) -> void:
	_hover_refresh_timer += delta
	var mouse_pos = get_global_mouse_position()
	if mouse_pos != _last_mouse_pos or _hover_refresh_timer >= 0.1:
		_hover_refresh_timer = 0.0
		_last_mouse_pos = mouse_pos
		_update_hover()

func _exit_tree() -> void:
	_clear_hover()

# ---------- HOVER & HIGHLIGHT LOGIC (LIVING ENTITIES & GROUND ITEMS) ----------

func get_hovered_entity() -> Node2D:
	if is_instance_valid(_hovered_entity):
		return _hovered_entity
	return null

func get_entity_info(node: Node2D) -> Dictionary:
	if not is_instance_valid(node):
		return {}
	var entity_name := "Unknown"
	if node is CharacterBody2D and node.is_in_group("claylings"):
		entity_name = node.get("clayling_name") if node.get("clayling_name") else "Clayling"
	elif node.is_in_group("threats") or node.is_in_group("enemies"):
		entity_name = node.get("enemy_name") if node.get("enemy_name") else node.name
	elif node.is_in_group("chicken") or node is Animal:
		entity_name = "Chicken"
	elif node is WorldItem:
		var item_data: ItemData = node.data
		if item_data:
			entity_name = item_data.display_name if (item_data.display_name and not item_data.display_name.is_empty()) else item_data.name
		else:
			entity_name = "Item"
	else:
		entity_name = node.name
	return {"name": entity_name}

func _is_mouse_over_ui() -> bool:
	var ctrl = get_viewport().gui_get_hovered_control()
	if ctrl != null:
		var tooltip = get_tree().get_first_node_in_group("world_tooltip")
		if tooltip and (ctrl == tooltip or tooltip.is_ancestor_of(ctrl)):
			return false
		return true
	if radial_menu and radial_menu.visible and radial_menu.is_mouse_over_menu():
		return true
	return false

func _is_hover_suppressed() -> bool:
	if _is_mouse_over_ui():
		return true
	if building_manager and (building_manager.is_previewing or building_manager.is_mandatory_placement):
		return true
	if rts_controller and (rts_controller.is_box_selecting or rts_controller.is_line_drawing):
		return true
	var defeat = get_tree().get_first_node_in_group("defeat_ui")
	if defeat and defeat.get("_is_active"):
		return true
	for z in get_tree().get_nodes_in_group("harvest_zones"):
		if is_instance_valid(z) and z.get("is_placing"):
			return true
	return false

func _get_entity_sprite(node: Node) -> CanvasItem:
	if not is_instance_valid(node):
		return null
	var cached = _sprite_cache.get(node)
	if cached != null:
		if is_instance_valid(cached):
			return cached
		_sprite_cache.erase(node)

	var sprite: CanvasItem = null
	if node.has_node("Pivot/AnimatedSprite2D"):
		sprite = node.get_node("Pivot/AnimatedSprite2D") as CanvasItem
	elif node.has_node("Sprite2D"):
		sprite = node.get_node("Sprite2D") as CanvasItem
	elif "sprite" in node and node.sprite is CanvasItem:
		sprite = node.sprite

	if sprite:
		_sprite_cache[node] = sprite
	return sprite

func _is_point_in_entity(node: Node2D, mouse_world_pos: Vector2) -> bool:
	if not is_instance_valid(node) or not node.is_inside_tree() or not node.visible:
		return false
	if node is CharacterBody2D:
		var visual_center = node.global_position + Vector2(0, -6)
		return visual_center.distance_squared_to(mouse_world_pos) <= 144.0
	elif node is WorldItem:
		return node.global_position.distance_squared_to(mouse_world_pos) <= 100.0
	return node.global_position.distance_squared_to(mouse_world_pos) <= 144.0

func _clear_hover() -> void:
	if _hovered_sprite != null and is_instance_valid(_hovered_sprite):
		_hovered_sprite.material = _previous_material
	var had_hover = _hovered_entity != null
	_hovered_entity = null
	_hovered_sprite = null
	_previous_material = null
	if had_hover:
		hovered_entity_changed.emit(null)

func _set_hovered_entity(entity: Node2D) -> void:
	if _hovered_entity == entity and is_instance_valid(_hovered_entity):
		return

	_clear_hover()

	if entity == null or not is_instance_valid(entity):
		return

	var sprite = _get_entity_sprite(entity)
	if sprite == null:
		return

	_hovered_entity = entity
	_hovered_sprite = sprite
	_previous_material = sprite.material
	sprite.material = _outline_material
	hovered_entity_changed.emit(_hovered_entity)

func _update_hover() -> void:
	if _is_hover_suppressed():
		_clear_hover()
		return

	var mouse_pos = _last_mouse_pos
	var chosen_entity: Node2D = null

	# Priority 1: Living entities (Claylings, threats/enemies, chickens)
	var hit_characters: Array = []
	for c in active_claylings:
		if is_instance_valid(c) and not c.get("is_dead"):
			if _is_point_in_entity(c, mouse_pos):
				hit_characters.append(c)

	if hit_characters.is_empty():
		for ch in get_tree().get_nodes_in_group("threats"):
			if is_instance_valid(ch) and not ch.get("is_dead"):
				if _is_point_in_entity(ch, mouse_pos):
					hit_characters.append(ch)

	if hit_characters.is_empty():
		for ch in get_tree().get_nodes_in_group("chicken"):
			if is_instance_valid(ch):
				if _is_point_in_entity(ch, mouse_pos):
					hit_characters.append(ch)

	if not hit_characters.is_empty():
		if hit_characters.size() > 1:
			hit_characters.sort_custom(func(a, b): return a.global_position.y > b.global_position.y)
		chosen_entity = hit_characters[0]

	# Priority 2: Ground items
	if chosen_entity == null:
		var ground_items = get_tree().get_nodes_in_group("ground_items")
		var hit_items: Array = []
		for item in ground_items:
			if is_instance_valid(item) and item.quantity > 0:
				if _is_point_in_entity(item, mouse_pos):
					hit_items.append(item)

		if not hit_items.is_empty():
			if hit_items.size() > 1:
				hit_items.sort_custom(func(a, b): return a.global_position.distance_squared_to(mouse_pos) < b.global_position.distance_squared_to(mouse_pos))
			chosen_entity = hit_items[0]

	_set_hovered_entity(chosen_entity)
