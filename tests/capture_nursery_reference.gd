extends "res://tests/capture_planting_reference.gd"

## Isolated native reference comparisons for the fenced nursery district.
## Supply --prefix=nursery-reference-before or --prefix=nursery-reference-after.
const NURSERY_WORLD = preload("res://scripts/garden_world.gd")
var source_digest: String = ""


func capture_nursery_state(label: String) -> void:
	game.home_panel = ""
	game.active_plot_area = ""
	game.active_plot_slot = -1
	for zoom_pair in [["min", NURSERY_WORLD.ZOOM_MIN], ["default", NURSERY_WORLD.DEFAULT_ZOOM], ["max", NURSERY_WORLD.ZOOM_MAX]]:
		await capture(label + "-nursery-" + zoom_pair[0], "nursery", zoom_pair[1])


func run() -> void:
	prefix = "nursery-reference-after"
	save_copy = "/private/tmp/planta2-nursery-player-copy.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="): prefix = arg.trim_prefix("--prefix=")
		if arg.begins_with("--save-copy="): save_copy = arg.trim_prefix("--save-copy=")
	if not FileAccess.file_exists(save_copy):
		push_error("An isolated nursery player save copy is required: " + save_copy)
		quit(1)
		return
	source_digest = FileAccess.get_sha256(save_copy)
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_process(false)
	await create_timer(0.2).timeout
	if not game.state.load_game(save_copy): errors.append("Cannot load isolated nursery player save copy")
	else: await capture_nursery_state("real")
	for label in ["empty", "partial", "full"]:
		configure(label)
		await capture_nursery_state(label)
	game._action("nursery")
	await capture("nursery-menu", "nursery", NURSERY_WORLD.DEFAULT_ZOOM)
	game.home_panel = ""
	for milestone in [1, 7, 15]:
		game.state.nursery_levels[0] = milestone
		game._open_plot("nursery", 0)
		await capture("nettle-upgrade-level-" + str(milestone), "nursery", NURSERY_WORLD.DEFAULT_ZOOM)
		game.home_panel = ""
	if source_digest != FileAccess.get_sha256(save_copy): errors.append("Player save copy was changed")
	print("Nursery reference capture: ", captures, " frames; source sha256=", source_digest, "; issues=", errors)
	game.queue_free()
	quit(0 if errors.is_empty() else 1)
