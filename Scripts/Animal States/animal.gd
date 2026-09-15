extends CharacterBody2D
class_name Animal

@export var speed := 40.0
@export var wander_radius := 64.0
@export var idle_time_min := 4.0
@export var idle_time_max := 6.0

@onready var world: Node2D = $".."
@onready var sprite: AnimatedSprite2D = $Pivot/AnimatedSprite2D
@onready var pivot: Node2D = $Pivot
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var agent: NavigationAgent2D = $NavigationAgent2D

var threat: Node = null

# FSM
var states := {}
var current_state: AnimalState

func _ready():
	add_to_group("chicken")
	add_to_group("animals")

	# Load states dynamically
	states["Idle"] = preload("res://Scripts/Animal States/idle.gd").new()
	states["Wander"] = preload("res://Scripts/Animal States/wandering.gd").new()
	states["Flee"] = preload("res://Scripts/Animal States/fleeing.gd").new()
	
	# Link this Animal to all state instances
	for s in states.values():
		s.animal = self
	change_state("Idle")
	
func _physics_process(delta):
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

func change_state(state_name: String, msg := {}):
	if current_state:
		current_state.exit()
	current_state = states.get(state_name)
	if current_state:
		current_state.enter(msg)

func move_to(target_position: Vector2):
	agent.target_position = target_position
