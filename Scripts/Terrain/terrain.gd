@tool
extends Node

# ========== REFERENCES ==========

@onready var world: Node2D = $".."
@onready var ground: TileMapLayer = $Ground
@onready var buildings: TileMapLayer = $Buildings
@onready var building_manager: Node2D = $"../BuildingManager"

# ========== RESOURCES (SCENES) ==========

@export_group("Resources Scenes")
@export var tree_scenes: Array[PackedScene] = [] 
@export var bush_scenes: Array[PackedScene] = []

@export_subgroup("Ores & Rocks")
@export var rock_scenes: Array[PackedScene] = []   
@export var copper_scenes: Array[PackedScene] = [] 
@export var iron_scenes: Array[PackedScene] = []   
@export var gold_scenes: Array[PackedScene] = []   

# ========== SETTINGS ==========

@export_group("Generation Settings")
@export var terrain_seed: int = 0
@export var map_size: Vector2i = Vector2i(128, 128)
const TILE_SIZE: int = 16 

@export_subgroup("Structure Thresholds")
@export var walls_threshold: float = 0.45 
@export var water_threshold: float = -0.45

@export_subgroup("Ore Generation (Groups)")
@export var rock_patches: int = 15
@export var rock_patch_size: int = 40
@export var rock_fill: float = 0.60

@export var copper_patches: int = 8
@export var copper_patch_size: int = 25
@export var copper_fill: float = 0.50

@export var iron_patches: int = 6
@export var iron_patch_size: int = 5
@export var iron_fill: float = 0.40

@export var gold_patches: int = 3
@export var gold_patch_size: int = 8
@export var gold_fill: float = 0.30

@export_subgroup("Vegetation")
@export var forest_threshold: float = 0.2
@export var forest_density: float = 0.40

@export var grass_threshold: float = 0.25
@export var grass_density: float = 0.60

@export_subgroup("TileSet IDs")
@export var water_terrain_set: int = 0 
@export var water_terrain_id: int = 0 
@export var wall_terrain_set: int = 0
@export var wall_terrain_id: int = 0

# ========== INTERNAL VARIABLES ==========

var ground_pool := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)]
var rng = RandomNumberGenerator.new()

var noise_elevation = FastNoiseLite.new()
var noise_forest = FastNoiseLite.new()
var noise_grass = FastNoiseLite.new()

var wall_cells: Array[Vector2i] = []
var water_cells: Array[Vector2i] = []
var ore_map: Dictionary = {} 

# ========== FUNCTIONS ==========

func _ready():
	if Engine.is_editor_hint():
		return
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("has_pending_load") and save_mgr.has_pending_load():
		return
	if terrain_seed == 0:
		terrain_seed = randi()
	rng.seed = terrain_seed
	setup_noise()
	generate_terrain(true)

func setup_noise():
	rng.seed = terrain_seed
	noise_elevation.seed = terrain_seed
	noise_elevation.noise_type = FastNoiseLite.TYPE_PERLIN
	noise_elevation.frequency = 0.03

	noise_forest.seed = terrain_seed + 100
	noise_forest.noise_type = FastNoiseLite.TYPE_PERLIN
	noise_forest.frequency = 0.04 

	noise_grass.seed = terrain_seed + 50
	noise_grass.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_grass.fractal_type = FastNoiseLite.FRACTAL_NONE
	noise_grass.frequency = 0.1 

func clearing_terrain():
	ground.clear()
	buildings.clear()
	wall_cells.clear()
	water_cells.clear()
	ore_map.clear()
	
	if building_manager:
		building_manager.used_tiles.clear()
		
	if is_inside_tree():
		for node in get_tree().get_nodes_in_group("generated"):
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				if node.get_parent():
					node.get_parent().remove_child(node)
				node.queue_free()
	elif world:
		for child in world.get_children():
			if child.is_in_group("generated"):
				world.remove_child(child)
				child.queue_free()

func generate_terrain(generate_objects: bool = true):
	clearing_terrain()
	rng.seed = terrain_seed
	setup_noise()
	if generate_objects:
		generate_all_ore_patches()

	for x in range(map_size.x):
		for y in range(map_size.y):
			var pos = Vector2i(x, y)
			var elev = noise_elevation.get_noise_2d(x, y)
			
			if elev < water_threshold:
				water_cells.append(pos)
				if building_manager: building_manager.used_tiles.append(pos)
				continue
			if elev > walls_threshold:
				wall_cells.append(pos)
				if building_manager: building_manager.used_tiles.append(pos)
				ground.set_cell(pos, 0, Vector2i(7,0))
				continue
				
			ground.set_cell(pos, 0, ground_pool[rng.randi() % ground_pool.size()])
			
			if not generate_objects:
				continue
			
			if building_manager and pos in building_manager.used_tiles:
				continue
			
			if ore_map.has(pos):
				var ore_data = ore_map[pos]
				if rng.randf() < ore_data["fill"]:
					spawn_object(ore_data["scenes"], pos)
				continue 
			
			try_spawn_vegetation(pos)
	
	update_terrain_texture()

func update_terrain_texture():
	if wall_cells.size() > 0:
		buildings.set_cells_terrain_connect(wall_cells, wall_terrain_set, wall_terrain_id, true)
	if water_cells.size() > 0:
		ground.set_cells_terrain_connect(water_cells, water_terrain_set, water_terrain_id, true)

func generate_all_ore_patches():
	if rock_scenes.size() > 0:   create_patches(rock_scenes, rock_patches, rock_patch_size, rock_fill)
	if copper_scenes.size() > 0: create_patches(copper_scenes, copper_patches, copper_patch_size, copper_fill)
	if iron_scenes.size() > 0:   create_patches(iron_scenes, iron_patches, iron_patch_size, iron_fill)
	if gold_scenes.size() > 0:   create_patches(gold_scenes, gold_patches, gold_patch_size, gold_fill)

func create_patches(scenes: Array[PackedScene], count: int, target_size: int, fill_rate: float):
	var dirs = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	for i in range(count):
		var start_pos = Vector2i(rng.randi_range(2, map_size.x - 3), rng.randi_range(2, map_size.y - 3))
		var patch_cells = [start_pos]
		ore_map[start_pos] = {"scenes": scenes, "fill": fill_rate}
		
		var current_size = 1
		var max_attempts = target_size * 5
		var attempts = 0
		
		while current_size < target_size and attempts < max_attempts:
			attempts += 1
			var base_cell = patch_cells[rng.randi() % patch_cells.size()]
			var new_cell = base_cell + dirs[rng.randi() % dirs.size()]
			
			if new_cell.x > 0 and new_cell.x < map_size.x and new_cell.y > 0 and new_cell.y < map_size.y:
				if not ore_map.has(new_cell):
					patch_cells.append(new_cell)
					ore_map[new_cell] = {"scenes": scenes, "fill": fill_rate}
					current_size += 1

func try_spawn_vegetation(pos: Vector2i):
	var forest_val = noise_forest.get_noise_2d(pos.x, pos.y)
	if forest_val > forest_threshold:
		if rng.randf() < forest_density: 
			spawn_object(tree_scenes, pos)
			return 
			
	var grass_val = noise_grass.get_noise_2d(pos.x, pos.y)
	if grass_val > grass_threshold:
		if rng.randf() < grass_density:
			spawn_object(bush_scenes, pos, true) 

func spawn_object(scene_list: Array[PackedScene], grid_pos: Vector2i, is_grass: bool = false):
	if scene_list.is_empty(): return
	
	var instance = scene_list[rng.randi() % scene_list.size()].instantiate()
	var pixel_pos = Vector2(grid_pos.x * TILE_SIZE, grid_pos.y * TILE_SIZE)
	
	if is_grass:
		var random_offset = Vector2(rng.randf_range(4, 12), rng.randf_range(4, 12))
		instance.global_position = pixel_pos + random_offset
	else:
		instance.global_position = pixel_pos + Vector2(8, 16)
	
	instance.add_to_group("generated")
	if world.is_node_ready():
		world.add_child(instance)
	else:
		world.call_deferred("add_child", instance)
	
	if not is_grass and building_manager:
		building_manager.used_tiles.append(grid_pos)
