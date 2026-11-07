extends SceneTree

## Native regression coverage for a full world behind floating HUD controls.
## All fixtures are artificial and enter test_mode before the scene is added.
const World = preload("res://scripts/garden_world.gd")
const View = preload("res://scripts/battle_map_view.gd")
const OldGardenBar := Color("6d8455")
const OldBattleBar := Color("42673c")

var game: Node2D
var failures: int = 0
var checks: int = 0
var captures: int = 0
var garden_edge_signatures: Dictionary = {}


func _initialize() -> void:
	run.call_deferred()


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func fresh_game() -> Node2D:
	var instance: Node2D = load("res://scenes/main.tscn").instantiate()
	instance.test_mode = true
	root.add_child(instance)
	instance.set_process(false)
	return instance


func fill_garden() -> void:
	game.state.coins = 100000
	for stage in range(1,4): game.state.claim_stage_reward(stage)
	for index in range(24):
		game.state.home_plots[index] = ("tomato" if index%2 == 0 else "marigold") if index < 8 else "cucumber" if index < 12 else ("strawberry" if index%2 == 0 else "currant") if index < 16 else "mint" if index < 20 else "pumpkin"
		game.state.home_levels[index] = [1,7,15,20][index%4]
	for index in range(12):
		game.state.nursery_plots[index] = ("nettle" if index%2 == 0 else "lavender") if index < 8 else "pepper"
		game.state.nursery_levels[index] = [1,7,15,20][index%4]
	for index in range(6):
		game.state.pond_plots[index] = "waterlily" if index%2 == 0 else "lotus"
		game.state.pond_levels[index] = [1,7,15,20][index%4]
	game.state.home_ready = true
	game.state.home_elapsed = game.State.HOME_CYCLE


func garden_progress() -> Array:
	return [game.state.coins,game.state.completed_level,game.state.home_plots.duplicate(),game.state.home_levels.duplicate(),game.state.nursery_plots.duplicate(),game.state.nursery_levels.duplicate(),game.state.pond_plots.duplicate(),game.state.pond_levels.duplicate(),game.state.unlocked_seeds.duplicate()]


func settle(label: String = "") -> Image:
	game.toast_time = 0
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	for layout in game.text_layouts:
		expect(not layout["truncated"],"floating UI keeps complete text: " + str(layout["text"]))
		for run in layout["runs"]:
			expect(layout["bounds"].grow(0.1).encloses(run["rect"]),"floating UI glyphs remain in their allocated area")
	var image: Image = root.get_texture().get_image()
	if not label.is_empty() and OS.get_cmdline_user_args().has("--screenshots"):
		image.save_png("res://artifacts/ui-overlay-" + label + ".png")
		captures += 1
	return image


func hit(action: String) -> Rect2:
	for index in range(game.hitboxes.size()-1,-1,-1):
		if str(game.hitboxes[index]["action"]) == action: return game.hitboxes[index]["rect"]
	return Rect2()


func logical_pixel(image: Image, point: Vector2) -> Color:
	var global: Vector2 = game.get_global_transform_with_canvas() * point
	var native: Vector2 = root.get_final_transform() * global
	return image.get_pixel(clampi(roundi(native.x),0,image.get_width()-1),clampi(roundi(native.y),0,image.get_height()-1))


func edge_signature(image: Image) -> String:
	var samples: Array[String] = []
	for x in [2,6,534,538]:
		for y in [2,10,28,52,80,96,826,844,872,906,936,958]:
			samples.append(logical_pixel(image,Vector2(x,y)).to_html(false))
	return "".join(samples)


func check_exposed_world(image: Image, old_bar: Color, label: String) -> void:
	var old_count: int = 0
	var total: int = 0
	for x in [2,6,534,538]:
		for y in range(2,98,4):
			var color: Color = logical_pixel(image,Vector2(x,y))
			if color.is_equal_approx(old_bar): old_count += 1
			total += 1
		for y in range(826,960,4):
			var color: Color = logical_pixel(image,Vector2(x,y))
			if color.is_equal_approx(old_bar): old_count += 1
			total += 1
	# These screen edges sit outside all floating controls. Former full-width
	# bars covered them; the background must now reach the actual screen edge.
	expect(float(old_count)/float(total) < 0.1,"world replaces the previous top/bottom flat bars: " + label)


func check_control_targets() -> void:
	for target in game.hitboxes:
		if bool(target.get("world",false)): continue
		var action: String = str(target["action"])
		if action in ["battle_ground"]: continue
		var bounds: Rect2 = target["rect"]
		expect(Rect2(0,0,540,960).grow(0.01).encloses(bounds),"visible UI control stays inside the portrait canvas: " + action)
		expect(bounds.size.x >= 44.0 and bounds.size.y >= 44.0,"floating UI retains a finger-sized target: " + action)


func press(point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = true
	event.position = game.get_global_transform_with_canvas() * point
	root.push_input(event,true)
	await process_frame


func release(point: Vector2, cancelled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = false
	event.canceled = cancelled
	event.position = game.get_global_transform_with_canvas() * point
	root.push_input(event,true)
	await settle()


func tap(point: Vector2) -> void:
	await press(point)
	await release(point)


func move(point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = game.get_global_transform_with_canvas() * point
	root.push_input(event,true)
	await settle()


func image_difference(first: Image, second: Image, bounds: Rect2) -> int:
	var changed: int = 0
	for x in range(roundi(bounds.position.x+3),roundi(bounds.end.x-3),3):
		for y in range(roundi(bounds.position.y+3),roundi(bounds.end.y-3),3):
			if logical_pixel(first,Vector2(x,y)) != logical_pixel(second,Vector2(x,y)):
				changed += 1
	return changed


func run() -> void:
	game = fresh_game()
	await process_frame
	fill_garden()
	var before: Array = garden_progress()
	for district in World.districts():
		for zoom in [["min",World.ZOOM_MIN],["default",World.DEFAULT_ZOOM],["max",World.ZOOM_MAX]]:
			game.garden_world.set_zoom(zoom[1])
			game.garden_world.focus_district(district["id"])
			var label: String = "garden-%s-%s" % [district["id"],zoom[0]]
			var image: Image = await settle(label)
			check_exposed_world(image,OldGardenBar,label)
			garden_edge_signatures[edge_signature(image)] = true
			check_control_targets()
	expect(garden_edge_signatures.size() >= 4,"real garden world, rather than a static wallpaper, continues behind header and footer as camera changes")
	expect(garden_progress() == before,"all full-screen garden views preserve actual plantings, levels, money and discoveries")
	game.garden_world.set_zoom(World.DEFAULT_ZOOM)
	game.garden_world.focus_district("garden")
	var normal: Image = await settle("garden-idle")
	var help: Rect2 = hit("help")
	expect(help.has_area(),"the floating garden help control is actually visible")
	await press(help.get_center())
	var held: Image = await settle("button-pressed")
	expect(game._is_control_pressed("help") and not game.help_open,"a held button has a pressed state before activation")
	expect(image_difference(normal,held,help) >= 4,"a real held button visibly changes on the rendered screen")
	await move(Vector2(280,370))
	expect(not game._is_control_pressed("help"),"moving out of a button removes its pressed appearance")
	await release(Vector2(280,370))
	expect(not game.help_open,"releasing a button outside its target cancels activation")
	await press(help.get_center())
	await release(help.get_center(),true)
	expect(not game.help_open and not game._is_control_pressed("help"),"system touch cancellation resets the visual state without opening a modal")
	game.state.home_ready = false
	game.state.home_elapsed = 2.0
	var disabled_before: Array = garden_progress()
	var camera_before: Vector2 = game.garden_world.center
	await settle("garden-disabled")
	var harvest_hud_active: bool = game.hitboxes.any(func(target:Dictionary)->bool:return target["action"]=="collect" and not target.get("world",false))
	expect(not harvest_hud_active,"the unripe floating harvest control has no active HUD purchase action")
	await press(Vector2(140,903))
	await move(Vector2(130,870))
	await release(Vector2(140,903))
	expect(garden_progress() == disabled_before and game.garden_world.center == camera_before,"the disabled floating control cannot leak input into world objects or pan the garden")
	await tap(help.get_center())
	await settle("garden-help")
	expect(game.help_open and not hit("open_districts").has_area() and not hit("home_plot:0").has_area(),"a modal owns input over the full world and floating HUD")
	game._action("help")
	game._action("battle")
	game._action("stage:1")
	game.loadout_choices.assign(["nettle","tomato"])
	game._action("confirm_loadout")
	var battle_image: Image = await settle("battle-idle")
	check_exposed_world(battle_image,OldBattleBar,"battle")
	check_control_targets()
	var battle_before: Dictionary = game.battle.export_snapshot()
	var primary: Rect2 = hit("primary")
	await press(primary.get_center())
	var battle_pressed: Image = await settle("battle-pressed")
	expect(game._is_control_pressed("primary") and game.battle.phase == "preparing","pressing the floating main action does not start a wave before release")
	expect(image_difference(battle_image,battle_pressed,primary) >= 8,"the primary action has a visible pressed state on top of the meadow")
	await release(primary.get_center(),true)
	expect(game.battle.export_snapshot() == battle_before,"cancelling the battle button preserves the complete simulation and wallet")
	game.queue_free()
	print("Floating UI overlays: ",checks," checks; ",failures," failures; ",captures," captures")
	quit(0 if failures == 0 else 1)
