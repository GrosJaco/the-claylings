extends Node

signal keybindings_changed

const CONFIG_PATH: String = "user://settings.cfg"
const KEYBINDINGS_SECTION: String = "keybindings"
const AUDIO_SECTION: String = "audio"
const VIDEO_SECTION: String = "video"

var ACTIONS: Array[Dictionary] = [
	{
		"id": &"cam_up",
		"name": "Move Camera Up",
		"category": "Camera",
		"default_keys": [KEY_W, KEY_UP, KEY_Z]
	},
	{
		"id": &"cam_down",
		"name": "Move Camera Down",
		"category": "Camera",
		"default_keys": [KEY_S, KEY_DOWN]
	},
	{
		"id": &"cam_left",
		"name": "Move Camera Left",
		"category": "Camera",
		"default_keys": [KEY_A, KEY_LEFT, KEY_Q]
	},
	{
		"id": &"cam_right",
		"name": "Move Camera Right",
		"category": "Camera",
		"default_keys": [KEY_D, KEY_RIGHT]
	},
	{
		"id": &"cam_center",
		"name": "Center Camera",
		"category": "Camera",
		"default_keys": [KEY_H, KEY_HOME]
	},
	{
		"id": &"speed_pause",
		"name": "Pause / Resume",
		"category": "Game Speed",
		"default_keys": [KEY_SPACE]
	},
	{
		"id": &"speed_1x",
		"name": "Normal Speed (1x)",
		"category": "Game Speed",
		"default_keys": [KEY_1, KEY_KP_1]
	},
	{
		"id": &"speed_2x",
		"name": "Fast Speed (2x)",
		"category": "Game Speed",
		"default_keys": [KEY_2, KEY_KP_2]
	},
	{
		"id": &"speed_3x",
		"name": "Ultra Speed (3x)",
		"category": "Game Speed",
		"default_keys": [KEY_3, KEY_KP_3]
	},
	{
		"id": &"call_to_arms",
		"name": "Call to Arms",
		"category": "Orders",
		"default_keys": [KEY_X]
	},
	{
		"id": &"call_to_work",
		"name": "Call to Work",
		"category": "Orders",
		"default_keys": [KEY_Z]
	},
	{
		"id": &"toggle_harvest_zone",
		"name": "Harvest Zone",
		"category": "Orders",
		"default_keys": [KEY_M]
	},
	{
		"id": &"cycle_clayling",
		"name": "Next Clayling",
		"category": "Orders",
		"default_keys": [KEY_TAB]
	},
	{
		"id": &"rotate_building",
		"name": "Rotate Building",
		"category": "Building",
		"default_keys": [KEY_R]
	}
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_actions()
	load_all_settings()

func _setup_actions() -> void:
	for action_data in ACTIONS:
		var action_id: StringName = action_data["id"]
		if not InputMap.has_action(action_id):
			InputMap.add_action(action_id)

func load_all_settings() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(CONFIG_PATH)
	if err != OK:
		_apply_defaults_to_input_map()
		return

	# Load Audio & Video settings
	if cfg.has_section_key(AUDIO_SECTION, "master_volume"):
		var vol = cfg.get_value(AUDIO_SECTION, "master_volume", 1.0)
		set_master_volume(vol, false)
	
	if cfg.has_section_key(VIDEO_SECTION, "fullscreen"):
		var fs = cfg.get_value(VIDEO_SECTION, "fullscreen", false)
		set_fullscreen(fs, false)

	# Load Keybindings
	for action_data in ACTIONS:
		var action_id: StringName = action_data["id"]
		var key_str = String(action_id)
		if cfg.has_section_key(KEYBINDINGS_SECTION, key_str):
			var saved_val = cfg.get_value(KEYBINDINGS_SECTION, key_str)
			var keys_to_set: Array[Key] = []
			if saved_val is Array:
				for k in saved_val:
					keys_to_set.append(k as Key)
			elif saved_val is int:
				keys_to_set.append(saved_val as Key)
			_set_action_keys(action_id, keys_to_set)
		else:
			var default_keys: Array = action_data["default_keys"]
			var cast_keys: Array[Key] = []
			for k in default_keys:
				cast_keys.append(k as Key)
			_set_action_keys(action_id, cast_keys)

func _apply_defaults_to_input_map() -> void:
	for action_data in ACTIONS:
		var action_id: StringName = action_data["id"]
		var default_keys: Array = action_data["default_keys"]
		var cast_keys: Array[Key] = []
		for k in default_keys:
			cast_keys.append(k as Key)
		_set_action_keys(action_id, cast_keys)

func _set_action_keys(action_id: StringName, keys: Array[Key]) -> void:
	InputMap.action_erase_events(action_id)
	for k in keys:
		if k != KEY_NONE:
			var ev = InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action_id, ev)

func get_action_primary_key(action_id: StringName) -> Key:
	if not InputMap.has_action(action_id):
		return KEY_NONE
	var events = InputMap.action_get_events(action_id)
	for ev in events:
		if ev is InputEventKey:
			var code = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
			if code != 0:
				return code as Key
	return KEY_NONE

func get_action_display_name(action_id: StringName) -> String:
	for data in ACTIONS:
		if data["id"] == action_id:
			return data["name"]
	return String(action_id)

func get_key_display_text(key: Key) -> String:
	if key == KEY_NONE:
		return "None"
	var text = OS.get_keycode_string(key)
	if text.is_empty():
		return "Key " + str(key)
	return text

func rebind_action(action_id: StringName, new_key: Key) -> void:
	# Swap or unbind if another action already uses this key
	for other_data in ACTIONS:
		var other_id: StringName = other_data["id"]
		if other_id != action_id:
			if get_action_primary_key(other_id) == new_key:
				_set_action_keys(other_id, [])
				_save_action_key(other_id, KEY_NONE)

	if new_key == KEY_NONE:
		_set_action_keys(action_id, [])
	else:
		_set_action_keys(action_id, [new_key])

	_save_action_key(action_id, new_key)
	keybindings_changed.emit()

func reset_to_defaults() -> void:
	var cfg = ConfigFile.new()
	cfg.load(CONFIG_PATH)
	if cfg.has_section(KEYBINDINGS_SECTION):
		cfg.erase_section(KEYBINDINGS_SECTION)
		cfg.save(CONFIG_PATH)

	_apply_defaults_to_input_map()
	keybindings_changed.emit()

func _save_action_key(action_id: StringName, key: Key) -> void:
	var cfg = ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value(KEYBINDINGS_SECTION, String(action_id), int(key))
	cfg.save(CONFIG_PATH)

func set_master_volume(value: float, save: bool = true) -> void:
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		if value <= 0.001:
			AudioServer.set_bus_mute(master_idx, true)
		else:
			AudioServer.set_bus_mute(master_idx, false)
			AudioServer.set_bus_volume_db(master_idx, linear_to_db(value))

	if save:
		var cfg = ConfigFile.new()
		cfg.load(CONFIG_PATH)
		cfg.set_value(AUDIO_SECTION, "master_volume", value)
		cfg.save(CONFIG_PATH)

func get_master_volume() -> float:
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		if AudioServer.is_bus_mute(master_idx):
			return 0.0
		return db_to_linear(AudioServer.get_bus_volume_db(master_idx))
	return 1.0

func set_fullscreen(enabled: bool, save: bool = true) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	if save:
		var cfg = ConfigFile.new()
		cfg.load(CONFIG_PATH)
		cfg.set_value(VIDEO_SECTION, "fullscreen", enabled)
		cfg.save(CONFIG_PATH)

func is_fullscreen() -> bool:
	var mode = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
