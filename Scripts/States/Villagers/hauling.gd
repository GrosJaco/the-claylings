extends State

var storage: Node2D = null
var scan_cooldown := 0.0
const SCAN_INTERVAL := 0.25
const SCAN_RADIUS := 64.0

func enter(msg := {}) -> void:
	storage = msg.get("storage", null)
	
	# If no storage or storage is full, drop inventory and idle
	if storage == null or !is_instance_valid(storage) or (storage.has_method("is_full") and storage.is_full()):
		if !clayling.is_inventory_empty():
			clayling.drop_item(-1, true)
		clayling.change_state("Idle")
		return
	
	clayling.move_to(_get_storage_destination())

func exit() -> void:
	clayling.force_animation = ""

func _get_storage_destination() -> Vector2:
	if storage and is_instance_valid(storage):
		var dest = storage.global_position
		if "interaction_point" in storage and storage.interaction_point:
			dest += storage.interaction_point.position
		return dest
	return clayling.global_position

func update(delta: float) -> void:
	if clayling.is_inventory_empty():
		clayling.change_state("Idle")
		return
	
	var dir = clayling.get_direction()
	clayling.play_forced_animation("hauling_" + dir)
	
	if storage == null or !is_instance_valid(storage) or (storage.has_method("is_full") and storage.is_full()):
		storage = clayling.world.find_nearest_storage_with_space(clayling.global_position)
		if storage == null:
			# No storage – drop everything and idle
			if !clayling.is_inventory_empty():
				clayling.drop_item(-1, true)
			clayling.change_state("Idle")
			return
		clayling.move_to(_get_storage_destination())
	
	scan_cooldown -= delta
	if scan_cooldown <= 0.0:
		scan_cooldown = SCAN_INTERVAL
		if storage and is_instance_valid(storage):
			_scan_and_pick_same_items()

	if clayling.global_position.distance_to(_get_storage_destination()) < 12.0:
		_deliver_to_storage()
		clayling.change_state("Idle")

func _scan_and_pick_same_items() -> void:
	if storage == null or !is_instance_valid(storage) or (storage.has_method("is_full") and storage.is_full()):
		clayling.change_state("Idle")
		return
	
	var carried: ItemData = clayling.carried_type()
	if carried == null:
		return
	
	var need = clayling._carry_capacity()
	if need <= 0:
		return

	var best: Node = null
	var best_d := INF
	for it in clayling.get_tree().get_nodes_in_group("ground_items"):
		if it == null or !is_instance_valid(it):
			continue
		if it.data != carried:
			continue
		if clayling.world.reserved_pickups.has(it):
			continue
		var d = clayling.global_position.distance_to(it.global_position)
		if d <= SCAN_RADIUS and d < best_d:
			best = it
			best_d = d
	
	if best == null:
		return
	
	if !clayling.world.reserve_pickup(best, clayling):
		return

	need = clayling._carry_capacity()
	if need <= 0 or !is_instance_valid(best):
		clayling.world.release_pickup(best)
		return
	
	var take = min(need, best.quantity)
	var taken = clayling.pick_item(best.data, take)
	if taken > 0:
		best.quantity -= taken
		if best.quantity <= 0:
			if is_instance_valid(best):
				best.queue_free()
			clayling.world.release_pickup(best)
		else:
			if is_instance_valid(best):
				best._refresh()
			clayling.world.release_pickup(best)
	else:
		clayling.world.release_pickup(best)

func _deliver_to_storage() -> void:
	if storage and is_instance_valid(storage) and storage.has_method("store_item"):
		var dropped = clayling.drop_item(-1, false)
		if dropped.size() > 0:
			storage.store_item(dropped)
