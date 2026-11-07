extends SceneTree

## The layout appends empty land without changing any paid source identity.
const State = preload("res://scripts/garden_state.gd")
const Battle = preload("res://scripts/battle_sim.gd")
const Layout = preload("res://scripts/field_layout.gd")
var checks: int = 0
var failures: int = 0
var save_path: String


func expect(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(reason)


func write_payload(payload: Dictionary) -> void:
	var file := FileAccess.open(save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()


func snapshot(state) -> Dictionary:
	var result: Dictionary = {}
	for field in ["coins","completed_level","levels","home_plots","home_levels","nursery_plots","nursery_levels","pond_plots","pond_levels","unlocked_seeds","helper_levels","home_stock","home_stock_value","home_elapsed","home_ready","session_data"]:
		var value = state.get(field)
		result[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result


func _initialize() -> void:
	save_path = "/private/tmp/planta2-square-bed-state-%d.json" % OS.get_process_id()
	var original := State.new()
	expect(State.SAVE_VERSION == 7,"square beds have their own explicit save version")
	expect(original.home_plot_capacity() == 144 and original.nursery_plot_capacity() == 144,"four full 6 by 6 squares are real planting places")
	expect(original.home_plots.slice(3).all(func(kind): return kind == "") and original.nursery_plots.all(func(kind): return kind == ""),"new ground never invents crops or defenders")
	for stage in range(1,4): original.claim_stage_reward(stage)
	original.coins = 500000
	for slot in range(96):
		original.home_plots[slot] = ["cucumber","mint","pumpkin"][slot%3]
		original.home_levels[slot] = 1+slot%20
		original.nursery_plots[slot] = ["nettle","lavender","pepper"][slot%3]
		original.nursery_levels[slot] = 1+slot%20
	original.nursery_plots[95] = "pepper"
	original.nursery_levels[95] = 20
	original.pond_plots[5] = "lotus"
	original.pond_levels[5] = 15
	original.helper_levels = {"irrigation":2,"compost":1,"harvest_crate":2}
	original.home_elapsed = 7.0
	var battle := Battle.new()
	battle.configure(original,Layout.battle_route(),Layout.battle_plots(),1)
	expect(battle.select_loadout(["pepper","pumpkin"]) and battle.plant(0,"pepper"),"fixture contains a paid live battle placement")
	original.session_data = {"version":1,"camera_center":Vector2(2112,688),"camera_zoom":0.6,"battle":battle.export_snapshot()}
	var old_roster: Array = original.battle_roster()
	var old_income: int = original.home_income()
	var before: Dictionary = snapshot(original)
	expect(original.save_game(save_path),"isolated fixture saves atomically")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	payload["version"] = 6
	for name in ["home_plots","home_levels","nursery_plots","nursery_levels"]: payload[name] = payload[name].slice(0,96)
	write_payload(payload)
	var restored := State.new()
	expect(restored.load_game(save_path),"exact old 96 by 96 version-six save loads")
	for field in before:
		expect(restored.get(field) == before[field],"migration preserves " + field)
	for area in ["home","nursery"]:
		for slot in range(96):
			expect(restored.plot_kind(area,slot) == original.plot_kind(area,slot) and restored.plot_level(area,slot) == original.plot_level(area,slot),"paid area:slot identity and level survive")
		for slot in range(96,144):
			expect(restored.is_plot_unlocked(area,slot) and restored.plot_kind(area,slot) == "" and restored.plot_level(area,slot) == 1,"appended cells are empty editable level-one ground")
	expect(restored.home_income() == old_income and restored.battle_roster() == old_roster,"expanded empty land changes neither earned income nor battle sources")
	var resumed := Battle.new()
	expect(resumed.restore_snapshot(restored,Layout.battle_route(),Layout.battle_plots(),restored.session_data["battle"]),"active battle resumes after layout migration")
	expect(resumed.get_plant(0).get("source_id") == battle.get_plant(0).get("source_id") and resumed.get_plant(0).get("level") == 20,"paid deployment retains source and level")
	expect(restored.plant_plot("home",143,"cucumber") and restored.plant_plot("nursery",143,"nettle"),"the last cell of each new square accepts normal paid planting")
	expect(restored.save_game(save_path),"version-seven state saves atomically")
	var round_trip := State.new()
	expect(round_trip.load_game(save_path) and snapshot(round_trip) == snapshot(restored),"version-seven round trip preserves all new and migrated sources")
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	var baseline: Dictionary = snapshot(restored)
	for mutation in ["v6_144","v7_96","short","empty_level","water_on_land"]:
		var invalid: Dictionary = valid.duplicate(true)
		match mutation:
			"v6_144": invalid["version"] = 6
			"v7_96":
				for name in ["home_plots","home_levels","nursery_plots","nursery_levels"]: invalid[name] = invalid[name].slice(0,96)
			"short": invalid["home_plots"].pop_back(); invalid["home_levels"].pop_back()
			"empty_level": invalid["home_levels"][142] = 2
			"water_on_land": invalid["home_plots"][142] = "lotus"
		write_payload(invalid)
		expect(not restored.load_game(save_path) and snapshot(restored) == baseline,"invalid save rejects without partial mutation: " + mutation)
	# Older schemas still run through their original shape and unlock validation.
	for version in [1,2,3,4,5]:
		var historic: Dictionary = payload.duplicate(true)
		historic["version"] = version
		var home_count: int = 24 if version >= 3 else 12
		var nursery_count: int = 12 if version >= 3 else 8
		for name in ["home_plots","home_levels"]: historic[name] = historic[name].slice(0,home_count)
		for name in ["nursery_plots","nursery_levels"]: historic[name] = historic[name].slice(0,nursery_count)
		if version < 4:
			historic["home_elapsed"] = 0.0
			historic["home_ready"] = false
		write_payload(historic)
		var legacy := State.new()
		expect(legacy.load_game(save_path),"legacy schema %d still migrates" % version)
		expect(legacy.home_plots.size() == 144 and legacy.nursery_plots.size() == 144,"legacy schema expands to complete squares")
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(save_path+".tmp")
	print("Square bed state: ",checks," checks; ",failures," failures")
	quit(0 if failures == 0 else 1)
