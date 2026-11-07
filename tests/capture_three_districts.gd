extends "res://tests/capture_planting_reference.gd"

## Read-only native evidence for the compact map and its three destinations.
const THREE_WORLD = preload("res://scripts/garden_world.gd")
const THREE_REGIONS = ["garden", "nursery", "greenhouse"]
var source_digest: String = ""


func prepare(default_prefix: String) -> bool:
	prefix = default_prefix
	save_copy = "/private/tmp/planta2-three-district-save.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="): prefix = arg.trim_prefix("--prefix=")
		if arg.begins_with("--save-copy="): save_copy = arg.trim_prefix("--save-copy=")
	if not FileAccess.file_exists(save_copy):
		errors.append("An isolated player save copy is required: " + save_copy)
		return false
	source_digest = FileAccess.get_sha256(save_copy)
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_process(false)
	await create_timer(0.2).timeout
	if not game.state.load_game(save_copy):
		errors.append("Cannot load isolated player save copy")
		return false
	return true


func configure_compact(label: String) -> void:
	game._show_screen("home")
	game.state = StateScript.new()
	for stage in range(1, 4): game.state.claim_stage_reward(stage)
	game.state.coins = 1000000
	game.state.home_plots.fill("")
	game.state.nursery_plots.fill("")
	game.state.pond_plots.fill("")
	game.home_panel = ""
	game.help_open = false
	game.stage_open = false
	game.result_open = false
	game.active_plot_area = ""
	game.active_plot_slot = -1
	if label == "empty": return
	for slot in range(8):
		game.state.home_plots[slot] = ["tomato", "marigold", "pumpkin"][slot % 3]
		game.state.home_levels[slot] = [1, 7, 15, 20][slot % 4]
		game.state.nursery_plots[slot] = ["nettle", "lavender", "pepper"][slot % 3]
		game.state.nursery_levels[slot] = [1, 7, 15, 20][slot % 4]
	for slot in range(8, 12):
		game.state.home_plots[slot] = ["cucumber", "strawberry", "currant", "mint"][slot - 8]
		game.state.home_levels[slot] = [1, 7, 15, 20][slot - 8]
	for slot in range(6):
		game.state.pond_plots[slot] = "waterlily" if slot % 2 == 0 else "lotus"
		game.state.pond_levels[slot] = [1, 7, 15, 20][slot % 4]
	game.state.home_ready = true
	game.state.home_elapsed = game.state.home_cycle()


func run() -> void:
	if not await prepare("three-districts"):
		push_error(str(errors))
		quit(1)
		return
	for region in THREE_REGIONS:
		await capture("real-" + region, region, THREE_WORLD.DEFAULT_ZOOM)
	await capture("real-greenhouse-pond", "pond", THREE_WORLD.DEFAULT_ZOOM)
	for label in ["empty", "full"]:
		configure_compact(label)
		game._action("open_districts")
		await capture(label + "-three-cards", "garden", THREE_WORLD.DEFAULT_ZOOM)
	configure_compact("empty")
	game._open_plot("home", 8)
	await capture("greenhouse-four-choices", "greenhouse", THREE_WORLD.DEFAULT_ZOOM)
	configure_compact("full")
	game._open_plot("pond", 0)
	await capture("water-plant-details", "pond", THREE_WORLD.DEFAULT_ZOOM)
	if source_digest != FileAccess.get_sha256(save_copy): errors.append("Player save copy was changed")
	print("Three district capture: ", captures, " frames; source sha256=", source_digest, "; issues=", errors)
	game.queue_free()
	quit(0 if errors.is_empty() else 1)
