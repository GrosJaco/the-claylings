extends Control
class_name WorldCreationDialog

# ========== SIGNALS ==========

signal world_creation_confirmed(settings: Dictionary)
signal cancelled

# ========== REFERENCES ==========

@onready var dark_overlay: ColorRect = $DarkOverlay
@onready var panel_container: PanelContainer = $PanelContainer

@onready var difficulty_option: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/OptionsList/DifficultyRow/DifficultyOption
@onready var seed_input: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/OptionsList/SeedRow/SeedContainer/SeedInput
@onready var random_seed_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/OptionsList/SeedRow/SeedContainer/RandomSeedButton
@onready var size_option: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/OptionsList/SizeRow/SizeOption
@onready var water_option: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/OptionsList/WaterRow/WaterOption
@onready var mountain_option: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/OptionsList/MountainRow/MountainOption
@onready var forest_option: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/OptionsList/ForestRow/ForestOption
@onready var resource_option: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/OptionsList/ResourceRow/ResourceOption

@onready var reset_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ActionButtons/ResetButton
@onready var cancel_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ActionButtons/CancelButton
@onready var start_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ActionButtons/StartButton

# ========== CONSTANTS & PRESETS ==========

const DIFFICULTY_PRESETS = [
	{"id": "wood", "label": "Wood"},
	{"id": "clay", "label": "Clay"},
	{"id": "stone", "label": "Stone"}
]

const SIZE_PRESETS = [
	{"label": "Small", "size": Vector2i(64, 64)},
	{"label": "Medium", "size": Vector2i(128, 128)},
	{"label": "Large", "size": Vector2i(256, 256)}
]

const WATER_PRESETS = [
	{"label": "Low", "threshold": -0.42},
	{"label": "Normal", "threshold": -0.30},
	{"label": "High", "threshold": -0.18}
]

const MOUNTAIN_PRESETS = [
	{"label": "Low", "threshold": 0.42},
	{"label": "Normal", "threshold": 0.30},
	{"label": "High", "threshold": 0.20}
]

const FOREST_PRESETS = [
	{"label": "Sparse", "density": 0.25, "threshold": 0.30},
	{"label": "Normal", "density": 0.40, "threshold": 0.20},
	{"label": "Dense", "density": 0.65, "threshold": 0.12}
]

const RESOURCE_PRESETS = [
	{"label": "Scarce", "multiplier": 0.6},
	{"label": "Normal", "multiplier": 1.0},
	{"label": "Abundant", "multiplier": 1.5}
]

# ========== INITIALIZATION ==========

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	_populate_options()
	_connect_signals()
	reset_to_defaults()

func _populate_options() -> void:
	if difficulty_option:
		difficulty_option.clear()
		for d in DIFFICULTY_PRESETS:
			difficulty_option.add_item(d["label"])

	if size_option:
		size_option.clear()
		for s in SIZE_PRESETS:
			size_option.add_item(s["label"])

	if water_option:
		water_option.clear()
		for w in WATER_PRESETS:
			water_option.add_item(w["label"])

	if mountain_option:
		mountain_option.clear()
		for m in MOUNTAIN_PRESETS:
			mountain_option.add_item(m["label"])

	if forest_option:
		forest_option.clear()
		for f in FOREST_PRESETS:
			forest_option.add_item(f["label"])

	if resource_option:
		resource_option.clear()
		for r in RESOURCE_PRESETS:
			resource_option.add_item(r["label"])

func _connect_signals() -> void:
	if random_seed_button:
		random_seed_button.pressed.connect(randomize_seed)
	if reset_button:
		reset_button.pressed.connect(reset_to_defaults)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	if start_button:
		start_button.pressed.connect(_on_start_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_cancel_pressed()
			get_viewport().set_input_as_handled()

# ========== DIALOG CONTROLS ==========

func open() -> void:
	visible = true
	if seed_input and seed_input.text.strip_edges().is_empty():
		randomize_seed()

func close() -> void:
	visible = false

func randomize_seed() -> void:
	var new_seed = randi() % 1000000000
	if seed_input:
		seed_input.text = str(new_seed)

func reset_to_defaults() -> void:
	if difficulty_option:
		difficulty_option.selected = 1 # Clay
	if size_option:
		size_option.selected = 1 # Medium
	if water_option:
		water_option.selected = 1 # Normal
	if mountain_option:
		mountain_option.selected = 1 # Normal
	if forest_option:
		forest_option.selected = 1 # Normal
	if resource_option:
		resource_option.selected = 1 # Normal
	randomize_seed()

func build_settings_dictionary() -> Dictionary:
	var diff_idx = difficulty_option.selected if difficulty_option else 1
	var size_idx = size_option.selected if size_option else 1
	var water_idx = water_option.selected if water_option else 1
	var mountain_idx = mountain_option.selected if mountain_option else 1
	var forest_idx = forest_option.selected if forest_option else 1
	var res_idx = resource_option.selected if resource_option else 1

	diff_idx = clampi(diff_idx, 0, DIFFICULTY_PRESETS.size() - 1)
	size_idx = clampi(size_idx, 0, SIZE_PRESETS.size() - 1)
	water_idx = clampi(water_idx, 0, WATER_PRESETS.size() - 1)
	mountain_idx = clampi(mountain_idx, 0, MOUNTAIN_PRESETS.size() - 1)
	forest_idx = clampi(forest_idx, 0, FOREST_PRESETS.size() - 1)
	res_idx = clampi(res_idx, 0, RESOURCE_PRESETS.size() - 1)

	var seed_val: int = 0
	var text_seed: String = seed_input.text.strip_edges() if seed_input else ""
	if text_seed.is_empty():
		seed_val = randi()
	elif text_seed.is_valid_int():
		seed_val = int(text_seed)
	else:
		seed_val = abs(text_seed.hash())

	return {
		"difficulty": DIFFICULTY_PRESETS[diff_idx]["id"],
		"seed": seed_val,
		"map_size": SIZE_PRESETS[size_idx]["size"],
		"water_threshold": WATER_PRESETS[water_idx]["threshold"],
		"walls_threshold": MOUNTAIN_PRESETS[mountain_idx]["threshold"],
		"forest_density": FOREST_PRESETS[forest_idx]["density"],
		"forest_threshold": FOREST_PRESETS[forest_idx]["threshold"],
		"grass_density": 0.60,
		"grass_threshold": 0.25,
		"resource_multiplier": RESOURCE_PRESETS[res_idx]["multiplier"]
	}

# ========== EVENT HANDLERS ==========

func _on_start_pressed() -> void:
	var settings = build_settings_dictionary()
	close()
	world_creation_confirmed.emit(settings)

func _on_cancel_pressed() -> void:
	close()
	cancelled.emit()
