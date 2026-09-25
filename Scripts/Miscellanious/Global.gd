extends Node
class_name GlobalAutoload

var dev_mode: bool = false
signal dev_mode_toggled(is_active: bool)

# World generation parameters passed from New Game dialog to main scene
var custom_world_settings: Dictionary = {}

var kit_items: Array[ItemData] = []
var _kit_item_names: Dictionary = {}

var _dev_layer: CanvasLayer = null
var _dev_label: Label = null

func _ready() -> void:
	_setup_dev_indicator()
	_load_kit_items()

func _load_kit_items() -> void:
	kit_items.clear()
	_kit_item_names.clear()
	var dir = DirAccess.open("res://Resources/Kit Resources/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var kit = load("res://Resources/Kit Resources/" + file_name)
				if kit is KitData:
					for it in kit.required_items:
						if it is ItemData:
							if not kit_items.has(it):
								kit_items.append(it)
							_kit_item_names[it.name] = true
			file_name = dir.get_next()
		dir.list_dir_end()

func is_kit_item(item: ItemData) -> bool:
	if item == null:
		return false
	if _kit_item_names.is_empty():
		_load_kit_items()
	if _kit_item_names.has(item.name):
		return true
	if item.resource_path != "" and "equipment" in item.resource_path.to_lower():
		return true
	for ki in kit_items:
		if ki == item or ki.name == item.name or (ki.resource_path != "" and ki.resource_path == item.resource_path):
			return true
	return false

func _setup_dev_indicator() -> void:
	_dev_layer = CanvasLayer.new()
	_dev_layer.layer = 128
	add_child(_dev_layer)

	_dev_label = Label.new()
	_dev_label.text = "[DEV MODE]"
	_dev_label.visible = false
	_dev_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_dev_label.offset_left = -160.0
	_dev_label.offset_top = 12.0
	_dev_label.offset_right = -16.0
	_dev_label.offset_bottom = 36.0
	_dev_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dev_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 0.95))
	_dev_layer.add_child(_dev_label)

func toggle_dev_mode() -> void:
	dev_mode = !dev_mode
	if _dev_label:
		_dev_label.visible = dev_mode
	dev_mode_toggled.emit(dev_mode)

func _is_dev_mode_key(event: InputEventKey) -> bool:
	if event.keycode == KEY_SECTION or event.physical_keycode == KEY_SECTION:
		return true
	if event.keycode == KEY_QUOTELEFT or event.physical_keycode == KEY_QUOTELEFT:
		return true
	if event.unicode == 178 or event.unicode == 0x00B2:
		return true
	if event.as_text_key_label() == "²":
		return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()
			return
		if _is_dev_mode_key(event):
			toggle_dev_mode()
			get_viewport().set_input_as_handled()
			return

func toggle_fullscreen() -> void:
	var mode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)