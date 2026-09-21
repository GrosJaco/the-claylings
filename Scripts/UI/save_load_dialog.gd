extends Control
class_name SaveLoadDialog

# ========== ENUMS & SIGNALS ==========

enum Mode { SAVE, LOAD }

signal save_confirmed(slot_name: String)
signal load_confirmed(slot_name: String)
signal cancelled

# ========== REFERENCES ==========

@onready var dark_overlay: ColorRect = $DarkOverlay
@onready var panel_container: PanelContainer = $PanelContainer

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var scroll_container: ScrollContainer = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer
@onready var save_list_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/SaveListContainer
@onready var empty_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/EmptyLabel

@onready var input_section: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/InputSection
@onready var name_input: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/InputSection/NameInput

@onready var primary_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ActionButtons/PrimaryButton
@onready var delete_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ActionButtons/DeleteButton
@onready var cancel_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ActionButtons/CancelButton

# ========== STYLES FOR LIST ITEMS ==========

var _btn_normal_style: StyleBoxFlat
var _btn_hover_style: StyleBoxFlat
var _btn_selected_style: StyleBoxFlat

# ========== STATE ==========

var current_mode: Mode = Mode.SAVE
var selected_slot: String = ""
var _cached_slots: Array[String] = []

# ========== INITIALIZATION ==========

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_styles()

	if primary_button:
		primary_button.pressed.connect(_on_primary_pressed)
	if delete_button:
		delete_button.pressed.connect(_on_delete_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)

	if name_input:
		name_input.text_changed.connect(_on_name_input_changed)
		name_input.text_submitted.connect(func(_text): _on_primary_pressed())

func _setup_styles() -> void:
	# Standard item style
	_btn_normal_style = StyleBoxFlat.new()
	_btn_normal_style.bg_color = Color(0.14, 0.14, 0.18, 0.85)
	_btn_normal_style.set_border_width_all(1)
	_btn_normal_style.border_color = Color(0.35, 0.35, 0.42, 0.8)
	_btn_normal_style.set_corner_radius_all(2)
	_btn_normal_style.content_margin_left = 10
	_btn_normal_style.content_margin_right = 10
	_btn_normal_style.content_margin_top = 6
	_btn_normal_style.content_margin_bottom = 6

	# Hover item style
	_btn_hover_style = _btn_normal_style.duplicate()
	_btn_hover_style.bg_color = Color(0.24, 0.24, 0.3, 0.95)
	_btn_hover_style.border_color = Color(0.65, 0.65, 0.75, 1.0)

	# Selected item style
	_btn_selected_style = _btn_normal_style.duplicate()
	_btn_selected_style.bg_color = Color(0.28, 0.28, 0.36, 1.0)
	_btn_selected_style.set_border_width_all(2)
	_btn_selected_style.border_color = Color(0.85, 0.85, 0.95, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_cancel_pressed()
			get_viewport().set_input_as_handled()

# ========== DIALOG OPEN / CLOSE ==========

func open_save_dialog() -> void:
	current_mode = Mode.SAVE
	title_label.text = "SAVE GAME"
	input_section.visible = true
	delete_button.visible = false
	selected_slot = ""
	name_input.text = ""
	
	_refresh_save_list()
	_update_buttons()
	_show()
	name_input.grab_focus()

func open_load_dialog() -> void:
	current_mode = Mode.LOAD
	title_label.text = "LOAD GAME"
	input_section.visible = false
	delete_button.visible = true
	selected_slot = ""
	
	_refresh_save_list()
	_update_buttons()
	_show()

func _show() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if dark_overlay:
		dark_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dark_overlay:
		dark_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cancelled.emit()

# ========== LIST POPULATION ==========

func _refresh_save_list() -> void:
	for child in save_list_container.get_children():
		child.queue_free()

	_cached_slots.clear()

	var save_mgr = get_node_or_null("/root/SaveManager")
	var saves: Array[Dictionary] = []
	if save_mgr and save_mgr.has_method("get_all_saves_metadata"):
		saves = save_mgr.get_all_saves_metadata()
	elif save_mgr and save_mgr.has_method("get_save_slots"):
		for s in save_mgr.get_save_slots():
			saves.append({"slot_name": s, "timestamp": "", "day": 1})

	empty_label.visible = saves.is_empty()

	for entry in saves:
		var slot = str(entry.get("slot_name", ""))
		_cached_slots.append(slot)
		var btn = _create_slot_button(entry)
		save_list_container.add_child(btn)

func _create_slot_button(entry: Dictionary) -> Button:
	var slot = str(entry.get("slot_name", ""))
	var day = int(entry.get("day", 1))
	var raw_time = str(entry.get("timestamp", ""))

	# Format clean timestamp (YYYY-MM-DD HH:MM)
	var formatted_time = ""
	if raw_time.length() >= 16:
		formatted_time = raw_time.substr(0, 10) + " " + raw_time.substr(11, 5)

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 36)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_slot_button_style(btn, slot == selected_slot)

	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.offset_left = 10
	hbox.offset_right = -10

	var name_lbl = Label.new()
	name_lbl.text = slot
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98, 1))

	var info_lbl = Label.new()
	var info_str = "Day %d" % day
	if formatted_time != "":
		info_str += " • " + formatted_time
	info_lbl.text = info_str
	info_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_lbl.add_theme_font_size_override("font_size", 13)
	info_lbl.add_theme_color_override("font_color", Color(0.68, 0.68, 0.74, 1))

	hbox.add_child(name_lbl)
	hbox.add_child(info_lbl)
	btn.add_child(hbox)

	btn.pressed.connect(func(): _on_slot_clicked(slot))
	return btn

func _apply_slot_button_style(btn: Button, is_selected: bool) -> void:
	if is_selected:
		btn.add_theme_stylebox_override("normal", _btn_selected_style)
		btn.add_theme_stylebox_override("hover", _btn_selected_style)
		btn.add_theme_stylebox_override("pressed", _btn_selected_style)
	else:
		btn.add_theme_stylebox_override("normal", _btn_normal_style)
		btn.add_theme_stylebox_override("hover", _btn_hover_style)
		btn.add_theme_stylebox_override("pressed", _btn_selected_style)

# ========== SELECTION & INPUT LOGIC ==========

func _on_slot_clicked(slot: String) -> void:
	selected_slot = slot

	if current_mode == Mode.SAVE:
		name_input.text = slot

	# Refresh visual selection highlights
	var children = save_list_container.get_children()
	for i in range(children.size()):
		var child = children[i]
		if child is Button and i < _cached_slots.size():
			_apply_slot_button_style(child, _cached_slots[i] == selected_slot)

	_update_buttons()

func _on_name_input_changed(new_text: String) -> void:
	selected_slot = new_text.strip_edges()
	_update_buttons()

func _update_buttons() -> void:
	if current_mode == Mode.SAVE:
		var raw_name = name_input.text.strip_edges()
		var is_empty_name = raw_name == ""
		var is_existing = _cached_slots.has(raw_name)

		primary_button.disabled = is_empty_name
		primary_button.text = "Overwrite" if is_existing else "Save"
		delete_button.visible = false

	elif current_mode == Mode.LOAD:
		var has_selection = selected_slot != ""
		primary_button.disabled = not has_selection
		primary_button.text = "Load"
		delete_button.visible = true
		delete_button.disabled = not has_selection

# ========== ACTION HANDLERS ==========

func _on_primary_pressed() -> void:
	if current_mode == Mode.SAVE:
		var clean_name = _sanitize_filename(name_input.text.strip_edges())
		if clean_name == "":
			return
		close()
		save_confirmed.emit(clean_name)

	elif current_mode == Mode.LOAD:
		if selected_slot == "":
			return
		var slot_to_load = selected_slot
		close()
		load_confirmed.emit(slot_to_load)

func _on_delete_pressed() -> void:
	if selected_slot == "":
		return
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("delete_save"):
		save_mgr.delete_save(selected_slot)
	selected_slot = ""
	_refresh_save_list()
	_update_buttons()

func _on_cancel_pressed() -> void:
	close()

func _sanitize_filename(fname: String) -> String:
	var invalid_chars = ["/", "\\", "?", "%", "*", ":", "|", "\"", "<", ">", "."]
	var res = fname
	for ch in invalid_chars:
		res = res.replace(ch, "_")
	return res
