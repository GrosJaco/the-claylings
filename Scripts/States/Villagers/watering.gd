extends State

var target_pos : Vector2i

func enter(msg := {}) -> void:
	if msg.has("pos") and msg["pos"] is Vector2i:
		target_pos = msg["pos"]
		var objective_pos = clayling.world.get_world_position(target_pos) + Vector2(8, 8)
		clayling.move_to(objective_pos)
	else:
		clayling.change_state("Idle")

func update(delta: float) -> void:
	if clayling.animation_over:
		clayling_animation_finished()
		return
	if clayling.global_position.distance_to(clayling.agent.target_position) < 8.0:
		if clayling.force_animation != "watering_side":
			SoundManager.play_at("watering", clayling.global_position, 0.1)
		clayling.offset_sprite(8, 0)
		clayling.play_forced_animation("watering_side")
		clayling.velocity = Vector2.ZERO

func clayling_animation_finished():
	clayling.animation_over = false
	clayling.watering_tile(target_pos)
	clayling.change_state("Idle")
