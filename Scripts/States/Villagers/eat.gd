extends State

var target_storage: Node2D = null
var food_item: ItemData = null

enum Phase { GOING_TO_FOOD, EATING }
var current_phase = Phase.GOING_TO_FOOD

var eating_timer: float = 0.0
var eating_duration: float = 2.0 

func enter(msg := {}) -> void:
	target_storage = msg.get("storage", null)
	food_item = msg.get("food", null)
	current_phase = Phase.GOING_TO_FOOD
	eating_timer = eating_duration

	if not clayling.is_inventory_empty():
		clayling.drop_item(-1, true) 
	if not is_instance_valid(target_storage) or food_item == null:
		clayling.change_state("Idle")
		return
	var dest = target_storage.global_position
	if "interaction_point" in target_storage and target_storage.interaction_point:
		dest += target_storage.interaction_point.position
	clayling.move_to(dest)


func exit() -> void:
	clayling.force_animation = ""
	if not clayling.is_inventory_empty():
		clayling.drop_item(-1, true)


func update(delta: float) -> void:
	if not is_instance_valid(target_storage):
		clayling.change_state("Idle")
		return

	if current_phase == Phase.GOING_TO_FOOD:
		clayling.play_forced_animation("")
		var dest = target_storage.global_position
		if "interaction_point" in target_storage and target_storage.interaction_point:
			dest += target_storage.interaction_point.position
			
		if clayling.global_position.distance_to(dest) < 12.0:
			_start_eating()

	elif current_phase == Phase.EATING:
		var dir = clayling.get_direction()
		clayling.play_forced_animation("eating_" + "down")
		
		eating_timer -= delta
		if eating_timer <= 0.0:
			_finish_eating()


func _start_eating() -> void:
	clayling.stop_moving()

	if target_storage.has_method("withdraw"):
		var amount_taken = target_storage.withdraw(food_item, 1)
		if amount_taken > 0:
			clayling.pick_item(food_item, 1)
			current_phase = Phase.EATING
		else:
			clayling.change_state("Idle")
	else:
		clayling.change_state("Idle")


func _finish_eating() -> void:
	var eaten_item = clayling.drop_item(-1, false)
	if typeof(eaten_item) == TYPE_DICTIONARY and eaten_item.has("item"):
		var nutrition_value = food_item.get("nutrition") if "nutrition" in food_item else 50.0
		clayling.hunger = min(clayling.hunger + nutrition_value, clayling.max_hunger)
		if clayling.personality_trait == "Gourmand":
			clayling.health = min(clayling.health + 25.0, clayling.max_health)
	clayling.change_state("Idle")
