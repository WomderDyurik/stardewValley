extends SceneTree

## Native reference comparison. Every game is isolated before entering the tree.
## Use --preview for five garden frames, or the default bounded district audit.
const StateScript = preload("res://scripts/garden_state.gd")
const DISTRICTS = ["garden","nursery","greenhouse","pond","berry","far_garden","sun_meadow"]
const STATE_FIELDS = ["coins","levels","home_plots","home_levels","nursery_plots","nursery_levels","pond_plots","pond_levels","unlocked_seeds","completed_level","home_elapsed","home_ready","session_data","helper_levels","home_stock","home_stock_value"]
var game: Node2D
var prefix: String = "garden-planting-after"
var save_copy: String = "/private/tmp/planta2-before-planting-reference.json"
var errors: Array[String] = []
var captures: int = 0


func _initialize() -> void:
	run.call_deferred()


func progress() -> Dictionary:
	var properties: Dictionary = {}
	for property in game.state.get_property_list(): properties[property["name"]] = true
	var result: Dictionary = {}
	for field in STATE_FIELDS:
		if not properties.has(field): continue
		var value = game.state.get(field)
		result[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result


func configure(label: String) -> void:
	game.state = StateScript.new()
	for stage in range(1,4): game.state.claim_stage_reward(stage)
	game.state.coins = 100000
	game.state.home_plots.fill("")
	game.state.nursery_plots.fill("")
	game.state.pond_plots.fill("")
	if label == "empty": return
	for slot in range(24):
		if label == "partial" and slot not in [0,2,8,12,13,16,20]: continue
		game.state.home_plots[slot] = ("tomato" if slot%2==0 else "marigold") if slot<8 else "cucumber" if slot<12 else ("strawberry" if slot%2==0 else "currant") if slot<16 else "mint" if slot<20 else "pumpkin"
		game.state.home_levels[slot] = [1,7,15,20][slot%4]
	for slot in range(12):
		if label == "partial" and slot not in [0,1,8,10]: continue
		game.state.nursery_plots[slot] = ("nettle" if slot%2==0 else "lavender") if slot<8 else "pepper"
		game.state.nursery_levels[slot] = [1,7,15,20][slot%4]
	for slot in range(6):
		if label == "partial" and slot not in [0,1]: continue
		game.state.pond_plots[slot] = "waterlily" if slot%2==0 else "lotus"
		game.state.pond_levels[slot] = [1,7,15,20][slot%4]
	game.state.home_ready = label != "growing"
	game.state.home_elapsed = game.state.home_cycle() * (0.55 if label == "growing" else 1.0)


func capture(label: String, district: String = "garden", zoom: float = 0.8, center = null) -> void:
	game.garden_world.set_zoom(zoom)
	game.garden_world.focus_district(district)
	if center is Vector2: game.garden_world.set_center(center)
	game.toast_time = 0
	var before: Dictionary = progress()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png("res://artifacts/"+prefix+"-"+label+".png")
	if result != OK: errors.append(label+": PNG save failed "+str(result))
	if progress() != before: errors.append(label+": render changed player state")
	for layout in game.text_layouts:
		if layout["truncated"]: errors.append(label+": truncated "+str(layout["text"]))
	captures += 1


func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="): prefix = arg.trim_prefix("--prefix=")
		if arg.begins_with("--save-copy="): save_copy = arg.trim_prefix("--save-copy=")
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_process(false)
	await create_timer(0.2).timeout
	if OS.get_cmdline_user_args().has("--preview"):
		configure("empty")
		await capture("empty-garden-default")
		configure("growing")
		await capture("growing-garden-default")
		configure("full")
		for zoom_pair in [["min",0.5],["default",0.8],["max",1.35]]:
			await capture("full-garden-"+zoom_pair[0],"garden",zoom_pair[1])
	else:
		var grid_audit: bool = OS.get_cmdline_user_args().has("--grid-audit")
		if not game.state.load_game(save_copy): errors.append("Cannot load supplied save copy")
		else:
			for district in DISTRICTS: await capture("real-"+district+"-default",district)
		for label in ["empty","full"]:
			configure(label)
			for district in DISTRICTS:
				await capture(label+"-"+district+"-default",district)
				if grid_audit and label == "full":
					for zoom_pair in [["min",0.5],["max",1.35]]:
						await capture(label+"-"+district+"-"+zoom_pair[0],district,zoom_pair[1])
		for label in ["partial","growing"]:
			configure(label)
			await capture(label+"-garden-default")
		if not grid_audit:
			configure("full")
			for district in ["garden","greenhouse","sun_meadow"]:
				for zoom_pair in [["min",0.5],["max",1.35]]:
					await capture("full-"+district+"-"+zoom_pair[0],district,zoom_pair[1])
	print("Planting reference capture: ",captures," frames; issues=",errors)
	game.queue_free()
	quit(0 if errors.is_empty() else 1)
