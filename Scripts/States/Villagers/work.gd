extends State

var target_building: Node2D = null
var is_working: bool = false
var _hit_timer: float = 0.0


func enter(msg := {}) -> void:
	target_building = msg.get("building", null)
	is_working = false
	_hit_timer = 0.0

	if target_building == null or !is_instance_valid(target_building):
		clayling.change_state("Idle")
		return

	var dest = _get_interaction_point()
	clayling.move_to(dest)


func exit() -> void:
	clayling.force_animation = ""
	clayling.offset_sprite(0, 0)
	if target_building and is_instance_valid(target_building):
		if target_building.get("worker_present") == true and is_working:
			target_building.worker_present = false
	is_working = false


func update(delta: float) -> void:
	if !is_instance_valid(target_building):
		clayling.change_state("Idle")
		return

	if not is_working:
		clayling.play_forced_animation("")
		var dest = _get_interaction_point()

		if clayling.global_position.distance_to(dest) < 12.0 or clayling.agent.is_navigation_finished():
			is_working = true
			target_building.worker_present = true
			clayling.stop_moving()
	else:
		var anim = target_building.get("worker_animation")
		clayling.play_forced_animation(anim if anim else "interacting_up")

		clayling.sprite.flip_h = target_building.get("worker_flip_h")

		var offset = target_building.get("worker_sprite_offset")
		if offset:
			clayling.offset_sprite(offset.x, offset.y)

		_hit_timer += delta
		var interval = target_building.get("worker_hit_interval")
		var sound_name = target_building.get("worker_hit_sound")
		if interval > 0.0 and sound_name != "" and _hit_timer >= interval:
			_hit_timer = 0.0
			SoundManager.play_at(sound_name, clayling.global_position, 0.1)

		if clayling.personality_trait == "Smart" and target_building.get("is_crafting") and "craft_timer" in target_building:
			target_building.craft_timer -= delta * 0.35

		var should_stop = false
		if not target_building.get("is_crafting"):
			should_stop = true
		elif target_building.get("active_recipe") == null:
			should_stop = true
		elif not target_building.active_recipe.get("need_clayling"):
			should_stop = true

		if should_stop:
			clayling.change_state("Idle")


func _get_interaction_point() -> Vector2:
	if target_building.has_node("InteractionPoint"):
		return target_building.get_node("InteractionPoint").global_position
	return target_building.global_position
