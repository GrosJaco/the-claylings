extends Control
class_name ClaylingInfoUI

# ========== REFERENCES ==========

@onready var portrait_rect: TextureRect = $Portrait
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var personality_label: Label = $VBoxContainer/PersonalityLabel
@onready var age_label: Label = $VBoxContainer/AgeLabel
@onready var health_bar: TextureProgressBar = $BarsContainer/HealthBar
@onready var energy_bar: TextureProgressBar = $BarsContainer/EnergyBar
@onready var hunger_bar: TextureProgressBar = $BarsContainer/HungerBar

# ========== VARIABLES ==========

@export var personality_portraits: Dictionary = {}
@export var default_portrait: Texture2D

var tracked_clayling: CharacterBody2D = null

# ========== FUNCTIONS ==========

func _ready():
	add_to_group("clayling_info_panel")
	visible = false
	
	portrait_rect.custom_minimum_size = Vector2(96, 96)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	_style_texture_bar(health_bar)
	_style_texture_bar(energy_bar)
	_style_texture_bar(hunger_bar)

func _process(_delta: float) -> void:
	if not visible: return
	if is_instance_valid(tracked_clayling):
		_refresh_bars()
	else:
		hide_panel()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if get_global_rect().has_point(event.position):
			hide_panel()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		hide_panel()
		get_viewport().set_input_as_handled()

# ---------- PUBLIC API ----------

func show_clayling(clayling: CharacterBody2D) -> void:
	tracked_clayling = clayling
	
	portrait_rect.texture = personality_portraits.get(clayling.personality_trait, default_portrait)
	
	name_label.text = clayling.clayling_name 
	personality_label.text = clayling.personality_trait + " • " + clayling.role.capitalize() + "\n" + _get_activity_text(clayling)
	age_label.text = str(clayling.age) + " y/o"
	
	_refresh_bars()
	visible = true

func open(clayling: CharacterBody2D) -> void:
	show_clayling(clayling)

func hide_panel() -> void:
	visible = false
	tracked_clayling = null

# ---------- INTERNAL ----------

func _refresh_bars() -> void:
	health_bar.max_value = tracked_clayling.max_health
	health_bar.value = tracked_clayling.health
	
	energy_bar.max_value = tracked_clayling.max_energy
	energy_bar.value = tracked_clayling.energy
	
	hunger_bar.max_value = tracked_clayling.max_hunger
	hunger_bar.value = tracked_clayling.hunger

	personality_label.text = tracked_clayling.personality_trait + " • " + tracked_clayling.role.capitalize() + "\n" + _get_activity_text(tracked_clayling)

func _get_activity_text(c: CharacterBody2D) -> String:
	if not is_instance_valid(c) or c.get("is_dead"):
		return "Deceased"
	if not ("current_state" in c) or c.current_state == null:
		return "Idle"
	for state_name in c.states.keys():
		if c.states[state_name] == c.current_state:
			match state_name:
				"Idle": return "Idle"
				"Wander": return "Wandering"
				"Move": return "Moving"
				"Chop": return "Chopping Wood"
				"Mine": return "Mining"
				"Forage": return "Foraging"
				"Harvest": return "Harvesting Crops"
				"Water": return "Watering Soil"
				"Plant": return "Planting Seeds"
				"Haul": return "Hauling to Storage"
				"Pick up": return "Picking up Item"
				"Deliver": return "Delivering Materials"
				"Construct": return "Constructing"
				"ConstructDelivery": return "Supplying Construction"
				"Work": return "Working Station"
				"CollectOutput": return "Collecting Output"
				"Eat": return "Eating"
				"Equip": return "Equipping"
				"Unequip": return "Unequipping"
				"SoldierMove": return "Moving"
				"SoldierAttack": return "Attacking"
				"SoldierStance", "SoldierToStance": return "In Formation"
				"SoldierIdle": return "Guarding"
				"Flee": return "Fleeing!"
				_: return state_name
	return "Idle"

func _style_texture_bar(bar: TextureProgressBar) -> void:
	bar.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
