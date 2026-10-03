extends Wall
class_name WoodGate

enum Orientation { HORIZONTAL = 0, VERTICAL = 1 }

@export_enum("Horizontal", "Vertical") var orientation: int = Orientation.HORIZONTAL
@export var is_manual_orientation: bool = false

var is_open: bool = false
var occupants: Array[Node2D] = []
var _close_timer: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $SpriteRoot/AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $StaticBody2D/CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea

func _ready() -> void:
	super._ready()
	add_to_group("gates")
	
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	_apply_orientation()

# Keep ground navigation mesh intact so Claylings can pathfind through closed gates
func _block_navigation(_pos: Vector2i) -> void:
	pass

func _restore_navigation(_pos: Vector2i) -> void:
	pass

func _physics_process(delta: float) -> void:
	if is_preview:
		return
	
	# Purge invalid, freed or dead occupants
	var i = occupants.size() - 1
	while i >= 0:
		var occ = occupants[i]
		if not is_instance_valid(occ) or (occ.has_method("get") and occ.get("is_dead")):
			occupants.remove_at(i)
		i -= 1

	if is_open:
		if occupants.is_empty():
			_close_timer += delta
			if _close_timer >= 0.35:
				_close_timer = 0.0
				close_gate()
		else:
			_close_timer = 0.0
	else:
		if not occupants.is_empty():
			open_gate()

func _on_detection_area_body_entered(body: Node2D) -> void:
	if is_preview:
		return
	if body.is_in_group("claylings") and not body in occupants:
		occupants.append(body)
		if not is_open:
			open_gate()

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body in occupants:
		occupants.erase(body)

func open_gate() -> void:
	if is_open:
		return
	is_open = true
	_close_timer = 0.0
	
	if animated_sprite:
		if orientation == Orientation.HORIZONTAL:
			animated_sprite.play("open_horizontal")
		else:
			animated_sprite.play("open_vertical")
			
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
		
	if SoundManager:
		SoundManager.play_at("pop", global_position, randf_range(-0.1, 0.1))

func close_gate() -> void:
	if not is_open:
		return
	is_open = false
	_close_timer = 0.0
	
	if animated_sprite:
		if orientation == Orientation.HORIZONTAL:
			animated_sprite.play("close_horizontal")
		else:
			animated_sprite.play("close_vertical")
			
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
		
	if SoundManager:
		SoundManager.play_at("pop", global_position, randf_range(-0.2, 0.0))

func toggle_orientation() -> void:
	is_manual_orientation = true
	if orientation == Orientation.HORIZONTAL:
		orientation = Orientation.VERTICAL
	else:
		orientation = Orientation.HORIZONTAL
	_apply_orientation()

func update_connections() -> void:
	if not is_manual_orientation:
		var pos = get_tile_pos()
		var has_left = is_connected_at(pos + Vector2i(-1, 0))
		var has_right = is_connected_at(pos + Vector2i(1, 0))
		var has_up = is_connected_at(pos + Vector2i(0, -1))
		var has_down = is_connected_at(pos + Vector2i(0, 1))

		var horizontal_neighbors = has_left or has_right
		var vertical_neighbors = has_up or has_down

		if horizontal_neighbors and not vertical_neighbors:
			orientation = Orientation.HORIZONTAL
		elif vertical_neighbors and not horizontal_neighbors:
			orientation = Orientation.VERTICAL
			
	_apply_orientation()

func _apply_orientation() -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
		
	if orientation == Orientation.HORIZONTAL:
		if is_open:
			animated_sprite.animation = "open_horizontal"
			animated_sprite.frame = 4
		else:
			animated_sprite.animation = "open_horizontal"
			animated_sprite.frame = 0
	else:
		if is_open:
			animated_sprite.animation = "open_vertical"
			animated_sprite.frame = 4
		else:
			animated_sprite.animation = "open_vertical"
			animated_sprite.frame = 0

func update_sprite() -> void:
	_apply_orientation()
