extends Node

# ========== SIGNALS ==========

signal save_completed(slot_name: String)
signal load_completed(slot_name: String)
signal save_failed(reason: String)
signal load_failed(reason: String)

# ========== CONSTANTS ==========

const SAVE_DIR: String = "user://saves/"

# ========== UI NOTIFICATION (TOAST) ==========

var _toast_layer: CanvasLayer = null
var _toast_label: Label = null
var _toast_tween: Tween = null

var _is_loading: bool = false
var _is_saving: bool = false

var _pending_load_data: Dictionary = {}
var _pending_slot_name: String = ""

# ========== FUNCTIONS ==========

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_toast_ui()

func has_pending_load() -> bool:
	return not _pending_load_data.is_empty()

func get_pending_load_data() -> Dictionary:
	return _pending_load_data

func get_pending_slot_name() -> String:
	return _pending_slot_name

# ---------- SERIALIZATION HELPERS ----------

static func _v2i_to_str(v: Vector2i) -> String:
	return "%d,%d" % [v.x, v.y]

static func _str_to_v2i(s: String) -> Vector2i:
	var parts = s.split(",")
	if parts.size() == 2:
		return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i.ZERO

# ---------- SAVE GAME ----------

func save_game(slot_name: String = "quicksave") -> bool:
	if _is_saving or _is_loading:
		push_warning("[SaveManager] Save or load already in progress, skipping save.")
		return false
	_is_saving = true

	var main = _get_main_node()
	if not main:
		var err = "Cannot save: Main scene node not found."
		push_error(err)
		save_failed.emit(err)
		_show_toast(err, true)
		_is_saving = false
		return false

	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		var make_dir_err = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		if make_dir_err != OK:
			var err = "Cannot create save directory: " + str(make_dir_err)
			push_error(err)
			save_failed.emit(err)
			_show_toast(err, true)
			_is_saving = false
			return false

	var terrain = main.get_node_or_null("Terrain")
	var building_manager = main.get_node_or_null("BuildingManager")
	var day_night = get_tree().get_first_node_in_group("day_night_cycle")
	var wave_mgr = get_tree().get_first_node_in_group("wave_manager")
	var weather_mgr = get_tree().get_first_node_in_group("weather_manager")
	var camera = get_viewport().get_camera_2d()
	if not camera:
		camera = main.get_node_or_null("Camera2D")

	var has_crystal_placed = get_tree().get_nodes_in_group("crystal").size() > 0 or get_tree().get_nodes_in_group("central_crystal").size() > 0
	if (building_manager and building_manager.is_mandatory_placement) or not has_crystal_placed:
		push_warning("[SaveManager] Cannot save before placing the initial crystal.")
		_show_toast("Place your crystal before saving!", true)
		_is_saving = false
		return false

	var save_data: Dictionary = {
		"meta": {
			"version": 2,
			"timestamp": Time.get_datetime_string_from_system(),
			"slot": slot_name
		},
		"environment": {
			"seed": terrain.terrain_seed if (terrain and "terrain_seed" in terrain) else 0,
			"difficulty": terrain.difficulty if (terrain and "difficulty" in terrain) else "clay",
			"map_size_x": terrain.map_size.x if (terrain and "map_size" in terrain) else 128,
			"map_size_y": terrain.map_size.y if (terrain and "map_size" in terrain) else 128,
			"water_threshold": terrain.water_threshold if (terrain and "water_threshold" in terrain) else -0.3,
			"walls_threshold": terrain.walls_threshold if (terrain and "walls_threshold" in terrain) else 0.3,
			"forest_threshold": terrain.forest_threshold if (terrain and "forest_threshold" in terrain) else 0.2,
			"forest_density": terrain.forest_density if (terrain and "forest_density" in terrain) else 0.4,
			"current_day": day_night.current_day if (day_night and "current_day" in day_night) else 1,
			"time_of_day": day_night.time_of_day if (day_night and "time_of_day" in day_night) else 0.33,
			"current_wave": wave_mgr.current_wave if (wave_mgr and "current_wave" in wave_mgr) else 0,
			"weather": weather_mgr.get_save_data() if (weather_mgr and weather_mgr.has_method("get_save_data")) else {}
		},
		"camera": {
			"x": camera.global_position.x if camera else 0.0,
			"y": camera.global_position.y if camera else 0.0,
			"zoom_x": camera.zoom.x if camera else 1.0,
			"zoom_y": camera.zoom.y if camera else 1.0
		},
		"task_priorities": main.get_task_priorities_save_data() if main.has_method("get_task_priorities_save_data") else [],
		"task_quotas": main.task_quotas.duplicate() if "task_quotas" in main else {},
		"used_tiles": [],
		"water_levels": {},
		"crops": {},
		"buildings": [],
		"resources": [],
		"claylings": [],
		"animals": [],
		"ground_items": [],
		"harvest_zones": []
	}

	# 1. Used tiles (preserves blocked grid tiles from terrain and buildings)
	if building_manager and "used_tiles" in building_manager:
		for t in building_manager.used_tiles:
			save_data["used_tiles"].append(_v2i_to_str(t))

	# 2. Water levels & Crops
	if "water_level" in main:
		for pos in main.water_level.keys():
			save_data["water_levels"][_v2i_to_str(pos)] = main.water_level[pos]

	if "crops_dic" in main:
		for pos in main.crops_dic.keys():
			save_data["crops"][_v2i_to_str(pos)] = main.crops_dic[pos]

	# 3. Player buildings
	var seen_buildings: Dictionary = {}
	var building_groups = ["storage", "crafting_buildings", "weapon_racks", "crystal", "central_crystal"]
	for grp in building_groups:
		for b in get_tree().get_nodes_in_group(grp):
			if not is_instance_valid(b) or b.is_queued_for_deletion() or b.get("is_preview"):
				continue
			var bid = b.get_instance_id()
			if seen_buildings.has(bid):
				continue
			seen_buildings[bid] = true

			var b_health = b.get("current_health") if "current_health" in b else 100
			if b_health <= 0 and "max_health" in b:
				b_health = b.max_health

			var b_dict: Dictionary = {
				"scene_path": b.scene_file_path,
				"x": b.global_position.x,
				"y": b.global_position.y,
				"health": b_health,
				"is_crystal": b.is_in_group("crystal") or b.is_in_group("central_crystal")
			}

			if b is StorageBuilding:
				b_dict["b_type"] = "storage"
				var items_arr: Array = []
				for item_res in b.inventory.keys():
					if item_res and item_res is ItemData:
						items_arr.append({
							"path": item_res.resource_path,
							"count": int(b.inventory[item_res])
						})
				b_dict["inventory"] = items_arr
				b_dict["current_fill"] = b.current_fill

			elif b is Blueprint:
				b_dict["b_type"] = "blueprint"
				b_dict["target_scene"] = b.target_building_scene.resource_path if b.target_building_scene else ""
				var req_m = {}
				for k in b.required_materials.keys():
					if k and k is ItemData:
						req_m[k.resource_path] = int(b.required_materials[k])
				b_dict["required_materials"] = req_m

				var cur_m = {}
				for k in b.current_materials.keys():
					if k and k is ItemData:
						cur_m[k.resource_path] = int(b.current_materials[k])
				b_dict["current_materials"] = cur_m

			elif b is WeaponRack:
				b_dict["b_type"] = "weapon_rack"
				var slots_arr: Array = []
				for slot in b.slots_data:
					var kit_p = slot["kit_resource"].resource_path if slot.get("kit_resource") else ""
					var item_paths: Array = []
					for it in slot.get("items", []):
						if it and it is ItemData:
							item_paths.append(it.resource_path)
					slots_arr.append({
						"kit_path": kit_p,
						"items": item_paths,
						"is_full": slot.get("is_full", false)
					})
				b_dict["slots"] = slots_arr

			elif b is CraftingBuilding:
				b_dict["b_type"] = "crafting"
				var recipes_arr: Array = []
				for r in b.recipe_queue:
					if r:
						recipes_arr.append(r.resource_path)
				b_dict["recipe_queue"] = recipes_arr
				b_dict["active_recipe"] = b.active_recipe.resource_path if b.active_recipe else ""
				b_dict["is_crafting"] = b.is_crafting
				b_dict["craft_timer"] = b.craft_timer
				b_dict["current_burn_time"] = b.current_burn_time
				b_dict["repeat_infinite"] = b.repeat_infinite

				var inp_inv = {}
				for k in b.input_inventory.keys():
					if k and k is ItemData:
						inp_inv[k.resource_path] = int(b.input_inventory[k])
				b_dict["input_inventory"] = inp_inv

				var out_inv = {}
				for k in b.output_inventory.keys():
					if k and k is ItemData:
						out_inv[k.resource_path] = int(b.output_inventory[k])
				b_dict["output_inventory"] = out_inv

				var fuel_inv = {}
				for k in b.fuel_inventory.keys():
					if k and k is ItemData:
						fuel_inv[k.resource_path] = int(b.fuel_inventory[k])
				b_dict["fuel_inventory"] = fuel_inv

			else:
				b_dict["b_type"] = "generic"

			save_data["buildings"].append(b_dict)

	# 3b. Natural & planted resources (Trees, Rocks, Ores, Plants, Saplings)
	var seen_resources: Dictionary = {}
	var resource_groups = ["trees", "rocks", "ores", "plants", "saplings"]
	for grp in resource_groups:
		for r in get_tree().get_nodes_in_group(grp):
			if not is_instance_valid(r) or r.is_queued_for_deletion() or r.get("is_preview"):
				continue
			var rid = r.get_instance_id()
			if seen_resources.has(rid):
				continue
			seen_resources[rid] = true

			var r_health = r.get("current_health") if "current_health" in r else 100
			if r_health <= 0 and "max_health" in r:
				r_health = r.max_health

			var r_dict: Dictionary = {
				"scene_path": r.scene_file_path,
				"x": r.global_position.x,
				"y": r.global_position.y,
				"health": r_health,
				"group": grp
			}

			if r is Sapling:
				r_dict["is_sapling"] = true
				r_dict["current_timer"] = r.current_timer
				r_dict["is_growing"] = r.is_growing

			save_data["resources"].append(r_dict)

	# 4. Claylings
	for c in get_tree().get_nodes_in_group("claylings"):
		if not is_instance_valid(c) or c.is_queued_for_deletion() or c.get("is_dead"):
			continue
		var item_res_path = ""
		if c.inventory.get("item") and c.inventory["item"] is ItemData:
			item_res_path = c.inventory["item"].resource_path

		var kit_res_path = ""
		if c.get("equipped_kit") and c.equipped_kit is KitData:
			kit_res_path = c.equipped_kit.resource_path

		save_data["claylings"].append({
			"name": c.clayling_name,
			"age": c.age,
			"personality": c.personality_trait,
			"x": c.global_position.x,
			"y": c.global_position.y,
			"health": c.health,
			"max_health": c.max_health,
			"hunger": c.hunger,
			"energy": c.energy,
			"happiness": c.happiness,
			"role": c.role,
			"is_combat_ready": c.is_combat_ready,
			"kit_path": kit_res_path,
			"item_path": item_res_path,
			"item_count": int(c.inventory.get("count", 0))
		})

	# 5. Animals (Chickens)
	for ch in get_tree().get_nodes_in_group("chicken"):
		if is_instance_valid(ch) and not ch.is_queued_for_deletion():
			save_data["animals"].append({
				"x": ch.global_position.x,
				"y": ch.global_position.y
			})
	if save_data["animals"].is_empty():
		for ch in main.get_children():
			if ch is Animal and not ch.is_queued_for_deletion():
				save_data["animals"].append({
					"x": ch.global_position.x,
					"y": ch.global_position.y
				})

	# 6. Ground items
	for it in get_tree().get_nodes_in_group("ground_items"):
		if is_instance_valid(it) and not it.is_queued_for_deletion() and it.data and it.quantity > 0:
			save_data["ground_items"].append({
				"item_path": it.data.resource_path,
				"quantity": it.quantity,
				"x": it.global_position.x,
				"y": it.global_position.y
			})

	# 7. Harvest zones
	for z in get_tree().get_nodes_in_group("harvest_zones"):
		if is_instance_valid(z) and not z.is_queued_for_deletion() and not z.get("is_placing"):
			save_data["harvest_zones"].append({
				"x": z.global_position.x,
				"y": z.global_position.y,
				"radius": z.radius,
				"target_index": z.current_target_index
			})

	# Safe atomic write via temporary file
	var file_path = SAVE_DIR + slot_name + ".json"
	var tmp_path = file_path + ".tmp"
	var file = FileAccess.open(tmp_path, FileAccess.WRITE)
	if not file:
		var err = "Failed to open save file for writing: " + tmp_path
		push_error(err)
		save_failed.emit(err)
		_show_toast(err, true)
		_is_saving = false
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()

	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
	DirAccess.rename_absolute(tmp_path, file_path)

	print("[SaveManager] Game saved successfully to: " + file_path)
	save_completed.emit(slot_name)
	_show_toast("Game Saved (" + slot_name + ")")
	_is_saving = false
	return true

# ---------- LOAD GAME ----------

func load_game(slot_name: String = "quicksave") -> bool:
	if _is_loading:
		push_warning("[SaveManager] Load operation already in progress, skipping.")
		return false
	_is_loading = true

	var file_path = SAVE_DIR + slot_name + ".json"
	if not FileAccess.file_exists(file_path):
		var err = "Save file not found: " + file_path
		push_warning(err)
		load_failed.emit(err)
		_show_toast(err, true)
		_is_loading = false
		return false

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		var err = "Failed to open save file: " + file_path
		push_error(err)
		load_failed.emit(err)
		_show_toast(err, true)
		_is_loading = false
		return false

	var content = file.get_as_text()
	file.close()

	var data = JSON.parse_string(content)
	if data == null or typeof(data) != TYPE_DICTIONARY:
		var err = "Corrupted save file or invalid JSON structure."
		push_error(err)
		load_failed.emit(err)
		_show_toast(err, true)
		_is_loading = false
		return false

	_pending_load_data = data
	_pending_slot_name = slot_name

	# Reset engine states before clean reload
	Engine.time_scale = 1.0
	get_tree().paused = false

	# Reload the main scene or switch to it if currently in another scene (e.g. Main Menu)
	if get_tree().current_scene and get_tree().current_scene.scene_file_path == "res://Scenes/main.tscn":
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file("res://Scenes/main.tscn")
	_is_loading = false
	return true

# ---------- APPLY PENDING LOAD (CALLED FROM FRESH MAIN._READY) ----------

func apply_pending_load(main: Node2D) -> void:
	if _pending_load_data.is_empty():
		return

	var data = _pending_load_data
	var slot_name = _pending_slot_name
	_pending_load_data = {}
	_pending_slot_name = ""

	var terrain = main.get_node_or_null("Terrain")
	var building_manager = main.get_node_or_null("BuildingManager")
	var day_night = get_tree().get_first_node_in_group("day_night_cycle")
	var wave_mgr = get_tree().get_first_node_in_group("wave_manager")
	var camera = get_viewport().get_camera_2d()
	if not camera:
		camera = main.get_node_or_null("Camera2D")

	# 1. Remove default scene chicken
	for ch in main.get_children():
		if ch is Animal:
			_safe_remove_and_free(ch)

	# 2. Reset engine pause & time scale
	Engine.time_scale = 1.0
	get_tree().paused = false

	var time_speed = get_tree().get_first_node_in_group("time_speed_ui")
	if not time_speed:
		time_speed = main.get_node_or_null("CanvasLayer/TimeSpeedUI")
	if time_speed and time_speed.has_method("set_speed_mode"):
		time_speed.set_speed_mode(TimeSpeedUI.SpeedMode.SPEED_1X)

	# 3. Environment & DayNightCycle & WaveManager & Quotas
	var env = data.get("environment", {})
	if day_night:
		day_night.current_day = int(env.get("current_day", 1))
		day_night.time_of_day = float(env.get("time_of_day", 0.33))

	if wave_mgr:
		wave_mgr.current_wave = int(env.get("current_wave", 0))
		wave_mgr.is_wave_active = false
		wave_mgr.is_spawning = false
		wave_mgr.active_enemies.clear()

	var weather_mgr = get_tree().get_first_node_in_group("weather_manager")
	if weather_mgr and weather_mgr.has_method("load_save_data") and env.has("weather"):
		weather_mgr.load_save_data(env["weather"])

	if data.has("task_priorities") and main.has_method("load_task_priorities_save_data"):
		main.load_task_priorities_save_data(data["task_priorities"])
		var t_menu = get_tree().get_first_node_in_group("task_priority_menu")
		if not t_menu:
			t_menu = main.get_node_or_null("CanvasLayer/TaskPriorityMenu")
		if t_menu and t_menu.has_method("load_orders_data"):
			t_menu.load_orders_data(data["task_priorities"])
	elif "task_quotas" in main and data.has("task_quotas"):
		main.task_quotas = data["task_quotas"].duplicate()
		var t_menu = get_tree().get_first_node_in_group("task_priority_menu")
		if not t_menu:
			t_menu = main.get_node_or_null("CanvasLayer/TaskPriorityMenu")
		if t_menu and t_menu.has_method("load_quotas"):
			t_menu.load_quotas(data["task_quotas"])

	_clear_main_reservations(main)

	# 4. Terrain Seed & Natural Resources
	var saved_seed = int(env.get("seed", 0))
	var has_saved_resources = data.has("resources")
	if terrain and "terrain_seed" in terrain:
		if saved_seed != 0:
			terrain.terrain_seed = saved_seed
		if "difficulty" in terrain and env.has("difficulty"):
			terrain.difficulty = str(env["difficulty"])
		if "map_size" in terrain and env.has("map_size_x") and env.has("map_size_y"):
			terrain.map_size = Vector2i(int(env["map_size_x"]), int(env["map_size_y"]))
		if "water_threshold" in terrain and env.has("water_threshold"):
			terrain.water_threshold = float(env["water_threshold"])
		if "walls_threshold" in terrain and env.has("walls_threshold"):
			terrain.walls_threshold = float(env["walls_threshold"])
		if "forest_threshold" in terrain and env.has("forest_threshold"):
			terrain.forest_threshold = float(env["forest_threshold"])
		if "forest_density" in terrain and env.has("forest_density"):
			terrain.forest_density = float(env["forest_density"])
		terrain.rng.seed = terrain.terrain_seed
		terrain.setup_noise()
		if has_saved_resources:
			terrain.generate_terrain(false)
		else:
			terrain.generate_terrain(true)

	# 4b. Restore Resources (Trees, Rocks, Ores, Plants, Saplings)
	if has_saved_resources:
		for r_dict in data.get("resources", []):
			var r_path = r_dict.get("scene_path", "")
			if not ResourceLoader.exists(r_path):
				continue
			var r_scene: PackedScene = load(r_path)
			var r_node = r_scene.instantiate()
			r_node.global_position = Vector2(float(r_dict.get("x", 0.0)), float(r_dict.get("y", 0.0)))
			if "current_health" in r_node:
				var h = int(r_dict.get("health", 100))
				r_node.current_health = h if h > 0 else (r_node.max_health if "max_health" in r_node else 100)
			if r_dict.get("is_sapling", false) or r_node is Sapling:
				if "current_timer" in r_node:
					r_node.current_timer = float(r_dict.get("current_timer", 5.0))
				if "is_growing" in r_node:
					r_node.is_growing = bool(r_dict.get("is_growing", true))
			r_node.add_to_group("generated")
			main.add_child(r_node)

	# 5. Used tiles in BuildingManager
	if building_manager and "used_tiles" in building_manager:
		building_manager.used_tiles.clear()
		for t_str in data.get("used_tiles", []):
			building_manager.used_tiles.append(_str_to_v2i(t_str))

	# 6. Water levels & Crops
	if "water_level" in main:
		main.water_level.clear()
		for k in data.get("water_levels", {}).keys():
			var pos = _str_to_v2i(k)
			var lvl = float(data["water_levels"][k])
			main.water_level[pos] = lvl
			if main.ground:
				if lvl > 0:
					main.set_tile("soil", pos, main.ground, 1)
				else:
					main.set_tile("soil", pos, main.ground, 0)

	if "crops_dic" in main:
		main.crops_dic.clear()
		if main.crops:
			main.crops.clear()
		for k in data.get("crops", {}).keys():
			var pos = _str_to_v2i(k)
			var c_info = data["crops"][k]
			main.crops_dic[pos] = c_info
			var c_name = c_info.get("name", "carrot")
			var dur = float(c_info.get("duration", 0.0))
			if main.custom_tile.has(c_name) and main.crops:
				if dur < 0 or dur >= main.custom_tile[c_name].duration:
					main.set_tile(c_name, pos, main.crops, main.custom_tile[c_name].atlas_coords.size() - 1)
				else:
					var idx = main.custom_tile[c_name].growth_index(dur)
					main.set_tile(c_name, pos, main.crops, idx)

	# 7. Restore Buildings
	var placed_crystal = null
	for b_dict in data.get("buildings", []):
		var scene_path = b_dict.get("scene_path", "")
		if not ResourceLoader.exists(scene_path):
			continue
		var b_scene: PackedScene = load(scene_path)
		var b_node = b_scene.instantiate()
		b_node.global_position = Vector2(b_dict.get("x", 0), b_dict.get("y", 0))
		if "current_health" in b_node:
			var h = int(b_dict.get("health", 100))
			b_node.current_health = h if h > 0 else (b_node.max_health if "max_health" in b_node else 100)
		main.add_child(b_node)

		if b_dict.get("is_crystal", false):
			b_node.add_to_group("crystal")
			b_node.add_to_group("central_crystal")
			placed_crystal = b_node

		var b_type = b_dict.get("b_type", "generic")
		if b_type == "storage" and b_node is StorageBuilding:
			b_node.inventory.clear()
			b_node.current_fill = 0
			for it_entry in b_dict.get("inventory", []):
				var p = it_entry.get("path", "")
				var count = int(it_entry.get("count", 0))
				if ResourceLoader.exists(p):
					var res = load(p)
					b_node.inventory[res] = count
					b_node.current_fill += count
			b_node.update_sprite()

		elif b_type == "blueprint" and b_node is Blueprint:
			var target_path = b_dict.get("target_scene", "")
			var target_scene = load(target_path) if ResourceLoader.exists(target_path) else null
			var req_m = {}
			for p in b_dict.get("required_materials", {}).keys():
				if ResourceLoader.exists(p):
					req_m[load(p)] = int(b_dict["required_materials"][p])
			b_node.setup(target_scene, req_m)
			for p in b_dict.get("current_materials", {}).keys():
				if ResourceLoader.exists(p):
					b_node.current_materials[load(p)] = int(b_dict["current_materials"][p])

		elif b_type == "weapon_rack" and b_node is WeaponRack:
			var saved_slots = b_dict.get("slots", [])
			for i in range(min(b_node.slots_data.size(), saved_slots.size())):
				var s_data = saved_slots[i]
				var kit_p = s_data.get("kit_path", "")
				b_node.slots_data[i]["kit_resource"] = load(kit_p) if (kit_p != "" and ResourceLoader.exists(kit_p)) else null
				b_node.slots_data[i]["items"].clear()
				for item_p in s_data.get("items", []):
					if ResourceLoader.exists(item_p):
						b_node.slots_data[i]["items"].append(load(item_p))
				b_node.slots_data[i]["is_full"] = s_data.get("is_full", false)
				b_node._update_slot_visuals(i)

		elif b_type == "crafting" and b_node is CraftingBuilding:
			b_node.recipe_queue.clear()
			for r_path in b_dict.get("recipe_queue", []):
				if ResourceLoader.exists(r_path):
					b_node.recipe_queue.append(load(r_path))
			var active_p = b_dict.get("active_recipe", "")
			b_node.active_recipe = load(active_p) if (active_p != "" and ResourceLoader.exists(active_p)) else null
			b_node.is_crafting = b_dict.get("is_crafting", false)
			b_node.craft_timer = float(b_dict.get("craft_timer", 0.0))
			b_node.current_burn_time = float(b_dict.get("current_burn_time", 0.0))
			b_node.repeat_infinite = b_dict.get("repeat_infinite", false)

			b_node.input_inventory.clear()
			for p in b_dict.get("input_inventory", {}).keys():
				if ResourceLoader.exists(p):
					b_node.input_inventory[load(p)] = int(b_dict["input_inventory"][p])

			b_node.output_inventory.clear()
			for p in b_dict.get("output_inventory", {}).keys():
				if ResourceLoader.exists(p):
					b_node.output_inventory[load(p)] = int(b_dict["output_inventory"][p])

			b_node.fuel_inventory.clear()
			for p in b_dict.get("fuel_inventory", {}).keys():
				if ResourceLoader.exists(p):
					b_node.fuel_inventory[load(p)] = int(b_dict["fuel_inventory"][p])

	# 8. Crystal status & Gameplay HUD
	var hud = get_tree().get_first_node_in_group("hud_controller")
	if not hud:
		hud = main.get_node_or_null("CanvasLayer/HUDController")

	if placed_crystal:
		if building_manager:
			building_manager.is_mandatory_placement = false
			building_manager.cancel_preview(true)
			if building_manager.has_signal("initial_crystal_placed"):
				building_manager.initial_crystal_placed.emit(placed_crystal)
		var banner = main.get_node_or_null("CanvasLayer/CrystalPlacementBanner")
		if banner and is_instance_valid(banner):
			banner.visible = false
			banner.queue_free()
		if hud and hud.has_method("set_gameplay_hud_visible"):
			hud.set_gameplay_hud_visible(true, false)

	# 9. Restore Claylings
	for c_data in data.get("claylings", []):
		if not main.clayling_scene:
			continue
		var c = main.clayling_scene.instantiate()
		c.global_position = Vector2(c_data.get("x", 0), c_data.get("y", 0))
		main.add_child(c)
		if "active_claylings" in main:
			main.active_claylings.append(c)

		c.clayling_name = c_data.get("name", "Clayling")
		c.age = int(c_data.get("age", 5))
		c.personality_trait = c_data.get("personality", "Normal")
		if c.has_method("_apply_trait_base_stats"):
			c._apply_trait_base_stats()
		c.health = float(c_data.get("health", 100.0))
		c.max_health = float(c_data.get("max_health", 100.0))
		c.hunger = float(c_data.get("hunger", 100.0))
		c.energy = float(c_data.get("energy", 100.0))
		c.happiness = float(c_data.get("happiness", 100.0))

		var kit_path = c_data.get("kit_path", "")
		if kit_path != "" and ResourceLoader.exists(kit_path):
			var kit_res: KitData = load(kit_path)
			if kit_res and c.has_method("_apply_kit"):
				c._apply_kit({
					"kit_resource": kit_res,
					"kit_type": kit_res.kit_id,
					"display_name": kit_res.display_name,
					"items": kit_res.required_items
				})
		else:
			c.role = c_data.get("role", "villager")
			c.is_combat_ready = false

		var item_path = c_data.get("item_path", "")
		if item_path != "" and ResourceLoader.exists(item_path):
			c.inventory["item"] = load(item_path)
			c.inventory["count"] = int(c_data.get("item_count", 1))
		else:
			c.inventory["item"] = null
			c.inventory["count"] = 0
		if c.has_method("_refresh_carry_sprite"):
			c._refresh_carry_sprite()

		if not c.is_combat_ready:
			c.change_state("Idle")
			if c.states.has("Idle"):
				c.states["Idle"].timer = randf_range(0.1, 3.5)

	# 10. Restore Animals (Chickens)
	for a_data in data.get("animals", []):
		if main.has_method("spawn_clayling"):
			var ch = main.spawn_clayling(Vector2(a_data.get("x", 0), a_data.get("y", 0)), "chicken")
			if ch and "states" in ch and ch.states.has("Idle"):
				ch.states["Idle"].timer = randf_range(0.1, 3.0)

	# 11. Restore Ground items
	for it_data in data.get("ground_items", []):
		var p = it_data.get("item_path", "")
		if ResourceLoader.exists(p) and main.item_scene:
			var it_node = main.item_scene.instantiate()
			it_node.global_position = Vector2(it_data.get("x", 0), it_data.get("y", 0))
			it_node.data = load(p)
			it_node.quantity = int(it_data.get("quantity", 1))
			main.add_child(it_node)

	# 12. Restore Harvest zones
	for z_data in data.get("harvest_zones", []):
		if main.zone_scene:
			var z_node = main.zone_scene.instantiate()
			z_node.global_position = Vector2(z_data.get("x", 0), z_data.get("y", 0))
			z_node.radius = float(z_data.get("radius", 60.0))
			z_node.current_target_index = int(z_data.get("target_index", 0))
			z_node.is_placing = false
			main.add_child(z_node)
			if z_node.has_method("mark_resources"):
				z_node.mark_resources()

	# 13. Restore Camera
	var cam_data = data.get("camera", {})
	if camera and not cam_data.is_empty():
		var cam_pos = Vector2(cam_data.get("x", camera.global_position.x), cam_data.get("y", camera.global_position.y))
		var cam_zoom_val = float(cam_data.get("zoom_x", camera.zoom.x))
		camera.global_position = cam_pos
		camera.zoom = Vector2(cam_zoom_val, cam_zoom_val)
		if "target_position" in camera:
			camera.target_position = cam_pos
		if "target_zoom" in camera:
			camera.target_zoom = cam_zoom_val
		if "is_centering" in camera:
			camera.is_centering = false
		if "dragging" in camera:
			camera.dragging = false

	if "assign_cooldown" in main:
		main.assign_cooldown = 0.0

	print("[SaveManager] Game loaded successfully via scene reload: " + slot_name)
	load_completed.emit(slot_name)
	_show_toast("Game Loaded (" + slot_name + ")")

# ---------- HELPER METHODS ----------

func get_save_slots() -> Array[String]:
	var slots: Array[String] = []
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		return slots

	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				slots.append(file_name.get_basename())
			file_name = dir.get_next()
		dir.list_dir_end()
	return slots

func get_all_saves_metadata() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var slots = get_save_slots()
	for slot in slots:
		var file_path = SAVE_DIR + slot + ".json"
		var file = FileAccess.open(file_path, FileAccess.READ)
		if not file:
			continue
		var content = file.get_as_text()
		file.close()
		var data = JSON.parse_string(content)
		if data == null or typeof(data) != TYPE_DICTIONARY:
			continue
		var meta = data.get("meta", {})
		var env = data.get("environment", {})
		result.append({
			"slot_name": slot,
			"timestamp": str(meta.get("timestamp", "")),
			"day": int(env.get("current_day", 1)),
			"wave": int(env.get("current_wave", 0))
		})
	# Sort by timestamp descending (newest first)
	result.sort_custom(func(a, b): return a["timestamp"] > b["timestamp"])
	return result

func has_save(slot_name: String) -> bool:
	return FileAccess.file_exists(SAVE_DIR + slot_name + ".json")

func delete_save(slot_name: String) -> bool:
	var path = SAVE_DIR + slot_name + ".json"
	if FileAccess.file_exists(path):
		var err = DirAccess.remove_absolute(path)
		return err == OK
	return false

func _get_main_node() -> Node2D:
	var node = get_tree().get_first_node_in_group("main")
	if node:
		return node as Node2D
	if get_tree().current_scene is Node2D:
		return get_tree().current_scene as Node2D
	return null

func _clear_main_reservations(main: Node2D) -> void:
	var res_fields = [
		"reserved_harvest", "reserved_water", "reserved_plant",
		"reserved_pickups", "reserved_trees", "reserved_rocks",
		"reserved_forages", "reserved_outputs", "reserved_work"
	]
	for field in res_fields:
		if field in main and main.get(field) is Dictionary:
			main.get(field).clear()

# ---------- TOAST NOTIFICATION ----------

func _setup_toast_ui() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 125
	add_child(_toast_layer)

	_toast_label = Label.new()
	_toast_label.anchors_preset = Control.PRESET_CENTER_TOP
	_toast_label.anchor_left = 0.5
	_toast_label.anchor_right = 0.5
	_toast_label.offset_left = -200.0
	_toast_label.offset_right = 200.0
	_toast_label.offset_top = 24.0
	_toast_label.offset_bottom = 60.0
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel = Panel.new()
	panel.show_behind_parent = true
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.add_child(panel)

	_toast_layer.add_child(_toast_label)

func _show_toast(message: String, is_error: bool = false) -> void:
	if not _toast_label:
		return

	_toast_label.text = message
	_toast_label.modulate = Color(1.0, 0.4, 0.4, 1.0) if is_error else Color(0.9, 1.0, 0.9, 1.0)

	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()

	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_label, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.6)

static func _safe_remove_and_free(node: Node) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	if node.get_parent():
		node.get_parent().remove_child(node)
	node.queue_free()
