extends "res://tests/capture_planting_reference.gd"

## Genuine 96+96+6 fixtures prepared before entering the isolated test scene.
const LARGE_WORLD = preload("res://scripts/garden_world.gd")
const LARGE_GRID = preload("res://scripts/garden_grid.gd")
const INCOME_KINDS = ["tomato", "marigold", "pumpkin", "cucumber", "strawberry", "currant", "mint"]
const DEFENDER_KINDS = ["nettle", "lavender", "pepper"]
var source_digest: String = ""

class FixtureGame:
	extends "res://scripts/main.gd"
	var prepared_state: GardenState
	func _ready() -> void:
		super._ready()
		# Parent initialization has test_mode set before entering the tree.
		state = prepared_state
		state.changed.connect(_state_changed)


func configure_arguments(default_prefix: String) -> bool:
	prefix = default_prefix
	save_copy = "/private/tmp/planta2-large-fields-save.json"
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
	for stage in range(1, 4): fixture.claim_stage_reward(stage)
	fixture.coins = 1000000
	fixture.home_plots.fill("")
	fixture.nursery_plots.fill("")
	fixture.pond_plots.fill("")
	fixture.home_levels.fill(1)
	fixture.nursery_levels.fill(1)
	fixture.pond_levels.fill(1)
	if label == "empty": return fixture
	for slot in range(96):
		if label == "partial" and slot not in [0, 1, 8, 23, 47, 70, 94, 95]: continue
		fixture.home_plots[slot] = INCOME_KINDS[slot % INCOME_KINDS.size()]
		fixture.nursery_plots[slot] = DEFENDER_KINDS[slot % DEFENDER_KINDS.size()]
		fixture.home_levels[slot] = [1, 7, 15, 20][slot % 4]
		fixture.nursery_levels[slot] = [1, 7, 15, 20][slot % 4]
	for slot in range(6):
		if label == "partial" and slot not in [0, 5]: continue
		fixture.pond_plots[slot] = "waterlily" if slot % 2 == 0 else "lotus"
		fixture.pond_levels[slot] = [1, 7, 15, 20][slot % 4]
	fixture.home_ready = true
	fixture.home_elapsed = fixture.home_cycle()
	return fixture


func install_case(label: String) -> void:
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	var prepared: GardenState = fixture_state(label)
	game = FixtureGame.new()
	game.test_mode = true
	game.prepared_state = prepared
	root.add_child(game)
	game.set_process(false)
	await process_frame


func run() -> void:
	if not configure_arguments("large-fields"):
		push_error(str(errors))
		quit(1)
		return
	await install_case("real")
	for district in ["garden", "nursery", "greenhouse", "pond"]:
		await capture("real-" + district, district, maxf(0.8, LARGE_WORLD.DEFAULT_ZOOM) if district == "greenhouse" else LARGE_WORLD.DEFAULT_ZOOM)
	for label in ["empty", "partial", "full"]:
		await install_case(label)
		for district in ["garden", "nursery"]:
			for zoom_pair in [["min", LARGE_WORLD.ZOOM_MIN], ["default", LARGE_WORLD.DEFAULT_ZOOM], ["max", LARGE_WORLD.ZOOM_MAX]]:
				await capture(label + "-" + district + "-" + zoom_pair[0], district, zoom_pair[1])
	await install_case("full")
	for area in ["home", "nursery"]:
		for slot in [0, 95]:
			var cell: Rect2 = LARGE_GRID.planting_rect(area, slot)
			await capture("full-" + area + "-edge-" + str(slot), "garden" if area == "home" else "nursery", 1.0, cell.get_center())
	await capture("greenhouse-upgrades-yard", "greenhouse", maxf(0.8, LARGE_WORLD.DEFAULT_ZOOM))
	game._action("greenhouse")
	await capture("greenhouse-upgrades-menu", "greenhouse", maxf(0.8, LARGE_WORLD.DEFAULT_ZOOM))
	game._action("helper:irrigation")
	await capture("irrigation-unbuilt", "greenhouse", maxf(0.8, LARGE_WORLD.DEFAULT_ZOOM))
	game._action("upgrade_helper:irrigation")
	await capture("irrigation-built", "greenhouse", maxf(0.8, LARGE_WORLD.DEFAULT_ZOOM))
	game._action("upgrade_helper:irrigation")
	await capture("irrigation-upgraded", "greenhouse", maxf(0.8, LARGE_WORLD.DEFAULT_ZOOM))
	game.home_panel = ""
	await capture("full-nursery-water", "pond", LARGE_WORLD.DEFAULT_ZOOM)
	game._open_plot("pond", 0)
	await capture("water-details", "pond", LARGE_WORLD.DEFAULT_ZOOM)
	game._action("close_home_panel")
	game._action("nursery")
	game.nursery_page = 11
	await capture("nursery-page-12", "nursery", LARGE_WORLD.DEFAULT_ZOOM)
	await install_case("empty")
	game._open_plot("home", 95)
	for page in range(3):
		game.seed_page = page
		await capture("home-seven-kinds-page-" + str(page + 1), "garden", LARGE_WORLD.DEFAULT_ZOOM)
	if source_digest != FileAccess.get_sha256(save_copy): errors.append("Player save copy was changed")
	print("Large field capture: ", captures, " frames; source sha256=", source_digest, "; issues=", errors)
	game.queue_free()
	quit(0 if errors.is_empty() else 1)
