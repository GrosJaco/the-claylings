extends AnimalState

var timer := 0.0

func enter(msg := {}):
	# If following leader and already too far, transition immediately to Wander
	if animal.get("follows_leader") and is_instance_valid(animal.get("leader_animal")) and not animal.leader_animal.is_dead:
		if animal.global_position.distance_to(animal.leader_animal.global_position) > animal.follow_distance_max:
			animal.change_state("Wander")
			return

	timer = randf_range(animal.idle_time_min, animal.idle_time_max)
	# Pick an animation (idle/eat if available)
	if randf() >= 0.75 and animal.sprite.sprite_frames and animal.sprite.sprite_frames.has_animation("eat"):
		animal.sprite.play("eat")
	else:
		animal.sprite.play("idle")

	# Stop moving
	animal.velocity = Vector2.ZERO

func update(delta: float):
	# If a threat is present, immediately flee
	if animal.threat:
		animal.change_state("Flee", {"threat": animal.threat})
		return

	# If following leader and leader moves away during idle, break idle to catch up
	if animal.get("follows_leader") and is_instance_valid(animal.get("leader_animal")) and not animal.leader_animal.is_dead:
		if animal.global_position.distance_to(animal.leader_animal.global_position) > animal.follow_distance_max:
			animal.change_state("Wander")
			return

	# Countdown timer
	timer -= delta
	if timer <= 0:
		animal.change_state("Wander")

func exit():
	# Reset velocity when leaving state
	animal.velocity = Vector2.ZERO
