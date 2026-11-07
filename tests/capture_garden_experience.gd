extends "res://tests/capture_square_beds.gd"

## Native, isolated proof of the living-garden pass and its real next action.
## No capture writes to the player's save or manufactures a grown defender.
const Experience = preload("res://scripts/garden_experience.gd")
var checks: int = 0


func expect(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		errors.append(reason)
		push_error(reason)


func fixture_state(label: String) -> GardenState:
	if label == "fresh" or label == "fresh_growing":
		var fresh := StateScript.new()
		# The real first visit starts with its existing three crops ripe. This
		# fixture models that first visit, without granting a plant or a coin.
		fresh.home_ready = label == "fresh"
		fresh.home_elapsed = fresh.home_cycle() if label == "fresh" else fresh.home_cycle()*0.25
		return fresh
	return super.fixture_state(label)


func hit(action: String) -> Rect2:
	for index in range(game.hitboxes.size()-1,-1,-1):
		if str(game.hitboxes[index]["action"]) == action: return game.hitboxes[index]["rect"]
	return Rect2()


func settle(label: String) -> void:
	game.toast_time = 0
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	for layout in game.text_layouts:
		expect(not layout["truncated"],label+": complete text: "+str(layout["text"]))
		for run in layout["runs"]:
			expect(layout["bounds"].grow(0.2).encloses(run["rect"]),label+": glyphs fit: "+str(layout["text"]))
	for target in game.hitboxes:
		if target.get("world",false) or str(target["action"]) == "battle_ground": continue
		var rect: Rect2 = target["rect"]
		expect(Rect2(0,0,540,960).grow(0.2).encloses(rect),label+": control remains on screen")
		expect(rect.size.x >= 44 and rect.size.y >= 44,label+": control keeps a full touch target")


func tap_action(action: String) -> bool:
	await settle("before "+action)
	var rect: Rect2 = hit(action)
	expect(rect.has_area(),"visible touch target exists: "+action)
	if not rect.has_area(): return false
	for pressed in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.pressed = pressed
		event.position = game.get_global_transform_with_canvas()*rect.get_center()
		root.push_input(event,true)
		await process_frame
	await settle("after "+action)
	return true


func capture(label: String, district: String = "garden", zoom: float = 0.8, center = null) -> void:
	await super.capture(label,district,zoom,center)
	await settle(label)


func check_latent_cells() -> void:
	await install_case("empty")
	var before: Dictionary = progress()
	for area in ["home","nursery"]:
		for slot in [0,35,36,71,72,107,108,143]:
			game.garden_world.set_zoom(0.8)
			game.garden_world.set_center(LARGE_GRID.planting_rect(area,slot).get_center())
			await settle("meadow cell %s:%d" % [area,slot])
			var action: String = ("home_plot:" if area == "home" else "nursery_plot:")+str(slot)
			var target: Rect2 = hit(action)
			expect(target.has_area() and target.size.x >= 44 and target.size.y >= 44,"an unplanted meadow cell keeps its actual finger-sized target: "+action)
			await tap_action(action)
			expect(game.home_panel == "plant_picker" and game.active_plot_area == area and game.active_plot_slot == slot,"touching meadow opens its exact saved planting: "+action)
			await tap_action("plot_back")
			expect(progress() == before,"browsing an empty meadow never buys a planting or changes progress")


func check_first_defender_journey() -> void:
	await install_case("fresh")
	var fresh: Dictionary = progress()
	await capture("fresh-garden","garden",LARGE_WORLD.DEFAULT_ZOOM)
	expect(Experience.next_goal(game.state)["id"] == "first_defender","fresh next action asks for a genuine first defender")
	await tap_action("garden_goal")
	expect(game.home_panel == "plant_picker" and game.active_plot_area == "nursery","the first goal opens the real nursery picker")
	expect(game.battle == null and progress() == fresh,"the first goal grants no free defender, currency or battle")
	await capture("fresh-first-defender-picker","nursery",0.8)
	var wallet: int = game.state.coins
	await tap_action("plant:nettle")
	expect(game.state.plot_kind("nursery",0) == "nettle" and game.state.coins < wallet,"the suggested defender is a real paid nursery planting")
	expect(Experience.next_goal(game.state)["id"] == "open_water","a paid defensive template immediately advances the real next action")
	await tap_action("close_home_panel")
	await capture("first-defender-feedback","nursery",0.8,LARGE_GRID.planting_rect("nursery",0).get_center())
	expect(not game.garden_moments.is_empty(),"real planting creates a short tending response")
	var active_caption: bool = false
	for layout in game.text_layouts:
		if str(layout["text"]) == "Новая жизнь": active_caption = true
	expect(active_caption,"a visible planting response accompanies the actual planted cell")
	game.elapsed += 2.0
	await settle("expired planting feedback")
	for layout in game.text_layouts:
		expect(str(layout["text"]) != "Новая жизнь","expired tending captions do not remain on the map")
	game._action("garden_journal")
	await capture("journal-after-first-defender","nursery",0.8)
	expect(hit("garden_goal").has_area() and hit("close_home_panel").has_area(),"journal exposes the truthful next action and a clear return")
	await tap_action("close_home_panel")
	await tap_action("garden_goal")
	expect(game.stage_open and game.battle == null,"after growing a defender, next action offers the real first defense selection")
	await capture("first-defense-offer","nursery",0.8)
	await tap_action("close_stage")
	game._action("home")
	game.state.nursery_plots[0] = ""
	game.state.nursery_levels[0] = 1
	var empty_defense: Dictionary = progress()
	game._action("battle")
	expect(game.battle == null and game.home_panel == "plant_picker" and game.active_plot_area == "nursery","the battle shortcut also routes a player without a defender to the real nursery")
	expect(progress() == empty_defense,"battle guidance never invents a defensive template")


func check_first_harvest() -> void:
	await install_case("fresh")
	game.garden_world.focus_district("garden")
	var wallet: int = game.state.coins
	var income: int = game.state.collectable_home_income()
	var crops: Array[String] = game.state.home_plots.duplicate()
	var levels: Array[int] = game.state.home_levels.duplicate()
	expect(income > 0,"the real first visit offers an immediate harvest from its three existing crops")
	await tap_action("collect")
	expect(game.state.coins == wallet+income and not game.state.home_ready,"first tending earns exactly one real crop yield and consumes the ripe cycle")
	expect(game.state.home_plots == crops and game.state.home_levels == levels,"first tending neither creates crops nor changes paid levels")
	await capture("first-harvest-feedback","garden",LARGE_WORLD.DEFAULT_ZOOM)
	var after_harvest: Dictionary = progress()
	await settle("after first harvest")
	expect(progress() == after_harvest,"rendering the first harvest cannot grant it again")


func run() -> void:
	if not configure_arguments("garden-experience-pass1"):
		push_error(str(errors))
		quit(1)
		return
	# These two first frames unblock artistic review before the wider audit.
	await install_case("real")
	await capture("real-garden","garden",LARGE_WORLD.DEFAULT_ZOOM)
	await install_case("fresh")
	await capture("fresh-garden","garden",LARGE_WORLD.DEFAULT_ZOOM)
	await install_case("fresh_growing")
	await capture("fresh-growing-garden","garden",LARGE_WORLD.DEFAULT_ZOOM)
	for label in ["real","empty","partial","full"]:
		await capture_overview(label)
		await install_case(label)
		for district in ["garden","nursery","greenhouse","pond"]:
			await capture(label+"-"+district,district,maxf(0.8,LARGE_WORLD.DEFAULT_ZOOM) if district == "greenhouse" else LARGE_WORLD.DEFAULT_ZOOM)
		await capture_junctions(label)
	for label in ["empty","full"]:
		await install_case(label)
		for pair in [["min",LARGE_WORLD.ZOOM_MIN],["max",LARGE_WORLD.ZOOM_MAX]]:
			for district in ["garden","nursery","pond"]:
				await capture(label+"-"+district+"-"+pair[0],district,pair[1])
	await check_latent_cells()
	await check_first_harvest()
	await check_first_defender_journey()
	await install_case("real")
	game._action("garden_journal")
	await capture("journal-real","garden",LARGE_WORLD.DEFAULT_ZOOM)
	expect(source_digest == FileAccess.get_sha256(save_copy),"the isolated real save copy remains byte-for-byte unchanged")
	print("Garden experience native: ",checks," checks; ",captures," frames; source sha256=",source_digest,"; issues=",errors)
	game.queue_free()
	quit(0 if errors.is_empty() else 1)
