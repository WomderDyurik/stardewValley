extends SceneTree

const State = preload("res://scripts/garden_state.gd")
const Battle = preload("res://scripts/battle_sim.gd")
const Placement = preload("res://scripts/battle_placement.gd")
const Layout = preload("res://scripts/field_layout.gd")
const Routes = preload("res://scripts/battle_routes.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func garden() -> GardenState:
	var result := State.new()
	result.coins = 100000
	result.plant_plot("nursery", 0, "nettle")
	result.nursery_levels[0] = 7
	return result


func field(grown: GardenState) -> BattleSim:
	var result := Battle.new()
	var path: Array[Vector2] = [Vector2(16, 14), Vector2(476, 14)]
	var empty: Array[Vector2] = []
	result.configure(grown, path, empty)
	result.select_loadout(["nettle", "tomato"])
	result.reward_rng.seed = 11843
	return result


func reject_unchanged(battle: BattleSim, point: Vector2, kind: String, code: String) -> void:
	var before: Dictionary = battle.export_snapshot()
	var coins: int = battle.state.coins
	expect(battle.placement_check(point, kind).get("code") == code, "preview explains rejected placement: " + code)
	expect(battle.plant_at(point, kind) == -1, "the paid operation also rejects: " + code)
	expect(battle.export_snapshot() == before and battle.state.coins == coins, "rejected placement preserves anchors, IDs, cooldowns, RNG, budget and garden: " + code)


func run() -> void:
	var grown: GardenState = garden()
	var battle: BattleSim = field(grown)
	var original_coins: int = grown.coins
	var empty_checkpoint: Dictionary = battle.export_snapshot()
	var empty_copy := Battle.new()
	var no_anchors: Array[Vector2] = []
	var uncommitted := Battle.new()
	uncommitted.configure(grown, battle.path_points(), no_anchors)
	var uncommitted_copy := Battle.new()
	expect(uncommitted_copy.restore_snapshot(grown,battle.path_points(),no_anchors,uncommitted.export_snapshot()), "an unconfirmed composition also resumes with zero anchors")
	expect(not uncommitted_copy.loadout_ready and uncommitted_copy.plants.is_empty() and uncommitted_copy.wave == 0, "restoring an unconfirmed free battle neither chooses plants nor starts or pays for a wave")
	expect(empty_checkpoint["version"] == 2 and empty_checkpoint["anchors"].is_empty(), "a new free field is a v2 checkpoint with zero reserved slots")
	expect(empty_copy.restore_snapshot(grown, battle.path_points(), no_anchors, empty_checkpoint) and empty_copy.plot_positions().is_empty(), "preparation with no plants and no anchors can resume")
	reject_unchanged(battle, Vector2(200, 40), "nettle", "road")
	reject_unchanged(battle, Vector2(32, 40), "nettle", "road")
	reject_unchanged(battle, Vector2(8, 150), "nettle", "outside")
	reject_unchanged(battle, Vector2.INF, "nettle", "outside")
	reject_unchanged(battle, Vector2(445, 35), "nettle", "greenhouse")
	reject_unchanged(battle, Vector2(140, 110), "pepper", "not_selected")
	var arbitrary := Vector2(143.25, 112.75)
	expect(not Layout.battle_plots().has(arbitrary), "the fixture deliberately avoids every former fixed planting slot")
	var first: int = battle.plant_at(arbitrary, "nettle")
	var canonical: Vector2 = Placement.snap(arbitrary)
	expect(first == 0 and battle.plot_positions() == [canonical], "the first success receives a stable ID at the canonical cell center")
	expect(battle.placement_check(arbitrary+Vector2(3,2))["position"] == canonical, "nearby points in one cell have exactly one preview center")
	expect(battle.supplies == 180 and battle.get_plant(first)["level"] == 7 and battle.get_plant(first)["source_id"] == "nursery:0", "a free position still pays the ordinary price and uses the frozen grown template")
	expect(grown.coins == original_coins and grown.plot_kind("nursery", 0) == "nettle", "placement consumes neither permanent coins nor the garden plant")
	reject_unchanged(battle, arbitrary + Vector2(1, 1), "tomato", "occupied")
	expect(battle.placement_check(canonical+Vector2(Placement.GRID_STEP,0),"tomato")["valid"], "adjacent distinct cells remain usable with a real gap between plants")
	var second: int = battle.plant_at(Vector2(280, 200), "tomato")
	expect(second == 1 and battle.supplies == 135, "a failed gesture never reserves an ID before the next successful placement")
	var second_position: Vector2 = battle.plot_positions()[second]
	expect(battle.replace_plant(second, "nettle") and battle.plot_positions()[second] == second_position and battle.supplies == 75, "replacement preserves the cell anchor and charges the full new price without a refund")
	battle._gain_supplies(Vector2.ZERO, 45, "test")
	expect(battle.plant_at(Vector2(360, 300), "nettle") == 2 and battle.supplies == 60, "multiple copies of a frozen species use independent regular cells")
	expect(battle.plant_at(Vector2(230, 330), "nettle") == 3 and battle.supplies == 0, "the last affordable copy pays its entire price")
	reject_unchanged(battle, Vector2(60, 280), "nettle", "supplies")
	battle.start_wave()
	for step in range(59): battle.tick(0.05)
	var before: Dictionary = battle.export_snapshot()
	var resumed := Battle.new()
	var changed_route: Array[Vector2] = [Vector2(16, 220), Vector2(476, 220)]
	expect(resumed.restore_snapshot(grown, changed_route, no_anchors, before), "a running free-position attempt restores its saved route even if new attempts use another map")
	if resumed.state != null:
		var after: Dictionary = resumed.export_snapshot()
		after["values"]["paused"] = before["values"]["paused"]
		expect(after == before, "restoration preserves every dynamic anchor, ability timer, projectile and RNG exactly apart from safe pause")
		resumed.paused = false
		for step in range(83):
			battle.tick(0.05)
			resumed.tick(0.05)
		expect(resumed.export_snapshot() == battle.export_snapshot(), "saved arbitrary positions continue the identical deterministic combat branch")
		var malformed: Dictionary = before.duplicate(true)
		malformed["anchors"][0] += Vector2(7, 0)
		var intact: Dictionary = resumed.export_snapshot()
		expect(not resumed.restore_snapshot(grown, changed_route, no_anchors, malformed) and resumed.export_snapshot() == intact, "a broken dynamic geometry hash cannot partially replace the live attempt")
		malformed = before.duplicate(true)
		malformed["path"] = [Vector2.ZERO]
		expect(not resumed.restore_snapshot(grown, changed_route, no_anchors, malformed), "a one-point saved route is rejected safely")
	check_capacity()
	check_legacy()
	check_grid_geometry()
	check_saved_free_anchors()
	print("Grid battle placement: ", checks, " checks; ", failures, " failures")
	quit(0 if failures == 0 else 1)


func check_capacity() -> void:
	var battle: BattleSim = field(garden())
	battle._gain_supplies(Vector2.ZERO, 20000, "test")
	var count: int = 0
	for point in Placement.grid_centers():
		if not battle.placement_check(point,"tomato")["valid"]: continue
		var slot: int = battle.plant_at(point, "tomato")
		expect(slot == count, "each paid grid copy receives the next stable ID beyond the former nineteen-slot limit")
		count += 1
	expect(count>19 and battle.plants.size() == count and battle.plot_positions().size() == count, "actual free cells and supplies limit copies instead of a nineteen-plant cap")
	var restored := Battle.new()
	var empty: Array[Vector2] = []
	expect(restored.restore_snapshot(battle.state, battle.path_points(), empty, battle.export_snapshot()) and restored.plants.size() == count, "a checkpoint keeps more than nineteen real plants and anchors")
	var copied: Array[Vector2] = restored.plot_positions()
	copied[0] = Vector2.ZERO
	expect(restored.plot_positions()[0] != Vector2.ZERO, "the public anchor getter cannot accidentally mutate model geometry")


func check_legacy() -> void:
	var old_garden := State.new()
	expect(old_garden.load_game("res://tests/fixtures/battle-before-reference-save.json"), "the pre-refactor artificial garden fixture loads")
	var old: Dictionary = old_garden.session_data.get("battle", {})
	expect(old.get("version") == 1, "compatibility evidence was actually created using the old snapshot version")
	var replacement_route: Array[Vector2] = [Vector2(16, 220), Vector2(476, 220)]
	var empty: Array[Vector2] = []
	var restored := Battle.new()
	expect(restored.restore_snapshot(old_garden, replacement_route, empty, old), "a v1 battle resumes its original exact route despite the new free-placement map")
	if restored.state == null: return
	var upgraded: Dictionary = restored.export_snapshot()
	var values: Dictionary = upgraded["values"].duplicate(true)
	values["paused"] = old["values"]["paused"]
	expect(values == old["values"] and upgraded["rng_seed"] == old["rng_seed"] and upgraded["rng_state"] == old["rng_state"], "upgrading v1 geometry never remaps progress, IDs, cooldowns, rewards or RNG")
	expect(upgraded["path"] == Layout.battle_route() and upgraded["anchors"] == Layout.battle_plots(), "the old nineteen identities remain the same old coordinates")


func check_grid_geometry() -> void:
	var centers: Array[Vector2] = Placement.grid_centers()
	expect(centers.size()==Placement.GRID_COUNT.x*Placement.GRID_COUNT.y,"the rectangular grid exposes every authored cell exactly once")
	for point in centers:
		expect(Placement.is_grid_center(point),"each exposed cell is a canonical center")
		expect(Layout.BOARD_RECT.encloses(Placement.footprint(point)),"every plant body in a cell fits fully within the playable field")
		for delta in [Vector2(-20,-20),Vector2(20,20),Vector2(-20,20),Vector2(20,-20)]:
			expect(Placement.snap(point+delta)==point,"tap and drag positions anywhere inside one cell resolve to its same center")
		var exact: Dictionary = Placement.check(point,[Vector2(16,14),Vector2(476,14)],[])
		expect(exact["position"]==point and exact["cell"]==Placement.grid_cell(point),"land rejection and acceptance both retain the canonical preview target")
	var capacities: Array[int] = []
	for stage in range(1,4):
		var available: int = 0
		var path: Array[Vector2] = Routes.for_stage(stage)
		for point in centers:
			if Placement.check(point,path,[])["valid"]: available+=1
		capacities.append(available)
		expect(available>=19,"each authored map leaves at least nineteen useful complete-body grid cells")
	print("Authored stage grid capacities: ",capacities)


func check_saved_free_anchors() -> void:
	# This constructs the exact v2 structure used before grid deployment: old
	# callers supplied unsnapped anchors to configure(), then planted by ID.
	var grown: GardenState = garden()
	var legacy := Battle.new()
	var raw := Vector2(143.25,112.75)
	var old_anchors: Array[Vector2] = [raw]
	var path: Array[Vector2] = [Vector2(16,14),Vector2(476,14)]
	legacy.configure(grown,path,old_anchors)
	legacy.select_loadout(["nettle","tomato"])
	expect(legacy.plant(0,"nettle"),"the legacy free-anchor fixture has one paid historical plant")
	legacy.start_wave()
	for step in range(91): legacy.tick(0.05)
	var before: Dictionary = legacy.export_snapshot()
	var resumed := Battle.new()
	var empty: Array[Vector2] = []
	expect(resumed.restore_snapshot(grown,Routes.for_stage(1),empty,before),"a historical v2 free-anchor battle restores after grid adoption")
	if resumed.state==null: return
	var after: Dictionary = resumed.export_snapshot()
	after["values"]["paused"] = before["values"]["paused"]
	expect(after==before and resumed.plot_positions()[0]==raw,"restoring never teleports historical coordinates or changes route, abilities, IDs, purchases, clocks and RNG")
	expect(not Placement.is_grid_center(raw),"the compatibility fixture actually contains a non-grid position")
	expect(resumed.placement_check(raw,"tomato")["code"]=="occupied","new grid cells respect the actual historical plant body rather than an imaginary snapped old body")
	var index: int = resumed.plant_at(Vector2(280,200),"tomato")
	expect(index==1 and Placement.is_grid_center(resumed.plot_positions()[index]),"the next paid plant in a resumed free-anchor battle uses the new canonical grid")
	expect(resumed.plot_positions()[0]==raw,"adding a grid plant never moves an existing saved free-anchor plant")
