extends Control
class_name MainMenu

# ========== REFERENCES ==========

@onready var new_game_button: Button = $VBoxContainer/NewGameButton
@onready var load_game_button: Button = $VBoxContainer/LoadGameButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var credits_button: Button = $VBoxContainer/CreditsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

@onready var settings_panel: Control = $SettingsPanel
@onready var credits_panel: Control = $CreditsPanel
@onready var settings_close_button: Button = $SettingsPanel/MarginContainer/VBoxContainer/CloseSettingsButton
@onready var credits_close_button: Button = $CreditsPanel/MarginContainer/VBoxContainer/CloseCreditsButton

@onready var volume_slider: HSlider = $SettingsPanel/MarginContainer/VBoxContainer/VolumeRow/VolumeSlider
@onready var fullscreen_check: CheckBox = $SettingsPanel/MarginContainer/VBoxContainer/FullscreenRow/FullscreenCheckBox

# ========== INITIALIZATION ==========

func _ready() -> void:
	# Hide overlay panels on startup
	if settings_panel:
		settings_panel.visible = false
	if credits_panel:
		credits_panel.visible = false

	# Connect main navigation buttons
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
	if load_game_button:
		load_game_button.pressed.connect(_on_load_game_pressed)
		_check_save_availability()
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if credits_button:
		credits_button.pressed.connect(_on_credits_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

	# Connect modal close buttons
	if settings_close_button:
		settings_close_button.pressed.connect(_close_modals)
	if credits_close_button:
		credits_close_button.pressed.connect(_close_modals)

	# Initialize settings controls
	_init_settings_values()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if (settings_panel and settings_panel.visible) or (credits_panel and credits_panel.visible):
				_close_modals()
				get_viewport().set_input_as_handled()

# ========== ACTIONS ==========

func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

func _on_load_game_pressed() -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("load_game"):
		save_mgr.load_game("quicksave")

func _on_settings_pressed() -> void:
	if credits_panel:
		credits_panel.visible = false
	if settings_panel:
		settings_panel.visible = true

func _on_credits_pressed() -> void:
	if settings_panel:
		settings_panel.visible = false
	if credits_panel:
		credits_panel.visible = true

func _close_modals() -> void:
	if settings_panel:
		settings_panel.visible = false
	if credits_panel:
		credits_panel.visible = false

func _on_quit_pressed() -> void:
	get_tree().quit()

# ========== SETTINGS & SAVE HELPERS ==========

func _check_save_availability() -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	var has_save: bool = false
	if save_mgr:
		if save_mgr.has_method("has_save"):
			has_save = save_mgr.has_save("quicksave")
		if not has_save and save_mgr.has_method("get_save_slots"):
			has_save = save_mgr.get_save_slots().size() > 0

	load_game_button.disabled = not has_save

func _init_settings_values() -> void:
	# Audio volume setup
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx >= 0 and volume_slider:
		var current_vol = db_to_linear(AudioServer.get_bus_volume_db(master_idx))
		volume_slider.value = current_vol
		volume_slider.value_changed.connect(_on_volume_changed)

	# Fullscreen toggle setup
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
