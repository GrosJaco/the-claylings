extends Building
class_name Torch

# ========== REFERENCES ==========

@onready var light: PointLight2D = $PointLight2D
@onready var fire_particles: CPUParticles2D = $FireParticles

# ========== CONFIGURATION ==========

@export var base_light_energy: float = 1.05
@export var flicker_intensity: float = 0.08
@export var flicker_speed: float = 8.0

var _flicker_time: float = 0.0

# ========== LIFECYCLE ==========

func _ready() -> void:
	super._ready()
	add_to_group("decorations")
	add_to_group("torches")

	if is_preview:
		if light:
			light.enabled = false
		if fire_particles:
			fire_particles.emitting = false
	else:
		if light:
			light.enabled = true
		if fire_particles:
			fire_particles.emitting = true

func _process(delta: float) -> void:
	if is_preview or not is_instance_valid(light) or not light.enabled:
		return

	_flicker_time += delta * flicker_speed
	var flicker = sin(_flicker_time) * 0.6 + sin(_flicker_time * 2.37) * 0.4
	light.energy = base_light_energy + flicker * flicker_intensity
