extends SceneTree

## Accepts the reference-inspired presentation through real touch controls.
## The fixture was written before the view refactor and contains no user data.
const Layout = preload("res://scripts/field_layout.gd")
const View = preload("res://scripts/battle_map_view.gd")
const Presentation = preload("res://scripts/battle_presentation.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Routes = preload("res://scripts/battle_routes.gd")
const Placement = preload("res://scripts/battle_placement.gd")
const LegacySave: String = "res://tests/fixtures/battle-before-reference-save.json"
const LegacyGeometry: String = "12603276088dc3ba9b2f203d7ea1b640de68de7e4f909986436ae70d569b30ca"

var game: Node2D
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func fresh_game() -> Node2D:
	var instance: Node2D = load("res://scenes/main.tscn").instantiate()
	instance.test_mode = true
	root.add_child(instance)
	instance.set_process(false)
	return instance

func settle(label: String = "", capture: bool = false) -> void:
	game.toast_time = 0
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	for layout in game.text_layouts:
		expect(not layout["truncated"], "reference presentation keeps complete text: " + str(layout["text"]))
		for run in layout["runs"]:
			expect(layout["bounds"].grow(0.1).encloses(run["rect"]), "reference text stays within its allocation")
	if capture and OS.get_cmdline_user_args().has("--screenshots"):
		root.get_texture().get_image().save_png("res://artifacts/battle-reference-" + label + ".png")

func hit(action: String) -> Rect2:
	for index in range(game.hitboxes.size()-1,-1,-1):
		if str(game.hitboxes[index]["action"]) == action:
			return game.hitboxes[index]["rect"]
	return Rect2()

func tap_point(point: Vector2) -> void:
	var position: Vector2 = game.get_global_transform_with_canvas() * point
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = position
	root.push_input(touch, true)
	await process_frame
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = position
	root.push_input(release, true)
	await settle()

func tap(action: String) -> bool:
	await settle()
	var bounds: Rect2 = hit(action)
	expect(bounds.has_area(), "real visible action exists: " + action)
	if not bounds.has_area(): return false
	await tap_point(bounds.get_center())
	return true

func check_legacy_checkpoint() -> void:
	var legacy: Node2D = fresh_game()
	expect(legacy.state.load_game(LegacySave), "the genuine old atomic save loads through the normal garden reader")
	var before: Dictionary = legacy.state.session_data.get("battle", {}).duplicate(true)
	expect(before.get("geometry", "") == LegacyGeometry, "legacy evidence retains its pre-refactor geometry signature")
	var coins: int = legacy.state.coins
	legacy._restore_session()
	expect(legacy.battle != null, "the new battle view resumes the genuine old running checkpoint")
	if legacy.battle != null:
		var after: Dictionary = legacy.battle.export_snapshot()
		before["values"]["paused"] = true
		expect(after.get("version",0) == 2 and after["values"] == before["values"] and after["rng_seed"] == before["rng_seed"] and after["rng_state"] == before["rng_state"], "upgrading the old checkpoint preserves every combat value, attacker, cooldown and RNG field")
		expect(after["path"] == Layout.battle_route() and after["anchors"] == Layout.battle_plots() and after["geometry"] == LegacyGeometry, "the old running battle keeps its exact original route and all stable planting coordinates")
		expect(legacy.battle.paused and legacy.screen == "home" and legacy.state.coins == coins, "legacy resume pauses without paying or simulating offline rewards")
		var clone := BattleSim.new()
		var garden := GardenState.new()
		garden.load_game(LegacySave)
		expect(clone.restore_snapshot(garden, Layout.battle_route(), Layout.battle_plots(), before), "the old checkpoint remains independently restorable by the original combat geometry")
		clone.paused = false
		legacy.battle.paused = false
		for step in range(120):
			clone.tick(0.05)
			legacy.battle.tick(0.05)
		expect(clone.export_snapshot() == legacy.battle.export_snapshot() and garden.coins == legacy.state.coins, "an old save continues identically after changing only its presentation")
	legacy.queue_free()

func check_projection_geometry() -> void:
	var positions: Array[Vector2] = View.plot_positions()
	var route: Array[Vector2] = View.route()
	expect(positions.size() == 19, "all persistent battle identities survive the portrait presentation")
	for slot in range(positions.size()):
		var bounds: Rect2 = View.plot_bounds(slot)
		expect(View.BOARD_RECT.encloses(bounds), "complete upright visual footprint remains inside the enlarged field")
		expect(bounds.encloses(View.bed_bounds(slot)) and bounds.encloses(View.sprite_bounds(slot)) and bounds.encloses(View.badge_bounds(slot)), "reserved bounds include the real soil, weapon and level badge")
		expect(not bounds.intersects(View.house_rect()), "the upright greenhouse cannot cover a planted slot")
		expect(View.simulation_point(View.screen_point(Layout.battle_plots()[slot])).is_equal_approx(Layout.battle_plots()[slot]), "touch projection maps back to the same simulation planting identity")
		for road in View.road_bounds(true):
			expect(not bounds.intersects(road), "upright plants retain the full projected road safety clearance")
		for other in range(slot+1,positions.size()):
			expect(not bounds.intersects(View.plot_bounds(other)), "complete neighboring plant visuals do not overlap")
		for index in range(1,route.size()):
			var distance: float = segment_rect_distance(route[index-1],route[index],bounds)
			expect(distance >= (Layout.ROAD_WIDTH/2.0+Layout.ROAD_CLEARANCE)*View.SCALE-0.01, "the actually rendered curved stone road leaves room for every full plant footprint")
	for road in View.road_bounds(false):
		expect(View.BOARD_RECT.encloses(road), "the visible road width stays within the enlarged field")
	expect(View.BOARD_RECT.encloses(View.house_rect()) and View.house_rect().has_point(route[-1]), "the unchanged enemy route visibly ends at the upright greenhouse")

func segment_rect_distance(start: Vector2, finish: Vector2, bounds: Rect2) -> float:
	if bounds.has_point(start) or bounds.has_point(finish): return 0.0
	var corners: Array[Vector2] = [bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)]
	var shortest: float = minf(start.distance_to(start.clamp(bounds.position,bounds.end)),finish.distance_to(finish.clamp(bounds.position,bounds.end)))
	for index in range(4):
		if Geometry2D.segment_intersects_segment(start,finish,corners[index],corners[(index+1)%4]) != null: return 0.0
		shortest = minf(shortest,corners[index].distance_to(Geometry2D.get_closest_point_to_segment(corners[index],start,finish)))
	return shortest

func check_visible_targets() -> void:
	var found: Dictionary = {}
	var projected: Array[Vector2] = View.project_route(game.battle.path_points())
	for target in game.hitboxes:
		var action: String = str(target["action"])
		if not action.begins_with("battle_plot:"): continue
		var slot: int = action.trim_prefix("battle_plot:").to_int()
		var bounds: Rect2 = target["rect"]
		expect(not found.has(slot) and not game.battle.get_plant(slot).is_empty(), "each actual paid plant has one unique occupied-plant target")
		found[slot] = true
		expect(game.BOARD.grow(0.001).encloses(bounds), "actual plant touches remain within the enlarged field")
		expect(bounds.size.x >= 44 and bounds.size.y >= 44, "arbitrary planting targets retain usable finger size")
		var local := Rect2(bounds.position-game.BOARD.position,bounds.size)
		for index in range(1,projected.size()):
			expect(Placement.segment_rect_distance(projected[index-1],projected[index],local) >= (Layout.ROAD_WIDTH/2.0+Layout.ROAD_CLEARANCE)*View.SCALE-0.01, "the full visible plant touch area stays clear of the real displayed road")
		for other in game.hitboxes:
			var other_action: String = str(other["action"])
			if other_action == action or other_action == "battle_ground": continue
			expect(not bounds.intersects(other["rect"]), "a plant cannot be intercepted by another plant or HUD control")
	expect(found.size() == game.battle.plants.size(), "unused legacy coordinates are not displayed as phantom empty planting controls")
	expect(hit("battle_ground").has_area(), "continuous empty land has its own input layer beneath actual plants")

func free_point(kind: String = "", near: Vector2 = Vector2.INF) -> Vector2:
	var best := Vector2.INF
	var score: float = INF
	for x in range(39,454,13):
		for y in range(39,392,13):
			var point := Vector2(float(x)+0.375,float(y)+0.125)
			if not game.battle.placement_check(point,kind).get("valid",false): continue
			if not near.is_finite(): return point
			var value: float = point.distance_to(near)
			if value < score:
				best = point
				score = value
	expect(best.is_finite(),"the actual route leaves a free continuous planting location")
	return best

func tap_free_ground(kind: String = "") -> Vector2:
	var point: Vector2 = free_point(kind)
	await tap_point(View.screen_point(point))
	return point

func last_slot() -> int:
	return int(game.battle.plants[-1]["slot"]) if not game.battle.plants.is_empty() else -1

func check_projected_range(slot: int) -> void:
	var points: PackedVector2Array = Presentation.projected_range_polygon(game,slot)
	expect(not points.is_empty(), "the selected cannon has its actual projected firing range")
	for point in points:
		expect(game.BOARD.grow(0.01).has_point(point), "visible range is clipped to the enlarged field rather than the HUD")

func garden_progress() -> Array:
	return [game.state.coins,game.state.completed_level,game.state.home_plots.duplicate(),game.state.home_levels.duplicate(),game.state.nursery_plots.duplicate(),game.state.nursery_levels.duplicate(),game.state.pond_plots.duplicate(),game.state.pond_levels.duplicate(),game.state.unlocked_seeds.duplicate()]

func check_full_loadout_pages() -> void:
	# Every offered type comes from a legitimate unlocked habitat planting.
	game.state.coins = 100000
	for stage in range(1,4): game.state.claim_stage_reward(stage)
	var fixtures: Array = [["home",0,"tomato"],["home",2,"marigold"],["nursery",0,"nettle"],["nursery",1,"lavender"],["nursery",8,"pepper"],["home",20,"pumpkin"],["home",8,"cucumber"],["home",12,"strawberry"],["home",13,"currant"],["home",16,"mint"],["pond",0,"waterlily"],["pond",1,"lotus"]]
	for index in range(fixtures.size()):
		var fixture: Array = fixtures[index]
		var area: String = str(fixture[0])
		var slot: int = int(fixture[1])
		var kind: String = str(fixture[2])
		if game.state.plot_kind(area,slot) != kind:
			var success: bool = game.state.plant_plot(area,slot,kind) if game.state.plot_kind(area,slot).is_empty() else game.state.replace_plot(area,slot,kind)
			expect(success,"all twelve tray species come from real compatible garden plots")
		var level: int = [1,7,15,20][index%4]
		if area == "home": game.state.home_levels[slot] = level
		elif area == "nursery": game.state.nursery_levels[slot] = level
		else: game.state.pond_levels[slot] = level
	game._new_battle()
	game.loadout_choices.assign(Catalog.ORDER)
	game._action("confirm_loadout")
	await settle()
	expect(game.battle.loadout.size() == 12 and game.battle.supplies == 240,"twelve grown types form one free frozen loadout with the ordinary supply budget")
	var progress_before: Array = garden_progress()
	var battle_before: Dictionary = game.battle.export_snapshot()
	var seen: Dictionary = {}
	for page in range(3):
		if page > 0: await tap("battle_quick_page:1")
		expect(game.quick_plant_page == page,"real quick-page control reaches its intended catalogue page")
		var visible: Array[String] = []
		for target in game.hitboxes:
			var action: String = str(target["action"])
			if action.begins_with("battle_quick_select:"): visible.append(action.trim_prefix("battle_quick_select:"))
		var expected: Array[String] = []
		for index in range(page*4,page*4+4): expected.append(str(game.battle.loadout[index]["kind"]))
		expect(visible == expected,"each quick page exposes exactly its four frozen kinds in order")
		for kind in visible:
			expect(not seen.has(kind),"catalogue pages never duplicate or hide a species")
			seen[kind] = true
			var entry: Dictionary = {}
			for candidate in game.battle.loadout:
				if candidate["kind"] == kind: entry = candidate
			var bounds: Rect2 = hit("battle_quick_select:"+kind)
			var identity: String = "%s · %d" % [entry["name"],entry["level"]]
			var has_identity: bool = false
			var has_price: bool = false
			for layout in game.text_layouts:
				if not bounds.encloses(layout["bounds"]): continue
				if str(layout["text"]) == identity: has_identity = true
				if str(layout["text"]) == str(entry["cost"]): has_price = true
			expect(has_identity and has_price,"every small tray card visibly names its actual species, frozen level and full supply price")
		if page == 0: await tap("battle_quick_select:"+visible[0])
		expect(game.quick_plant_kind == str(game.battle.loadout[0]["kind"]),"paging preserves the selected kind even when its card is on another page")
		await settle("full-loadout-page%d" % (page+1),true)
		expect(game.battle.export_snapshot() == battle_before and garden_progress() == progress_before,"browsing and selecting tray pages never rewrites the garden or active battle")
	expect(seen.size() == 12 and seen.has("waterlily") and seen.has("lotus"),"all twelve actual species including both aquatic types remain reachable")
	var original_supplies: int = game.battle.supplies
	await tap("battle_quick_select:waterlily")
	await tap_free_ground("waterlily")
	var water_slot: int = last_slot()
	expect(game.battle.get_plant(water_slot).get("kind","") == "waterlily" and game.battle.supplies == original_supplies-int(Catalog.PLANTS["waterlily"]["battle_cost"]),"a last-page aquatic crop installs as a paid frozen-loadout copy")
	await tap("battle_quick_select:lotus")
	await tap_free_ground("lotus")
	var lotus_slot: int = last_slot()
	var expected_supplies: int = original_supplies-int(Catalog.PLANTS["waterlily"]["battle_cost"])-int(Catalog.PLANTS["lotus"]["battle_cost"])
	expect(game.battle.get_plant(lotus_slot).get("kind","") == "lotus" and game.battle.supplies == expected_supplies,"the final aquatic cannon also pays its exact independent supply price")
	for placement in game.battle.plants:
		for template in battle_before["values"]["loadout"]:
			if template["kind"] == placement["kind"]:
				expect(placement["level"] == template["level"] and placement["source_id"] == template["source_id"],"last-page copies retain the frozen individual level and source identity")
	expect(garden_progress() == progress_before,"last-page copies never consume or upgrade their permanent aquatic sources")

func run() -> void:
	check_legacy_checkpoint()
	check_projection_geometry()
	game = fresh_game()
	await process_frame
	game.state.plant_plot("nursery",0,"nettle")
	game.state.nursery_levels[0] = 7
	game._action("battle")
	game._action("stage:1")
	game.loadout_choices.assign(["nettle","tomato"])
	game._action("confirm_loadout")
	await settle("preparation", true)
	expect(game.BOARD.size.y >= 580, "the tactical field gains a substantial share of the portrait screen")
	expect(game.battle.path_points() == Routes.for_stage(1) and game.battle.plot_positions().is_empty(), "new attempts use the authored loop route and have no fixed grid anchors")
	check_visible_targets()
	var original_coins: int = game.state.coins
	var original_supplies: int = game.battle.supplies
	await tap("battle_quick_select:nettle")
	expect(game.quick_plant_kind == "nettle" and game.battle_panel.is_empty(), "plant selection stays on the tactical field")
	await settle("quick-selection", true)
	await tap_free_ground("nettle")
	var first_defender: int = last_slot()
	expect(game.battle.get_plant(first_defender).get("kind", "") == "nettle" and game.battle.supplies == original_supplies-60, "a quick placement pays the exact same cannon price")
	expect(game.quick_plant_kind == "nettle" and game.battle_panel.is_empty(), "the same selected species remains ready for another paid copy")
	await tap_free_ground("nettle")
	var second_defender: int = last_slot()
	expect(game.battle.get_plant(second_defender).get("kind", "") == "nettle" and game.battle.supplies == original_supplies-120, "quick placement supports repeated paid copies without consuming garden plants")
	await tap("battle_quick_select:tomato")
	await tap_free_ground("tomato")
	var income_slot: int = last_slot()
	expect(game.battle.get_plant(income_slot).get("kind", "") == "tomato" and game.battle.supplies == original_supplies-165, "the same quick flow deploys a real income crop for supplies")
	expect(game.state.coins == original_coins and game.state.plot_kind("nursery",0) == "nettle", "quick deployment never pays from or consumes the permanent garden")
	await tap("battle_plot:%d" % first_defender)
	expect(game.battle_panel == "inspect" and game.battle.get_plant(first_defender).get("kind", "") == "nettle", "tapping an occupied slot opens its contextual inspection without replacing it")
	await settle("inspect", true)
	await tap("close_battle_panel")
	game.battle.paused = true
	game.active_battle_slot = first_defender
	check_projected_range(first_defender)
	await settle("range",true)
	game.quick_plant_kind = ""
	await tap_free_ground()
	expect(game.battle_panel == "plant_picker", "an empty bed still offers the contextual picker when no quick plant is selected")
	await settle("picker", true)
	await tap("close_battle_panel")
	await tap("battle_quick_select:nettle")
	var before: Array = game.battle.plants.duplicate(true)
	game.battle.supplies = 0
	await settle("unaffordable", true)
	expect(not hit("battle_quick_select:tomato").has_area(), "an unaffordable tray plant has no active purchase selection")
	await tap_free_ground()
	expect(game.battle.plants == before and game.battle.supplies == 0, "a previously selected plant cannot bypass the current supply balance")
	await tap("battle_quick_select:nettle")
	expect(game.quick_plant_kind.is_empty() and game.battle.supplies == 0 and game.battle.plants == before, "the selected unaffordable card can still be cancelled by a real touch without any charge")
	expect(not hit("battle_quick_select:nettle").has_area(), "after cancellation the same unaffordable card becomes disabled again")
	game.battle_panel = ""
	game.quick_plant_kind = ""
	game.battle.supplies = original_supplies-165
	game._action("battle_quick_select:marigold")
	expect(game.quick_plant_kind.is_empty(), "quick selection cannot add a species excluded from the frozen loadout")
	await tap("wave_preview")
	await settle("guide", true)
	expect(not hit("battle_plot:%d" % first_defender).has_area() and not hit("battle_quick_select:nettle").has_area(), "the forecast exclusively owns its modal input layer")
	await tap("close_wave_preview")
	# Capture a separate legal formation with a second line farther along the
	# path, so the screenshot has real travelling enemies rather than showing
	# an instant kill at the entry of the earlier level-seven test formation.
	game._new_battle()
	game.loadout_choices.assign(["nettle","tomato"])
	game._action("confirm_loadout")
	var path: Array[Vector2] = game.battle.path_points()
	var reserve_slot: int = game.battle.plant_at(free_point("nettle",path[-1]),"nettle")
	game.battle.plant_at(free_point("nettle",path[-1]),"nettle")
	game.battle.plant_at(free_point("tomato"),"tomato")
	game._sync_battle_geometry()
	game.active_battle_slot = -1
	await tap("primary")
	for step in range(220): game.battle.tick(0.05)
	await settle("running",true)
	expect(game.battle.phase == "running" and game.battle.enemies.size() > 0, "the active screenshot contains real authored attackers on the shared path")
	await tap("primary")
	expect(game.battle.paused, "the compact battle controls can pause a running wave")
	game.active_battle_slot = reserve_slot
	check_projected_range(reserve_slot)
	await settle("paused",true)
	game.battle._record_leak({"kind":"beetle","position":Vector2.ZERO},1)
	game.battle.base_hp = 0
	game.battle._finish_battle(false)
	game.result_delay = 0
	game.result_open = true
	await settle("outcome",true)
	await check_full_loadout_pages()
	game.queue_free()
	print("Battle reference presentation: ",checks," checks; ",failures," failures")
	quit(0 if failures == 0 else 1)
