extends "res://tests/capture_large_fields.gd"

## Native touch coverage for two 144-cell fields and the upgrade greenhouse.
const Helpers = preload("res://scripts/garden_helpers.gd")
var checks: int = 0


func fixture_state(label: String) -> GardenState:
	var fixture: GardenState = super.fixture_state(label)
	if label == "full":
		for slot in range(96,144):
			fixture.home_plots[slot] = INCOME_KINDS[slot % INCOME_KINDS.size()]
			fixture.nursery_plots[slot] = DEFENDER_KINDS[slot % DEFENDER_KINDS.size()]
			fixture.home_levels[slot] = [1,7,15,20][slot%4]
			fixture.nursery_levels[slot] = [1,7,15,20][slot%4]
	return fixture


func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		errors.append(message)
		push_error(message)


func hit(action: String) -> Rect2:
	for index in range(game.hitboxes.size() - 1, -1, -1):
		if str(game.hitboxes[index]["action"]) == action: return game.hitboxes[index]["rect"]
	return Rect2()


func actions(action_prefix: String) -> Array[String]:
	var result: Array[String] = []
	for target in game.hitboxes:
		if str(target["action"]).begins_with(action_prefix): result.append(str(target["action"]).trim_prefix(action_prefix))
	return result


func settle(label: String) -> void:
	game.toast_time = 0
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	for layout in game.text_layouts:
		expect(not layout["truncated"], label + ": text is complete: " + str(layout["text"]))
		for run in layout["runs"]: expect(layout["bounds"].grow(0.1).encloses(run["rect"]), label + ": glyphs fit their allocated rectangle")
	for target in game.hitboxes:
		if target.get("world", false) or str(target["action"]) == "battle_ground": continue
		var rect: Rect2 = target["rect"]
		expect(Rect2(0, 0, 540, 960).grow(0.1).encloses(rect), label + ": UI action stays inside the portrait screen")
		expect(rect.size.x >= 44 and rect.size.y >= 44, label + ": UI action keeps a full touch target")


func touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = game.get_global_transform_with_canvas() * point
	root.push_input(event, true)
	await process_frame


func move_touch(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = game.get_global_transform_with_canvas() * point
	root.push_input(event, true)
	await process_frame


func tap(action: String) -> bool:
	await settle("before " + action)
	var rect: Rect2 = hit(action)
	expect(rect.has_area(), "a real visible touch target exists: " + action)
	if not rect.has_area(): return false
	await touch(0, rect.get_center(), true)
	await touch(0, rect.get_center(), false)
	await settle("after " + action)
	return true


func check_three_destinations() -> void:
	await install_case("empty")
	await tap("open_districts")
	expect(actions("district:") == ["garden", "nursery", "greenhouse"], "the larger map retains exactly three destinations")
	await tap("district:greenhouse")
	expect(actions("home_plot:").is_empty() and actions("nursery_plot:").is_empty() and actions("pond_plot:").is_empty(), "the actual greenhouse arrival frame contains no agricultural or water plotting targets")
	await tap("greenhouse")
	expect(game.home_panel == "helpers", "touching the greenhouse opens its permanent upgrade hub directly")
	expect(actions("helper:") == Helpers.ORDER, "the greenhouse contains precisely its three existing upgrades")
	expect(actions("plant:").is_empty() and actions("home_plot:").is_empty() and actions("pond_plot:").is_empty(), "the greenhouse hub has no planting actions")
	var title_found: bool = false
	for layout in game.text_layouts:
		if str(layout["text"]) == "Улучшения теплицы": title_found = true
	expect(title_found, "the greenhouse menu identifies its new purpose")
	await tap("close_home_panel")


func check_seven_home_kinds() -> void:
	await install_case("empty")
	game.garden_world.set_zoom(LARGE_WORLD.DEFAULT_ZOOM)
	game.garden_world.set_center(LARGE_GRID.planting_rect("home", 143).get_center())
	await tap("home_plot:143")
	var seen: Array[String] = []
	for page in range(3):
		expect(game.seed_page == page, "real seed paging advances to page " + str(page + 1))
		var shown: Array[String] = actions("plant:")
		expect(shown.size() == (3 if page < 2 else 1), "seven income species occupy three bounded pages")
		for kind in shown:
			expect(not seen.has(kind), "seed pages never repeat or omit a species")
			seen.append(kind)
		expect(hit("seed_page:-1").has_area() == (page > 0), "seed paging has a valid first boundary")
		expect(hit("seed_page:1").has_area() == (page < 2), "seed paging has a valid final boundary")
		if page < 2: await tap("seed_page:1")
	expect(seen == INCOME_KINDS, "all seven income plants are reachable through actual seed pages")
	await tap("plot_back")
	for index in range(INCOME_KINDS.size()):
		game.state.home_plots[143] = ""
		game.state.home_levels[143] = 1
		await settle("empty final income cell")
		await tap("home_plot:143")
		for page in range(index / 3): await tap("seed_page:1")
		var kind: String = INCOME_KINDS[index]
		await tap("plant:" + kind)
		await tap("upgrade_plot")
		expect(game.state.plot_kind("home", 143) == kind and game.state.plot_level("home", 143) == 2, "the final income cell plants and improves its chosen species: " + kind)
		expect(game.active_plot_area == "home" and game.active_plot_slot == 143, "the final income cell retains its permanent identifier")
		await tap("close_home_panel")


func check_four_square_nursery_slots() -> void:
	await install_case("empty")
	game.garden_world.set_center(LARGE_WORLD.NURSERY_RECT.get_center())
	await tap("nursery")
	var seen: Array[String] = []
	for page in range(18):
		expect(game.nursery_page == page, "the nursery overview reaches page " + str(page + 1))
		var shown: Array[String] = actions("nursery_plot:")
		expect(shown.size() == 8, "each nursery page contains eight distinct saved plantings")
		for local_index in range(shown.size()):
			expect(shown[local_index] == str(page * 8 + local_index), "nursery paging preserves real saved slot order")
			seen.append(shown[local_index])
		expect(hit("nursery_page:-1").has_area() == (page > 0), "nursery paging has a valid first boundary")
		expect(hit("nursery_page:1").has_area() == (page < 17), "nursery paging has a valid final boundary")
		if page < 17: await tap("nursery_page:1")
	expect(seen.size() == 144, "all 144 nursery cells are reachable from the overview")
	var before_center: Vector2 = game.garden_world.center
	await tap("nursery_plot:143")
	expect(game.active_plot_area == "nursery" and game.active_plot_slot == 143, "the final nursery card opens exactly its own saved planting")
	expect(game.garden_world.center != before_center, "a distant nursery card brings its actual cell into view")
	var cell: Rect2 = LARGE_GRID.planting_rect("nursery", 143)
	var projected := Rect2(game.garden_world.world_to_screen(cell.position), cell.size * game.garden_world.zoom)
	expect(LARGE_WORLD.MAP_VIEW.grow(0.1).encloses(projected), "the complete final nursery cell is visible after menu selection")
	expect(actions("plant:") == DEFENDER_KINDS, "the nursery offers only its three defender species")
	await tap("plant:pepper")
	await tap("upgrade_plot")
	expect(game.state.plot_kind("nursery", 143) == "pepper" and game.state.plot_level("nursery", 143) == 2, "the final nursery cell can really be planted and improved")
	await tap("close_home_panel")


func check_greenhouse_purchases() -> void:
	await install_case("empty")
	game.garden_world.focus_district("greenhouse")
	await tap("greenhouse")
	var prices: Dictionary = {"irrigation": [90, 270], "compost": [120, 360], "harvest_crate": [100, 300]}
	var saved_plants: Array = [game.state.home_plots.duplicate(), game.state.nursery_plots.duplicate(), game.state.pond_plots.duplicate()]
	for id in Helpers.ORDER:
		await tap("helper:" + id)
		for tier in range(2):
			expect(game.state.helper_upgrade_cost(id) == prices[id][tier], "the greenhouse retains the original permanent upgrade price: " + id)
			var wallet: int = game.state.coins
			await tap("upgrade_helper:" + id)
			expect(game.state.helper_level(id) == tier + 1 and game.state.coins == wallet - prices[id][tier], "the upgrade hub charges exactly once for its displayed tier: " + id)
		await tap("locate_helper:" + id)
		expect(game.garden_world.current_district().get("id") == "greenhouse", "installed equipment is located at the greenhouse")
		await tap("helper:" + id)
		await tap("helpers")
	expect(saved_plants == [game.state.home_plots, game.state.nursery_plots, game.state.pond_plots], "greenhouse improvements cannot replace agricultural plantings")
	await tap("close_home_panel")


func check_nursery_water() -> void:
	await install_case("empty")
	game.garden_world.set_center(LARGE_WORLD.NURSERY_RECT.get_center())
	await tap("nursery")
	await tap("visit_pond")
	expect(game.garden_world.current_district().get("id") == "nursery", "the water shortcut belongs to the nursery")
	await tap("pond_plot:5")
	expect(actions("plant:") == ["waterlily", "lotus"], "the final water slot retains its aquatic-only choices")
	await tap("plant:lotus")
	await tap("upgrade_plot")
	expect(game.state.plot_kind("pond", 5) == "lotus" and game.state.plot_level("pond", 5) == 2, "the final nursery water cell can be planted and improved")
	await tap("close_home_panel")


func check_field_gestures_and_neighbors() -> void:
	await install_case("full")
	var before: Dictionary = progress()
	for area in ["home", "nursery"]:
		var field: Rect2 = LARGE_WORLD.GARDEN_FLOOR if area == "home" else LARGE_WORLD.NURSERY_FLOOR
		game.garden_world.set_zoom(0.6)
		game.garden_world.set_center(field.get_center())
		await settle("large field before gestures")
		var center: Vector2 = game.garden_world.center
		await touch(0, Vector2(270, 450), true)
		await move_touch(0, Vector2(180, 520))
		await touch(0, Vector2(180, 520), false)
		expect(game.garden_world.center != center and game.home_panel.is_empty(), "a real drag moves the large field without opening a planting")
		var zoom: float = game.garden_world.zoom
		await touch(0, Vector2(180, 430), true)
		await touch(1, Vector2(360, 430), true)
		await move_touch(0, Vector2(140, 430))
		await move_touch(1, Vector2(400, 430))
		await touch(0, Vector2(140, 430), false)
		await touch(1, Vector2(400, 430), false)
		expect(game.garden_world.zoom > zoom and game.home_panel.is_empty(), "a real two-finger gesture magnifies the large field")
		game.garden_world.set_zoom(LARGE_WORLD.ZOOM_MIN)
		for pair in [[0, 1], [5, 11], [35, 66], [106, 107], [142, 143]]:
			var first: Rect2 = LARGE_GRID.planting_rect(area, pair[0])
			var second: Rect2 = LARGE_GRID.planting_rect(area, pair[1])
			game.garden_world.set_center((first.get_center() + second.get_center()) / 2.0)
			await settle("minimum zoom neighboring cells")
			var action_prefix: String = "home_plot:" if area == "home" else "nursery_plot:"
			var a: Rect2 = hit(action_prefix + str(pair[0]))
			var b: Rect2 = hit(action_prefix + str(pair[1]))
			expect(a.size.x >= 44 and a.size.y >= 44 and b.size.x >= 44 and b.size.y >= 44, "adjacent edge cells keep complete touch targets at minimum zoom")
			expect(not a.intersects(b), "adjacent planting cells have no overlapping input pixels")
			for slot in pair:
				await tap(action_prefix + str(slot))
				expect(game.active_plot_area == area and game.active_plot_slot == slot, "an adjacent-cell touch opens exactly its own permanent ID")
				await tap("close_home_panel")
	expect(progress() == before, "field gestures and adjacent-cell inspection preserve all 294 paid plantings")


func check_real_legacy_plot() -> void:
	await install_case("real")
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_copy))
	expect(game.state.home_plots.size() == 144 and game.state.nursery_plots.size() == 144 and game.state.pond_plots.size() == 6, "the real old save expands to the full 294-cell model")
	expect(game.state.home_plots[8] == old["home_plots"][8] and game.state.home_levels[8] == int(old["home_levels"][8]), "the old greenhouse crop retains its exact index, species and paid level")
	expect(game.state.plot_district("home", 8) == "garden" and LARGE_WORLD.plot_district(8) == "garden", "the old greenhouse crop now appears on the first agricultural field")
	game.garden_world.set_zoom(0.8)
	game.garden_world.set_center(LARGE_GRID.planting_rect("home", 8).get_center())
	var before: Dictionary = progress()
	await tap("home_plot:8")
	expect(game.active_plot_area == "home" and game.active_plot_slot == 8, "the migrated crop is reachable at its actual first-field location")
	expect(progress() == before, "inspecting the migrated crop never changes serialized progress")
	await tap("close_home_panel" if game.home_panel == "plot" else "plot_back")
	for slot in range(144): expect(LARGE_WORLD.plot_district(slot) == "garden", "the greenhouse no longer owns any agricultural cell")


func check_camera_layout_migration() -> void:
	await install_case("empty")
	for entry in [[Vector2(480, 384), "garden"], [Vector2(1296, 384), "nursery"], [Vector2(480, 1104), "greenhouse"], [Vector2(1296, 1056), "pond"]]:
		game.state.session_data = {"version": 1, "camera_center": entry[0], "camera_zoom": 1.35, "camera_context": {"focus": entry[0]}, "battle": {}}
		var before: Dictionary = progress()
		game._restore_session()
		await settle("old camera layout migration")
		var expected_focus: Vector2 = LARGE_WORLD.district(entry[1])["center"]
		expect(game.garden_world.navigation_context()["focus"] == expected_focus, "an old map camera recovers its corresponding new place")
		var expected_zoom: float = maxf(0.8, LARGE_WORLD.DEFAULT_ZOOM) if entry[1] == "greenhouse" else LARGE_WORLD.DEFAULT_ZOOM
		expect(is_equal_approx(game.garden_world.zoom, expected_zoom), "old map camera recovery uses the readable zoom for its destination")
		expect(progress() == before, "camera migration cannot mutate paid player progress")
	for entry in [[Vector2(624,1872),"greenhouse"],[Vector2(2976,1344),"pond"]]:
		game.state.session_data = {"version":1,"world_layout":2,"camera_center":entry[0],"camera_zoom":1.35,"camera_context":{"focus":entry[0]},"battle":{}}
		var before: Dictionary = progress()
		game._restore_session()
		await settle("96-cell layout camera migration")
		expect(game.garden_world.navigation_context()["focus"] == LARGE_WORLD.district(entry[1])["center"],"the previous workshop and pond camera follow their relocated destination")
		expect(progress() == before,"layout-two camera recovery preserves all paid progress")
	game.state.session_data = {"version":1,"world_layout":2,"camera_center":Vector2(2448,864),"camera_zoom":1.1,"camera_context":{"focus":Vector2(2448,864)},"battle":{}}
	game._restore_session()
	expect(game.garden_world.center.is_equal_approx(Vector2(2448,864)) and is_equal_approx(game.garden_world.zoom,1.1),"an old northern-field camera retains its exact panning and zoom")

	game.state.session_data = {"version": 1, "world_layout": 3, "camera_center": Vector2(2448, 864), "camera_zoom": 1.1, "camera_context": {"focus": Vector2(2448, 864)}, "battle": {}}
	game._restore_session()
	expect(game.garden_world.center.is_equal_approx(Vector2(2448, 864)) and is_equal_approx(game.garden_world.zoom, 1.1), "current-layout sessions preserve their exact panning and zoom")


func run() -> void:
	if not configure_arguments("large-field-ui"):
		push_error(str(errors))
		quit(1)
		return
	await check_three_destinations()
	await check_seven_home_kinds()
	await check_four_square_nursery_slots()
	await check_greenhouse_purchases()
	await check_nursery_water()
	await check_field_gestures_and_neighbors()
	await check_real_legacy_plot()
	await check_camera_layout_migration()
	if source_digest != FileAccess.get_sha256(save_copy): errors.append("Player save copy was changed")
	print("Large field native UI: ", checks, " checks; source sha256=", source_digest, "; issues=", errors)
	game.queue_free()
	quit(0 if errors.is_empty() else 1)
