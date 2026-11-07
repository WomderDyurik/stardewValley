extends SceneTree

## Test the new promises against real persistent progress and occupied land.
## Rendering and querying the garden must never grant plants or rewards.
const State = preload("res://scripts/garden_state.gd")
const Experience = preload("res://scripts/garden_experience.gd")
const Grid = preload("res://scripts/garden_grid.gd")
const World = preload("res://scripts/garden_world.gd")
const Paths = preload("res://scripts/garden_paths.gd")
const Main = preload("res://scripts/main.gd")
const Battle = preload("res://scripts/battle_sim.gd")
const Layout = preload("res://scripts/field_layout.gd")
var checks: int = 0
var failures: int = 0

class MomentCanvas:
	extends Node2D
	var garden_moments: Array[Dictionary] = []
	var elapsed: float = 0.0


func expect(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(reason)


func snapshot(state) -> Dictionary:
	var result: Dictionary = {}
	for field in ["coins","completed_level","levels","home_plots","home_levels","nursery_plots","nursery_levels","pond_plots","pond_levels","unlocked_seeds","helper_levels","home_stock","home_stock_value","home_elapsed","home_ready","session_data"]:
		var value = state.get(field)
		result[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result


func check_goal(state, id: String, action: String, progress: int, total: int) -> void:
	var before: Dictionary = snapshot(state)
	var goal: Dictionary = Experience.next_goal(state)
	expect(goal.get("id") == id and goal.get("action") == action,"the next useful action follows current progress: "+id)
	expect(goal.get("progress") == progress and goal.get("total") == total,"the goal reports exact real progress: "+id)
	for key in ["title","detail","button"]:
		expect(goal.has(key) and not String(goal[key]).is_empty(),"the goal explains itself and its action: "+id)
	expect(snapshot(state) == before,"deriving a goal never changes permanent development")


func _initialize() -> void:
	_check_goal_progression()
	_check_real_soil()
	_check_landmark_clearance()
	_check_short_responses()
	_check_first_visit_and_reload()
	_check_defensive_loadout_guard()
	print("Garden experience: ",checks," checks; ",failures," failures")
	quit(0 if failures == 0 else 1)


func _check_goal_progression() -> void:
	var state := State.new()
	state.coins = 1000000
	check_goal(state,"first_defender","grow_defender",0,1)
	expect(Experience.planted_count(state,"home") == 3 and Experience.planted_count(state,"nursery") == 0,"fresh garden progress counts its three genuine crops and no free defender")
	# Economic templates must not falsely satisfy the defensive role.
	expect(state.plant_plot("home",143,"cucumber"),"a genuine remote income planting is purchased")
	check_goal(state,"first_defender","grow_defender",0,1)
	expect(state.plant_plot("nursery",143,"nettle"),"a genuine remote defensive template is purchased")
	check_goal(state,"open_water","battle",0,1)
	expect(not state.is_district_unlocked("pond"),"the goal does not unlock its promised reward early")
	state.claim_stage_reward(1)
	check_goal(state,"water_plant","visit_pond",0,1)
	expect(Experience.planted_count(state,"pond") == 0,"opening the pond grants empty habitat, not grown water plants")
	expect(state.plant_plot("pond",5,"waterlily"),"a real water planting completes the next local goal")
	check_goal(state,"next_defense","battle",1,3)
	state.claim_stage_reward(2)
	check_goal(state,"next_defense","battle",2,3)
	state.claim_stage_reward(3)
	check_goal(state,"workshop","helpers",0,3)
	for index in range(3):
		var helper: String = ["irrigation","compost","harvest_crate"][index]
		expect(state.upgrade_helper(helper),"the real permanent helper is purchased: "+helper)
		if index < 2: check_goal(state,"workshop","helpers",index+1,3)
	check_goal(state,"living_garden","garden_journal",3,3)
	var final_count: int = Experience.planted_count(state,"home")+Experience.planted_count(state,"nursery")+Experience.planted_count(state,"pond")
	expect(String(Experience.next_goal(state)["detail"]).contains(str(final_count)),"the mature-garden detail uses real planted records")
	# A migrated save or a deliberate replacement can change the available
	# template. The current state, rather than a stale completed tutorial flag,
	# remains authoritative even after all campaign rewards were claimed.
	state.nursery_plots[143] = ""
	state.nursery_levels[143] = 1
	check_goal(state,"first_defender","grow_defender",0,1)
	state.nursery_plots[143] = "nettle"
	state.pond_plots[5] = ""
	state.pond_levels[5] = 1
	check_goal(state,"water_plant","visit_pond",0,1)
	state.pond_plots[5] = "waterlily"
	check_goal(state,"living_garden","garden_journal",3,3)


func _check_real_soil() -> void:
	var state := State.new()
	state.coins = 1000000
	state.home_plots.fill("")
	for area in ["home","nursery"]:
		expect(Experience.soil_cells(state,area).is_empty(),"an empty district paints no giant cultivated field: "+area)
		expect(Grid.planting_cells(area).size() == 144,"meadow presentation retains all 144 real saved cells: "+area)
		for slot in [0,35,36,71,72,107,108,143]:
			var kind: String = "tomato" if area == "home" else "nettle"
			expect(state.can_plant(area,slot,kind),"latent corners of each 6x6 square remain editable")
			expect(state.plant_plot(area,slot,kind),"occupancy fixture uses a paid real cell")
		var before: Dictionary = snapshot(state)
		var soil: Array[Rect2] = Experience.soil_cells(state,area)
		expect(soil.size() == 8 and Experience.planted_count(state,area) == 8,"soil and progress contain exactly the eight actual paid plantings")
		for slot in range(144):
			var actual: bool = not state.plot_kind(area,slot).is_empty()
			expect(soil.has(Grid.planting_rect(area,slot)) == actual,"painted soil agrees with actual saved occupancy: %s:%d" % [area,slot])
			expect(World.WORLD_RECT.encloses(Grid.planting_rect(area,slot)),"every latent and occupied cell retains a real world footprint")
		expect(snapshot(state) == before,"soil derivation does not alter plants, levels, currency or income")
		# Returning the list must not allow accidental edits to erase saved land.
		soil.clear()
		expect(Experience.soil_cells(state,area).size() == 8,"a caller cannot mutate persistent land by editing a returned soil list")


func polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])


func _check_landmark_clearance() -> void:
	var frames: Array[Rect2] = [Experience.HEART_RECT]
	expect(World.WORLD_RECT.encloses(Experience.HEART_RECT),"the new living landmark fits inside the estate")
	expect(Experience.HEART_RECT.encloses(Experience.HEART_SEAT),"the resting place belongs to its landmark footprint")
	var flowers: Array[Dictionary] = Experience.flower_clusters()
	expect(not flowers.is_empty(),"distinct nonproductive flower pockets were actually created")
	for flower in flowers:
		frames.append(Rect2(Vector2(flower["at"])-Vector2(6,10),Vector2(16,18)))
	for frame in frames:
		for area in ["home","nursery","pond"]:
			for slot in range(Grid.planting_cells(area).size()):
				expect(not frame.intersects(Grid.planting_rect(area,slot)),"the landmark and wild flowers leave every actual planting cell clear")
		for occupied in World.building_hit_regions().values():
			expect(not frame.intersects(occupied),"new art cannot cover a building interaction")
		for route in Paths.polygons():
			expect(Geometry2D.intersect_polygons(polygon(frame.grow(-0.01)),route).is_empty(),"new art leaves the complete walking network clear")
	var before: Array[Dictionary] = flowers.duplicate(true)
	expect(Experience.flower_clusters() == before,"authored flower positions are stable between frames")


func _check_short_responses() -> void:
	var canvas := MomentCanvas.new()
	for index in range(20):
		canvas.elapsed = float(index)
		Experience.note(canvas,"plant",Vector2(index,index*2),"actual "+str(index))
	expect(canvas.garden_moments.size() <= 8,"short responses have bounded memory after repeated tending")
	expect(canvas.garden_moments[-1]["time"] == 19.0 and canvas.garden_moments[-1]["at"] == Vector2(19,38),"the newest response belongs to the real event time and location")
	for index in range(1,canvas.garden_moments.size()):
		expect(float(canvas.garden_moments[index]["time"]) >= float(canvas.garden_moments[index-1]["time"]),"bounded feedback does not resurrect an older event as the newest one")
	canvas.free()


func _check_first_visit_and_reload() -> void:
	var path: String = "/private/tmp/planta2-experience-first-visit-%d.json" % OS.get_process_id()
	DirAccess.remove_absolute(path)
	var game := Main.new()
	game.test_mode = true
	game.state = State.new()
	var before: Dictionary = snapshot(game.state)
	expect(not game._load_garden(path),"a genuinely missing isolated save starts a first visit")
	expect(game.state.home_ready and is_equal_approx(game.state.home_elapsed,game.state.home_cycle()),"the existing starter crops are ripe on the genuine first visit")
	for field in before:
		if field in ["home_ready","home_elapsed"]: continue
		expect(snapshot(game.state)[field] == before[field],"first-visit ripeness grants no extra development: "+field)
	for label in ["growing","stored_harvest"]:
		var saved := State.new()
		saved.coins = 12345
		saved.home_elapsed = 7.25
		if label == "stored_harvest":
			saved.helper_levels["harvest_crate"] = 2
			saved.home_stock = 2
			saved.home_stock_value = 137
			saved.home_ready = true
		var exact: Dictionary = snapshot(saved)
		expect(saved.save_game(path),"the isolated "+label+" fixture saves through the real atomic writer")
		var digest: String = FileAccess.get_sha256(path)
		game.state = State.new()
		expect(game._load_garden(path),"a valid existing "+label+" save is recognized")
		expect(snapshot(game.state) == exact,"loading an existing garden preserves its exact timer, stored value, ready flag and paid development: "+label)
		expect(FileAccess.get_sha256(path) == digest,"loading an existing save never rewrites it or grants a reload reward")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path+".tmp")
	game.free()


func _check_defensive_loadout_guard() -> void:
	var game := Main.new()
	game.test_mode = true
	game.state = State.new()
	game.battle = Battle.new()
	game.battle.configure(game.state,Layout.battle_route(),Layout.battle_plots(),1)
	game.battle_panel = "loadout"
	game.loadout_choices.assign(["tomato","marigold"])
	var before: Dictionary = snapshot(game.state)
	var supplies: int = game.battle.supplies
	game._action("confirm_loadout")
	expect(not game.battle.loadout_ready and game.battle_panel == "loadout","the actual confirmation action rejects an income-only roster")
	expect(not game.toast_text.is_empty(),"an income-only roster receives an explanation")
	expect(snapshot(game.state) == before and game.battle.supplies == supplies and game.battle.plants.is_empty(),"rejected guidance spends no garden coins or battle supplies")
	game.loadout_choices.assign(["tomato","nettle"])
	game._action("confirm_loadout")
	expect(not game.battle.loadout_ready,"naming an unowned defender cannot manufacture its battle template")
	expect(game.state.plant_plot("nursery",0,"nettle"),"the first defender is purchased through the real garden rules")
	before = snapshot(game.state)
	game._action("confirm_loadout")
	expect(game.battle.loadout_ready and game.battle_panel.is_empty(),"the same action accepts a roster containing a real grown defender")
	expect(game.battle.loadout.any(func(entry): return entry["kind"] == "nettle" and entry["role"] == "defense"),"confirmed roster contains the actual defensive source")
	expect(snapshot(game.state) == before and game.battle.supplies == supplies and game.battle.plants.is_empty(),"confirming templates does not buy a deployed copy or alter persistent development")
	game.free()
