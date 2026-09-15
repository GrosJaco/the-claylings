extends State

# How far from its current position the clayling will move
var wander_radius = 75
func enter(msg := {}) -> void:
	var target_pos = clayling.global_position
	var found = false
	for attempt in range(20):
		var candidate = clayling.global_position + Vector2(randf_range(-wander_radius, wander_radius), randf_range(-wander_radius, wander_radius))
		if clayling.world and clayling.world.building_manager:
			var grid_pos = clayling.world.get_grid_position(candidate)
			if not clayling.world.building_manager.used_tiles.has(grid_pos):
				target_pos = candidate
				found = true
				break
		else:
			target_pos = candidate
			found = true
			break

	if found:
		clayling.move_to(target_pos)
	else:
		clayling.change_state("Idle")

func update(delta: float) -> void:
	if clayling.global_position.distance_to(clayling.agent.target_position) < 8.0:
		clayling.velocity = Vector2.ZERO
		clayling.change_state("Idle")
