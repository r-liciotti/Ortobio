class_name InventoryManager
extends RefCounted
## Minecraft-style 6-slot hotbar + 24-slot backpack inventory with tool durability & perishable crops.

const HOTBAR_SIZE := 6
const BACKPACK_SIZE := 24

var items_db: Dictionary = {}
var hotbar: Array[Dictionary] = []
var backpack: Array[Dictionary] = []


func _init(p_items_db: Dictionary = {}) -> void:
	items_db = p_items_db
	clear_all()


func clear_all() -> void:
	hotbar.clear()
	for _i: int in range(HOTBAR_SIZE):
		hotbar.append({})
	backpack.clear()
	for _i: int in range(BACKPACK_SIZE):
		backpack.append({})


func setup_starter_inventory() -> void:
	clear_all()
	hotbar[0] = create_tool_slot("spade")
	hotbar[1] = create_tool_slot("rake")
	hotbar[2] = create_tool_slot("water")
	hotbar[3] = _create_stack_slot("seed_ravanello", 10)
	hotbar[4] = _create_stack_slot("seed_pomodoro", 10)
	hotbar[5] = _create_stack_slot("seed_cavolo_verza", 10)

	backpack[0] = create_tool_slot("probe")
	backpack[1] = _create_stack_slot("compost", 15)
	backpack[2] = _create_stack_slot("seed_piselli", 10)
	backpack[3] = _create_stack_slot("seed_trifoglio", 10)


func create_tool_slot(item_id: String, tier: String = "old") -> Dictionary:
	var item_def: Dictionary = items_db.get(item_id, {})
	var max_dur: int = maxi(1, int(item_def.get("max_durability", 60)))
	return {
		"item_id": item_id,
		"qty": 1,
		"tier": tier,
		"durability": max_dur,
		"max_durability": max_dur,
	}


func _create_stack_slot(item_id: String, qty: int, days_left: int = -1) -> Dictionary:
	var slot: Dictionary = {
		"item_id": item_id,
		"qty": qty,
	}
	if days_left >= 0:
		slot["days_left"] = days_left
	return slot


func _is_valid_slot(container: String, index: int) -> bool:
	if container == "hotbar":
		return index >= 0 and index < HOTBAR_SIZE
	if container == "backpack":
		return index >= 0 and index < BACKPACK_SIZE
	return false


func _get_container_array(container: String) -> Array[Dictionary]:
	if container == "hotbar":
		return hotbar
	return backpack


func get_slot(container: String, index: int) -> Dictionary:
	if not _is_valid_slot(container, index):
		return {}
	var arr: Array[Dictionary] = _get_container_array(container)
	return arr[index]


func set_slot(container: String, index: int, slot: Dictionary) -> void:
	if not _is_valid_slot(container, index):
		return
	var arr: Array[Dictionary] = _get_container_array(container)
	arr[index] = {} if slot.is_empty() else slot.duplicate(true)


func swap_slots(c1: String, i1: int, c2: String, i2: int) -> bool:
	if not _is_valid_slot(c1, i1) or not _is_valid_slot(c2, i2):
		return false
	if c1 == c2 and i1 == i2:
		return true
	var arr1: Array[Dictionary] = _get_container_array(c1)
	var arr2: Array[Dictionary] = _get_container_array(c2)
	var tmp: Dictionary = arr1[i1]
	arr1[i1] = arr2[i2]
	arr2[i2] = tmp
	return true


func add_item(item_id: String, qty: int = 1, days_left_override: int = -1) -> int:
	if qty <= 0 or not items_db.has(item_id):
		return 0
	var item_def: Dictionary = items_db[item_id]
	var category: String = str(item_def.get("category", ""))
	var is_stackable: bool = bool(item_def.get("stackable", true)) and category != "tool"

	if not is_stackable:
		var added: int = 0
		var tool_order: Array[String] = ["hotbar", "backpack"]
		for _n: int in range(qty):
			if _place_in_first_empty(tool_order, create_tool_slot(item_id)):
				added += 1
			else:
				break
		return added

	var shelf_life: int = int(item_def.get("shelf_life_days", 0))
	var resolved_days: int = -1
	if days_left_override >= 0:
		resolved_days = days_left_override
	elif shelf_life > 0:
		resolved_days = shelf_life

	var search_order: Array[String] = ["hotbar", "backpack"]
	if category == "crop":
		search_order = ["backpack", "hotbar"]

	# Merge into an existing matching stack first
	for cname: String in search_order:
		var arr: Array[Dictionary] = _get_container_array(cname)
		for i: int in range(arr.size()):
			var slot: Dictionary = arr[i]
			if slot.is_empty() or str(slot.get("item_id", "")) != item_id:
				continue
			if resolved_days >= 0:
				if not slot.has("days_left") or int(slot["days_left"]) != resolved_days:
					continue
			elif slot.has("days_left"):
				continue
			slot["qty"] = int(slot.get("qty", 0)) + qty
			return qty

	# Otherwise place in first empty slot following category preference
	var new_slot: Dictionary = _create_stack_slot(item_id, qty, resolved_days)
	if _place_in_first_empty(search_order, new_slot):
		return qty
	return 0


func _place_in_first_empty(container_order: Array[String], slot_data: Dictionary) -> bool:
	for cname: String in container_order:
		var arr: Array[Dictionary] = _get_container_array(cname)
		for i: int in range(arr.size()):
			if arr[i].is_empty():
				arr[i] = slot_data
				return true
	return false


func consume_from_slot(container: String, index: int, qty: int = 1) -> bool:
	if qty <= 0 or not _is_valid_slot(container, index):
		return false
	var arr: Array[Dictionary] = _get_container_array(container)
	var slot: Dictionary = arr[index]
	if slot.is_empty():
		return false
	var cur_qty: int = int(slot.get("qty", 0))
	if cur_qty < qty:
		return false
	var remaining: int = cur_qty - qty
	if remaining <= 0:
		arr[index] = {}
	else:
		slot["qty"] = remaining
	return true


func damage_tool_in_slot(container: String, index: int, amount: int = 1) -> Dictionary:
	if not _is_valid_slot(container, index):
		return {"ok": false, "reason": "invalid_slot"}
	var arr: Array[Dictionary] = _get_container_array(container)
	var slot: Dictionary = arr[index]
	if slot.is_empty() or not slot.has("durability"):
		return {"ok": false, "reason": "not_a_tool"}
	var max_dur: int = int(slot.get("max_durability", 60))
	var dur: int = maxi(0, int(slot.get("durability", max_dur)) - maxi(0, amount))
	slot["durability"] = dur
	return {
		"ok": true,
		"broken": dur <= 0,
		"durability": dur,
		"max_durability": max_dur,
	}


func is_tool_broken(slot: Dictionary) -> bool:
	if slot.is_empty() or not slot.has("durability"):
		return false
	return int(slot["durability"]) <= 0


func repair_tool_in_slot(container: String, index: int) -> Dictionary:
	if not _is_valid_slot(container, index):
		return {"ok": false, "reason": "invalid_slot"}
	var arr: Array[Dictionary] = _get_container_array(container)
	var slot: Dictionary = arr[index]
	if slot.is_empty() or not slot.has("durability"):
		return {"ok": false, "reason": "not_a_tool"}
	var max_dur: int = int(slot.get("max_durability", 60))
	var cur_dur: int = int(slot.get("durability", max_dur))
	if cur_dur >= max_dur:
		return {"ok": false, "reason": "not_damaged"}
	var item_id: String = str(slot.get("item_id", ""))
	var item_def: Dictionary = items_db.get(item_id, {})
	var repair_cost: int = int(item_def.get("repair_cost", 15))
	slot["durability"] = max_dur
	return {
		"ok": true,
		"cost": repair_cost,
		"durability": max_dur,
		"max_durability": max_dur,
	}


func tick_freshness() -> Dictionary:
	var total_expired: int = 0
	var expired_list: Array[Dictionary] = []

	for cname: String in ["hotbar", "backpack"]:
		var arr: Array[Dictionary] = _get_container_array(cname)
		for i: int in range(arr.size()):
			var slot: Dictionary = arr[i]
			if slot.is_empty() or not slot.has("days_left"):
				continue
			var days: int = int(slot["days_left"])
			if days <= 0:
				continue
			days -= 1
			slot["days_left"] = days
			if days <= 0:
				var exp_id: String = str(slot.get("item_id", ""))
				var exp_qty: int = int(slot.get("qty", 0))
				arr[i] = {}
				total_expired += exp_qty
				expired_list.append({
					"item_id": exp_id,
					"qty": exp_qty,
				})

	if total_expired > 0:
		if items_db.has("scarti_vegetali"):
			add_item("scarti_vegetali", total_expired)
		else:
			var fallback_order: Array[String] = ["hotbar", "backpack"]
			_place_in_first_empty(fallback_order, _create_stack_slot("scarti_vegetali", total_expired))

	return {
		"expired_count": total_expired,
		"expired_items": expired_list,
	}


func sell_all_crops() -> Dictionary:
	var sold_count: int = 0
	var earned: int = 0
	for cname: String in ["hotbar", "backpack"]:
		var arr: Array[Dictionary] = _get_container_array(cname)
		for i: int in range(arr.size()):
			var slot: Dictionary = arr[i]
			if slot.is_empty():
				continue
			var item_id: String = str(slot.get("item_id", ""))
			var item_def: Dictionary = items_db.get(item_id, {})
			if str(item_def.get("category", "")) != "crop":
				continue
			var qty: int = int(slot.get("qty", 0))
			var sell_price: int = int(item_def.get("sell_price", 0))
			sold_count += qty
			earned += sell_price * qty
			arr[i] = {}
	return {
		"sold_count": sold_count,
		"earned": earned,
	}


func get_total_item_count(item_id: String) -> int:
	var total: int = 0
	for cname: String in ["hotbar", "backpack"]:
		var arr: Array[Dictionary] = _get_container_array(cname)
		for slot: Dictionary in arr:
			if not slot.is_empty() and str(slot.get("item_id", "")) == item_id:
				total += int(slot.get("qty", 0))
	return total


func _normalize_slot(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var d: Dictionary = raw
	if d.is_empty() or not d.has("item_id"):
		return {}
	var qty: int = int(d.get("qty", 0))
	if qty <= 0:
		return {}
	var slot: Dictionary = {
		"item_id": str(d.get("item_id", "")),
		"qty": qty,
	}
	if d.has("tier"):
		slot["tier"] = str(d["tier"])
	if d.has("durability"):
		slot["durability"] = maxi(0, int(d["durability"]))
	if d.has("max_durability"):
		slot["max_durability"] = maxi(1, int(d["max_durability"]))
	if d.has("days_left"):
		slot["days_left"] = int(d["days_left"])
	return slot


func to_dict() -> Dictionary:
	var hb: Array[Dictionary] = []
	for slot: Dictionary in hotbar:
		hb.append({} if slot.is_empty() else _normalize_slot(slot))
	var bp: Array[Dictionary] = []
	for slot: Dictionary in backpack:
		bp.append({} if slot.is_empty() else _normalize_slot(slot))
	return {
		"hotbar": hb,
		"backpack": bp,
	}


func from_dict(data: Dictionary) -> void:
	clear_all()
	var raw_hb: Variant = data.get("hotbar", [])
	if raw_hb is Array:
		var hb_arr: Array = raw_hb
		for i: int in range(mini(HOTBAR_SIZE, hb_arr.size())):
			hotbar[i] = _normalize_slot(hb_arr[i])
	var raw_bp: Variant = data.get("backpack", [])
	if raw_bp is Array:
		var bp_arr: Array = raw_bp
		for i: int in range(mini(BACKPACK_SIZE, bp_arr.size())):
			backpack[i] = _normalize_slot(bp_arr[i])
