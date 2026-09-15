extends State

# ========== VARIABLES ==========

var target_tree: Node2D = null
var chop_cooldown: float = 0.8
var hit_delay: float = 0.6
var current_timer: float = 0.0
var damage_per_hit: int = 10
var _hit_pending: bool = true

# ========== FUNCTIONS ==========

func enter(msg: Dictionary = {}) -> void:
	if msg.has("target") and is_instance_valid(msg["target"]):
		target_tree = msg["target"]
		
		# Find interaction point
		var dest = target_tree.global_position
		if "interaction_point" in target_tree and target_tree.interaction_point:
			dest = target_tree.interaction_point.global_position
		elif target_tree.has_node("InteractionPoint"):
			dest = target_tree.get_node("InteractionPoint").global_position
			
		clayling.move_to(dest)
	else:
		clayling.change_state("Idle")
		
func update(delta: float) -> void:
	# Safety Check
	if not is_instance_valid(target_tree) or not target_tree.get("is_marked_for_harvest"):
		clayling.change_state("Idle")
		return
	# Movement Logic
	var dist = clayling.global_position.distance_to(clayling.agent.target_position)
	if dist > 14.0:
		return
	clayling.velocity = Vector2.ZERO
	_face_tree()
	clayling.offset_sprite(8, 0)
	if clayling.sprite.animation != "woodcutting_side":
		clayling.play_forced_animation("woodcutting_side")
		
	# Chopping Logic
	current_timer += delta
	
	if _hit_pending and current_timer >= hit_delay:
		_perform_chop()
		_hit_pending = false
	
	if current_timer >= chop_cooldown:
		current_timer = 0.0
		_hit_pending = true
		
func exit() -> void:
	target_tree = null
	current_timer = 0.0
	_hit_pending = true
	clayling.play_forced_animation("")
	clayling.offset_sprite(0, 0)
	
# ========== HELPERS ==========

func _face_tree():
	if target_tree.global_position.x < clayling.global_position.x:
		clayling.set_flip_h(true)
	else:
		clayling.set_flip_h(false)
		
func _perform_chop():
	if not is_instance_valid(target_tree):
		return
	
	SoundManager.play_at("chop", clayling.global_position, 0.1)
	
	if target_tree.has_method("take_damage"):
		target_tree.take_damage(damage_per_hit)
	else:
		target_tree.queue_free()
