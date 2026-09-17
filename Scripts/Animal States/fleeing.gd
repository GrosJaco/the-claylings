extends AnimalState

var threat_node: Node = null
var safe_timer: float = 0.0
var repath_timer: float = 0.0

func enter(msg := {}) -> void:
	threat_node = msg.get("threat", null)
	safe_timer = 0.0
	repath_timer = 0.0
	animal.sprite.play("run")
	_pick_flee_target()

func update(delta: float) -> void:
	repath_timer -= delta

	var active_threat = threat_node
	if not is_instance_valid(active_threat) or active_threat.get("is_dead"):
		active_threat = _find_nearest_threat(130.0)
		threat_node = active_threat

	if active_threat and is_instance_valid(active_threat):
		var dist = animal.global_position.distance_to(active_threat.global_position)
		if dist > 130.0:
			safe_timer += delta
			if safe_timer >= 1.2:
				animal.change_state("Idle")
		else:
			safe_timer = 0.0
			var dist_to_target = animal.global_position.distance_to(animal.agent.target_position)
			if repath_timer <= 0.0 or animal.agent.is_navigation_finished() or dist_to_target < 16.0:
				repath_timer = randf_range(0.35, 0.5)
				_pick_flee_target()
	else:
		safe_timer += delta
		if safe_timer >= 1.2:
			animal.change_state("Idle")

func exit() -> void:
	animal.velocity = Vector2.ZERO
	threat_node = null
	animal.threat = null

func _pick_flee_target() -> void:
	var away_dir = Vector2.RIGHT.rotated(randf() * TAU)
	if threat_node and is_instance_valid(threat_node):
		var diff = animal.global_position - threat_node.global_position
		if diff.length_squared() > 0.01:
			away_dir = diff.normalized()

	away_dir = away_dir.rotated(randf_range(-0.6, 0.6))
	var target = animal.global_position + away_dir * 95.0

	var nav_map = animal.get_world_2d().navigation_map
	if nav_map.is_valid():
		var valid_pt = NavigationServer2D.map_get_closest_point(nav_map, target)
		if valid_pt != Vector2.ZERO:
			target = valid_pt

	animal.move_to(target)

func _find_nearest_threat(max_dist: float) -> Node2D:
	var threats = animal.get_tree().get_nodes_in_group("threats")
	var max_sq = max_dist * max_dist
	var nearest: Node2D = null
	var nearest_sq = max_sq

	for t in threats:
		if not is_instance_valid(t) or t.get("is_dead"):
			continue
		var d_sq = animal.global_position.distance_squared_to(t.global_position)
		if d_sq <= nearest_sq:
			nearest = t
			nearest_sq = d_sq

	return nearest
