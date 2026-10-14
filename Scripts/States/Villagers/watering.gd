extends State

var target_pos: Vector2i
var _is_action_active: bool = false

func enter(msg := {}) -> void:
	_is_action_active = false
	clayling.animation_over = false
	if msg.has("pos") and msg["pos"] is Vector2i:
		target_pos = msg["pos"]
		var objective_pos = clayling.world.get_world_position(target_pos) + Vector2(8, 8)
		clayling.move_to(objective_pos)
	else:
		clayling.change_state("Idle")

func update(_delta: float) -> void:
	if _is_action_active:
		if clayling.animation_over:
			clayling_animation_finished()
		return

	# If the tile was already hydrated while traveling, cancel task
	if clayling.world.water_level.get(target_pos, 0.0) >= 5.0:
		clayling.change_state("Idle")
		return

	var target_world_pos = clayling.world.get_world_position(target_pos) + Vector2(8, 8)
	if clayling.global_position.distance_to(target_world_pos) <= 16.0:
		_is_action_active = true
		clayling.animation_over = false
		if target_world_pos.x < clayling.global_position.x:
			clayling.set_flip_h(true)
		else:
			clayling.set_flip_h(false)
		SoundManager.play_at("watering", clayling.global_position, 0.1)
		clayling.offset_sprite(8, 0)
		clayling.play_forced_animation("watering_side")
		clayling.velocity = Vector2.ZERO

func clayling_animation_finished() -> void:
	_is_action_active = false
	clayling.animation_over = false
	clayling.watering_tile(target_pos)
	clayling.change_state("Idle")

func exit() -> void:
	_is_action_active = false
	clayling.animation_over = false
	clayling.play_forced_animation("")
	clayling.offset_sprite(0, 0)
