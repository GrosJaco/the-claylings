extends Node2D
class_name WaveManager

# ========== SIGNALS ==========

signal wave_warning(wave_num: int, budget: int)
signal wave_started(wave_num: int, enemy_count: int)
signal wave_cleared(wave_num: int)

# ========== EXPORTS ==========

@export_group("Enemy Catalog")
@export var enemy_catalog: Array[EnemySpawnData] = []

@export_group("Budget & Difficulty")
@export var base_budget: int = 9  # Base budget
@export var growth_factor: float = 6.0 # Rate of budget growth per subsequent wave
@export var growth_exponent: float = 1.2 # Exponential scaling curve for later waves

@export_group("Timing & Pacing")
@export var spawn_interval: float = 0.4
@export var wave_frequency_days: int = 1 # How often waves trigger: 1 = every night, 2 = every 2 nights

@export_group("Audio")
@export var alert_sound: String = ""
@export var victory_sound: String = ""

# ========== STATE ==========

var current_wave: int = 0
var active_enemies: Array[Node2D] = []
var is_wave_active: bool = false
var is_spawning: bool = false
var _completion_check_timer: float = 0.0

# ========== REFERENCES ==========

@onready var world: Node2D = $".."
var day_night: DayNightCycle = null

# ========== FUNCTIONS ==========

func _ready() -> void:
	add_to_group("wave_manager")
	# Connect to DayNightCycle once the scene tree is fully ready
	call_deferred("_connect_day_night")

func _process(delta: float) -> void:
	if is_wave_active and not is_spawning:
		_completion_check_timer -= delta
		if _completion_check_timer <= 0.0:
			_completion_check_timer = 0.4
			_check_wave_completion()


func _connect_day_night() -> void:
	day_night = get_tree().get_first_node_in_group("day_night_cycle")
	if day_night:
		day_night.night_started.connect(_on_night_started)

# ---------- NIGHT TRIGGER & MANUAL TRIGGER ----------

func trigger_next_wave() -> void:
	current_wave += 1
	var budget = calculate_budget(current_wave)
	start_procedural_wave(current_wave, budget)

func _on_night_started() -> void:
	if day_night and (day_night.current_day % wave_frequency_days == 0):
		trigger_next_wave()

func calculate_budget(wave_num: int) -> int:
	if wave_num <= 1:
		return base_budget
	var extra = pow(float(wave_num - 1), growth_exponent) * growth_factor
	return base_budget + int(round(extra))

# ---------- ROSTER GENERATION ----------

func generate_roster(budget: int, wave_num: int) -> Array[EnemySpawnData]:
	var roster: Array[EnemySpawnData] = []
	var remaining_budget = budget

	# Filter unlocked enemies for this wave
	var unlocked = enemy_catalog.filter(func(e): return e != null and e.min_wave <= wave_num)

	# Determine cheapest unlocked enemy to know when budget is exhausted
	var min_cost: int = 999999
	for e in unlocked:
		min_cost = min(min_cost, e.point_cost)

	# Spend available points
	while remaining_budget >= min_cost:
		var affordable = unlocked.filter(func(e): return e.point_cost <= remaining_budget)
		if affordable.is_empty():
			break

		var chosen = _pick_weighted(affordable)
		if chosen:
			roster.append(chosen)
			remaining_budget -= chosen.point_cost
		else:
			break

	return roster

func _pick_weighted(candidates: Array) -> EnemySpawnData:
	var total_weight: float = 0.0
	for e in candidates:
		total_weight += max(0.01, e.selection_weight)

	var roll = randf() * total_weight
	var cumulative: float = 0.0
	for e in candidates:
		cumulative += max(0.01, e.selection_weight)
		if roll <= cumulative:
			return e

	return candidates.back() if not candidates.is_empty() else null

# ---------- WAVE SPAWN & ASSAULT ----------

func start_procedural_wave(wave_num: int, budget: int) -> void:
	var roster = generate_roster(budget, wave_num)
	if roster.is_empty():
		return

	is_wave_active = true
	is_spawning = true
	wave_started.emit(wave_num, roster.size())

	# Optional alert SFX if defined in SoundManager
	if alert_sound != "" and "sounds" in SoundManager and SoundManager.sounds.has(alert_sound):
		SoundManager.play(alert_sound)

	# Determine spawn points (split into 2 flanks on wave 4+)
	var directions = ["north", "south", "east", "west"]
	var spawn_points: Array[Vector2] = []
	var primary_dir = directions.pick_random()
	spawn_points.append(_get_edge_spawn_point(primary_dir))

	if wave_num >= 4:
		var secondary_dirs = directions.filter(func(d): return d != primary_dir)
		spawn_points.append(_get_edge_spawn_point(secondary_dirs.pick_random()))

	var colony_center = _get_colony_center()

	# Spawn enemies sequentially
	for i in range(roster.size()):
		var enemy_data = roster[i]
		if enemy_data == null or enemy_data.scene == null:
			continue

		var spawn_pos = spawn_points[i % spawn_points.size()]
		var jitter = Vector2(randf_range(-16.0, 16.0), randf_range(-16.0, 16.0))

		var enemy = enemy_data.scene.instantiate()
		world.add_child(enemy)
		enemy.global_position = spawn_pos + jitter

		# Route enemy toward colony center
		if enemy.has_method("set_assault_target"):
			enemy.set_assault_target(colony_center)
		elif "agent" in enemy and enemy.agent:
			enemy.agent.target_position = colony_center

		active_enemies.append(enemy)

		if spawn_interval > 0.0:
			await get_tree().create_timer(spawn_interval).timeout

	is_spawning = false

# ---------- COMPLETION CHECK ----------

func _check_wave_completion() -> void:
	# Keep only live, valid enemies
	active_enemies = active_enemies.filter(func(e): return is_instance_valid(e) and not e.get("is_dead"))

	if active_enemies.is_empty():
		is_wave_active = false
		wave_cleared.emit(current_wave)

		if victory_sound != "" and "sounds" in SoundManager and SoundManager.sounds.has(victory_sound):
			SoundManager.play(victory_sound)

# ---------- SPAWN POSITION HELPERS ----------

func _get_edge_spawn_point(direction: String) -> Vector2:
	var terrain = world.get_node_or_null("Terrain")
	if terrain and "map_size" in terrain and "wall_cells" in terrain and "water_cells" in terrain:
		var map_w: int = terrain.map_size.x
		var map_h: int = terrain.map_size.y
		var candidates: Array[Vector2i] = []

		match direction:
			"north":
				for x in range(5, map_w - 5):
					var tile = Vector2i(x, 2)
					if not tile in terrain.wall_cells and not tile in terrain.water_cells:
						candidates.append(tile)
			"south":
				for x in range(5, map_w - 5):
					var tile = Vector2i(x, map_h - 3)
					if not tile in terrain.wall_cells and not tile in terrain.water_cells:
						candidates.append(tile)
			"east":
				for y in range(5, map_h - 5):
					var tile = Vector2i(map_w - 3, y)
					if not tile in terrain.wall_cells and not tile in terrain.water_cells:
						candidates.append(tile)
			"west":
				for y in range(5, map_h - 5):
					var tile = Vector2i(2, y)
					if not tile in terrain.wall_cells and not tile in terrain.water_cells:
						candidates.append(tile)

		if not candidates.is_empty():
			var chosen = candidates.pick_random()
			return Vector2(chosen.x * 16 + 8, chosen.y * 16 + 8)

	# Fallback if terrain is unavailable or all edge tiles are blocked
	var center = _get_colony_center()
	var angle = randf() * TAU
	return center + Vector2(cos(angle), sin(angle)) * 600.0

func _get_colony_center() -> Vector2:
	var crystals = get_tree().get_nodes_in_group("crystal")
	for c in crystals:
		if is_instance_valid(c) and not c.get("is_preview") and not c.get("_is_destroyed") and ("current_health" not in c or c.current_health > 0):
			return c.global_position

	var storages = get_tree().get_nodes_in_group("storage")
	for s in storages:
		if is_instance_valid(s):
			return s.global_position

	var claylings = get_tree().get_nodes_in_group("claylings")
	for c in claylings:
		if is_instance_valid(c) and not c.get("is_dead"):
			return c.global_position

	var terrain = world.get_node_or_null("Terrain")
	if terrain and "map_size" in terrain:
		return Vector2(terrain.map_size.x * 8.0, terrain.map_size.y * 8.0)

	return Vector2(1024.0, 1024.0)
