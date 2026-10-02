extends TextureButton
class_name CallToArmsButton

# ========== EXPORTS ==========

@export var bell_texture: Texture2D
@export var crossed_bell_texture: Texture2D
@export var arm_tooltip: String = "Call to Arms (X)"
@export var work_tooltip: String = "Call to Work (Z)"

# ========== REFERENCES ==========

@onready var icon: TextureRect = get_node_or_null("Icon")

# ========== VARIABLES ==========

var is_armed: bool = false
var _check_timer: float = 0.0

# ========== FUNCTIONS ==========

func _ready() -> void:
	add_to_group("call_to_arms_button")
	focus_mode = Control.FOCUS_NONE
	pressed.connect(_on_pressed)

	_setup_default_textures()
	_update_display()
	call_deferred("_connect_signals")

func _setup_default_textures() -> void:
	var ui_icons_texture = preload("res://Art/UI/UIIcons.png")
	if bell_texture == null:
		var atlas = AtlasTexture.new()
		atlas.atlas = ui_icons_texture
		atlas.region = Rect2(0, 16, 16, 16)
		bell_texture = atlas

	if crossed_bell_texture == null:
		var atlas = AtlasTexture.new()
		atlas.atlas = ui_icons_texture
		atlas.region = Rect2(16, 16, 16, 16)
		crossed_bell_texture = atlas

func _connect_signals() -> void:
	var rts = get_tree().get_first_node_in_group("rts_controller")
	if rts:
		if not rts.call_to_arms_triggered.is_connected(_on_rts_call_to_arms):
			rts.call_to_arms_triggered.connect(_on_rts_call_to_arms)
		if not rts.call_to_work_triggered.is_connected(_on_rts_call_to_work):
			rts.call_to_work_triggered.connect(_on_rts_call_to_work)

func _process(delta: float) -> void:
	if not is_armed:
		return

	_check_timer += delta
	if _check_timer < 0.5:
		return
	_check_timer = 0.0

	# Automatically reset to Call to Arms mode when no soldiers remain active or equipping
	if not _has_active_soldiers_or_equipping():
		set_armed(false)

func _has_active_soldiers_or_equipping() -> bool:
	var soldiers = get_tree().get_nodes_in_group("soldiers")
	for s in soldiers:
		if is_instance_valid(s) and not s.get("is_dead") and s.get("is_combat_ready"):
			return true

	var claylings = get_tree().get_nodes_in_group("claylings")
	for c in claylings:
		if is_instance_valid(c) and not c.get("is_dead"):
			if "current_state" in c and "states" in c and c.current_state == c.states.get("Equip"):
				return true
	return false

func _on_pressed() -> void:
	var main_node = get_tree().get_first_node_in_group("main")
	var rts_node = get_tree().get_first_node_in_group("rts_controller")

	if not is_armed:
		if main_node and main_node.has_method("trigger_call_to_arms"):
			main_node.trigger_call_to_arms()
		elif rts_node and rts_node.has_method("trigger_call_to_arms"):
			rts_node.trigger_call_to_arms()
		set_armed(true)
	else:
		if main_node and main_node.has_method("trigger_call_to_work"):
			main_node.trigger_call_to_work()
		elif rts_node and rts_node.has_method("trigger_call_to_work"):
			rts_node.trigger_call_to_work()
		set_armed(false)

func _on_rts_call_to_arms() -> void:
	set_armed(true)

func _on_rts_call_to_work() -> void:
	set_armed(false)

func set_armed(armed: bool) -> void:
	is_armed = armed
	_update_display()

func _update_display() -> void:
	if not is_armed:
		tooltip_text = arm_tooltip
		if icon:
			icon.texture = bell_texture
	else:
		tooltip_text = work_tooltip
		if icon:
			icon.texture = crossed_bell_texture
