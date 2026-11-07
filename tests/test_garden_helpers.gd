extends SceneTree

const State = preload("res://scripts/garden_state.gd")
const Helpers = preload("res://scripts/garden_helpers.gd")
var checks: int = 0
var failures: int = 0
var save_path: String


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	save_path = "/private/tmp/planta2-test-helpers-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	_test_optional_and_paid()
	_test_irrigation_progress()
	_test_banked_value_and_partial_collection()
	_test_storage_limits()
	_test_persistence_and_migration()
	_test_invalid_saves_are_atomic()
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(save_path + ".tmp")
	print("Garden helpers: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _rich_state():
	var state = State.new()
	state.coins = 100000
	return state


func _test_optional_and_paid() -> void:
	var state = State.new()
	_check(state.helper_levels.values().all(func(level): return level == 0), "new farms own no imaginary installations")
	_check(state.home_cycle() == 30.0 and state.home_income() == 14 and state.harvest_capacity() == 1, "an unequipped farm retains its original safe growth and income")
	var roster: Array = state.battle_templates()
	var nettle: Dictionary = state.plant_data("nettle", 7)
	var before: int = state.coins
	_check(not state.upgrade_helper("unknown") and state.coins == before, "unknown installations cannot spend or create money")
	state.coins = 89
	_check(not state.can_upgrade_helper("irrigation") and not state.upgrade_helper("irrigation") and state.coins == 89, "an unaffordable build is rejected atomically")
	state.coins = 90
	_check(state.upgrade_helper("irrigation") and state.helper_level("irrigation") == 1 and state.coins == 0, "building once charges exactly the first tier price")
	state.earn(100000)
	for id in Helpers.ORDER:
		while state.helper_level(id) < Helpers.MAX_LEVEL:
			var level_before: int = state.helper_level(id)
			var wallet: int = state.coins
			var price: int = state.helper_upgrade_cost(id)
			_check(state.upgrade_helper(id) and state.helper_level(id) == level_before + 1 and state.coins == wallet - price, "each installation progresses one paid level: " + id)
		var capped_wallet: int = state.coins
		_check(state.helper_upgrade_cost(id) == 0 and not state.upgrade_helper(id) and state.coins == capped_wallet, "maximum tier cannot charge again: " + id)
	_check(state.home_cycle() == 21.0 and state.home_income() == 18 and state.harvest_capacity() == 4, "maximum conveniences have bounded independent effects")
	_check(state.battle_templates() == roster and state.plant_data("nettle", 7) == nettle, "garden equipment never changes paid deployment, weapons or battle templates")


func _test_irrigation_progress() -> void:
	var state = _rich_state()
	state.tick(15.0)
	_check(is_equal_approx(state.home_growth_fraction(), 0.5), "a partial crop has measurable actual progress")
	_check(state.upgrade_helper("irrigation") and not state.home_ready and is_equal_approx(state.home_elapsed, 13.5), "buying irrigation preserves the halfway-grown crop")
	state.tick(13.4)
	_check(not state.home_ready, "irrigation does not grant an early harvest from the old elapsed time")
	state.tick(0.11)
	_check(state.home_ready and state.stored_harvests() == 1 and state.collectable_home_income() == 14, "the remaining shortened cycle ripens exactly one real harvest")
	_check(state.upgrade_helper("irrigation") and state.home_ready and state.collectable_home_income() == 14 and state.home_elapsed == 24.0, "upgrading irrigation while ripe preserves its crop and complete-cycle marker")
	_check(state.save_game(save_path), "a shortened ripe cycle saves")
	var restored = State.new()
	_check(restored.load_game(save_path) and restored.home_cycle() == 24.0 and restored.home_ready, "a ripe irrigated harvest reloads without the old thirty-second invariant")
	_check(restored.collect_home() == 14 and restored.collect_home() == 0, "a ripe irrigated harvest still pays once")
	state = _rich_state()
	state.home_ready = true
	state.home_elapsed = 30.0
	_check(state.upgrade_helper("irrigation") and state.stored_harvests() == 1 and state.collectable_home_income() == 14 and state.home_elapsed == 27.0, "legacy ready-flag callers are preserved when irrigation is built")


func _test_banked_value_and_partial_collection() -> void:
	var state = _rich_state()
	state.tick(30.0)
	_check(state.upgrade_helper("harvest_crate") and state.stored_harvests() == 1 and state.home_elapsed == 0.0, "building storage beside a full basket starts only the NEXT growth cycle")
	state.tick(10.0)
	_check(state.stored_harvests() == 1 and not is_equal_approx(state.home_elapsed, 0.0), "additional storage accumulates growth beside a ready harvest")
	_check(state.upgrade_helper("compost") and state.home_income() == 15 and state.collectable_home_income() == 14, "new compost improves future crops rather than multiplying banked money")
	_check(state.upgrade_plot("home", 0) and state.collectable_home_income() == 14, "a later planting upgrade cannot rewrite the value of an already stored harvest")
	_check(state.collect_home() == 14 and is_equal_approx(state.home_elapsed, 10.0) and not state.home_ready, "collecting a partial store preserves the next crop's unfinished growth")
	state.tick(20.0)
	_check(state.collectable_home_income() == state.home_income() and state.home_income() == 17, "the next actual crop earns its upgraded current yield")
	state.tick(30.0)
	_check(state.stored_harvests() == 2 and state.collectable_home_income() == 34, "two newly grown yields are added exactly once")
	state.upgrade_helper("compost")
	_check(state.collectable_home_income() == 34, "another compost upgrade also preserves both banked harvests")


func _test_storage_limits() -> void:
	var state = _rich_state()
	for index in range(3): state.upgrade_helper("harvest_crate")
	state.tick(1000000.0)
	_check(state.stored_harvests() == 4 and state.collectable_home_income() == 56 and state.home_elapsed == 30.0, "a huge delta cannot exceed four unpaid harvests")
	state.tick(1000000.0)
	_check(state.collectable_home_income() == 56, "a full store pauses instead of generating infinite accumulated money")
	var wallet: int = state.coins
	_check(state.collect_home() == 56 and state.coins == wallet + 56 and state.home_elapsed == 0.0, "the bounded stock pays in one explicit collection")
	_check(state.collect_home() == 0, "collecting an emptied crate cannot duplicate the stock")
	for invalid in [NAN, INF, -1.0, 0.0]:
		state.tick(invalid)
		_check(state.home_elapsed == 0.0 and state.stored_harvests() == 0, "invalid or empty time does not grow or damage the garden")
	state.home_plots.fill("")
	state.tick(1000000.0)
	_check(state.stored_harvests() == 0, "equipment with no real productive plants cannot create a harvest")


func _test_persistence_and_migration() -> void:
	var state = _rich_state()
	state.claim_stage_reward(1)
	state.plant_plot("pond", 0, "waterlily")
	state.upgrade_plot("pond", 0)
	state.upgrade_helper("harvest_crate")
	state.upgrade_helper("harvest_crate")
	state.upgrade_helper("irrigation")
	state.upgrade_helper("compost")
	state.session_data = {"camera": Vector2(123, 456), "battle": {"phase":"paused", "supplies":123}}
	state.tick(61.0)
	var expected_value: int = state.collectable_home_income()
	_check(state.stored_harvests() == 2 and is_equal_approx(state.home_elapsed, 7.0), "the fixture contains real stock beside a partially grown next crop")
	_check(state.save_game(save_path), "a non-full store and all equipment levels save atomically")
	var restored = State.new()
	_check(restored.load_game(save_path), "the new schema reloads its actual bank and helper levels")
	_check(restored.helper_levels == state.helper_levels and restored.home_stock == 2 and restored.home_stock_value == expected_value and restored.home_elapsed == 7.0, "all helper and partial-crop state survives reload exactly")
	_check(restored.home_plots == state.home_plots and restored.home_levels == state.home_levels and restored.pond_plots == state.pond_plots and restored.pond_levels == state.pond_levels and restored.session_data == state.session_data, "equipment persistence preserves paid plantings and the exact optional battle checkpoint")
	_check(restored.collect_home() == expected_value and restored.home_elapsed == 7.0, "reloading stock cannot replay growth or lose the unfinished next crop")
	# A v4 payload carries no helpers. It must not grant construction, seeds or
	# change the old crop/weapon identities while adopting one ready harvest.
	var legacy = State.new()
	legacy.tick(30.0)
	legacy.save_game(save_path)
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	payload["home_plots"] = payload["home_plots"].slice(0, State.HISTORIC_HOME_PLOT_COUNT)
	payload["home_levels"] = payload["home_levels"].slice(0, State.HISTORIC_HOME_PLOT_COUNT)
	payload["nursery_plots"] = payload["nursery_plots"].slice(0, State.HISTORIC_NURSERY_PLOT_COUNT)
	payload["nursery_levels"] = payload["nursery_levels"].slice(0, State.HISTORIC_NURSERY_PLOT_COUNT)
	payload["version"] = 4
	for key in ["helper_levels", "home_stock", "home_stock_value"]: payload.erase(key)
	_write(payload)
	_check(restored.load_game(save_path) and restored.helper_levels.values().all(func(level): return level == 0), "v4 migrates without granting or buying any installation")
	_check(restored.home_stock == 1 and restored.collectable_home_income() == 14 and restored.home_elapsed == 30.0, "a legacy ready flag migrates as one genuine ready harvest")
	_check(restored.coins == legacy.coins and restored.home_plots == legacy.home_plots and restored.nursery_levels == legacy.nursery_levels and restored.unlocked_seeds == legacy.unlocked_seeds, "legacy migration preserves wallet, crops, weapons and discovered seeds")
	_check(restored.collect_home() == 14 and restored.collect_home() == 0, "a migrated ready harvest cannot be collected twice")


func _test_invalid_saves_are_atomic() -> void:
	var state = _rich_state()
	state.upgrade_helper("irrigation")
	state.upgrade_helper("harvest_crate")
	state.tick(35.0)
	state.save_game(save_path)
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	var invalid: Array[Dictionary] = []
	for value in [-1, 4, 0.5, "1"]:
		var payload: Dictionary = valid.duplicate(true)
		payload["helper_levels"]["irrigation"] = value
		invalid.append(payload)
	var missing: Dictionary = valid.duplicate(true)
	missing["helper_levels"].erase("compost")
	invalid.append(missing)
	var extra: Dictionary = valid.duplicate(true)
	extra["helper_levels"]["free_money"] = 3
	invalid.append(extra)
	for entry in [["home_stock",3],["home_stock",-1],["home_stock_value",-1],["home_ready",false],["home_elapsed",27.0],["home_elapsed",-1.0]]:
		var payload: Dictionary = valid.duplicate(true)
		payload[entry[0]] = entry[1]
		invalid.append(payload)
	var original_helpers: Dictionary = state.helper_levels.duplicate()
	var original_wallet: int = state.coins
	var original_bank: int = state.home_stock_value
	for payload in invalid:
		_write(payload)
		_check(not state.load_game(save_path), "malformed helper or harvest fields fail validation")
		_check(state.coins == original_wallet and state.helper_levels == original_helpers and state.home_stock_value == original_bank and state.home_stock == 1 and state.home_elapsed == 8.0, "an invalid helper save cannot partly replace any live garden progress")


func _write(payload: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
