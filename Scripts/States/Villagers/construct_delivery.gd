extends State

# ========== VARIABLES ==========

var target_item: Node = null
var target_blueprint: Node = null
var item_to_fetch: ItemData = null
var amount_needed: int = 0

enum Phase { GOING_TO_ITEM, GOING_TO_BLUEPRINT }
var current_phase = Phase.GOING_TO_ITEM

var delivery_successful: bool = false

const SCAN_RADIUS = 150.0
var scan_cooldown: float = 0.0
const SCAN_INTERVAL = 0.5

# ========== FUNCTIONS ==========

func enter(msg := {}) -> void:
	target_item = msg.get("ground_item", null)
	target_blueprint = msg.get("building", null)
	item_to_fetch = msg.get("item", null)
	amount_needed = msg.get("amount", 0)

	current_phase = Phase.GOING_TO_ITEM
	delivery_successful = false

	if target_item == null or !is_instance_valid(target_item):
		clayling.change_state("Idle")
		return
	if target_blueprint == null or !is_instance_valid(target_blueprint):
		clayling.change_state("Idle")
		return

	# Reserve the ground item
	if clayling.world and clayling.world.has_method("reserve_pickup"):
		if not clayling.world.reserve_pickup(target_item, clayling):
			clayling.change_state("Idle")
			return

	clayling.move_to(target_item.global_position)

func exit() -> void:
	clayling.force_animation = ""

	# Release reservation if still held
	if target_item and is_instance_valid(target_item):
		if clayling.world.reserved_pickups.has(target_item):
			clayling.world.reserved_pickups.erase(target_item)

	# Cancel delivery reservation on blueprint if we didn't deliver
	if not delivery_successful:
		if target_blueprint and is_instance_valid(target_blueprint) and target_blueprint.has_method("cancel_delivery"):
			if item_to_fetch != null and amount_needed > 0:
				target_blueprint.cancel_delivery(item_to_fetch, amount_needed)

	# Drop carried items if we were in delivery phase and didn't deliver
	if current_phase == Phase.GOING_TO_BLUEPRINT and !clayling.is_inventory_empty() and not delivery_successful:
		clayling.drop_item(-1, true)

func update(delta: float) -> void:
	# In delivery phase, target_item is expected to be gone (picked up and queue_freed)
	if current_phase == Phase.GOING_TO_ITEM:
		if target_item == null or !is_instance_valid(target_item):
			clayling.change_state("Idle")
			return

	if target_blueprint == null or !is_instance_valid(target_blueprint):
		clayling.change_state("Idle")
		return

	scan_cooldown -= delta

	var dir = clayling.get_direction()

	if current_phase == Phase.GOING_TO_ITEM:
		clayling.play_forced_animation("")

		if clayling.global_position.distance_to(target_item.global_position) < 16.0 or clayling.agent.is_navigation_finished():
			_pick_up_item()

	elif current_phase == Phase.GOING_TO_BLUEPRINT:
		clayling.play_forced_animation("hauling_" + dir)

		# Scan for more items of the same type while en route (like Haul state)
		if scan_cooldown <= 0.0:
			scan_cooldown = SCAN_INTERVAL
			_scan_and_pick_same_items()

		var dest = target_blueprint.global_position
		if "interaction_point" in target_blueprint and target_blueprint.interaction_point:
			dest += target_blueprint.interaction_point.position

		if clayling.global_position.distance_to(dest) < 16.0 or clayling.agent.is_navigation_finished():
			_deliver_to_blueprint()
			return

func _pick_up_item() -> void:
	if target_item == null or !is_instance_valid(target_item):
		clayling.change_state("Idle")
		return

	# Check if item matches what we need
	var matches_item = (target_item.data == item_to_fetch) or (target_item.data != null and item_to_fetch != null and (target_item.data.resource_path == item_to_fetch.resource_path or target_item.data.name == item_to_fetch.name))
	if not matches_item:
		clayling.world.release_pickup(target_item)
		clayling.change_state("Idle")
		return

	# Pick up as much as we can carry (like Haul state does)
	var capacity = clayling._carry_capacity_for(item_to_fetch)
	var take = min(capacity, target_item.quantity)
	var taken = clayling.pick_item(target_item.data, take)

	if taken > 0:
		target_item.quantity -= taken
		if target_item.quantity <= 0 and is_instance_valid(target_item):
			target_item.queue_free()
		clayling.world.release_pickup(target_item)

		# Switch to delivery phase
		current_phase = Phase.GOING_TO_BLUEPRINT
		var dest = target_blueprint.global_position
		if "interaction_point" in target_blueprint and target_blueprint.interaction_point:
			dest += target_blueprint.interaction_point.position
		clayling.move_to(dest)
	else:
		clayling.world.release_pickup(target_item)
		clayling.change_state("Idle")

func _deliver_to_blueprint() -> void:
	if target_blueprint == null or !is_instance_valid(target_blueprint):
		clayling.change_state("Idle")
		return

	var dropped_item = clayling.drop_item(-1, false)

	if typeof(dropped_item) == TYPE_DICTIONARY and dropped_item.has("item"):
		if target_blueprint.has_method("receive_item"):
			var data = dropped_item["item"]
			var qty = dropped_item.get("count", dropped_item.get("amount", 0))

			if qty > 0:
				target_blueprint.receive_item(data, qty)
				delivery_successful = true

	clayling.change_state("Idle")

func _scan_and_pick_same_items() -> void:
	if clayling.is_inventory_full():
		return

	var carried_type = clayling.carried_type()
	if carried_type != item_to_fetch:
		return

	var capacity = clayling._carry_capacity()
	if capacity <= 0:
		return

	var best: Node = null
	var best_d := INF
	for it in clayling.get_tree().get_nodes_in_group("ground_items"):
		if it == null or !is_instance_valid(it):
			continue
		if it.data != carried_type:
			continue
		if clayling.world.reserved_pickups.has(it):
			continue
		var d = clayling.global_position.distance_to(it.global_position)
		if d <= SCAN_RADIUS and d < best_d:
			best = it
			best_d = d

	if best == null:
		return

	if not clayling.world.reserve_pickup(best, clayling):
		return

	capacity = clayling._carry_capacity()
	if capacity <= 0 or !is_instance_valid(best):
		clayling.world.release_pickup(best)
		return

	var take = min(capacity, best.quantity)
	var taken = clayling.pick_item(best.data, take)
	if taken > 0:
		best.quantity -= taken
		if best.quantity <= 0 and is_instance_valid(best):
			best.queue_free()
		clayling.world.release_pickup(best)
