extends Node2D
class_name RTSController

# ========== REFERENCES ==========

@onready var world: Node2D = $".."

# ========== VARIABLES ==========

var selected_soldiers: Array = []

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

# ========== SIGNALS ==========

signal call_to_arms_triggered
signal call_to_work_triggered

# ========== FUNCTIONS ==========

func _ready() -> void:
	add_to_group("rts_controller")
	z_index = 100

func _draw() -> void:
	# 1. Draw Box Selection (Left-click)
	if is_box_selecting:
		var start = to_local(selection_start)
		var end = to_local(selection_end)
		var rect = Rect2(start, end - start).abs()
		if rect.size.length() > 4.0:
			draw_rect(rect, Color(1.0, 1.0, 1.0, 0.12), true)
			draw_rect(rect, Color(1.0, 1.0, 1.0, 0.95), false, 2.5)

	# 2. Draw Line Formation (Right-click)
	if is_line_drawing and selected_soldiers.size() > 0:
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
		deselect_all_soldiers()
	if is_instance_valid(soldier) and not selected_soldiers.has(soldier):
		selected_soldiers.append(soldier)
		soldier.set_selected(true)
		_play_squad_voice([soldier], "interrogation")

func deselect_all_soldiers() -> void:
	for s in selected_soldiers:
		if is_instance_valid(s):
			s.set_selected(false)
	selected_soldiers.clear()

func select_soldiers_in_rect(rect: Rect2, add_to_selection: bool = false) -> void:
	if not add_to_selection:
		deselect_all_soldiers()
	var all_soldiers = get_tree().get_nodes_in_group("soldiers")
	var newly_selected: Array = []
	for s in all_soldiers:
		if is_instance_valid(s) and not s.is_dead:
			if rect.has_point(s.global_position):
				if not selected_soldiers.has(s):
					selected_soldiers.append(s)
					s.set_selected(true)
					newly_selected.append(s)
	if newly_selected.size() > 0:
		_play_squad_voice(selected_soldiers, "interrogation")

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
	var count = soldiers.size()
	if count == 0 or points.is_empty():
		return

	# Calculate line vector and forward perpendicular orientation
	# Start is left flank, End is right flank -> Forward is orthogonal to line
	var line_vec = end_pos - start_pos
	var forward_facing = Vector2(line_vec.y, -line_vec.x).normalized() if line_vec.length() > 1.0 else Vector2.DOWN

	# Sort soldiers along the line projection to prevent cross-walking
	var sorted_soldiers = soldiers.duplicate()
	if count > 1 and line_vec.length() > 1.0:
		var line_dir = line_vec.normalized()
		sorted_soldiers.sort_custom(func(a, b):
			var proj_a = (a.global_position - start_pos).dot(line_dir)
			var proj_b = (b.global_position - start_pos).dot(line_dir)
			return proj_a < proj_b
		)

	# Assign each soldier to their formation slot with target facing direction
	for i in range(count):
		var target_pt = points[i]
		sorted_soldiers[i].command_move(target_pt, forward_facing)

	_play_squad_voice(sorted_soldiers, "affirmation")

	# Spawn visual feedback marker
	_spawn_move_marker((start_pos + end_pos) * 0.5)

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
		var offset = Vector2.ZERO
		if count > 1:
			var angle = (TAU / count) * i
			offset = Vector2(cos(angle), sin(angle)) * 14.0
		var dest = target_pos + offset
		if nav_map.is_valid():
			var valid_dest = NavigationServer2D.map_get_closest_point(nav_map, dest)
			if valid_dest != Vector2.ZERO and valid_dest.distance_to(dest) < 32.0:
				dest = valid_dest
		soldiers[i].command_move(dest)

	_play_squad_voice(soldiers, "affirmation")
	_spawn_move_marker(target_pos)

func command_attack_selected(target_enemy: Node2D) -> void:
	var soldiers = _get_valid_selected_soldiers()
	if soldiers.is_empty() or not is_instance_valid(target_enemy):
		return

	for s in soldiers:
		s.command_attack(target_enemy)

	_play_squad_voice(soldiers, "affirmation")

# ---------- VISUAL FEEDBACK ----------

func _spawn_move_marker(pos: Vector2) -> void:
	var marker = Node2D.new()
	marker.global_position = pos
	marker.z_index = 100
	add_child(marker)

	var ring = Line2D.new()
	ring.width = 1.5
	ring.default_color = Color(0.2, 1.0, 0.4, 0.9)
	var pts = PackedVector2Array()
	for i in range(17):
		var a = (TAU / 16) * i
		pts.append(Vector2(cos(a) * 6.0, sin(a) * 6.0))
	ring.points = pts
	marker.add_child(ring)

	var tween = create_tween()
	tween.tween_property(marker, "scale", Vector2(1.8, 1.8), 0.35)
	tween.parallel().tween_property(ring, "default_color:a", 0.0, 0.35)
	tween.tween_callback(marker.queue_free)

func _spawn_attack_marker(pos: Vector2) -> void:
	var marker = Node2D.new()
	marker.global_position = pos
	marker.z_index = 100
	add_child(marker)

	var ring = Line2D.new()
	ring.width = 2.0
	ring.default_color = Color(1.0, 0.2, 0.2, 0.95)
	var pts = PackedVector2Array()
	for i in range(17):
		var a = (TAU / 16) * i
		pts.append(Vector2(cos(a) * 8.0, sin(a) * 8.0))
	ring.points = pts
	marker.add_child(ring)

	var tween = create_tween()
	tween.tween_property(marker, "scale", Vector2(1.8, 1.8), 0.35)
	tween.parallel().tween_property(ring, "default_color:a", 0.0, 0.35)
	tween.tween_callback(marker.queue_free)

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
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_X:
			trigger_call_to_arms()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Z:
			trigger_call_to_work()
			get_viewport().set_input_as_handled()

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
				select_soldiers_in_rect(rect)
				get_viewport().set_input_as_handled()

	# Global drag tracking for RTS line formation (Right-click)
	if is_line_drawing:
		if event is InputEventMouseMotion:
			line_end = get_global_mouse_position()
			var soldiers = _get_valid_selected_soldiers()
			line_points = _calculate_line_points(line_start, line_end, soldiers.size())
			is_line_valid = _check_line_validity(line_start, line_end, line_points)
			queue_redraw()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			is_line_drawing = false
			line_end = get_global_mouse_position()
			queue_redraw()

			var drag_dist = line_start.distance_to(line_end)
			var soldiers = _get_valid_selected_soldiers()

			if drag_dist >= 12.0:
				# Line formation requested
				line_points = _calculate_line_points(line_start, line_end, soldiers.size())
				is_line_valid = _check_line_validity(line_start, line_end, line_points)

				if is_line_valid:
					_execute_line_formation(line_start, line_end, line_points)
				# If not valid (blocked by wall), the order is cancelled automatically!
			else:
				# Check if clicked directly on an enemy or animal (e.g. chickens)
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
					# Simple right-click point move
					command_move_selected(line_start)

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
				# Single click selection
				var clicked_soldier = null
				for s in get_tree().get_nodes_in_group("soldiers"):
					if is_instance_valid(s) and not s.is_dead and s.global_position.distance_to(mouse_pos) < 18.0:
						clicked_soldier = s
						break

				if clicked_soldier:
					select_soldier(clicked_soldier)
					var clayling_ui = get_tree().get_first_node_in_group("clayling_info_panel")
					if clayling_ui and clayling_ui.has_method("show_clayling"):
						clayling_ui.show_clayling(clicked_soldier)
					get_viewport().set_input_as_handled()
				else:
					if not is_box_selecting and selected_soldiers.size() > 0:
						deselect_all_soldiers()

		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var soldiers = _get_valid_selected_soldiers()
			if soldiers.size() > 0:
				is_line_drawing = true
				line_start = mouse_pos
				line_end = mouse_pos
				line_points = _calculate_line_points(line_start, line_end, soldiers.size())
				is_line_valid = _check_line_validity(line_start, line_end, line_points)
				queue_redraw()
				get_viewport().set_input_as_handled()
