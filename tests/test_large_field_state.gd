extends SceneTree

## Real paid records keep their area:slot identity while their world placement
## moves into the two 144-cell fields. All files here are isolated fixtures.
const State = preload("res://scripts/garden_state.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Battle = preload("res://scripts/battle_sim.gd")
const Layout = preload("res://scripts/field_layout.gd")
var checks: int = 0
var failures: int = 0
var save_path: String


func _initialize() -> void:
	save_path = "/private/tmp/planta2-large-field-state-%d.json" % OS.get_process_id()
	_check_live_fields()
	_check_paid_v5_migration()
	_check_legacy_versions()
	_check_atomic_rejection()
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(save_path + ".tmp")
	print("Large field state: ", checks, " checks; ", failures, " failures")
	quit(0 if failures == 0 else 1)


func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func write_payload(payload: Dictionary) -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()


func payload_for(state) -> Dictionary:
	expect(state.save_game(save_path), "fixture saves through the atomic writer")
	return JSON.parse_string(FileAccess.get_file_as_string(save_path))


func snapshot(state) -> Dictionary:
	var result: Dictionary = {}
	for field in ["coins","completed_level","levels","home_plots","home_levels","nursery_plots","nursery_levels","pond_plots","pond_levels","unlocked_seeds","helper_levels","home_stock","home_stock_value","home_elapsed","home_ready","session_data"]:
		var value = state.get(field)
		result[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result


func expanded_fixture():
	var state := State.new()
	for stage in range(1,4): state.claim_stage_reward(stage)
	state.coins = 123456
	for record in [[8,"cucumber",7],[9,"currant",15],[10,"mint",5],[11,"strawberry",8],[12,"strawberry",9],[16,"mint",12],[20,"pumpkin",7],[23,"pumpkin",20]]:
		state.home_plots[record[0]] = record[1]
		state.home_levels[record[0]] = record[2]
	state.nursery_plots[11] = "pepper"
	state.nursery_levels[11] = 15
	state.pond_plots[0] = "waterlily"
	state.pond_levels[0] = 7
	state.helper_levels = {"irrigation":2,"compost":1,"harvest_crate":1}
	state.home_ready = true
	state.home_stock = 2
	state.home_stock_value = 987
	state.home_elapsed = state.home_cycle()
	return state


func legacy_v5_payload(state) -> Dictionary:
	var payload: Dictionary = payload_for(state)
	payload["version"] = 5
	payload["home_plots"] = payload["home_plots"].slice(0,24)
	payload["home_levels"] = payload["home_levels"].slice(0,24)
	payload["nursery_plots"] = payload["nursery_plots"].slice(0,12)
	payload["nursery_levels"] = payload["nursery_levels"].slice(0,12)
	return payload


func _check_live_fields() -> void:
	var state := State.new()
	expect(State.SAVE_VERSION == 7, "expanded fields use an explicit version-seven save schema")
	expect(state.home_plot_capacity() == 144 and state.nursery_plot_capacity() == 144, "both districts provide 144 real editable cells from the start")
	expect(state.home_plots.size() == 144 and state.nursery_plots.size() == 144, "saved arrays contain every available planting")
	expect(state.home_plots.slice(3).all(func(kind): return kind == "") and state.nursery_plots.all(func(kind): return kind == ""), "newly available ground invents no grown plants")
	expect(state.home_levels.all(func(level): return level == 1) and state.nursery_levels.all(func(level): return level == 1), "empty new cells start at level one")
	var initial_roster: Array = state.battle_roster()
	expect(initial_roster.size() == 3, "large empty fields add no imaginary battle sources")
	for slot in range(144):
		expect(state.plot_district("home",slot) == "garden" and state.is_plot_unlocked("home",slot), "all income cells belong to the first district")
		expect(state.plot_district("nursery",slot) == "nursery" and state.is_plot_unlocked("nursery",slot), "all defender cells belong to the second district")
	expect(state.plot_district("home",144).is_empty() and not state.is_plot_unlocked("nursery",144), "new field bounds reject phantom cell 145")
	expect(state.plot_count("greenhouse") == 0 and state.allowed_kinds("greenhouse").is_empty() and not state.can_plant("greenhouse",0,"cucumber"), "the greenhouse offers no planting area")
	expect(state.allowed_kinds("home",143) == ["tomato","marigold","pumpkin","cucumber","strawberry","currant","mint"], "all seven dry economic species can grow in the first district")
	expect(state.allowed_kinds("nursery",143) == ["nettle","lavender","pepper"], "all three dry defenders can grow in the second district")
	state.coins = 100000
	expect(state.plant_plot("home",143,"cucumber") and state.plant_plot("nursery",143,"nettle"), "the farthest new cells accept genuine paid plantings")
	expect(state.pond_plot_capacity() == 0 and not state.can_plant("pond",0,"waterlily"), "water cells still require the first campaign victory")
	var first_reward: Dictionary = state.claim_stage_reward(1)
	expect(first_reward["pond_plots"] == 6 and first_reward["districts"] == ["nursery"], "the first victory opens the nursery's six water cells")
	expect(state.plot_info("pond",0)["parent_district"] == "nursery" and state.plot_info("pond",0)["district_name"] == "Питомник · Водные грядки", "water habitats explicitly belong to the nursery")
	expect(state.plant_plot("pond",5,"lotus"), "water source identity remains pond:5 after the world relocation")
	expect(not state.can_plant("home",142,"lotus") and not state.can_plant("nursery",142,"waterlily") and not state.can_plant("pond",1,"cucumber"), "expanded fields preserve dry-versus-water habitat rules")
	for stage in range(2,4):
		var reward: Dictionary = state.claim_stage_reward(stage)
		expect(reward["home_plots"] == 0 and reward["nursery_plots"] == 0 and state.home_plot_capacity() == 144 and state.nursery_plot_capacity() == 144, "campaign progression never manufactures another hidden field")
	for pair in [["home",138,"strawberry"],["home",139,"currant"],["home",140,"mint"],["home",141,"pumpkin"],["nursery",141,"pepper"]]:
		expect(state.plant_plot(pair[0],pair[1],pair[2]), "all newly unlocked seeds remain growable in the two fields")


func _check_paid_v5_migration() -> void:
	var original = expanded_fixture()
	var battle := Battle.new()
	battle.configure(original,Layout.battle_route(),Layout.battle_plots(),1)
	expect(battle.select_loadout(["pepper","pumpkin"]) and battle.plant(0,"pepper"), "migration fixture contains an actual paid defender in an active battle")
	original.session_data = {"version":1,"camera_center":Vector2(1296,1872),"camera_zoom":0.8,"battle":battle.export_snapshot()}
	var payload: Dictionary = legacy_v5_payload(original)
	var before: Dictionary = snapshot(original)
	var before_roster: Array = original.battle_roster()
	var income: int = original.home_income()
	write_payload(payload)
	var restored := State.new()
	expect(restored.load_game(save_path), "the exact old 24/12/6 version-five shape still loads")
	for field in ["coins","completed_level","levels","unlocked_seeds","helper_levels","home_stock","home_stock_value","home_elapsed","home_ready","session_data"]:
		expect(restored.get(field) == before[field], "version-five migration preserves " + field)
	for slot in range(24):
		expect(restored.home_plots[slot] == before["home_plots"][slot] and restored.home_levels[slot] == before["home_levels"][slot], "every paid income ID keeps its exact kind and level")
	for slot in range(12):
		expect(restored.nursery_plots[slot] == before["nursery_plots"][slot] and restored.nursery_levels[slot] == before["nursery_levels"][slot], "every paid defender ID keeps its exact kind and level")
	expect(restored.pond_plots == before["pond_plots"] and restored.pond_levels == before["pond_levels"], "water records retain their exact identities and levels")
	expect(restored.home_plots.slice(24).all(func(kind): return kind == "") and restored.home_levels.slice(24).all(func(level): return level == 1), "migration appends empty level-one income ground only")
	expect(restored.nursery_plots.slice(12).all(func(kind): return kind == "") and restored.nursery_levels.slice(12).all(func(level): return level == 1), "migration appends empty level-one defender ground only")
	expect(restored.home_income() == income and restored.battle_roster() == before_roster, "new empty slots do not alter actual yield or grown battle sources")
	for slot in [8,9,10,11,12,16,20,23]: expect(restored.is_plot_unlocked("home",slot) and restored.plot_district("home",slot) == "garden", "former greenhouse and archived income cells become editable in the first field")
	expect(restored.is_plot_unlocked("nursery",11), "an archived paid defender becomes visible and editable in the second field")
	var resumed := Battle.new()
	expect(resumed.restore_snapshot(restored,Layout.battle_route(),Layout.battle_plots(),restored.session_data["battle"]), "saved combat resumes against unchanged area:slot source identities")
	expect(resumed.get_plant(0).get("source_id") == "nursery:11" and resumed.get_plant(0).get("level") == 15, "resuming preserves the original battle defender and paid level")
	expect(restored.upgrade_plot("home",8) and restored.upgrade_plot("nursery",11), "transferred former greenhouse and archive plantings retain normal upgrade actions")
	expect(restored.plant_plot("home",143,"cucumber") and restored.plant_plot("nursery",143,"nettle"), "migrated saves can purchase the new farthest ground")
	var full_before: Dictionary = snapshot(restored)
	var v7: Dictionary = payload_for(restored)
	expect(v7["version"] == 7 and v7["home_plots"].size() == 144 and v7["nursery_plots"].size() == 144, "the next atomic save writes the complete new schema")
	var reloaded := State.new()
	expect(reloaded.load_game(save_path) and snapshot(reloaded) == full_before, "version-seven round trip preserves every paid and empty slot exactly")


func _check_legacy_versions() -> void:
	for version in [1,2,3,4]:
		var original = expanded_fixture() if version >= 3 else State.new()
		var payload: Dictionary = legacy_v5_payload(original)
		payload["version"] = version
		payload["home_elapsed"] = 30.0 if version >= 3 else 0.0
		payload["home_ready"] = version >= 3
		if version <= 2:
			payload["home_plots"] = payload["home_plots"].slice(0,12)
			payload["home_levels"] = payload["home_levels"].slice(0,12)
			payload["nursery_plots"] = payload["nursery_plots"].slice(0,8)
			payload["nursery_levels"] = payload["nursery_levels"].slice(0,8)
		if version == 1:
			payload["levels"]["nettle"] = 7
			payload["home_plots"] = payload["home_plots"].slice(0,6)
		write_payload(payload)
		var restored := State.new()
		expect(restored.load_game(save_path), "legacy version %d loads before appending new ground" % version)
		expect(restored.home_plots.size() == 144 and restored.nursery_plots.size() == 144, "legacy version %d migrates to two complete fields" % version)
		expect(restored.home_plots[0] == "tomato" and restored.home_levels[0] == int(payload["levels"]["tomato"] if version == 1 else payload["home_levels"][0]), "legacy version %d preserves the original crop level" % version)
		if version == 1: expect(restored.nursery_plots[0] == "nettle" and restored.nursery_levels[0] == 7, "version-one paid catalog upgrades still become one real defender")
		if version >= 3: expect(restored.home_plots[23] == "pumpkin" and restored.home_levels[23] == 20, "older expanded saves keep their last paid income record")
		if version < 4: expect(restored.pond_plots.all(func(kind): return kind == ""), "pre-water saves do not gain decorative grown water crops")


func _check_atomic_rejection() -> void:
	var state := State.new()
	state.coins = 100000
	expect(state.plant_plot("home",143,"cucumber") and state.plant_plot("nursery",143,"nettle"), "fresh version-seven saves can use far cells before any victory")
	var payload: Dictionary = payload_for(state)
	var before: Dictionary = snapshot(state)
	for corruption in ["short_array","empty_upgraded","aquatic_on_land","bad_level"]:
		var malformed: Dictionary = payload.duplicate(true)
		match corruption:
			"short_array": malformed["home_plots"].pop_back(); malformed["home_levels"].pop_back()
			"empty_upgraded": malformed["home_levels"][142] = 2
			"aquatic_on_land": malformed["home_plots"][142] = "lotus"
			"bad_level": malformed["nursery_levels"][143] = 21
		write_payload(malformed)
		expect(not state.load_game(save_path) and snapshot(state) == before, "invalid expanded data rejects atomically: " + corruption)
	var historic: Dictionary = legacy_v5_payload(expanded_fixture())
	historic["completed_level"] = 0
	historic["pond_plots"].fill("")
	historic["pond_levels"].fill(1)
	write_payload(historic)
	expect(not state.load_game(save_path) and snapshot(state) == before, "old locked tail records still obey their original campaign validation")
