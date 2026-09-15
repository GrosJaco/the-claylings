extends State

# ========== VARIABLES ==========

var target_ore: Node2D = null
var mine_cooldown: float = 0.8
var hit_delay: float = 0.6
var current_timer: float = 0.0
var damage_per_hit: int = 10
var _hit_pending: bool = true

# ========== FUNCTIONS ==========

func enter(msg: Dictionary = {}) -> void:
	if msg.has("target") and is_instance_valid(msg["target"]):
		target_ore = msg["target"]
		
		var dest = target_ore.global_position
		if "interaction_point" in target_ore and target_ore.interaction_point:
			dest = target_ore.interaction_point.global_position
		elif target_ore.has_node("InteractionPoint"):
			dest = target_ore.get_node("InteractionPoint").global_position
			
		clayling.move_to(dest)
	else:
		clayling.change_state("Idle")
		
func update(delta: float) -> void:
	if not is_instance_valid(target_ore) or not target_ore.get("is_marked_for_harvest"):
		clayling.change_state("Idle")
		return
	
	var dist = clayling.global_position.distance_to(clayling.agent.target_position)
	if dist > 14.0:
		return
		
	clayling.velocity = Vector2.ZERO
	_face_ore()
	clayling.offset_sprite(8, 0)
	
	if clayling.sprite.animation != "mining_side":
		clayling.play_forced_animation("mining_side")
	
	current_timer += delta
	
	if _hit_pending and current_timer >= hit_delay:
		_perform_mine()
		_hit_pending = false
	
	if current_timer >= mine_cooldown:
		current_timer = 0.0
		_hit_pending = true
		
func exit() -> void:
	target_ore = null
	current_timer = 0.0
	_hit_pending = true
	clayling.play_forced_animation("")
	clayling.offset_sprite(0, 0)
	
# ========== HELPERS ==========

func _face_ore():
	if target_ore.global_position.x < clayling.global_position.x:
		clayling.set_flip_h(true)
	else:
		clayling.set_flip_h(false)
func _perform_mine():
	if not is_instance_valid(target_ore):
		return
	
	SoundManager.play_at("rock hit", clayling.global_position, 0.1)
	
	if target_ore.has_method("take_damage"):
		target_ore.take_damage(damage_per_hit)
	else:
		target_ore.queue_free()
