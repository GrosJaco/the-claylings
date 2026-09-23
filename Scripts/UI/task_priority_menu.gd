extends Control
class_name TaskPriorityMenu

# ========== SIGNALS ==========

signal order_priorities_changed(orders: Array)
signal quota_changed(task_name: String, value: int)

# ========== REFERENCES ==========

@onready var margin_container: MarginContainer = $MarginContainer
@onready var toggle_button: BaseButton = $ToggleButton
@onready var rows_container: VBoxContainer = $MarginContainer/RowsContainer

# ========== EXPORTS ==========

@export_group("Background")
@export var background_texture: Texture2D
@export var bg_margin_left: int = 8
@export var bg_margin_top: int = 8
@export var bg_margin_right: int = 8
@export var bg_margin_bottom: int = 8

@export_group("Content Padding")
@export var padding_left: int = 14
@export var padding_top: int = 14
@export var padding_right: int = 14
@export var padding_bottom: int = 14

@export_group("Text Appearance")
@export var text_color: Color = Color.WHITE

@export_group("Tasks")
@export var task_names: Array[String] = [
	"Logistics", "Construction", "Crafting", "Farming", "Woodcutting", "Mining", "Foraging"
]

# ========== CONSTANTS & STATE ==========

const DEFAULT_ORDERS: Array[Dictionary] = [
	{"id": "logistics", "name": "Logistics", "enabled": true},
	{"id": "construction", "name": "Construction", "enabled": true},
	{"id": "crafting", "name": "Crafting", "enabled": true},
	{"id": "farming", "name": "Farming", "enabled": true},
	{"id": "woodcutting", "name": "Woodcutting", "enabled": true},
	{"id": "mining", "name": "Mining", "enabled": true},
	{"id": "foraging", "name": "Foraging", "enabled": true}
]

var orders: Array[Dictionary] = []
var task_quotas: Dictionary = {}

var _order_rows_container: VBoxContainer = null
var _worker_labels: Dictionary = {}
var _total_label: Label = null
var _world: Node2D = null
var _initialized: bool = false
var _refresh_timer: float = 0.0

# ========== FUNCTIONS ==========

func _ready() -> void:
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

	_setup_header()

	if orders.is_empty():
		for item in DEFAULT_ORDERS:
			orders.append(item.duplicate())

	_rebuild_rows()
	call_deferred("_sync_with_world")

func _setup_header() -> void:
	for child in rows_container.get_children():
		child.queue_free()

	var title_label = Label.new()
	title_label.text = "ORDER PRIORITIES"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", text_color)
	title_label.add_theme_font_size_override("font_size", 13)
	rows_container.add_child(title_label)

	_total_label = Label.new()
	_total_label.text = "Claylings: 0 (0 idle)"
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total_label.add_theme_color_override("font_color", text_color)
	_total_label.add_theme_font_size_override("font_size", 11)
	rows_container.add_child(_total_label)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	rows_container.add_child(spacer)

	_order_rows_container = VBoxContainer.new()
	_order_rows_container.add_theme_constant_override("separation", 4)
	rows_container.add_child(_order_rows_container)

func _process(delta: float) -> void:
	if not _initialized:
		var w = _get_world()
		if w:
			_sync_with_world()
			_initialized = true
		return

	if margin_container.visible:
		_refresh_timer -= delta
		if _refresh_timer <= 0.0:
			_refresh_timer = 0.2
			_update_worker_counts()

func _on_toggle_pressed() -> void:
	UIPanelManager.toggle_panel(margin_container)
	if margin_container.visible:
		_update_worker_counts()

func _get_world() -> Node2D:
	if _world == null or not is_instance_valid(_world):
		_world = get_tree().get_first_node_in_group("main")
	return _world

func _rebuild_rows() -> void:
	if _order_rows_container == null:
		return

	for child in _order_rows_container.get_children():
		child.queue_free()

	_worker_labels.clear()

	for i in range(orders.size()):
		var order_data = orders[i]
		var order_id: String = order_data.get("id", "")
		var order_name: String = order_data.get("name", order_id)
		var is_enabled: bool = order_data.get("enabled", true)

		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 24)
		row.add_theme_constant_override("separation", 4)

		var rank_lbl = Label.new()
		rank_lbl.text = "#" + str(i + 1)
		rank_lbl.custom_minimum_size = Vector2(20, 0)
		rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rank_lbl.add_theme_color_override("font_color", text_color)
		rank_lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(rank_lbl)

		var name_lbl = Label.new()
		name_lbl.text = order_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.clip_text = true
		name_lbl.add_theme_font_size_override("font_size", 11)
		if is_enabled:
			name_lbl.add_theme_color_override("font_color", text_color)
		else:
			name_lbl.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.45))
		row.add_child(name_lbl)

		var worker_lbl = Label.new()
		worker_lbl.text = "(0)"
		worker_lbl.custom_minimum_size = Vector2(26, 0)
		worker_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		worker_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		worker_lbl.add_theme_font_size_override("font_size", 10)
		if is_enabled:
			worker_lbl.add_theme_color_override("font_color", text_color)
		else:
			worker_lbl.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.45))
		row.add_child(worker_lbl)
		_worker_labels[order_id] = worker_lbl

		var toggle_btn = Button.new()
		toggle_btn.text = "ON" if is_enabled else "OFF"
		toggle_btn.custom_minimum_size = Vector2(34, 20)
		toggle_btn.focus_mode = Control.FOCUS_NONE
		toggle_btn.add_theme_font_size_override("font_size", 10)
		if is_enabled:
			toggle_btn.add_theme_color_override("font_color", Color(0.2, 0.55, 0.25, 1.0))
		else:
			toggle_btn.add_theme_color_override("font_color", Color(0.65, 0.25, 0.25, 1.0))
		toggle_btn.pressed.connect(_on_toggle_order_pressed.bind(i))
		row.add_child(toggle_btn)

		var up_btn = Button.new()
		up_btn.text = "^"
		up_btn.custom_minimum_size = Vector2(20, 20)
		up_btn.focus_mode = Control.FOCUS_NONE
		up_btn.disabled = (i == 0)
		up_btn.add_theme_font_size_override("font_size", 10)
		up_btn.pressed.connect(_on_move_up_pressed.bind(i))
		row.add_child(up_btn)

		var down_btn = Button.new()
		down_btn.text = "v"
		down_btn.custom_minimum_size = Vector2(20, 20)
		down_btn.focus_mode = Control.FOCUS_NONE
		down_btn.disabled = (i == orders.size() - 1)
		down_btn.add_theme_font_size_override("font_size", 10)
		down_btn.pressed.connect(_on_move_down_pressed.bind(i))
		row.add_child(down_btn)

		_order_rows_container.add_child(row)

func _on_move_up_pressed(index: int) -> void:
	if index <= 0 or index >= orders.size():
		return
	var temp = orders[index]
	orders[index] = orders[index - 1]
	orders[index - 1] = temp
	_rebuild_rows()
	_update_worker_counts()
	_notify_changes()

func _on_move_down_pressed(index: int) -> void:
	if index < 0 or index >= orders.size() - 1:
		return
	var temp = orders[index]
	orders[index] = orders[index + 1]
	orders[index + 1] = temp
	_rebuild_rows()
	_update_worker_counts()
	_notify_changes()

func _on_toggle_order_pressed(index: int) -> void:
	if index < 0 or index >= orders.size():
		return
	orders[index]["enabled"] = not orders[index].get("enabled", true)
	_rebuild_rows()
	_update_worker_counts()
	_notify_changes()

func _notify_changes() -> void:
	order_priorities_changed.emit(orders)
	var w = _get_world()
	if w and "task_priority_orders" in w:
		w.task_priority_orders = orders.duplicate(true)

func _update_worker_counts() -> void:
	var w = _get_world()
	if w == null or not is_instance_valid(w):
		return

	if _total_label and is_instance_valid(_total_label):
		var total = w.get_active_clayling_count() if w.has_method("get_active_clayling_count") else 0
		var idle_count = w.get_idle_clayling_count() if w.has_method("get_idle_clayling_count") else 0
		_total_label.text = "Claylings: " + str(total) + " (" + str(idle_count) + " idle)"

	for order_id in _worker_labels:
		var lbl = _worker_labels[order_id]
		if is_instance_valid(lbl):
			var count = w.get_order_active_count(order_id) if w.has_method("get_order_active_count") else 0
			lbl.text = "(" + str(count) + ")"

func _sync_with_world() -> void:
	var w = _get_world()
	if w and "task_priority_orders" in w:
		if not w.task_priority_orders.is_empty():
			orders = w.task_priority_orders.duplicate(true)
			_rebuild_rows()
		else:
			w.task_priority_orders = orders.duplicate(true)
	_update_worker_counts()

func load_orders_data(saved_orders: Array) -> void:
	if saved_orders.is_empty():
		return
	orders.clear()
	for item in saved_orders:
		if item is Dictionary:
			orders.append(item.duplicate())

	for def in DEFAULT_ORDERS:
		var found = false
		for o in orders:
			if o.get("id") == def["id"]:
				found = true
				break
		if not found:
			orders.append(def.duplicate())

	_rebuild_rows()
	_update_worker_counts()
	_notify_changes()

func load_quotas(_legacy_quotas: Dictionary) -> void:
	_rebuild_rows()
	_update_worker_counts()
	_notify_changes()
