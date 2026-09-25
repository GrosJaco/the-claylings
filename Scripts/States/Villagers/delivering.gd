extends State

var target_building: Node2D = null
var target_storage: Node2D = null
var item_to_fetch: ItemData = null
var amount_to_fetch: int = 0

var delivery_successful: bool = false

enum Phase { GOING_TO_STORAGE, GOING_TO_BUILDING }
var current_phase = Phase.GOING_TO_STORAGE

func enter(msg := {}) -> void:
	target_building = msg.get("building", null)
	target_storage = msg.get("storage", null)
	item_to_fetch = msg.get("item", null)
	amount_to_fetch = msg.get("amount", 0)
	
	delivery_successful = false
	current_phase = Phase.GOING_TO_STORAGE
	
	if target_storage == null or !is_instance_valid(target_storage) or target_building == null or !is_instance_valid(target_building):
		clayling.change_state("Idle")
		return
		
	var dest = target_storage.global_position
	if "interaction_point" in target_storage and target_storage.interaction_point:
		dest += target_storage.interaction_point.position
	clayling.move_to(dest)

func exit() -> void:
	clayling.force_animation = ""
	
	if not delivery_successful and target_building and is_instance_valid(target_building) and target_building.has_method("cancel_delivery"):
		if item_to_fetch != null and amount_to_fetch > 0:
			target_building.cancel_delivery(item_to_fetch, amount_to_fetch)
			
	if current_phase == Phase.GOING_TO_BUILDING and !clayling.is_inventory_empty():
		clayling.drop_item(-1, true)

func update(_delta: float) -> void:
	if !is_instance_valid(target_storage) or !is_instance_valid(target_building):
		if !clayling.is_inventory_empty():
			clayling.drop_item(-1, true)
		clayling.change_state("Idle")
		return

	var dir = clayling.get_direction()
	if current_phase == Phase.GOING_TO_BUILDING:
		clayling.play_forced_animation("hauling_" + dir)
	else:
		clayling.play_forced_animation("")

	if current_phase == Phase.GOING_TO_STORAGE:
		var dest = target_storage.global_position
		if "interaction_point" in target_storage and target_storage.interaction_point:
			dest += target_storage.interaction_point.position
			
		if clayling.global_position.distance_to(dest) < 16.0 or clayling.agent.is_navigation_finished():
			_take_from_storage()

	elif current_phase == Phase.GOING_TO_BUILDING:
		var dest = target_building.global_position
		if "interaction_point" in target_building and target_building.interaction_point:
			dest += target_building.interaction_point.position
			
		if clayling.global_position.distance_to(dest) < 16.0 or clayling.agent.is_navigation_finished():
			_deliver_to_building()

func _take_from_storage() -> void:
	if target_storage.has_method("withdraw"):
		var amount_taken = target_storage.withdraw(item_to_fetch, amount_to_fetch)
		
		var shortfall = amount_to_fetch - amount_taken
		if shortfall > 0 and target_building and target_building.has_method("cancel_delivery"):
			target_building.cancel_delivery(item_to_fetch, shortfall)
			
		amount_to_fetch = amount_taken 
		
		if amount_taken > 0:
			clayling.pick_item(item_to_fetch, amount_taken)
			
			current_phase = Phase.GOING_TO_BUILDING
			var dest = target_building.global_position
			if "interaction_point" in target_building and target_building.interaction_point:
				dest += target_building.interaction_point.position
			clayling.move_to(dest)
			return
			
	clayling.change_state("Idle")

func _deliver_to_building() -> void:
	var dropped_item = clayling.drop_item(-1, false)
	
	if typeof(dropped_item) == TYPE_DICTIONARY and dropped_item.has("item"):
		if target_building.has_method("receive_item"):
			var data = dropped_item["item"]
			var qty = dropped_item.get("count", dropped_item.get("amount", 0))
			
			if qty > 0:
				delivery_successful = true
				target_building.receive_item(data, qty)
			
	clayling.change_state("Idle")
