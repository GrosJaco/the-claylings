extends Control
class_name PauseMenu

# ========== REFERENCES ==========

@onready var dark_overlay: ColorRect = $DarkOverlay
@onready var menu_container: VBoxContainer = $VBoxContainer

@onready var resume_button: Button = $VBoxContainer/ResumeButton
@onready var save_button: Button = $VBoxContainer/SaveButton
@onready var load_button: Button = $VBoxContainer/LoadButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var main_menu_button: Button = $VBoxContainer/MainMenuButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

@onready var settings_panel: Control = $SettingsPanel
@onready var close_settings_button: Button = $SettingsPanel/MarginContainer/VBoxContainer/CloseSettingsButton
@onready var volume_slider: HSlider = $SettingsPanel/MarginContainer/VBoxContainer/VolumeRow/VolumeSlider
@onready var fullscreen_check: CheckBox = $SettingsPanel/MarginContainer/VBoxContainer/FullscreenRow/FullscreenCheckBox

# ========== STATE ==========

var _is_open: bool = false

# ========== INITIALIZATION ==========

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dark_overlay:
		dark_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if settings_panel:
		settings_panel.visible = false

	# Connect navigation buttons
	if resume_button:
		resume_button.pressed.connect(resume)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if load_button:
		load_button.pressed.connect(_on_load_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

	if close_settings_button:
		close_settings_button.pressed.connect(_close_settings)

	_init_settings_values()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _is_open:
				if settings_panel and settings_panel.visible:
					_close_settings()
				else:
					resume()
				get_viewport().set_input_as_handled()
			else:
				if _can_open_pause():
					pause()
					get_viewport().set_input_as_handled()

func _can_open_pause() -> bool:
	# Do not pause if game over defeat screen is active
	var defeat = get_tree().get_first_node_in_group("defeat_ui")
	if defeat and defeat.get("_is_active"):
		return false

	# Do not pause if a HUD panel is already open (Escape should close the panel first)
	var panel_mgr = get_node_or_null("/root/UIPanelManager")
	if panel_mgr and panel_mgr.has_method("is_panel_open") and panel_mgr.is_panel_open():
		return false

	# Do not pause if a building preview is active (Escape cancels preview first)
	var b_mgr = get_tree().get_first_node_in_group("building_manager")
	if b_mgr and b_mgr.get("is_previewing"):
		return false

	# Do not pause if clayling info sheet is visible
	var clayling_info = get_tree().get_first_node_in_group("clayling_info_ui")
	if not clayling_info:
		var main_node = get_tree().get_first_node_in_group("main")
		if main_node:
			clayling_info = main_node.get_node_or_null("CanvasLayer/ClaylingInfoUI")
	if clayling_info and clayling_info.visible:
		return false

	return true

# ========== PAUSE & RESUME ==========

func pause() -> void:
	if _is_open:
		return
	_is_open = true
	get_tree().paused = true

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if dark_overlay:
		dark_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	if settings_panel:
		settings_panel.visible = false

	_update_load_button_state()

	if resume_button:
		resume_button.grab_focus()

func resume() -> void:
	if not _is_open:
		return
	_is_open = false
	get_tree().paused = false

	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dark_overlay:
		dark_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if settings_panel:
		settings_panel.visible = false

# ========== BUTTON HANDLERS ==========

func _on_save_pressed() -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("save_game"):
		save_mgr.save_game("quicksave")
		_update_load_button_state()

func _on_load_pressed() -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("load_game"):
		save_mgr.load_game("quicksave")

func _on_settings_pressed() -> void:
	if settings_panel:
		settings_panel.visible = true
		if close_settings_button:
			close_settings_button.grab_focus()

func _close_settings() -> void:
	if settings_panel:
		settings_panel.visible = false
		if settings_button:
			settings_button.grab_focus()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

# ========== SETTINGS & SAVE HELPERS ==========

func _update_load_button_state() -> void:
	if not load_button:
		return
	var save_mgr = get_node_or_null("/root/SaveManager")
	var has_save: bool = false
	if save_mgr:
		if save_mgr.has_method("has_save"):
			has_save = save_mgr.has_save("quicksave")
		if not has_save and save_mgr.has_method("get_save_slots"):
			has_save = save_mgr.get_save_slots().size() > 0

	load_button.disabled = not has_save

func _init_settings_values() -> void:
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx >= 0 and volume_slider:
		var current_vol = db_to_linear(AudioServer.get_bus_volume_db(master_idx))
		volume_slider.value = current_vol
		volume_slider.value_changed.connect(_on_volume_changed)

	if fullscreen_check:
		var mode = DisplayServer.window_get_mode()
		fullscreen_check.button_pressed = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)

func _on_volume_changed(value: float) -> void:
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		if value <= 0.001:
			AudioServer.set_bus_mute(master_idx, true)
		else:
			AudioServer.set_bus_mute(master_idx, false)
			AudioServer.set_bus_volume_db(master_idx, linear_to_db(value))

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
