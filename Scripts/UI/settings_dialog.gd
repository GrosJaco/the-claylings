extends Control
class_name SettingsDialog

signal closed

# ========== REFERENCES ==========

@onready var dark_overlay: ColorRect = $DarkOverlay
@onready var panel_container: PanelContainer = $PanelContainer

@onready var tab_audio_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/TabHeader/AudioTabButton
@onready var tab_shortcuts_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/TabHeader/ShortcutsTabButton

@onready var audio_video_panel: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/AudioVideoPanel
@onready var shortcuts_panel: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ShortcutsPanel

@onready var volume_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/AudioVideoPanel/VolumeRow/VolumeSlider
@onready var fullscreen_check: CheckBox = $PanelContainer/MarginContainer/VBoxContainer/AudioVideoPanel/FullscreenRow/FullscreenCheckBox

@onready var shortcuts_list_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ShortcutsPanel/ScrollContainer/ShortcutsListContainer
@onready var reset_defaults_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/ShortcutsPanel/ResetDefaultsButton
@onready var close_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/CloseButton

# ========== STATE ==========

enum Tab { AUDIO_VIDEO, SHORTCUTS }
var current_tab: Tab = Tab.AUDIO_VIDEO

var _listening_action_id: StringName = &""
var _action_buttons: Dictionary = {} # action_id (StringName) -> Button

# ========== INITIALIZATION ==========

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dark_overlay:
		dark_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if tab_audio_btn:
		tab_audio_btn.pressed.connect(func(): _switch_tab(Tab.AUDIO_VIDEO))
	if tab_shortcuts_btn:
		tab_shortcuts_btn.pressed.connect(func(): _switch_tab(Tab.SHORTCUTS))

	if close_btn:
		close_btn.pressed.connect(close)

	if reset_defaults_btn:
		reset_defaults_btn.pressed.connect(_on_reset_defaults_pressed)

	_init_audio_video_controls()
	_populate_shortcuts_list()

	var input_mgr = get_node_or_null("/root/InputManager")
	if input_mgr and input_mgr.has_signal("keybindings_changed"):
		input_mgr.keybindings_changed.connect(_update_all_shortcut_buttons)

	_switch_tab(Tab.AUDIO_VIDEO)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# Handle key capture while in listening/rebind mode
	if _listening_action_id != &"":
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				_stop_listening()
			else:
				var key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
				var input_mgr = get_node_or_null("/root/InputManager")
				if input_mgr:
					input_mgr.rebind_action(_listening_action_id, key as Key)
				_stop_listening()
			get_viewport().set_input_as_handled()
		return

	# Escape closes the dialog when not capturing a key
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()

# ========== OPEN & CLOSE ==========

func open() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if dark_overlay:
		dark_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_stop_listening()
	_refresh_audio_video_values()
	_update_all_shortcut_buttons()
	_switch_tab(Tab.AUDIO_VIDEO)

func close() -> void:
	_stop_listening()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dark_overlay:
		dark_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit()

# ========== TAB SWITCHING ==========

func _switch_tab(new_tab: Tab) -> void:
	_stop_listening()
	current_tab = new_tab

	var is_audio = (current_tab == Tab.AUDIO_VIDEO)
	if audio_video_panel:
		audio_video_panel.visible = is_audio
	if shortcuts_panel:
		shortcuts_panel.visible = not is_audio

	# Highlight active tab button
	if tab_audio_btn:
		_set_tab_button_active(tab_audio_btn, is_audio)
	if tab_shortcuts_btn:
		_set_tab_button_active(tab_shortcuts_btn, not is_audio)

func _set_tab_button_active(btn: Button, active: bool) -> void:
	if active:
		btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		btn.modulate = Color(0.65, 0.65, 0.72, 0.85)

# ========== AUDIO & VIDEO ==========

func _init_audio_video_controls() -> void:
	if volume_slider:
		volume_slider.value_changed.connect(_on_volume_changed)
	if fullscreen_check:
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)

func _refresh_audio_video_values() -> void:
	var input_mgr = get_node_or_null("/root/InputManager")
	if volume_slider:
		var current_vol: float = 1.0
		if input_mgr and input_mgr.has_method("get_master_volume"):
			current_vol = input_mgr.get_master_volume()
		else:
			var master_idx = AudioServer.get_bus_index("Master")
			if master_idx >= 0:
				current_vol = db_to_linear(AudioServer.get_bus_volume_db(master_idx))
		volume_slider.set_value_no_signal(current_vol)

	if fullscreen_check:
		var is_fs: bool = false
		if input_mgr and input_mgr.has_method("is_fullscreen"):
			is_fs = input_mgr.is_fullscreen()
		else:
			var mode = DisplayServer.window_get_mode()
			is_fs = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		fullscreen_check.set_pressed_no_signal(is_fs)

func _on_volume_changed(value: float) -> void:
	var input_mgr = get_node_or_null("/root/InputManager")
	if input_mgr and input_mgr.has_method("set_master_volume"):
		input_mgr.set_master_volume(value, true)
	else:
		var master_idx = AudioServer.get_bus_index("Master")
		if master_idx >= 0:
			if value <= 0.001:
				AudioServer.set_bus_mute(master_idx, true)
			else:
				AudioServer.set_bus_mute(master_idx, false)
				AudioServer.set_bus_volume_db(master_idx, linear_to_db(value))

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	var input_mgr = get_node_or_null("/root/InputManager")
	if input_mgr and input_mgr.has_method("set_fullscreen"):
		input_mgr.set_fullscreen(toggled_on, true)
	else:
		if toggled_on:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

# ========== SHORTCUTS LIST & REBINDING ==========

func _populate_shortcuts_list() -> void:
	if not shortcuts_list_container:
		return

	# Clear previous children
	for child in shortcuts_list_container.get_children():
		child.queue_free()
	_action_buttons.clear()

	var input_mgr = get_node_or_null("/root/InputManager")
	var actions = input_mgr.ACTIONS if input_mgr else []

	var current_category: String = ""

	for action_data in actions:
		var category: String = action_data.get("category", "General")
		if category != current_category:
			current_category = category
			var cat_label = Label.new()
			cat_label.text = category.to_upper()
			cat_label.theme_type_variation = "HeaderSmall"
			cat_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.85, 1.0))
			cat_label.add_theme_font_size_override("font_size", 14)
			shortcuts_list_container.add_child(cat_label)

		var action_id: StringName = action_data["id"]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var name_label = Label.new()
		name_label.text = action_data.get("name", String(action_id))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 14)
		row.add_child(name_label)

		var key_btn = Button.new()
		key_btn.custom_minimum_size = Vector2(130, 28)
		key_btn.focus_mode = Control.FOCUS_NONE
		key_btn.add_theme_font_size_override("font_size", 13)
		key_btn.pressed.connect(_on_key_button_pressed.bind(action_id, key_btn))

		row.add_child(key_btn)
		shortcuts_list_container.add_child(row)

		_action_buttons[action_id] = key_btn

	_update_all_shortcut_buttons()

func _update_all_shortcut_buttons() -> void:
	var input_mgr = get_node_or_null("/root/InputManager")
	if not input_mgr:
		return

	for action_id in _action_buttons:
		var btn: Button = _action_buttons[action_id]
		if action_id == _listening_action_id:
			btn.text = "[ Press a key... ]"
			btn.modulate = Color(1.0, 0.9, 0.3, 1.0)
		else:
			var primary_key: Key = input_mgr.get_action_primary_key(action_id)
			btn.text = input_mgr.get_key_display_text(primary_key)
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_key_button_pressed(action_id: StringName, btn: Button) -> void:
	if _listening_action_id == action_id:
		_stop_listening()
	else:
		_listening_action_id = action_id
		_update_all_shortcut_buttons()

func _stop_listening() -> void:
	_listening_action_id = &""
	_update_all_shortcut_buttons()

func _on_reset_defaults_pressed() -> void:
	var input_mgr = get_node_or_null("/root/InputManager")
	if input_mgr and input_mgr.has_method("reset_to_defaults"):
		input_mgr.reset_to_defaults()
