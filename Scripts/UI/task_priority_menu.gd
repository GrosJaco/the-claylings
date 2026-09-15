extends Control
class_name TaskPriorityMenu

signal quota_changed(task_name: String, value: int)

@onready var margin_container: MarginContainer = $MarginContainer
@onready var toggle_button: BaseButton = $ToggleButton
@onready var rows_container: VBoxContainer = $MarginContainer/RowsContainer

@export_group("Background")
@export var background_texture: Texture2D
@export var bg_margin_left: int = 8
@export var bg_margin_top: int = 8
@export var bg_margin_right: int = 8
@export var bg_margin_bottom: int = 8

@export_group("Content Padding")
@export var padding_left: int = 20
@export var padding_top: int = 20
@export var padding_right: int = 20
@export var padding_bottom: int = 20

@export_group("Text Appearance")
@export var text_color: Color = Color.WHITE

@export_group("Tasks")
@export var task_names: Array[String] = [
	"Haul", "Deliver", "Construct", "CollectOutput", "Work",
	"Harvest", "Pick up", "Chop", "Mine", "Forage", "Plant", "Water"
]

var task_quotas: Dictionary = {}
var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}
var _total_label: Label = null

var _world: Node2D = null
var _last_known_total: int = -1
var _last_known_unemployed: int = -1
var _initialized: bool = false

func _ready():
	add_to_group("task_priority_menu")
	margin_container.visible = false
	
	if toggle_button:
		toggle_button.pressed.connect(_on_toggle_pressed)
		toggle_button.focus_mode = Control.FOCUS_NONE
		
	if background_texture:
		var bg = NinePatchRect.new()
		bg.texture = background_texture
		bg.patch_margin_left = bg_margin_left
		bg.patch_margin_top = bg_margin_top
		bg.patch_margin_right = bg_margin_right
		bg.patch_margin_bottom = bg_margin_bottom
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		margin_container.add_child(bg)
		margin_container.move_child(bg, 0)
	
	margin_container.remove_child(rows_container)
	
	var padding_container = MarginContainer.new()
	padding_container.add_theme_constant_override("margin_left", padding_left)
	padding_container.add_theme_constant_override("margin_top", padding_top)
	padding_container.add_theme_constant_override("margin_right", padding_right)
	padding_container.add_theme_constant_override("margin_bottom", padding_bottom)
	
	margin_container.add_child(padding_container)
	padding_container.add_child(rows_container)
	
	for child in rows_container.get_children():
		child.queue_free()
	
	_total_label = Label.new()
	_total_label.add_theme_color_override("font_color", text_color)
	rows_container.add_child(_total_label)
	
	for task_name in task_names:
		task_quotas[task_name] = 0
		_create_row(task_name)

func _process(_delta: float) -> void:
	if not _initialized:
		var w = _get_world()
		if w:
			_refresh_total(true)
			_initialized = true
		return
	
	if visible:
		_refresh_total(false)

func _on_toggle_pressed():
	UIPanelManager.toggle_panel(margin_container)

func _get_world() -> Node2D:
	if _world == null or not is_instance_valid(_world):
		_world = get_tree().get_first_node_in_group("main")
	return _world

func _get_total_allocated() -> int:
	var total_allocated = 0
	for v in task_quotas.values():
		total_allocated += v
	return total_allocated

func _refresh_total(force: bool) -> void:
	var w = _get_world()
	if w == null:
		return
	
	var total = w.get_active_clayling_count()
	var unemployed = total - _get_total_allocated()
	
	if not force and total == _last_known_total and unemployed == _last_known_unemployed:
		return
	
	var total_changed = (total != _last_known_total)
	_last_known_total = total
	_last_known_unemployed = unemployed
	_total_label.text = "Claylings : " + str(total) + " (" + str(unemployed) + " free)"
	
	if force or total_changed:
		for task_name in task_names:
			_sliders[task_name].max_value = total

func _create_row(task_name: String) -> void:
	var row = HBoxContainer.new()
	
	var label = Label.new()
	label.text = task_name
	label.custom_minimum_size = Vector2(200, 0)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override("font_color", text_color)
	
	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 0 
	slider.step = 1
	slider.value = 0
	slider.custom_minimum_size = Vector2(150, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var value_label = Label.new()
	value_label.text = "0"
	value_label.custom_minimum_size = Vector2(30, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", text_color)
	
	slider.value_changed.connect(_on_slider_value_changed.bind(task_name))
	
	row.add_child(label)
	row.add_child(slider)
	row.add_child(value_label)
	rows_container.add_child(row)
	
	_sliders[task_name] = slider
	_value_labels[task_name] = value_label

func _on_slider_value_changed(value: float, task_name: String) -> void:
	var requested_value = int(value)
	
	var others_sum = 0
	for other in task_names:
		if other != task_name:
			others_sum += task_quotas.get(other, 0)
	
	var max_allowed = max(0, _last_known_total - others_sum)
	var actual_value = min(requested_value, max_allowed)
	
	if requested_value > actual_value:
		_sliders[task_name].set_value_no_signal(actual_value)
		
	task_quotas[task_name] = actual_value
	_value_labels[task_name].text = str(actual_value)
	quota_changed.emit(task_name, actual_value)
	
	_refresh_total(false)

func load_quotas(new_quotas: Dictionary) -> void:
	var w = _get_world()
	var total = w.get_active_clayling_count() if (w and w.has_method("get_active_clayling_count")) else _last_known_total
	for task_name in task_names:
		if _sliders.has(task_name) and is_instance_valid(_sliders[task_name]):
			_sliders[task_name].max_value = max(total, 1)
		if new_quotas.has(task_name):
			var val = int(new_quotas[task_name])
			task_quotas[task_name] = val
			if _sliders.has(task_name) and is_instance_valid(_sliders[task_name]):
				_sliders[task_name].set_value_no_signal(val)
			if _value_labels.has(task_name) and is_instance_valid(_value_labels[task_name]):
				_value_labels[task_name].text = str(val)
	_refresh_total(false)
