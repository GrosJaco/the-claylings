extends State

var target_enemy: Node2D = null
var target_facing: Vector2 = Vector2.ZERO
var tension_timer: float = 0.0
var base_tension_duration: float = 6.0
var max_tension_duration: float = 6.0
var attack_range: float = 26.0
var alert_range: float = 150.0

var assist_range: float = 70.0
var max_leash_dist: float = 45.0
var _scan_timer: float = 0.0

var is_player_order: bool = false

func enter(msg := {}) -> void:
	target_enemy = msg.get("target_enemy", null)
	if target_enemy and (not is_instance_valid(target_enemy) or target_enemy.get("is_dead")):
		target_enemy = null

	is_player_order = msg.get("is_player_order", false)
	target_facing = msg.get("target_facing", clayling.formation_facing if "formation_facing" in clayling else Vector2.ZERO)
	tension_timer = 0.0
	max_tension_duration = base_tension_duration + randf_range(-1.0, 1.0)
	_scan_timer = randf_range(0.0, 0.1)
	clayling.stop_moving()
	clayling.force_animation = ""

	# If ordered target is alive and outside attack reach, resume pursuit immediately
	if target_enemy and is_instance_valid(target_enemy) and not target_enemy.get("is_dead") and is_player_order:
		var reach_sq = (attack_range + 4.0) * (attack_range + 4.0)
		if clayling.global_position.distance_squared_to(target_enemy.global_position) > reach_sq:
			clayling.change_state("SoldierMove", { 
				"target_enemy": target_enemy, 
				"target_facing": target_facing,
				"is_player_order": true
			})
			return

	# Clean up dead attacker reference
	if clayling.last_attacker and (not is_instance_valid(clayling.last_attacker) or clayling.last_attacker.get("is_dead")):
		clayling.last_attacker = null
		clayling.is_under_attack = false
		clayling._under_attack_timer = 0.0

	if clayling.is_under_attack and clayling.last_attacker and is_instance_valid(clayling.last_attacker) and not clayling.last_attacker.get("is_dead"):
		_face_target(clayling.last_attacker.global_position)
	elif target_facing != Vector2.ZERO:
		_face_direction(target_facing)
	elif target_enemy and is_instance_valid(target_enemy) and not target_enemy.get("is_dead"):
		_face_target(target_enemy.global_position)

	_play_stance_animation()

func update(delta: float) -> void:
	# 1. Clean up dead attacker reference
	if clayling.last_attacker and (not is_instance_valid(clayling.last_attacker) or clayling.last_attacker.get("is_dead")):
		clayling.last_attacker = null
		clayling.is_under_attack = false
		clayling._under_attack_timer = 0.0

	# 2. Priority 0: Active targeted entity (e.g. from player attack order against enemy or chicken)
	if target_enemy and is_instance_valid(target_enemy) and not target_enemy.get("is_dead"):
		var dist_to_target_sq = clayling.global_position.distance_squared_to(target_enemy.global_position)
		var reach_sq = (attack_range + 4.0) * (attack_range + 4.0)
		if dist_to_target_sq <= reach_sq:
			clayling.change_state("SoldierAttack", { 
				"target_enemy": target_enemy, 
				"target_facing": target_facing,
				"is_player_order": is_player_order
			})
			return
		elif is_player_order:
			clayling.change_state("SoldierMove", { 
				"target_enemy": target_enemy, 
				"target_facing": target_facing,
				"is_player_order": true
			})
			return

	# 3. PRIORITY #1: Strike ANY living enemy in spear reach (<= 30px) immediately!
	var melee_target = clayling.find_nearest_enemy(attack_range + 4.0)
	if melee_target:
		clayling.change_state("SoldierAttack", { "target_enemy": melee_target, "target_facing": target_facing })
		return

	# Throttled perception scans (assistance & alert range)
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = randf_range(0.12, 0.18)

		# 3. PRIORITY #2: Assist nearby ally under attack within 70px with slight micro-movement (<= 45px)
		var threat = clayling.find_threat_to_assist(assist_range)
		if threat and is_instance_valid(threat) and not threat.get("is_dead"):
			var guard_origin = clayling.guard_position if clayling.guard_position != Vector2.ZERO else clayling.global_position
			var max_reach = max_leash_dist + attack_range
			if guard_origin.distance_squared_to(threat.global_position) <= max_reach * max_reach:
				tension_timer = 0.0
				var reach_sq = (attack_range + 4.0) * (attack_range + 4.0)
				if clayling.global_position.distance_squared_to(threat.global_position) <= reach_sq:
					clayling.change_state("SoldierAttack", { "target_enemy": threat, "target_facing": target_facing })
					return
				else:
					clayling.change_state("SoldierMove", { 
						"target_enemy": threat, 
						"target_facing": target_facing,
						"is_autonomous_assist": true
					})
					return

		# 4. If no threat, return to guard post if displaced
		if clayling.guard_position != Vector2.ZERO and clayling.global_position.distance_squared_to(clayling.guard_position) > 64.0:
			clayling.change_state("SoldierMove", { 
				"target_position": clayling.guard_position, 
				"target_facing": clayling.formation_facing,
				"is_returning_to_post": true
			})
			return

		# 5. Alert range (150px): maintain combat stance while holding formation
		var max_alert_sq = alert_range * alert_range
		if target_enemy == null or not is_instance_valid(target_enemy) or target_enemy.get("is_dead") or clayling.global_position.distance_squared_to(target_enemy.global_position) > max_alert_sq:
			target_enemy = clayling.find_nearest_enemy(alert_range)

	if target_enemy and is_instance_valid(target_enemy) and not target_enemy.get("is_dead"):
		tension_timer = 0.0

		# Maintain formation facing unless personally attacked by a living enemy
		if clayling.is_under_attack and clayling.last_attacker and is_instance_valid(clayling.last_attacker) and not clayling.last_attacker.get("is_dead"):
			_face_target(clayling.last_attacker.global_position)
		elif target_facing != Vector2.ZERO:
			_face_direction(target_facing)
		elif "formation_facing" in clayling and clayling.formation_facing != Vector2.ZERO:
			_face_direction(clayling.formation_facing)
		else:
			_face_target(target_enemy.global_position)

		_play_stance_animation()
		return

	# 6. If no enemy within 150px, tick tension timer to relax back to idle
	tension_timer += delta
	if tension_timer >= max_tension_duration:
		clayling.change_state("SoldierIdle", { "target_facing": target_facing })

func _play_stance_animation() -> void:
	var dir = clayling.last_direction if clayling.last_direction != "" else "down"
	var anim_name = "spearman_combat_stance_" + dir
	clayling._update_sprite_offset_for_animation(anim_name)
	if clayling.sprite.animation != anim_name:
		clayling.sprite.play(anim_name)

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
