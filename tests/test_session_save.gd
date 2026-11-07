extends SceneTree

const SAVE_PATH: String = "/private/tmp/planta2-session-integration-test.json"
var failures: int = 0
var checks: int = 0
var game: Node2D
var resumed: Node2D

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func fresh_game() -> Node2D:
	var instance: Node2D = load("res://scenes/main.tscn").instantiate()
	instance.test_mode = true
	root.add_child(instance)
	instance.set_process(false)
	return instance

func run() -> void:
	game = fresh_game()
	await process_frame
	game.state.plant_plot("nursery", 0, "nettle")
	game._action("battle")
	game._action("stage:1")
	# Keep this pre-existing saved-attempt scenario on its original geometry;
	# dynamic free placement and the new maps have their own native roundtrip.
	game.battle.configure(game.state, game.Layout.battle_route(), game.Layout.battle_plots(), 1)
	game._sync_battle_geometry()
	game._action("confirm_loadout")
	for slot in [1, 4, 5]: game.battle.plant(slot, "nettle")
	game.battle.plant(0, "tomato")
	game.battle.reward_rng.seed = 44117
	game.battle.start_wave()
	for step in range(137): game._process(0.05)
	game.garden_world.set_zoom(1.35)
	game.garden_world.set_center(Vector2(205, 340))
	game._save(SAVE_PATH)
	var before: Dictionary = game.battle.export_snapshot()
	resumed = fresh_game()
	expect(resumed.state.load_game(SAVE_PATH), "atomic garden/checkpoint file loads through the ordinary save reader")
	expect(resumed.state.coins == game.state.coins, "saved garden coins correspond to the exact combat checkpoint")
	resumed._restore_session()
	expect(resumed.battle != null, "main scene reconnects the restored active battle")
	if resumed.battle == null:
		cleanup()
		return
	expect(resumed.screen == "home" and resumed.battle.paused, "restart opens a safe garden with an explicitly paused battle")
	expect(resumed.garden_world.center.is_equal_approx(game.garden_world.center) and is_equal_approx(resumed.garden_world.zoom, game.garden_world.zoom), "camera and zoom survive restart with clamping")
	expect(is_equal_approx(resumed.battle_play_seconds, game.battle_play_seconds), "actual active play time survives restart and excludes offline time")
	expect(resumed.battle.coin_rewarded.is_connected(resumed._coin_rewarded) and resumed.battle.changed.is_connected(resumed._state_changed), "restored battle reconnects payouts, UI and save scheduling")
	expect(resumed.battle.supplies == game.battle.supplies and resumed.battle.enemies.size() == game.battle.enemies.size(), "restoration neither pays again nor drops the current attackers")
	resumed.battle.tick(10)
	expect(resumed.battle.supplies == game.battle.supplies and resumed.battle.kills == game.battle.kills, "paused or offline time cannot create combat rewards")
	resumed._action("battle")
	var played_before: float = resumed.battle_play_seconds
	var simulated_before: float = resumed.battle.active_seconds
	game.battle.speed = 2.0
	resumed.battle.speed = 2.0
	game.battle.paused = false
	resumed.battle.paused = false
	game._process(0.2)
	resumed._process(0.2)
	expect(is_equal_approx(resumed.battle_play_seconds - played_before, 0.2) and is_equal_approx(resumed.battle.active_seconds - simulated_before, 0.4), "x2 accelerates the simulation while the displayed session clock measures actual active play")
	resumed.battle.paused = true
	resumed._process(0.2)
	expect(is_equal_approx(resumed.battle_play_seconds - played_before, 0.2), "the session clock does not count a paused battle")
	resumed.battle.paused = false
	for step in range(18000):
		if game.battle.phase != "running": break
		game.battle.tick(0.05)
		resumed.battle.tick(0.05)
	expect(game.battle.phase == "between" and resumed.battle.phase == "between", "original and resumed first waves finish normally")
	expect(resumed.battle.kills == game.battle.kills and resumed.battle.supplies == game.battle.supplies and resumed.state.coins == game.state.coins, "RNG and guaranteed payouts remain identical after resuming")
	resumed._save(SAVE_PATH)
	var third: Node2D = fresh_game()
	third.state.load_game(SAVE_PATH)
	third._restore_session()
	expect(third.battle != null and third.battle.phase == "between" and third.battle.wave == 1, "between-wave checkpoints preserve the completed wave")
	if third.battle != null:
		var resources: int = third.battle.supplies
		third.battle.tick(10)
		expect(third.battle.supplies == resources, "loading a completed wave cannot repay its harvest or bonus")
	third.queue_free()
	for district in GardenWorld.districts():
		var wanted: String = str(district["id"])
		game.garden_world.set_zoom(GardenWorld.ZOOM_MIN)
		game.garden_world.focus_district(wanted)
		var saved_center: Vector2 = game.garden_world.center
		var saved_context: Dictionary = game.garden_world.navigation_context()
		game._save(SAVE_PATH)
		var navigation_copy: Node2D = fresh_game()
		expect(navigation_copy.state.load_game(SAVE_PATH), "semantic camera checkpoint loads for " + wanted)
		navigation_copy._restore_session()
		expect(navigation_copy.garden_world.current_district().get("id", "") == wanted, "selected district survives restart at minimum zoom despite camera clamping: " + wanted)
		expect(navigation_copy.garden_world.center.is_equal_approx(saved_center) and navigation_copy.garden_world.navigation_context() == saved_context, "semantic context restoration never moves the saved camera: " + wanted)
		expect(navigation_copy.state.completed_level == game.state.completed_level and navigation_copy.state.home_plots == game.state.home_plots and navigation_copy.state.nursery_plots == game.state.nursery_plots and navigation_copy.state.pond_plots == game.state.pond_plots, "previewing or restoring a district grants no land and preserves all real plantings: " + wanted)
		navigation_copy.queue_free()
	resumed.battle = null
	resumed.state.session_data = {"version":1, "camera_center":Vector2.INF, "camera_zoom":NAN, "camera_context":{"focus":Vector2.INF}, "battle":{"version":1,"phase":"running"}}
	resumed._restore_session()
	expect(resumed.battle == null and resumed.garden_world.center.is_finite(), "a broken optional checkpoint cannot corrupt the garden or camera")
	expect(not before.is_empty(), "the checkpoint contains an actual running battle rather than an empty placeholder")
	cleanup()

func cleanup() -> void:
	if game != null: game.queue_free()
	if resumed != null: resumed.queue_free()
	DirAccess.remove_absolute(SAVE_PATH)
	print("Session save integration: ", checks, " checks; ", failures, " failures")
	quit(0 if failures == 0 else 1)
