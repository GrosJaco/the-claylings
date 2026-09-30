extends Building
class_name CrystalBuilding

# ========== SIGNALS ==========

signal crystal_damaged(current_hp: int, max_hp: int)
signal crystal_healed(current_hp: int, max_hp: int)
signal crystal_destroyed

# ========== EXPORTS ==========

@export_group("Crystal Stats")
@export var max_crystal_health: int = 500
@export var passive_regen_rate: float = 2.0
@export var regen_cooldown_delay: float = 8.0

@export_group("Visuals & Animation")
@export var hover_amplitude: float = 1.25
@export var hover_speed: float = 2.0
@export var pulse_speed: float = 2.5
@export var pulse_min_energy: float = 0.85
@export var pulse_max_energy: float = 1.35

# ========== STATE & VARIABLES ==========

var _time_since_last_damage: float = 0.0
var _regen_accumulator: float = 0.0
var _is_destroyed: bool = false
var _initial_sprite_y: float = -24.0
var _shake_tween: Tween = null
var _flash_tween: Tween = null
var _bar_fade_tween: Tween = null

# ========== REFERENCES ==========

@onready var sprite_2d: Sprite2D = $SpriteRoot/Sprite2D
@onready var light: PointLight2D = $PointLight2D
@onready var magic_particles: CPUParticles2D = $MagicParticles
@onready var health_bar: ProgressBar = $HealthBar

# ========== FUNCTIONS ==========

func _ready() -> void:
	if is_preview:
		set_process(false)
		if light:
			light.enabled = false
		if magic_particles:
			magic_particles.emitting = false
		if health_bar:
			health_bar.visible = false
		return

	building_type = "crystal"
	size_in_tiles = Vector2i(3, 3)
	max_health = max_crystal_health
	current_health = max_health

	add_to_group("crystal")
	add_to_group("central_crystal")

	super._ready()

	if sprite_root:
		_initial_sprite_y = sprite_root.position.y

	_setup_health_bar()
	_register_building_tiles()

func _setup_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = false

func _register_building_tiles() -> void:
	var manager = get_tree().get_first_node_in_group("building_manager")
	if manager:
		var occupied = _get_footprint_tiles()
		for tile in occupied:
			if not tile in manager.used_tiles:
				manager.used_tiles.append(tile)

func _get_footprint_tiles() -> Array[Vector2i]:
	var occupied_tiles: Array[Vector2i] = []
	var offset = Vector2((size_in_tiles.x * 16) / 2.0, size_in_tiles.y * 16)
	var top_left_world_pos = global_position - offset
	var top_left_tile = Vector2i(
		round(top_left_world_pos.x / 16.0),
		round(top_left_world_pos.y / 16.0)
	)
	for x in range(size_in_tiles.x):
		for y in range(size_in_tiles.y):
			occupied_tiles.append(top_left_tile + Vector2i(x, y))
	return occupied_tiles

func _process(delta: float) -> void:
	if _is_destroyed:
		return

	_process_hover_and_light()
	_process_passive_regen(delta)

func _process_hover_and_light() -> void:
	var ticks = Time.get_ticks_msec() * 0.001
	if sprite_root:
		sprite_root.position.y = _initial_sprite_y + sin(ticks * hover_speed) * hover_amplitude

	if light:
		var pulse_t = (sin(ticks * pulse_speed) + 1.0) * 0.5
		light.energy = lerp(pulse_min_energy, pulse_max_energy, pulse_t)

func _process_passive_regen(delta: float) -> void:
	if current_health >= max_health:
		if health_bar and health_bar.visible and health_bar.modulate.a > 0.0 and (_bar_fade_tween == null or not _bar_fade_tween.is_valid()):
			_bar_fade_tween = create_tween()
			_bar_fade_tween.tween_interval(2.0)
			_bar_fade_tween.tween_property(health_bar, "modulate:a", 0.0, 0.8)
			_bar_fade_tween.tween_callback(func(): health_bar.visible = false)
		return

	_time_since_last_damage += delta
	if _time_since_last_damage >= regen_cooldown_delay:
		_regen_accumulator += passive_regen_rate * delta
		if _regen_accumulator >= 1.0:
			var heal_points = int(_regen_accumulator)
			_regen_accumulator -= heal_points
			current_health = min(max_health, current_health + heal_points)
			_update_health_bar()
			crystal_healed.emit(current_health, max_health)

# ---------- COMBAT & DAMAGE ----------

func take_damage(amount: int):
	if _is_destroyed:
		return

	_time_since_last_damage = 0.0
	current_health = max(0, current_health - amount)

	_show_health_bar()
	_update_health_bar()
	_play_hit_effects()

	SoundManager.play_at("crystal hit", global_position, 0.15)
	crystal_damaged.emit(current_health, max_health)

	if current_health <= 0:
		destroyed()

func _update_health_bar() -> void:
	if health_bar:
		health_bar.value = current_health

func _show_health_bar() -> void:
	if not health_bar:
		return

	if _bar_fade_tween and _bar_fade_tween.is_valid():
		_bar_fade_tween.kill()

	health_bar.modulate.a = 1.0
	health_bar.visible = true

func _play_hit_effects() -> void:
	if sprite_2d:
		if _flash_tween and _flash_tween.is_valid():
			_flash_tween.kill()
		_flash_tween = create_tween()
		sprite_2d.modulate = Color(2.5, 0.4, 0.4, 1.0)
		_flash_tween.tween_property(sprite_2d, "modulate", Color.WHITE, 0.18)

	if sprite_root:
		if _shake_tween and _shake_tween.is_valid():
			_shake_tween.kill()
		_shake_tween = create_tween()
		_shake_tween.tween_property(sprite_root, "position:x", 3.0, 0.03)
		_shake_tween.tween_property(sprite_root, "position:x", -3.0, 0.03)
		_shake_tween.tween_property(sprite_root, "position:x", 1.5, 0.03)
		_shake_tween.tween_property(sprite_root, "position:x", 0.0, 0.03)

# ---------- DESTRUCTION ----------

func destroyed() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true

	crystal_destroyed.emit()
	get_tree().call_group("defeat_ui", "show_defeat")
	SoundManager.play_at("crystal breaks", global_position, 0.2)

	# Burst magical particles outwards
	if magic_particles:
		magic_particles.amount = 35
		magic_particles.initial_velocity_min = 40.0
		magic_particles.initial_velocity_max = 85.0
		magic_particles.explosiveness = 0.95
		magic_particles.lifetime_randomness = 0.5
		magic_particles.lifetime = 10
		magic_particles.restart()

	# Fade out visual elements
	if sprite_2d:
		var t = create_tween()
		t.tween_property(sprite_2d, "modulate:a", 0.0, 0.6)
	if light:
		var t_light = create_tween()
		t_light.tween_property(light, "energy", 0.0, 0.6)
	if health_bar:
		health_bar.visible = false

	# Free tiles from BuildingManager so space becomes clear
	var manager = get_tree().get_first_node_in_group("building_manager")
	if manager:
		manager.free_tiles(_get_footprint_tiles())

	# Delay removal to allow sound and explosion effects to finish
	await get_tree().create_timer(2.5).timeout
	queue_free()
