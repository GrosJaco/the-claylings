extends Control
class_name DefeatUI

# ========== SIGNALS ==========

signal defeat_shown

@onready var dark_overlay: ColorRect = $DarkOverlay
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $VBoxContainer/SubtitleLabel
@onready var restart_button: Button = $VBoxContainer/RestartButton

var _is_active: bool = false
var _is_restarting: bool = false

# ========== FUNCTIONS ==========

func _ready() -> void:
	visible = false
	process_mode = PROCESS_MODE_ALWAYS
	add_to_group("defeat_ui")
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dark_overlay:
		dark_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if restart_button:
		restart_button.pressed.connect(_restart_game)

	call_deferred("_connect_signals")

func _connect_signals() -> void:
	var manager = get_tree().get_first_node_in_group("building_manager")
	if manager and manager.has_signal("initial_crystal_placed"):
		manager.initial_crystal_placed.connect(_on_crystal_placed)

	# In case a non-preview crystal is already in the tree
	var crystals = get_tree().get_nodes_in_group("crystal")
	for c in crystals:
		_on_crystal_placed(c)

func _on_crystal_placed(crystal_node: Node2D) -> void:
	if crystal_node and is_instance_valid(crystal_node) and not crystal_node.get("is_preview"):
		if crystal_node.has_signal("crystal_destroyed"):
			if not crystal_node.crystal_destroyed.is_connected(show_defeat):
				crystal_node.crystal_destroyed.connect(show_defeat)

func show_defeat() -> void:
	if _is_active:
		return
	_is_active = true

	defeat_shown.emit()

	visible = true
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	if dark_overlay:
		dark_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 1.0, 0.8)

	if restart_button:
		restart_button.grab_focus()

func reset_defeat() -> void:
	_is_active = false
	_is_restarting = false
	visible = false
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dark_overlay:
		dark_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	if not _is_active or _is_restarting:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if is_inside_tree():
			var vp = get_viewport()
			if vp:
				vp.set_input_as_handled()
		_restart_game()

func _restart_game() -> void:
	if _is_restarting:
		return
	_is_restarting = true
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
