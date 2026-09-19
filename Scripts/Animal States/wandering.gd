extends AnimalState

@export var wander_radius := 64

func enter(msg := {}) -> void:
	var target_pos = animal.global_position
	var center_pos = animal.global_position
	var radius = wander_radius

	# Follow leader/mother if designated
	if animal.get("follows_leader") and is_instance_valid(animal.get("leader_animal")) and not animal.leader_animal.is_dead:
		center_pos = animal.leader_animal.global_position
		radius = animal.follow_distance_stop + 10.0

	var found = false
	for attempt in range(20):
		var candidate = center_pos + Vector2(randf_range(-radius, radius), randf_range(-radius, radius))
		if animal.world and animal.world.building_manager:
			var grid_pos = animal.world.get_grid_position(candidate)
			if not animal.world.building_manager.used_tiles.has(grid_pos):
				target_pos = candidate
				found = true
				break
		else:
			target_pos = candidate
			found = true
			break

	if found:
		animal.move_to(target_pos)
		animal.sprite.play("run")
	else:
		animal.change_state("Idle")

func update(delta: float) -> void:
	# If there is a threat, flee immediately
	if animal.threat:
		animal.change_state("Flee", {"threat": animal.threat})
		return

	# If following leader and leader walked too far away, repath toward leader
	if animal.get("follows_leader") and is_instance_valid(animal.get("leader_animal")) and not animal.leader_animal.is_dead:
		var dist_to_leader = animal.global_position.distance_to(animal.leader_animal.global_position)
		if dist_to_leader > animal.follow_distance_max:
			var repath_target = animal.leader_animal.global_position + Vector2(randf_range(-16, 16), randf_range(-16, 16))
			animal.move_to(repath_target)
	
	# Check if the animal reached the target
	if animal.global_position.distance_to(animal.agent.target_position) < 10.0:
		animal.velocity = Vector2.ZERO
		animal.change_state("Idle")
