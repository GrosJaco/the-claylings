extends Node2D
class_name RTSController

# ========== REFERENCES ==========

@onready var world: Node2D = $".."

# ========== VARIABLES ==========

var selected_soldiers: Array = []
var selected_villagers: Array = []

# Box selection (Left-click drag)
var is_box_selecting: bool = false
var selection_start: Vector2 = Vector2.ZERO
var selection_end: Vector2 = Vector2.ZERO

# Line formation (Right-click drag)
var is_line_drawing: bool = false
var line_start: Vector2 = Vector2.ZERO
var line_end: Vector2 = Vector2.ZERO
var is_line_valid: bool = true
var line_points: Array[Vector2] = []
var _last_voice_order_time: int = 0
var _last_voice_select_time: int = 0

# Demolition mode
var is_demolish_mode: bool = false
signal demolish_mode_changed(active: bool)

# ========== SIGNALS ==========

signal call_to_arms_triggered
signal call_to_work_triggered

# ========== FUNCTIONS ==========

func _ready() -> void:
	add_to_group("rts_controller")
	z_index = 100

func set_demolish_mode(active: bool) -> void:
	if is_demolish_mode == active:
		return
	is_demolish_mode = active
	if is_demolish_mode:
		deselect_all()
	if is_box_selecting:
		is_box_selecting = false
	queue_redraw()
	demolish_mode_changed.emit(is_demolish_mode)

func _draw() -> void:
	# 1. Draw Box Selection (Left-click)
	if is_box_selecting:
		var start = to_local(selection_start)
		var end = to_local(selection_end)
		var rect = Rect2(start, end - start).abs()
		if rect.size.length() > 4.0:
			if is_demolish_mode:
				draw_rect(rect, Color(1.0, 0.2, 0.2, 0.15), true)
				draw_rect(rect, Color(1.0, 0.2, 0.2, 0.95), false, 2.5)
			else:
				draw_rect(rect, Color(1.0, 1.0, 1.0, 0.12), true)
				draw_rect(rect, Color(1.0, 1.0, 1.0, 0.95), false, 2.5)

	# 2. Draw Line Formation (Right-click)
	var total_selected = selected_soldiers.size() + selected_villagers.size()
	if is_line_drawing and total_selected > 0:
		var line_color = Color(1.0, 1.0, 1.0, 1.0) if is_line_valid else Color(1.0, 0.2, 0.2, 1.0)
		var start_local = to_local(line_start)
		var end_local = to_local(line_end)
		var drag_dist = line_start.distance_to(line_end)

		if drag_dist >= 8.0:
			# Draw main line (sharp, no antialiasing blur)
			draw_line(start_local, end_local, line_color, 2.5, false)

			# Draw forward facing indicator tick at center of line
			var line_vec = line_end - line_start
			var forward_vec = Vector2(line_vec.y, -line_vec.x).normalized()
			var mid_local = (start_local + end_local) * 0.5
			draw_line(mid_local, mid_local + forward_vec * 10.0, line_color, 2.0, false)

		# Draw crisp destination points along the line
		for pt in line_points:
			var pt_local = to_local(pt)
			draw_circle(pt_local, 3.5, line_color)

# ---------- SELECTION API ----------

func select_soldier(soldier: Node2D, add_to_selection: bool = false) -> void:
	if not add_to_selection:
		deselect_all()
	if is_instance_valid(soldier) and not selected_soldiers.has(soldier):
		selected_soldiers.append(soldier)
		soldier.set_selected(true)
		_play_squad_voice([soldier], "interrogation")

func select_villager(villager: Node2D, add_to_selection: bool = false) -> void:
	if not add_to_selection:
		deselect_all()
	if is_instance_valid(villager) and not selected_villagers.has(villager):
		selected_villagers.append(villager)
		villager.set_selected(true)
		_play_squad_voice([villager], "interrogation")

func deselect_all_soldiers() -> void:
	for s in selected_soldiers:
		if is_instance_valid(s):
			s.set_selected(false)
	selected_soldiers.clear()

func deselect_all_villagers() -> void:
	for v in selected_villagers:
		if is_instance_valid(v):
			v.set_selected(false)
	selected_villagers.clear()

func deselect_all() -> void:
	deselect_all_soldiers()
	deselect_all_villagers()

func select_soldiers_in_rect(rect: Rect2, add_to_selection: bool = false) -> void:
	select_claylings_in_rect(rect, add_to_selection)

func select_claylings_in_rect(rect: Rect2, add_to_selection: bool = false) -> void:
	if not add_to_selection:
		deselect_all()
	var all_claylings = get_tree().get_nodes_in_group("claylings")
	var soldiers_in_rect: Array = []
	var villagers_in_rect: Array = []
	for c in all_claylings:
		if is_instance_valid(c) and not c.get("is_dead") and rect.has_point(c.global_position):
			if c.get("is_combat_ready"):
				soldiers_in_rect.append(c)
			else:
				villagers_in_rect.append(c)

	if soldiers_in_rect.size() > 0:
		for s in soldiers_in_rect:
			if not selected_soldiers.has(s):
				selected_soldiers.append(s)
				s.set_selected(true)
		_play_squad_voice(selected_soldiers, "interrogation")
	elif villagers_in_rect.size() > 0:
		for v in villagers_in_rect:
			if not selected_villagers.has(v):
				selected_villagers.append(v)
				v.set_selected(true)
		_play_squad_voice(selected_villagers, "interrogation")

func select_all_melee_soldiers(add_to_selection: bool = false) -> void:
	if not add_to_selection:
		deselect_all_soldiers()
	var all_soldiers = get_tree().get_nodes_in_group("soldiers")
	var newly_selected: Array = []
	for s in all_soldiers:
		if is_instance_valid(s) and not s.get("is_dead") and s.get("is_combat_ready"):
			var r = s.get("role")
			if r != "archer" and r != "villager":
				if not selected_soldiers.has(s):
					selected_soldiers.append(s)
					s.set_selected(true)
					newly_selected.append(s)
	if newly_selected.size() > 0 or selected_soldiers.size() > 0:
		_play_squad_voice(selected_soldiers, "interrogation")

func select_all_ranged_soldiers(add_to_selection: bool = false) -> void:
	if not add_to_selection:
		deselect_all_soldiers()
	var all_soldiers = get_tree().get_nodes_in_group("soldiers")
	var newly_selected: Array = []
	for s in all_soldiers:
		if is_instance_valid(s) and not s.get("is_dead") and s.get("is_combat_ready"):
			if s.get("role") == "archer":
				if not selected_soldiers.has(s):
					selected_soldiers.append(s)
					s.set_selected(true)
					newly_selected.append(s)
	if newly_selected.size() > 0 or selected_soldiers.size() > 0:
		_play_squad_voice(selected_soldiers, "interrogation")

func get_ready_melee_soldiers() -> Array:
	var valid: Array = []
	var all_soldiers = get_tree().get_nodes_in_group("soldiers")
	for s in all_soldiers:
		if is_instance_valid(s) and not s.get("is_dead") and s.get("is_combat_ready"):
			var r = s.get("role")
			if r != "archer" and r != "villager":
				valid.append(s)
	return valid

func get_ready_ranged_soldiers() -> Array:
	var valid: Array = []
	var all_soldiers = get_tree().get_nodes_in_group("soldiers")
	for s in all_soldiers:
		if is_instance_valid(s) and not s.get("is_dead") and s.get("is_combat_ready"):
			if s.get("role") == "archer":
				valid.append(s)
	return valid

func get_selected_soldiers() -> Array:
	return selected_soldiers

func _get_valid_selected_soldiers() -> Array:
	var valid: Array = []
	for s in selected_soldiers:
		if is_instance_valid(s) and not s.is_dead:
			valid.append(s)
	selected_soldiers = valid
	return selected_soldiers

func get_selected_villagers() -> Array:
	return selected_villagers

func _get_valid_selected_villagers() -> Array:
	var valid: Array = []
	for v in selected_villagers:
		if is_instance_valid(v) and not v.is_dead:
			valid.append(v)
	selected_villagers = valid
	return selected_villagers

func get_all_selected() -> Array:
	return _get_valid_selected_soldiers() + _get_valid_selected_villagers()

# ---------- LINE FORMATION LOGIC ----------

func _calculate_line_points(start_pos: Vector2, end_pos: Vector2, count: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if count <= 0:
		return points

	var nav_map = get_world_2d().navigation_map

	if count == 1:
		var pt = end_pos
		if nav_map.is_valid():
			var valid_pt = NavigationServer2D.map_get_closest_point(nav_map, pt)
			if valid_pt != Vector2.ZERO and valid_pt.distance_to(pt) < 32.0:
				pt = valid_pt
		points.append(pt)
		return points

	for i in range(count):
		var t = float(i) / float(count - 1)
		var p = start_pos.lerp(end_pos, t)
		if nav_map.is_valid():
			var valid_pt = NavigationServer2D.map_get_closest_point(nav_map, p)
			if valid_pt != Vector2.ZERO and valid_pt.distance_to(p) < 32.0:
				p = valid_pt
		points.append(p)

	return points

func _check_line_validity(start_pos: Vector2, end_pos: Vector2, points: Array[Vector2]) -> bool:
	var space_state = get_world_2d().direct_space_state

	# 1. Check direct raycast along the line against Walls layer (mask 2)
	var ray_query = PhysicsRayQueryParameters2D.create(start_pos, end_pos, 2)
	var ray_hit = space_state.intersect_ray(ray_query)
	if not ray_hit.is_empty():
		return false

	# 2. Check points sampled along line for obstacles
	var sample_count = max(2, int(ceil(start_pos.distance_to(end_pos) / 10.0)))
	for i in range(sample_count + 1):
		var sample_p = start_pos.lerp(end_pos, float(i) / float(sample_count))
		if _is_point_blocked(space_state, sample_p):
			return false

	# 3. Check each destination circle point
	for pt in points:
		if _is_point_blocked(space_state, pt):
			return false

	return true

func _is_point_blocked(space_state: PhysicsDirectSpaceState2D, pos: Vector2) -> bool:
	# Physics point query on Layer 2 (Walls)
	var point_query = PhysicsPointQueryParameters2D.new()
	point_query.position = pos
	point_query.collision_mask = 2
	var hits = space_state.intersect_point(point_query, 1)
	if not hits.is_empty():
		return true

	# Check terrain wall cells and occupied building tiles
	if world:
		var terrain = world.get_node_or_null("Terrain")
		if terrain:
			var ground_tilemap = terrain.get_node_or_null("Ground")
			if ground_tilemap and "wall_cells" in terrain:
				var local_p = ground_tilemap.to_local(pos)
				var tile_p = ground_tilemap.local_to_map(local_p)
				if tile_p in terrain.wall_cells:
					return true

		if "building_manager" in world and world.building_manager and "used_tiles" in world.building_manager:
			var b_layer = world.get_node_or_null("Terrain/Buildings")
			var tile_b = b_layer.local_to_map(b_layer.to_local(pos)) if b_layer else Vector2i(pos / 16.0)
			if tile_b in world.building_manager.used_tiles:
				return true

	return false

func _execute_line_formation(start_pos: Vector2, end_pos: Vector2, points: Array[Vector2]) -> void:
	var soldiers = _get_valid_selected_soldiers()
	var villagers = _get_valid_selected_villagers()
	var all_units = soldiers + villagers
	var count = all_units.size()
	if count == 0 or points.is_empty():
		return

	# Calculate line vector and forward perpendicular orientation
	# Start is left flank, End is right flank -> Forward is orthogonal to line
	var line_vec = end_pos - start_pos
	var forward_facing = Vector2(line_vec.y, -line_vec.x).normalized() if line_vec.length() > 1.0 else Vector2.DOWN

	# Sort units along the line projection to prevent cross-walking
	var sorted_units = all_units.duplicate()
	if count > 1 and line_vec.length() > 1.0:
		var line_dir = line_vec.normalized()
		sorted_units.sort_custom(func(a, b):
			var proj_a = (a.global_position - start_pos).dot(line_dir)
			var proj_b = (b.global_position - start_pos).dot(line_dir)
			return proj_a < proj_b
		)

	# Assign each unit to their formation slot
	for i in range(count):
		var target_pt = points[i]
		var u = sorted_units[i]
		if is_instance_valid(u) and not u.is_inventory_empty():
			u.drop_item(-1, true)
		if u.get("is_combat_ready"):
			u.command_move(target_pt, forward_facing)
		else:
			u.assign_task("Move", {"target_position": target_pt})

	_play_squad_voice(sorted_units, "affirmation")

	# Spawn visual feedback marker
	_spawn_action_marker((start_pos + end_pos) * 0.5, Color(0.2, 1.0, 0.4), 8.0)

# ---------- COMMANDS & DEFAULT FORMATIONS ----------

func _play_squad_voice(agents: Array, category: String) -> void:
	if agents.is_empty():
		return
	var current_time = Time.get_ticks_msec()
	if category == "affirmation":
		if current_time - _last_voice_order_time < 350:
			return
		_last_voice_order_time = current_time
	else:
		if current_time - _last_voice_select_time < 350:
			return
		_last_voice_select_time = current_time

	var count = agents.size()
	# Exact squad count: 1 soldier -> 1 voice, 2 soldiers -> 2 voices, 3 or more -> 3 voices
	var num_speakers = min(count, 3)

	var candidates = agents.duplicate()
	candidates.shuffle()

	for i in range(num_speakers):
		var speaker = candidates[i]
		if is_instance_valid(speaker) and speaker.has_method("play_voice"):
			if i == 0:
				speaker.play_voice(category)
			else:
				var delay = randf_range(0.06, 0.11) * i
				get_tree().create_timer(delay, false).timeout.connect(
					func():
						if is_instance_valid(speaker):
							speaker.play_voice(category)
				)

func command_move_selected(target_pos: Vector2) -> void:
	var soldiers = _get_valid_selected_soldiers()
	var count = soldiers.size()
	if count == 0:
		return

	var nav_map = get_world_2d().navigation_map

	for i in range(count):
		var s = soldiers[i]
		if is_instance_valid(s) and not s.is_inventory_empty():
			s.drop_item(-1, true)
		var offset = Vector2.ZERO
		if count > 1:
			var angle = (TAU / count) * i
			offset = Vector2(cos(angle), sin(angle)) * 14.0
		var dest = target_pos + offset
		if nav_map.is_valid():
			var valid_dest = NavigationServer2D.map_get_closest_point(nav_map, dest)
			if valid_dest != Vector2.ZERO and valid_dest.distance_to(dest) < 32.0:
				dest = valid_dest
		s.command_move(dest)

	_play_squad_voice(soldiers, "affirmation")
	_spawn_move_marker(target_pos)

func command_attack_selected(target_enemy: Node2D) -> void:
	var soldiers = _get_valid_selected_soldiers()
	if soldiers.is_empty() or not is_instance_valid(target_enemy):
		return

	for s in soldiers:
		if is_instance_valid(s) and not s.is_inventory_empty():
			s.drop_item(-1, true)
		s.command_attack(target_enemy)

	_play_squad_voice(soldiers, "affirmation")

# ---------- VISUAL FEEDBACK ----------

func _spawn_action_marker(pos: Vector2, color: Color = Color(0.2, 1.0, 0.4, 0.9), radius: float = 6.0) -> void:
	var marker = Node2D.new()
	marker.global_position = pos
	marker.z_index = 100
	add_child(marker)

	var ring = Line2D.new()
	ring.width = 1.8
	ring.default_color = color
	var pts = PackedVector2Array()
	for i in range(17):
		var a = (TAU / 16) * i
		pts.append(Vector2(cos(a) * radius, sin(a) * radius))
	ring.points = pts
	marker.add_child(ring)

	var tween = create_tween()
	tween.tween_property(marker, "scale", Vector2(1.8, 1.8), 0.35)
	tween.parallel().tween_property(ring, "default_color:a", 0.0, 0.35)
	tween.tween_callback(marker.queue_free)

func _spawn_move_marker(pos: Vector2) -> void:
	_spawn_action_marker(pos, Color(0.2, 1.0, 0.4, 0.9), 6.0)

func _spawn_attack_marker(pos: Vector2) -> void:
	_spawn_action_marker(pos, Color(1.0, 0.2, 0.2, 0.95), 8.0)

# ---------- VILLAGER ORDERS (MICROMANAGEMENT) ----------

func command_move_villagers(target_pos: Vector2) -> void:
	var villagers = _get_valid_selected_villagers()
	var count = villagers.size()
	if count == 0:
		return

	var nav_map = get_world_2d().navigation_map

	for i in range(count):
		var v = villagers[i]
		if is_instance_valid(v) and not v.is_inventory_empty():
			v.drop_item(-1, true)
		var offset = Vector2.ZERO
		if count > 1:
			var angle = (TAU / count) * i
			offset = Vector2(cos(angle), sin(angle)) * 14.0
		var dest = target_pos + offset
		if nav_map.is_valid():
			var valid_dest = NavigationServer2D.map_get_closest_point(nav_map, dest)
			if valid_dest != Vector2.ZERO and valid_dest.distance_to(dest) < 32.0:
				dest = valid_dest
		v.assign_task("Move", {"target_position": dest})

	_play_squad_voice(villagers, "affirmation")
	_spawn_action_marker(target_pos, Color(0.2, 1.0, 0.4))

func _execute_villager_order(target_pos: Vector2) -> void:
	var villagers = _get_valid_selected_villagers()
	if villagers.is_empty():
		return

	if not world or not world.has_method("find_context_target_at"):
		command_move_villagers(target_pos)
		return

	var target_data = world.find_context_target_at(target_pos)
	var target_type = target_data.get("type", "ground")

	# Drop carried items on player order unless depositing into storage or equipping at rack
	if target_type != "storage" and target_type != "weapon_rack":
		for v in villagers:
			if is_instance_valid(v) and not v.is_inventory_empty():
				v.drop_item(-1, true)

	match target_type:
		"tree":
			var primary_tree = target_data.get("node")
			if primary_tree and is_instance_valid(primary_tree):
				_dispatch_chop_order(villagers, primary_tree)
		"rock":
			var primary_rock = target_data.get("node")
			if primary_rock and is_instance_valid(primary_rock):
				_dispatch_mine_order(villagers, primary_rock)
		"plant":
			var primary_plant = target_data.get("node")
			if primary_plant and is_instance_valid(primary_plant):
				_dispatch_forage_order(villagers, primary_plant)
		"farm_harvest":
			_dispatch_farm_order(villagers, target_data.get("pos"), "Harvest")
		"farm_water":
			_dispatch_farm_order(villagers, target_data.get("pos"), "Water")
		"farm_plant":
			_dispatch_farm_order(villagers, target_data.get("pos"), "Plant")
		"blueprint":
			var bp = target_data.get("node")
			if bp and is_instance_valid(bp):
				_dispatch_construct_order(villagers, bp)
		"crafting_building":
			var b = target_data.get("node")
			if b and is_instance_valid(b):
				_dispatch_crafting_order(villagers, b)
		"storage":
			var s = target_data.get("node")
			if s and is_instance_valid(s):
				_dispatch_storage_order(villagers, s)
		"ground_item":
			var item = target_data.get("node")
			if item and is_instance_valid(item):
				_dispatch_pickup_order(villagers, item)
		"weapon_rack":
			var rack = target_data.get("node")
			if rack and is_instance_valid(rack):
				_dispatch_rack_order(villagers, rack)
		_:
			command_move_villagers(target_pos)

func _dispatch_chop_order(villagers: Array, primary_tree: Node2D) -> void:
	primary_tree.set("is_marked_for_harvest", true)
	if primary_tree.has_method("set_highlight"):
		primary_tree.set_highlight(true)
	world.reserved_trees[primary_tree] = villagers[0]
	villagers[0].assign_task("Chop", {"target": primary_tree})

	if villagers.size() > 1:
		var nearby_trees: Array = []
		for t in get_tree().get_nodes_in_group("trees"):
			if is_instance_valid(t) and t != primary_tree and not t.is_in_group("saplings") and not t.is_queued_for_deletion():
				if not world.reserved_trees.has(t):
					var dist = t.global_position.distance_to(primary_tree.global_position)
					if dist <= 160.0:
						nearby_trees.append({"tree": t, "dist": dist})
		nearby_trees.sort_custom(func(a, b): return a.dist < b.dist)

		for i in range(1, villagers.size()):
			var v = villagers[i]
			if i - 1 < nearby_trees.size():
				var t = nearby_trees[i - 1].tree
				t.set("is_marked_for_harvest", true)
				if t.has_method("set_highlight"):
					t.set_highlight(true)
				world.reserved_trees[t] = v
				v.assign_task("Chop", {"target": t})
			else:
				var offset = Vector2(cos(i * 1.5), sin(i * 1.5)) * 16.0
				v.assign_task("Move", {"target_position": primary_tree.global_position + offset})

	_spawn_action_marker(primary_tree.global_position, Color(0.9, 0.6, 0.2))
	_play_squad_voice(villagers, "affirmation")

func _dispatch_mine_order(villagers: Array, primary_rock: Node2D) -> void:
	primary_rock.set("is_marked_for_harvest", true)
	if primary_rock.has_method("set_highlight"):
		primary_rock.set_highlight(true)
	world.reserved_rocks[primary_rock] = villagers[0]
	villagers[0].assign_task("Mine", {"target": primary_rock})

	if villagers.size() > 1:
		var nearby_rocks: Array = []
		var rocks = get_tree().get_nodes_in_group("rocks") + get_tree().get_nodes_in_group("ores")
		for r in rocks:
			if is_instance_valid(r) and r != primary_rock and not r.is_queued_for_deletion():
				if not world.reserved_rocks.has(r):
					var dist = r.global_position.distance_to(primary_rock.global_position)
					if dist <= 160.0:
						nearby_rocks.append({"rock": r, "dist": dist})
		nearby_rocks.sort_custom(func(a, b): return a.dist < b.dist)

		for i in range(1, villagers.size()):
			var v = villagers[i]
			if i - 1 < nearby_rocks.size():
				var r = nearby_rocks[i - 1].rock
				r.set("is_marked_for_harvest", true)
				if r.has_method("set_highlight"):
					r.set_highlight(true)
				world.reserved_rocks[r] = v
				v.assign_task("Mine", {"target": r})
			else:
				var offset = Vector2(cos(i * 1.5), sin(i * 1.5)) * 16.0
				v.assign_task("Move", {"target_position": primary_rock.global_position + offset})

	_spawn_action_marker(primary_rock.global_position, Color(0.75, 0.75, 0.85))
	_play_squad_voice(villagers, "affirmation")

func _dispatch_forage_order(villagers: Array, primary_plant: Node2D) -> void:
	primary_plant.set("is_marked_for_harvest", true)
	if primary_plant.has_method("set_highlight"):
		primary_plant.set_highlight(true)
	world.reserved_forages[primary_plant] = villagers[0]
	villagers[0].assign_task("Forage", {"target": primary_plant})

	if villagers.size() > 1:
		var nearby_plants: Array = []
		for p in get_tree().get_nodes_in_group("plants"):
			if is_instance_valid(p) and p != primary_plant and not p.is_queued_for_deletion():
				if not world.reserved_forages.has(p):
					var dist = p.global_position.distance_to(primary_plant.global_position)
					if dist <= 160.0:
						nearby_plants.append({"plant": p, "dist": dist})
		nearby_plants.sort_custom(func(a, b): return a.dist < b.dist)

		for i in range(1, villagers.size()):
			var v = villagers[i]
			if i - 1 < nearby_plants.size():
				var p = nearby_plants[i - 1].plant
				p.set("is_marked_for_harvest", true)
				if p.has_method("set_highlight"):
					p.set_highlight(true)
				world.reserved_forages[p] = v
				v.assign_task("Forage", {"target": p})
			else:
				var offset = Vector2(cos(i * 1.5), sin(i * 1.5)) * 16.0
				v.assign_task("Move", {"target_position": primary_plant.global_position + offset})

	_spawn_action_marker(primary_plant.global_position, Color(0.3, 0.9, 0.4))
	_play_squad_voice(villagers, "affirmation")

func _dispatch_farm_order(villagers: Array, start_tile: Vector2i, task_name: String) -> void:
	var color = Color(1.0, 0.85, 0.2)
	if task_name == "Water":
		color = Color(0.2, 0.7, 1.0)
	elif task_name == "Plant":
		color = Color(0.4, 0.9, 0.2)

	_assign_single_farm_task(villagers[0], start_tile, task_name)

	if villagers.size() > 1:
		var candidates: Array[Vector2i] = []
		if task_name == "Harvest":
			for pos in world.crops_dic.keys():
				if pos != start_tile and not world.reserved_harvest.has(pos):
					if world.crops.get_cell_source_id(pos) != -1 and world.crops_dic[pos].get("duration", 0.0) < 0:
						candidates.append(pos)
		elif task_name == "Water":
			for pos in world.water_level.keys():
				if pos != start_tile and not world.reserved_water.has(pos):
					if world.water_level[pos] < 5.0:
						candidates.append(pos)
		elif task_name == "Plant":
			for pos in world.water_level.keys():
				if pos != start_tile and not world.reserved_plant.has(pos):
					if world.water_level[pos] > 1.0 and not world.crops_dic.has(pos):
						candidates.append(pos)

		candidates.sort_custom(func(a, b): return (a - start_tile).length_squared() < (b - start_tile).length_squared())

		for i in range(1, villagers.size()):
			var v = villagers[i]
			if i - 1 < candidates.size():
				_assign_single_farm_task(v, candidates[i - 1], task_name)
			else:
				var world_p = world.get_world_position(start_tile) + Vector2(8, 8)
				var offset = Vector2(cos(i * 1.5), sin(i * 1.5)) * 16.0
				v.assign_task("Move", {"target_position": world_p + offset})

	var marker_pos = world.get_world_position(start_tile) + Vector2(8, 8)
	_spawn_action_marker(marker_pos, color)
	_play_squad_voice(villagers, "affirmation")

func _assign_single_farm_task(v: CharacterBody2D, tile: Vector2i, task_name: String) -> void:
	if task_name == "Harvest":
		world.reserved_harvest[tile] = v
		v.assign_task("Harvest", {"pos": tile})
	elif task_name == "Water":
		world.reserved_water[tile] = v
		v.assign_task("Water", {"pos": tile})
	elif task_name == "Plant":
		world.reserved_plant[tile] = v
		v.assign_task("Plant", {"pos": tile})

func _dispatch_construct_order(villagers: Array, bp: Blueprint) -> void:
	for v in villagers:
		var assigned = world._try_assign_delivery(bp, "Construct", [v])
		if not assigned:
			v.assign_task("Move", {"target_position": bp.global_position})
	_spawn_action_marker(bp.global_position, Color(0.2, 0.85, 0.95))
	_play_squad_voice(villagers, "affirmation")

func _dispatch_crafting_order(villagers: Array, b: Node2D) -> void:
	var primary = villagers[0]
	if b.get("output_inventory") and not b.output_inventory.is_empty():
		world.reserved_outputs[b] = primary
		primary.assign_task("CollectOutput", {"building": b})
	elif b.get("is_crafting") and b.get("active_recipe") and b.active_recipe.get("need_clayling") and not b.get("worker_present"):
		world.reserved_work[b] = primary
		primary.assign_task("Work", {"building": b})
	else:
		world._try_assign_delivery(b, "Deliver", [primary])

	for i in range(1, villagers.size()):
		var v = villagers[i]
		var offset = Vector2(cos(i * 1.5), sin(i * 1.5)) * 18.0
		v.assign_task("Move", {"target_position": b.global_position + offset})

	_spawn_action_marker(b.global_position, Color(1.0, 0.6, 0.1))
	_play_squad_voice(villagers, "affirmation")

func _dispatch_storage_order(villagers: Array, s: Node2D) -> void:
	for v in villagers:
		if not v.is_inventory_empty():
			v.assign_task("Haul", {"storage": s})
		else:
			v.assign_task("Move", {"target_position": s.global_position})
	_spawn_action_marker(s.global_position, Color(0.8, 0.6, 0.4))
	_play_squad_voice(villagers, "affirmation")

func _dispatch_pickup_order(villagers: Array, primary_item: Node2D) -> void:
	world.reserved_pickups[primary_item] = villagers[0]
	villagers[0].assign_task("Pick up", {"node": primary_item})

	if villagers.size() > 1:
		var items = get_tree().get_nodes_in_group("ground_items")
		var nearby_items: Array = []
		for it in items:
			if is_instance_valid(it) and it != primary_item and it.visible and it.quantity > 0:
				if not world.reserved_pickups.has(it):
					var dist = it.global_position.distance_to(primary_item.global_position)
					if dist <= 160.0:
						nearby_items.append({"item": it, "dist": dist})
		nearby_items.sort_custom(func(a, b): return a.dist < b.dist)

		for i in range(1, villagers.size()):
			var v = villagers[i]
			if i - 1 < nearby_items.size():
				var it = nearby_items[i - 1].item
				world.reserved_pickups[it] = v
				v.assign_task("Pick up", {"node": it})
			else:
				var offset = Vector2(cos(i * 1.5), sin(i * 1.5)) * 14.0
				v.assign_task("Move", {"target_position": primary_item.global_position + offset})

	_spawn_action_marker(primary_item.global_position, Color(1.0, 0.9, 0.2))
	_play_squad_voice(villagers, "affirmation")

func _dispatch_rack_order(villagers: Array, rack: Node2D) -> void:
	for v in villagers:
		if rack.has_method("find_available_kit_index") and rack.find_available_kit_index() != -1:
			if rack.has_method("reserve_equip"):
				rack.reserve_equip(v)
			v.assign_task("Equip", {"target": rack})
		else:
			v.assign_task("Move", {"target_position": rack.global_position})
	_spawn_action_marker(rack.global_position, Color(0.7, 0.3, 0.9))
	_play_squad_voice(villagers, "affirmation")

# ---------- CALL TO ARMS & CALL TO WORK ----------

func trigger_call_to_arms() -> void:
	call_to_arms_triggered.emit()
	var racks = get_tree().get_nodes_in_group("weapon_racks")
	var active_claylings = world.active_claylings if world and "active_claylings" in world else get_tree().get_nodes_in_group("claylings")

	var candidates: Array = []
	for c in active_claylings:
		if is_instance_valid(c) and not c.get("is_dead"):
			var is_equipping = (c.current_state == c.states.get("Equip"))
			if not c.is_combat_ready and not is_equipping:
				candidates.append(c)

	for rack in racks:
		if not is_instance_valid(rack):
			continue
		var available_kits = rack.get_available_kit_count_unreserved() if rack.has_method("get_available_kit_count_unreserved") else rack.get_completed_kit_count()
		if available_kits <= 0:
			continue

		for i in range(available_kits):
			if candidates.is_empty():
				return

			var best_candidate = _get_nearest_node(rack.global_position, candidates)
			if best_candidate:
				if rack.has_method("reserve_equip"):
					rack.reserve_equip(best_candidate)
				best_candidate.assign_task("Equip", {"target": rack})
				candidates.erase(best_candidate)

func trigger_call_to_work() -> void:
	call_to_work_triggered.emit()
	var racks = get_tree().get_nodes_in_group("weapon_racks")
	var soldiers = get_tree().get_nodes_in_group("soldiers")

	# If soldiers are currently selected, demobilize selected ones; otherwise demobilize all
	var target_soldiers: Array = []
	var valid_selected = _get_valid_selected_soldiers()
	if valid_selected.size() > 0:
		target_soldiers = valid_selected.duplicate()
	else:
		for s in soldiers:
			if is_instance_valid(s) and not s.get("is_dead") and (s.get("is_combat_ready") or s.get("role") != "villager"):
				var is_unequipping = ("states" in s and s.current_state == s.states.get("Unequip"))
				if not is_unequipping:
					target_soldiers.append(s)

	if target_soldiers.is_empty():
		return

	for s in target_soldiers:
		if "states" in s and s.current_state == s.states.get("Unequip"):
			continue

		var soldier_kit = s.get("equipped_kit")
		var best_rack: Node2D = null
		var best_dist_sq: float = INF

		# Search for nearest rack with unreserved capacity for this kit
		for rack in racks:
			if is_instance_valid(rack):
				var can_accept = false
				if rack.has_method("can_accept_kit_unreserved"):
					can_accept = rack.can_accept_kit_unreserved(soldier_kit)
				elif rack.has_method("has_empty_slot"):
					can_accept = rack.has_empty_slot()

				if can_accept:
					var d_sq = s.global_position.distance_squared_to(rack.global_position)
					if d_sq < best_dist_sq:
						best_dist_sq = d_sq
						best_rack = rack

		# Only send soldier to unequip if an available rack has space for this kit
		if best_rack:
			if best_rack.has_method("reserve_unequip_slot"):
				best_rack.reserve_unequip_slot(s, soldier_kit)
			if selected_soldiers.has(s):
				s.set_selected(false)
				selected_soldiers.erase(s)
			s.change_state("Unequip", {"target_rack": best_rack})

func _get_nearest_node(pos: Vector2, nodes: Array) -> Node2D:
	var nearest: Node2D = null
	var nearest_d: float = INF
	for n in nodes:
		if not is_instance_valid(n):
			continue
		var d = pos.distance_to(n.global_position)
		if d < nearest_d:
			nearest = n
			nearest_d = d
	return nearest

# ---------- INPUT HANDLING ----------

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and is_demolish_mode:
			set_demolish_mode(false)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("call_to_arms"):
			trigger_call_to_arms()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("call_to_work"):
			trigger_call_to_work()
			get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if is_demolish_mode:
			set_demolish_mode(false)
			get_viewport().set_input_as_handled()
			return

	# Global drag tracking for RTS box selection (Left-click)
	if is_box_selecting:
		if event is InputEventMouseMotion:
			selection_end = get_global_mouse_position()
			queue_redraw()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			is_box_selecting = false
			selection_end = get_global_mouse_position()
			queue_redraw()

			var drag_dist = selection_start.distance_to(selection_end)
			if drag_dist >= 8.0:
				var rect = Rect2(selection_start, selection_end - selection_start).abs()
				if is_demolish_mode:
					_demolish_buildings_in_rect(rect)
				else:
					select_claylings_in_rect(rect)
				get_viewport().set_input_as_handled()

	# Global drag tracking for RTS line formation (Right-click)
	if is_line_drawing:
		if event is InputEventMouseMotion:
			line_end = get_global_mouse_position()
			var total_units = _get_valid_selected_soldiers().size() + _get_valid_selected_villagers().size()
			line_points = _calculate_line_points(line_start, line_end, total_units)
			is_line_valid = _check_line_validity(line_start, line_end, line_points)
			queue_redraw()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			is_line_drawing = false
			line_end = get_global_mouse_position()
			queue_redraw()

			var drag_dist = line_start.distance_to(line_end)
			var soldiers = _get_valid_selected_soldiers()
			var villagers = _get_valid_selected_villagers()

			if drag_dist >= 12.0:
				var total_units = soldiers.size() + villagers.size()
				line_points = _calculate_line_points(line_start, line_end, total_units)
				is_line_valid = _check_line_validity(line_start, line_end, line_points)

				if is_line_valid:
					_execute_line_formation(line_start, line_end, line_points)
			else:
				if soldiers.size() > 0:
					var clicked_target: Node2D = null
					var candidates: Array = []
					candidates.append_array(get_tree().get_nodes_in_group("enemies"))
					candidates.append_array(get_tree().get_nodes_in_group("animals"))

					var min_dist: float = 24.0
					for target in candidates:
						if is_instance_valid(target) and not target.get("is_dead"):
							var d = target.global_position.distance_to(line_start)
							if d < min_dist:
								min_dist = d
								clicked_target = target

					if clicked_target:
						command_attack_selected(clicked_target)
						_spawn_attack_marker(clicked_target.global_position)
					else:
						command_move_selected(line_start)

				if villagers.size() > 0:
					_execute_villager_order(line_start)

			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_pos = get_global_mouse_position()

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				selection_start = mouse_pos
				selection_end = mouse_pos
				is_box_selecting = true
			else:
				# Single click selection or single click demolition
				if is_demolish_mode:
					_demolish_buildings_at_point(mouse_pos)
					get_viewport().set_input_as_handled()
				else:
					var clicked_clayling = null
					var best_dist = 18.0
					for c in get_tree().get_nodes_in_group("claylings"):
						if is_instance_valid(c) and not c.get("is_dead"):
							var body_center = c.global_position + Vector2(0, -7)
							var d = body_center.distance_to(mouse_pos)
							if d < best_dist:
								best_dist = d
								clicked_clayling = c

					if clicked_clayling:
						if clicked_clayling.get("is_combat_ready"):
							select_soldier(clicked_clayling)
						else:
							select_villager(clicked_clayling)
						var clayling_ui = get_tree().get_first_node_in_group("clayling_info_panel")
						if clayling_ui and clayling_ui.has_method("show_clayling"):
							clayling_ui.show_clayling(clicked_clayling)
						get_viewport().set_input_as_handled()
					else:
						if not is_box_selecting and (selected_soldiers.size() > 0 or selected_villagers.size() > 0):
							deselect_all()

		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if is_demolish_mode:
				set_demolish_mode(false)
				get_viewport().set_input_as_handled()
				return

			var total_units = _get_valid_selected_soldiers().size() + _get_valid_selected_villagers().size()
			if total_units > 0:
				is_line_drawing = true
				line_start = mouse_pos
				line_end = mouse_pos
				line_points = _calculate_line_points(line_start, line_end, total_units)
				is_line_valid = _check_line_validity(line_start, line_end, line_points)
				queue_redraw()
				get_viewport().set_input_as_handled()

# ---------- DEMOLITION LOGIC ----------

func _is_demolishable_building(node: Node) -> bool:
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return false
	if node.get("is_preview"):
		return false
	if node.is_in_group("crystal") or node.is_in_group("central_crystal"):
		return false
	if node.is_in_group("trees") or node.is_in_group("rocks") or node.is_in_group("ores") or node.is_in_group("plants") or node.is_in_group("saplings"):
		return false
	if node is Blueprint or node is Building:
		return true
	if node.is_in_group("crafting_buildings") or node.is_in_group("storage") or node.is_in_group("walls") or node.is_in_group("gates") or node.is_in_group("weapon_racks"):
		return true
	return false

func _get_all_demolishable_candidates() -> Array:
	var list: Array = []
	var groups_to_check = ["crafting_buildings", "storage", "walls", "gates", "weapon_racks"]
	for g in groups_to_check:
		for n in get_tree().get_nodes_in_group(g):
			if not list.has(n) and _is_demolishable_building(n):
				list.append(n)

	var main_node = get_tree().get_first_node_in_group("main")
	if main_node:
		for child in main_node.get_children():
			if not list.has(child) and _is_demolishable_building(child):
				list.append(child)

	return list

func _demolish_buildings_in_rect(rect: Rect2) -> void:
	var candidates = _get_all_demolishable_candidates()
	var destroyed_count = 0
	for b in candidates:
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			continue

		var size_tiles = b.size_in_tiles if "size_in_tiles" in b else Vector2i(1, 1)
		var offset = Vector2((size_tiles.x * 16.0) / 2.0, size_tiles.y * 16.0)
		var b_rect = Rect2(b.global_position - offset, Vector2(size_tiles.x * 16.0, size_tiles.y * 16.0))

		if rect.intersects(b_rect) or rect.has_point(b.global_position):
			if b.has_method("destroyed"):
				b.destroyed()
			else:
				b.queue_free()
			destroyed_count += 1

	if destroyed_count > 0:
		SoundManager.play("rock break", 0.1)

func _demolish_buildings_at_point(pos: Vector2) -> void:
	var candidates = _get_all_demolishable_candidates()
	var closest_b: Node2D = null
	var closest_dist: float = 24.0

	for b in candidates:
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			continue

		var size_tiles = b.size_in_tiles if "size_in_tiles" in b else Vector2i(1, 1)
		var offset = Vector2((size_tiles.x * 16.0) / 2.0, size_tiles.y * 16.0)
		var b_rect = Rect2(b.global_position - offset, Vector2(size_tiles.x * 16.0, size_tiles.y * 16.0))

		if b_rect.has_point(pos):
			closest_b = b
			break

		var d = b.global_position.distance_to(pos)
		if d < closest_dist:
			closest_dist = d
			closest_b = b

	if closest_b:
		if closest_b.has_method("destroyed"):
			closest_b.destroyed()
		else:
			closest_b.queue_free()
		SoundManager.play("rock break", 0.1)
