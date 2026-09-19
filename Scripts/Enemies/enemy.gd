extends CharacterBody2D
class_name Enemy

# ========== SIGNALS ==========

signal enemy_died(enemy: Enemy)

# ========== EXPORTED VARIABLES ==========

@export var enemy_name: String = "Enemy"
@export var max_health: float = 50.0
@export var speed: float = 40.0
@export var attack_damage: float = 12.0
@export var attack_range: float = 22.0
@export var aggro_range: float = 140.0
@export var attack_cooldown: float = 1.5
@export_enum("melee", "ranged") var attack_type: String = "melee"
@export var projectile_scene: PackedScene = null
@export var wander_radius: float = 64.0
@export var attack_windup_time: float = 0.25
@export var attack_knockback: float = 45.0

@export_group("Loot")
@export var loot_table: Array[LootDrop] = []

# ========== STATE & VARIABLES ==========

var health: float = 50.0
var is_dead: bool = false
var current_target: Node2D = null

var state: String = "idle" # "idle", "wander", "chase", "attack", "assault", "death"
var assault_target: Vector2 = Vector2.ZERO
var has_assault_target: bool = false

var _state_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _spawn_pos: Vector2 = Vector2.ZERO
var _stuck_timer: float = 0.0
var _scan_timer: float = 0.0
var _last_direction: String = "down"
var knockback_velocity: Vector2 = Vector2.ZERO

# ========== REFERENCES ==========

@onready var world: Node2D = $".."
@onready var sprite: AnimatedSprite2D = $Pivot/AnimatedSprite2D
@onready var pivot: Node2D = $Pivot
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var agent: NavigationAgent2D = $NavigationAgent2D

# ========== FUNCTIONS ==========

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("threats")
	
	collision_layer = 1
	collision_mask = 2 # Walls layer only
	
	health = max_health
	_spawn_pos = assault_target if has_assault_target else global_position
	_scan_timer = randf_range(0.0, 0.2) # Jitter initial scan
	if has_assault_target:
		call_deferred("_enter_assault")
	else:
		_enter_idle()

func set_assault_target(target_pos: Vector2) -> void:
	assault_target = target_pos
	has_assault_target = true
	_spawn_pos = target_pos
	if is_inside_tree() and state != "attack" and state != "chase":
		_enter_assault()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta

	# Throttled target scanning (every ~0.2s instead of 60 FPS)
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = randf_range(0.18, 0.24)
		if state != "attack":
			_evaluate_target()

	match state:
		"idle":
			_process_idle(delta)
		"wander":
			_process_wander(delta)
		"chase":
			_process_chase(delta)
		"attack":
			_process_attack(delta)
		"assault":
			_process_assault(delta)

	if knockback_velocity.length_squared() > 1.0:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 1100.0 * delta)
	else:
		knockback_velocity = Vector2.ZERO

	move_and_slide()

# ---------- TARGET ACQUISITION ----------

func _is_target_invalid(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return true
	if target.get("is_dead"):
		return true
	if target is Building and target.current_health <= 0:
		return true
	return false

func _evaluate_target() -> void:
	# Verify existing target validity
	if current_target and is_instance_valid(current_target):
		if _is_target_invalid(current_target):
			current_target = null
		else:
			var max_aggro_sq = (aggro_range * 1.5) * (aggro_range * 1.5)
			if global_position.distance_squared_to(current_target.global_position) > max_aggro_sq:
				current_target = null

	# Search for new target if none
	if current_target == null or not is_instance_valid(current_target):
		current_target = _find_closest_target()
		if current_target and state != "attack":
			_enter_chase()

func _find_closest_target() -> Node2D:
	var closest_clayling = _find_closest_clayling()
	if closest_clayling:
		return closest_clayling

	# If in assault mode, target nearby colony buildings if no claylings in sight
	if has_assault_target or state == "assault":
		return _find_closest_building()

	# If wandering near the crystal, aggro on it
	var closest_building = _find_closest_building()
	if closest_building and closest_building.is_in_group("crystal"):
		return closest_building

	return null

func _find_closest_clayling() -> Node2D:
	var claylings = get_tree().get_nodes_in_group("claylings")
	var closest: Node2D = null
	var closest_dist_sq: float = aggro_range * aggro_range

	for c in claylings:
		if not is_instance_valid(c) or c.get("is_dead"):
			continue
		var d_sq = global_position.distance_squared_to(c.global_position)
		if d_sq <= closest_dist_sq:
			closest = c
			closest_dist_sq = d_sq

	return closest

func _find_closest_building() -> Node2D:
	var closest: Node2D = null
	var closest_dist_sq: float = aggro_range * aggro_range

	for c in get_tree().get_nodes_in_group("crystal"):
		if not is_instance_valid(c) or c.get("is_preview") or c.get("_is_destroyed") or ("current_health" in c and c.current_health <= 0):
			continue
		var d_sq = global_position.distance_squared_to(c.global_position)
		if d_sq <= closest_dist_sq:
			closest = c
			closest_dist_sq = d_sq

	for s in get_tree().get_nodes_in_group("storage"):
		if not is_instance_valid(s) or s.get("is_preview"):
			continue
		var d_sq = global_position.distance_squared_to(s.global_position)
		if d_sq <= closest_dist_sq:
			closest = s
			closest_dist_sq = d_sq

	for b in get_tree().get_nodes_in_group("crafting_buildings"):
		if not is_instance_valid(b) or b.get("is_preview") or b is Blueprint:
			continue
		var d_sq = global_position.distance_squared_to(b.global_position)
		if d_sq <= closest_dist_sq:
			closest = b
			closest_dist_sq = d_sq

	return closest

# ---------- STATE MACHINE ----------

func _enter_idle() -> void:
	state = "idle"
	velocity = Vector2.ZERO
	_state_timer = randf_range(1.5, 3.5)
	_play_animation("idle")

func _process_idle(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_timer -= delta
	if _state_timer <= 0.0:
		_enter_wander()

func _enter_wander() -> void:
	state = "wander"
	var offset = Vector2(randf_range(-wander_radius, wander_radius), randf_range(-wander_radius, wander_radius))
	var wander_dest = _spawn_pos + offset
	agent.target_position = wander_dest
	_play_animation("run")

func _process_wander(delta: float) -> void:
	if agent.is_navigation_finished() or global_position.distance_to(agent.target_position) < 8.0:
		_enter_idle()
		return

	var next_pos = agent.get_next_path_position()
	var dir = global_position.direction_to(next_pos)
	velocity = dir * (speed * 0.6)
	_update_direction(dir)

	if get_real_velocity().length() < 3.0:
		_stuck_timer += delta
		if _stuck_timer >= 1.5:
			_stuck_timer = 0.0
			_enter_idle()
			return
	else:
		_stuck_timer = 0.0

func _enter_assault() -> void:
	state = "assault"
	_stuck_timer = 0.0
	if agent:
		agent.target_position = assault_target
	_play_animation("run")

func _process_assault(delta: float) -> void:
	# Arrived near assault target or navigation path completed
	if agent.is_navigation_finished() or global_position.distance_to(assault_target) < 32.0:
		_spawn_pos = global_position
		has_assault_target = false
		_enter_wander()
		return

	# Re-sync target if destination changed
	if agent.target_position.distance_squared_to(assault_target) > 256.0:
		agent.target_position = assault_target

	if not agent.is_navigation_finished():
		var next_pos = agent.get_next_path_position()
		var dir = global_position.direction_to(next_pos)
		velocity = dir * speed
		_update_direction(dir)

		# Anti-stuck watchdog during assault
		if get_real_velocity().length() < 3.0:
			_stuck_timer += delta
			if _stuck_timer >= 2.0:
				_stuck_timer = 0.0
				var detour = assault_target + Vector2(randf_range(-48.0, 48.0), randf_range(-48.0, 48.0))
				agent.target_position = detour
		else:
			_stuck_timer = max(0.0, _stuck_timer - delta * 0.5)
	else:
		velocity = Vector2.ZERO
		_play_animation("idle")

func _enter_chase() -> void:
	state = "chase"
	_stuck_timer = 0.0
	_play_animation("run")

func _process_chase(delta: float) -> void:
	if _is_target_invalid(current_target):
		current_target = null
		if has_assault_target:
			_enter_assault()
		else:
			_enter_idle()
		return

	var dist_sq = global_position.distance_squared_to(current_target.global_position)
	var atk_range_sq = attack_range * attack_range

	# Check if close enough to attack
	if dist_sq <= atk_range_sq:
		velocity = Vector2.ZERO
		_stuck_timer = 0.0
		if _attack_cooldown_timer <= 0.0:
			_enter_attack()
		else:
			_play_animation("idle")
			_face_position(current_target.global_position)
		return

	# Move toward target (only repath if target moved > 16px to avoid 60Hz A* spam)
	if agent.target_position.distance_squared_to(current_target.global_position) > 256.0:
		agent.target_position = current_target.global_position

	if not agent.is_navigation_finished():
		var next_pos = agent.get_next_path_position()
		var dir = global_position.direction_to(next_pos)
		velocity = dir * speed
		_update_direction(dir)

		# Anti-stuck watchdog: if blocked against wall for > 2.0s, drop pursuit
		if get_real_velocity().length() < 5.0:
			_stuck_timer += delta
			if _stuck_timer >= 2.0:
				_stuck_timer = 0.0
				current_target = null
				if has_assault_target:
					_enter_assault()
				else:
					_enter_wander()
				return
		else:
			_stuck_timer = max(0.0, _stuck_timer - delta * 0.5)
	else:
		velocity = Vector2.ZERO
		_play_animation("idle")

var _attack_executed: bool = false

func _enter_attack() -> void:
	state = "attack"
	velocity = Vector2.ZERO
	_state_timer = 0.0
	_attack_executed = false
	if current_target and is_instance_valid(current_target):
		_face_position(current_target.global_position)
	_play_animation("attack")

func _process_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_timer += delta

	# Trigger attack execution once at windup peak
	if not _attack_executed and _state_timer >= attack_windup_time:
		_attack_executed = true
		_execute_attack()

	# Finish attack after animation completion or duration
	var anim_length = 0.6
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(sprite.animation):
		var frame_count = sprite.sprite_frames.get_frame_count(sprite.animation)
		var fps = sprite.sprite_frames.get_animation_speed(sprite.animation)
		if fps > 0:
			anim_length = float(frame_count) / float(fps)

	if _state_timer >= anim_length:
		_attack_cooldown_timer = attack_cooldown
		if current_target and is_instance_valid(current_target) and not _is_target_invalid(current_target):
			_enter_chase()
		else:
			if has_assault_target:
				_enter_assault()
			else:
				_enter_idle()

func _execute_attack() -> void:
	if _is_target_invalid(current_target):
		return

	_face_position(current_target.global_position)

	if attack_type == "melee":
		var dist = global_position.distance_to(current_target.global_position)
		if dist <= attack_range + 24.0:
			if current_target is Building:
				current_target.take_damage(int(attack_damage))
			elif current_target.has_method("take_damage"):
				current_target.take_damage(attack_damage, self)
	elif attack_type == "ranged":
		if projectile_scene:
			var proj = projectile_scene.instantiate()
			var target_pos = current_target.global_position
			if current_target is Building:
				target_pos.y -= (current_target.size_in_tiles.y * 16.0) * 0.5
			elif current_target.get_node_or_null("CollisionShape2D"):
				target_pos = current_target.get_node("CollisionShape2D").global_position

			var shoot_dir = (target_pos - global_position).normalized()
			proj.global_position = global_position + shoot_dir * 8.0
			proj.set_target_direction(shoot_dir)
			proj.damage = attack_damage
			proj.target_group = "claylings"
			proj.shooter = self
			get_parent().add_child(proj)

# ---------- ANIMATIONS & FACING ----------

func _play_animation(anim_name: String) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	var full_anim = anim_name
	# Check directional variants first if available
	if sprite.sprite_frames.has_animation(anim_name + "_" + _last_direction):
		full_anim = anim_name + "_" + _last_direction
	elif sprite.sprite_frames.has_animation(anim_name + "_side"):
		full_anim = anim_name + "_side"
	elif sprite.sprite_frames.has_animation(anim_name):
		full_anim = anim_name

	if sprite.animation != full_anim:
		sprite.play(full_anim)

func _update_direction(dir_vec: Vector2) -> void:
	if abs(dir_vec.x) > abs(dir_vec.y):
		_last_direction = "side"
		sprite.flip_h = dir_vec.x < 0
	else:
		_last_direction = "up" if dir_vec.y < 0 else "down"

func _face_position(target_pos: Vector2) -> void:
	var diff = target_pos - global_position
	if abs(diff.x) > abs(diff.y):
		_last_direction = "side"
		sprite.flip_h = diff.x < 0
	else:
		_last_direction = "up" if diff.y < 0 else "down"

# ---------- DAMAGE & DEATH ----------

func apply_knockback(source_pos: Vector2, force: float) -> void:
	if is_dead or force <= 0.0:
		return
	var dir = (global_position - source_pos).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT.rotated(randf() * TAU)
	var impulse = dir * force
	if impulse.length_squared() > knockback_velocity.length_squared():
		knockback_velocity = impulse

func take_damage(amount: float, attacker: Node2D = null) -> void:
	if is_dead:
		return

	health = max(0.0, health - amount)

	# Sharp white hit flash
	modulate = Color(5.0, 5.0, 5.0, 1.0)
	var hit_tween = create_tween()
	hit_tween.tween_interval(0.07)
	hit_tween.tween_callback(func(): modulate = Color.WHITE)

	# Apply class-based knockback from kit resource if available
	if attacker and is_instance_valid(attacker):
		var kb_force: float = 0.0
		var kit = attacker.get("equipped_kit")
		if kit and kit is KitData:
			kb_force = kit.knockback_force
		elif attacker.get("role") == "villager":
			kb_force = 40.0

		if kb_force > 0.0:
			if attacker.get("personality_trait") == "Strong":
				kb_force += 40.0
			apply_knockback(attacker.global_position, kb_force)

	# If attacker provided, retaliate directly; otherwise scan nearby targets
	if attacker and is_instance_valid(attacker) and not _is_target_invalid(attacker):
		current_target = attacker
		if state != "attack":
			_enter_chase()
	elif state == "idle" or state == "wander" or state == "assault":
		_evaluate_target()

	if health <= 0.0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	state = "death"
	velocity = Vector2.ZERO

	enemy_died.emit(self)
	remove_from_group("enemies")
	remove_from_group("threats")

	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	_play_animation("death")
	_drop_loot()

	# Fade corpse away and remove node
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree():
		return

	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 1.5)
	fade_tween.tween_callback(queue_free)

func _drop_loot() -> void:
	for drop in loot_table:
		if drop == null or drop.item == null:
			continue
		if randf() <= drop.chance:
			var count = randi_range(drop.min_count, drop.max_count)
			if count > 0:
				_spawn_ground_item(drop.item, count, 6.0)

func _spawn_ground_item(item_data: ItemData, count: int, offset_range: float = 0.0) -> void:
	if item_data == null or count <= 0:
		return
	var scene = preload("res://Scenes/item.tscn")
	var item_node: WorldItem = scene.instantiate()
	item_node.data = item_data
	item_node.quantity = count
	var offset = Vector2.ZERO
	if offset_range > 0.0:
		offset = Vector2(randf_range(-offset_range, offset_range), randf_range(-offset_range, offset_range))
	item_node.global_position = global_position + offset
	var target_parent = world if world else get_parent()
	target_parent.call_deferred("add_child", item_node)
