extends Node

var sounds: Dictionary = {
	"chop": preload("res://Audio/SFX/chop.wav"),
	"tree fall": preload("res://Audio/SFX/tree_fall.wav"),
	"rock hit": preload("res://Audio/SFX/rock_hit.wav"),
	"rock break": preload("res://Audio/SFX/rock_break.wav"),
	"grass": preload("res://Audio/SFX/grass.wav"),
	"furnace": preload("res://Audio/SFX/furnace.wav"),
	"thunder": preload("res://Audio/SFX/thunder_strike.wav"),
	}

@export_group("Spatial Audio")
@export var outside_fade_distance: float = 500.0
# Total volume drop (in dB) once a sound is outside_fade_distance away from the frame edge
@export var max_outside_attenuation_db: float = 40.0
# Camera zoom value at which sounds play at full volume (your "normal"/zoomed-in reference)
@export var zoom_reference: float = 4.0
# Camera zoom value at which sounds are fully muted (your camera's max dezoom / zoom_min)
@export var zoom_out_silence: float = 0.5

func play(sound_name: String, pitch_variation: float = 0.0) -> void:
	_spawn_player(sound_name, pitch_variation, null)

func play_at(sound_name: String, world_position: Vector2, pitch_variation: float = 0.0) -> void:
	_spawn_player(sound_name, pitch_variation, world_position)

func _spawn_player(sound_name: String, pitch_variation: float, world_position) -> void:
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

			# 3. APPLY BOTH FACTORS
			p2d.volume_db = zoom_db + spatial_db
			p2d.attenuation = 0.0
			p2d.max_distance = 100000.0 # very large so it never cuts abruptly
		else:
			p2d.attenuation = 0.0

		player = p2d
	else:
		player = AudioStreamPlayer.new()

	player.stream = sounds[sound_name]
	if pitch_variation > 0.0:
		player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
