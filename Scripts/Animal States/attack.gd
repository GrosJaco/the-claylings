extends AnimalState

# Target and state tracking
var target: Node2D = null
var chase_timer: float = 0.0
var cooldown_timer: float = 0.0
var repath_timer: float = 0.0
var _original_speed: float = 40.0
var _is_attacking: bool = false

func enter(msg := {}) -> void:
	target = msg.get("target", null)
	chase_timer = animal.attack_chase_timeout
	cooldown_timer = 0.0
	repath_timer = 0.0
	_is_attacking = false
	
	# Boost movement speed during combat
	_original_speed = animal.speed
	if animal.attack_speed_boost > 0.0:
		animal.speed = animal.attack_speed_boost

	# Connect animation callback
	if animal.sprite and not animal.sprite.animation_finished.is_connected(_on_animation_finished):
		animal.sprite.animation_finished.connect(_on_animation_finished)

	if not _is_target_valid():
		animal.change_state("Idle")
		return

	animal.sprite.play("run")
	animal.move_to(target.global_position)

func update(delta: float) -> void:
	if not _is_target_valid():
		animal.change_state("Idle")
		return

	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	var dist = animal.global_position.distance_to(target.global_position)

	# Face the target
	if target.global_position.x != animal.global_position.x:
		animal.sprite.flip_h = target.global_position.x < animal.global_position.x

	# Within attack range
	if dist <= animal.attack_range:
		animal.velocity = Vector2.ZERO
		animal.agent.target_position = animal.global_position

		if cooldown_timer <= 0.0 and not _is_attacking:
			_execute_attack()
	else:
		# Pursuing target: countdown pursuit timer without landed hits
		chase_timer -= delta
		if chase_timer <= 0.0:
			animal.change_state("Idle")
			return

		if not _is_attacking:
			if animal.sprite.animation != "run":
				animal.sprite.play("run")

			repath_timer -= delta
			if repath_timer <= 0.0:
				repath_timer = 0.2
				animal.move_to(target.global_position)

func exit() -> void:
	# Restore normal stats and animations
	animal.speed = _original_speed
	animal.velocity = Vector2.ZERO
	_is_attacking = false
	target = null

	if animal.sprite and animal.sprite.animation_finished.is_connected(_on_animation_finished):
		animal.sprite.animation_finished.disconnect(_on_animation_finished)

func set_target(new_target: Node2D) -> void:
	if is_instance_valid(new_target) and not new_target.get("is_dead"):
		target = new_target
		chase_timer = animal.attack_chase_timeout

func _is_target_valid() -> bool:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return false
	if target.get("is_dead"):
		return false
	return true

func _execute_attack() -> void:
	_is_attacking = true
	cooldown_timer = animal.attack_cooldown
	chase_timer = animal.attack_chase_timeout

	if animal.sprite.sprite_frames and animal.sprite.sprite_frames.has_animation("attack"):
		animal.sprite.play("attack")

	# Apply damage and knockback to target
	if target.has_method("take_damage"):
		target.take_damage(animal.attack_damage, animal)

func _on_animation_finished() -> void:
	if not is_instance_valid(animal) or not animal.sprite:
		return

	if animal.sprite.animation == "attack" or animal.sprite.animation == "hit":
		_is_attacking = false
		if _is_target_valid():
			var dist = animal.global_position.distance_to(target.global_position)
			if dist <= animal.attack_range:
				if animal.sprite.sprite_frames.has_animation("idle"):
					animal.sprite.play("idle")
			else:
				if animal.sprite.sprite_frames.has_animation("run"):
					animal.sprite.play("run")
