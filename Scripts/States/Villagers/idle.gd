extends State

# How long the clayling stays idle before doing something else
@export var idle_time = 5
var timer = 0.0

func enter(msg := {}) -> void:
	clayling.stop_moving()
	
	# If carrying items but no storage is available, drop everything
	if !clayling.is_inventory_empty():
		var nearest_storage = clayling.world.find_nearest_storage_with_space(clayling.global_position)
		if nearest_storage:
			clayling.change_state("Haul", {"storage": nearest_storage})
			return
		else:
			# No storage, then drop items and stay idle
			clayling.drop_item(-1, true)
			return

	timer = randi_range(idle_time - 1, idle_time + 1)

func update(delta: float) -> void:
	timer -= delta
	if timer <= 0.0:
		clayling.change_state("Wander")

