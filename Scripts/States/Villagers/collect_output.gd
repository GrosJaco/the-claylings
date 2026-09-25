extends State

var target_building: Node2D = null

func enter(msg := {}) -> void:
	target_building = msg.get("building", null)
	
	if target_building == null or !is_instance_valid(target_building):
		clayling.change_state("Idle")
		return
		
	var dest = target_building.global_position
	if "interaction_point" in target_building and target_building.interaction_point:
		dest += target_building.interaction_point.position
	clayling.move_to(dest)

func exit() -> void:
	clayling.force_animation = ""

func update(_delta: float) -> void:
	if !is_instance_valid(target_building):
		clayling.change_state("Idle")
		return

	clayling.play_forced_animation("")

	var dest = target_building.global_position
	if "interaction_point" in target_building and target_building.interaction_point:
		dest += target_building.interaction_point.position
		
	if clayling.global_position.distance_to(dest) < 12.0 or clayling.agent.is_navigation_finished():
		_grab_output_and_haul()

func _grab_output_and_haul() -> void:
	if target_building.has_method("take_output"):
		var extracted = target_building.take_output()
		
		if not extracted.is_empty():
			clayling.pick_item(extracted["item"], extracted["count"])
			var storage = clayling.world.find_nearest_storage_with_space(clayling.global_position, extracted["item"])
			if storage:
				clayling.change_state("Haul", {"storage": storage})
				return
			else:
				clayling.drop_item(-1, true)
				
	clayling.change_state("Idle")
