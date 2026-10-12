extends Camera2D

@export var zoom_speed: float = 0.25 
@export var zoom_min: float = 0.5
@export var zoom_max: float = 4.0 # Update sound_manager if changed
@export var smooth_factor: float = 10.0

@export var keyboard_pan_speed: float = 600.0

var target_zoom: float = 1.0
var dragging: bool = false
var target_position: Vector2 = Vector2.ZERO
var is_centering: bool = false
var _shake_timer: float = 0.0
var _shake_intensity: float = 0.0

var _last_tick: int = 0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("camera")
	target_zoom = zoom.x
	target_position = global_position
	_last_tick = Time.get_ticks_usec()

func shake(intensity: float = 6.0, duration: float = 0.35) -> void:
	_shake_intensity = intensity
	_shake_timer = duration

func _process(delta: float):
	var now = Time.get_ticks_usec()
	var dt = (now - _last_tick) / 1000000.0 if _last_tick > 0 else (1.0 / 60.0)
	_last_tick = now
	dt = clampf(dt, 0.0, 0.1)

	if _shake_timer > 0.0:
		_shake_timer -= dt
		offset = Vector2(randf_range(-_shake_intensity, _shake_intensity), randf_range(-_shake_intensity, _shake_intensity))
		if _shake_timer <= 0.0:
			offset = Vector2.ZERO

	zoom = zoom.lerp(Vector2(target_zoom, target_zoom), smooth_factor * dt)

	if is_centering:
		global_position = global_position.lerp(target_position, smooth_factor * dt)
		if global_position.distance_to(target_position) < 1.5:
			global_position = target_position
			is_centering = false
	
	var direction = Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	if direction == Vector2.ZERO:
		direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if direction != Vector2.ZERO:
		is_centering = false
		position += direction * keyboard_pan_speed * dt / zoom.x

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			if dragging:
				is_centering = false

	elif event is InputEventMouseMotion and dragging:
		is_centering = false
		position -= event.relative / zoom.x

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom += zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom -= zoom_speed
			
		target_zoom = clamp(target_zoom, zoom_min, zoom_max)

	if event.is_action_pressed("cam_center"):
		center_on_crystal(true)
		get_viewport().set_input_as_handled()

func focus_on_position(target: Vector2) -> void:
	target_position = target
	is_centering = true

func center_on_crystal(smooth: bool = true) -> void:
	var crystals = get_tree().get_nodes_in_group("central_crystal")
	if crystals.is_empty():
		crystals = get_tree().get_nodes_in_group("crystal")
	for c in crystals:
		if is_instance_valid(c) and not c.get("is_preview"):
			if smooth:
				focus_on_position(c.global_position)
			else:
				global_position = c.global_position
				is_centering = false
			return
