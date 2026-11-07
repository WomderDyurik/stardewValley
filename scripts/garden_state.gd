class_name GardenState
extends RefCounted

## Permanent plantings, campaign discoveries and per-plant levels. Only grown
## species supply the reusable templates selected before a paid-deployment battle.
signal changed

const Catalog = preload("res://scripts/catalog.gd")
const CampaignData = preload("res://scripts/campaign.gd")
const Helpers = preload("res://scripts/garden_helpers.gd")
const HOME_CYCLE: float = 30.0
const BASE_HOME_PLOT_COUNT: int = 144
const BASE_NURSERY_PLOT_COUNT: int = 144
const HOME_PLOT_COUNT: int = 144
const NURSERY_PLOT_COUNT: int = 144
const HISTORIC_BASE_HOME_PLOT_COUNT: int = 12
const HISTORIC_BASE_NURSERY_PLOT_COUNT: int = 8
const HISTORIC_HOME_PLOT_COUNT: int = 24
const HISTORIC_NURSERY_PLOT_COUNT: int = 12
const VERSION_SIX_PLOT_COUNT: int = 96
const LEGACY_HOME_PLOT_COUNT: int = 6
const MAX_PLANT_LEVEL: int = 20
const MAX_COINS: int = 1000000000
const SAVE_VERSION: int = 7
const POND_PLOT_COUNT: int = 6
const VERSION_THREE_KINDS: Array[String] = ["tomato", "marigold", "nettle", "lavender", "pepper", "pumpkin"]
const DISTRICT_KINDS: Dictionary = {
	"garden": ["tomato", "marigold", "pumpkin", "cucumber", "strawberry", "currant", "mint"],
	"nursery": ["nettle", "lavender", "pepper"],
	"pond": ["waterlily", "lotus"],
}
const DISTRICT_NAMES: Dictionary = {"garden": "Огород", "nursery": "Питомник", "pond": "Питомник · Водные грядки"}
const LEGACY_KINDS: Array[String] = ["tomato", "marigold", "nettle", "lavender", "pepper"]

var coins: int = 240
# Kept for v1 migration and catalog previews. Gameplay levels belong to plots.
var levels: Dictionary = {}
var home_plots: Array[String] = ["tomato", "tomato", "marigold", "", "", "", "", "", "", "", "", ""]
var home_levels: Array[int] = []
var nursery_plots: Array[String] = []
var nursery_levels: Array[int] = []
var pond_plots: Array[String] = []
var pond_levels: Array[int] = []
var unlocked_seeds: Array[String] = ["tomato", "marigold", "nettle", "cucumber"]
var completed_level: int = 0
var home_elapsed: float = 0.0
var home_ready: bool = false
var helper_levels: Dictionary = {"irrigation": 0, "compost": 0, "harvest_crate": 0}
var home_stock: int = 0
var home_stock_value: int = 0
# Optional runtime checkpoint. Packed built-in values preserve Vector2 and RNG
# integers; the garden and battle are committed together in the atomic save.
var session_data: Dictionary = {}


func _init() -> void:
	for kind in Catalog.ORDER:
		levels[kind] = 1
	while home_plots.size() < HOME_PLOT_COUNT:
		home_plots.append("")
	home_levels.resize(HOME_PLOT_COUNT)
	home_levels.fill(1)
	nursery_plots.resize(NURSERY_PLOT_COUNT)
	nursery_plots.fill("")
	nursery_levels.resize(NURSERY_PLOT_COUNT)
	nursery_levels.fill(1)
	pond_plots.resize(POND_PLOT_COUNT)
	pond_plots.fill("")
	pond_levels.resize(POND_PLOT_COUNT)
	pond_levels.fill(1)


func home_plot_capacity() -> int:
	return BASE_HOME_PLOT_COUNT


func nursery_plot_capacity() -> int:
	return BASE_NURSERY_PLOT_COUNT


func plot_count(area: String) -> int:
	return HOME_PLOT_COUNT if area == "home" else NURSERY_PLOT_COUNT if area == "nursery" else POND_PLOT_COUNT if area == "pond" else 0


func pond_plot_capacity() -> int:
	return POND_PLOT_COUNT if is_district_unlocked("pond") else 0


func plot_district(area: String, slot: int) -> String:
	if slot < 0 or slot >= plot_count(area):
		return ""
	if area == "pond":
		return "pond"
	if area == "nursery":
		return "nursery"
	return "garden"


func plot_info(area: String, slot: int) -> Dictionary:
	var district: String = plot_district(area, slot)
	if district.is_empty():
		return {}
	return {"area": area, "slot": slot, "district": district, "parent_district": "nursery" if area == "pond" else district, "district_name": DISTRICT_NAMES[district], "habitat": "water" if area == "pond" else "dry", "title": "%s · %s %d" % [DISTRICT_NAMES[district], "водная клетка" if area == "pond" else "клетка", slot + 1], "allowed_kinds": allowed_kinds(area, slot), "unlock_stage": CampaignData.district_unlock_stage(district), "unlocked": is_plot_unlocked(area, slot)}


func is_district_unlocked(id: String) -> bool:
	var stage: int = CampaignData.district_unlock_stage(id)
	return stage >= 0 and completed_level >= stage


func is_plot_unlocked(area: String, slot: int) -> bool:
	if slot < 0 or slot >= plot_count(area):
		return false
	return is_district_unlocked(plot_district(area, slot))


func is_seed_unlocked(kind: String) -> bool:
	return Catalog.PLANTS.has(kind) and unlocked_seeds.has(kind)


func is_stage_unlocked(stage: int) -> bool:
	return stage >= 1 and stage <= CampaignData.COUNT and stage <= completed_level + 1


func claim_stage_reward(stage: int) -> Dictionary:
	if not is_stage_unlocked(stage) or stage != completed_level + 1:
		return {}
	var info: Dictionary = CampaignData.stage_info(stage)
	if info.is_empty():
		return {}
	var new_seeds: Array[String] = []
	completed_level = stage
	for kind in info["seeds"]:
		if not unlocked_seeds.has(kind):
			unlocked_seeds.append(String(kind))
			new_seeds.append(String(kind))
	var reward: Dictionary = info.duplicate(true)
	reward["first_clear"] = true
	reward["new_seeds"] = new_seeds
	changed.emit()
	return reward


static func _home_capacity(progress: int) -> int:
	# Only versions 3–5 used campaign land grants. Keep their original limits
	# when validating old records, independently from the square-bed fields.
	return HISTORIC_BASE_HOME_PLOT_COUNT + 4 * clampi(progress, 0, CampaignData.COUNT)


static func _nursery_capacity(progress: int) -> int:
	return HISTORIC_BASE_NURSERY_PLOT_COUNT + 2 * maxi(clampi(progress, 0, CampaignData.COUNT) - 1, 0)


func plant_data(kind: String, level_override: int = 0) -> Dictionary:
	if not Catalog.PLANTS.has(kind):
		return {}
	var data: Dictionary = Catalog.PLANTS[kind].duplicate(true)
	var level: int = clampi(level_override if level_override > 0 else int(levels.get(kind, 1)), 1, MAX_PLANT_LEVEL)
	var yield_multiplier: float = pow(1.2, level - 1)
	data["kind"] = kind
	data["level"] = level
	data["home_yield"] = roundi(float(data["home_yield"]) * yield_multiplier)
	data["battle_yield"] = roundi(float(data["battle_yield"]) * yield_multiplier)
	data["damage"] = float(data["damage"]) * pow(1.22, level - 1)
	data["range"] = float(data["range"]) + minf(float(level - 1) * 3.0, 30.0)
	return data


func allowed_kinds(area: String, slot: int = -1) -> Array[String]:
	var result: Array[String] = []
	if slot >= 0:
		var district: String = plot_district(area, slot)
		for kind in DISTRICT_KINDS.get(district, []):
			if _kind_fits_area(String(kind), area):
				result.append(String(kind))
		return result
	for kind in Catalog.ORDER:
		if _kind_fits_area(kind, area):
			result.append(kind)
	return result


func _kind_fits_area(kind: String, area: String) -> bool:
	if not Catalog.PLANTS.has(kind):
		return false
	var data: Dictionary = Catalog.PLANTS[kind]
	if area == "pond":
		return data.get("habitat", "dry") == "water"
	if data.get("habitat", "dry") == "water":
		return false
	return data["role"] == "income" if area == "home" else data["role"] == "defense" if area == "nursery" else false


func plot_kind(area: String, slot: int) -> String:
	var plots: Array[String] = _plots_for(area)
	if slot < 0 or slot >= plots.size():
		return ""
	return plots[slot]


func plot_level(area: String, slot: int) -> int:
	var plot_levels: Array[int] = _levels_for(area)
	if slot < 0 or slot >= plot_levels.size():
		return 0
	return plot_levels[slot]


func plot_data(area: String, slot: int) -> Dictionary:
	var kind: String = plot_kind(area, slot)
	if kind.is_empty() or not _planting_contributes(area, slot):
		return {}
	var data: Dictionary = plant_data(kind, plot_level(area, slot))
	if not data.is_empty():
		data["id"] = "%s:%d" % [area, slot]
		data["area"] = area
		data["slot"] = slot
	return data


func _planting_contributes(area: String, slot: int) -> bool:
	# Former greenhouse and archived records now occupy the same stable IDs
	# inside the two expanded fields; there are no invisible planting sources.
	return is_plot_unlocked(area, slot)


func spend(amount: int) -> bool:
	if amount < 0 or amount > coins:
		return false
	if amount > 0:
		coins -= amount
		changed.emit()
	return true


func earn(amount: int) -> void:
	if amount <= 0:
		return
	coins = mini(MAX_COINS, coins + mini(amount, MAX_COINS))
	changed.emit()


func can_plant(area: String, slot: int, kind: String, replace_existing: bool = false) -> bool:
	var plots: Array[String] = _plots_for(area)
	var plot_levels: Array[int] = _levels_for(area)
	if slot < 0 or slot >= plots.size() or slot >= plot_levels.size() or not allowed_kinds(area, slot).has(kind) or not is_plot_unlocked(area, slot) or not is_seed_unlocked(kind):
		return false
	if replace_existing:
		if plots[slot].is_empty() or plots[slot] == kind:
			return false
	elif not plots[slot].is_empty():
		return false
	return coins >= int(Catalog.PLANTS[kind]["cost"])


func plant_plot(area: String, slot: int, kind: String) -> bool:
	if not can_plant(area, slot, kind):
		return false
	return _set_plant(area, slot, kind)


func replace_plot(area: String, slot: int, kind: String) -> bool:
	if not can_plant(area, slot, kind, true):
		return false
	# The new plant is bought once. Replacement never refunds the previous plant
	# and its upgrades, so swapping cannot duplicate coins or high-level units.
	return _set_plant(area, slot, kind)


func _set_plant(area: String, slot: int, kind: String) -> bool:
	var plots: Array[String] = _plots_for(area)
	var plot_levels: Array[int] = _levels_for(area)
	coins -= int(Catalog.PLANTS[kind]["cost"])
	plots[slot] = kind
	plot_levels[slot] = 1
	changed.emit()
	return true


func plant_home(slot: int, kind: String) -> bool:
	return plant_plot("home", slot, kind)


func plant_nursery(slot: int, kind: String) -> bool:
	return plant_plot("nursery", slot, kind)


func plot_upgrade_cost(area: String, slot: int) -> int:
	if not is_plot_unlocked(area, slot):
		return 0
	var data: Dictionary = plot_data(area, slot)
	if data.is_empty() or int(data["level"]) >= MAX_PLANT_LEVEL:
		return 0
	return roundi(float(data["upgrade_base"]) * pow(1.55, int(data["level"]) - 1))


func upgrade_plot(area: String, slot: int) -> bool:
	var cost: int = plot_upgrade_cost(area, slot)
	if cost <= 0 or cost > coins:
		return false
	var plot_levels: Array[int] = _levels_for(area)
	coins -= cost
	plot_levels[slot] += 1
	changed.emit()
	return true


# Compatibility for callers that previously selected a species globally.
# These wrappers now affect one real planting; the game UI uses plot methods.
func upgrade_cost(kind: String) -> int:
	for entry in battle_roster():
		if entry["kind"] == kind:
			return plot_upgrade_cost(entry["area"], entry["slot"])
	return 0


func upgrade(kind: String) -> bool:
	for entry in battle_roster():
		if entry["kind"] == kind:
			return upgrade_plot(entry["area"], entry["slot"])
	return false


func battle_roster() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for area in ["home", "nursery", "pond"]:
		var plots: Array[String] = _plots_for(area)
		for slot in range(plots.size()):
			if _planting_contributes(area, slot) and not plots[slot].is_empty():
				result.append({
					"id": "%s:%d" % [area, slot],
					"area": area,
					"slot": slot,
					"kind": plots[slot],
					"level": plot_level(area, slot),
				})
	return result


func battle_templates() -> Array[Dictionary]:
	var best: Dictionary = {}
	for entry in battle_roster():
		var kind: String = entry["kind"]
		if not best.has(kind) or int(entry["level"]) > int(best[kind]["level"]):
			best[kind] = entry
	var result: Array[Dictionary] = []
	for kind in Catalog.ORDER:
		if not best.has(kind):
			continue
		var source: Dictionary = best[kind]
		var data: Dictionary = plant_data(kind, int(source["level"]))
		result.append({
			"id": kind,
			"kind": kind,
			"level": int(source["level"]),
			"source_id": String(source["id"]),
			"area": String(source["area"]),
			"slot": int(source["slot"]),
			"cost": int(data["battle_cost"]),
			"name": String(data["name"]),
			"role": String(data["role"]),
			"habitat": String(data.get("habitat", "dry")),
		})
	return result


func home_income() -> int:
	var amount: int = 0
	for area in ["home", "pond"]:
		for slot in range(plot_count(area)):
			amount += int(plot_data(area, slot).get("home_yield", 0))
	return roundi(float(amount) * Helpers.yield_multiplier(helper_level("compost")))


func helper_level(id: String) -> int:
	return int(helper_levels.get(id, 0)) if Helpers.is_valid(id) else 0


func helper_upgrade_cost(id: String) -> int:
	return Helpers.upgrade_cost(id, helper_level(id))


func can_upgrade_helper(id: String) -> bool:
	var cost: int = helper_upgrade_cost(id)
	return cost > 0 and coins >= cost


func upgrade_helper(id: String) -> bool:
	if not can_upgrade_helper(id):
		return false
	# Banked crops keep the value earned before a compost or storage upgrade.
	var stock: int = stored_harvests()
	var value: int = collectable_home_income()
	var full_before: bool = stock >= harvest_capacity()
	var old_cycle: float = home_cycle()
	coins -= helper_upgrade_cost(id)
	helper_levels[id] = helper_level(id) + 1
	home_stock = stock
	home_stock_value = value
	if id == "harvest_crate" and full_before:
		home_elapsed = 0.0
	elif id == "irrigation":
		# Preserve progress rather than making a purchased speedup create or
		# erase an already partially grown harvest.
		home_elapsed = home_cycle() if full_before else clampf(home_elapsed / old_cycle, 0.0, 1.0) * home_cycle()
	home_ready = home_stock > 0
	changed.emit()
	return true


func home_cycle() -> float:
	return Helpers.cycle(helper_level("irrigation"))


func harvest_capacity() -> int:
	return Helpers.capacity(helper_level("harvest_crate"))


func stored_harvests() -> int:
	# Older callers and v1-v4 saves represented one ripe crop with this flag.
	if not home_ready:
		return 0
	return clampi(maxi(home_stock, 1), 1, harvest_capacity())


func collectable_home_income() -> int:
	var stock: int = stored_harvests()
	if stock <= 0:
		return 0
	return home_stock_value if home_stock_value > 0 else mini(MAX_COINS, home_income() * stock)


func home_growth_fraction() -> float:
	return clampf(home_elapsed / home_cycle(), 0.0, 1.0)


func collect_home() -> int:
	if not home_ready:
		return 0
	var amount: int = collectable_home_income()
	var was_full: bool = stored_harvests() >= harvest_capacity()
	home_ready = false
	if was_full:
		home_elapsed = 0.0
	home_stock = 0
	home_stock_value = 0
	coins = mini(MAX_COINS, coins + amount)
	changed.emit()
	return amount


func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var stock: int = stored_harvests()
	if stock >= harvest_capacity() or home_income() <= 0:
		return
	var bank: int = collectable_home_income()
	var cycle: float = home_cycle()
	home_elapsed = minf(cycle * harvest_capacity(), home_elapsed + delta)
	var ripe: int = mini(harvest_capacity() - stock, floori(home_elapsed / cycle))
	if ripe > 0:
		home_stock = stock + ripe
		home_stock_value = mini(MAX_COINS, bank + ripe * home_income())
		home_ready = home_stock > 0
		home_elapsed = cycle if home_stock >= harvest_capacity() else home_elapsed - ripe * cycle
		changed.emit()


func save_game(path: String = "user://garden_save.json") -> bool:
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"coins": coins,
		"levels": levels,
		"home_plots": home_plots,
		"home_levels": home_levels,
		"nursery_plots": nursery_plots,
		"nursery_levels": nursery_levels,
		"pond_plots": pond_plots,
		"pond_levels": pond_levels,
		"unlocked_seeds": unlocked_seeds,
		"completed_level": completed_level,
		"home_elapsed": home_elapsed,
		"home_ready": home_ready,
		"helper_levels": helper_levels,
		"home_stock": stored_harvests(),
		"home_stock_value": collectable_home_income(),
		"session": Marshalls.raw_to_base64(var_to_bytes(session_data)),
	}
	var temporary_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return false
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path),
		ProjectSettings.globalize_path(path)
	) == OK


func load_game(path: String = "user://garden_save.json") -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parser = JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not parser.data is Dictionary:
		return false
	var payload: Dictionary = parser.data
	if not _valid_save(payload):
		return false
	# Every replacement value is built first, so malformed saves never partly
	# change the live wallet, campaign, seeds or grown templates.
	var version: int = int(payload["version"])
	var loaded_home: Array[String] = []
	var loaded_home_levels: Array[int] = []
	var loaded_nursery: Array[String] = []
	var loaded_nursery_levels: Array[int] = []
	var loaded_catalog_levels: Dictionary = {}
	var loaded_pond: Array[String] = []
	var loaded_pond_levels: Array[int] = []
	for kind in Catalog.ORDER:
		loaded_catalog_levels[kind] = int(payload["levels"].get(kind, 1))
	for slot in range(payload["home_plots"].size()):
		var kind: String = payload["home_plots"][slot]
		loaded_home.append(kind)
		loaded_home_levels.append(int(payload["home_levels"][slot]) if version >= 2 else int(loaded_catalog_levels[kind]) if not kind.is_empty() else 1)
	while loaded_home.size() < HOME_PLOT_COUNT:
		loaded_home.append("")
		loaded_home_levels.append(1)
	if version >= 2:
		for slot in range(payload["nursery_plots"].size()):
			loaded_nursery.append(String(payload["nursery_plots"][slot]))
			loaded_nursery_levels.append(int(payload["nursery_levels"][slot]))
	while loaded_nursery.size() < NURSERY_PLOT_COUNT:
		loaded_nursery.append("")
		loaded_nursery_levels.append(1)
	if version == 1:
		# Paid pre-nursery upgrades remain actual plantings. Decorative level-one
		# catalog entries never grant a grown battle template.
		var nursery_slot: int = 0
		for kind in ["nettle", "lavender", "pepper"]:
			var old_level: int = int(loaded_catalog_levels[kind])
			if old_level > 1:
				loaded_nursery[nursery_slot] = kind
				loaded_nursery_levels[nursery_slot] = old_level
				nursery_slot += 1
	if version >= 4:
		for slot in range(payload["pond_plots"].size()):
			loaded_pond.append(String(payload["pond_plots"][slot]))
			loaded_pond_levels.append(int(payload["pond_levels"][slot]))
	while loaded_pond.size() < POND_PLOT_COUNT:
		loaded_pond.append("")
		loaded_pond_levels.append(1)
	var loaded_seeds: Array[String] = []
	if version >= 3:
		for kind in payload["unlocked_seeds"]:
			loaded_seeds.append(String(kind))
	if version < 4:
		for kind in Catalog.ORDER:
			var unlock_stage: int = CampaignData.seed_unlock_stage(kind)
			var grew_before: bool = loaded_home.has(kind) or loaded_nursery.has(kind)
			var paid_before: bool = Catalog.PLANTS[kind]["role"] == "defense" and int(loaded_catalog_levels[kind]) > 1
			if (unlock_stage >= 0 and unlock_stage <= int(payload["completed_level"])) or grew_before or paid_before:
				if not loaded_seeds.has(kind):
					loaded_seeds.append(kind)
	coins = int(payload["coins"])
	levels = loaded_catalog_levels
	home_plots = loaded_home
	home_levels = loaded_home_levels
	nursery_plots = loaded_nursery
	nursery_levels = loaded_nursery_levels
	pond_plots = loaded_pond
	pond_levels = loaded_pond_levels
	unlocked_seeds = loaded_seeds
	completed_level = int(payload["completed_level"])
	home_elapsed = float(payload["home_elapsed"])
	home_ready = bool(payload["home_ready"])
	helper_levels = {"irrigation": 0, "compost": 0, "harvest_crate": 0}
	if version >= 5:
		for id in Helpers.ORDER:
			helper_levels[id] = int(payload["helper_levels"][id])
	home_stock = int(payload["home_stock"]) if version >= 5 else 1 if home_ready else 0
	home_stock_value = int(payload["home_stock_value"]) if version >= 5 else home_income() if home_ready else 0
	session_data = {}
	var packed_session: Variant = payload.get("session", "")
	if packed_session is String and packed_session.length() > 0 and packed_session.length() <= 2000000:
		var session_bytes: PackedByteArray = Marshalls.base64_to_raw(packed_session)
		if not session_bytes.is_empty():
			var decoded: Variant = bytes_to_var(session_bytes)
			if decoded is Dictionary:
				session_data = decoded
	changed.emit()
	return true


func _valid_save(payload: Dictionary) -> bool:
	for key in ["version", "coins", "levels", "home_plots", "completed_level", "home_elapsed", "home_ready"]:
		if not payload.has(key):
			return false
	if not _integer_in_range(payload["version"], 1, SAVE_VERSION):
		return false
	if not _integer_in_range(payload["coins"], 0, MAX_COINS) or not _integer_in_range(payload["completed_level"], 0, 10000):
		return false
	var version: int = int(payload["version"])
	if not payload["levels"] is Dictionary:
		return false
	for kind in (Catalog.ORDER if version >= 4 else VERSION_THREE_KINDS if version == 3 else LEGACY_KINDS):
		if not payload["levels"].has(kind) or not _integer_in_range(payload["levels"][kind], 1, MAX_PLANT_LEVEL):
			return false
	for kind in payload["levels"]:
		if not Catalog.PLANTS.has(kind) or not _integer_in_range(payload["levels"][kind], 1, MAX_PLANT_LEVEL):
			return false
	var home_counts: Array[int] = []
	home_counts.append(HOME_PLOT_COUNT if version >= 7 else VERSION_SIX_PLOT_COUNT if version == 6 else HISTORIC_HOME_PLOT_COUNT if version >= 3 else HISTORIC_BASE_HOME_PLOT_COUNT)
	if version == 1:
		home_counts.append(LEGACY_HOME_PLOT_COUNT)
	if not _valid_plots(payload["home_plots"], "home", home_counts):
		return false
	if version >= 2:
		for key in ["home_levels", "nursery_plots", "nursery_levels"]:
			if not payload.has(key):
				return false
		var nursery_count: int = NURSERY_PLOT_COUNT if version >= 7 else VERSION_SIX_PLOT_COUNT if version == 6 else HISTORIC_NURSERY_PLOT_COUNT if version >= 3 else HISTORIC_BASE_NURSERY_PLOT_COUNT
		if not _valid_plots(payload["nursery_plots"], "nursery", [nursery_count]):
			return false
		if not _valid_plot_levels(payload["home_levels"], payload["home_plots"]) or not _valid_plot_levels(payload["nursery_levels"], payload["nursery_plots"]):
			return false
	if version >= 4:
		if not payload.has("pond_plots") or not payload.has("pond_levels") or not _valid_plots(payload["pond_plots"], "pond", [POND_PLOT_COUNT]) or not _valid_plot_levels(payload["pond_levels"], payload["pond_plots"]):
			return false
		if int(payload["completed_level"]) < 1 and not payload["pond_plots"].all(func(kind): return kind == ""):
			return false
	if version >= 3:
		if not payload.has("unlocked_seeds") or not _valid_seeds(payload["unlocked_seeds"], int(payload["completed_level"]), payload["home_plots"], payload["nursery_plots"], payload.get("pond_plots", []), version):
			return false
		if version < 6:
			for slot in range(_home_capacity(int(payload["completed_level"])), HISTORIC_HOME_PLOT_COUNT):
				if not payload["home_plots"][slot].is_empty():
					return false
			for slot in range(_nursery_capacity(int(payload["completed_level"])), HISTORIC_NURSERY_PLOT_COUNT):
				if not payload["nursery_plots"][slot].is_empty():
					return false
	var elapsed = payload["home_elapsed"]
	if not (elapsed is float or elapsed is int) or not is_finite(float(elapsed)) or float(elapsed) < 0.0:
		return false
	if not payload["home_ready"] is bool:
		return false
	if version >= 5:
		if not _valid_helper_save(payload):
			return false
	else:
		if float(elapsed) > HOME_CYCLE or bool(payload["home_ready"]) != (float(elapsed) >= HOME_CYCLE):
			return false
	return true


func _valid_helper_save(payload: Dictionary) -> bool:
	var stored: Variant = payload.get("helper_levels")
	if not stored is Dictionary or stored.size() != Helpers.ORDER.size():
		return false
	for id in Helpers.ORDER:
		if not stored.has(id) or not _integer_in_range(stored[id], 0, Helpers.MAX_LEVEL):
			return false
	var capacity: int = Helpers.capacity(int(stored["harvest_crate"]))
	var cycle: float = Helpers.cycle(int(stored["irrigation"]))
	if not _integer_in_range(payload.get("home_stock"), 0, capacity) or not _integer_in_range(payload.get("home_stock_value"), 0, MAX_COINS):
		return false
	var stock: int = int(payload["home_stock"])
	var value: int = int(payload["home_stock_value"])
	var elapsed: float = float(payload["home_elapsed"])
	if bool(payload["home_ready"]) != (stock > 0) or (stock == 0 and value != 0) or elapsed > cycle:
		return false
	# A full store pauses at a complete cycle. Partial stores keep only the
	# next crop's actual progress; no elapsed cycles can be replayed on reload.
	if stock == capacity:
		return is_equal_approx(elapsed, cycle)
	return elapsed < cycle


func _valid_seeds(value, progress: int, home: Array, nursery: Array, pond: Array = [], version: int = SAVE_VERSION) -> bool:
	if not value is Array:
		return false
	var seen: Dictionary = {}
	for kind in value:
		if not kind is String or not Catalog.PLANTS.has(kind) or seen.has(kind):
			return false
		seen[kind] = true
	for kind in (Catalog.ORDER if version >= 4 else VERSION_THREE_KINDS):
		var unlock_stage: int = CampaignData.seed_unlock_stage(kind)
		if ((unlock_stage >= 0 and unlock_stage <= progress) or home.has(kind) or nursery.has(kind) or pond.has(kind)) and not seen.has(kind):
			return false
	return true


func _valid_plots(value, area: String, valid_counts: Array[int]) -> bool:
	if not value is Array or value.size() not in valid_counts:
		return false
	for slot in range(value.size()):
		var kind = value[slot]
		if not kind is String:
			return false
		if kind.is_empty():
			continue
		if not _kind_fits_area(kind, area):
			return false
		if allowed_kinds(area, slot).has(kind):
			continue
		# Existing dry crops and defenders stay in their paid positions even when
		# the area's new specialisation differs. New aquatic species never use it.
		if not VERSION_THREE_KINDS.has(kind):
			return false
	return true


func _valid_plot_levels(value, plots: Array) -> bool:
	if not value is Array or value.size() != plots.size():
		return false
	for slot in range(value.size()):
		if not _integer_in_range(value[slot], 1, MAX_PLANT_LEVEL):
			return false
		if plots[slot].is_empty() and int(value[slot]) != 1:
			return false
	return true


func _plots_for(area: String) -> Array[String]:
	if area == "home":
		return home_plots
	if area == "nursery":
		return nursery_plots
	if area == "pond":
		return pond_plots
	return []


func _levels_for(area: String) -> Array[int]:
	if area == "home":
		return home_levels
	if area == "nursery":
		return nursery_levels
	if area == "pond":
		return pond_levels
	return []


func _integer_in_range(value, lower: int, upper: int) -> bool:
	if not (value is int or value is float):
		return false
	var number: float = float(value)
	return is_finite(number) and number >= float(lower) and number <= float(upper) and number == floor(number)
