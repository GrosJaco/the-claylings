extends Building
class_name RockBuilding

# ========== VARIABLES ==========

# ---------- HARVESTING ----------

@export_group("Harvesting")
@export var harvest_group: String = "rocks" 
var is_marked_for_harvest: bool = false
var original_modulate: Color = Color.WHITE

# ---------- RESOURCES ----------

@export_group("Resources")
@export var resource_item: ItemData 
@export var min_drop: int = 2
@export var max_drop: int = 4

# ---------- VISUALS ----------

@export_group("Visual Variations")
@export var possible_sprites: Array[Texture2D] = []

# ========== FUNCTIONS ==========

# ---------- GENERAL ----------

func _ready():
	add_to_group(harvest_group) 
	super._ready() 
	_apply_random_visuals()

# ---------- LOGIC ----------

func take_damage(amount: int):
	super.take_damage(amount)
	_play_shake_effect()

func destroyed():
	SoundManager.play_at("rock break", global_position, 0.3)
	_drop_resources()
	super.destroyed()

# ---------- HARVEST SYSTEM ----------

func set_highlight(active: bool) -> void:
	if sprite:
		sprite.modulate = (original_modulate * 1.5) if active else original_modulate

# ---------- HELPERS ----------

func _apply_random_visuals():
	if possible_sprites.size() > 0:
		var random_tex = possible_sprites.pick_random()
		
		if sprite is Sprite2D:
			sprite.texture = random_tex
			sprite.flip_h = (randi() % 2 == 0) 
			
			original_modulate = Color(randf_range(0.98, 1.0), randf_range(0.98, 1.0), randf_range(0.98, 1.0))
			sprite.modulate = original_modulate

func _play_shake_effect():
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "offset", Vector2(2, 0), 0.03)
		tween.tween_property(sprite, "offset", Vector2(-2, 0), 0.03)
		tween.tween_property(sprite, "offset", Vector2(0, 0), 0.03)

func _drop_resources():
	if resource_item == null:
		return
		
	var amount = randi_range(min_drop, max_drop)
	var parent_node = get_parent()
	
	for i in range(amount):
		var item = load("res://Scenes/item.tscn").instantiate()
		item.data = resource_item
		item.quantity = 1
		var offset = Vector2(randf_range(-5, 5), randf_range(-5, 5))
		item.global_position = global_position + offset
		parent_node.call_deferred("add_child", item)
