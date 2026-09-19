extends CharacterBody2D
class_name Animal

# ========== EXPORTED VARIABLES ==========

@export_group("Stats")
@export var animal_name: String = "Animal"
@export var max_health: float = 20.0
@export var speed := 40.0
@export var wander_radius := 64.0
@export var idle_time_min := 4.0
@export var idle_time_max := 6.0

@export_group("Growth")
@export var grows_into: PackedScene = null
@export var growth_duration_min: float = 160.0
@export var growth_duration_max: float = 200.0

@export_group("Egg Laying")
@export var egg_item: ItemData = preload("res://Resources/Item Resources/Raw/egg.tres")
@export var egg_lay_interval_min: float = 60.0
@export var egg_lay_interval_max: float = 120.0

@export_group("Social / Following")
@export var follows_leader: bool = false
@export var follow_distance_max: float = 65.0
@export var follow_distance_stop: float = 28.0

@export_group("Loot")
@export var loot_table: Array[LootDrop] = []

# ========== REFERENCES ==========

@onready var world: Node2D = $".."
@onready var sprite: AnimatedSprite2D = $Pivot/AnimatedSprite2D
@onready var pivot: Node2D = $Pivot
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var agent: NavigationAgent2D = $NavigationAgent2D

# ========== STATE & VARIABLES ==========

var health: float = 20.0
var is_dead: bool = false
var threat: Node = null
var _threat_scan_timer: float = 0.0
var _egg_timer: float = 0.0
var _growth_timer: float = 0.0
var leader_animal: Animal = null
var _leader_search_timer: float = 0.0

# FSM
var states := {}
var current_state: AnimalState

# ========== FUNCTIONS ==========

func _ready() -> void:
	add_to_group("animals")
	if animal_name and not animal_name.is_empty():
		add_to_group(animal_name.to_lower())

	health = max_health
	_egg_timer = randf_range(egg_lay_interval_min, egg_lay_interval_max)
	if grows_into != null:
		_growth_timer = randf_range(growth_duration_min, growth_duration_max)

	# Load states dynamically
	states["Idle"] = preload("res://Scripts/Animal States/idle.gd").new()
	states["Wander"] = preload("res://Scripts/Animal States/wandering.gd").new()
	states["Flee"] = preload("res://Scripts/Animal States/fleeing.gd").new()
	
	# Link this Animal to all state instances
	for s in states.values():
		s.animal = self
	change_state("Idle")
	
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Growth timer toward adult stage
	if grows_into != null:
		_growth_timer -= delta
		if _growth_timer <= 0.0:
			grow_up()
			return

	# Periodic leader / mother scan
	if follows_leader:
		_leader_search_timer -= delta
		if _leader_search_timer <= 0.0:
			_leader_search_timer = randf_range(1.0, 1.5)
			_update_leader()

	# Egg laying timer (active while alive and not fleeing)
	if egg_item != null and current_state != states.get("Flee"):
		_egg_timer -= delta
		if _egg_timer <= 0.0:
			_egg_timer = randf_range(egg_lay_interval_min, egg_lay_interval_max)
			lay_egg()

	# Proactive threat detection
	_threat_scan_timer -= delta
	if _threat_scan_timer <= 0.0:
		_threat_scan_timer = randf_range(0.2, 0.28)
		if current_state != states.get("Flee"):
			var nearby_threat = _find_nearby_threat(95.0)
			if nearby_threat:
				threat = nearby_threat
				change_state("Flee", {"threat": threat})

	if current_state:
		current_state.update(delta)
	
	# Update velocity toward next path point
	if not agent.is_navigation_finished():
		var next_pos = agent.get_next_path_position()
		var dir = global_position.direction_to(next_pos)
		velocity = dir * speed
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()
	_handle_sprite_flip()

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity

func _handle_sprite_flip() -> void:
	if abs(velocity.x) > 1:
		sprite.flip_h = velocity.x < 0

func change_state(state_name: String, msg := {}) -> void:
	if is_dead:
		return
	if current_state:
		current_state.exit()
	current_state = states.get(state_name)
	if current_state:
		current_state.enter(msg)

func move_to(target_position: Vector2) -> void:
	if is_dead:
		return
	agent.target_position = target_position

func _find_nearby_threat(max_dist: float) -> Node2D:
	var threats = get_tree().get_nodes_in_group("threats")
	var max_dist_sq = max_dist * max_dist
	var nearest: Node2D = null
	var nearest_sq = max_dist_sq
	for t in threats:
		if not is_instance_valid(t) or t.get("is_dead"):
			continue
		var d_sq = global_position.distance_squared_to(t.global_position)
		if d_sq <= nearest_sq:
			nearest = t
			nearest_sq = d_sq
	return nearest

func _update_leader() -> void:
	if not follows_leader or is_dead:
		return
	if leader_animal != null:
		if not is_instance_valid(leader_animal) or leader_animal.is_dead or not leader_animal.is_inside_tree():
			leader_animal = null
		elif global_position.distance_squared_to(leader_animal.global_position) > 300.0 * 300.0:
			var closer = _find_nearest_leader(180.0)
			if closer:
				leader_animal = closer
	if leader_animal == null:
		leader_animal = _find_nearest_leader(250.0)

func _find_nearest_leader(max_dist: float) -> Animal:
	var potential_leaders = get_tree().get_nodes_in_group("animals")
	var max_dist_sq = max_dist * max_dist
	var nearest: Animal = null
	var nearest_sq = max_dist_sq

	for a in potential_leaders:
		if not is_instance_valid(a) or a == self or not (a is Animal):
			continue
		if a.is_dead or not a.is_inside_tree() or a.follows_leader:
			continue
		var d_sq = global_position.distance_squared_to(a.global_position)
		if d_sq <= nearest_sq:
			nearest = a
			nearest_sq = d_sq

	return nearest

# ---------- LIFE, DEATH & LOOT ----------

func take_damage(amount: float, _attacker: Node2D = null) -> void:
	if is_dead:
		return
	health = max(0.0, health - amount)
	if health <= 0.0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO

	if current_state:
		current_state.exit()
		current_state = null

	remove_from_group("animals")
	if animal_name and not animal_name.is_empty():
		remove_from_group(animal_name.to_lower())

	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	if sprite:
		sprite.play("death")

	_drop_loot()

	# Fade corpse away and remove node
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree():
		return

	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 1.5)
	fade_tween.tween_callback(queue_free)

func grow_up() -> void:
	if is_dead or grows_into == null:
		return
	is_dead = true
	if current_state:
		current_state.exit()
		current_state = null

	var adult = grows_into.instantiate()
	adult.global_position = global_position
	var target_parent = world if world else get_parent()
	target_parent.call_deferred("add_child", adult)
	queue_free()

func lay_egg() -> void:
	if is_dead or egg_item == null:
		return
	_spawn_ground_item(egg_item, 1)

func _drop_loot() -> void:
	for drop in loot_table:
		if drop == null or drop.item == null:
			continue
		if randf() <= drop.chance:
			var count = randi_range(drop.min_count, drop.max_count)
			if count > 0:
				_spawn_ground_item(drop.item, count, 6.0)

func _spawn_ground_item(item_data: ItemData, count: int, offset_range: float = 0.0) -> void:
	if item_data == null or count <= 0:
		return
	var scene = preload("res://Scenes/item.tscn")
	var item_node: WorldItem = scene.instantiate()
	item_node.data = item_data
	item_node.quantity = count
	var offset = Vector2.ZERO
	if offset_range > 0.0:
		offset = Vector2(randf_range(-offset_range, offset_range), randf_range(-offset_range, offset_range))
	item_node.global_position = global_position + offset
	var target_parent = world if world else get_parent()
	target_parent.call_deferred("add_child", item_node)
