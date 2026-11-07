extends SceneTree

## Actual paid placements and authored live spawns; no writes to user saves.
const Encounter = preload("res://scripts/battle_encounter_art.gd")
const Placement = preload("res://scripts/battle_placement.gd")
var game: Node2D
var errors: Array[String] = []
var captures: int = 0
var prefix: String = "battle-redesign-pass1"


func _initialize() -> void:
	run.call_deferred()


func capture(label: String) -> void:
	game.toast_time = 0
	var before: Dictionary = game.battle.export_snapshot()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	for layout in game.text_layouts:
		if layout["truncated"]: errors.append(label+": text truncated: "+str(layout["text"]))
		for run in layout["runs"]:
			if not layout["bounds"].grow(0.1).encloses(run["rect"]): errors.append(label+": glyphs escape bounds")
	if before!=game.battle.export_snapshot(): errors.append(label+": drawing mutated actual combat")
	var result: Error = root.get_texture().get_image().save_png("res://artifacts/"+prefix+"-"+label+".png")
	if result!=OK: errors.append(label+": screenshot could not be written")
	captures+=1


func prepare(stage: int) -> void:
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_process(false)
	await process_frame
	game.state.coins = 100000
	for victory in range(1,4): game.state.claim_stage_reward(victory)
	game.state.plant_plot("nursery",0,"nettle")
	game.state.plant_plot("nursery",1,"lavender")
	game.state.plant_plot("nursery",2,"pepper")
	game.state.nursery_levels[0] = 3
	game.current_stage = stage
	game._new_battle()
	game._show_screen("battle")
	game.loadout_choices.assign(["nettle","tomato"] if stage==1 else ["nettle","lavender","tomato"] if stage==2 else ["nettle","lavender","pepper","tomato"])
	game._action("confirm_loadout")


func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--prefix="): prefix=argument.trim_prefix("--prefix=")
	for stage in range(1,4):
		await prepare(stage)
		await capture("stage%d-preparation" % stage)
		game.quick_plant_kind = "nettle"
		await capture("stage%d-coverage" % stage)
		var choices: Array[Dictionary] = Encounter.coverage_hints(game.battle,"nettle")
		if choices.is_empty(): errors.append("no actual useful opening position"); continue
		game.battle.plant_at(choices[0]["position"],"nettle")
		choices = Encounter.coverage_hints(game.battle,"nettle")
		if choices.is_empty(): errors.append("no actual useful second position"); continue
		game.battle.plant_at(choices[0]["position"],"nettle")
		game._sync_battle_geometry()
		game.quick_plant_kind = ""
		await capture("stage%d-ready" % stage)
		game.battle.start_wave()
		for step in range(240): game.battle.tick(0.05)
		game._sync_battle_geometry()
		await capture("stage%d-running" % stage)
		# Use a later real tick with a live shot, never fabricate a hit or enemy.
		for step in range(360):
			game.battle.tick(1.0/60.0)
			if not game.battle.shots.is_empty() and float(game.battle.shots[0]["life"])<0.08: break
		game._sync_battle_geometry()
		await capture("stage%d-impact" % stage)
		game.battle.paused = true
		await capture("stage%d-paused" % stage)
	print("Battle redesign capture: ",captures," frames; issues=",errors)
	game.queue_free()
	quit(0 if errors.is_empty() else 1)
