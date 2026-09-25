extends Control
class_name BuildMenu

# ========== SIGNALS ==========

signal start_building(building_data)

# ========== REFERENCES ==========

@onready var margin_container: MarginContainer = $MarginContainer
@onready var toggle_button: BaseButton = $ToggleButton

@onready var tabs_container: VBoxContainer = $MarginContainer/VBoxContainer/TabsContainer
@onready var items_container: GridContainer = $MarginContainer/VBoxContainer/ItemsContainer

@export var all_buildings: Array[BuildingData] = []
@export var show_categories: bool = true

@export var frame_normal: Texture2D 
@export var frame_pressed: Texture2D

@export var category_icons: Dictionary = {
	"Production": AtlasTexture, 
	"Storage": AtlasTexture,    
	"Survival": AtlasTexture,   
	"Decoration": AtlasTexture,
	"Defense": AtlasTexture
}

func _ready():
	margin_container.visible = false
	
	if toggle_button:
		toggle_button.pressed.connect(_on_toggle_pressed)
		toggle_button.focus_mode = Control.FOCUS_NONE
		
	if tabs_container:
		for child in tabs_container.get_children():
			child.queue_free()
	if items_container:
		for child in items_container.get_children():
			child.queue_free()

	if show_categories:
		var wall_res = load("res://Resources/Building Resources/wood_wall.tres")
		if wall_res is BuildingData:
			var already_has = false
			for b in all_buildings:
				if b and b.resource_path == wall_res.resource_path:
					already_has = true
					break
			if not already_has:
				all_buildings.append(wall_res)

	if not show_categories or tabs_container == null:
		if tabs_container:
			tabs_container.visible = false
		for b_data in all_buildings:
			_create_build_button(b_data)
		return

	var desired_order = ["Production", "Storage", "Defense", "Survival", "Decoration"]
	var active_categories = []
	for cat in desired_order:
		for b in all_buildings:
			if b.category == cat and not active_categories.has(cat):
				active_categories.append(cat)
				break
	for b in all_buildings:
		if not active_categories.has(b.category):
			active_categories.append(b.category)
			
	for category in active_categories:
		var tab_btn = TextureButton.new()
		
		if frame_normal: tab_btn.texture_normal = frame_normal
		if frame_pressed: tab_btn.texture_pressed = frame_pressed
		
		if category_icons.has(category) and category_icons[category] != null:
			var center = CenterContainer.new()
			center.set_anchors_preset(Control.PRESET_FULL_RECT)
			center.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			var icon_rect = TextureRect.new()
			icon_rect.texture = category_icons[category]
			icon_rect.custom_minimum_size = Vector2(26, 26)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			center.add_child(icon_rect)
			tab_btn.add_child(center)
			
		tab_btn.pressed.connect(_on_category_pressed.bind(category))
		tabs_container.add_child(tab_btn)
		
	if active_categories.size() > 0:
		_on_category_pressed(active_categories[0])

func _on_toggle_pressed():
	UIPanelManager.toggle_panel(margin_container)

func _on_category_pressed(category_name: String):
	for child in items_container.get_children():
		child.queue_free()

	for b_data in all_buildings:
		if b_data.category == category_name:
			_create_build_button(b_data)


func _create_build_button(b_data: BuildingData):
	var btn = TextureButton.new()

	if frame_normal: btn.texture_normal = frame_normal
	if frame_pressed: btn.texture_pressed = frame_pressed

	if b_data.icon:
		var center = CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var icon_rect = TextureRect.new()
		icon_rect.texture = b_data.icon
		icon_rect.custom_minimum_size = Vector2(26, 26)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		center.add_child(icon_rect)
		btn.add_child(center)

	btn.tooltip_text = b_data.building_name

	btn.pressed.connect(func():
		var data = {
			"scene": b_data.scene,
			"texture": b_data.icon,
			"cost": b_data.cost
		}
		emit_signal("start_building", data)
	)

	items_container.add_child(btn)
