extends Control
class_name OffscreenThreatIndicators

# ========== EXPORTS ==========

@export var dot_color: Color = Color8(255, 51, 51, 255)
@export var dot_border_color: Color = Color(0.1, 0.02, 0.02, 0.9)
@export var dot_radius: float = 5.5
@export var border_thickness: float = 1.5
@export var screen_margin: float = 20.0
@export var pulse_speed: float = 4.0

# ========== STATE ==========

var _offscreen_positions: Array[Vector2] = []
var _pulse_timer: float = 0.0

# ========== FUNCTIONS ==========

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	_pulse_timer += delta * pulse_speed
	_calculate_offscreen_indicators()
	queue_redraw()

func _calculate_offscreen_indicators() -> void:
	_offscreen_positions.clear()

	var crystal = get_tree().get_first_node_in_group("central_crystal")
	if not is_instance_valid(crystal) or crystal.get("is_preview"):
		return

	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	var vp = get_viewport()
	if not vp:
		return

	var canvas_transform = vp.get_canvas_transform()
	var vp_size = vp.get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return

	var screen_center = vp_size * 0.5
	var half_w = max(1.0, (vp_size.x * 0.5) - screen_margin)
	var half_h = max(1.0, (vp_size.y * 0.5) - screen_margin)
	var view_padding = 16.0

	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.get("is_dead"):
			continue

		var screen_pos = canvas_transform * enemy.global_position

		# Skip enemies that are currently within the visible viewport
		if screen_pos.x >= -view_padding and screen_pos.x <= vp_size.x + view_padding \
		and screen_pos.y >= -view_padding and screen_pos.y <= vp_size.y + view_padding:
			continue

		var diff = screen_pos - screen_center
		if diff == Vector2.ZERO:
			continue

		# Ray-box intersection to project to the nearest screen edge
		var scale_x = half_w / abs(diff.x) if abs(diff.x) > 0.0001 else INF
		var scale_y = half_h / abs(diff.y) if abs(diff.y) > 0.0001 else INF
		var edge_scale = min(scale_x, scale_y)

		var edge_pos = screen_center + (diff * edge_scale)
		_offscreen_positions.append(edge_pos)

func _draw() -> void:
	if _offscreen_positions.is_empty():
		return

	var pulse = 0.85 + 0.15 * sin(_pulse_timer)
	var current_color = Color(dot_color.r, dot_color.g, dot_color.b, dot_color.a * pulse)

	for pos in _offscreen_positions:
		# Dark protective outer outline for contrast
		draw_circle(pos, dot_radius + border_thickness, dot_border_color)
		draw_circle(pos, dot_radius, current_color)
