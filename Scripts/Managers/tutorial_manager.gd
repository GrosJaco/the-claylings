extends Node
class_name TutorialManager

# ========== SIGNALS ==========

signal step_changed(step_index: int, step_data: Dictionary)
signal objective_updated(step_index: int, objective_index: int, current: int, target: int, completed: bool)
signal step_completed(step_index: int)
signal tutorial_finished

# ========== STATE ==========

var steps: Array[Dictionary] = []
var current_step_index: int = 0
var is_completed: bool = false
var _check_timer: float = 0.0

var _initial_cam_pos: Vector2 = Vector2.ZERO
var _camera_has_panned: bool = false
var _call_to_arms_has_triggered: bool = false
var _first_wave_cleared: bool = false
var trees_felled_count: int = 0

const SAVE_PATH: String = "user://tutorial.cfg"

# ========== INITIALIZATION ==========

func _ready() -> void:
	add_to_group("tutorial_manager")
	_init_steps()
	_load_progress()
	call_deferred("_setup_listeners")

func _init_steps() -> void:
	steps = [
		{
			"id": "awakening",
			"title": "1. THE AWAKENING",
			"description": "Welcome to your new settlement! Survey your land by panning the camera with [b]WASD[/b] or [b]Arrow Keys[/b]. Then, place your [b]Central Crystal[/b] in a safe, open area.",
			"hud_highlight": "",
			"objectives": [
				{"id": "pan_camera", "text": "Pan the camera", "target": 1, "current": 0, "completed": false},
				{"id": "place_crystal", "text": "Place Central Crystal", "target": 1, "current": 0, "completed": false}
			]
		},
		{
			"id": "woodcutting",
			"title": "2. GATHERING TIMBER",
			"description": "Wood is the bedrock of construction. Designate trees to fell by drawing a [b]Harvest Zone [M][/b], or select a Clayling and [b]right-click[/b] directly on a tree.",
			"hud_highlight": "harvest_zone_button",
			"objectives": [
				{"id": "cut_trees", "text": "Cut 10 Trees", "target": 10, "current": 0, "completed": false}
			]
		},
		{
			"id": "storage",
			"title": "3. BASIC LOGISTICS",
			"description": "Items left on the ground clutter the world. Open the [b]Build Menu [B][/b], navigate to [b]Logistics[/b], and erect a [b]Storage[/b] building for your goods.",
			"hud_highlight": "build_menu",
			"objectives": [
				{"id": "build_storage", "text": "Build 1 Storage Building", "target": 1, "current": 0, "completed": false}
			]
		},
		{
			"id": "sustenance",
			"title": "4. SUSTENANCE",
			"description": "Claylings hunger over time. Till fertile land with Soil Tiles from the [b]Planting Menu [P][/b]. Your workers will automatically plant crops and carry water to irrigate them.",
			"hud_highlight": "plant_menu",
			"objectives": [
				{"id": "plant_crops", "text": "Plant 4 Crops", "target": 4, "current": 0, "completed": false}
			]
		},
		{
			"id": "carpentry",
			"title": "5. CARPENTRY",
			"description": "Rough timber must be shaped for construction. Open the [b]Build Menu [B][/b], place a [b]Chopping Block[/b], and process raw wood into [b]Wood Planks[/b].",
			"hud_highlight": "build_menu",
			"objectives": [
				{"id": "build_chopping_block", "text": "Build 1 Chopping Block", "target": 1, "current": 0, "completed": false},
				{"id": "craft_planks", "text": "Produce 6 Wood Planks", "target": 6, "current": 0, "completed": false}
			]
		},
		{
			"id": "metallurgy",
			"title": "6. METALLURGY",
			"description": "Advanced tools and armor require forged metal. Gather stone and ore, then erect a [b]Furnace[/b] from the [b]Build Menu [B][/b] to smelt raw ore into [b]Metal Ingots[/b].",
			"hud_highlight": "build_menu",
			"objectives": [
				{"id": "build_furnace", "text": "Build 1 Furnace", "target": 1, "current": 0, "completed": false},
				{"id": "smelt_ingots", "text": "Smelt 4 Metal Ingots", "target": 4, "current": 0, "completed": false}
			]
		},
		{
			"id": "defense",
			"title": "7. TO ARMS!",
			"description": "Nightfall brings perils. With planks and forged metal ready, construct a [b]Weapon Rack[/b] from the [b]Build Menu [B][/b] so Claylings can assemble combat gear.",
			"hud_highlight": "build_menu",
			"objectives": [
				{"id": "build_weapon_rack", "text": "Build 1 Weapon Rack", "target": 1, "current": 0, "completed": false},
				{"id": "ready_soldier", "text": "Ready at least 1 Soldier", "target": 1, "current": 0, "completed": false}
			]
		},
		{
			"id": "trial",
			"title": "8. THE FIRST TRIAL",
			"description": "Enemies lurk in the dark. Ring the town bell with [b]Call to Arms [X][/b] to mobilize your troops and defend the Central Crystal against the approaching wave!",
			"hud_highlight": "call_to_arms_button",
			"objectives": [
				{"id": "call_to_arms", "text": "Sound Call to Arms [X]", "target": 1, "current": 0, "completed": false},
				{"id": "repel_wave", "text": "Survive the First Wave", "target": 1, "current": 0, "completed": false}
			]
		},
		{
			"id": "completion",
			"title": "SETTLEMENT FOUNDED",
			"description": "Your colony has withstood every trial! With carpentry, smelting, and an armed garrison, your Claylings are ready to prosper. Lead them to greatness!",
			"hud_highlight": "",
			"objectives": [
				{"id": "finish", "text": "Tutorial Completed", "target": 1, "current": 1, "completed": true}
			]
		}
	]

func _setup_listeners() -> void:
	var camera = get_tree().get_first_node_in_group("camera") as Camera2D
	if camera:
		_initial_cam_pos = camera.global_position

	var rts = get_tree().get_first_node_in_group("rts_controller")
	if rts and rts.has_signal("call_to_arms_triggered"):
		rts.call_to_arms_triggered.connect(_on_call_to_arms_triggered)

	var wave_manager = get_tree().get_first_node_in_group("wave_manager")
	if wave_manager and wave_manager.has_signal("wave_cleared"):
		wave_manager.wave_cleared.connect(_on_wave_cleared)

	# Initial step notification
	if not is_completed:
		step_changed.emit(current_step_index, steps[current_step_index])

# ========== PROCESS & EVALUATION ==========

func _process(delta: float) -> void:
	if is_completed:
		return

	# Fast camera pan detection in step 0
	if current_step_index == 0 and not _camera_has_panned:
		var camera = get_tree().get_first_node_in_group("camera") as Camera2D
		if camera and camera.global_position.distance_to(_initial_cam_pos) > 60.0:
			_camera_has_panned = true
		elif Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down") != Vector2.ZERO:
			_camera_has_panned = true
		elif Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") != Vector2.ZERO:
			_camera_has_panned = true

	# Periodic state-based verification (Timberborn style)
	_check_timer += delta
	if _check_timer >= 0.25:
		_check_timer = 0.0
		_evaluate_current_step()

func _evaluate_current_step() -> void:
	if current_step_index < 0 or current_step_index >= steps.size():
		return

	var step = steps[current_step_index]
	var all_objectives_done = true

	for i in range(step["objectives"].size()):
		var obj = step["objectives"][i]
		var prev_curr = obj["current"]
		var prev_done = obj["completed"]

		_update_objective_data(step["id"], obj)

		if obj["current"] != prev_curr or obj["completed"] != prev_done:
			objective_updated.emit(current_step_index, i, obj["current"], obj["target"], obj["completed"])

		if not obj["completed"]:
			all_objectives_done = false

	if all_objectives_done and step["id"] != "completion":
		advance_step()

func _update_objective_data(step_id: String, obj: Dictionary) -> void:
	match obj["id"]:
		"pan_camera":
			obj["current"] = 1 if _camera_has_panned else 0
			obj["completed"] = _camera_has_panned

		"place_crystal":
			var has_crystal = _has_active_crystal()
			obj["current"] = 1 if has_crystal else 0
			obj["completed"] = has_crystal

		"cut_trees":
			var effective_count = max(trees_felled_count, (_count_items("wood") + _count_ground_wood()) / 3)
			obj["current"] = mini(effective_count, obj["target"])
			obj["completed"] = effective_count >= obj["target"]

		"build_storage":
			var storages = _count_storages()
			obj["current"] = mini(storages, obj["target"])
			obj["completed"] = storages >= obj["target"]

		"plant_crops":
			var crops = _count_crops()
			obj["current"] = mini(crops, obj["target"])
			obj["completed"] = crops >= obj["target"]

		"build_chopping_block":
			var cb = _count_crafting_building("chopping_block")
			obj["current"] = mini(cb, obj["target"])
			obj["completed"] = cb >= obj["target"]

		"craft_planks":
			var planks = _count_items("wood_plank")
			obj["current"] = mini(planks, obj["target"])
			obj["completed"] = planks >= obj["target"]

		"build_furnace":
			var f = _count_crafting_building("furnace")
			obj["current"] = mini(f, obj["target"])
			obj["completed"] = f >= obj["target"]

		"smelt_ingots":
			var ingots = _count_ingots()
			obj["current"] = mini(ingots, obj["target"])
			obj["completed"] = ingots >= obj["target"]

		"build_weapon_rack":
			var racks = _count_weapon_racks()
			obj["current"] = mini(racks, obj["target"])
			obj["completed"] = racks >= obj["target"]

		"ready_soldier":
			var soldiers = _count_soldiers()
			obj["current"] = mini(soldiers, obj["target"])
			obj["completed"] = soldiers >= obj["target"]

		"call_to_arms":
			var active = _call_to_arms_has_triggered or _is_call_to_arms_active()
			obj["current"] = 1 if active else 0
			obj["completed"] = active

		"repel_wave":
			var cleared = _first_wave_cleared or _is_first_wave_cleared()
			obj["current"] = 1 if cleared else 0
			obj["completed"] = cleared

		"finish":
			obj["current"] = 1
			obj["completed"] = true

# ========== STEP NAVIGATION ==========

func advance_step() -> void:
	step_completed.emit(current_step_index)
	current_step_index += 1

	if current_step_index >= steps.size():
		complete_tutorial()
	else:
		step_changed.emit(current_step_index, steps[current_step_index])
		_save_progress()

func skip_tutorial() -> void:
	complete_tutorial()

func complete_tutorial() -> void:
	is_completed = true
	tutorial_finished.emit()
	_save_progress()

func notify_tree_felled() -> void:
	trees_felled_count += 1
	_save_progress()

func reset_tutorial() -> void:
	is_completed = false
	current_step_index = 0
	_camera_has_panned = false
	_call_to_arms_has_triggered = false
	_first_wave_cleared = false
	trees_felled_count = 0
	_init_steps()
	step_changed.emit(current_step_index, steps[current_step_index])
	_save_progress()

# ========== WORLD STATE QUERIES ==========

func _has_active_crystal() -> bool:
	var crystals = get_tree().get_nodes_in_group("crystal")
	for c in crystals:
		if is_instance_valid(c) and not c.get("is_preview"):
			return true
	return false

func _count_items(item_name: String) -> int:
	var count = 0
	var lower_name = item_name.to_lower()

	# Count from storages
	var storages = get_tree().get_nodes_in_group("storage")
	for s in storages:
		if not is_instance_valid(s) or s.get("is_preview"):
			continue
		if "inventory" in s:
			for item in s.inventory.keys():
				if item is ItemData:
					if item.name.to_lower() == lower_name or item.display_name.to_lower() == lower_name:
						count += int(s.inventory[item])

	# Count from claylings holding items
	var claylings = get_tree().get_nodes_in_group("claylings")
	for c in claylings:
		if not is_instance_valid(c):
			continue
		if "inventory" in c and c.inventory.get("item") != null:
			var item = c.inventory["item"]
			if item is ItemData:
				if item.name.to_lower() == lower_name or item.display_name.to_lower() == lower_name:
					count += int(c.inventory.get("count", 0))

	# Count from crafting buildings output inventories
	var crafting = get_tree().get_nodes_in_group("crafting_buildings")
	for cb in crafting:
		if not is_instance_valid(cb) or cb.get("is_preview"):
			continue
		if "output_inventory" in cb and cb.output_inventory is Dictionary:
			for item in cb.output_inventory.keys():
				if item is ItemData:
					if item.name.to_lower() == lower_name or item.display_name.to_lower() == lower_name:
						count += int(cb.output_inventory[item])

	# Count from ground items
	var ground = get_tree().get_nodes_in_group("ground_items")
	for it in ground:
		if is_instance_valid(it) and "data" in it and it.data is ItemData:
			if it.data.name.to_lower() == lower_name or it.data.display_name.to_lower() == lower_name:
				count += int(it.quantity) if "quantity" in it else 1

	return count

func _count_crafting_building(type_name: String) -> int:
	var count = 0
	var buildings = get_tree().get_nodes_in_group("crafting_buildings")
	for b in buildings:
		if not is_instance_valid(b) or b.get("is_preview") or b.get("is_blueprint") or b is Blueprint:
			continue
		if "building_type" in b and str(b.building_type).to_lower() == type_name.to_lower():
			count += 1
		elif b.name.to_lower().contains(type_name.to_lower()):
			count += 1
	return count

func _count_ingots() -> int:
	return _count_items("copper_bar") + _count_items("iron_bar") + _count_items("gold_bar")

func _count_storages() -> int:
	var count = 0
	var storages = get_tree().get_nodes_in_group("storage")
	for s in storages:
		if is_instance_valid(s) and not s.get("is_preview"):
			count += 1
	return count

func _count_crops() -> int:
	var main_node = get_tree().get_first_node_in_group("main")
	if main_node and "crops_dic" in main_node:
		return main_node.crops_dic.size()
	return 0

func _count_weapon_racks() -> int:
	var count = 0
	var racks = get_tree().get_nodes_in_group("weapon_racks")
	for r in racks:
		if is_instance_valid(r) and not r.get("is_preview"):
			count += 1
	return count

func _count_soldiers() -> int:
	var count = 0
	var soldiers = get_tree().get_nodes_in_group("soldiers")
	for s in soldiers:
		if is_instance_valid(s) and not s.get("is_dead") and s.get("is_combat_ready"):
			count += 1
	return count

func _is_call_to_arms_active() -> bool:
	var btn = get_tree().get_first_node_in_group("call_to_arms_button")
	if btn and "is_armed" in btn:
		return bool(btn.is_armed)
	return false

func _is_first_wave_cleared() -> bool:
	var wm = get_tree().get_first_node_in_group("wave_manager")
	if wm and "current_wave" in wm:
		return int(wm.current_wave) >= 1 and not wm.is_wave_active and not wm.is_spawning
	return false

func _count_ground_wood() -> int:
	var count = 0
	var items = get_tree().get_nodes_in_group("ground_items")
	for it in items:
		if is_instance_valid(it) and "data" in it and it.data is ItemData:
			if it.data.name.to_lower() == "wood" or it.data.display_name.to_lower() == "wood":
				count += int(it.quantity) if "quantity" in it else 1
	return count

# ========== SIGNAL CALLBACKS ==========

func _on_call_to_arms_triggered() -> void:
	_call_to_arms_has_triggered = true

func _on_wave_cleared(wave_num: int) -> void:
	if wave_num >= 1:
		_first_wave_cleared = true

# ========== PERSISTENCE ==========

func _save_progress() -> void:
	var config = ConfigFile.new()
	config.set_value("tutorial", "completed", is_completed)
	config.set_value("tutorial", "current_step", current_step_index)
	config.set_value("tutorial", "trees_felled", trees_felled_count)
	config.save(SAVE_PATH)

func _load_progress() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		is_completed = config.get_value("tutorial", "completed", false)
		current_step_index = config.get_value("tutorial", "current_step", 0)
		trees_felled_count = config.get_value("tutorial", "trees_felled", 0)
