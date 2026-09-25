extends Control
class_name InventoryUI

# ========== REFERENCES ==========

@onready var categories_container: HBoxContainer = $CategoriesContainer
@export var custom_separator_texture: Texture2D
@export var panel_style: StyleBox

@export_group("Category Icons")
@export var icon_raw: Texture2D
@export var icon_refined: Texture2D
@export var icon_equipment: Texture2D
@export var icon_consumables: Texture2D
@export var icon_special: Texture2D

# ========== FUNCTIONS ==========

func _ready():
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(update_inventory)
	add_child(timer)

	update_inventory()


func update_inventory():
	var cat_data = {
	"Raw Materials": {"total": 0, "items": {}},
	"Refined Materials": {"total": 0, "items": {}},
	"Equipment": {"total": 0, "items": {}},
	"Consommables": {"total": 0, "items": {}},
	"Special": {"total": 0, "items": {}}
	}

	var storages = get_tree().get_nodes_in_group("storage")
	for s in storages:
		if s.get("is_preview"): continue
		
		for item in s.inventory:
			var amount = s.inventory[item]
			if amount <= 0: continue
			
			var cat = _get_item_category(item)
			if not cat_data.has(cat): cat = "Special"
			
			cat_data[cat]["total"] += amount
			cat_data[cat]["items"][item] = cat_data[cat]["items"].get(item, 0) + amount

	var racks = get_tree().get_nodes_in_group("weapon_racks")
	for r in racks:
		if r.get("is_preview"): continue
		if "slots_data" in r:
			for slot in r.slots_data:
				for item in slot.get("items", []):
					if not item: continue
					var cat = _get_item_category(item)
					if not cat_data.has(cat): cat = "Special"
					cat_data[cat]["total"] += 1
					cat_data[cat]["items"][item] = cat_data[cat]["items"].get(item, 0) + 1
			
	for child in categories_container.get_children():
		child.queue_free()
	
	for cat_name in cat_data:
		var panel = PanelContainer.new()
		
		categories_container.add_child(panel)
		panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		panel.custom_minimum_size = Vector2(125, 0)
		
		if panel_style:
			panel.add_theme_stylebox_override("panel", panel_style)
		else:
			var default_style = StyleBoxFlat.new()
			default_style.corner_radius_top_left = 4
			default_style.corner_radius_top_right = 4
			default_style.corner_radius_bottom_left = 4
			default_style.corner_radius_bottom_right = 4
			panel.add_theme_stylebox_override("panel", default_style)
			
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 5)
		margin.add_theme_constant_override("margin_bottom", 5)
		panel.add_child(margin)
		
		var cat_vbox = VBoxContainer.new()
		cat_vbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		
		# --- Title of category ---
		var header_hbox = HBoxContainer.new()
		header_hbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		
		var cat_icon = TextureRect.new()
		cat_icon.custom_minimum_size = Vector2(32, 32)
		
		match cat_name:
			"Raw Materials": cat_icon.texture = icon_raw
			"Refined Materials": cat_icon.texture = icon_refined
			"Equipment": cat_icon.texture = icon_equipment
			"Consommables": cat_icon.texture = icon_consumables
			"Special": cat_icon.texture = icon_special
			
		var header_label = Label.new()
		header_label.text = " " + str(cat_data[cat_name]["total"])
		header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		header_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		header_label.custom_minimum_size = Vector2(80, 0)
		
		header_hbox.add_child(cat_icon)
		header_hbox.add_child(header_label)
		cat_vbox.add_child(header_hbox)
		
		# --- Separation Line ---
		if custom_separator_texture:
			var sep = TextureRect.new()
			sep.texture = custom_separator_texture
			sep.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			cat_vbox.add_child(sep)
		else:
			var sep = HSeparator.new()
			cat_vbox.add_child(sep)
		
		# --- Object list ---
		var item_list = VBoxContainer.new()
		for item in cat_data[cat_name]["items"]:
			var amount = cat_data[cat_name]["items"][item]
			
			var hbox = HBoxContainer.new()
			hbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			
			var icon = TextureRect.new()
			if item.get("icon"): icon.texture = item.icon
			icon.custom_minimum_size = Vector2(16, 16)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			
			var label = Label.new()
			label.text = str(amount)
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			label.custom_minimum_size = Vector2(60, 0)
			
			hbox.add_child(icon)
			hbox.add_child(label)
			item_list.add_child(hbox)
			
		cat_vbox.add_child(item_list)
		margin.add_child(cat_vbox)


func _get_item_category(item: ItemData) -> String:
	if item.get("category"): return item.category
	var path = item.resource_path.to_lower()
	if "raw" in path :
		return "Raw Materials"
	if "refined" in path:
		return "Refined Materials"
	if "equipment" in path:
		return "Equipment"
	if "crops & foods" in path:
		return "Consommables"
		
	return "Special"
