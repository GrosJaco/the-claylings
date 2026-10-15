extends Building
class_name TreeBuilding

# ========== VARIABLES ==========

@export_group("Harvesting")
@export var harvest_group: String = "trees"
var is_marked_for_harvest: bool = false
var original_modulate: Color = Color.WHITE

@export_group("Resources")
@export var wood_item: ItemData # The resource that will drop
@export var min_drop: int = 2
@export var max_drop: int = 5

@export_group("Visual Variations")
@export var possible_sprites: Array[Texture2D] = []

# ========== FUNCTIONS ==========

func _ready():
	add_to_group(harvest_group) # Setup specific tree group BEFORE calling super
	super._ready() # Call parent _ready (initializes health, etc.)
	_apply_random_visuals() # Apply visual variation

func take_damage(amount: int):
	super.take_damage(amount)
	_play_shake_effect()

func destroyed():
	SoundManager.play_at("tree fall", global_position, 0.1)
	_drop_resources()
	var tm = get_tree().get_first_node_in_group("tutorial_manager")
	if tm and tm.has_method("notify_tree_felled"):
		tm.notify_tree_felled()
	super.destroyed()

# ---------- HARVEST SYSTEM ----------

# Called dynamically by the harvest zone during drag/resize
func set_highlight(active: bool) -> void:
	if sprite:
		if active:
			sprite.modulate = original_modulate * 1.5 # Brighten
		else:
			sprite.modulate = original_modulate # Reset to original color

# ---------- HELPERS ----------

func _apply_random_visuals():
	if possible_sprites.size() > 0:
		var random_tex = possible_sprites.pick_random()
		
		if sprite is Sprite2D:
			sprite.texture = random_tex
			sprite.flip_h = (randi() % 2 == 0) # Random horizontal flip
			# Save the random color so we can restore it after highlighting
			original_modulate = Color(randf_range(0.8, 1.0), randf_range(0.8, 1.0), randf_range(0.8, 1.0))
			sprite.modulate = original_modulate

func _play_shake_effect():
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "rotation_degrees", 5, 0.05)
		tween.tween_property(sprite, "rotation_degrees", -5, 0.05)
		tween.tween_property(sprite, "rotation_degrees", 0, 0.05)

func _drop_resources():
	if wood_item == null: return
	var amount = randi_range(min_drop, max_drop)
	var parent_node = get_parent() 
	
	for i in range(amount):
		var item = load("res://Scenes/item.tscn").instantiate()
		item.data = wood_item
		item.quantity = 1
		var offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
		item.global_position = global_position + offset
		parent_node.call_deferred("add_child", item)
