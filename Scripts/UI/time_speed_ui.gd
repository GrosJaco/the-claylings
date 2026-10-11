extends Control
class_name TimeSpeedUI

enum SpeedMode { PAUSE, SPEED_1X, SPEED_2X, SPEED_3X }

@onready var pause_button: TextureButton = %PauseButton
@onready var speed1_button: TextureButton = %Speed1Button
@onready var speed2_button: TextureButton = %Speed2Button
@onready var speed3_button: TextureButton = %Speed3Button

const COLOR_ACTIVE: Color = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_INACTIVE: Color = Color(0.65, 0.65, 0.65, 0.85)
const COLOR_HOVER: Color = Color(0.88, 0.88, 0.88, 0.95)

var current_mode: SpeedMode = SpeedMode.SPEED_1X
var previous_speed_mode: SpeedMode = SpeedMode.SPEED_1X
var _buttons: Dictionary = {}

func _ready() -> void:
	# Keep receiving inputs even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	_buttons = {
		SpeedMode.PAUSE: pause_button,
		SpeedMode.SPEED_1X: speed1_button,
		SpeedMode.SPEED_2X: speed2_button,
		SpeedMode.SPEED_3X: speed3_button
	}

	pause_button.pressed.connect(func(): set_speed_mode(SpeedMode.PAUSE))
	speed1_button.pressed.connect(func(): set_speed_mode(SpeedMode.SPEED_1X))
	speed2_button.pressed.connect(func(): set_speed_mode(SpeedMode.SPEED_2X))
	speed3_button.pressed.connect(func(): set_speed_mode(SpeedMode.SPEED_3X))

	for mode in _buttons:
		var btn: TextureButton = _buttons[mode]
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_entered.connect(_on_button_hover.bind(btn, mode, true))
		btn.mouse_exited.connect(_on_button_hover.bind(btn, mode, false))

	set_speed_mode(SpeedMode.SPEED_1X)

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_pressed() or event.is_echo():
		return

	if event.is_action_pressed("speed_pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("speed_1x"):
		set_speed_mode(SpeedMode.SPEED_1X)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("speed_2x"):
		set_speed_mode(SpeedMode.SPEED_2X)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("speed_3x"):
		set_speed_mode(SpeedMode.SPEED_3X)
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	if current_mode == SpeedMode.PAUSE:
		set_speed_mode(previous_speed_mode if previous_speed_mode != SpeedMode.PAUSE else SpeedMode.SPEED_1X)
	else:
		set_speed_mode(SpeedMode.PAUSE)

func set_speed_mode(mode: SpeedMode) -> void:
	if current_mode != SpeedMode.PAUSE and mode == SpeedMode.PAUSE:
		previous_speed_mode = current_mode

	current_mode = mode

	match mode:
		SpeedMode.PAUSE:
			Engine.time_scale = 0.0
		SpeedMode.SPEED_1X:
			Engine.time_scale = 1.0
		SpeedMode.SPEED_2X:
			Engine.time_scale = 2.0
		SpeedMode.SPEED_3X:
			Engine.time_scale = 3.0

	_refresh_buttons_visual()

func _refresh_buttons_visual() -> void:
	for mode in _buttons:
		var btn: TextureButton = _buttons[mode]
		if mode == current_mode:
			btn.self_modulate = COLOR_ACTIVE
		else:
			btn.self_modulate = COLOR_INACTIVE

func _on_button_hover(btn: TextureButton, mode: SpeedMode, is_hovering: bool) -> void:
	if mode != current_mode:
		btn.self_modulate = COLOR_HOVER if is_hovering else COLOR_INACTIVE
