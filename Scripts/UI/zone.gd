extends Node2D

# ========== SETTINGS ==========
@export var radius: float = 60.0
@export var min_radius: float = 50.0
@export var max_radius: float = 300.0

@export var rock_icon: Texture2D
@export var tree_icon: Texture2D
@export var plant_icon: Texture2D
@export var metal_icon: Texture2D

var available_targets = ["rocks", "trees", "plants", "ores"]
var current_target_index = 0
var target_to_icon_map = {}

# ========== INTERNAL ==========
var is_placing: bool = true
var is_dragging_center: bool = false
var is_resizing: bool = false
var drag_offset: Vector2 = Vector2.ZERO

var menu_inner_radius: float = 8.0
var menu_outer_radius: float = 30.0
var hovered_slice: int = -1

var is_menu_open: bool = false 
var marked_nodes: Array = []
var highlighted_nodes: Array = [] 

func _ready():
	z_index = 50
	add_to_group("harvest_zones") 
	
	target_to_icon_map = {
		"rocks": rock_icon,
		"trees": tree_icon,
		"plants": plant_icon,
		"ores": metal_icon
	}

func _exit_tree():
	clear_preview() 
	
	for node in marked_nodes:
		if is_instance_valid(node):
			node.is_marked_for_harvest = false

func _process(_delta):
	if is_placing:
		global_position = get_global_mouse_position()
	elif is_dragging_center:
		global_position = get_global_mouse_position() + drag_offset
	elif is_resizing:
		var local_mouse = get_local_mouse_position()
		radius = clamp(local_mouse.length(), min_radius, max_radius)
	else:
		var local_mouse = get_local_mouse_position()
		var dist = local_mouse.length()
		
		var is_closest_zone = true
		var global_mouse = get_global_mouse_position()
		var my_dist = global_position.distance_to(global_mouse)
		
		for zone in get_tree().get_nodes_in_group("harvest_zones"):
			if zone != self and is_instance_valid(zone) and not zone.is_placing:
				if zone.global_position.distance_to(global_mouse) < my_dist:
					is_closest_zone = false
					break
		
		if not is_closest_zone:
			is_menu_open = false
		else:
			if not is_menu_open and dist <= 12.0:
				is_menu_open = true
			elif is_menu_open and dist > menu_outer_radius * 1.2:
				is_menu_open = false
			
		if is_menu_open:
			if dist > menu_inner_radius and dist <= menu_outer_radius:
				var angle = local_mouse.angle()
				if angle < 0: angle += TAU
				var slice_angle = TAU / available_targets.size()
				hovered_slice = int(angle / slice_angle) % available_targets.size()
			else:
				hovered_slice = -1
		else:
			hovered_slice = -1

	queue_redraw()

	# --- LIVE PREVIEW ---
	var is_interacting = is_placing or is_dragging_center or is_resizing or is_menu_open
	if is_interacting:
		update_preview()
	elif highlighted_nodes.size() > 0:
		clear_preview()

# ---------- DRAWING ----------
func _draw():
	if is_placing or is_dragging_center:
		draw_circle(Vector2.ZERO, radius, Color(1.0, 1.0, 1.0, 0.15))

	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color.WHITE, 2.0)
	
	var local_mouse = get_local_mouse_position()
	if not is_placing and (abs(local_mouse.length() - radius) < 15.0 or is_resizing):
		var handle_pos = Vector2.RIGHT * radius
		if local_mouse.length() > 0:
			handle_pos = local_mouse.normalized() * radius
		draw_circle(handle_pos, 5.0, Color.WHITE)

	draw_circle(Vector2.ZERO, 4.0, Color.WHITE)
	
	if is_menu_open and not is_placing and not is_dragging_center and not is_resizing:
		var slice_count = available_targets.size()
		var slice_angle = TAU / slice_count
		
		var half_gap: float = 1.0
		var gap_out: float = half_gap / menu_outer_radius
		var gap_in: float = half_gap / menu_inner_radius

		for i in range(slice_count):
			var start_a = i * slice_angle
			var end_a = (i + 1) * slice_angle
			var a1_out = start_a + gap_out
			var a2_out = end_a - gap_out
			var a1_in = start_a + gap_in
			var a2_in = end_a - gap_in
			
			var poly_color = Color(0.1, 0.1, 0.1, 0.85)
			if i == current_target_index:
				poly_color = Color(0.2, 0.2, 0.2, 0.95)
			
			var points = PackedVector2Array()
			var resolution = 16
			for j in range(resolution + 1):
				var t = j / float(resolution)
				var cur_angle = lerp(a1_out, a2_out, t)
				points.append(Vector2(cos(cur_angle), sin(cur_angle)) * menu_outer_radius)
			for j in range(resolution + 1):
				var t = j / float(resolution)
				var cur_angle = lerp(a2_in, a1_in, t)
				points.append(Vector2(cos(cur_angle), sin(cur_angle)) * menu_inner_radius)
				
			draw_polygon(points, PackedColorArray([poly_color]))

			var target_key = available_targets[i]
			var texture = target_to_icon_map.get(target_key)
			if texture:
				var mid_a = (start_a + end_a) / 2.0
				var mid_r = (menu_inner_radius + menu_outer_radius) / 2.0
				var icon_center = Vector2(cos(mid_a), sin(mid_a)) * mid_r
				var icon_color = Color(0.5, 0.5, 0.5, 0.6)
				if i == current_target_index: icon_color = Color(1.0, 1.0, 1.0, 0.95)
				if i == hovered_slice: icon_color = Color(1.0, 1.0, 1.0, 1.0)
				
				var offset = texture.get_size() / 2.0
				draw_texture(texture, icon_center - offset, icon_color)

# ---------- MOUSE INTERACTIONS ----------
func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton:
		
		var is_closest_zone = true
		var global_mouse = get_global_mouse_position()
		var my_dist = global_position.distance_to(global_mouse)
		for zone in get_tree().get_nodes_in_group("harvest_zones"):
			if zone != self and is_instance_valid(zone) and not zone.is_placing:
				if zone.global_position.distance_to(global_mouse) < my_dist:
					is_closest_zone = false
					break
		
		if not is_placing and not is_closest_zone:
			return

		var local_mouse = get_local_mouse_position()
		var dist_to_center = local_mouse.length()

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if is_placing:
					is_placing = false
					mark_resources()
					get_viewport().set_input_as_handled()
				else:
					if hovered_slice != -1 and is_menu_open:
						current_target_index = hovered_slice
						mark_resources()
						get_viewport().set_input_as_handled()
						return
					
					var handle_pos = Vector2(radius, 0)
					if dist_to_center > 0: handle_pos = local_mouse.normalized() * radius
					
					if local_mouse.distance_to(handle_pos) < 15.0:
						is_resizing = true
						get_viewport().set_input_as_handled()
					elif dist_to_center <= 6.0:
						is_dragging_center = true
						drag_offset = global_position - get_global_mouse_position()
						get_viewport().set_input_as_handled()
			else:
				if is_resizing or is_dragging_center:
					is_resizing = false
					is_dragging_center = false
					mark_resources()

		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if is_placing or dist_to_center <= 15.0: 
				queue_free()

# ---------- GAME LOGIC ----------
func mark_resources():
	for node in marked_nodes:
		if is_instance_valid(node):
			node.is_marked_for_harvest = false
	marked_nodes.clear()
	
	var current_group = available_targets[current_target_index]
	var nodes = get_tree().get_nodes_in_group(current_group)
	
	for node in nodes:
		if "is_marked_for_harvest" in node:
			var dist = global_position.distance_to(node.global_position)
			if dist <= radius:
				node.is_marked_for_harvest = true
				marked_nodes.append(node) 

# ---------- VISUAL PREVIEW ----------
func update_preview():
	clear_preview()
	var target_idx = current_target_index
	if hovered_slice != -1: target_idx = hovered_slice
		
	var current_group = available_targets[target_idx]
	var nodes = get_tree().get_nodes_in_group(current_group)
	
	for node in nodes:
		if is_instance_valid(node):
			if global_position.distance_to(node.global_position) <= radius:
				if node.has_method("set_highlight"):
					node.set_highlight(true)
					highlighted_nodes.append(node)

func clear_preview():
	for node in highlighted_nodes:
		if is_instance_valid(node) and node.has_method("set_highlight"):
			node.set_highlight(false)
	highlighted_nodes.clear()
