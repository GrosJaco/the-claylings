extends TextureButton
class_name DemolishButton

# ========== EXPORTS ==========

@export var trash_icon_texture: Texture2D

# ========== REFERENCES ==========

@onready var icon: TextureRect = get_node_or_null("Icon")

# ========== FUNCTIONS ==========

func _ready() -> void:
	add_to_group("demolish_button")
	focus_mode = Control.FOCUS_NONE
	pressed.connect(_on_pressed)

	_setup_textures()
	_update_display(false)
	call_deferred("_connect_signals")

func _setup_textures() -> void:
	if trash_icon_texture == null:
		var ui_icons = preload("res://Art/UI/UIIcons.png")
		var atlas = AtlasTexture.new()
		atlas.atlas = ui_icons
		atlas.region = Rect2(32, 16, 16, 16)
		trash_icon_texture = atlas

	if icon and trash_icon_texture:
		icon.texture = trash_icon_texture

func _connect_signals() -> void:
	var rts = get_tree().get_first_node_in_group("rts_controller")
	if rts and rts.has_signal("demolish_mode_changed"):
		if not rts.demolish_mode_changed.is_connected(_on_demolish_mode_changed):
			rts.demolish_mode_changed.connect(_on_demolish_mode_changed)
		_update_display(rts.is_demolish_mode)

func _on_pressed() -> void:
	var rts = get_tree().get_first_node_in_group("rts_controller")
	if not rts:
		return

	var will_be_active = not rts.is_demolish_mode

	# Close any other open UI panels or placement previews when entering demolish mode
	if will_be_active:
		if UIPanelManager and UIPanelManager.has_method("close_current_panel"):
			UIPanelManager.close_current_panel()
		var bm = get_tree().get_first_node_in_group("building_manager")
		if bm and bm.has_method("cancel_preview"):
			bm.cancel_preview()

	rts.set_demolish_mode(will_be_active)

func _on_demolish_mode_changed(active: bool) -> void:
	_update_display(active)

func _update_display(active: bool) -> void:
	if active:
		self_modulate = Color(0.55, 0.55, 0.55, 1.0)
		if icon:
			icon.modulate = Color(1.0, 0.45, 0.45, 1.0)
		tooltip_text = "Demolish Mode Active (Right-click to cancel)"
	else:
		self_modulate = Color.WHITE
		if icon:
			icon.modulate = Color.WHITE
		tooltip_text = "Demolish Buildings"
