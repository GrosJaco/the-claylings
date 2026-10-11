extends Control
class_name MainMenu

# ========== REFERENCES ==========

@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var new_game_button: Button = $VBoxContainer/NewGameButton
@onready var load_game_button: Button = $VBoxContainer/LoadGameButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var credits_button: Button = $VBoxContainer/CreditsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

@onready var settings_dialog: SettingsDialog = $SettingsDialog
@onready var credits_panel: Control = $CreditsPanel
@onready var credits_close_button: Button = $CreditsPanel/MarginContainer/VBoxContainer/CloseCreditsButton

@onready var save_load_dialog: SaveLoadDialog = $SaveLoadDialog
@onready var world_creation_dialog: WorldCreationDialog = $WorldCreationDialog

# ========== INITIALIZATION ==========

func _ready() -> void:
	if credits_panel:
		credits_panel.visible = false

	# Connect main navigation buttons
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
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

	if credits_close_button:
		credits_close_button.pressed.connect(_close_modals)

	if save_load_dialog:
		save_load_dialog.load_confirmed.connect(_on_save_load_confirmed)
		save_load_dialog.cancelled.connect(_check_save_availability)

	if world_creation_dialog:
		world_creation_dialog.world_creation_confirmed.connect(_on_world_creation_confirmed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if save_load_dialog and save_load_dialog.visible:
				return
			if world_creation_dialog and world_creation_dialog.visible:
				return
			if settings_dialog and settings_dialog.visible:
				return
			if credits_panel and credits_panel.visible:
				_close_modals()
				get_viewport().set_input_as_handled()

# ========== ACTIONS ==========

func _on_continue_pressed() -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if not save_mgr:
		return
	var latest_slot = ""
	if save_mgr.has_method("get_latest_save_slot"):
		latest_slot = save_mgr.get_latest_save_slot()
	elif save_mgr.has_method("get_all_saves_metadata"):
		var metas = save_mgr.get_all_saves_metadata()
		if not metas.is_empty():
			latest_slot = metas[0].get("slot_name", "")
	elif save_mgr.has_method("get_save_slots"):
		var slots = save_mgr.get_save_slots()
		if not slots.is_empty():
			latest_slot = slots[0]

	if latest_slot != "":
		_close_modals()
		save_mgr.load_game(latest_slot)

func _on_new_game_pressed() -> void:
	_close_modals()
	if world_creation_dialog:
		world_creation_dialog.open()
	else:
		get_tree().change_scene_to_file("res://Scenes/main.tscn")

func _on_world_creation_confirmed(settings: Dictionary) -> void:
	var global = get_node_or_null("/root/Global")
	if global:
		global.custom_world_settings = settings
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

func _on_load_game_pressed() -> void:
	if save_load_dialog:
		save_load_dialog.open_load_dialog()

func _on_save_load_confirmed(slot_name: String) -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("load_game"):
		save_mgr.load_game(slot_name)

func _on_settings_pressed() -> void:
	if credits_panel:
		credits_panel.visible = false
	if settings_dialog:
		settings_dialog.open()

func _on_credits_pressed() -> void:
	if settings_dialog:
		settings_dialog.close()
	if credits_panel:
		credits_panel.visible = true

func _close_modals() -> void:
	if settings_dialog:
		settings_dialog.close()
	if credits_panel:
		credits_panel.visible = false
	if save_load_dialog:
		save_load_dialog.close()
	if world_creation_dialog:
		world_creation_dialog.close()

func _on_quit_pressed() -> void:
	get_tree().quit()

# ========== SAVE HELPERS ==========

func _check_save_availability() -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	var has_save: bool = false
	if save_mgr:
		if save_mgr.has_method("get_save_slots"):
			has_save = save_mgr.get_save_slots().size() > 0
		elif save_mgr.has_method("has_save"):
			has_save = save_mgr.has_save("quicksave")

	if continue_button:
		continue_button.disabled = not has_save
	if load_game_button:
		load_game_button.disabled = not has_save
