extends State

var target_node: Node = null

func enter(msg := {}) -> void:
	target_node = msg.get("node", null)
	if target_node == null or !is_instance_valid(target_node):
		clayling.change_state("Idle")
		return
	if clayling.world.reserved_pickups.has(target_node) and clayling.world.reserved_pickups[target_node] != clayling:
		clayling.change_state("Idle")
		return
	clayling.move_to(target_node.global_position)

func update(_delta: float) -> void:
	if target_node == null or !is_instance_valid(target_node):
		_release_and_idle()
		return
	
	clayling.agent.target_position = target_node.global_position
	
	# Check if close enough to pick up
	if clayling.global_position.distance_to(target_node.global_position) < 10.0:
		await clayling.get_tree().create_timer(0.0).timeout
		if target_node == null or !is_instance_valid(target_node):
			_release_and_idle()
			return
		# Only pick up if inventory is empty
		if clayling.is_inventory_empty():
			var it_data = target_node.data
			var taken = clayling.pick_item(it_data, target_node.quantity)
			target_node.quantity -= taken
			if target_node.quantity <= 0 and is_instance_valid(target_node):
				target_node.queue_free()
			var dest_storage = clayling.world.find_nearest_storage_with_space(clayling.global_position, it_data)
			clayling.change_state("Haul", {"storage": dest_storage})
		else:
			_release_and_idle()

func exit() -> void:
	_release_reservation()
	target_node = null

func _release_reservation() -> void:
	if target_node and is_instance_valid(target_node):
		if clayling.world.reserved_pickups.has(target_node):
			clayling.world.reserved_pickups.erase(target_node)

func _release_and_idle() -> void:
	_release_reservation()
	clayling.change_state("Idle")
