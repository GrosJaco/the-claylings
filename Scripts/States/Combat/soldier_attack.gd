extends State

var target_enemy: Node2D = null
var attack_damage: float = 25.0
var damage_applied: bool = false
var elapsed: float = 0.0
var attack_duration: float = 0.5 # 6 frames at 12 fps = 0.5s

var target_facing: Vector2 = Vector2.ZERO

var is_player_order: bool = false

func enter(msg := {}) -> void:
	target_enemy = msg.get("target_enemy", null)
	target_facing = msg.get("target_facing", clayling.formation_facing if "formation_facing" in clayling else Vector2.ZERO)
	is_player_order = msg.get("is_player_order", false)
	damage_applied = false
	elapsed = 0.0
	clayling.stop_moving()

	if target_enemy and is_instance_valid(target_enemy):
		_face_target(target_enemy.global_position)

	var dir = clayling.last_direction if clayling.last_direction != "" else "down"
	var anim_name = "spearman_attacking_" + dir
	clayling.play_forced_animation(anim_name)

func update(delta: float) -> void:
	elapsed += delta

	# Apply damage at strike peak (frame 3/6 ~ 0.25s)
	if not damage_applied and elapsed >= 0.25:
		damage_applied = true
		if target_enemy and is_instance_valid(target_enemy):
			if target_enemy.has_method("take_damage"):
				var dmg = attack_damage
				if clayling.personality_trait == "Brave":
					dmg *= 1.2
				target_enemy.take_damage(dmg, clayling)

	# Return to combat stance once the thrust attack animation completes
	if elapsed >= attack_duration or clayling.force_animation == "":
		clayling.force_animation = ""
		var next_target = target_enemy if (target_enemy and is_instance_valid(target_enemy) and not target_enemy.get("is_dead")) else null
		if is_player_order and next_target == null:
			clayling.guard_position = clayling.global_position
		clayling.change_state("SoldierStance", { "target_enemy": next_target, "target_facing": target_facing })

func exit() -> void:
	clayling.force_animation = ""

func _face_target(pos: Vector2) -> void:
	var diff = pos - clayling.global_position
	if abs(diff.x) * 1.5 >= abs(diff.y):
		clayling.last_direction = "side"
		clayling.set_flip_h(diff.x < 0)
	else:
		clayling.last_direction = "up" if diff.y < 0 else "down"

