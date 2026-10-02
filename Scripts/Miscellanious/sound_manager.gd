extends Node

var sounds: Dictionary = {
	"chop": preload("res://Audio/SFX/chop.wav"),
	"tree fall": preload("res://Audio/SFX/tree_fall.wav"),
	"rock hit": preload("res://Audio/SFX/rock_hit.wav"),
	"rock break": preload("res://Audio/SFX/rock_break.wav"),
	"grass": preload("res://Audio/SFX/grass.wav"),
	"furnace": preload("res://Audio/SFX/furnace.wav"),
	"thunder": [preload("res://Audio/SFX/thunder.wav"), preload("res://Audio/SFX/thunder2.wav")],
	"thunder1": preload("res://Audio/SFX/thunder.wav"),
	"thunder2": preload("res://Audio/SFX/thunder2.wav"),
	"watering": preload("res://Audio/SFX/watering.wav"),
	"equipping": preload("res://Audio/SFX/equipping.wav"),
	"step": [preload("res://Audio/SFX/step1.wav"), preload("res://Audio/SFX/step2.wav"), preload("res://Audio/SFX/step3.wav")],
	"step1": preload("res://Audio/SFX/step1.wav"),
	"step2": preload("res://Audio/SFX/step2.wav"),
	"step3": preload("res://Audio/SFX/step3.wav"),
	"shoot": preload("res://Audio/SFX/shoot.wav"),
	"die": preload("res://Audio/SFX/die.wav"),
	"bell": preload("res://Audio/SFX/bell.wav"),
	"crystal breaks": preload("res://Audio/SFX/crystal_breaks.wav"),
	"crystal hit": [preload("res://Audio/SFX/crystal_hit1.wav"), preload("res://Audio/SFX/crystal_hit2.wav")],
	"crystal hit1": preload("res://Audio/SFX/crystal_hit1.wav"),
	"crystal hit2": preload("res://Audio/SFX/crystal_hit2.wav"),
	"forge": preload("res://Audio/SFX/forge.wav"),
	"harvesting": preload("res://Audio/SFX/harvesting.wav"),
	"loom": preload("res://Audio/SFX/loom.wav"),
	"planting": preload("res://Audio/SFX/planting.wav"),
	"pop": preload("res://Audio/SFX/pop.wav"),
	"spider bite": preload("res://Audio/SFX/spider_bite.wav"),
	"spider running": preload("res://Audio/SFX/spider_running.wav"),
	"spider spit": preload("res://Audio/SFX/spider_spit.wav"),
}

# Base volume offsets (in dB) to balance all sounds across the game
var sound_base_volumes: Dictionary = {
	# Ambient & loops
	"furnace": -8.0,

	# Heavy impacts & destruction
	"thunder": -15.0,
	"thunder1": -15.0,
	"thunder2": -15.0,
	"bell": -3.0,
	"crystal breaks": -3.0,
	"tree fall": -7.0,
	"rock break": -7.0,

	# Frequent movements & pickups
	"step": -4.0,
	"step1": -4.0,
	"step2": -4.0,
	"step3": -4.0,
	"pop": -13.0,
	"spider running": -12.0,

	# Work, harvest & gathering
	"chop": -10.0,
	"rock hit": -7.0,
	"crystal hit": -5.0,
	"crystal hit1": -5.0,
	"crystal hit2": -5.0,
	"grass": -6.0,
	"harvesting": -3.0,
	"planting": -3.0,
	"watering": -3.0,
	"forge": -5.0,
	"loom": 4.0,

	# Combat & projectiles
	"shoot": -6.0,
	"die": -5.0,
	"equipping": -6.0,
	"spider bite": -5.0,
	"spider spit": -6.0,
}

@export_group("Spatial Audio")
@export var outside_fade_distance: float = 500.0
# Total volume drop (in dB) once a sound is outside_fade_distance away from the frame edge
@export var max_outside_attenuation_db: float = 40.0
# Camera zoom value at which sounds play at full volume (your "normal"/zoomed-in reference)
@export var zoom_reference: float = 4.0
# Camera zoom value at which sounds are fully muted (your camera's max dezoom / zoom_min)
@export var zoom_out_silence: float = 0.5

func get_camera_zoom_db() -> float:
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return 0.0
	var current_zoom = camera.zoom.x
	var zoom_t = clamp(inverse_lerp(zoom_reference, zoom_out_silence, current_zoom), 0.0, 1.0)
	var zoom_factor = 1.0 - zoom_t
	return linear_to_db(max(zoom_factor, 0.0001))

func play(sound_name: String, pitch_variation: float = 0.0, volume_offset_db: float = 0.0) -> Node:
	return _spawn_player(sound_name, pitch_variation, null, volume_offset_db)

func play_at(sound_name: String, world_position: Vector2, pitch_variation: float = 0.0, volume_offset_db: float = 0.0) -> Node:
	return _spawn_player(sound_name, pitch_variation, world_position, volume_offset_db)

func _spawn_player(sound_name: String, pitch_variation: float, world_position, volume_offset_db: float = 0.0) -> Node:
	if not sounds.has(sound_name) or sounds[sound_name] == null:
		return null

	var stream_entry = sounds[sound_name]
	var stream: AudioStream = null
	if stream_entry is Array:
		if stream_entry.is_empty():
			return null
		stream = stream_entry.pick_random()
	elif stream_entry is AudioStream:
		stream = stream_entry
	else:
		return null

	var base_vol: float = sound_base_volumes.get(sound_name, 0.0)

	var player: Node
	if world_position != null:
		var p2d := AudioStreamPlayer2D.new()
		p2d.global_position = world_position

		var camera = get_viewport().get_camera_2d()
		if camera:
			var current_zoom = camera.zoom.x

			# 1. VOLUME DROP LINKED TO ZOOM LEVEL
			var zoom_t = clamp(inverse_lerp(zoom_reference, zoom_out_silence, current_zoom), 0.0, 1.0)
			var zoom_factor = 1.0 - zoom_t
			var zoom_db = linear_to_db(max(zoom_factor, 0.0001))

			# 2. VOLUME DROP LINKED TO FRAME
			var canvas_transform = get_viewport().get_canvas_transform()
			var inv_transform = canvas_transform.affine_inverse()
			var vp_size = get_viewport().get_visible_rect().size
			var top_left = inv_transform * Vector2.ZERO
			var bottom_right = inv_transform * vp_size
			var frame_rect = Rect2(top_left, bottom_right - top_left).abs()

			var distance_outside = 0.0
			if not frame_rect.has_point(world_position):
				# If the sound is outside the frame, measure distance to the closest edge
				var closest_edge = world_position.clamp(frame_rect.position, frame_rect.end)
				distance_outside = world_position.distance_to(closest_edge)

			# Linear dB falloff with distance
			var dist_t = clamp(distance_outside / outside_fade_distance, 0.0, 1.0)
			var spatial_db = -max_outside_attenuation_db * dist_t

			# 3. APPLY BOTH FACTORS WITH BASE VOLUME AND OFFSET
			p2d.volume_db = zoom_db + spatial_db + base_vol + volume_offset_db
			p2d.attenuation = 0.0
			p2d.max_distance = 100000.0 # very large so it never cuts abruptly
		else:
			p2d.attenuation = 0.0
			p2d.volume_db = base_vol + volume_offset_db

		player = p2d
	else:
		var p := AudioStreamPlayer.new()
		p.volume_db = base_vol + volume_offset_db
		player = p

	player.stream = stream
	if pitch_variation > 0.0:
		player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player
