extends Node2D
class_name WorldItem

@export var data: ItemData : set = set_data
@export var quantity: int = 1 : set = set_quantity

@onready var sprite: Sprite2D = $Sprite2D
@onready var area: Area2D = $Area2D

var is_fertile: bool = false
var hatch_timer: float = 0.0
var _has_evaluated_fertility: bool = false

func _ready() -> void:
	add_to_group("ground_items")
	_refresh()
	_check_hatching_eligibility()

# When a clayling enters Area2D
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.world.find_nearest_storage_with_space(body.global_position) == null:
		return
	if !body.has_method("pick_item"):
		return
	if data == null or quantity <= 0:
		return
	
	# Check if there is a storage
	if body.world.find_nearest_storage_with_space(body.global_position) == null:
		return
	
	var taken: int = body.pick_item(data, quantity)
	if taken <= 0:
		return
	
	quantity -= taken
	if quantity <= 0:
		queue_free()
	else:
		_refresh()

# Update data
func set_data(v: ItemData) -> void:
	data = v
	_refresh()
	_check_hatching_eligibility()

func set_quantity(v: int) -> void:
	if !data:
		quantity = v
	else:
		quantity = clamp(v, 0, data.stack_size)
	_refresh()

func _refresh() -> void:
	if !is_inside_tree():
		return
	if data and sprite:
		sprite.texture = data.icon

func can_stack_with(other: WorldItem) -> bool:
	return other and other.data == data and data != null and data.stack_size > 1

# Add a quantity and return what couldn't be added
func add_quantity(amount: int) -> int:
	if !data:
		return amount
	var room = data.stack_size - quantity
	var taken = min(amount, room)
	quantity += taken
	_refresh()
	return amount - taken

# ---------- HATCHING (EGGS ON GROUND) ----------

func _check_hatching_eligibility() -> void:
	if _has_evaluated_fertility:
		return
	if data and data.can_hatch and data.hatch_scene:
		_has_evaluated_fertility = true
		is_fertile = randf() < data.hatch_chance
		if is_fertile:
			hatch_timer = randf_range(data.hatch_duration_min, data.hatch_duration_max)
			set_process(true)
		else:
			set_process(false)
	else:
		is_fertile = false
		set_process(false)

func _process(delta: float) -> void:
	if is_queued_for_deletion() or not is_fertile or data == null or not data.can_hatch or data.hatch_scene == null:
		set_process(false)
		return

	hatch_timer -= delta
	if hatch_timer <= 0.0:
		_hatch()

func _hatch() -> void:
	if is_queued_for_deletion() or not is_fertile:
		return

	# Immediately disarm hatching to prevent multiple spawns on subsequent frames
	is_fertile = false
	set_process(false)

	if data and data.hatch_scene:
		var chick = data.hatch_scene.instantiate()
		chick.global_position = global_position
		var target_parent = get_parent() if get_parent() else get_tree().current_scene
		target_parent.call_deferred("add_child", chick)

	quantity -= 1
	if quantity <= 0:
		queue_free()
	else:
		_refresh()
		_has_evaluated_fertility = false
		hatch_timer = 0.0
		_check_hatching_eligibility()
