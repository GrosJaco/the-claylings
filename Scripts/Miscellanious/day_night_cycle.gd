extends CanvasModulate
class_name DayNightCycle

# ========== SIGNALS ==========

signal day_started
signal night_started
signal new_day_announced(day_number: int)

# ========== VARIABLES ==========

@export var day_duration: float = 300.0
@export var color_over_time: Gradient
@export var time_of_day: float = 0.3

@export_range(0.0, 1.0) var night_start: float = 20.0 / 24.0
@export_range(0.0, 1.0) var night_end: float = 0.25
@export_range(0.0, 1.0) var announce_hour: float = 8.0 / 24.0

var current_day: int = 1

var _was_night: bool = false
var _has_announced_today: bool = false

# ========== FUNCTIONS ==========

func _ready() -> void:
	add_to_group("day_night_cycle")
	if color_over_time:
		color = color_over_time.sample(time_of_day)

func _process(delta: float) -> void:
	# Wait for the central crystal to be placed before advancing time
	if not _has_placed_crystal():
		if color_over_time:
			color = color_over_time.sample(time_of_day)
		return

	var previous_time = time_of_day
	time_of_day = fmod(time_of_day + delta / day_duration, 1.0)
	
	if time_of_day < previous_time:
		current_day += 1
		_has_announced_today = false
	
	if color_over_time:
		color = color_over_time.sample(time_of_day)
	
	var night_now = is_night()
	if night_now and not _was_night:
		night_started.emit()
	elif not night_now and _was_night:
		day_started.emit()
	_was_night = night_now
	
	if not _has_announced_today and time_of_day >= announce_hour:
		_has_announced_today = true
		new_day_announced.emit(current_day)

func _has_placed_crystal() -> bool:
	var crystals = get_tree().get_nodes_in_group("crystal")
	for c in crystals:
		if is_instance_valid(c) and not c.get("is_preview") and not c.get("_is_destroyed"):
			return true
	return false

func is_night() -> bool:
	return time_of_day >= night_start or time_of_day < night_end

func get_hour() -> float:
	return time_of_day * 24.0

# ---------- TIME CONTROL ----------

func set_time(new_time: float) -> void:
	time_of_day = fposmod(new_time, 1.0)
	if color_over_time:
		color = color_over_time.sample(time_of_day)
	
	var night_now = is_night()
	if night_now and not _was_night:
		night_started.emit()
	elif not night_now and _was_night:
		day_started.emit()
	_was_night = night_now

func set_hour(target_hour: float) -> void:
	set_time(target_hour / 24.0)

func shift_hours(delta_hours: float) -> void:
	var raw_new_time = time_of_day + (delta_hours / 24.0)
	if raw_new_time >= 1.0:
		current_day += int(floor(raw_new_time))
	elif raw_new_time < 0.0:
		current_day = max(1, current_day + int(floor(raw_new_time)))
	set_time(raw_new_time)

static func to_roman(n: int) -> String:
	if n <= 0:
		return ""
	var values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
	var symbols = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
	var result = ""
	var remaining = n
	for i in range(values.size()):
		while remaining >= values[i]:
			result += symbols[i]
			remaining -= values[i]
	return result
