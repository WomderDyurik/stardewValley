extends SceneTree

const State = preload("res://scripts/garden_state.gd")
const Catalog = preload("res://scripts/catalog.gd")
const CampaignData = preload("res://scripts/campaign.gd")
var checks: int = 0
var failures: int = 0
var test_save: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	test_save = "/private/tmp/planta2-district-state-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	_test_regions_and_gates()
	_test_pond_and_battle()
	_test_v3_migration()
	_test_malformed_water_saves()
	DirAccess.remove_absolute(test_save)
	DirAccess.remove_absolute(test_save + ".tmp")
	print("District planting and migration: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _test_regions_and_gates() -> void:
	var state := State.new()
	state.coins = 10000
	_expect(state.pond_plots.size() == 6 and state.pond_plots.all(func(kind): return kind == ""), "Pond begins with actual empty positions, not decorative plant ownership")
	_expect(state.pond_plot_capacity() == 0 and not state.is_district_unlocked("pond"), "Water planting is a first-victory discovery")
	_expect(state.is_seed_unlocked("cucumber") and state.allowed_kinds("home",8) == ["cucumber"], "Greenhouse starts with its own plant choice")
	_expect(not state.plant_plot("pond",0,"waterlily") and not state.plant_plot("home",12,"strawberry"), "Money cannot bypass locked habitats or regional seeds")
	var reward: Dictionary = state.claim_stage_reward(1)
	_expect(reward["districts"] == ["berry","pond"] and reward["pond_plots"] == 6 and state.pond_plot_capacity() == 6, "First victory opens the berry patch and six real water positions")
	_expect(state.is_seed_unlocked("lotus") and state.is_seed_unlocked("waterlily") and not state.is_seed_unlocked("mint"), "Pond and berry discoveries precede the remote garden")
	state.claim_stage_reward(2)
	state.claim_stage_reward(3)
	var cases: Array = [
		["home",0,"garden",["tomato","marigold"]],
		["home",8,"greenhouse",["cucumber"]],
		["home",12,"berry",["strawberry","currant"]],
		["home",16,"far_garden",["mint"]],
		["home",20,"sun_meadow",["pumpkin"]],
		["nursery",0,"nursery",["nettle","lavender"]],
		["nursery",8,"far_garden",["pepper"]],
		["nursery",10,"sun_meadow",["pepper"]],
		["pond",0,"pond",["waterlily","lotus"]],
	]
	for entry in cases:
		var info: Dictionary = state.plot_info(entry[0],entry[1])
		_expect(info["district"] == entry[2] and info["allowed_kinds"] == entry[3], "Regional planting offer matches its location")
		_expect(info["habitat"] == ("water" if entry[0] == "pond" else "dry") and info["unlocked"], "Every offer identifies its habitat and actual unlocked state")
		for kind in Catalog.ORDER:
			var expected: bool = entry[3].has(kind)
			_expect(state.can_plant(entry[0],entry[1],kind,true) == expected if not state.plot_kind(entry[0],entry[1]).is_empty() and state.plot_kind(entry[0],entry[1]) != kind else state.can_plant(entry[0],entry[1],kind) == (expected and state.plot_kind(entry[0],entry[1]).is_empty()), "A species cannot be bought into the wrong region")
	_expect(state.plant_plot("home",8,"cucumber") and state.plant_plot("home",12,"strawberry") and state.plant_plot("home",16,"mint") and state.plant_plot("home",20,"pumpkin"), "Every discovered district supports its own real planting")
	var before: Dictionary = _snapshot(state)
	for command in [["home",9,"tomato"],["home",13,"mint"],["nursery",1,"pepper"],["nursery",8,"nettle"],["home",9,"waterlily"],["pond",0,"tomato"]]:
		_expect(not state.plant_plot(command[0],command[1],command[2]) and _snapshot(state) == before, "Wrong region or habitat rejects a purchase atomically")
	var choices: Array[String] = state.allowed_kinds("pond",0)
	choices.clear()
	_expect(state.allowed_kinds("pond",0) == ["waterlily","lotus"] and state.plot_info("pond",6).is_empty(), "Offer snapshots cannot mutate rules and invalid positions remain absent")

func _test_pond_and_battle() -> void:
	var state := State.new()
	state.coins = 100000
	state.claim_stage_reward(1)
	var initial_income: int = state.home_income()
	_expect(state.plant_plot("pond",0,"waterlily") and state.plant_plot("pond",1,"lotus"), "Both pond species can be actually planted after discovery")
	_expect(state.home_income() == initial_income + 10, "Only the planted water income species increases the shared harvest")
	_expect(state.upgrade_plot("pond",0) and state.pond_levels[0] == 2 and state.home_income() == initial_income + 12, "Water crop upgrades are individual and affect actual yield")
	state.pond_levels[1] = 7
	var roster: Array[Dictionary] = state.battle_roster()
	_expect(roster.any(func(unit): return unit["id"] == "pond:1" and unit["kind"] == "lotus" and unit["level"] == 7), "A grown water defender contributes its exact plot identity and level")
	var templates: Array[Dictionary] = state.battle_templates()
	_expect(templates.any(func(unit): return unit["kind"] == "lotus" and unit["habitat"] == "water" and unit["cost"] == 115), "The battle template carries the water habitat and temporary supply price")
	var battle := BattleSim.new()
	var path: Array[Vector2] = [Vector2.ZERO,Vector2(1000,0)]
	var plots: Array[Vector2] = [Vector2(100,30),Vector2(200,30)]
	battle.configure(state,path,plots)
	_expect(battle.select_loadout(["waterlily","lotus"]) and battle.plant(0,"waterlily") and battle.plant(1,"lotus"), "Water plants work in the existing paid battle composition")
	_expect(battle.get_plant(1)["level"] == 7 and battle.wave_income() == state.plant_data("waterlily",2)["battle_yield"], "Water battle levels and wave yield use their confirmed snapshots")
	state.pond_levels[1] = 8
	_expect(battle.get_plant(1)["level"] == 7, "Subsequent pond development cannot alter an existing battle")
	state.tick(State.HOME_CYCLE)
	var before: int = state.coins
	var harvest_amount: int = state.home_income()
	_expect(state.collect_home() == harvest_amount and state.coins == before + harvest_amount, "Collecting includes water yield exactly once")
	_expect(state.collect_home() == 0, "Repeated collection cannot duplicate pond income")
	_expect(state.save_game(test_save), "Expanded three-area garden saves atomically")
	var restored := State.new()
	_expect(restored.load_game(test_save) and _snapshot(restored) == _snapshot(state), "Water plantings and their levels round-trip without loss or phantom plants")

func _test_v3_migration() -> void:
	var old: Dictionary = {
		"version":3,"coins":713,"completed_level":3,"home_elapsed":12.5,"home_ready":false,
		"levels":{},"home_plots":[],"home_levels":[],"nursery_plots":[],"nursery_levels":[],
		"unlocked_seeds":["tomato","marigold","nettle","lavender","pepper","pumpkin"],
	}
	for kind in State.VERSION_THREE_KINDS: old["levels"][kind] = 1
	for slot in range(24):
		old["home_plots"].append("")
		old["home_levels"].append(1)
	for slot in range(12):
		old["nursery_plots"].append("")
		old["nursery_levels"].append(1)
	old["home_plots"][8] = "tomato"
	old["home_levels"][8] = 5
	old["home_plots"][12] = "marigold"
	old["home_levels"][12] = 4
	old["nursery_plots"][0] = "pepper"
	old["nursery_levels"][0] = 6
	old["nursery_plots"][9] = "nettle"
	old["nursery_levels"][9] = 3
	_write(old)
	var state := State.new()
	_expect(state.load_game(test_save), "A real version-three save with old mixed regional crops migrates")
	_expect(state.coins == 713 and state.home_elapsed == 12.5 and state.completed_level == 3, "Migration never charges the player or rewinds growth and discovery")
	_expect(state.home_plots == old["home_plots"] and state.home_levels == old["home_levels"] and state.nursery_plots == old["nursery_plots"] and state.nursery_levels == old["nursery_levels"], "Every paid existing position and individual level is retained")
	_expect(state.pond_plots.all(func(kind): return kind == "") and state.unlocked_seeds.size() == Catalog.ORDER.size(), "New habitats remain empty while already earned regional seeds become available")
	_expect(state.plot_upgrade_cost("nursery",0) > 0 and state.battle_templates().any(func(unit): return unit["kind"] == "pepper" and unit["level"] == 6), "Grandfathered defenders still upgrade and supply their paid battle level")
	state.coins = 100000
	_expect(state.upgrade_plot("nursery",0) and state.nursery_levels[0] == 7, "Out-of-profile legacy planting remains upgradeable")
	_expect(not state.plant_plot("home",9,"tomato") and not state.plant_plot("nursery",1,"pepper"), "Preserving legacy ownership cannot bypass the new planting rules")
	_expect(state.save_game(test_save), "A migrated version-three garden can save as version four")
	var restored := State.new()
	_expect(restored.load_game(test_save) and _snapshot(restored) == _snapshot(state), "Grandfathered crop locations survive the version-four round trip")
	var stable_snapshot: Dictionary = _snapshot(restored)
	for iteration in range(6):
		_expect(restored.save_game(test_save), "Repeated run can save the grandfathered greenhouse crop")
		var reloaded := State.new()
		_expect(reloaded.load_game(test_save) and _snapshot(reloaded) == stable_snapshot and reloaded.home_plots[8] == "tomato" and reloaded.home_levels[8] == 5, "Six repeated version-four runs preserve the paid old tomato and its exact greenhouse position")
		restored = reloaded
	_expect(restored.replace_plot("home",8,"cucumber") and not restored.replace_plot("home",8,"tomato"), "Replacing legacy crops adopts the current region without refund or loophole")

func _test_malformed_water_saves() -> void:
	var state := State.new()
	state.coins = 10000
	state.claim_stage_reward(1)
	state.plant_plot("pond",0,"waterlily")
	state.save_game(test_save)
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(test_save))
	var before: Dictionary = _snapshot(state)
	var variants: Array[Dictionary] = []
	for field in ["pond_plots","pond_levels"]:
		var missing: Dictionary = valid.duplicate(true)
		missing.erase(field)
		variants.append(missing)
		for value in ["bad",[],[1],{}]:
			var wrong: Dictionary = valid.duplicate(true)
			wrong[field] = value
			variants.append(wrong)
	for command in [["pond_plots",0,"tomato"],["home_plots",3,"waterlily"],["nursery_plots",0,"lotus"],["pond_levels",0,1.5],["pond_levels",1,2]]:
		var broken: Dictionary = valid.duplicate(true)
		broken[command[0]][command[1]] = command[2]
		variants.append(broken)
	for broken in variants:
		_write(broken)
		_expect(not state.load_game(test_save) and _snapshot(state) == before, "Malformed habitat data cannot partly replace any player state")

func _snapshot(state: GardenState) -> Dictionary:
	return {"coins":state.coins,"home":state.home_plots.duplicate(),"home_levels":state.home_levels.duplicate(),"nursery":state.nursery_plots.duplicate(),"nursery_levels":state.nursery_levels.duplicate(),"pond":state.pond_plots.duplicate(),"pond_levels":state.pond_levels.duplicate(),"levels":state.levels.duplicate(true),"seeds":state.unlocked_seeds.duplicate(),"progress":state.completed_level,"elapsed":state.home_elapsed,"ready":state.home_ready}

func _write(payload: Dictionary) -> void:
	var file := FileAccess.open(test_save,FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
