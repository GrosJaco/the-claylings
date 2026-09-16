extends Node2D

# ========== SIGNALS ==========

signal initial_crystal_placed(crystal_node: Node2D)

# ========== REFERENCES ==========

@onready var world: Node2D = $".."
@export var blueprint_scene: PackedScene

# ========== VARIABLES ==========

const TILE := 16

var used_tiles: Array[Vector2i] = []

var preview_instance: Node2D = null
var current_preview_scene: PackedScene = null
var is_previewing := false

var preview_tiles: Array[Vector2i] = []
var preview_can_place := false
var is_dragging_placement: bool = false

var current_build_cost: Dictionary = {}
var current_build_texture: Texture2D = null

# ---------- BUILDINGS ----------

@export var crystal_scene: PackedScene = preload("res://Scenes/Buildings/Crystal.tscn")
var is_mandatory_placement: bool = false

@export var soil_tile_scene: PackedScene = preload("res://Scenes/Buildings/SoilTile.tscn")

var storage_building_scene: PackedScene = preload("res://Scenes/Buildings/StorageBuilding.tscn")
var weapon_rack_scene: PackedScene = preload("res://Scenes/Buildings/WeaponRack.tscn")
var furnace_scene: PackedScene = preload("res://Scenes/Buildings/Furnace.tscn")
var forge_scene: PackedScene = preload("res://Scenes/Buildings/Forge.tscn")


@export var sapling_scene: PackedScene = preload("res://Scenes/Buildings/OakSapling.tscn")


# ========== FUNCTIONS ==========

func _ready() -> void:
	add_to_group("building_manager")
	call_deferred("_check_initial_crystal")

func _check_initial_crystal() -> void:
	var existing = get_tree().get_nodes_in_group("crystal")
	if existing.is_empty() and crystal_scene:
		start_initial_crystal_placement()

func start_initial_crystal_placement() -> void:
	is_mandatory_placement = true
	start_preview(crystal_scene)

# ---------- INPUT ----------

func _input(event):
	# If mandatory initial crystal placement, block other building hotkeys
	if is_mandatory_placement and event is InputEventKey and event.pressed:
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if is_previewing and not is_mandatory_placement:
				cancel_preview()
				get_viewport().set_input_as_handled()
	
	# Mouse interaction during preview
	if is_previewing and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if not _is_mouse_over_ui():
					var b_type = preview_instance.get("building_type") if preview_instance else null
					if b_type == null:
						b_type = "building"
					if b_type == "ground_tile":
						is_dragging_placement = true
						place_tile_type(b_type)
						get_viewport().set_input_as_handled()
					else:
						confirm_placement()
						get_viewport().set_input_as_handled()
			else:
				is_dragging_placement = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if not is_mandatory_placement:
				cancel_preview()
				get_viewport().set_input_as_handled()

	# Mouse drag motion during preview
	if is_previewing and is_dragging_placement and event is InputEventMouseMotion:
		if not _is_mouse_over_ui() and _is_crop_preview():
			_update_preview_under_mouse()
			if preview_can_place:
				place_tile_type("ground_tile")

# ---------- PREVIEW ----------

func start_preview(scene: PackedScene, cost: Dictionary = {}):
	cancel_preview()
	is_dragging_placement = false
	current_preview_scene = scene
	current_build_cost = cost
	preview_instance = scene.instantiate()
	if "is_preview" in preview_instance:
		preview_instance.is_preview = true
	add_child(preview_instance)
	preview_instance.modulate = Color(1, 1, 1, 0.5)
	is_previewing = true

func _process(_delta):
	if !is_previewing or !preview_instance:
		return
	_update_preview_under_mouse()
	if is_dragging_placement and not _is_mouse_over_ui() and _is_crop_preview():
		if preview_can_place:
			place_tile_type("ground_tile")

func _update_preview_under_mouse():
	var size: Vector2i = Vector2i(1, 1)

	var s = preview_instance.get("size_in_tiles")
	if s != null:
		size = s
		
	var mouse_pos = get_global_mouse_position()
	var half_size_pixels = Vector2(size.x * TILE, size.y * TILE) / 2.0
	var raw_top_left = mouse_pos - half_size_pixels
	
	var top_left_tile := Vector2i(
		floor((raw_top_left.x / TILE) + 0.5),
		floor((raw_top_left.y / TILE) + 0.5)
	)
	
	var top_left_world_pos := Vector2(top_left_tile) * TILE
	
	var offset = Vector2( (size.x * TILE) / 2.0, size.y * TILE )
	preview_instance.global_position = top_left_world_pos + offset

	preview_tiles.clear()
	for x in range(size.x):
		for y in range(size.y):
			preview_tiles.append(top_left_tile + Vector2i(x, y))
	
	preview_can_place = true
	var terrain = world.get_node_or_null("Terrain") if world else null
	for t in preview_tiles:
		if terrain and "map_size" in terrain:
			if t.x < 1 or t.x >= terrain.map_size.x - 1 or t.y < 1 or t.y >= terrain.map_size.y - 1:
				preview_can_place = false
				break
		if t in used_tiles:
			preview_can_place = false
			break
	
	preview_instance.modulate = (Color(0, 1, 0, 0.5) if preview_can_place else Color(1, 0, 0, 0.5))

# ---------- PLACEMENT ----------

func place_tile_type(x):
	if world == null:
		cancel_preview()
		return

	match x:
		"ground_tile":
			if not preview_can_place:
				return
			for tile in preview_tiles:
				world.ground.set_cell(tile, 0, Vector2i(6,0))
				world.water_level[tile] = 0
				if tile not in used_tiles:
					used_tiles.append(tile)
			_update_preview_under_mouse()
			return
	
	cancel_preview()

func confirm_placement():
	if !is_previewing or !preview_instance:
		return
	_update_preview_under_mouse()
	if !preview_can_place:
		return

	var spawn_position = preview_instance.global_position
	# Dev mode places finished building directly without blueprint or resource cost
	var is_dev = Global.dev_mode if ("dev_mode" in Global) else false
	var is_blueprint = not current_build_cost.is_empty() and not is_dev
	var placed: Node2D

	if is_blueprint:
		if not blueprint_scene:
			cancel_preview()
			return
		placed = blueprint_scene.instantiate()
	else:
		placed = current_preview_scene.instantiate()

	placed.global_position = spawn_position

	if world:
		world.add_child(placed)
	else:
		add_child(placed)

	if is_blueprint:
		placed.setup(current_preview_scene, current_build_cost)
	else:
		placed.modulate = Color(1, 1, 1, 1)
		if "is_preview" in placed:
			placed.is_preview = false

	for t in preview_tiles:
		if t not in used_tiles:
			used_tiles.append(t)

	var was_mandatory = is_mandatory_placement
	is_mandatory_placement = false

	cancel_preview()

	if was_mandatory:
		placed.add_to_group("crystal")
		placed.add_to_group("central_crystal")
		initial_crystal_placed.emit(placed)

func cancel_preview(force: bool = false):
	if is_mandatory_placement and not force:
		return
	if force:
		is_mandatory_placement = false
	is_dragging_placement = false
	if preview_instance:
		preview_instance.queue_free()
	preview_instance = null
	current_preview_scene = null
	current_build_cost = {}
	is_previewing = false
	preview_tiles.clear()
	preview_can_place = false

func _is_crop_preview() -> bool:
	if not preview_instance:
		return false
	return preview_instance.get("building_type") == "ground_tile"

func _is_mouse_over_ui() -> bool:
	var vp = get_viewport()
	if vp:
		var hovered = vp.gui_get_hovered_control()
		if hovered and hovered.is_visible_in_tree() and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return true
	return false

#---------- DELETING ----------

func free_tiles(tiles_to_free: Array[Vector2i]) -> void:
	for tile in tiles_to_free:
		used_tiles.erase(tile)
