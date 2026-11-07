extends "res://tests/capture_large_fields.gd"

## Real player data is read from a copy; all fixtures are isolated before _ready.
## Every square is populated through genuine saved slots, never crop scenery.
const PARTIAL_SLOTS = [0,1,2,6,7,12,30,35,36,37,42,65,71,72,73,78,101,107,108,109,114,137,143]


class OverviewCamera:
	extends "res://scripts/garden_world.gd"
	# Culling receives the full estate, independent of the gameplay zoom limits.
	func screen_to_world(point: Vector2) -> Vector2:
		return point/Vector2(540,960)*WORLD_SIZE
	func world_to_screen(point: Vector2) -> Vector2:
		return point*0.3


class OverviewGame:
	extends "res://scripts/main.gd"
	const Terrain = preload("res://scripts/garden_terrain.gd")
	var prepared_state: GardenState
	func _ready() -> void:
		super._ready()
		state = prepared_state
		garden_world = OverviewCamera.new()
		garden_world.zoom = 0.3
		set_process(false)
	func _draw() -> void:
		if state == null or active_view == null: return
		text_layouts.clear()
		hitboxes.clear()
		draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE*0.3)
		Terrain.draw(self,elapsed,FARM_ART)
		active_view._draw_plots(self)
		active_view._draw_buildings(self)
		active_view._draw_pond(self)
		HelperArt.draw_world(self,active_view)


func configure_arguments(default_prefix: String) -> bool:
	prefix = default_prefix
	save_copy = "/private/tmp/planta2-square-beds-save.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--prefix="): prefix = argument.trim_prefix("--prefix=")
		if argument.begins_with("--save-copy="): save_copy = argument.trim_prefix("--save-copy=")
	if not FileAccess.file_exists(save_copy):
		errors.append("Missing isolated player save copy: " + save_copy)
		return false
	source_digest = FileAccess.get_sha256(save_copy)
	return true


func fixture_state(label: String) -> GardenState:
	var fixture := StateScript.new()
	if label == "real":
		if not fixture.load_game(save_copy): errors.append("Cannot load the isolated real player save")
		return fixture
	for stage in range(1,4): fixture.claim_stage_reward(stage)
	fixture.coins = 1000000
	fixture.home_plots.fill("")
	fixture.nursery_plots.fill("")
	fixture.pond_plots.fill("")
	fixture.home_levels.fill(1)
	fixture.nursery_levels.fill(1)
	fixture.pond_levels.fill(1)
	if label == "empty": return fixture
	var block_kinds: Array[String] = ["tomato","cucumber","strawberry","pumpkin"]
	for slot in range(fixture.home_plots.size()):
		if label == "partial" and slot not in PARTIAL_SLOTS: continue
		fixture.home_plots[slot] = block_kinds[(slot/36)%block_kinds.size()]
		fixture.home_levels[slot] = [1,7,15,20][(slot/36)%4]
	for slot in range(fixture.nursery_plots.size()):
		if label == "partial" and slot not in PARTIAL_SLOTS: continue
		fixture.nursery_plots[slot] = DEFENDER_KINDS[(slot/36)%DEFENDER_KINDS.size()]
		fixture.nursery_levels[slot] = [1,7,15,20][(slot/36)%4]
	for slot in range(fixture.pond_plots.size()):
		if label == "partial" and slot not in [0,5]: continue
		fixture.pond_plots[slot] = "waterlily" if slot%2 == 0 else "lotus"
		fixture.pond_levels[slot] = [1,7,15,20][slot%4]
	fixture.home_ready = label != "growing"
	fixture.home_elapsed = fixture.home_cycle()*(0.55 if label == "growing" else 1.0)
	if label == "full": fixture.helper_levels = {"irrigation":3,"compost":3,"harvest_crate":3}
	return fixture


func capture_overview(label: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1080,864)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var overview := OverviewGame.new()
	overview.test_mode = true
	overview.prepared_state = fixture_state(label)
	viewport.add_child(overview)
	await process_frame
	overview.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var result: Error = viewport.get_texture().get_image().save_png("res://artifacts/"+prefix+"-overview-"+label+".png")
	if result != OK: errors.append("Overview "+label+": PNG save failed "+str(result))
	captures += 1
	viewport.queue_free()
	await process_frame


func capture_junctions(label: String) -> void:
	await capture(label+"-garden-junction","garden",0.6,Vector2(816,1104))
	await capture(label+"-nursery-junction","nursery",0.6,Vector2(2544,1008))


func run() -> void:
	if not configure_arguments("square-beds"):
		push_error(str(errors))
		quit(1)
		return
	var preview: bool = OS.get_cmdline_user_args().has("--preview")
	for label in ["real","empty","full"]: await capture_overview(label)
	await install_case("real")
	for district in ["garden","nursery","greenhouse","pond"]:
		await capture("real-"+district,district,maxf(0.8,LARGE_WORLD.DEFAULT_ZOOM) if district == "greenhouse" else LARGE_WORLD.DEFAULT_ZOOM)
	await capture_junctions("real")
	for label in ["empty","partial","full"]:
		await install_case(label)
		await capture_junctions(label)
		for district in ["garden","nursery","greenhouse","pond"]:
			if preview:
				if label == "full": await capture(label+"-"+district+"-default",district,LARGE_WORLD.DEFAULT_ZOOM)
				continue
			for zoom_pair in [["min",LARGE_WORLD.ZOOM_MIN],["default",LARGE_WORLD.DEFAULT_ZOOM],["max",LARGE_WORLD.ZOOM_MAX]]:
				await capture(label+"-"+district+"-"+zoom_pair[0],district,zoom_pair[1])
	if not preview:
		await install_case("growing")
		await capture_junctions("growing")
		await install_case("full")
		for area in ["home","nursery"]:
			var last: int = LARGE_GRID.planting_cells(area).size()-1
			for slot in [0,last]:
				var cell: Rect2 = LARGE_GRID.planting_rect(area,slot)
				await capture("full-"+area+"-edge-"+str(slot),"garden" if area == "home" else "nursery",1.0,cell.get_center())
		await capture("garden-bottom","garden",0.6,Vector2(816,1728))
		await capture("nursery-bottom","nursery",0.6,Vector2(2544,1632))
		game._action("greenhouse")
		await capture("greenhouse-upgrades-menu","greenhouse",0.8)
		game._action("close_home_panel")
		game._open_plot("pond",5)
		await capture("water-last-cell","pond",0.8)
		await install_case("empty")
		game._open_plot("home",LARGE_GRID.planting_cells("home").size()-1)
		await capture("home-last-cell-picker","garden",0.6)
	if source_digest != FileAccess.get_sha256(save_copy): errors.append("Player save copy was changed")
	print("Square beds capture: ",captures," frames; source sha256=",source_digest,"; issues=",errors)
	game.queue_free()
	quit(0 if errors.is_empty() else 1)
