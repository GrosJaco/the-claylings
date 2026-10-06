extends TextureButton
class_name SoldierSelectButton

# ========== EXPORTS ==========

@export_enum("melee", "ranged") var soldier_type: String = "melee"
@export var melee_icon_texture: Texture2D
@export var ranged_icon_texture: Texture2D

# ========== REFERENCES ==========

@onready var icon: TextureRect = get_node_or_null("Icon")

# ========== VARIABLES ==========

var _check_timer: float = 0.0

# ========== FUNCTIONS ==========

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	pressed.connect(_on_pressed)

	_setup_textures()
	_update_state()

func _setup_textures() -> void:
	var ui_icons_texture = preload("res://Art/UI/UIIcons.png")
	if melee_icon_texture == null:
		var atlas = AtlasTexture.new()
		atlas.atlas = ui_icons_texture
		atlas.region = Rect2(0, 32, 16, 16)
		melee_icon_texture = atlas

	if ranged_icon_texture == null:
		var atlas = AtlasTexture.new()
		atlas.atlas = ui_icons_texture
		atlas.region = Rect2(16, 32, 16, 16)
		ranged_icon_texture = atlas

	if icon:
		if soldier_type == "melee":
			icon.texture = melee_icon_texture
		else:
			icon.texture = ranged_icon_texture

func _process(delta: float) -> void:
	_check_timer += delta
	if _check_timer < 0.2:
		return
	_check_timer = 0.0
	_update_state()

func _get_ready_soldiers() -> Array:
	var result: Array = []
	var all_soldiers = get_tree().get_nodes_in_group("soldiers")
	for s in all_soldiers:
		if is_instance_valid(s) and not s.get("is_dead") and s.get("is_combat_ready"):
			var r = s.get("role")
			if soldier_type == "melee":
				if r != "archer" and r != "villager":
					result.append(s)
			elif soldier_type == "ranged":
				if r == "archer":
					result.append(s)
	return result

func _update_state() -> void:
	var ready_soldiers = _get_ready_soldiers()
	var count = ready_soldiers.size()
	var has_soldiers = count > 0

	disabled = not has_soldiers

	if has_soldiers:
		self_modulate = Color(1.0, 1.0, 1.0, 1.0)
		if icon:
			icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if soldier_type == "melee":
			tooltip_text = "Select Melee Soldiers (%d)" % count
		else:
			tooltip_text = "Select Ranged Soldiers (%d)" % count
	else:
		self_modulate = Color(0.4, 0.4, 0.4, 0.6)
		if icon:
			icon.modulate = Color(0.4, 0.4, 0.4, 0.6)
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		if soldier_type == "melee":
			tooltip_text = "No melee soldiers ready"
		else:
			tooltip_text = "No ranged soldiers ready"

func _on_pressed() -> void:
	var rts = get_tree().get_first_node_in_group("rts_controller")
	if not rts:
		return

	var add_to_selection = Input.is_key_pressed(KEY_SHIFT)
	if soldier_type == "melee":
		if rts.has_method("select_all_melee_soldiers"):
			rts.select_all_melee_soldiers(add_to_selection)
	elif soldier_type == "ranged":
		if rts.has_method("select_all_ranged_soldiers"):
			rts.select_all_ranged_soldiers(add_to_selection)
