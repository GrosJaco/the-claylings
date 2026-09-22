extends CharacterBody2D

# ========== REFERENCES ==========

@onready var world: Node2D = $".."
@onready var sprite: AnimatedSprite2D = $Pivot/AnimatedSprite2D
@onready var carry_sprite: Sprite2D = $Pivot/CarrySprite
@onready var pivot: Node2D = $Pivot
@onready var collision_shape_2D: CollisionShape2D = $CollisionShape2D
@onready var agent: NavigationAgent2D = $NavigationAgent2D

# ========== VARIABLES ==========

# ---------- IDENTITY & TRAITS ----------
var clayling_name: String = ""
var age: int = 5
var personality_trait: String = "Normal"

# ---------- VITALS & NEEDS ----------

var max_health: float = 100.0
var health: float = 100.0

var max_hunger: float = 100.0
var hunger: float = 100.0
var hunger_decay_rate: float = 1

var max_energy: float = 100.0
var energy: float = 100.0
var energy_decay_rate: float = 0.3

var happiness: float = 100.0

# ---------- STATS ----------

var speed : float = 50.0
var speed_multiplier: float = 1.0
var weather_speed_multiplier: float = 1.0
var _slow_timer: float = 0.0
var role : String = "villager" # ex: "villager", "spearman", "archer"
var is_combat_ready : bool = false
var is_dead : bool = false
var formation_facing: Vector2 = Vector2.ZERO
var guard_position: Vector2 = Vector2.ZERO
var last_attacker: Node2D = null
var is_under_attack: bool = false
var _under_attack_timer: float = 0.0
var _threat_scan_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO

# ---------- STATE MACHINE ----------

var states : Dictionary = {}
var current_state : State

# ---------- ANIMATIONS ----------

var last_direction : String = "down"
var animation_over : bool = false
var force_animation : String = ""

# ---------- PATHFINDING ----------

@export var goal : Vector2
var _stuck_timer: float = 0.0

# ---------- INVENTORY ----------

var inventory: Dictionary = {
	"item": null,   # item name
	"count": 0,     
	"max_stack": 16
}

var equipment : Array = [] 
var equipped_kit: KitData = null

# ========== FUNCTIONS ==========

# ---------- STATE MACHINE ----------

func change_state(name: String, msg := {}) -> void:
	if current_state:
		current_state.exit()
	
	if states.has(name):
		current_state = states[name]
		current_state.enter(msg)
	else:
		push_error("State " + name + " does not exist.")

func assign_task(state_name: String, msg := {}) -> void:
	change_state(state_name, msg)

func watering_tile(pos: Vector2i) -> void:
	var data = world.ground.get_cell_tile_data(pos)
	if data:
		var tile_name = data.get_custom_data("tile_name")
		world.watering_tile(tile_name, pos, 50)

func harvesting(pos: Vector2i) -> void:
	world.harvesting(pos)

func planting(pos: Vector2i) -> void:
	world.planting(pos)

# ---------- ANIMATION ----------

var current_sprite_offset: Vector2 = Vector2.ZERO

func handle_animation() -> void:
	if is_dead or force_animation != "":
		return

	if current_state == states.get("SoldierStance") or current_state == states.get("SoldierToStance") or current_state == states.get("SoldierAttack"):
		return       

	if velocity.length() > 5.0:
		var dir = get_direction()
		last_direction = dir
		var anim = "spearman_running_" + dir if role == "spearman" else "running_" + dir

		_update_sprite_offset_for_animation(anim)
		if sprite.animation != anim or not sprite.is_playing():
			sprite.play(anim)
	else:
		var anim = "spearman_idle_" + last_direction if role == "spearman" else "idle_" + last_direction

		_update_sprite_offset_for_animation(anim)
		if sprite.animation != anim or not sprite.is_playing():
			sprite.play(anim)

func _update_sprite_offset_for_animation(anim_name: String) -> void:
	if anim_name.begins_with("spearman_running"):
		offset_sprite(0, -16)                                                                                       
	elif anim_name.begins_with("spearman_idle"):
		offset_sprite(0, -8)       
	elif anim_name.begins_with("spearman_to_combat_stance") or anim_name.begins_with("spearman_combat_stance"):
		offset_sprite(8, 8)            
	elif anim_name.begins_with("spearman_attacking") or anim_name.begins_with("spearman_dying"):
		offset_sprite(24, 8)              
	elif anim_name.begins_with("spearman_running"):
		offset_sprite(0, -16)
	elif anim_name.begins_with("spearman_idle"):
		offset_sprite(0, -8)
	elif anim_name in ["woodcutting_side", "mining_side", "harvesting_side", "watering_side"]:
		offset_sprite(8, 0)
	elif anim_name == "interacting_up":
		offset_sprite(0, -8)
	else:
		offset_sprite(0, 0)           

func set_flip_h(flipped: bool) -> void:
	sprite.flip_h = flipped
	_apply_pivot_offset()

# Decide what animation to use between up, side or down
func get_direction() -> String:
	if velocity.length() < 5.0:
		return last_direction
		
	if abs(velocity.x) > abs(velocity.y):
		if velocity.x < -0.1:
			set_flip_h(true)
		elif velocity.x > 0.1:
			set_flip_h(false)
		return "side"
	else:
		if velocity.y < 0:
			return "up"
		else:
			return "down"

# Offset the animator for animations larger/smaller than 16x16
func offset_sprite(x: float, y: float) -> void:
	current_sprite_offset = Vector2(x, y)
	_apply_pivot_offset()

func _apply_pivot_offset() -> void:
	if sprite.flip_h:
		pivot.position = Vector2(-current_sprite_offset.x, -7 + current_sprite_offset.y)
		sprite.position.x = -0.5
	else:
		pivot.position = Vector2(current_sprite_offset.x, -7 + current_sprite_offset.y)
		sprite.position.x = 0.5

func play_forced_animation(anim_name: String) -> void:
	force_animation = anim_name
	if anim_name != "":
		_update_sprite_offset_for_animation(anim_name)
		sprite.play(anim_name)

func _on_animated_sprite_2d_animation_finished() -> void:
	if is_dead:
		_start_corpse_decay()
		return
	if force_animation != "":
		force_animation = ""
		animation_over = true

func _on_animated_sprite_2d_animation_looped() -> void:
	pass

# ---------- PATHFINDING ---------

func move_to(target_position: Vector2):
	agent.target_position = target_position

func stop_moving() -> void:
	agent.target_position = global_position 
	velocity = Vector2.ZERO

# ---------- INVENTORY ----------

func carried_type() -> ItemData:
	return inventory["item"]

func is_inventory_empty() -> bool:
	return inventory["item"] == null or inventory["count"] <= 0

func is_inventory_full() -> bool:
	if inventory["item"] == null:
		return false
	var i: ItemData = inventory["item"]
	return inventory["count"] >= min(inventory["max_stack"], i.stack_size)

func _carry_capacity_for(item: ItemData) -> int:
	if item == null:
		return 0
	if inventory["item"] == null:
		return min(inventory["max_stack"], item.stack_size)
	if inventory["item"] != item:
		return 0
	return min(inventory["max_stack"], item.stack_size) - inventory["count"]

func _carry_capacity() -> int:
	if inventory["item"] == null:
		return inventory["max_stack"]
	return _carry_capacity_for(inventory["item"])

func pick_item(item: ItemData, amount: int) -> int:
	if item == null or amount <= 0:
		return 0
	var room := _carry_capacity_for(item)
	if room <= 0:
		return 0
	var taken = min(amount, room)
	if inventory["item"] == null:
		inventory["item"] = item
		inventory["count"] = taken
	else:
		inventory["count"] += taken
	
	_refresh_carry_sprite()
	return taken

func drop_item(amount: int = -1, to_ground: bool = false) -> Dictionary:
	if inventory["item"] == null or inventory["count"] <= 0:
		return {}
	
	var out = {}
	if amount == -1 or amount >= inventory["count"]:
		out = {"item": inventory["item"], "count": inventory["count"]}
		inventory["item"] = null
		inventory["count"] = 0
	else:
		inventory["count"] -= amount
		out = {"item": inventory["item"], "count": amount}
	
	_refresh_carry_sprite()
	
	if to_ground and out.size() > 0:
		var scene: PackedScene = preload("res://Scenes/item.tscn")
		var item_node = scene.instantiate()
		item_node.data = out["item"]
		item_node.quantity = out["count"]
		item_node.global_position = global_position
		world.add_child(item_node)
	
	return out

func _refresh_carry_sprite() -> void:
	if inventory["item"] and inventory["count"] > 0:
		carry_sprite.texture = inventory["item"].icon
		carry_sprite.visible = true
	else:
		carry_sprite.visible = false

# ---------- COMBAT & EQUIPMENT ----------

func try_equip_from_rack(rack_node) -> bool:
	if not is_instance_valid(rack_node):
		return false
		
	# Ask rack for a complete kit index
	var kit_index = rack_node.find_available_kit_index()
	
	if kit_index != -1:
		# Retrieve kit data
		var kit_data = rack_node.take_kit(kit_index)
		if kit_data.size() > 0:
			_apply_kit(kit_data)
			return true
			
	return false

func _apply_kit(kit_data: Dictionary) -> void:
	equipped_kit = kit_data.get("kit_resource", null)
	if equipped_kit:
		role = equipped_kit.kit_id
	else:
		role = kit_data.get("kit_type", "villager")

	equipment = kit_data.get("items", []).duplicate()
	is_combat_ready = true
	add_to_group("soldiers")

	# Refresh animations for the new role immediately
	force_animation = ""
	print("Clayling " + clayling_name + " is now equipped as: " + str(kit_data.get("display_name", role)))

	if role == "spearman":
		change_state("SoldierToStance")
	elif role == "archer" or role == "knight":
		change_state("SoldierIdle")
	else:
		change_state("Idle")

func debug_become_spearman() -> void:
	if is_dead:
		return
	if inventory.get("count", 0) > 0:
		drop_item(-1, true)
	var spearman_kit: KitData = load("res://Resources/Kit Resources/spearman.tres")
	_apply_kit({
		"kit_resource": spearman_kit,
		"kit_type": "spearman",
		"display_name": "Spearman",
		"items": spearman_kit.required_items if spearman_kit else []
	})

func unequip_at_rack(rack_node: Node2D = null) -> bool:
	if not is_combat_ready and role == "villager":
		return false

	if not rack_node or not is_instance_valid(rack_node) or not rack_node.has_method("deposit_kit"):
		return false

	var items_to_deposit = equipment.duplicate()
	var kit_to_deposit = equipped_kit

	var deposited = rack_node.deposit_kit(items_to_deposit, kit_to_deposit, self)
	if not deposited:
		return false

	equipment.clear()
	equipped_kit = null

	# Reset combat and soldier status
	is_combat_ready = false
	role = "villager"
	guard_position = Vector2.ZERO
	formation_facing = Vector2.ZERO
	remove_from_group("soldiers")
	set_selected(false)

	var rts = get_tree().get_first_node_in_group("rts_controller")
	if rts and "selected_soldiers" in rts:
		rts.selected_soldiers.erase(self)

	force_animation = ""
	offset_sprite(0, 0)
	change_state("Idle")
	return true

# ---------- RTS COMMANDS ----------

func command_move(target_pos: Vector2, target_facing: Vector2 = Vector2.ZERO) -> void:
	if not is_combat_ready:
		return
	guard_position = target_pos
	if target_facing != Vector2.ZERO:
		formation_facing = target_facing
	change_state("SoldierMove", { 
		"target_position": target_pos, 
		"target_facing": target_facing,
		"is_player_order": true
	})

func command_attack(enemy_node: Node2D) -> void:
	if not is_combat_ready:
		return
	guard_position = Vector2.ZERO # Clear previous guard post so the soldier chases without leash
	change_state("SoldierMove", { 
		"target_enemy": enemy_node,
		"is_player_order": true
	})

func find_nearest_enemy(max_dist: float = 150.0) -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_d_sq: float = max_dist * max_dist
	for e in enemies:
		if not is_instance_valid(e) or e.get("is_dead"):
			continue
		var d_sq = global_position.distance_squared_to(e.global_position)
		if d_sq <= nearest_d_sq:
			nearest = e
			nearest_d_sq = d_sq
	return nearest

func find_threat_to_assist(assist_range: float = 70.0) -> Node2D:
	var my_origin = guard_position if guard_position != Vector2.ZERO else global_position
	var assist_sq = assist_range * assist_range
	var max_origin_sq = (assist_range + 20.0) * (assist_range + 20.0)
	var allies = get_tree().get_nodes_in_group("claylings")
	for ally in allies:
		if not is_instance_valid(ally) or ally == self or ally.get("is_dead"):
			continue
		if global_position.distance_squared_to(ally.global_position) > assist_sq:
			continue
		if ally.get("is_under_attack") and ally.get("last_attacker"):
			var attacker = ally.get("last_attacker")
			if is_instance_valid(attacker) and not attacker.get("is_dead"):
				var d_from_origin_sq = my_origin.distance_squared_to(attacker.global_position)
				if d_from_origin_sq <= max_origin_sq:
					return attacker
	return null

# ---------- IDENTITY & NEEDS LOGIC ----------

func _generate_identity() -> void:
	var first_names = ["Natasha", "Maxime", "Clément", "Achille", "Mathis", "Gabriel", "Gamelle", "Godin", "Cyprien", 
					"Joe", "Mauer", 
					"Romain", "Mathieu", "Louis", 
					"Pedro", "Filipe", "Tiago", "Enzo", "Rodriguo", 
					"João", "Rafael", "Matthias", "Samuel", "Barth", "Bastien", "Alexandre", "Aurélien", "Fabian", "Joachim", "Hugo"]
	
	var used_names: Dictionary = {}
	if is_inside_tree():
		for c in get_tree().get_nodes_in_group("claylings"):
			if c != self and is_instance_valid(c) and "clayling_name" in c and c.clayling_name != "":
				used_names[c.clayling_name] = true

	var available_names: Array = []
	for n in first_names:
		if not used_names.has(n):
			available_names.append(n)

	if not available_names.is_empty():
		clayling_name = available_names.pick_random()
	else:
		clayling_name = first_names.pick_random()

	age = randi_range(18, 65)
	
	var traits = [
		"Resilient", "Swift", "Efficient", "Strong", "Smart",
		"Brave", "Dexterous", "Optimistic", "Hermit", "Tough",
		"Gourmand", "NightOwl", "Curious"
	]
	personality_trait = traits.pick_random()
	_apply_trait_base_stats()

func _apply_trait_base_stats() -> void:
	if personality_trait == "Resilient":
		max_energy = 15.0
		energy = 15.0
	elif personality_trait == "Swift":
		speed = 65.0
	elif personality_trait == "Strong":
		inventory["max_stack"] = 24
	elif personality_trait == "Brave":
		max_health = 120.0
		health = max_health
	elif personality_trait == "Tough":
		max_health = 115.0
		health = max_health

func _update_needs(delta: float) -> void:
	if is_dead:
		return

	var current_hunger_decay = hunger_decay_rate
	if personality_trait == "Efficient":
		current_hunger_decay *= 0.75
	elif personality_trait == "Gourmand":
		current_hunger_decay *= 1.2
		
	hunger -= current_hunger_decay * delta
	hunger = clamp(hunger, 0.0, max_hunger)
	
	if velocity.length() > 0 or force_animation != "":
		var current_energy_decay = energy_decay_rate
		if personality_trait == "Resilient":
			current_energy_decay *= 0.8
		elif personality_trait == "NightOwl":
			var day_night = get_tree().get_first_node_in_group("day_night_cycle")
			if day_night and day_night.has_method("is_night") and day_night.is_night():
				current_energy_decay = 0.0
		
		energy -= current_energy_decay * delta
		energy = clamp(energy, 0.0, max_energy)

	if personality_trait == "Optimistic" and (current_state == states.get("Idle") or current_state == states.get("Wandering")):
		health = min(max_health, health + 0.5 * delta)
		
	if hunger <= 0:
		take_damage(1.0 * delta)

func apply_knockback(source_pos: Vector2, force: float = 40.0) -> void:
	if is_dead or force <= 0.0:
		return
	var dir = (global_position - source_pos).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT.rotated(randf() * TAU)
	var effective_force = force
	if equipped_kit and equipped_kit is KitData:
		effective_force *= (1.0 - clampf(equipped_kit.knockback_resistance, 0.0, 1.0))
	if personality_trait == "Tough":
		effective_force *= 0.5
	if effective_force > 0.0:
		var impulse = dir * effective_force
		if impulse.length_squared() > knockback_velocity.length_squared():
			knockback_velocity = impulse

func take_damage(amount: float, source: Node2D = null) -> void:
	if is_dead:
		return
	if personality_trait == "Tough":
		amount *= 0.75
	health = max(0.0, health - amount)

	# Record attacker for personal defense
	if source and is_instance_valid(source):
		last_attacker = source
		var kb_force: float = 0.0
		if "attack_knockback" in source:
			kb_force = source.attack_knockback
		elif "knockback_force" in source:
			kb_force = source.knockback_force
		elif source.get("attack_type") == "melee":
			kb_force = 40.0
		if kb_force > 0.0:
			apply_knockback(source.global_position, kb_force)
	is_under_attack = true
	_under_attack_timer = 4.0

	# Sharp white hit flash
	var base_color = Color(0.8, 0.8, 1.0, 1.0) if _slow_timer > 0.0 else Color.WHITE
	modulate = Color(5.0, 5.0, 5.0, 1.0)
	var hit_tween = create_tween()
	hit_tween.tween_interval(0.07)
	hit_tween.tween_callback(func(): modulate = base_color)

	if health <= 0:
		die()
	elif role == "villager" and not is_combat_ready and current_state != states.get("Flee") and current_state != states.get("Equip") and current_state != states.get("Unequip"):
		change_state("Flee", {"threat": source if source else last_attacker})

func apply_slow(factor: float, duration: float) -> void:
	if is_dead:
		return
	speed_multiplier = min(speed_multiplier, factor)
	_slow_timer = max(_slow_timer, duration)
	modulate = Color(0.8, 0.8, 1.0, 1.0)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	is_combat_ready = false

	# Close UI info panel if inspecting this clayling
	var panel = get_tree().get_first_node_in_group("clayling_info_panel")
	if panel and panel.get("tracked_clayling") == self:
		panel.hide_panel()

	# Drop carried inventory items to the ground
	drop_item(-1, true)

	# Clear equipped combat items without dropping them to the ground
	if equipment and equipment.size() > 0:
		equipment.clear()
		equipped_kit = null

	# Stop movement and disable collisions/navigation
	stop_moving()
	set_selected(false)
	collision_shape_2D.set_deferred("disabled", true)
	input_pickable = false
	remove_from_group("claylings")
	remove_from_group("soldiers")

	var rts = get_tree().get_first_node_in_group("rts_controller")
	if rts and "selected_soldiers" in rts:
		rts.selected_soldiers.erase(self)

	if world and "active_claylings" in world:
		world.active_claylings.erase(self)

	if current_state:
		current_state.exit()
		current_state = null

	# Play directional dying animation (uses spearman_dying_* for spearmen and dying_* for villagers)
	var dir = last_direction if last_direction != "" else "down"
	var death_anim = "spearman_dying_" + dir if role == "spearman" else "dying_" + dir
	if not sprite.sprite_frames.has_animation(death_anim):
		death_anim = "dying_down"

	sprite.sprite_frames.set_animation_loop(death_anim, false)
	play_forced_animation(death_anim)

func _start_corpse_decay() -> void:
	# Freeze sprite on the final frame of the death animation
	sprite.pause()
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(sprite.animation):
		var last_frame_idx = sprite.sprite_frames.get_frame_count(sprite.animation) - 1
		if last_frame_idx >= 0:
			sprite.frame = last_frame_idx
	
	# Turn the corpse grey
	var grey_tween = create_tween()
	grey_tween.tween_property(self, "modulate", Color(0.45, 0.45, 0.45, 1.0), 0.5)

	# Wait 20 seconds before fading away
	await get_tree().create_timer(20.0).timeout

	if not is_inside_tree():
		return

	# Fade away over 2 seconds then free node
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 2.0)
	fade_tween.tween_callback(queue_free)

# ---------- GENERAL ----------

func _ready():
	add_to_group("claylings")
	_generate_identity()
	input_pickable = true
	
	# Load all states
	states["Idle"] = load("res://Scripts/States/Villagers/idle.gd").new()
	states["Wander"] = load("res://Scripts/States/Villagers/wandering.gd").new()
	states["Flee"] = load("res://Scripts/States/Villagers/fleeing.gd").new()
	states["Water"] = load("res://Scripts/States/Villagers/watering.gd").new()
	states["Harvest"] = load("res://Scripts/States/Villagers/harvesting.gd").new()
	states["Plant"] = load("res://Scripts/States/Villagers/planting.gd").new()
	states["Pick up"] = load("res://Scripts/States/Villagers/picking_up.gd").new()
	states["Haul"] = load("res://Scripts/States/Villagers/hauling.gd").new()
	states["Equip"] = load("res://Scripts/States/Villagers/equipping.gd").new()
	states["Unequip"] = load("res://Scripts/States/Villagers/unequipping.gd").new()
	states["Chop"] = load("res://Scripts/States/Villagers/chopping.gd").new()
	states["Mine"] = load("res://Scripts/States/Villagers/mining.gd").new()
	states["Forage"] = load("res://Scripts/States/Villagers/foraging.gd").new()
	states["Deliver"] = load("res://Scripts/States/Villagers/delivering.gd").new()
	states["Construct"] = load("res://Scripts/States/Villagers/delivering.gd").new()
	states["ConstructDelivery"] = load("res://Scripts/States/Villagers/construct_delivery.gd").new()
	states["CollectOutput"] = load("res://Scripts/States/Villagers/collect_output.gd").new()
	states["Work"] = load("res://Scripts/States/Villagers/work.gd").new()
	states["Eat"] = load("res://Scripts/States/Villagers/eat.gd").new()
	
	# Load combat states
	states["SoldierMove"] = load("res://Scripts/States/Combat/soldier_move.gd").new()
	states["SoldierToStance"] = load("res://Scripts/States/Combat/soldier_to_stance.gd").new()
	states["SoldierStance"] = load("res://Scripts/States/Combat/soldier_stance.gd").new()
	states["SoldierAttack"] = load("res://Scripts/States/Combat/soldier_attack.gd").new()
	states["SoldierIdle"] = load("res://Scripts/States/Combat/soldier_idle.gd").new()
	
	# Link this clayling to each state
	for s in states.values():
		s.clayling = self

	var wm = get_tree().get_first_node_in_group("weather_manager")
	if wm and wm.has_method("get_weather_speed_multiplier"):
		weather_speed_multiplier = wm.get_weather_speed_multiplier()
	
	last_direction = "down"
	change_state("Idle")
	handle_animation()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	# Update slow debuff timer
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			speed_multiplier = 1.0
			modulate = Color.WHITE

	# Update personal attack alert timer
	if last_attacker != null:
		if not is_instance_valid(last_attacker) or last_attacker.get("is_dead"):
			last_attacker = null
			is_under_attack = false
			_under_attack_timer = 0.0

	if _under_attack_timer > 0.0:
		_under_attack_timer -= delta
		if _under_attack_timer <= 0.0:
			is_under_attack = false
			last_attacker = null

	# Proactive threat detection for unarmed villagers
	if role == "villager" and not is_combat_ready:
		_threat_scan_timer -= delta
		if _threat_scan_timer <= 0.0:
			_threat_scan_timer = randf_range(0.2, 0.28)
			if current_state != states.get("Flee") and current_state != states.get("Equip") and current_state != states.get("Unequip"):
				var threat = _find_nearby_threat(120.0)
				if threat:
					change_state("Flee", {"threat": threat})

	if current_state:
		current_state.update(delta)
	
	var effective_speed = speed * speed_multiplier * weather_speed_multiplier
	if personality_trait == "Hermit":
		var crystal = get_tree().get_first_node_in_group("central_crystal")
		if crystal and is_instance_valid(crystal):
			if global_position.distance_squared_to(crystal.global_position) > 122500.0:
				effective_speed *= 1.25
	elif personality_trait == "NightOwl":
		var day_night = get_tree().get_first_node_in_group("day_night_cycle")
		if day_night and day_night.has_method("is_night"):
			if day_night.is_night():
				effective_speed *= 1.25
			else:
				effective_speed *= 0.9

	if agent.is_navigation_finished():
		velocity = Vector2.ZERO
		_stuck_timer = 0.0
	else:
		var next_path_position = agent.get_next_path_position()
		var new_velocity = global_position.direction_to(next_path_position) * effective_speed
		
		# Proactive continuous wall-sliding to glide smoothly around corners
		if get_slide_collision_count() > 0:
			var col = get_slide_collision(0)
			var normal = col.get_normal()
			var slide_vec = new_velocity.slide(normal)
			if slide_vec.length_squared() > 0.01:
				new_velocity = slide_vec.normalized() * effective_speed

			if get_real_velocity().length() < 12.0:
				_stuck_timer += delta
				if _stuck_timer > 0.05:
					new_velocity = (new_velocity + normal * 16.0).normalized() * effective_speed
			else:
				_stuck_timer = 0.0
		else:
			_stuck_timer = 0.0

		if agent.avoidance_enabled:
			agent.set_velocity(new_velocity)
		else:
			_on_velocity_computed(new_velocity)
	
	if knockback_velocity.length_squared() > 1.0:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 1100.0 * delta)
	else:
		knockback_velocity = Vector2.ZERO

	move_and_slide()
	handle_animation()
	_update_needs(delta)

func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var panel = get_tree().get_first_node_in_group("clayling_info_panel")
		if panel:
			panel.show_clayling(self)

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity

func _find_nearby_threat(max_dist: float = 120.0) -> Node2D:
	var threats = get_tree().get_nodes_in_group("threats")
	var max_dist_sq = max_dist * max_dist
	var nearest: Node2D = null
	var nearest_sq = max_dist_sq
	for t in threats:
		if not is_instance_valid(t) or t.get("is_dead"):
			continue
		var d_sq = global_position.distance_squared_to(t.global_position)
		if d_sq <= nearest_sq:
			nearest = t
			nearest_sq = d_sq
	return nearest

# ---------- SELECTION INDICATOR ----------

var is_selected: bool = false
@onready var selected_halo: Sprite2D = $SelectedHalo

func set_selected(selected: bool) -> void:
	is_selected = selected
	if selected_halo:
		selected_halo.visible = selected and not is_dead
