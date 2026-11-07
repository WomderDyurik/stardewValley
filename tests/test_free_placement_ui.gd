extends SceneTree

## Exercises actual touch and mouse gestures against the portrait game. Every
## instance enters test_mode before _ready, so no player save can be changed.
const View = preload("res://scripts/battle_map_view.gd")
const Layout = preload("res://scripts/field_layout.gd")
const State = preload("res://scripts/garden_state.gd")
const Battle = preload("res://scripts/battle_sim.gd")
const Placement = preload("res://scripts/battle_placement.gd")
const SAVE_PATH: String = "/private/tmp/planta2-free-placement-ui-save.json"
const TOUCH_OFFSET := Vector2(0, 56)

var game: Node2D
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)


func fresh_game() -> Node2D:
	var instance: Node2D = load("res://scenes/main.tscn").instantiate()
	instance.test_mode = true
	root.add_child(instance)
	instance.set_process(false)
	return instance


func fixture() -> void:
	if game != null:
		game.queue_free()
		await process_frame
	game = fresh_game()
	game.state.coins = 1000
	expect(game.state.plant_plot("nursery", 0, "nettle"), "fixture defender is actually grown in its permanent nursery")
	game.state.nursery_levels[0] = 3
	game._action("battle")
	game._action("stage:1")
	game.loadout_choices.assign(["nettle", "tomato"])
	game._action("confirm_loadout")
	await settle()
	expect(game.battle != null and game.battle.loadout_ready, "each free-placement scenario begins with a legitimate frozen garden roster")


func settle(label: String = "") -> void:
	game.toast_time = 0
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	for layout in game.text_layouts:
		expect(not layout["truncated"], "free placement retains complete text: " + str(layout["text"]))
		for run in layout["runs"]:
			expect(layout["bounds"].grow(0.1).encloses(run["rect"]), "free placement text remains inside its allocated bounds")
	if not label.is_empty() and OS.get_cmdline_user_args().has("--screenshots"):
		root.get_texture().get_image().save_png("res://artifacts/free-placement-" + label + ".png")


func hit(action: String) -> Rect2:
	for index in range(game.hitboxes.size()-1, -1, -1):
		if str(game.hitboxes[index]["action"]) == action: return game.hitboxes[index]["rect"]
	return Rect2()


func action_count(prefix: String) -> int:
	var count: int = 0
	for target in game.hitboxes:
		if str(target["action"]).begins_with(prefix): count += 1
	return count


func press(point: Vector2, mouse: bool = false, index: int = 0) -> void:
	var global: Vector2 = game.get_global_transform_with_canvas() * point
	if mouse:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.position = global
		root.push_input(event, true)
	else:
		var event := InputEventScreenTouch.new()
		event.index = index
		event.pressed = true
		event.position = global
		root.push_input(event, true)
	await process_frame


func move(point: Vector2, mouse: bool = false, index: int = 0) -> void:
	var global: Vector2 = game.get_global_transform_with_canvas() * point
	if mouse:
		var event := InputEventMouseMotion.new()
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		event.position = global
		root.push_input(event, true)
	else:
		var event := InputEventScreenDrag.new()
		event.index = index
		event.position = global
		root.push_input(event, true)
	await settle()


func release(point: Vector2, mouse: bool = false, canceled: bool = false, index: int = 0) -> void:
	var global: Vector2 = game.get_global_transform_with_canvas() * point
	if mouse:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = false
		event.position = global
		root.push_input(event, true)
	else:
		var event := InputEventScreenTouch.new()
		event.index = index
		event.pressed = false
		event.canceled = canceled
		event.position = global
		root.push_input(event, true)
	await settle()


func tap_point(point: Vector2) -> void:
	await press(point)
	await release(point)


func tap(action: String) -> bool:
	await settle()
	var rect: Rect2 = hit(action)
	expect(rect.has_area(), "the actual visible control exists: " + action)
	if not rect.has_area(): return false
	await tap_point(rect.get_center())
	return true


func garden_progress() -> Array:
	return [game.state.coins, game.state.completed_level, game.state.home_plots.duplicate(), game.state.home_levels.duplicate(), game.state.nursery_plots.duplicate(), game.state.nursery_levels.duplicate(), game.state.pond_plots.duplicate(), game.state.pond_levels.duplicate(), game.state.unlocked_seeds.duplicate()]


func free_point(kind: String = "", near: Vector2 = Vector2.INF) -> Vector2:
	var best: Vector2 = Vector2.INF
	var score: float = INF
	for candidate in Placement.grid_centers():
		if not game.battle.placement_check(candidate, kind).get("valid", false): continue
		var screen: Vector2 = View.screen_point(candidate)
		if screen.y + TOUCH_OFFSET.y >= View.BOARD.end.y - 4: continue
		if not near.is_finite(): return candidate
		var candidate_score: float = candidate.distance_to(near)
		if candidate_score < score:
			best = candidate
			score = candidate_score
	expect(best.is_finite(), "the actual map has an available canonical cell for this paid plant")
	return best


func placement_at(point: Vector2) -> Dictionary:
	for plant in game.battle.plants:
		if Vector2(game.battle._plots[int(plant["slot"])]).is_equal_approx(point): return plant
	return {}


func begin_drag(kind: String, point: Vector2, mouse: bool = false) -> void:
	await settle()
	var rect: Rect2 = hit("battle_quick_select:"+kind)
	expect(rect.has_area(), "the drag begins on a real affordable frozen-roster card")
	await press(rect.get_center(), mouse)
	var finish: Vector2 = View.screen_point(point) + (Vector2.ZERO if mouse else TOUCH_OFFSET)
	for step in range(1, 7):
		await move(rect.get_center().lerp(finish, float(step)/6.0), mouse)


func check_tap_flow() -> void:
	await fixture()
	expect(action_count("battle_plot:") == 0 and hit("battle_ground").has_area(), "an empty field has continuous land input rather than nineteen invisible preset slots")
	expect(game.battle._plots.is_empty(), "a new free-placement battle has no unused fixed planting anchors")
	var progress: Array = garden_progress()
	var first: Vector2 = free_point("nettle")
	var before: Dictionary = game.battle.export_snapshot()
	await tap_point(View.screen_point(first+Vector2(5,-4)))
	expect(game.battle_panel == "plant_picker" and hit("deploy:nettle").has_area(), "tapping arbitrary valid land opens the actual plant picker")
	expect(game.battle.export_snapshot() == before, "opening the ground picker never reserves a slot or spends supplies")
	await settle("ground-picker")
	await tap("deploy:nettle")
	var placed: Dictionary = placement_at(first)
	expect(not placed.is_empty() and placed.get("kind", "") == "nettle", "an off-center tap purchases the canonical cell center shown by its picker")
	expect(game.battle.supplies == 180 and game.battle._plots.size() == 1, "the first continuous placement pays once and allocates exactly one stable identity")
	await tap("battle_quick_select:tomato")
	var second: Vector2 = free_point("tomato")
	await tap_point(View.screen_point(second))
	expect(placement_at(second).get("kind", "") == "tomato" and game.battle.supplies == 135, "selecting a tray card then land places a real paid income crop at that coordinate")
	await tap("battle_quick_select:nettle")
	var third: Vector2 = free_point("nettle")
	await tap_point(View.screen_point(third))
	expect(placement_at(third).get("kind", "") == "nettle" and game.battle.supplies == 75, "one selected species supports another paid continuous copy")
	before = game.battle.export_snapshot()
	await tap_point(View.screen_point(first))
	expect(game.battle_panel == "inspect" and game.active_battle_slot == int(placed["slot"]), "tapping an occupied plant inspects that stable identity even while another copy is selected")
	expect(game.battle.export_snapshot() == before, "inspection neither replaces the plant nor pays again")
	await tap("close_battle_panel")
	before = game.battle.export_snapshot()
	await tap("wave_preview")
	expect(not hit("battle_ground").has_area() and action_count("battle_quick_select:") == 0, "the guide exclusively owns input above the free-placement field")
	await tap_point(View.screen_point(free_point()))
	expect(game.battle.export_snapshot() == before, "a touch behind the forecast cannot create or replace a plant")
	await settle("guide")
	await tap("close_wave_preview")
	expect(garden_progress() == progress, "both tap flows preserve every permanent planting, level, coin and district")
	await settle("tap-formation")


func check_drag_flow() -> void:
	await fixture()
	var progress: Array = garden_progress()
	var first: Vector2 = free_point("nettle")
	var before: Dictionary = game.battle.export_snapshot()
	var raw_drop: Vector2 = first+Vector2(4,5)
	await begin_drag("nettle", raw_drop)
	var preview: Dictionary = game.get_battle_placement_preview()
	expect(preview.get("active", false) and preview.get("kind", "") == "nettle" and preview.get("valid", false), "a real touch drag exposes the chosen plant and valid preview")
	expect(Vector2(preview.get("position", Vector2.INF)).is_equal_approx(first), "the off-center touch ghost resolves to the same canonical cell that will be paid for")
	var rect: Rect2 = preview.get("rect", Rect2())
	var finger: Vector2 = preview.get("finger", Vector2.ZERO)
	expect(rect.has_area() and rect.end.y + 10 < finger.y, "the complete touch ghost remains visibly above the user's finger")
	expect(game.battle.export_snapshot() == before, "pressing and moving a card never charges before release")
	await settle("drag-valid")
	await release(View.screen_point(raw_drop)+TOUCH_OFFSET)
	expect(placement_at(first).get("kind", "") == "nettle" and game.battle.supplies == 180, "releasing a valid touch ghost places exactly one paid copy")
	expect(not game.get_battle_placement_preview().get("active", false), "successful release clears the drag preview")
	var path: Array = game.battle.path_points()
	var road: Vector2 = path[path.size()/3]
	before = game.battle.export_snapshot()
	await begin_drag("nettle", road)
	preview = game.get_battle_placement_preview()
	expect(preview.get("active", false) and not preview.get("valid", true) and not str(preview.get("reason", "")).is_empty(), "dragging onto the real curved road shows an explained invalid preview")
	await settle("drag-road")
	await release(View.screen_point(road)+TOUCH_OFFSET)
	expect(game.battle.export_snapshot() == before, "an invalid road drop spends no money, advances no ID and changes no combat state")
	var outside: Vector2 = View.simulation_point(Vector2(-90, 360))
	await begin_drag("nettle", outside)
	await release(View.screen_point(outside)+TOUCH_OFFSET)
	expect(game.battle.export_snapshot() == before, "dropping outside the field is a complete cancellation")
	var second: Vector2 = free_point("nettle")
	await begin_drag("nettle", second)
	await release(View.screen_point(second)+TOUCH_OFFSET, false, true)
	expect(game.battle.export_snapshot() == before and not game.get_battle_placement_preview().get("active", false), "an OS-cancelled touch cancels the purchase and preview")
	await begin_drag("nettle", second)
	await press(View.screen_point(second)+Vector2(80,40), false, 1)
	await release(View.screen_point(second)+Vector2(80,40), false, false, 1)
	await release(View.screen_point(second)+TOUCH_OFFSET)
	expect(game.battle.export_snapshot() == before, "a second finger cancels a drag instead of creating an accidental purchase")
	await begin_drag("nettle", second)
	var back := InputEventKey.new()
	back.keycode = KEY_ESCAPE
	back.pressed = true
	root.push_input(back,true)
	await settle()
	expect(game.screen == "battle" and not game.get_battle_placement_preview().get("active",false), "Back during a drag cancels its preview while keeping the tactical field open")
	await release(View.screen_point(second)+TOUCH_OFFSET)
	expect(game.battle.export_snapshot() == before, "releasing a finger after Back cannot finish the cancelled purchase")
	await begin_drag("nettle", second, true)
	preview = game.get_battle_placement_preview()
	expect(preview.get("valid", false) and Vector2(preview.get("position", Vector2.INF)).is_equal_approx(second), "a mouse drag uses the actual cursor without the touch offset")
	await release(View.screen_point(second), true)
	expect(placement_at(second).get("kind", "") == "nettle" and game.battle.supplies == 120, "the desktop drag path also pays once at release")
	expect(garden_progress() == progress, "dragging copies never consumes or alters the permanent garden")
	await settle("drag-formation")


func check_no_funds() -> void:
	await fixture()
	await tap("battle_quick_select:nettle")
	for index in range(4):
		var point: Vector2 = free_point("nettle")
		await tap_point(View.screen_point(point))
	expect(game.battle.supplies == 0 and game.battle.plants.size() == 4, "four real paid cannon copies consume the ordinary starting budget")
	var before: Dictionary = game.battle.export_snapshot()
	await tap_point(View.screen_point(free_point()))
	expect(game.battle.export_snapshot() == before, "a selected card cannot bypass an empty supply wallet")
	await tap("battle_quick_select:nettle")
	expect(game.quick_plant_kind.is_empty() and game.battle.export_snapshot() == before, "an exhausted selected card still supports free cancellation")
	expect(not hit("battle_quick_select:nettle").has_area(), "after cancelling an unaffordable card cannot start another purchase gesture")
	await settle("no-funds")


func check_dynamic_checkpoint() -> void:
	await fixture()
	var first: Vector2 = free_point("nettle", game.battle.path_points()[0])
	await tap("battle_quick_select:nettle")
	await tap_point(View.screen_point(first))
	await tap("battle_quick_select:tomato")
	var second: Vector2 = free_point("tomato")
	await tap_point(View.screen_point(second))
	game.battle.reward_rng.seed = 73142
	await tap("primary")
	for step in range(240):
		game.battle.tick(1.0/60.0)
		if game.battle.active_seconds > 2 and not game.battle.enemies.is_empty() and not game.battle.shots.is_empty(): break
	expect(game.battle.phase == "running" and not game.battle.enemies.is_empty(), "the saved free formation is a real active wave with travelling attackers")
	var before: Dictionary = game.battle.export_snapshot()
	game._save(SAVE_PATH)
	var resumed: Node2D = fresh_game()
	expect(resumed.state.load_game(SAVE_PATH), "the dynamic checkpoint uses the normal atomic garden save reader")
	resumed._restore_session()
	expect(resumed.battle != null, "normal application restoration accepts the new arbitrary coordinates")
	if resumed.battle != null:
		before["values"]["paused"] = true
		expect(resumed.battle.export_snapshot() == before, "every arbitrary anchor, attacker, cooldown, resource and RNG value is restored exactly")
		expect(resumed.battle._plots.size() == 2 and resumed.battle._plots[0].is_equal_approx(first) and resumed.battle._plots[1].is_equal_approx(second), "restoration keeps continuous coordinates and stable identities without returning to the legacy grid")
		game.battle.paused = false
		resumed.battle.paused = false
		for step in range(120):
			game.battle.tick(1.0/60.0)
			resumed.battle.tick(1.0/60.0)
		expect(resumed.battle.export_snapshot() == game.battle.export_snapshot() and resumed.state.coins == game.state.coins, "the resumed arbitrary formation continues identically, including random garden rewards")
	resumed.queue_free()
	await settle("running")


func run() -> void:
	await check_tap_flow()
	await check_drag_flow()
	await check_no_funds()
	await check_dynamic_checkpoint()
	game.queue_free()
	print("Free placement UI: ", checks, " checks; ", failures, " failures")
	quit(0 if failures == 0 else 1)
