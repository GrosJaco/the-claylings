extends State

# ========== VARIABLES ==========

var target_plant: Node2D = null
var damage_per_hit: int = 10

# ========== FUNCTIONS ==========

func enter(msg: Dictionary = {}) -> void:
	if msg.has("target") and is_instance_valid(msg["target"]):
		target_plant = msg["target"]
		
		var dest = target_plant.global_position + Vector2(0, 10)
		
		if "interaction_point" in target_plant and target_plant.interaction_point:
			dest = target_plant.interaction_point.global_position
		elif target_plant.has_node("InteractionPoint"):
			dest = target_plant.get_node("InteractionPoint").global_position
			
		clayling.move_to(dest)
	else:
		clayling.change_state("Idle")

func update(delta: float) -> void:
	if not is_instance_valid(target_plant) or not target_plant.get("is_marked_for_harvest"):
		clayling.change_state("Idle")
		return

	# --- ANIMATION LOGIC ---
	# If the animation just finished this frame, deal damage!
	if clayling.animation_over:
		clayling.animation_over = false
		_perform_forage()
		return 

	# --- MOVEMENT LOGIC ---
	var dist = clayling.global_position.distance_to(clayling.agent.target_position)
	if dist > 14.0:
		return
		
	# We arrived at the plant
	clayling.velocity = Vector2.ZERO
	clayling.offset_sprite(0, 0) # No X offset needed for Up/Down animations
	
	# Start the animation loop
	if clayling.sprite.animation != "interacting_up":
		clayling.play_forced_animation("interacting_up")

func exit() -> void:
	target_plant = null
	clayling.animation_over = false # Reset just in case we exit mid-animation

# ========== HELPERS ==========

func _perform_forage():
	if not is_instance_valid(target_plant):
		return
	
	SoundManager.play_at("grass", clayling.global_position, 0.3)
	
	if clayling.personality_trait == "Curious" and randf() < 0.25:
		if "resource_item" in target_plant and target_plant.resource_item and clayling.world and clayling.world.has_method("drop_item"):
			clayling.world.drop_item(target_plant.resource_item, 1, clayling.world.get_grid_position(clayling.global_position))

	if target_plant.has_method("take_damage"):
		target_plant.take_damage(damage_per_hit)
	else:
		target_plant.queue_free()
