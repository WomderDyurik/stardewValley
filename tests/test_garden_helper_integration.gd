extends "res://tests/capture_planting_reference.gd"

## Real native menus, paid construction, atomic checkpoint and legacy migration.
const HelperArt = preload("res://scripts/garden_helper_visuals.gd")
const Terrain = preload("res://scripts/garden_terrain.gd")
const World = preload("res://scripts/garden_world.gd")
const Grid = preload("res://scripts/garden_grid.gd")
const Placement = preload("res://scripts/battle_placement.gd")
var checks: int = 0
var save_path: String


func expect(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		errors.append(reason)
		push_error(reason)


func fresh_game() -> Node2D:
	var instance: Node2D = load("res://scenes/main.tscn").instantiate()
	instance.test_mode = true
	root.add_child(instance)
	instance.set_process(false)
	return instance


func hit(action: String) -> Rect2:
	for index in range(game.hitboxes.size()-1,-1,-1):
		if game.hitboxes[index]["action"] == action: return game.hitboxes[index]["rect"]
	return Rect2()


func settle() -> void:
	game.toast_time = 0
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	for layout in game.text_layouts:
		expect(not layout["truncated"],"helper menu text is complete: "+str(layout["text"]))
		for run in layout["runs"]:
			expect(layout["bounds"].grow(0.1).encloses(run["rect"]),"helper menu glyphs remain inside their allocated bounds")


func tap(action: String) -> void:
	var rect: Rect2 = hit(action)
	expect(rect.has_area(),"native control exists: "+action)
	if not rect.has_area(): return
	var point: Vector2 = game.get_global_transform_with_canvas()*rect.get_center()
	for pressed in [true,false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = pressed
		touch.position = point
		root.push_input(touch,true)
	await settle()


func check_placement() -> void:
	for id in HelperArt.FRAMES:
		var frame: Rect2 = HelperArt.FRAMES[id]
		expect(World.WORLD_RECT.encloses(frame),"helper sprite remains inside the estate: "+id)
		for area in ["home","nursery","pond"]:
			var count: int = 24 if area == "home" else 12 if area == "nursery" else 6
			for slot in range(count):
				var bounds: Rect2 = World.plot_visual_rect(slot) if area == "home" else World.nursery_plot_rect(slot) if area == "nursery" else World.pond_plot_rect(slot)
				expect(not frame.intersects(bounds),"helper leaves the full planting visible: %s/%s:%d" % [id,area,slot])
		for route in Terrain.path_rects(): expect(not route.intersects(frame),"helper does not block the real walking network: "+id)
		for tree in Terrain.tree_rects(): expect(not tree.intersects(frame),"helper does not collide with a tree canopy: "+id)
		for building in World.building_hit_regions().values(): expect(not Rect2(building).intersects(frame),"helper is separate from building interactions: "+id)
		for prop in World.PROP_RECTS.values()+World.SIGN_RECTS.values()+[Terrain.WELL_RECT,Terrain.POND_BENCH_RECT,Grid.BERRY_BENCH_RECT]:
			expect(not Rect2(prop).intersects(frame),"helper stays separate from garden furniture and signs: "+id)
		for other_id in HelperArt.FRAMES:
			if other_id != id: expect(not Rect2(HelperArt.FRAMES[other_id]).intersects(frame),"built helpers retain separate silhouettes")
		for segment in Terrain.fence_segments():
			var footprint := Rect2(Vector2(segment[0]).min(segment[1])-Vector2(4,24),(Vector2(segment[1])-Vector2(segment[0])).abs()+Vector2(52,56))
			expect(not footprint.intersects(frame),"helper stays clear of fence timber: "+id)


func check_badges() -> void:
	for id in HelperArt.FRAMES:
		for zoom in [0.5,0.8,1.35]:
			game.garden_world.set_zoom(zoom)
			game.garden_world.set_center(HelperArt.FRAMES[id].get_center())
			await settle()
			var frame: Rect2 = HelperArt.FRAMES[id]
			var body: Rect2 = HelperArt.sprite_bounds(id)
			var projected := Rect2(game.garden_world.world_to_screen(body.position),body.size*zoom)
			var found: bool = false
			for label in game.active_view.world_label_layouts:
				if label["kind"] == "level" and label["world_rect"] == frame:
					found = true
					expect(not Rect2(label["rect"]).intersects(projected),"the real rendered level badge never hides its equipment body at zoom "+str(zoom)+": "+id)
			expect(found,"visible built equipment has a readable external level badge: "+id)


func run() -> void:
	prefix = "garden-planting-after"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="): prefix = arg.trim_prefix("--prefix=")
	save_path = "/private/tmp/planta2-helper-native-%d.json" % OS.get_process_id()
	game = fresh_game()
	await settle()
	var migrated = StateScript.new()
	expect(migrated.load_game(save_copy),"real v4 copy loads through the new reader")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_copy))
	expect(migrated.coins == source["coins"] and migrated.completed_level == source["completed_level"],"v4 migration preserves the real wallet and campaign")
	for field in ["home_plots","nursery_plots","pond_plots","unlocked_seeds"]:
		expect(migrated.get(field) == source[field],"v4 migration preserves every paid planting field: "+field)
	# JSON numbers are floats; typed level arrays are integers after loading.
	# Compare every integer value without falsely rejecting its container type.
	for field in ["home_levels","nursery_levels","pond_levels"]:
		var actual: Array = migrated.get(field)
		expect(actual.size() == source[field].size(),"v4 keeps every paid level slot: "+field)
		for slot in range(actual.size()):
			expect(actual[slot] == int(source[field][slot]),"v4 keeps the exact individual level: %s:%d" % [field,slot])
	expect(migrated.levels.size() == source["levels"].size(),"v4 keeps the old catalog entries")
	for kind in source["levels"]:
		expect(migrated.levels[kind] == int(source["levels"][kind]),"v4 keeps the old catalog level: "+kind)
	var checkpoint: Dictionary = bytes_to_var(Marshalls.base64_to_raw(source["session"]))
	expect(migrated.session_data == checkpoint,"real v4 optional battle and camera checkpoint survives migration exactly")
	expect(migrated.helper_levels.values().all(func(level): return level == 0),"old save grants no imaginary built equipment")
	check_placement()
	configure("growing")
	for id in game.state.Helpers.ORDER:
		game.garden_world.set_center(HelperArt.FRAMES[id].get_center())
		await settle()
		expect(not hit("helper:"+id).has_area(),"unbuilt helper has no world interaction: "+id)
	game._action("open_districts")
	await settle()
	await tap("helpers")
	expect(game.home_panel == "helpers","district menu opens the equipment overview")
	await capture("menu-helpers-unbuilt")
	await tap("helper:irrigation")
	await capture("menu-helper-irrigation-unbuilt")
	var fraction: float = game.state.home_growth_fraction()
	for id in game.state.Helpers.ORDER:
		game._action("helper:"+id)
		await settle()
		var wallet: int = game.state.coins
		var price: int = game.state.helper_upgrade_cost(id)
		await tap("upgrade_helper:"+id)
		expect(game.state.helper_level(id) == 1 and game.state.coins == wallet-price,"native build charges once and installs selected equipment: "+id)
	expect(is_equal_approx(game.state.home_growth_fraction(),fraction) and game.state.home_cycle() < 30.0,"real irrigation accelerates the current crop without granting or discarding growth")
	game._action("close_home_panel")
	await capture("built-helpers-garden","garden",0.5)
	await capture("built-helpers-garden-default","garden",0.8)
	await capture("built-helpers-greenhouse","greenhouse",0.8)
	await check_badges()
	for id in game.state.Helpers.ORDER:
		game.garden_world.set_zoom(0.5)
		game.garden_world.set_center(HelperArt.FRAMES[id].get_center())
		await settle()
		var rect: Rect2 = hit("helper:"+id)
		expect(rect.size.x >= 44 and rect.size.y >= 44,"built world helper remains finger-sized at minimum zoom: "+id)
		await tap("helper:"+id)
		expect(game.home_panel == "helper_details" and game.active_helper_id == id,"world helper touch opens its own details: "+id)
		await tap("locate_helper:"+id)
		expect(game.home_panel.is_empty() and game.garden_world.zoom == 0.8,"locate returns to the actual garden at usable zoom: "+id)
	game._action("helper:harvest_crate")
	await settle()
	await tap("upgrade_helper:harvest_crate")
	game._action("close_home_panel")
	game.state.tick(game.state.home_cycle()*2.0+5.0-game.state.home_elapsed)
	expect(game.state.stored_harvests() == 2 and game.state.harvest_capacity() == 3 and is_equal_approx(game.state.home_elapsed,5.0),"equipment accumulates two genuine crops beside a partial third")
	var amount: int = game.state.collectable_home_income()
	expect(amount == game.state.home_income()*2,"banked amount equals two actual compost-enriched crops")
	game._action("battle")
	game._action("stage:1")
	game._action("confirm_loadout")
	expect(game.battle != null,"native equipment coexistence creates a real battle")
	if game.battle != null:
		var installed: bool = false
		for point in Placement.grid_centers():
			if game.battle.placement_check(point,"nettle").get("valid",false):
				installed = game.battle.plant_at(point,"nettle") >= 0
				break
		expect(installed,"the helper checkpoint includes a real paid cannon in a legal cell")
		expect(game.battle.start_wave(),"the helper checkpoint begins a real wave")
		game.battle.tick(1.0)
	game._show_screen("home")
	game._save(save_path)
	var saved_state: Dictionary = progress()
	var saved_battle: Dictionary = game.battle.export_snapshot() if game.battle != null else {}
	var original: Node2D = game
	game = fresh_game()
	expect(game.state.load_game(save_path),"main atomic save with helpers and battle loads")
	game._restore_session()
	expect(progress() == saved_state,"all planted IDs, levels, helpers, bank, wallet and checkpoint survive the main save")
	expect(game.battle != null and game.battle.export_snapshot() == saved_battle,"the real paused battle checkpoint survives beside the helper bank")
	await capture("stored-helper-harvest")
	var wallet: int = game.state.coins
	await settle()
	await tap("collect")
	expect(game.state.coins == wallet+amount and game.state.stored_harvests() == 0 and is_equal_approx(game.state.home_elapsed,5.0),"native collect pays exactly the displayed stock and preserves unfinished growth")
	game._action("collect")
	expect(game.state.coins == wallet+amount,"repeated native collect cannot duplicate a stored crop")
	game._action("helpers")
	for id in game.state.Helpers.ORDER:
		game._action("helper:"+id)
		while game.state.helper_level(id) < 3: game._action("upgrade_helper:"+id)
	await capture("menu-helper-maximum")
	game._action("helpers")
	await capture("menu-helpers-maximum")
	game._action("close_home_panel")
	await check_badges()
	await capture("built-helpers-maximum","garden",0.5)
	game.state.coins = 0
	game.state.helper_levels["compost"] = 0
	game._action("helper:compost")
	await capture("menu-helper-unaffordable")
	expect(not hit("upgrade_helper:compost").has_area(),"unaffordable construction is visibly disabled and has no live hit target")
	game.queue_free()
	original.queue_free()
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(save_path+".tmp")
	print("Garden helper native integration: ",checks," checks; ",captures," captures; issues=",errors)
	quit(0 if errors.is_empty() else 1)
