extends Area2D
class_name Arrow

# ========== EXPORTED VARIABLES ==========

@export var speed: float = 240.0
@export var damage: float = 16.0
@export var max_arc_height: float = 36.0

# ========== STATE VARIABLES ==========

var shooter: Node2D = null
var target_node: Node2D = null
var start_pos: Vector2 = Vector2.ZERO
var target_pos: Vector2 = Vector2.ZERO
var flight_duration: float = 0.5
var elapsed: float = 0.0
var arc_height: float = 24.0
var is_flying: bool = false

# ========== REFERENCES ==========

@onready var sprite: Sprite2D = $Sprite2D
@onready var shadow: Node2D = get_node_or_null("Shadow")

# ========== FUNCTIONS ==========

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0 # Handled via ballistic landing logic
	if shadow:
		shadow.top_level = true

func launch(from_pos: Vector2, to_pos: Vector2, target: Node2D = null, arrow_damage: float = 16.0) -> void:
	shooter = null
	start_pos = from_pos
	target_pos = to_pos
	target_node = target
	damage = arrow_damage
	elapsed = 0.0
	is_flying = true

	var dist = start_pos.distance_to(target_pos)
	flight_duration = max(0.2, dist / speed)
	# Parabolic peak proportional to horizontal distance
	arc_height = clampf(dist * 0.32, 10.0, max_arc_height)

	global_position = start_pos
	if shadow:
		shadow.global_position = start_pos

	_update_trajectory(0.0)

func _physics_process(delta: float) -> void:
	if not is_flying:
		return

	elapsed += delta
	var progress = clampf(elapsed / flight_duration, 0.0, 1.0)

	# Gentle tracking so moving enemies don't evade every shot
	if is_instance_valid(target_node) and not target_node.get("is_dead"):
		target_pos = target_pos.lerp(target_node.global_position, delta * 3.5)

	_update_trajectory(progress)

	if progress >= 1.0:
		_on_impact()

func _update_trajectory(progress: float) -> void:
	var ground_pos = start_pos.lerp(target_pos, progress)
	var height = 4.0 * arc_height * progress * (1.0 - progress)
	var current_pos = ground_pos - Vector2(0.0, height)

	global_position = current_pos

	# Align rotation tangent to ballistic trajectory curve
	var next_progress = min(1.0, progress + 0.03)
	var next_ground = start_pos.lerp(target_pos, next_progress)
	var next_h = 4.0 * arc_height * next_progress * (1.0 - next_progress)
	var next_pos = next_ground - Vector2(0.0, next_h)

	var trajectory_vector = next_pos - current_pos
	if trajectory_vector.length_squared() > 0.001:
		rotation = trajectory_vector.angle()

	# Update ground shadow
	if shadow and is_instance_valid(shadow):
		shadow.global_position = ground_pos
		shadow.global_rotation = 0.0
		var h_ratio = clampf(height / max(1.0, arc_height), 0.0, 1.0)
		shadow.modulate.a = lerp(0.5, 0.2, h_ratio)
		var s = lerp(1.0, 0.7, h_ratio)
		shadow.scale = Vector2(s, s)

func _on_impact() -> void:
	is_flying = false

	# Apply damage to designated target if valid
	var hit_entity: Node2D = null
	if is_instance_valid(target_node) and not target_node.get("is_dead"):
		var dist_to_target = global_position.distance_to(target_node.global_position)
		if dist_to_target <= 28.0:
			hit_entity = target_node

	# Area fallback if designated target shifted or was cleared
	if hit_entity == null:
		hit_entity = _find_closest_damageable(24.0)

	if hit_entity and hit_entity.has_method("take_damage"):
		hit_entity.take_damage(damage, shooter)

	# Clean up shadow and arrow node
	if shadow and is_instance_valid(shadow):
		shadow.queue_free()
	queue_free()

func _find_closest_damageable(max_dist: float) -> Node2D:
	var candidates: Array = []
	candidates.append_array(get_tree().get_nodes_in_group("enemies"))
	candidates.append_array(get_tree().get_nodes_in_group("animals"))

	var nearest: Node2D = null
	var nearest_d_sq = max_dist * max_dist

	for c in candidates:
		if not is_instance_valid(c) or c == shooter or c.get("is_dead"):
			continue
		var d_sq = global_position.distance_squared_to(c.global_position)
		if d_sq <= nearest_d_sq:
			nearest = c
			nearest_d_sq = d_sq

	return nearest
