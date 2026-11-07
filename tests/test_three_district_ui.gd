extends "res://tests/capture_three_districts.gd"

## Real touch acceptance for compact destinations, habitat choice and archives.
const Placement = preload("res://scripts/battle_placement.gd")
const FORBIDDEN_PLACE_NAMES = ["ягодник", "дальний огород", "тёплая поляна"]
var checks: int = 0


func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		errors.append(message)
		push_error(message)


func actions(action_prefix: String) -> Array[String]:
	var result: Array[String] = []
	for target in game.hitboxes:
		if str(target["action"]).begins_with(action_prefix): result.append(str(target["action"]).trim_prefix(action_prefix))
	return result


func hit(action: String) -> Rect2:
	for index in range(game.hitboxes.size() - 1, -1, -1):
		if str(game.hitboxes[index]["action"]) == action: return game.hitboxes[index]["rect"]
	return Rect2()


func settle(label: String) -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	for layout in game.text_layouts:
		expect(not layout["truncated"], label + ": complete text: " + str(layout["text"]))
		for run in layout["runs"]: expect(layout["bounds"].grow(0.1).encloses(run["rect"]), label + ": glyphs fit their allocated text rectangle")
	for target in game.hitboxes:
		if target.get("world", false) or str(target["action"]) == "battle_ground": continue
		var rect: Rect2 = target["rect"]
		expect(Rect2(0, 0, 540, 960).grow(0.1).encloses(rect), label + ": UI action is inside the portrait screen: " + str(target["action"]))
		expect(rect.size.x >= 44 and rect.size.y >= 44, label + ": UI action retains a finger-sized target: " + str(target["action"]))


func tap(action: String) -> bool:
	await settle("before " + action)
	var rect: Rect2 = hit(action)
	expect(rect.has_area(), "the actual visible control exists: " + action)
	if not rect.has_area(): return false
	var point: Vector2 = game.get_global_transform_with_canvas() * rect.get_center()
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = pressed
		touch.position = point
		root.push_input(touch, true)
		await process_frame
	await settle("after " + action)
	return true


func expect_no_removed_names(label: String) -> void:
	for layout in game.text_layouts:
		var text: String = str(layout["text"]).to_lower()
		for old_name in FORBIDDEN_PLACE_NAMES: expect(not text.contains(old_name), label + ": removed destination never appears: " + old_name)


func verify_three_rows(label: String) -> void:
	expect(actions("district:") == ["garden", "nursery", "greenhouse"], label + ": navigation contains exactly the three retained destinations")
	expect_no_removed_names(label)
	var rectangles: Array[Rect2] = []
	for region in THREE_REGIONS:
		var rect: Rect2 = hit("district:" + region)
		for previous in rectangles: expect(not rect.intersects(previous), "the three district rows do not overlap")
		rectangles.append(rect)


func check_navigation() -> void:
	configure_compact("empty")
	var before: Dictionary = progress()
	for region in THREE_REGIONS:
		await tap("open_districts")
		verify_three_rows("empty navigation")
		await tap("district:" + region)
		expect(game.garden_world.current_district().get("id") == region, "a real row touch focuses its retained destination: " + region)
	expect(progress() == before, "three-district inspection never spends coins or changes plantings")
	configure_compact("full")
	await tap("open_districts")
	verify_three_rows("developed navigation")
	await tap("close_home_panel")


func check_picker_profiles() -> void:
	var profiles: Array = [["home", 0, "garden", ["tomato", "marigold", "pumpkin"]], ["nursery", 0, "nursery", ["nettle", "lavender", "pepper"]], ["home", 8, "greenhouse", ["cucumber", "strawberry", "currant", "mint"]]]
	for profile in profiles:
		configure_compact("empty")
		game.garden_world.focus_district(profile[2])
		await tap(("home_plot:" if profile[0] == "home" else "nursery_plot:") + str(profile[1]))
		expect(actions("plant:") == profile[3], "the real picker offers every compatible retained-district species: " + str(profile[2]))
		var rectangles: Array[Rect2] = []
		for kind in profile[3]:
			var rect: Rect2 = hit("plant:" + kind)
			for previous in rectangles: expect(not rect.intersects(previous), "three/four species cards never overlap")
			rectangles.append(rect)
		expect_no_removed_names("new planting profile")
	# Every greenhouse card must actually plant and upgrade its own species.
	for kind in ["cucumber", "strawberry", "currant", "mint"]:
		configure_compact("empty")
		game.garden_world.focus_district("greenhouse")
		await tap("home_plot:8")
		await tap("plant:" + kind)
		expect(game.state.plot_kind("home", 8) == kind and game.home_panel == "plot", "the greenhouse card plants its displayed species: " + kind)
		await tap("upgrade_plot")
		expect(game.state.plot_kind("home", 8) == kind and game.state.plot_level("home", 8) == 2, "greenhouse improvement preserves the selected species: " + kind)
		await tap("close_home_panel")


func check_greenhouse_pond() -> void:
	configure_compact("empty")
	game.state = StateScript.new()
	game.state.coins = 1000000
	game.garden_world.focus_district("greenhouse")
	await tap("greenhouse")
	expect(hit("visit_pond").has_area(), "the greenhouse offers its own pond before discovery")
	await tap("visit_pond")
	expect(game.garden_world.current_district().get("id") == "greenhouse", "inspecting the pond keeps the greenhouse navigation identity")
	expect(not hit("pond_plot:0").has_area() and not hit("pond_plot:5").has_area(), "the locked greenhouse pond cannot expose phantom playable slots")
	game.state.claim_stage_reward(1)
	game.garden_world.focus_district("greenhouse")
	await settle("first discovery")
	await tap("greenhouse")
	await tap("visit_pond")
	await tap("pond_plot:0")
	expect(actions("plant:") == ["waterlily", "lotus"], "the greenhouse pond retains its aquatic-only picker")
	await tap("plant:waterlily")
	await tap("upgrade_plot")
	expect(game.active_plot_area == "pond" and game.active_plot_slot == 0 and game.state.plot_kind("pond", 0) == "waterlily" and game.state.plot_level("pond", 0) == 2, "a direct water planting and upgrade retain the aquatic identity")
	await tap("change_plant")
	await tap("plant:lotus")
	await tap("upgrade_plot")
	expect(game.state.plot_kind("pond", 0) == "lotus" and game.state.plot_level("pond", 0) == 2, "a direct aquatic replacement and upgrade retain the selected lotus")
	await tap("close_home_panel")
	await tap("open_districts")
	verify_three_rows("pond context")
	var selected: Array[String] = []
	for layout in game.text_layouts:
		if str(layout["text"]).ends_with(" · сейчас"): selected.append(str(layout["text"]))
	expect(selected == ["Теплица · сейчас"], "the pond selects the greenhouse row, without a fourth destination")
	await tap("close_home_panel")


func check_campaign_and_help() -> void:
	configure_compact("empty")
	game.state = StateScript.new()
	game.battle = null
	await tap("battle")
	expect_no_removed_names("campaign")
	await tap("close_stage")
	await tap("help")
	expect_no_removed_names("help")
	await tap("help")
	for stage in range(1, 4):
		configure_compact("empty")
		game.state = StateScript.new()
		for earlier in range(1, stage): game.state.claim_stage_reward(earlier)
		game.current_stage = stage
		game._new_battle()
		game.battle.discovery_reward = game.state.claim_stage_reward(stage)
		game.battle.phase = "won"
		game.battle.loadout_ready = true
		game._show_screen("battle")
		game.result_open = true
		await settle("first reward " + str(stage))
		expect_no_removed_names("first reward " + str(stage))
		game.result_open = false


func check_archived_source() -> void:
	configure_compact("full")
	game.state.nursery_plots[8] = "pepper"
	game.state.nursery_levels[8] = 19
	game.state.home_plots[12] = "strawberry"
	game.state.home_levels[12] = 17
	var roster: Array[Dictionary] = game.state.battle_roster()
	expect(roster.any(func(entry): return entry["id"] == "nursery:8" and entry["level"] == 19), "the archive keeps an already paid defender in the roster")
	expect(roster.any(func(entry): return entry["id"] == "home:12" and entry["level"] == 17), "the archive keeps an already paid economic plant in the roster")
	game.current_stage = 1
	game._new_battle()
	game.loadout_choices.assign(["pepper", "strawberry"])
	game._show_screen("battle")
	await tap("confirm_loadout")
	game.battle.supplies = 1000000
	var slot: int = -1
	for point in Placement.grid_centers():
		if game.battle.placement_check(point, "pepper").get("valid", false):
			slot = game.battle.plant_at(point, "pepper")
			break
	expect(slot >= 0, "the highest paid archived pepper can still be deployed")
	if slot < 0: return
	game._sync_battle_geometry()
	expect(game.battle.get_plant(slot).get("source_id") == "nursery:8", "the deployed unit keeps its archived source and paid level")
	game._action("battle_plot:" + str(slot))
	await settle("archived defender inspection")
	var before: Dictionary = progress()
	await tap("manage_source")
	expect(game.screen == "home" and game.home_panel.is_empty(), "opening an archived source returns gracefully without an inaccessible plot modal")
	expect(game.garden_world.current_district().get("id") == "garden", "an archived source returns to the retained garden")
	expect(game.toast_text.contains("Растение сохранено"), "the archive flow explains that the paid plant remains preserved")
	expect(progress() == before, "the archive-source action cannot change levels, income, wallet or saved plants")
	game._open_plot("home", 12)
	await settle("direct archived plot request")
	expect(game.home_panel.is_empty(), "an old direct plot ID cannot reopen a removed map district")


func check_legacy_camera_recovery() -> void:
	configure_compact("full")
	game.battle = null
	game.state.session_data = {"version": 1, "camera_center": Vector2(480, 2448), "camera_zoom": 0.8, "camera_context": {"focus": Vector2(480, 2448)}, "battle": {}}
	var before: Dictionary = progress()
	game._restore_session()
	await settle("legacy southern camera")
	expect(THREE_REGIONS.has(game.garden_world.current_district().get("id")), "a saved removed-region camera recovers a retained navigation context")
	expect(THREE_WORLD.WORLD_RECT.grow(0.1).encloses(game.garden_world.visible_world_rect()), "the old southern camera stays inside the compact world")
	expect(progress() == before, "camera recovery never mutates paid player progress")
	await tap("open_districts")
	verify_three_rows("legacy camera")
	await tap("close_home_panel")


func run() -> void:
	if not await prepare("three-district-ui"):
		push_error(str(errors))
		quit(1)
		return
	var real_before: Dictionary = progress()
	game._restore_session()
	await settle("copied real save")
	expect(progress() == real_before, "the real old save restores without altering serialized progress")
	await check_navigation()
	await check_picker_profiles()
	await check_greenhouse_pond()
	await check_campaign_and_help()
	await check_archived_source()
	await check_legacy_camera_recovery()
	if source_digest != FileAccess.get_sha256(save_copy): errors.append("Player save copy was changed")
	print("Three district native UI: ", checks, " checks; issues=", errors)
	game.queue_free()
	quit(0 if errors.is_empty() else 1)
