extends PanelContainer
class_name WorldTooltip

@onready var label: Label = $Label

var _tracked_entity: Node2D = null
var _main_node: Node2D = null
var _refresh_timer: float = 0.0
var _fade_tween: Tween = null
var _custom_text: String = ""

func _ready() -> void:
	add_to_group("world_tooltip")
	_set_mouse_ignore_recursive(self)
	visible = false
	modulate.a = 0.0
	call_deferred("_setup_connections")

func _set_mouse_ignore_recursive(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore_recursive(child)

func _setup_connections() -> void:
	var tree = get_tree()
	if not tree:
		return
	_main_node = tree.get_first_node_in_group("main")
	if _main_node and _main_node.has_signal("hovered_entity_changed"):
		_main_node.hovered_entity_changed.connect(_on_hovered_entity_changed)
		var current = _main_node.get_hovered_entity()
		if current:
			_on_hovered_entity_changed(current)

func _process(delta: float) -> void:
	if not visible and modulate.a <= 0.0:
		return

	if _custom_text != "":
		_update_position()
		return

	if not is_instance_valid(_tracked_entity) or (_tracked_entity.has_method("get") and _tracked_entity.get("is_dead")):
		hide_tooltip()
		return

	_refresh_timer += delta
	if _refresh_timer >= 0.1:
		_refresh_timer = 0.0
		_refresh_display()

	_update_position()

func _update_position() -> void:
	var vp = get_viewport()
	if vp == null:
		return
	var mouse_pos = vp.get_mouse_position()
	var vp_size = get_viewport_rect().size
	var tip_size = get_combined_minimum_size()

	var offset = Vector2(16.0, 16.0)
	var target_x = mouse_pos.x + offset.x
	var target_y = mouse_pos.y + offset.y

	if target_x + tip_size.x > vp_size.x - 10.0:
		target_x = mouse_pos.x - tip_size.x - 12.0

	if target_y + tip_size.y > vp_size.y - 10.0:
		target_y = mouse_pos.y - tip_size.y - 12.0

	target_x = clampf(target_x, 8.0, maxf(8.0, vp_size.x - tip_size.x - 8.0))
	target_y = clampf(target_y, 8.0, maxf(8.0, vp_size.y - tip_size.y - 8.0))

	global_position = Vector2(round(target_x), round(target_y))

func _on_hovered_entity_changed(entity: Node2D) -> void:
	if _custom_text != "":
		return
	if entity == null or not is_instance_valid(entity):
		hide_tooltip()
		return

	_tracked_entity = entity
	_refresh_display()
	_update_position()
	show_tooltip()

func show_custom_text(text: String) -> void:
	_tracked_entity = null
	var changed = (_custom_text != text)
	_custom_text = text
	if changed or label.text != text:
		label.text = text
		reset_size()
	_update_position()
	if not visible or modulate.a < 1.0:
		show_tooltip()

func clear_custom_text() -> void:
	if _custom_text != "":
		_custom_text = ""
		hide_tooltip()

func show_tooltip() -> void:
	visible = true
	if not is_inside_tree():
		modulate.a = 1.0
		return
	if modulate.a >= 1.0 and (_fade_tween == null or not _fade_tween.is_valid()):
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, 0.08)

func hide_tooltip() -> void:
	_tracked_entity = null
	_custom_text = ""
	if not is_inside_tree():
		modulate.a = 0.0
		visible = false
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.08)
	_fade_tween.tween_callback(func():
		if _tracked_entity == null and _custom_text == "":
			visible = false
	)

func _refresh_display() -> void:
	if not is_instance_valid(_tracked_entity):
		hide_tooltip()
		return

	if not is_instance_valid(_main_node):
		var tree = get_tree()
		if tree:
			_main_node = tree.get_first_node_in_group("main")

	var info: Dictionary = {}
	if _main_node and _main_node.has_method("get_entity_info"):
		info = _main_node.get_entity_info(_tracked_entity)

	if info.is_empty():
		hide_tooltip()
		return

	var entity_name: String = info.get("name", "Unknown")
	if label.text != entity_name:
		label.text = entity_name
		reset_size()
