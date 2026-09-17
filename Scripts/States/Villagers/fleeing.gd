extends State

var threat_node: Node2D = null
var safe_timer: float = 0.0
var repath_timer: float = 0.0

func enter(msg := {}) -> void:
	threat_node = msg.get("threat", null)
	safe_timer = 0.0
	repath_timer = 0.0
	_pick_flee_destination()

func update(delta: float) -> void:
	repath_timer -= delta

	var current_threat = _find_nearest_threat(160.0)
	if current_threat:
		threat_node = current_threat
		safe_timer = 0.0

		var dist_to_goal = clayling.global_position.distance_to(clayling.agent.target_position)
		if repath_timer <= 0.0 or clayling.agent.is_navigation_finished() or dist_to_goal < 20.0:
			repath_timer = randf_range(0.4, 0.6)
			_pick_flee_destination()
	else:
		safe_timer += delta
		if safe_timer >= 1.5:
			clayling.change_state("Idle")

func exit() -> void:
	clayling.stop_moving()
	threat_node = null

func _pick_flee_destination() -> void:
	var away_dir = Vector2.RIGHT.rotated(randf() * TAU)
	if threat_node and is_instance_valid(threat_node):
		var diff = clayling.global_position - threat_node.global_position
		if diff.length_squared() > 0.01:
			away_dir = diff.normalized()

	# Add random angular spread to disperse fleeing villagers
	away_dir = away_dir.rotated(randf_range(-0.5, 0.5))
	var target = clayling.global_position + away_dir * 110.0

	var nav_map = clayling.get_world_2d().navigation_map
	if nav_map.is_valid():
		var valid_pt = NavigationServer2D.map_get_closest_point(nav_map, target)
		if valid_pt != Vector2.ZERO:
			target = valid_pt

	clayling.move_to(target)

func _find_nearest_threat(max_dist: float) -> Node2D:
	var threats = clayling.get_tree().get_nodes_in_group("threats")
	var max_sq = max_dist * max_dist
	var nearest: Node2D = null
	var nearest_sq = max_sq

	for t in threats:
		if not is_instance_valid(t) or t.get("is_dead"):
			continue
		var d_sq = clayling.global_position.distance_squared_to(t.global_position)
		if d_sq <= nearest_sq:
			nearest = t
			nearest_sq = d_sq

	return nearest
