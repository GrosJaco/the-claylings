extends State

var target_position: Vector2 = Vector2.ZERO
var target_enemy: Node2D = null
var target_facing: Vector2 = Vector2.ZERO
var attack_range: float = 24.0
var _nav_initialized: bool = false

var is_player_order: bool = false
var is_autonomous_assist: bool = false

func enter(msg := {}) -> void:
	_nav_initialized = false
	target_enemy = msg.get("target_enemy", null)
	target_facing = msg.get("target_facing", Vector2.ZERO)
	is_player_order = msg.get("is_player_order", false)
	is_autonomous_assist = msg.get("is_autonomous_assist", false)

	if target_enemy and is_instance_valid(target_enemy):
		target_position = target_enemy.global_position
	else:
		target_position = msg.get("target_position", clayling.global_position)

	# Ensure target position is snapped to the navigation mesh
	var nav_map = clayling.get_world_2d().navigation_map
	if nav_map.is_valid():
		var valid_pt = NavigationServer2D.map_get_closest_point(nav_map, target_position)
		if valid_pt != Vector2.ZERO and valid_pt.distance_to(target_position) < 32.0:
			target_position = valid_pt

	clayling.agent.target_position = target_position

	# Instantly face destination and start running animation to avoid 1-frame lag
	_face_target(target_position)
	var dir = clayling.last_direction if clayling.last_direction != "" else "down"
	var anim = "spearman_running_" + dir
	clayling._update_sprite_offset_for_animation(anim)
	clayling.sprite.play(anim)

func update(_delta: float) -> void:
	# Give NavigationAgent2D at least one physics frame to calculate path before checking is_navigation_finished
	if not _nav_initialized:
		_nav_initialized = true
		return

	# If pursuing an enemy, check target validity, leash, and strike range
	if target_enemy:
		if not is_instance_valid(target_enemy) or target_enemy.get("is_dead"):
			clayling.stop_moving()
			if is_player_order:
				clayling.guard_position = clayling.global_position
			clayling.change_state("SoldierStance", { "target_facing": target_facing })
			return

		var dist_to_enemy_sq = clayling.global_position.distance_squared_to(target_enemy.global_position)
		if dist_to_enemy_sq <= attack_range * attack_range:
			clayling.stop_moving()
			_face_target(target_enemy.global_position)
			clayling.change_state("SoldierAttack", { 
				"target_enemy": target_enemy, 
				"target_facing": target_facing,
				"is_player_order": is_player_order
			})
			return

		# Check micro-leash distance from guard post ONLY during autonomous assistance (never on player orders!)
		if is_autonomous_assist and clayling.guard_position != Vector2.ZERO:
			var dist_from_guard_sq = clayling.guard_position.distance_squared_to(clayling.global_position)
			if dist_from_guard_sq > 2500.0: # 50px squared
				# Break off pursuit and return to guard post
				clayling.stop_moving()
				clayling.change_state("SoldierMove", { 
					"target_position": clayling.guard_position, 
					"target_facing": clayling.formation_facing,
					"is_returning_to_post": true
				})
				return

		# Only repath if target enemy has moved > 16px
		if target_enemy.global_position.distance_squared_to(target_position) > 256.0:
			target_position = target_enemy.global_position
			clayling.agent.target_position = target_position

	# Check destination reached
	var dist_sq = clayling.global_position.distance_squared_to(target_position)
	if clayling.agent.is_navigation_finished() or dist_sq <= 16.0:
		if target_enemy and is_instance_valid(target_enemy) and not target_enemy.get("is_dead"):
			var dist_to_enemy_sq = clayling.global_position.distance_squared_to(target_enemy.global_position)
			if dist_to_enemy_sq <= attack_range * attack_range:
				clayling.stop_moving()
				_face_target(target_enemy.global_position)
				clayling.change_state("SoldierAttack", { 
					"target_enemy": target_enemy, 
					"target_facing": target_facing,
					"is_player_order": is_player_order
				})
				return
			else:
				# Target is still running away, continue pursuit
				target_position = target_enemy.global_position
				clayling.agent.target_position = target_position
				return

		clayling.stop_moving()
		if is_player_order:
			clayling.guard_position = clayling.global_position
		if target_facing != Vector2.ZERO:
			_face_direction(target_facing)
		elif "formation_facing" in clayling and clayling.formation_facing != Vector2.ZERO:
			_face_direction(clayling.formation_facing)
		clayling.change_state("SoldierToStance", { 
			"target_enemy": target_enemy, 
			"target_facing": target_facing,
			"is_player_order": is_player_order
		})

func _face_target(pos: Vector2) -> void:
	var diff = pos - clayling.global_position
	if abs(diff.x) * 1.5 >= abs(diff.y):
		clayling.last_direction = "side"
		clayling.set_flip_h(diff.x < 0)
	else:
		clayling.last_direction = "up" if diff.y < 0 else "down"

func _face_direction(dir_vec: Vector2) -> void:
	if abs(dir_vec.x) * 1.5 >= abs(dir_vec.y):
		clayling.last_direction = "side"
		clayling.set_flip_h(dir_vec.x < 0)
	else:
		clayling.last_direction = "up" if dir_vec.y < 0 else "down"
