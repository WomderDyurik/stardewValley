extends "res://tests/capture_planting_reference.gd"

## Read-only native comparisons against the supplied farmhouse screenshot.
## Run with --prefix=stardew-farm-before or --prefix=stardew-farm-after.
## The real state is read only from an explicit isolated JSON copy.
const FARM_WORLD = preload("res://scripts/garden_world.gd")
const FARM_DISTRICTS = ["pond", "nursery", "greenhouse"]
var source_digest: String = ""


func capture_state(label: String) -> void:
	for zoom_pair in [["min", FARM_WORLD.ZOOM_MIN], ["default", FARM_WORLD.DEFAULT_ZOOM], ["max", FARM_WORLD.ZOOM_MAX]]:
		await capture(label + "-garden-" + zoom_pair[0], "garden", zoom_pair[1])
	for district in FARM_DISTRICTS:
		await capture(label + "-" + district + "-default", district, FARM_WORLD.DEFAULT_ZOOM)


func run() -> void:
	prefix = "stardew-farm-after"
	save_copy = "/private/tmp/planta2-stardew-farm-player-save.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="): prefix = arg.trim_prefix("--prefix=")
		if arg.begins_with("--save-copy="): save_copy = arg.trim_prefix("--save-copy=")
	if not FileAccess.file_exists(save_copy):
		push_error("An isolated player save copy is required: " + save_copy)
		quit(1)
		return
	source_digest = FileAccess.get_sha256(save_copy)
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_process(false)
	await create_timer(0.2).timeout
	if not game.state.load_game(save_copy):
		errors.append("Cannot load isolated player save copy")
	else:
		await capture_state("real")
	for label in ["empty", "partial", "full"]:
		configure(label)
		await capture_state(label)
	configure("growing")
	await capture("growing-garden-default", "garden", FARM_WORLD.DEFAULT_ZOOM)
	configure("full")
	# The bank and its floating plant targets need both camera limits as well.
	for zoom_pair in [["min", FARM_WORLD.ZOOM_MIN], ["max", FARM_WORLD.ZOOM_MAX]]:
		await capture("full-pond-" + zoom_pair[0], "pond", zoom_pair[1])
	for id in game.state.helper_levels: game.state.helper_levels[id] = 1
	await capture("helpers-garden-default", "garden", FARM_WORLD.DEFAULT_ZOOM)
	if source_digest != FileAccess.get_sha256(save_copy): errors.append("Player save copy was changed")
	print("Stardew farmhouse capture: ", captures, " frames; source sha256=", source_digest, "; issues=", errors)
	game.queue_free()
	quit(0 if errors.is_empty() else 1)
