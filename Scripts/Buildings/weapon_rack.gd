extends Building
class_name WeaponRack

# ========== REFERENCES ==========

@onready var interaction_point: Node2D = $InteractionPoint
@onready var slots_visuals = [
	[$"Slot 1/Item Sprite 1", $"Slot 1/Item Sprite 2", $"Slot 1/Item Sprite 3"],
	[$"Slot 2/Item Sprite 1", $"Slot 2/Item Sprite 2", $"Slot 2/Item Sprite 3"],
	[$"Slot 3/Item Sprite 1", $"Slot 3/Item Sprite 2", $"Slot 3/Item Sprite 3"]
]

# ========== VARIABLES ==========

var slots_data: Array = [
	{ "kit_resource": null, "items": [], "is_full": false }, # Slot 0 (Archer / Left)
	{ "kit_resource": null, "items": [], "is_full": false }, # Slot 1 (Spearman / Center)
	{ "kit_resource": null, "items": [], "is_full": false }  # Slot 2 (Knight / Right)
]

var _available_kits: Array[KitData] = []
var _reserved_equip_claylings: Array = []
var _reserved_unequip_slots: Dictionary = {} # clayling (Node2D) -> slot_index (int)

# ========== FUNCTIONS ==========

# ---------- GENERAL ----------

func _ready():
	super._ready()

	add_to_group("weapon_racks")
	_load_available_kits()
	_clear_all_visuals()

func _load_available_kits() -> void:
	"""Scan Resources/Kit Resources for KitData resources in consistent order."""
	_available_kits.clear()

	var default_paths = [
		"res://Resources/Kit Resources/archer.tres",
		"res://Resources/Kit Resources/spearman.tres",
		"res://Resources/Kit Resources/knight.tres"
	]
	for p in default_paths:
		if ResourceLoader.exists(p):
			var kit = load(p)
			if kit and kit is KitData:
				_available_kits.append(kit)

	var dir = DirAccess.open("res://Resources/Kit Resources/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var full_path = "res://Resources/Kit Resources/" + file_name
				if not default_paths.has(full_path):
					var kit = load(full_path)
					if kit and kit is KitData:
						_available_kits.append(kit)
			file_name = dir.get_next()
		dir.list_dir_end()

# ---------- RESERVATIONS ----------

func get_available_kit_count_unreserved() -> int:
	_cleanup_reservations()
	return max(0, get_completed_kit_count() - _reserved_equip_claylings.size())

func reserve_equip(clayling: Node2D) -> bool:
	_cleanup_reservations()
	if get_available_kit_count_unreserved() > 0:
		if not _reserved_equip_claylings.has(clayling):
			_reserved_equip_claylings.append(clayling)
		return true
	return false

func release_equip_reservation(clayling: Node2D) -> void:
	_reserved_equip_claylings.erase(clayling)

func can_accept_kit_unreserved(kit_resource: KitData = null) -> bool:
	_cleanup_reservations()
	var reserved_indices = _reserved_unequip_slots.values()

	# 1. Check matching slot for kit_id
	if kit_resource:
		var preferred_idx = _get_preferred_slot_index_for_kit(kit_resource)
		if preferred_idx >= 0 and preferred_idx < slots_data.size():
			if not reserved_indices.has(preferred_idx) and not slots_data[preferred_idx]["is_full"]:
				return true

	# 2. Check any unreserved empty slot
	for i in range(slots_data.size()):
		if not reserved_indices.has(i):
			var slot = slots_data[i]
			if slot["kit_resource"] == null and slot["items"].is_empty():
				return true
			if kit_resource and slot["kit_resource"] != null and slot["kit_resource"].kit_id == kit_resource.kit_id and not slot["is_full"]:
				return true

	return false

func reserve_unequip_slot(soldier: Node2D, kit_resource: KitData = null) -> int:
	_cleanup_reservations()
	var reserved_indices = _reserved_unequip_slots.values()

	# 1. Try preferred slot for this kit
	if kit_resource:
		var preferred_idx = _get_preferred_slot_index_for_kit(kit_resource)
		if preferred_idx >= 0 and preferred_idx < slots_data.size():
			if not reserved_indices.has(preferred_idx) and not slots_data[preferred_idx]["is_full"]:
				_reserved_unequip_slots[soldier] = preferred_idx
				return preferred_idx

	# 2. Try any unreserved empty slot
	for i in range(slots_data.size()):
		if not reserved_indices.has(i):
			var slot = slots_data[i]
			if slot["kit_resource"] == null and slot["items"].is_empty():
				_reserved_unequip_slots[soldier] = i
				return i
			if kit_resource and slot["kit_resource"] != null and slot["kit_resource"].kit_id == kit_resource.kit_id and not slot["is_full"]:
				_reserved_unequip_slots[soldier] = i
				return i

	return -1

func release_unequip_reservation(clayling: Node2D) -> void:
	if clayling:
		_reserved_unequip_slots.erase(clayling)

func _cleanup_reservations() -> void:
	var valid_equippers: Array = []
	for c in _reserved_equip_claylings:
		if is_instance_valid(c) and not c.get("is_dead"):
			valid_equippers.append(c)
	_reserved_equip_claylings = valid_equippers

	var valid_unequippers: Dictionary = {}
	for c in _reserved_unequip_slots.keys():
		if is_instance_valid(c) and not c.get("is_dead"):
			valid_unequippers[c] = _reserved_unequip_slots[c]
	_reserved_unequip_slots = valid_unequippers

func _get_preferred_slot_index_for_kit(kit_resource: KitData) -> int:
	if not kit_resource:
		return -1
	if kit_resource.kit_id == "archer":
		return 0
	elif kit_resource.kit_id == "spearman":
		return 1
	elif kit_resource.kit_id == "knight":
		return 2
	for i in range(_available_kits.size()):
		if _available_kits[i].kit_id == kit_resource.kit_id:
			return i
	return -1

# ---------- ITEM MANAGEMENT ----------

func is_full() -> bool:
	for slot in slots_data:
		if not slot.get("is_full", false):
			return false
	return true

func can_accept(item_data: ItemData) -> bool:
	return can_accept_item(item_data)

func store_item(item: Dictionary) -> int:
	if item.is_empty():
		return 0
	var data: ItemData = item.get("item", null)
	var amount: int = int(item.get("count", 0))
	if data == null or amount <= 0:
		return 0
	var stored = 0
	for i in range(amount):
		if add_item(data):
			stored += 1
		else:
			break
	return stored

func deposit(item: Dictionary) -> int:
	return store_item(item)

func can_accept_item(item_data: ItemData) -> bool:
	if not item_data:
		return false
	var kit_resource = _get_kit_resource_for_item(item_data)
	if not kit_resource:
		return false

	for i in range(slots_data.size()):
		if _can_slot_accept_item(i, item_data, kit_resource):
			return true
	return false

func add_item(item_data: ItemData) -> bool:
	if not item_data:
		return false
	var kit_resource = _get_kit_resource_for_item(item_data)
	if not kit_resource:
		return false

	# 1. Search preferred slot
	var pref_idx = _get_preferred_slot_index_for_kit(kit_resource)
	if pref_idx >= 0 and pref_idx < slots_data.size():
		if _can_slot_accept_item(pref_idx, item_data, kit_resource):
			_place_item_in_slot(pref_idx, item_data, kit_resource)
			return true

	# 2. Search any matching slot
	for i in range(slots_data.size()):
		if slots_data[i]["kit_resource"] != null and slots_data[i]["kit_resource"].kit_id == kit_resource.kit_id:
			if _can_slot_accept_item(i, item_data, kit_resource):
				_place_item_in_slot(i, item_data, kit_resource)
				return true

	# 3. Else, search an empty slot
	for i in range(slots_data.size()):
		if slots_data[i]["kit_resource"] == null and slots_data[i]["items"].is_empty():
			_place_item_in_slot(i, item_data, kit_resource)
			return true

	return false

# ---------- LOGIC ----------

func _place_item_in_slot(index: int, item: ItemData, kit_resource: KitData):
	var slot = slots_data[index]

	if slot["kit_resource"] == null:
		slot["kit_resource"] = kit_resource

	slot["items"].append(item)

	_check_slot_completeness(index)
	_update_slot_visuals(index)

func _can_slot_accept_item(index: int, item: ItemData, kit_resource: KitData) -> bool:
	var slot = slots_data[index]

	if slot["is_full"]:
		return false

	if slot["kit_resource"] != null and slot["kit_resource"].kit_id != kit_resource.kit_id:
		return false

	# Verify item is part of required items
	var is_req = false
	for req in kit_resource.required_items:
		if req and (req == item or req.name == item.name):
			is_req = true
			break
	if not is_req:
		return false

	# Can't put the same item twice in the same slot
	for existing in slot["items"]:
		if existing and (existing == item or existing.name == item.name):
			return false

	return true

func _check_slot_completeness(index: int):
	if index < 0 or index >= slots_data.size():
		return
	var slot = slots_data[index]

	if slot["kit_resource"] == null:
		slot["is_full"] = false
		return

	var needed_items = slot["kit_resource"].required_items
	if slot["items"].size() < needed_items.size():
		slot["is_full"] = false
		return

	for req in needed_items:
		if not req:
			continue
		var found = false
		for item in slot["items"]:
			if item and (item == req or item.name == req.name):
				found = true
				break
		if not found:
			slot["is_full"] = false
			return

	slot["is_full"] = true

func _get_kit_resource_for_item(item_data: ItemData) -> KitData:
	if not item_data:
		return null
	if _available_kits.is_empty():
		_load_available_kits()
	for kit in _available_kits:
		for required_item in kit.required_items:
			if required_item and (required_item == item_data or required_item.name == item_data.name):
				return kit
	return null

# ---------- VISUALS ----------

func _update_slot_visuals(index: int):
	if index < 0 or index >= slots_data.size():
		return
	var items = slots_data[index]["items"]
	var sprites = slots_visuals[index]

	# Reset visuals first
	for s in sprites:
		s.visible = false
		s.texture = null

	# Display present items
	for i in range(items.size()):
		if i < sprites.size() and items[i] and items[i].icon:
			sprites[i].texture = items[i].icon
			sprites[i].visible = true

func _clear_all_visuals():
	for slot_arr in slots_visuals:
		for sprite in slot_arr:
			sprite.visible = false
			sprite.texture = null

# ---------- CLAYLING INTERACTION ----------

func take_kit(index: int) -> Dictionary:
	if index < 0 or index >= 3:
		return {}
	if not slots_data[index]["is_full"]:
		return {}

	var kit_resource = slots_data[index]["kit_resource"]
	if not kit_resource:
		return {}

	var result = {
		"kit_resource": kit_resource,
		"kit_type": kit_resource.kit_id,
		"display_name": kit_resource.display_name,
		"items": slots_data[index]["items"].duplicate(),
		"sprite_frames": kit_resource.sprite_frames
	}

	# Reset the slot completely so it can accept a new type later
	slots_data[index] = { "kit_resource": null, "items": [], "is_full": false }
	_update_slot_visuals(index)

	return result

func has_empty_slot() -> bool:
	for slot in slots_data:
		if slot["kit_resource"] == null and slot["items"].is_empty():
			return true
	return false

func deposit_kit(items: Array, kit_resource: KitData = null, depositor: Node2D = null) -> bool:
	if items.is_empty():
		return false

	# Detect kit_resource from items if not provided
	if not kit_resource:
		for item in items:
			if item is ItemData:
				var detected = _get_kit_resource_for_item(item)
				if detected:
					kit_resource = detected
					break

	var target_index: int = -1

	# Check if this depositor had a reserved slot
	if depositor and _reserved_unequip_slots.has(depositor):
		target_index = _reserved_unequip_slots[depositor]
		release_unequip_reservation(depositor)

	# 1. Try preferred slot if empty or matching
	if target_index == -1 and kit_resource:
		var pref = _get_preferred_slot_index_for_kit(kit_resource)
		if pref >= 0 and pref < slots_data.size():
			if slots_data[pref]["kit_resource"] == null and slots_data[pref]["items"].is_empty():
				target_index = pref
			elif slots_data[pref]["kit_resource"] != null and slots_data[pref]["kit_resource"].kit_id == kit_resource.kit_id and not slots_data[pref]["is_full"]:
				target_index = pref

	# 2. Try any empty slot
	if target_index == -1:
		for i in range(slots_data.size()):
			if slots_data[i]["kit_resource"] == null and slots_data[i]["items"].is_empty():
				target_index = i
				break

	# 3. Try any matching incomplete slot
	if target_index == -1 and kit_resource:
		for i in range(slots_data.size()):
			if slots_data[i]["kit_resource"] != null and slots_data[i]["kit_resource"].kit_id == kit_resource.kit_id and not slots_data[i]["is_full"]:
				target_index = i
				break

	if target_index != -1:
		var slot = slots_data[target_index]
		slot["kit_resource"] = kit_resource
		for item in items:
			if item is ItemData:
				var already = false
				for existing in slot["items"]:
					if existing and (existing == item or existing.name == item.name):
						already = true
						break
				if not already:
					slot["items"].append(item)

		_check_slot_completeness(target_index)
		_update_slot_visuals(target_index)
		return true

	# 4. Fallback: try adding items individually
	var all_added = true
	for item in items:
		if item is ItemData:
			if not add_item(item):
				all_added = false

	return all_added

func find_available_kit_index() -> int:
	for i in range(3):
		if slots_data[i]["is_full"]:
			return i
	return -1

func get_completed_kit_count() -> int:
	var count = 0
	for slot in slots_data:
		if slot["is_full"]:
			count += 1
	return count

func get_available_kits() -> Array[KitData]:
	return _available_kits.duplicate()

# ---------- DESTRUCTION ----------

func destroyed():
	for i in range(3):
		_drop_slot_content(i)

	super.destroyed()

func _drop_slot_content(index: int):
	var items = slots_data[index]["items"]
	if items.is_empty():
		return

	for item_data in items:
		var item_scene = load("res://Scenes/item.tscn").instantiate()
		item_scene.data = item_data
		item_scene.quantity = 1
		item_scene.global_position = global_position + Vector2(randf_range(-10,10), randf_range(10, 5))
		get_parent().add_child(item_scene)

# ---------- DEBUG ----------

func debug_fill_random_kit():
	if _available_kits.is_empty():
		return

	for i in range(3):
		if not slots_data[i]["is_full"]:
			var kit_to_load: KitData = null
			if i < _available_kits.size():
				kit_to_load = _available_kits[i]
			else:
				kit_to_load = _available_kits.pick_random()

			if kit_to_load:
				var needed_items = kit_to_load.required_items
				var loaded_items = []

				for item_data in needed_items:
					if item_data:
						loaded_items.append(item_data)

				if loaded_items.size() == needed_items.size():
					slots_data[i]["kit_resource"] = kit_to_load
					slots_data[i]["items"] = loaded_items
					slots_data[i]["is_full"] = true
					_update_slot_visuals(i)
