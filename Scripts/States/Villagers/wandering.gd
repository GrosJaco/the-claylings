extends State

var wander_radius = 75
var wander_timer: float = 0.0
const MAX_WANDER_TIME: float = 3.0

func enter(msg := {}) -> void:
	wander_timer = 0.0
	var target_pos = clayling.global_position
	var found = false
	var nav_map = clayling.get_world_2d().navigation_map

	for attempt in range(20):
		var candidate = clayling.global_position + Vector2(randf_range(-wander_radius, wander_radius), randf_range(-wander_radius, wander_radius))
		if nav_map.is_valid():
			var valid_pt = NavigationServer2D.map_get_closest_point(nav_map, candidate)
			if valid_pt != Vector2.ZERO and valid_pt.distance_to(candidate) < 24.0:
				candidate = valid_pt
			else:
				continue

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
	wander_timer += delta
	if wander_timer >= MAX_WANDER_TIME or clayling.global_position.distance_to(clayling.agent.target_position) < 8.0 or clayling.agent.is_navigation_finished():
		clayling.stop_moving()
		clayling.change_state("Idle")

func exit() -> void:
	clayling.stop_moving()
