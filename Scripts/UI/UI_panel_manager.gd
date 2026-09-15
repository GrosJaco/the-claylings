extends Node

var _open_panel: Control = null

func toggle_panel(panel: Control) -> void:
	if not is_instance_valid(panel):
		return

	if is_instance_valid(_open_panel) and _open_panel == panel:
		panel.visible = false
		_open_panel = null
		return
	
	if is_instance_valid(_open_panel):
		_open_panel.visible = false
	
	panel.visible = true
	_open_panel = panel

func close_current_panel() -> bool:
	if _open_panel and is_instance_valid(_open_panel):
		_open_panel.visible = false
		_open_panel = null
		return true
	_open_panel = null
	return false

func is_panel_open() -> bool:
	return _open_panel != null and is_instance_valid(_open_panel) and _open_panel.visible

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if close_current_panel():
				get_viewport().set_input_as_handled()
