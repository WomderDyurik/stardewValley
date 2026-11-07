extends SceneTree

## Sends real touch/key events to scene controls without loading player saves.
const Layout = preload("res://scripts/field_layout.gd")
const MapView = preload("res://scripts/battle_map_view.gd")
const Placement = preload("res://scripts/battle_placement.gd")
const World = preload("res://scripts/garden_world.gd")
const Presentation = preload("res://scripts/battle_presentation.gd")

var game: Node2D
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _settle() -> void:
	await process_frame
	await process_frame
	_check_garden_building_targets()


func _has_action(action: String) -> bool:
	for hitbox in game.hitboxes:
		if hitbox["action"] == action:
			return true
	return false


func _action_count(action: String) -> int:
	var count: int = 0
	for hitbox in game.hitboxes:
		if hitbox["action"] == action:
			count += 1
	return count


func _action_prefix_count(prefix: String) -> int:
	var count: int = 0
	for hitbox in game.hitboxes:
		if String(hitbox["action"]).begins_with(prefix):
			count += 1
	return count


func _text_contains(fragment: String) -> bool:
	for layout in game.text_layouts:
		if String(layout["text"]).contains(fragment):
			return true
	return false


func _rendered_font_weight(face: Font) -> float:
	var text_server: TextServer = TextServerManager.get_primary_interface()
	var axis: int = text_server.name_to_tag("wght")
	var coordinates: Dictionary = text_server.font_get_variation_coordinates(face.get_rids()[0])
	return float(coordinates.get(axis, face.get_font_weight()))


func _check_home_plot_controls(expect_any: bool = true) -> void:
	var plots: Array[Dictionary] = []
	var seen: Dictionary = {}
	for hitbox in game.hitboxes:
		var action: String = String(hitbox["action"])
		if not action.begins_with("home_plot:"):
			continue
		var index_text: String = action.trim_prefix("home_plot:")
		_expect(index_text.is_valid_int(), "world crop control has a numeric index")
		var index: int = index_text.to_int()
		_expect(index >= 0 and index < game.State.HOME_PLOT_COUNT, "world crop control identifies an existing permanent bed")
		if index < 0 or index >= game.State.HOME_PLOT_COUNT:
			continue
		_expect(not seen.has(index), "each visible crop has only one touch target")
		seen[index] = true
		_expect(game.state.is_plot_unlocked("home", index), "locked crop land never creates an active touch target")
		var bounds: Rect2 = hitbox["rect"]
		_expect(bounds.has_area(), "visible crop exposes a nonempty touch target")
		_expect(World.MAP_VIEW.grow(0.01).encloses(bounds), "crop input is clipped to the map viewport")
		var world_bounds: Rect2 = World.plot_visual_rect(index)
		var projected = Rect2(game.garden_world.world_to_screen(world_bounds.position), world_bounds.size * game.garden_world.zoom)
		_expect(projected.grow(1.0).encloses(bounds), "crop input follows the actual camera projection")
		plots.append(hitbox)
	_expect(plots.size() <= game.state.home_plot_capacity(), "offscreen and locked crops do not create duplicate or phantom targets")
	if expect_any:
		_expect(not plots.is_empty(), "garden focus makes crop beds available to touch")
	for index in range(plots.size()):
		for other_index in range(index + 1, plots.size()):
			_expect(not plots[index]["rect"].intersects(plots[other_index]["rect"]), "projected crop touch targets never overlap")


func _check_garden_building_targets() -> void:
	if game.screen != "home" or not game.home_panel.is_empty() or game.help_open or game.stage_open: return
	var planting: Array[Dictionary] = []
	var buildings: Array[Dictionary] = []
	for hitbox in game.hitboxes:
		var action: String = str(hitbox["action"])
		if action.begins_with("home_plot:") or action.begins_with("nursery_plot:") or action.begins_with("pond_plot:"):
			planting.append(hitbox)
		elif action in ["nursery","greenhouse","gate","collect"] and bool(hitbox.get("world",false)):
			buildings.append(hitbox)
	for plant in planting:
		for building in buildings:
			_expect(not Rect2(plant["rect"]).intersects(building["rect"]), "building touch target cannot intercept a real plant: %s / %s" % [plant["action"],building["action"]])



func _check_battle_plot_controls() -> void:
	var seen: Dictionary = {}
	var projected: Array[Vector2] = MapView.project_route(game.battle.path_points())
	for hitbox in game.hitboxes:
		var action: String = String(hitbox["action"])
		if not action.begins_with("battle_plot:"): continue
		var index: int = action.trim_prefix("battle_plot:").to_int()
		_expect(index >= 0 and index < game.battle._plots.size(), "an occupied plant control identifies its stable dynamic anchor")
		if index < 0 or index >= game.battle._plots.size(): continue
		_expect(not game.battle.get_plant(index).is_empty(), "unused legacy anchors never become phantom planting targets")
		_expect(not seen.has(index), "each actual battle plant has exactly one touch control")
		seen[index] = true
		var displayed: Rect2 = hitbox["rect"]
		var local: Rect2 = Rect2(displayed.position - game.BOARD.position, displayed.size)
		_expect(MapView.footprint_at(game.battle._plots[index]).grow(0.001).encloses(local), "actual battle touch bounds stay inside the complete upright projected plant")
		for segment in range(1,projected.size()):
			_expect(Placement.segment_rect_distance(projected[segment-1],projected[segment],local) >= (Layout.ROAD_WIDTH/2.0+Layout.ROAD_CLEARANCE)*MapView.SCALE-0.01, "actual occupied-plant touches keep full clearance from the curved road")
	_expect(seen.size() == game.battle.plants.size(), "only real paid plants expose individual occupied-plant targets")
	_expect(_has_action("battle_ground"), "continuous empty land remains available independently of occupied plants")


func _free_battle_point() -> Vector2:
	for x in range(39,454,13):
		for y in range(39,392,13):
			var candidate := Vector2(float(x)+0.375,float(y)+0.125)
			if game.battle.placement_check(candidate).get("valid",false): return candidate
	_expect(false,"the authored route leaves another valid continuous planting position")
	return Vector2.INF


func _tap_free_battle_ground() -> Vector2:
	await _settle()
	if not game.quick_plant_kind.is_empty():
		await _tap_action("battle_quick_select:"+game.quick_plant_kind)
	var local: Vector2 = _free_battle_point()
	var global: Vector2 = game.get_global_transform_with_canvas() * MapView.screen_point(local)
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = global
	root.push_input(press,true)
	await process_frame
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = global
	root.push_input(release,true)
	await _settle()
	return local


func _last_battle_slot() -> int:
	return int(game.battle.plants[-1]["slot"]) if not game.battle.plants.is_empty() else -1


func _screen_scene_count() -> int:
	var count: int = 0
	for child in game.get_children():
		if child.scene_file_path in ["res://scenes/garden.tscn", "res://scenes/defense.tscn"]:
			count += 1
	return count


func _tap_action(action: String, expect_available: bool = true) -> bool:
	# Read the current frame's control bounds rather than baking in a layout.
	await _settle()
	if action.begins_with("district:") and not _has_action(action) and game.screen == "home" and game.home_panel.is_empty() and not game.help_open and not game.stage_open:
		if not await _tap_action("open_districts", expect_available):
			return false
	var bounds: Rect2 = Rect2()
	var found: bool = false
	for index in range(game.hitboxes.size() - 1, -1, -1):
		if game.hitboxes[index]["action"] == action:
			bounds = game.hitboxes[index]["rect"]
			found = true
			break
	if not found:
		if expect_available:
			_expect(false, "expected visible touch control: " + action)
		return false
	var point: Vector2 = game.get_global_transform_with_canvas() * bounds.get_center()
	var press = InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = point
	root.push_input(press, true)
	await process_frame
	var release = InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = point
	root.push_input(release, true)
	await _settle()
	return true


func _key(keycode: Key) -> void:
	var press = InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var release = InputEventKey.new()
	release.keycode = keycode
	release.pressed = false
	root.push_input(release, true)
	await _settle()


func _abort_if_no_battle() -> bool:
	if game.battle != null:
		return false
	_expect(false, "battle scene must provide a BattleSim before further interaction")
	game.queue_free()
	quit(1)
	return true


func _touch_drag(start: Vector2, delta: Vector2) -> void:
	var press = InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = game.get_global_transform_with_canvas() * start
	root.push_input(press, true)
	await process_frame
	var previous: Vector2 = press.position
	for step in range(1, 7):
		var local: Vector2 = start + delta * float(step) / 6.0
		var drag = InputEventScreenDrag.new()
		drag.index = 0
		drag.position = game.get_global_transform_with_canvas() * local
		drag.relative = drag.position - previous
		root.push_input(drag, true)
		previous = drag.position
		await process_frame
	var release = InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = previous
	root.push_input(release, true)
	await _settle()


func _mouse_drag(start: Vector2, delta: Vector2) -> void:
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = game.get_global_transform_with_canvas() * start
	root.push_input(press, true)
	await process_frame
	var previous: Vector2 = press.position
	for step in range(1, 7):
		var move = InputEventMouseMotion.new()
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		move.position = game.get_global_transform_with_canvas() * (start + delta * float(step) / 6.0)
		move.relative = move.position - previous
		root.push_input(move, true)
		previous = move.position
		await process_frame
	var release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = previous
	root.push_input(release, true)
	await _settle()


func _mouse_wheel(point: Vector2, button: MouseButton) -> void:
	var wheel = InputEventMouseButton.new()
	wheel.button_index = button
	wheel.pressed = true
	wheel.position = game.get_global_transform_with_canvas() * point
	root.push_input(wheel, true)
	await _settle()


func _hold_touch_then_escape(point: Vector2) -> void:
	var screen_point: Vector2 = game.get_global_transform_with_canvas() * point
	var press = InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = screen_point
	root.push_input(press, true)
	await process_frame
	await _key(KEY_ESCAPE)
	var release = InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = screen_point
	root.push_input(release, true)
	await _settle()


func _cancel_touch(point: Vector2) -> void:
	var screen_point: Vector2 = game.get_global_transform_with_canvas() * point
	var press = InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = screen_point
	root.push_input(press, true)
	await process_frame
	var release = InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.canceled = true
	release.position = screen_point
	root.push_input(release, true)
	await _settle()


func _bounds_for(action: String) -> Rect2:
	for hitbox in game.hitboxes:
		if hitbox["action"] == action:
			return hitbox["rect"]
	return Rect2()


func _check_camera_bounds(message: String) -> void:
	_expect(World.WORLD_RECT.grow(0.01).encloses(game.garden_world.visible_world_rect()), message)


func _finger(index: int, point: Vector2, pressed: bool, cancelled: bool = false) -> void:
	var event = InputEventScreenTouch.new()
	event.index = index
	event.position = game.get_global_transform_with_canvas() * point
	event.pressed = pressed
	event.canceled = cancelled
	root.push_input(event, true)
	await process_frame


func _finger_move(index: int, from: Vector2, to: Vector2) -> void:
	var event = InputEventScreenDrag.new()
	event.index = index
	event.position = game.get_global_transform_with_canvas() * to
	event.relative = game.get_global_transform_with_canvas().basis_xform(to - from)
	root.push_input(event, true)
	await process_frame


func _pinch(midpoint: Vector2, start_distance: float, end_distance: float) -> void:
	var first: Vector2 = midpoint - Vector2(start_distance / 2.0, 0)
	var second: Vector2 = midpoint + Vector2(start_distance / 2.0, 0)
	await _finger(0, first, true)
	await _finger(1, second, true)
	for step in range(1, 7):
		var distance: float = lerpf(start_distance, end_distance, float(step) / 6.0)
		var next_first: Vector2 = midpoint - Vector2(distance / 2.0, 0)
		var next_second: Vector2 = midpoint + Vector2(distance / 2.0, 0)
		await _finger_move(0, first, next_first)
		await _finger_move(1, second, next_second)
		first = next_first
		second = next_second
	await _finger(0, first, false)
	await _finger(1, second, false)
	await _settle()


func _close_home_panel() -> void:
	for attempt in range(2):
		if game.home_panel.is_empty():
			break
		if _has_action("close_home_panel"):
			await _tap_action("close_home_panel")
		elif _has_action("plot_back"):
			await _tap_action("plot_back")
		else:
			_expect(false, "garden menu exposes its back or close action")
			break
	_expect(game.home_panel.is_empty(), "contextual garden menu closes")


func _choose_loadout(kinds: Array[String]) -> void:
	await _settle()
	_expect(game.battle_panel == "loadout", "loadout is chosen in the pre-battle panel")
	var options: Array[Dictionary] = game.battle.loadout_options()
	for index in range(options.size()):
		var kind: String = options[index]["kind"]
		var wanted: bool = kinds.has(kind)
		if game.loadout_choices.has(kind) != wanted:
			var page: int = index / 6
			while game.loadout_page < page:
				if not await _tap_action("loadout_page:1"): return
			while game.loadout_page > page:
				if not await _tap_action("loadout_page:-1"): return
			await _tap_action("loadout_toggle:" + kind)
	while game.loadout_page > 0:
		if not await _tap_action("loadout_page:-1"): return
	await _settle()


func _open_mission(stage: int, kinds: Array[String]) -> bool:
	await _tap_action("battle")
	_expect(game.stage_open, "starting a new expedition opens the campaign mission board")
	if not await _tap_action("stage:%d" % stage):
		return false
	if _abort_if_no_battle():
		return false
	_expect(game.screen == "battle" and game.battle_panel == "loadout", "mission choice opens its pre-battle plant selection")
	await _choose_loadout(kinds)
	await _tap_action("confirm_loadout")
	_expect(game.battle.loadout_ready and game.battle_panel.is_empty(), "confirming loadout enables the battle field")
	return true


func _finish_ui(won: bool = true) -> void:
	game.battle._finish_battle(won)
	# Successful final rewards remain visible before the summary. Exercise the
	# normal scene clock rather than assuming that two rendered frames finish it.
	for step in range(20):
		if game.result_open:
			break
		game._process(0.1)
	await _settle()
	_expect(game.result_open, "battle finish opens a result summary")


func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	await _settle()
	_expect(game.state.coins == 240, "fresh game starts with its ordinary shared wallet")
	_expect(game.screen == "home" and game.active_view != null, "first launch opens the independent garden scene")
	if game.active_view == null:
		game.queue_free()
		quit(1)
		return
	_expect(game.active_view.scene_file_path == "res://scenes/garden.tscn" and _screen_scene_count() == 1, "one garden screen scene is mounted")
	_expect(_action_count("battle") == 1 and not _has_action("home"), "garden has an expedition entrance without top tabs")
	_expect(game.state.home_plots.size() == 24 and game.state.nursery_plots.size() == 12, "persistent arrays reserve all campaign planting locations")
	_expect(game.state.home_plot_capacity() == 12 and game.state.nursery_plot_capacity() == 8, "only starter planting land is initially unlocked")
	_expect(game.state.nursery_plots.count("") == 12, "new nursery has no imaginary defenders")
	_expect(not game.state.is_seed_unlocked("lavender") and not game.state.is_seed_unlocked("pepper") and not game.state.is_seed_unlocked("pumpkin"), "campaign seeds start locked")
	_expect(_action_prefix_count("select:") == 0 and _action_prefix_count("plant:") == 0, "plant choice is contextual rather than always visible")
	_expect(not _has_action("zoom_in") and not _has_action("zoom_out"), "pinch replaces plus and minus zoom controls")
	_expect(World.WORLD_SIZE.x > World.MAP_VIEW.size.x * 2.0 and World.districts().size() == 7, "world includes the base garden and three expansion districts")
	_check_home_plot_controls()
	_check_camera_bounds("initial camera stays inside the expanded world")
	_expect(game.font.has_char(0x0416), "normal UI font supports Cyrillic")
	_expect(not game.font.get_font_name().to_lower().contains("pixelify"), "readable normal UI font is retained")
	_expect(_rendered_font_weight(game.font) >= 450.0 and _rendered_font_weight(game.bold) >= 650.0, "readable body and heading font weights are retained")
	_expect(_has_action("open_districts") and _action_prefix_count("district:") == 0, "compact garden navigation reveals districts only on request")
	var navigation_camera: Vector2 = game.garden_world.center
	var navigation_wallet: int = game.state.coins
	await _tap_action("open_districts")
	_expect(game.home_panel == "districts" and _action_prefix_count("district:") == World.districts().size(), "real touch opens every district in its navigation sheet")
	_expect(_action_prefix_count("home_plot:") == 0 and not _has_action("collect") and not _has_action("battle") and not _has_action("minimap"), "district sheet blocks every underlying garden action")
	await _finger(0, Vector2(270, 150), true)
	await _finger(0, Vector2(270, 150), false)
	_expect(game.home_panel == "districts" and game.garden_world.center == navigation_camera and game.state.coins == navigation_wallet, "touch outside district sheet cannot activate the garden behind it")
	await _tap_action("close_home_panel")
	_expect(game.home_panel.is_empty() and _has_action("open_districts") and game.garden_world.center == navigation_camera, "district sheet closes by touch without moving the garden")
	await _tap_action("open_districts")
	await _key(KEY_ESCAPE)
	_expect(game.home_panel.is_empty() and _has_action("battle"), "Escape also dismisses district navigation and restores the garden")

	# Gesture handling still targets the world, with no accidental plot purchase.
	var crop_start: Rect2 = _bounds_for("home_plot:5")
	_expect(crop_start.has_area(), "starter garden exposes an empty bed for gesture testing")
	if not crop_start.has_area():
		game.queue_free()
		quit(1)
		return
	var wallet_before: int = game.state.coins
	var crops_before: Array[String] = game.state.home_plots.duplicate()
	var camera_before: Vector2 = game.garden_world.center
	await _cancel_touch(crop_start.get_center())
	_expect(not game.pointer_down and game.home_panel.is_empty() and game.state.coins == wallet_before, "system-cancelled touch clears without planting or opening a picker")
	await _hold_touch_then_escape(crop_start.get_center())
	_expect(game.help_open and game.state.home_plots == crops_before, "held touch cannot plant behind a newly opened help modal")
	_expect(_action_prefix_count("home_plot:") == 0, "help removes garden touch targets behind it")
	await _key(KEY_ESCAPE)
	await _touch_drag(crop_start.get_center(), Vector2(-85, 75))
	_expect(game.garden_world.center.distance_to(camera_before) > 20.0, "touch drag pans the garden map")
	_expect(game.home_panel.is_empty() and game.state.coins == wallet_before and game.state.home_plots == crops_before, "dragging from soil never purchases or opens the planting picker")
	_check_home_plot_controls()
	await _tap_action("home_plot:1")
	_expect(game.home_panel == "plot" and game.active_plot_slot == 1, "tap after panning opens the correct occupied plot")
	await _close_home_panel()
	camera_before = game.garden_world.center
	await _mouse_drag(World.MAP_VIEW.get_center() + Vector2(0, 140), Vector2(-70, -55))
	_expect(game.garden_world.center.distance_to(camera_before) > 20.0 and game.home_panel.is_empty(), "mouse dragging pans without activating a crop")
	await _tap_action("district:garden")
	var midpoint: Vector2 = World.MAP_VIEW.get_center()
	var zoom_before: float = game.garden_world.zoom
	var anchored_world: Vector2 = game.garden_world.screen_to_world(midpoint)
	await _pinch(midpoint, 100, 150)
	_expect(game.garden_world.zoom > zoom_before, "spreading two real touch contacts zooms in")
	_expect(game.garden_world.screen_to_world(midpoint).distance_to(anchored_world) < 2.0, "pinch keeps the world point beneath its midpoint")
	_expect(game.home_panel.is_empty() and game.state.coins == wallet_before and game.state.home_plots == crops_before, "pinch lift never activates a garden bed")
	zoom_before = game.garden_world.zoom
	await _pinch(midpoint, 150, 100)
	_expect(game.garden_world.zoom < zoom_before, "bringing fingers together zooms back out")
	await _finger(0, midpoint - Vector2(50, 0), true)
	await _finger(1, midpoint + Vector2(50, 0), true)
	await _finger(1, midpoint + Vector2(50, 0), false, true)
	await _finger(0, midpoint - Vector2(50, 0), false)
	await _settle()
	_expect(game.home_panel.is_empty() and game.state.coins == wallet_before, "cancelled multitouch cannot become a plot tap")
	var wheel_anchor: Vector2 = midpoint + Vector2(50, 0)
	anchored_world = game.garden_world.screen_to_world(wheel_anchor)
	zoom_before = game.garden_world.zoom
	await _mouse_wheel(wheel_anchor, MOUSE_BUTTON_WHEEL_UP)
	_expect(game.garden_world.zoom > zoom_before and game.garden_world.screen_to_world(wheel_anchor).distance_to(anchored_world) < 0.1, "desktop wheel zoom preserves its cursor anchor")
	game.garden_world.set_zoom(World.DEFAULT_ZOOM)
	for id in ["garden", "nursery", "greenhouse", "pond"]:
		await _tap_action("district:" + id)
		var expected = World.new()
		expected.set_zoom(game.garden_world.zoom)
		expected.focus_district(id)
		_expect(game.garden_world.center.distance_to(expected.center) < 0.1, "base district navigation focuses actual geography: " + id)
		_check_camera_bounds("district camera remains inside the expanded estate")
	await _tap_action("district:garden")
	camera_before = game.garden_world.center
	await _tap_action("minimap")
	_expect(game.garden_world.center.distance_to(camera_before) > 100.0, "mini-map still navigates through the expanded world")
	game.garden_world.focus_district("berry")
	await _settle()
	_expect(not _has_action("home_plot:12") and not _has_action("home_plot:15"), "locked expansion land has no active planting controls")

	# Plot context remains individual, and locked seed species cannot be planted.
	await _tap_action("district:garden")
	await _tap_action("home_plot:0")
	_expect(game.home_panel == "plot" and _has_action("upgrade_plot") and _has_action("change_plant"), "occupied plot opens its own upgrade and replacement actions")
	await _tap_action("upgrade_plot")
	_expect(game.state.plot_level("home", 0) == 2 and game.state.plot_level("home", 1) == 1 and game.state.coins == 165, "individual upgrade changes only the chosen tomato and charges once")
	await _tap_action("change_plant")
	_expect(_has_action("plant:marigold") and not _has_action("plant:pumpkin"), "income picker offers only discovered seeds")
	await _tap_action("plant:marigold")
	_expect(game.state.plot_kind("home", 0) == "marigold" and game.state.plot_level("home", 0) == 1 and game.state.coins == 120, "replacement pays the crop price and resets only this planting")
	await _close_home_panel()
	await _tap_action("home_plot:5")
	_expect(game.home_panel == "plant_picker" and not _has_action("plant:pumpkin"), "an empty bed opens the discovered-seed picker after a tap")
	await _tap_action("plant:tomato")
	_expect(game.state.plot_kind("home", 5) == "tomato" and game.state.coins == 90, "new crop purchase uses the garden wallet")
	await _close_home_panel()
	await _tap_action("collect")
	_expect(game.state.coins == 110 and not game.state.home_ready, "collection pays the actual changed garden yield once")
	var hud_collect_available: bool = false
	for hitbox in game.hitboxes:
		if hitbox["action"] == "collect" and not bool(hitbox.get("world",false)): hud_collect_available = true
	_expect(not hud_collect_available, "the HUD harvest button is disabled until ripe")
	await _tap_action("collect")
	_expect(game.state.coins == 110 and not game.state.home_ready, "the farmhouse can explain growing crops without duplicating an unripe harvest")
	game.state.coins = 300
	await _tap_action("home_plot:1")
	await _tap_action("upgrade_plot")
	_expect(game.state.plot_level("home", 1) == 2 and game.state.plot_level("home", 5) == 1, "same-kind copies retain individual garden levels")
	await _close_home_panel()
	await _tap_action("district:nursery")
	await _tap_action("nursery_plot:0")
	_expect(_has_action("plant:nettle") and not _has_action("plant:lavender") and not _has_action("plant:pepper"), "nursery picker disables unearned campaign seeds")
	await _tap_action("plant:nettle")
	_expect(game.state.plot_kind("nursery", 0) == "nettle" and game.state.nursery_plots.count("") == 11, "only the actually purchased nursery planting exists")
	await _close_home_panel()
	var shared_state: GardenState = game.state
	var shared_world = game.garden_world
	camera_before = game.garden_world.center
	zoom_before = game.garden_world.zoom
	game.state.coins = 200

	# Expedition board -> choice of grown species -> paid repeatable copies.
	await _tap_action("battle")
	_expect(game.stage_open and _has_action("stage:1") and not _has_action("stage:2") and not _has_action("stage:3"), "campaign board gates later missions before any discovery")
	_expect(game.battle == null, "opening the mission board neither starts a battle nor spends money")
	var board_camera: Vector2 = game.garden_world.center
	var board_zoom: float = game.garden_world.zoom
	await _touch_drag(World.MAP_VIEW.get_center(), Vector2(-40, 45))
	await _mouse_wheel(World.MAP_VIEW.get_center(), MOUSE_BUTTON_WHEEL_UP)
	_expect(game.stage_open and game.garden_world.center == board_camera and game.garden_world.zoom == board_zoom, "campaign board blocks panning and zooming of the garden beneath it")
	await _tap_action("stage:1")
	if _abort_if_no_battle():
		return
	_expect(game.screen == "battle" and game.active_view.scene_file_path == "res://scenes/defense.tscn" and _screen_scene_count() == 1, "mission starts its separate defense scene")
	_expect(game.battle_panel == "loadout" and _action_prefix_count("battle_plot:") == 0, "loadout blocks the field until confirmed")
	var forecast_battle: BattleSim = game.battle
	var forecast_choices: Array[String] = game.loadout_choices.duplicate()
	await _tap_action("wave_preview")
	_expect(game.wave_guide_open and game.battle == forecast_battle, "forecast opens before composition is committed without replacing the expedition")
	_expect(not _has_action("confirm_loadout") and _action_prefix_count("loadout_toggle:") == 0 and not _has_action("primary"), "wave guide exclusively owns its touch layer")
	await _key(KEY_SPACE)
	_expect(game.battle.wave == 0 and game.battle.phase == "preparing", "SPACE cannot start a wave behind its pre-battle forecast")
	await _tap_action("battle_guide_tab:enemies")
	_expect(game.wave_guide_tab == "enemies" and game.wave_guide_open, "guide exposes the enemy-role reference without leaving the expedition")
	_expect(_text_contains("нескольких быстрых пушек"), "first-stage swarm advice offers an answer available before any battle seed unlock")
	await _tap_action("battle_guide_tab:rules")
	_expect(game.wave_guide_tab == "rules" and game.wave_guide_open and not _has_action("confirm_loadout"), "rules are available inside the same modal without committing or changing the composition")
	await _tap_action("close_wave_preview")
	_expect(not game.wave_guide_open and game.battle_panel == "loadout" and game.loadout_choices == forecast_choices and game.battle == forecast_battle, "closing forecast restores the same uncommitted composition")

	_expect(_has_action("loadout_toggle:nettle") and not _has_action("loadout_toggle:lavender"), "loadout offers grown species rather than all catalog seeds")
	var prepared_battle: BattleSim = game.battle
	await _key(KEY_ESCAPE)
	_expect(game.screen == "home" and game.battle == prepared_battle and not game.battle.loadout_ready, "Back from an unconfirmed loadout returns home without starting or paying for the battle")
	await _tap_action("battle")
	_expect(game.battle == prepared_battle and game.battle_panel == "loadout" and _action_prefix_count("battle_plot:") == 0, "resuming an unconfirmed expedition reopens its required loadout instead of an inactive field")
	await _key(KEY_SPACE)
	_expect(game.battle.wave == 0 and game.battle.phase == "preparing", "SPACE cannot start waves behind loadout")
	await _choose_loadout([])
	_expect(not _has_action("confirm_loadout") and not game.battle.loadout_ready, "empty loadout cannot be confirmed")
	await _choose_loadout(["nettle", "tomato"])
	await _tap_action("confirm_loadout")
	_expect(game.battle.loadout_ready and game.battle_panel.is_empty() and game.battle.supplies == 240, "selection confirmation is free and enables deployment")
	await _tap_free_battle_ground()
	_expect(_has_action("deploy:nettle") and _has_action("deploy:tomato") and not _has_action("deploy:marigold"), "field picker excludes grown species not taken on this expedition")
	await _tap_action("close_battle_panel")
	await _tap_action("change_loadout")
	await _choose_loadout(["nettle", "tomato", "marigold"])
	await _tap_action("confirm_loadout")
	_expect(game.battle.loadout.size() == 3, "loadout can be revised before the first paid placement")
	var defenders: Array[int] = []
	for copy in range(3):
		await _tap_free_battle_ground()
		await _tap_action("deploy:nettle")
		defenders.append(_last_battle_slot())
	_expect(defenders.size() == 3 and game.battle.get_plant(defenders[0])["kind"] == "nettle" and game.battle.get_plant(defenders[1])["kind"] == "nettle" and game.battle.get_plant(defenders[2])["kind"] == "nettle", "one grown defender supports multiple paid battlefield copies at continuous positions")
	var inspected_defender: int = defenders[2]
	_expect(game.battle.supplies == 60, "each of three cannon copies costs sixty supplies")
	_expect(game.battle.available_plants().size() == 3 and game.state.plot_kind("nursery", 0) == "nettle", "deployment neither consumes selected species nor the original nursery plant")
	_expect(not _has_action("change_loadout"), "selection locks after paid deployment begins")
	await _tap_free_battle_ground()
	await _tap_action("deploy:tomato")
	var income_slot: int = _last_battle_slot()
	_expect(game.battle.get_plant(income_slot)["level"] == 2, "battle copy snapshots the best grown individual level of its species")
	game.battle.supplies += 65 # Simulate reinvestment of wave income.
	await _tap_free_battle_ground()
	await _tap_action("deploy:marigold")
	_expect(game.battle.supplies == 15 and game.battle.plants.size() == 5, "additional income planting reinvests earned supplies")
	_check_battle_plot_controls()
	game.battle.supplies = 0
	await _tap_free_battle_ground()
	_expect(_action_prefix_count("deploy:") == 0, "unaffordable plants have no active deployment action")
	var planted_before: Array[Dictionary] = game.battle.plants.duplicate(true)
	game.battle.supplies = 0
	await _settle()
	_expect(game.battle.plants == planted_before and _action_prefix_count("deploy:") == 0, "zero wallet cannot place a free copy")
	game.battle.supplies += 60
	await _settle()
	_expect(_has_action("deploy:nettle") and not _has_action("deploy:marigold"), "open picker updates affordability when money is earned")
	await _tap_action("deploy:nettle")
	_expect(game.battle.supplies == 0 and game.battle.get_plant(_last_battle_slot())["kind"] == "nettle", "a fourth copy is placed after paying its full cost")
	await _tap_action("primary")
	await _tap_action("primary")
	_expect(game.battle.phase == "running" and game.battle.paused, "wave controls start and pause the paid composition")
	var paused_guide_enemies: Array[Dictionary] = game.battle.enemies.duplicate(true)
	var paused_guide_wallet: int = game.battle.supplies
	await _tap_action("wave_preview")
	await create_timer(0.1).timeout
	await _key(KEY_SPACE)
	_expect(game.wave_guide_open and game.battle.enemies == paused_guide_enemies and game.battle.supplies == paused_guide_wallet, "forecast freezes a paused wave and does not earn or spend supplies")
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle()
	_expect(not game.wave_guide_open and game.screen == "battle" and game.battle.paused, "system Back closes the guide and retains the previously paused battle")

	var enemies_before: Array[Dictionary] = game.battle.enemies.duplicate(true)
	game.battle.tick(1.0)
	_expect(game.battle.enemies == enemies_before, "paused battle freezes enemy progression")
	await _tap_action("speed")
	_expect(game.battle.speed == 2.0, "speed control still works")
	await _tap_action("primary")
	await _tap_action("wave_preview")
	var active_guide_enemies: Array[Dictionary] = game.battle.enemies.duplicate(true)
	var active_guide_supplies: int = game.battle.supplies
	await create_timer(0.1).timeout
	await _settle()
	_expect(game.wave_guide_open and game.battle.enemies == active_guide_enemies and game.battle.supplies == active_guide_supplies, "forecast also freezes an otherwise active battle")
	await _tap_action("close_wave_preview")
	_expect(not game.battle.paused and game.battle.phase == "running", "closing active-wave forecast restores its unpaused state")
	await _tap_action("battle_plot:%d" % inspected_defender)
	enemies_before = game.battle.enemies.duplicate(true)
	await create_timer(0.1).timeout
	_expect(game.battle.enemies == enemies_before, "a contextual field menu freezes the running battle behind it")
	# Keep the wallet assertion independent of a kill on the first resumed frame.
	game.battle.paused = true
	var range_points: PackedVector2Array = Presentation.projected_range_polygon(game,inspected_defender)
	_expect(not range_points.is_empty(), "selected cannon has an actual visible firing-range polygon")
	for point in range_points:
		_expect(game.BOARD.grow(0.01).has_point(point), "rendered firing-range polygon remains inside the battle board")
	var priority_cooldown: float = float(game.battle.get_plant(inspected_defender)["cooldown"])
	var priority_wallet: int = game.battle.supplies
	await _tap_action("target_mode:fast")
	_expect(game.battle.get_plant(inspected_defender).get("target_mode", "") == "fast" and is_equal_approx(float(game.battle.get_plant(inspected_defender)["cooldown"]), priority_cooldown), "fast priority changes target selection without resetting the cannon's cooldown")
	await _tap_action("target_mode:strong")
	_expect(game.battle.get_plant(inspected_defender).get("target_mode", "") == "strong" and game.battle.supplies == priority_wallet, "strong-target priority is a free tactical choice rather than another installation")
	game.battle.supplies = 500
	await _tap_action("change_battle_plant")
	_expect(not _has_action("deploy:nettle") and _has_action("deploy:tomato"), "replacement picker disables the existing species and offers paid alternatives")
	await _tap_action("deploy:tomato")
	_expect(game.battle.get_plant(inspected_defender)["kind"] == "tomato" and game.battle.supplies == 455, "replacement pays the new crop price without refunding the old defender")
	var active_battle: BattleSim = game.battle
	await _tap_action("home")
	_expect(game.screen == "home" and game.state == shared_state and game.garden_world == shared_world, "returning home preserves persistent model instances")
	_expect(game.garden_world.center == camera_before and game.garden_world.zoom == zoom_before, "garden return restores the exact camera position and zoom")
	_expect(game.battle == active_battle and game.battle.paused, "garden visit retains the paid battle placements in a paused model")
	# A locked-region notice must not replace an already paid expedition.
	var paid_placements: Array[Dictionary] = game.battle.plants.duplicate(true)
	var paid_wallet: int = game.state.coins
	game.garden_world.focus_district("sun_meadow")
	await _settle()
	_expect(_has_action("campaign_board"), "locked district exposes its mission-board notice")
	await _tap_action("campaign_board")
	_expect(not game.stage_open and game.battle == active_battle and game.battle.plants == paid_placements and game.state.coins == paid_wallet, "locked-land board cannot replace a paid active battle or lose its wallet and placements")
	game._action("stage:1")
	await _settle()
	_expect(game.battle == active_battle and game.battle.plants == paid_placements and game.state.coins == paid_wallet and not game.stage_open, "direct stage action also preserves an already paid active battle")
	await _tap_action("battle")
	_expect(game.battle == active_battle and game.battle.plants == paid_placements and not game.stage_open, "expedition entrance resumes the same paid battle after visiting locked land")
	await _tap_action("wave_preview")
	await _key(KEY_SPACE)
	_expect(game.wave_guide_open and game.battle.paused, "battle guide blocks keyboard controls while retaining the existing pause")
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	_expect(game.screen == "home", "Escape from battle returns to the garden")
	await _tap_action("battle")
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle()
	_expect(game.screen == "home" and game.battle == active_battle, "Android Back preserves the active paid battle")
	await _tap_action("battle")

	# Simulate UI victory notifications; real five-wave outcomes are tested by BattleSim.
	await _finish_ui()
	_expect(game.state.completed_level == 1 and game.state.home_plot_capacity() == 16 and game.state.nursery_plot_capacity() == 8, "first victory permanently opens four real garden beds")
	_expect(game.state.is_seed_unlocked("lavender") and not game.state.is_seed_unlocked("pepper"), "first victory opens its specific new seed")
	_expect(game.battle.discovery_reward.get("seeds", []).has("lavender"), "battle result receives the actual first-clear seed reward")
	await _tap_action("result_home")
	_expect(game.screen == "home" and game.battle == null, "result returns to garden and releases the finished battle model")
	await _tap_action("district:berry")
	_expect(_has_action("home_plot:12") and _has_action("home_plot:15"), "awarded berry district contains newly interactive garden beds")
	await _tap_action("home_plot:12")
	_expect(_has_action("plant:strawberry") and _has_action("plant:currant") and not _has_action("plant:tomato") and not _has_action("plant:pumpkin"), "berry land offers its own discovered crops and excludes other habitats")
	wallet_before = game.state.coins
	await _tap_action("plant:strawberry")
	_expect(game.state.plot_kind("home", 12) == "strawberry" and game.state.coins == wallet_before - 60, "first awarded bed accepts a real paid planting")
	await _close_home_panel()
	await _tap_action("district:nursery")
	await _tap_action("nursery_plot:1")
	_expect(_has_action("plant:lavender") and not _has_action("plant:pepper"), "newly discovered lavender is available to plant while pepper remains locked")
	await _tap_action("plant:lavender")
	await _close_home_panel()
	_expect(game.state.battle_templates().size() == 5, "a regional seed adds a battle type only after it is actually grown")

	# Replay produces money, but no duplicate land or seed grants.
	if not await _open_mission(1, ["nettle"]):
		return
	wallet_before = game.state.coins
	await _finish_ui()
	_expect(game.battle.discovery_reward.is_empty(), "replaying a cleared mission has no new discovery reward")
	_expect(game.state.coins == wallet_before + 35 and game.state.home_plot_capacity() == 16, "replay pays ordinary victory coins without duplicating expansion land")
	await _tap_action("result_home")
	if not await _open_mission(2, ["nettle", "lavender"]):
		return
	await _finish_ui()
	_expect(game.state.completed_level == 2 and game.state.home_plot_capacity() == 20 and game.state.nursery_plot_capacity() == 10 and game.state.is_seed_unlocked("pepper"), "second mission grants another district and pepper seeds")
	await _tap_action("result_home")
	await _tap_action("district:far_garden")
	_expect(_has_action("home_plot:16") and _has_action("nursery_plot:8"), "second district exposes both awarded income and defense beds")
	await _tap_action("nursery_plot:8")
	await _tap_action("plant:pepper")
	await _close_home_panel()
	_expect(game.state.plot_kind("nursery", 8) == "pepper", "new defense land accepts the newly discovered species")
	if not await _open_mission(3, ["nettle", "pepper"]):
		return
	await _finish_ui()
	_expect(game.state.completed_level == 3 and game.state.home_plot_capacity() == 24 and game.state.nursery_plot_capacity() == 12 and game.state.is_seed_unlocked("pumpkin"), "third mission grants final prototype land and a genuinely new income crop")
	await _tap_action("result_home")
	await _tap_action("district:sun_meadow")
	_expect(_has_action("home_plot:20") and _has_action("nursery_plot:10") and game.state.plot_kind("home", 20).is_empty(), "third discovery opens empty real land without inventing planted pumpkins")
	var had_pumpkin: bool = false
	for entry in game.state.battle_templates():
		had_pumpkin = had_pumpkin or entry["kind"] == "pumpkin"
	_expect(not had_pumpkin, "discovering pumpkin seeds alone does not add a battle template")
	await _tap_action("home_plot:20")
	_expect(_has_action("plant:pumpkin"), "third reward seed is offered in the garden planting menu")
	await _tap_action("plant:pumpkin")
	await _close_home_panel()
	_expect(game.state.plot_kind("home", 20) == "pumpkin", "new pumpkin can actually be planted on the awarded land")
	had_pumpkin = false
	for entry in game.state.battle_templates():
		had_pumpkin = had_pumpkin or entry["kind"] == "pumpkin"
	_expect(had_pumpkin, "growing the new pumpkin makes it a selectable pre-battle species")
	_check_home_plot_controls()
	await _test_new_habitats_and_paged_composition()
	print("Campaign planting UI integration: ", checks, " checks, ", failures, " failures")
	game.queue_free()
	quit(0 if failures == 0 else 1)


func _test_new_habitats_and_paged_composition() -> void:
	game.state.earn(10000)
	await _tap_action("district:greenhouse")
	await _tap_action("home_plot:8")
	_expect(_has_action("plant:cucumber") and _action_prefix_count("plant:") == 1, "greenhouse planting offers only its own cucumber crop")
	await _tap_action("plant:cucumber")
	await _close_home_panel()
	await _tap_action("district:berry")
	await _tap_action("home_plot:13")
	await _tap_action("plant:currant")
	await _close_home_panel()
	await _tap_action("district:far_garden")
	await _tap_action("home_plot:16")
	_expect(_has_action("plant:mint") and _action_prefix_count("plant:") == 1, "remote garden income position is specialised for mint")
	await _tap_action("plant:mint")
	await _close_home_panel()
	await _tap_action("district:pond")
	_expect(_has_action("pond_plot:0") and _has_action("pond_plot:1"), "earned pond contains touchable water planting positions")
	await _tap_action("pond_plot:0")
	_expect(_has_action("plant:waterlily") and _has_action("plant:lotus") and not _has_action("plant:tomato"), "water slot offers aquatic crops and excludes dry planting")
	await _tap_action("plant:waterlily")
	var before_income: int = game.state.home_income()
	var before_coins: int = game.state.coins
	await _tap_action("upgrade_plot")
	_expect(game.state.plot_kind("pond",0) == "waterlily" and game.state.plot_level("pond",0) == 2 and game.state.home_income() > before_income and game.state.coins == before_coins - 145, "pond upgrade changes one actual crop and charges its garden price")
	await _close_home_panel()
	await _tap_action("pond_plot:1")
	await _tap_action("plant:lotus")
	await _close_home_panel()
	_expect(game.state.battle_templates().size() == 12, "all twelve grown regional species become distinct battle templates")
	# All campaign enemies must remain readable without changing the garden or
	# committing a composition while navigating the pre-battle reference.
	await _tap_action("battle")
	await _tap_action("stage:3")
	var reference_battle: BattleSim = game.battle
	var reference_choices: Array[String] = game.loadout_choices.duplicate()
	await _tap_action("wave_preview")
	await _tap_action("battle_guide_tab:enemies")
	var reference_page: Dictionary = Presentation.guide_enemy_page(3,0)
	_expect(game.enemy_guide_page == 0 and _has_action("enemy_guide_page:1") and not _has_action("enemy_guide_page:-1"), "expanded enemy guide starts with valid forward navigation")
	var seen: Dictionary = {}
	for page in range(int(reference_page["pages"])):
		_expect(game.enemy_guide_page == page and _has_action("enemy_guide_page:-1") == (page > 0) and _has_action("enemy_guide_page:1") == (page+1 < int(reference_page["pages"])), "each enemy-reference page offers only existing destinations")
		for profile in Presentation.guide_enemy_page(3,page)["profiles"]:
			_expect(_text_contains(profile["name"]), "paged enemy reference exposes the actual local creature")
			seen[profile["kind"]] = true
		if page+1 < int(reference_page["pages"]): await _tap_action("enemy_guide_page:1")
	_expect(seen.size() == reference_page["total"], "dynamic reference pages include the full local enemy collection")
	for category in ["soil", "sap_suckers", "all"]:
		await _tap_action("enemy_group:" + category)
		_expect(game.enemy_guide_category == category and game.enemy_guide_page == 0, "touching a group selects it and returns to its first real page")
		for profile in Presentation.guide_enemy_page(3,0,category)["profiles"]:
			_expect(_text_contains(profile["name"]), "touch-selected classification exposes the expected creatures")
	_expect(game.enemy_guide_page == 0 and not _has_action("enemy_guide_page:-1"), "returning to all creatures cannot move before its first page")
	await _tap_action("close_wave_preview")
	_expect(game.battle == reference_battle and game.loadout_choices == reference_choices and game.battle_panel == "loadout", "browsing the enemy reference preserves the uncommitted expedition and composition")
	await _tap_action("loadout_back")
	await _tap_action("stage:1")
	_expect(_action_prefix_count("loadout_toggle:") == 6 and _has_action("loadout_page:1") and not _has_action("loadout_page:-1"), "first loadout page exposes six species and a forward control")
	var selected_before: Array[String] = game.loadout_choices.duplicate()
	await _tap_action("loadout_page:1")
	_expect(_action_prefix_count("loadout_toggle:") == 6 and _has_action("loadout_toggle:lotus") and not _has_action("loadout_page:1") and _has_action("loadout_page:-1"), "second page exposes remaining six species including aquatic plants")
	_expect(game.loadout_choices == selected_before, "page navigation never changes selected species")
	await _choose_loadout(game.Catalog.ORDER)
	await _tap_action("confirm_loadout")
	_expect(game.battle.loadout.size() == 12 and game.battle.supplies == 240, "all pages contribute to one free composition with the ordinary starting supplies")
	await _tap_free_battle_ground()
	_expect(_action_prefix_count("deploy:") == 6 and _has_action("battle_page:1"), "deployment picker paginates the complete composition")
	await _tap_action("battle_page:1")
	_expect(_has_action("deploy:lotus") and _has_action("deploy:waterlily"), "second deployment page contains both grown aquatic species")
	await _tap_action("deploy:lotus")
	var aquatic_slot: int = _last_battle_slot()
	_expect(game.battle.get_plant(aquatic_slot).get("kind", "") == "lotus" and game.battle.supplies == 125, "water defender uses the same isolated supply economy")
	await _tap_action("battle_plot:%d" % aquatic_slot)
	await _tap_action("manage_source")
	_expect(game.screen == "home" and game.home_panel == "plot" and game.active_plot_area == "pond" and game.active_plot_slot == 1, "manage source returns from a water battle unit to its actual pond planting")
