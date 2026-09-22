extends Node
class_name WeatherManager

# ========== SIGNALS ==========

signal weather_changed(new_weather: WeatherType, old_weather: WeatherType)
signal lightning_occurred

# ========== ENUMS ==========

enum WeatherType {
	CLEAR = 0,
	RAIN = 1,
	THUNDERSTORM = 2
}

# ========== EXPORT VARIABLES ==========

@export var current_weather: WeatherType = WeatherType.CLEAR
@export var is_weather_cycling: bool = true
@export var clear_duration_range: Vector2 = Vector2(120.0, 240.0)
@export var rain_duration_range: Vector2 = Vector2(60.0, 120.0)
@export var storm_duration_range: Vector2 = Vector2(35.0, 60.0)

# ========== CONSTANTS ==========

const RAIN_SFX: AudioStream = preload("res://Audio/SFX/rain_ambient.wav")

# ========== REFERENCES ==========

@onready var canvas_layer: CanvasLayer = $WeatherCanvasLayer
@onready var rain_particles: CPUParticles2D = $RainParticles
@onready var sky_overlay: ColorRect = $WeatherCanvasLayer/SkyOverlay
@onready var lightning_flash: ColorRect = $WeatherCanvasLayer/LightningFlash
@onready var ambient_rain_player: AudioStreamPlayer = $AmbientRainPlayer

# ========== VARIABLES ==========

var weather_timer: float = 120.0
var _lightning_timer: float = 8.0
var _weather_tween: Tween = null
var _flash_tween: Tween = null

# ========== FUNCTIONS ==========

func _ready() -> void:
	add_to_group("weather_manager")

	if is_instance_valid(ambient_rain_player):
		ambient_rain_player.stream = RAIN_SFX

	get_viewport().size_changed.connect(_update_particle_bounds)
	_update_particle_bounds()

	weather_timer = randf_range(clear_duration_range.x, clear_duration_range.y)
	set_weather(current_weather, weather_timer, true)

func _process(delta: float) -> void:
	_update_rain_position()

	if not _has_placed_crystal():
		return

	if is_weather_cycling:
		weather_timer -= delta
		if weather_timer <= 0.0:
			_pick_next_weather()

	if current_weather == WeatherType.THUNDERSTORM:
		_lightning_timer -= delta
		if _lightning_timer <= 0.0:
			trigger_lightning()
			_lightning_timer = randf_range(7.0, 16.0)

func _update_rain_position() -> void:
	if not is_instance_valid(rain_particles) or not rain_particles.emitting:
		return
	var camera = get_tree().get_first_node_in_group("camera")
	if not camera or not is_instance_valid(camera):
		return
	var cam_zoom = camera.zoom.x if camera.zoom.x > 0.0 else 1.0
	var half_h = (get_viewport().get_visible_rect().size.y / cam_zoom) * 0.5
	rain_particles.global_position = camera.global_position + Vector2(100.0, -half_h - 60.0)

func _has_placed_crystal() -> bool:
	var crystals = get_tree().get_nodes_in_group("crystal")
	for c in crystals:
		if is_instance_valid(c) and not c.get("is_preview") and not c.get("_is_destroyed"):
			return true
	return false

func set_weather(new_weather: WeatherType, duration: float = -1.0, immediate: bool = false) -> void:
	var old_weather = current_weather
	current_weather = new_weather

	if duration > 0.0:
		weather_timer = duration
	else:
		weather_timer = _get_random_duration_for(new_weather)

	if current_weather == WeatherType.THUNDERSTORM:
		_lightning_timer = randf_range(3.0, 7.0)

	_apply_visuals(immediate)
	_apply_audio(immediate)
	_notify_claylings()

	weather_changed.emit(new_weather, old_weather)

func cycle_next_weather() -> void:
	var next = (int(current_weather) + 1) % 3
	set_weather(next as WeatherType)

func trigger_lightning() -> void:
	if not is_instance_valid(lightning_flash):
		return

	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	# Double flash lightning pulse
	_flash_tween = create_tween()
	lightning_flash.color = Color(0.9, 0.95, 1.0, 0.0)
	_flash_tween.tween_property(lightning_flash, "color:a", 0.75, 0.05)
	_flash_tween.tween_property(lightning_flash, "color:a", 0.15, 0.06)
	_flash_tween.tween_property(lightning_flash, "color:a", 0.65, 0.05)
	_flash_tween.tween_property(lightning_flash, "color:a", 0.0, 0.35)

	SoundManager.play("thunder", 0.15)

	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake"):
		camera.shake(5.0, 0.35)

	lightning_occurred.emit()

func is_raining() -> bool:
	return current_weather == WeatherType.RAIN or current_weather == WeatherType.THUNDERSTORM

func get_rain_water_rate() -> float:
	match current_weather:
		WeatherType.RAIN:
			return 0.5
		WeatherType.THUNDERSTORM:
			return 1.2
		_:
			return 0.0

func get_weather_speed_multiplier() -> float:
	match current_weather:
		WeatherType.RAIN:
			return 0.90
		WeatherType.THUNDERSTORM:
			return 0.85
		_:
			return 1.0

func get_weather_name(type: WeatherType = current_weather) -> String:
	match type:
		WeatherType.CLEAR:
			return "Clear"
		WeatherType.RAIN:
			return "Rain"
		WeatherType.THUNDERSTORM:
			return "Thunderstorm"
		_:
			return "Unknown"

func _pick_next_weather() -> void:
	var roll = randf()
	var next: WeatherType = WeatherType.CLEAR

	# Transition probabilities modeling natural weather flow
	match current_weather:
		WeatherType.CLEAR:
			if roll < 0.70:
				next = WeatherType.CLEAR
			elif roll < 0.92:
				next = WeatherType.RAIN
			else:
				next = WeatherType.THUNDERSTORM
		WeatherType.RAIN:
			if roll < 0.55:
				next = WeatherType.CLEAR
			elif roll < 0.80:
				next = WeatherType.RAIN
			else:
				next = WeatherType.THUNDERSTORM
		WeatherType.THUNDERSTORM:
			if roll < 0.50:
				next = WeatherType.RAIN
			else:
				next = WeatherType.CLEAR

	set_weather(next)

func _get_random_duration_for(type: WeatherType) -> float:
	match type:
		WeatherType.CLEAR:
			return randf_range(clear_duration_range.x, clear_duration_range.y)
		WeatherType.RAIN:
			return randf_range(rain_duration_range.x, rain_duration_range.y)
		WeatherType.THUNDERSTORM:
			return randf_range(storm_duration_range.x, storm_duration_range.y)
		_:
			return 120.0

func _apply_visuals(immediate: bool) -> void:
	if not is_instance_valid(rain_particles) or not is_instance_valid(sky_overlay):
		return

	if _weather_tween and _weather_tween.is_valid():
		_weather_tween.kill()

	var target_sky_color: Color = Color(1.0, 1.0, 1.0, 0.0)
	var target_amount: int = 0
	var should_emit: bool = false
	var target_particle_velocity: float = 480.0

	match current_weather:
		WeatherType.CLEAR:
			target_sky_color = Color(0.1, 0.1, 0.15, 0.0)
			target_amount = 0
			should_emit = false
		WeatherType.RAIN:
			target_sky_color = Color(0.227, 0.298, 0.412, 0.22)
			target_amount = 1000
			should_emit = true
			target_particle_velocity = 620.0
		WeatherType.THUNDERSTORM:
			target_sky_color = Color(0.157, 0.211, 0.299, 0.439)
			target_amount = 1700
			should_emit = true
			target_particle_velocity = 820.0

	if should_emit:
		_update_rain_position()

	if immediate:
		sky_overlay.color = target_sky_color
		rain_particles.emitting = should_emit
		if should_emit:
			rain_particles.amount = target_amount
			rain_particles.initial_velocity_min = target_particle_velocity * 0.85
			rain_particles.initial_velocity_max = target_particle_velocity * 1.15
	else:
		_weather_tween = create_tween().set_parallel(true)
		_weather_tween.tween_property(sky_overlay, "color", target_sky_color, 2.5)

		if should_emit:
			rain_particles.amount = target_amount
			rain_particles.initial_velocity_min = target_particle_velocity * 0.85
			rain_particles.initial_velocity_max = target_particle_velocity * 1.15
			rain_particles.emitting = true
		else:
			# Allow remaining drops to dissipate before stopping
			get_tree().create_timer(1.2).timeout.connect(func():
				if current_weather == WeatherType.CLEAR and is_instance_valid(rain_particles):
					rain_particles.emitting = false
			)

func _apply_audio(immediate: bool) -> void:
	if not is_instance_valid(ambient_rain_player):
		return

	var target_volume_db: float = -80.0
	var should_play: bool = false

	match current_weather:
		WeatherType.CLEAR:
			target_volume_db = -80.0
			should_play = false
		WeatherType.RAIN:
			target_volume_db = -9.0
			should_play = true
		WeatherType.THUNDERSTORM:
			target_volume_db = -4.0
			should_play = true

	if immediate:
		ambient_rain_player.volume_db = target_volume_db
		if should_play and not ambient_rain_player.playing:
			ambient_rain_player.play()
		elif not should_play and ambient_rain_player.playing:
			ambient_rain_player.stop()
	else:
		var audio_tween = create_tween()
		if should_play:
			if not ambient_rain_player.playing:
				ambient_rain_player.volume_db = -80.0
				ambient_rain_player.play()
			audio_tween.tween_property(ambient_rain_player, "volume_db", target_volume_db, 2.0)
		else:
			audio_tween.tween_property(ambient_rain_player, "volume_db", -80.0, 2.0)
			audio_tween.tween_callback(func():
				if current_weather == WeatherType.CLEAR and is_instance_valid(ambient_rain_player):
					ambient_rain_player.stop()
			)

func _update_particle_bounds() -> void:
	if not is_instance_valid(rain_particles):
		return
	var vp_size = get_viewport().get_visible_rect().size
	# Span wide enough across world coordinates to cover lowest zoom (zoom_min = 0.5)
	var max_world_w = vp_size.x / 0.5
	rain_particles.emission_rect_extents = Vector2(max_world_w * 0.65 + 400.0, 20.0)

func _notify_claylings() -> void:
	var mult = get_weather_speed_multiplier()
	var claylings = get_tree().get_nodes_in_group("claylings")
	for c in claylings:
		if is_instance_valid(c) and "weather_speed_multiplier" in c:
			c.weather_speed_multiplier = mult

func get_save_data() -> Dictionary:
	return {
		"current_weather": int(current_weather),
		"weather_timer": weather_timer,
		"is_weather_cycling": is_weather_cycling
	}

func load_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	var w = data.get("current_weather", int(WeatherType.CLEAR))
	var t = data.get("weather_timer", 120.0)
	if data.has("is_weather_cycling"):
		is_weather_cycling = bool(data["is_weather_cycling"])
	set_weather(w as WeatherType, t, true)
