extends PanelContainer
class_name TutorialUI

# ========== REFERENCES ==========

@onready var manager: TutorialManager = $TutorialManager
@onready var title_label: Label = $MarginContainer/VBoxContainer/Header/TitleLabel
@onready var minimize_button: Button = $MarginContainer/VBoxContainer/Header/MinimizeButton
@onready var skip_button: Button = $MarginContainer/VBoxContainer/Header/SkipButton
@onready var content_container: VBoxContainer = $MarginContainer/VBoxContainer/ContentContainer
@onready var description_label: RichTextLabel = $MarginContainer/VBoxContainer/ContentContainer/DescriptionLabel
@onready var objectives_container: VBoxContainer = $MarginContainer/VBoxContainer/ContentContainer/ObjectivesContainer

# ========== TYPEWRITER STATE ==========

var _typewriter_progress: float = 0.0
var _is_typing: bool = false
var _chars_per_sec: float = 42.0
var _sound_counter: int = 0

# ========== HUD PULSE STATE ==========

var _current_pulsed_control: Control = null
var _pulse_tween: Tween = null
var _is_minimized: bool = false

# ========== FUNCTIONS ==========

func _ready() -> void:
	add_to_group("tutorial_ui")
	
	minimize_button.pressed.connect(_on_minimize_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	gui_input.connect(_on_gui_input)

	manager.step_changed.connect(_on_step_changed)
	manager.objective_updated.connect(_on_objective_updated)
	manager.step_completed.connect(_on_step_completed)
	manager.tutorial_finished.connect(_on_tutorial_finished)

	if manager.is_completed:
		visible = false
	else:
		_load_current_step()

func _process(delta: float) -> void:
	if _is_typing:
		_typewriter_progress += delta * _chars_per_sec
		var target_chars = int(_typewriter_progress)
		
		if target_chars > description_label.visible_characters:
			var total = description_label.get_total_character_count()
			description_label.visible_characters = mini(target_chars, total)
			
			_sound_counter += 1
			if _sound_counter % 3 == 0:
				var sm = get_node_or_null("/root/SoundManager")
				if sm and sm.has_method("play"):
					sm.play("pop", 0.4, -22.0)
					
			if description_label.visible_characters >= total:
				_finish_typing()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_typing:
			_finish_typing()
			accept_event()

func _finish_typing() -> void:
	_is_typing = false
	description_label.visible_characters = -1

# ========== STEP PRESENTATION ==========

func _load_current_step() -> void:
	if manager.current_step_index < 0 or manager.current_step_index >= manager.steps.size():
		return
	_display_step(manager.current_step_index, manager.steps[manager.current_step_index])

func _on_step_changed(step_index: int, step_data: Dictionary) -> void:
	_display_step(step_index, step_data)

func _display_step(step_index: int, step_data: Dictionary) -> void:
	visible = true
	title_label.text = step_data.get("title", "TUTORIAL")
	
	var is_completion = step_data.get("id", "") == "completion"
	if is_completion:
		skip_button.text = "✓"
		skip_button.tooltip_text = "Close Tutorial"
		minimize_button.visible = false
	else:
		skip_button.text = "✕"
		skip_button.tooltip_text = "Skip Tutorial"
		minimize_button.visible = true

	var desc_text = step_data.get("description", "")
	description_label.text = desc_text
	
	if _is_minimized:
		content_container.visible = false
		minimize_button.text = "+"
		description_label.visible_characters = -1
		_is_typing = false
	else:
		content_container.visible = true
		minimize_button.text = "-"
		description_label.visible_characters = 0
		_typewriter_progress = 0.0
		_sound_counter = 0
		_is_typing = true

	_rebuild_objectives(step_data.get("objectives", []))
	_update_hud_highlight(step_data.get("hud_highlight", ""))
	call_deferred("reset_size")

func _rebuild_objectives(objectives: Array) -> void:
	for child in objectives_container.get_children():
		child.queue_free()

	for obj in objectives:
		var label = RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("normal_font_size", 14)
		label.add_theme_font_size_override("bold_font_size", 14)
		
		_render_objective_label(label, obj)
		objectives_container.add_child(label)

func _render_objective_label(label: RichTextLabel, obj: Dictionary) -> void:
	var done: bool = obj.get("completed", false)
	var text: String = obj.get("text", "")
	var target: int = obj.get("target", 1)
	var current: int = obj.get("current", 0)

	var icon_str = "[color=#70d440]✓[/color] " if done else "[color=#999999]○[/color] "
	var count_str = ""
	if target > 1:
		count_str = " (%d/%d)" % [current, target]
	
	if done:
		label.text = "%s[color=#c8e6c9]%s%s[/color]" % [icon_str, text, count_str]
	else:
		label.text = "%s%s%s" % [icon_str, text, count_str]

func _on_objective_updated(_step_idx: int, obj_idx: int, current: int, target: int, completed: bool) -> void:
	if obj_idx >= 0 and obj_idx < objectives_container.get_child_count():
		var label = objectives_container.get_child(obj_idx) as RichTextLabel
		if label and _step_idx >= 0 and _step_idx < manager.steps.size():
			var step = manager.steps[_step_idx]
			var objectives = step.get("objectives", [])
			if obj_idx < objectives.size():
				var obj = objectives[obj_idx]
				obj["current"] = current
				obj["target"] = target
				obj["completed"] = completed
				_render_objective_label(label, obj)

func _on_step_completed(_step_idx: int) -> void:
	var sm = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play"):
		sm.play("crystal hit1", 0.1, -10.0)

func _on_tutorial_finished() -> void:
	_stop_hud_pulse()
	visible = false

# ========== HUD PULSING ==========

func _update_hud_highlight(highlight_id: String) -> void:
	_stop_hud_pulse()
	if highlight_id == "":
		return

	var target: Control = null
	match highlight_id:
		"harvest_zone_button":
			target = get_tree().get_first_node_in_group("harvest_zone_button") as Control
			if not target:
				var hud = get_tree().get_first_node_in_group("hud_controller")
				if hud and "harvest_zone_button" in hud:
					target = hud.harvest_zone_button
		"build_menu":
			var hud = get_tree().get_first_node_in_group("hud_controller")
			if hud and "build_menu" in hud and hud.build_menu:
				target = hud.build_menu.get_node_or_null("ToggleButton")
		"plant_menu":
			var hud = get_tree().get_first_node_in_group("hud_controller")
			if hud and "plant_menu" in hud and hud.plant_menu:
				target = hud.plant_menu.get_node_or_null("ToggleButton")
		"call_to_arms_button":
			target = get_tree().get_first_node_in_group("call_to_arms_button") as Control

	if target and is_instance_valid(target):
		_start_hud_pulse(target)

func _start_hud_pulse(ctrl: Control) -> void:
	_current_pulsed_control = ctrl
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(ctrl, "modulate", Color(1.35, 1.35, 0.75, 1.0), 0.55).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(ctrl, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.55).set_trans(Tween.TRANS_SINE)

func _stop_hud_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
	if _current_pulsed_control and is_instance_valid(_current_pulsed_control):
		_current_pulsed_control.modulate = Color.WHITE
		_current_pulsed_control = null

# ========== MINIMIZE & SKIP ==========

func _on_minimize_pressed() -> void:
	_is_minimized = not _is_minimized
	content_container.visible = not _is_minimized
	minimize_button.text = "+" if _is_minimized else "-"
	if not _is_minimized:
		description_label.visible_characters = -1
		_is_typing = false
	call_deferred("reset_size")

func _on_skip_pressed() -> void:
	manager.skip_tutorial()

func show_tutorial() -> void:
	visible = true
	_is_minimized = false
	if content_container:
		content_container.visible = true
	if minimize_button:
		minimize_button.text = "-"
	if manager:
		manager.is_completed = false
		_load_current_step()
	call_deferred("reset_size")

func hide_tutorial() -> void:
	visible = false
