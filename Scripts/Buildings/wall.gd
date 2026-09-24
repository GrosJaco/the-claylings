extends Building
class_name Wall

# Global registry of active walls for O(1) neighbor lookups
static var walls_map: Dictionary = {}

@export var wall_texture: Texture2D = preload("res://Art/Buildings/Wooden Walls.png")
@export var tile_size: Vector2i = Vector2i(16, 32)

# Sprite atlas coordinates matching the user's layout:
# Row 0: Top-Left L (0,0), Vertical 1 (1,0), Vertical 2 (2,0), Top-Right L (3,0)
# Row 1: Bottom-Left L (0,1), Horizontal 1 (1,1), Horizontal 2 (2,1), Bottom-Right L (3,1)
# Row 2: Isolated Post (0,2), End-Left (1,2), End-Right (2,2)
# Row 3: T Right (0,3), T Left (1,3), Cross (2,3)
const TILE_MAP = {
	"isolated": [Vector2i(0, 2)],
	"horizontal": [Vector2i(1, 1), Vector2i(2, 1)],
	"vertical": [Vector2i(1, 0), Vector2i(2, 0)],
	"corner_top_left": [Vector2i(0, 0)],
	"corner_top_right": [Vector2i(3, 0)],
	"corner_bottom_left": [Vector2i(0, 1)],
	"corner_bottom_right": [Vector2i(3, 1)],
	"end_left": [Vector2i(1, 2)],
	"end_right": [Vector2i(2, 2)],
	"t_right": [Vector2i(0, 3)],
	"t_left": [Vector2i(1, 3)],
	"cross": [Vector2i(2, 3)],
}

var _is_registered: bool = false
var _hit_tween: Tween = null

func _ready() -> void:
	super._ready()
	add_to_group("walls")
	
	if not is_preview:
		_register_wall()
		update_connections()
		_notify_neighbors()

func get_tile_pos() -> Vector2i:
	return Vector2i(
		int(floor(global_position.x / 16.0)),
		int(floor((global_position.y - 1.0) / 16.0))
	)

func _register_wall() -> void:
	if not _is_registered:
		var pos = get_tile_pos()
		walls_map[pos] = self
		_is_registered = true

func _unregister_wall() -> void:
	if _is_registered:
		var pos = get_tile_pos()
		if walls_map.get(pos) == self:
			walls_map.erase(pos)
		_is_registered = false

func is_wall_at(pos: Vector2i) -> bool:
	if not walls_map.has(pos):
		return false
	var w = walls_map[pos]
	return is_instance_valid(w) and not w.is_preview and not w.is_queued_for_deletion()

func update_connections() -> void:
	if not sprite is Sprite2D:
		return
	
	var pos = get_tile_pos()
	var has_up = is_wall_at(pos + Vector2i(0, -1))
	var has_down = is_wall_at(pos + Vector2i(0, 1))
	var has_left = is_wall_at(pos + Vector2i(-1, 0))
	var has_right = is_wall_at(pos + Vector2i(1, 0))
	
	var connection_type = _determine_connection_type(has_up, has_down, has_left, has_right)
	var variants: Array = TILE_MAP.get(connection_type, [Vector2i(0, 2)])
	
	# Pick deterministic variant based on tile position
	var variant_index = abs(pos.x * 37 + pos.y * 17) % variants.size()
	var coord: Vector2i = variants[variant_index]
	
	var s2d: Sprite2D = sprite as Sprite2D
	s2d.texture = wall_texture
	s2d.region_enabled = true
	s2d.region_rect = Rect2(coord.x * tile_size.x, coord.y * tile_size.y, tile_size.x, tile_size.y)

func _determine_connection_type(has_up: bool, has_down: bool, has_left: bool, has_right: bool) -> String:
	# 4-way intersection (Cross)
	if has_up and has_down and has_left and has_right:
		return "cross"

	# 3-way T-junctions
	if has_up and has_down and has_right and not has_left:
		return "t_right"
	if has_up and has_down and has_left and not has_right:
		return "t_left"
	if has_left and has_right and (has_down or has_up):
		return "cross"

	# 4 corners
	if has_down and has_right and not has_up and not has_left:
		return "corner_top_left"
	if has_down and has_left and not has_up and not has_right:
		return "corner_top_right"
	if has_up and has_right and not has_down and not has_left:
		return "corner_bottom_left"
	if has_up and has_left and not has_down and not has_right:
		return "corner_bottom_right"
		
	# Straight lines
	if has_left and has_right and not has_up and not has_down:
		return "horizontal"
	if has_up and has_down and not has_left and not has_right:
		return "vertical"
		
	# Line ends
	if has_right and not has_left and not has_up and not has_down:
		return "end_left"
	if has_left and not has_right and not has_up and not has_down:
		return "end_right"
	if (has_up or has_down) and not has_left and not has_right:
		return "vertical"
		
	# Isolated
	if not has_up and not has_down and not has_left and not has_right:
		return "isolated"
		
	# Fallbacks
	if has_left and has_right:
		return "horizontal"
	if has_up and has_down:
		return "vertical"
	if has_down and has_right:
		return "corner_top_left"
	if has_down and has_left:
		return "corner_top_right"
	if has_up and has_right:
		return "corner_bottom_left"
	if has_up and has_left:
		return "corner_bottom_right"
		
	return "isolated"

func _notify_neighbors() -> void:
	var pos = get_tile_pos()
	var offsets = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for offset in offsets:
		var n_pos = pos + offset
		if walls_map.has(n_pos):
			var neighbor = walls_map[n_pos]
			if is_instance_valid(neighbor) and not neighbor.is_queued_for_deletion():
				neighbor.update_connections()

func take_damage(amount: int) -> void:
	current_health = max(current_health - amount, 0)
	
	if SoundManager:
		SoundManager.play_at("chop", global_position, randf_range(-0.15, 0.15))
		
	# Subtle punch & shake tween on hit
	if sprite:
		if _hit_tween and _hit_tween.is_valid():
			_hit_tween.kill()
		_hit_tween = create_tween()
		sprite.scale = Vector2(1.1, 0.92)
		sprite.position = Vector2(randf_range(-1.5, 1.5), 0)
		_hit_tween.parallel().tween_property(sprite, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_hit_tween.parallel().tween_property(sprite, "position", Vector2.ZERO, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	if current_health <= 0:
		destroyed()

func destroyed() -> void:
	_unregister_wall()
	_notify_neighbors()
	
	if SoundManager:
		SoundManager.play_at("tree fall", global_position)
		
	super.destroyed()
