extends Control
class_name ClockWidget

# ========== REFERENCES ==========

@onready var arrow: TextureRect = $Arrow
@onready var time_label: Label = $TimeLabel
@onready var day_label: Label = $DayLabel
@onready var weather_icon: TextureRect = get_node_or_null("WeatherIcon")

# ========== CONSTANTS ==========

const WEATHER_ICONS_TEX: Texture2D = preload("res://Art/UI/WeatherIcons.png")

# ========== EXPORTS ==========

@export var sun_angle: float = -90
@export var moon_angle: float = 90

# ========== VARIABLES ==========

var _day_night: Node = null
var _weather_manager: Node = null
var _weather_atlas_cache: Array[AtlasTexture] = []

# ========== FUNCTIONS ==========

func _ready() -> void:
	_init_weather_atlas()
	call_deferred("_connect_weather")

func _init_weather_atlas() -> void:
	_weather_atlas_cache.clear()
	for i in range(3):
		var atlas = AtlasTexture.new()
		atlas.atlas = WEATHER_ICONS_TEX
		atlas.region = Rect2(i * 16, 0, 16, 16)
		_weather_atlas_cache.append(atlas)

func _connect_weather() -> void:
	_weather_manager = get_tree().get_first_node_in_group("weather_manager")
	if _weather_manager and _weather_manager.has_signal("weather_changed"):
		if not _weather_manager.weather_changed.is_connected(_on_weather_changed):
			_weather_manager.weather_changed.connect(_on_weather_changed)
		_update_weather_display(_weather_manager.current_weather)

func _on_weather_changed(new_weather: int, _old_weather: int) -> void:
	_update_weather_display(new_weather)

func _update_weather_display(weather_type: int) -> void:
	if not is_instance_valid(weather_icon):
		return
	if weather_type >= 0 and weather_type < _weather_atlas_cache.size():
		weather_icon.texture = _weather_atlas_cache[weather_type]
	if _weather_manager and _weather_manager.has_method("get_weather_name"):
		weather_icon.tooltip_text = _weather_manager.get_weather_name(weather_type)

func _process(_delta: float) -> void:
	var cycle = _get_day_night()
	if cycle != null:
		var swing = abs(cycle.time_of_day - 0.5) * 2.0
		arrow.rotation_degrees = lerp(sun_angle, moon_angle, swing)
		time_label.text = _format_time(cycle.get_hour())
		day_label.text = DayNightCycle.to_roman(cycle.current_day)

	if not is_instance_valid(_weather_manager):
		_weather_manager = get_tree().get_first_node_in_group("weather_manager")
		if _weather_manager and _weather_manager.has_signal("weather_changed"):
			if not _weather_manager.weather_changed.is_connected(_on_weather_changed):
				_weather_manager.weather_changed.connect(_on_weather_changed)
			_update_weather_display(_weather_manager.current_weather)

func _get_day_night() -> Node:
	if _day_night == null or not is_instance_valid(_day_night):
		_day_night = get_tree().get_first_node_in_group("day_night_cycle")
	return _day_night

func _format_time(hour_float: float) -> String:
	var total_minutes = int(hour_float * 60.0)
	var h = total_minutes / 60
	var m = total_minutes % 60
	return "%02d:%02d" % [h, m]
