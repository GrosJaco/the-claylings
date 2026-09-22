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

func _ready():
	add_to_group("camera")
	target_zoom = zoom.x
	target_position = global_position

func shake(intensity: float = 6.0, duration: float = 0.35) -> void:
	_shake_intensity = intensity
	_shake_timer = duration

func _process(delta: float):
	if _shake_timer > 0.0:
		_shake_timer -= delta
		offset = Vector2(randf_range(-_shake_intensity, _shake_intensity), randf_range(-_shake_intensity, _shake_intensity))
		if _shake_timer <= 0.0:
			offset = Vector2.ZERO

	zoom = zoom.lerp(Vector2(target_zoom, target_zoom), smooth_factor * delta)

	if is_centering:
		global_position = global_position.lerp(target_position, smooth_factor * delta)
		if global_position.distance_to(target_position) < 1.5:
			global_position = target_position
			is_centering = false
	
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction == Vector2.ZERO:
		var dx = 0.0
		var dy = 0.0
		if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
			dx += 1.0
		if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_Q):
			dx -= 1.0
		if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
			dy += 1.0
		if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_Z):
			dy -= 1.0
		direction = Vector2(dx, dy).normalized()
	
	if direction != Vector2.ZERO:
		is_centering = false
		position += direction * keyboard_pan_speed * delta / zoom.x

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

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H or event.keycode == KEY_HOME:
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
