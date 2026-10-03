extends Node2D

# ========== VARIABLES ==========

var building: CraftingBuilding
var menu_inner_radius: float = 14.0
var menu_outer_radius: float = 36.0
var hovered_slice: int = -1

@onready var queue_container: HBoxContainer = $QueueContainer
@onready var repeat_checkbox: CheckBox = $RepeatCheckbox

# ========== FUNCTIONS ==========

func _ready():
	z_index = 100
	hide()
	repeat_checkbox.toggled.connect(_on_repeat_toggled)
	
	repeat_checkbox.toggled.connect(func(toggled_on): if building:building.repeat_infinite = toggled_on)
	
	queue_container.alignment = BoxContainer.ALIGNMENT_CENTER
	queue_container.mouse_filter = Control.MOUSE_FILTER_PASS

func open(target_building: CraftingBuilding):
	building = target_building
	global_position = building.global_position + building.menu_offset 
	
	repeat_checkbox.set_pressed_no_signal(building.repeat_infinite)
	
	if not building.queue_changed.is_connected(update_queue_ui):
		building.queue_changed.connect(update_queue_ui)
		
	show()
	update_queue_ui()

func _process(_delta):
	if not visible or building == null or building.available_recipes.is_empty():
		return

	var local_mouse = get_local_mouse_position()
	var dist = local_mouse.length()

	if dist > menu_inner_radius and dist <= menu_outer_radius:
		var angle = local_mouse.angle()
		if angle < 0: angle += TAU
		var slice_angle = TAU / building.available_recipes.size()
		hovered_slice = int(angle / slice_angle) % building.available_recipes.size()
	else:
		hovered_slice = -1

	queue_redraw()

func is_mouse_over_menu() -> bool:
	var local_mouse = get_local_mouse_position()
	
	if local_mouse.length() <= menu_outer_radius:
		return true
		
	if queue_container.get_rect().has_point(local_mouse):
		return true
		
	if repeat_checkbox.get_rect().has_point(local_mouse):
		return true
	
	return false

# ---------- DRAWING ----------

func _draw():
	if building == null or building.available_recipes.is_empty():
		return
		
	var recipes = building.available_recipes
	var slice_count = recipes.size()
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
		if i == hovered_slice: 
			poly_color = Color(0.2, 0.2, 0.2, 0.95)
		
		var points = PackedVector2Array()
		var res = 16
		for j in range(res + 1):
			var t = j / float(res)
			var cur_angle = lerp(a1_out, a2_out, t)
			points.append(Vector2(cos(cur_angle), sin(cur_angle)) * menu_outer_radius)
		for j in range(res + 1):
			var t = j / float(res)
			var cur_angle = lerp(a2_in, a1_in, t)
			points.append(Vector2(cos(cur_angle), sin(cur_angle)) * menu_inner_radius)
			
		draw_polygon(points, PackedColorArray([poly_color]))

		var recipe = recipes[i]
		if recipe.output_item and "icon" in recipe.output_item and recipe.output_item.icon:
			var texture = recipe.output_item.icon
			var mid_a = (start_a + end_a) / 2.0
			var mid_r = (menu_inner_radius + menu_outer_radius) / 2.0
			var icon_center = Vector2(cos(mid_a), sin(mid_a)) * mid_r
			
			var icon_color = Color(0.5, 0.5, 0.5, 0.6)
			if i == hovered_slice: icon_color = Color(1.0, 1.0, 1.0, 1.0)
			
			# Same drawing logic as the Zone script
			var offset = texture.get_size() / 2.0
			draw_texture(texture, icon_center - offset, icon_color)

# ---------- INPUT ----------

func _unhandled_input(event: InputEvent):
	if not visible or building == null:
		return
		
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if hovered_slice != -1:
				var clicked_recipe = building.available_recipes[hovered_slice]
				if building.recipe_queue.size() < building.max_queue_size:
					building.recipe_queue.append(clicked_recipe)
					update_queue_ui()
				get_viewport().set_input_as_handled()
				
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			hide()
			get_viewport().set_input_as_handled()

# ---------- UI LOGIC ----------

func _on_repeat_toggled(toggled_on: bool):
	if building:
		building.repeat_infinite = toggled_on

func update_queue_ui():
	if building == null: return
	
	queue_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	queue_container.add_theme_constant_override("separation", 0) 

	for child in queue_container.get_children():
		child.queue_free()
		
	for i in range(building.recipe_queue.size()):
		var recipe = building.recipe_queue[i]
		if recipe.output_item and "icon" in recipe.output_item:
			var btn = Button.new()
			btn.icon = recipe.output_item.icon
			btn.flat = true 
			btn.custom_minimum_size = Vector2(24, 24)
			btn.expand_icon = true
			
			btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.pressed.connect(_on_queue_item_clicked.bind(i))
			
			queue_container.add_child(btn)

# Triggered when clicking an item in the HBoxContainer
func _on_queue_item_clicked(index: int):
	if building and index < building.recipe_queue.size():
		building.recipe_queue.remove_at(index)
		update_queue_ui()
