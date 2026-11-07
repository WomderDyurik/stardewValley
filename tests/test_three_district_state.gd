extends SceneTree

## Live land can shrink without deleting paid records or invalidating old saves.
const State = preload("res://scripts/garden_state.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Battle = preload("res://scripts/battle_sim.gd")
const Layout = preload("res://scripts/field_layout.gd")
var checks: int = 0
var failures: int = 0
var save_path: String


func _initialize() -> void:
	save_path = "/private/tmp/planta2-three-district-state-%d-%d.json" % [OS.get_process_id(),Time.get_ticks_usec()]
	_check_live_land_and_rewards()
	_check_existing_investments()
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(save_path+".tmp")
	print("Three district state: ",checks," checks; ",failures," failures")
	quit(0 if failures == 0 else 1)


func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _check_live_land_and_rewards() -> void:
	var state := State.new()
	state.coins = 100000
	expect(state.home_plots.size()==24 and state.nursery_plots.size()==12 and state.pond_plots.size()==6,"serialized planting arrays retain every old stable ID")
	expect(state.home_plot_capacity()==12 and state.nursery_plot_capacity()==8 and state.pond_plot_capacity()==0,"fresh games expose only the live dry land and a locked water subarea")
	for retired in ["berry","far_garden","sun_meadow"]:
		expect(Campaign.district_unlock_stage(retired)==-1 and not state.is_district_unlocked(retired),"retired districts are not unlockable: "+retired)
	for stage in range(1,4):
		var reward: Dictionary = state.claim_stage_reward(stage)
		expect(not reward.is_empty() and reward["first_clear"],"each sequential victory still grants its one-time seed discovery")
		expect(reward["home_plots"]==0 and reward["nursery_plots"]==0,"campaign rewards do not manufacture retired expansion land")
		expect(reward["district"] in ["garden","nursery","greenhouse"],"reward identity belongs to the three live districts")
		for id in reward["districts"]: expect(id in ["garden","nursery","greenhouse"],"reward navigation never links a removed district")
		expect(state.home_plot_capacity()==12 and state.nursery_plot_capacity()==8,"live dry land capacity stays constant after victories")
		expect(state.claim_stage_reward(stage).is_empty(),"repeated wins cannot repeat the permanent discovery")
		for slot in range(12,24):
			expect(not state.is_plot_unlocked("home",slot) and state.allowed_kinds("home",slot).is_empty(),"retired income slots stay unavailable after victories")
			expect(not state.plant_plot("home",slot,"strawberry"),"money and seeds cannot buy retired income land")
		for slot in range(8,12):
			expect(not state.is_plot_unlocked("nursery",slot) and not state.plant_plot("nursery",slot,"pepper"),"money and seeds cannot buy retired defender land")
	expect(state.pond_plot_capacity()==6 and state.plot_info("pond",0)["parent_district"]=="greenhouse","water gameplay remains a six-slot subarea of the greenhouse")
	expect(state.plot_info("pond",0)["district_name"]=="Теплица · Пруд","water planting labels explain their parent district")
	expect(state.allowed_kinds("home",0)==["tomato","marigold","pumpkin"],"the garden accepts its three current crops")
	expect(state.allowed_kinds("home",8)==["cucumber","strawberry","currant","mint"],"former expansion crops are offered in the greenhouse")
	expect(state.allowed_kinds("nursery",0)==["nettle","lavender","pepper"],"pepper remains growable in the live nursery")
	for pair in [["home",3,"pumpkin"],["home",8,"strawberry"],["home",9,"mint"],["nursery",0,"pepper"],["pond",0,"lotus"]]:
		expect(state.plant_plot(pair[0],pair[1],pair[2]),"every relocated seed can actually be planted in a compatible live slot")
	expect(not state.can_plant("home",1,"lotus") and not state.can_plant("pond",1,"cucumber"),"three districts do not relax dry and aquatic habitat rules")
	expect(Campaign.seed_unlock_stage("lavender")==1 and Campaign.seed_unlock_stage("pepper")==2 and Campaign.seed_unlock_stage("pumpkin")==3,"seed timing remains compatible with existing campaign saves")


func _check_existing_investments() -> void:
	var original := State.new()
	for stage in range(1,4): original.claim_stage_reward(stage)
	original.coins = 54321
	original.home_plots[12] = "strawberry"
	original.home_levels[12] = 9
	original.home_plots[16] = "mint"
	original.home_levels[16] = 12
	original.home_plots[20] = "pumpkin"
	original.home_levels[20] = 7
	original.nursery_plots[8] = "pepper"
	original.nursery_levels[8] = 15
	original.nursery_plots[10] = "pepper"
	original.nursery_levels[10] = 20
	original.pond_plots[0] = "waterlily"
	original.pond_levels[0] = 5
	expect(original.home_income()==166,"paid retired crops retain their exact yield alongside live crops and water plants")
	var pepper: Dictionary = {}
	for template in original.battle_templates():
		if template["kind"]=="pepper": pepper = template
	expect(pepper.get("level")==20 and pepper.get("source_id")=="nursery:10","the best paid retired defender remains the real battle template source")
	var battle := Battle.new()
	battle.configure(original,Layout.battle_route(),Layout.battle_plots(),1)
	expect(battle.select_loadout(["pepper"]) and battle.plant(0,"pepper"),"a paid archived source can still be deployed with its preserved level")
	original.session_data = {"version":1,"camera_center":Vector2(1296,1872),"camera_zoom":0.8,"battle":battle.export_snapshot()}
	var before_home: Array = original.home_plots.duplicate()
	var before_levels: Array = original.home_levels.duplicate()
	var before_nursery: Array = original.nursery_plots.duplicate()
	var before_nursery_levels: Array = original.nursery_levels.duplicate()
	expect(original.save_game(save_path),"a valid expanded v5 save can still be written atomically")
	var restored := State.new()
	var loaded: bool = restored.load_game(save_path)
	expect(loaded,"a fully paid expanded v5 save still passes legacy capacity validation")
	if not loaded: return
	expect(restored.coins==54321 and restored.home_plots==before_home and restored.home_levels==before_levels,"loading preserves the wallet and every income planting/level")
	expect(restored.nursery_plots==before_nursery and restored.nursery_levels==before_nursery_levels,"loading preserves all paid defender identities and levels")
	expect(restored.home_income()==166 and restored.session_data==original.session_data,"yield and the active battle checkpoint survive the normal reader unchanged")
	var resumed := Battle.new()
	expect(resumed.restore_snapshot(restored,Layout.battle_route(),Layout.battle_plots(),restored.session_data["battle"]),"the battle validator still accepts a snapshot whose paid source is archived")
	expect(resumed.get_plant(0).get("source_id")=="nursery:10" and resumed.get_plant(0).get("level")==20,"resuming does not replace the archived source or reduce its level")
	var emptied := State.new()
	expect(emptied.load_game(save_path),"the source-rejection fixture begins with the same valid legacy save")
	emptied.nursery_plots[10] = ""
	emptied.nursery_levels[10] = 1
	var unavailable := Battle.new()
	expect(not unavailable.restore_snapshot(emptied,Layout.battle_route(),Layout.battle_plots(),restored.session_data["battle"]),"an empty archived slot cannot impersonate a paid checkpoint source")
	var live_before: Dictionary = resumed.export_snapshot()
	for forged_slot in [-1,State.NURSERY_PLOT_COUNT,999]:
		var forged: Dictionary = original.session_data["battle"].duplicate(true)
		forged["values"]["loadout"][0]["slot"] = forged_slot
		forged["values"]["loadout"][0]["source_id"] = "nursery:%d" % forged_slot
		forged["values"]["plants"][0]["source_id"] = "nursery:%d" % forged_slot
		expect(not resumed.restore_snapshot(restored,Layout.battle_route(),Layout.battle_plots(),forged),"archived-source compatibility never accepts a forged source index")
		expect(resumed.export_snapshot()==live_before,"rejected source indices cannot partially mutate the resumed battle")
	for pair in [["home",12,"currant"],["home",16,"pumpkin"],["nursery",8,"nettle"],["nursery",10,"lavender"]]:
		expect(not restored.replace_plot(pair[0],pair[1],pair[2]) and not restored.upgrade_plot(pair[0],pair[1]),"archived paid records cannot be changed through hidden replacement or upgrade calls")
	expect(restored.coins==54321 and restored.home_levels==before_levels and restored.nursery_levels==before_nursery_levels,"rejected archive purchases do not charge coins or mutate levels")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	payload["version"] = 3
	var file := FileAccess.open(save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	var old_reader := State.new()
	expect(old_reader.load_game(save_path),"version-three expanded planting records migrate through the original reader")
	expect(old_reader.home_plots==before_home and old_reader.nursery_levels==before_nursery_levels,"older expanded saves retain their exact paid positions and levels")
	# A forged fresh save still cannot smuggle a paid tail into never-won land.
	payload["version"] = 5
	payload["completed_level"] = 0
	payload["pond_plots"].fill("")
	payload["pond_levels"].fill(1)
	file = FileAccess.open(save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	expect(not restored.load_game(save_path) and restored.coins==54321 and restored.home_levels==before_levels,"malformed locked-land saves remain rejected atomically")
