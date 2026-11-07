extends SceneTree

## Native acceptance of the finite critic list: logical district selection,
## visible screen labels, stable nursery identity, real aquatic taps and art.
const World = preload("res://scripts/garden_world.gd")
const GardenScreen = preload("res://scripts/screens/garden_screen.gd")

class AuditedGame:
	extends "res://scripts/main.gd"
	var sprite_calls: Array[Dictionary] = []
	func _draw() -> void:
		sprite_calls.clear()
		super._draw()
	func _sprite(texture: Texture2D, rect: Rect2, tint: Color = Color.WHITE) -> void:
		sprite_calls.append({"texture":texture,"rect":rect})
		super._sprite(texture,rect,tint)

var game: Node2D
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	game.toast_time = 0
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	for layout in game.text_layouts:
		expect(not layout["truncated"],"critic corrections keep readable complete text: " + str(layout["text"]))

func hit(action: String) -> Rect2:
	for index in range(game.hitboxes.size()-1,-1,-1):
		if game.hitboxes[index]["action"] == action: return game.hitboxes[index]["rect"]
	return Rect2()

func tap_point(point: Vector2) -> void:
	var global: Vector2 = game.get_global_transform_with_canvas() * point
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = global
	root.push_input(touch,true)
	await process_frame
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = global
	root.push_input(release,true)
	await settle()

func tap(action: String) -> bool:
	await settle()
	var bounds: Rect2 = hit(action)
	expect(bounds.has_area(),"the actual visible control exists: " + action)
	if not bounds.has_area(): return false
	await tap_point(bounds.get_center())
	return true

func drag(first: Vector2, last: Vector2) -> void:
	var transform: Transform2D = game.get_global_transform_with_canvas()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = transform * first
	root.push_input(touch,true)
	await process_frame
	var previous: Vector2 = transform * first
	for step in range(1,9):
		var position: Vector2 = transform * first.lerp(last,float(step)/8.0)
		var motion := InputEventScreenDrag.new()
		motion.index = 0
		motion.position = position
		motion.relative = position - previous
		root.push_input(motion,true)
		previous = position
		await process_frame
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = transform * last
	root.push_input(release,true)
	await settle()

func garden_data() -> Array:
	return [game.state.coins,game.state.completed_level,game.state.unlocked_seeds.duplicate(),game.state.home_plots.duplicate(),game.state.home_levels.duplicate(),game.state.nursery_plots.duplicate(),game.state.nursery_levels.duplicate(),game.state.pond_plots.duplicate(),game.state.pond_levels.duplicate()]

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

func check_header_footer(id: String) -> void:
	var name: String = World.district(id)["name"]
	var header: bool = false
	var footer: bool = false
	for layout in game.text_layouts:
		var bounds: Rect2 = layout["bounds"]
		if str(layout["text"]).begins_with(name):
			if bounds.position.y < World.MAP_VIEW.position.y: header = true
			if bounds.position.y >= World.MAP_VIEW.end.y: footer = true
	expect(header and footer,"header and footer agree with the selected district: " + id)

func check_world_labels() -> void:
	var labels: Array = game.active_view.get("world_label_layouts")
	var levels: Array[Rect2] = []
	for label in labels:
		var rect: Rect2 = label["rect"]
		expect(World.MAP_VIEW.grow(0.1).encloses(rect),"world text remains wholly in its visible map area")
		if label["kind"] == "level":
			expect(rect.size.x >= 18.0 and rect.size.y >= 14.0,"individual progress uses a stable readable cell badge")
			levels.append(rect)
			var readable: bool = false
			for layout in game.text_layouts:
				if str(layout["text"]) == str(label["text"]) and rect.grow(0.1).encloses(layout["bounds"]) and int(layout["font_size"]) >= 11:
					readable = true
			expect(readable,"1/7/15/20 stay actual readable text at every zoom")
	for index in range(levels.size()):
		for other in range(index+1,levels.size()):
			expect(not levels[index].intersects(levels[other]),"neighboring progress badges never overlap on a phone viewport")

func run() -> void:
	game = AuditedGame.new()
	game.test_mode = true
	root.add_child(game)
	await create_timer(0.2).timeout
	game.set_process(false)
	fill_garden()
	var original: Array = garden_data()
	for zoom in [World.ZOOM_MIN,World.DEFAULT_ZOOM,World.ZOOM_MAX]:
		game.garden_world.set_zoom(zoom)
		for district in World.districts():
			var id: String = district["id"]
			await tap("open_districts")
			await tap("district:" + id)
			expect(game.garden_world.current_district().get("id") == id,"real district row selects its intended place at every zoom")
			check_header_footer(id)
			check_world_labels()
			await tap("open_districts")
			var selected: Array[String] = []
			for layout in game.text_layouts:
				if str(layout["text"]).ends_with(" · сейчас"): selected.append(str(layout["text"]))
			expect(selected == [str(district["name"]) + " · сейчас"],"district sheet highlights exactly the selected place after clamping")
			await tap("close_home_panel")
	game.garden_world.set_zoom(World.ZOOM_MIN)
	game.garden_world.focus_district("garden")
	await settle()
	await drag(World.MAP_VIEW.get_center(),World.MAP_VIEW.get_center()+Vector2(0,-340))
	expect(game.garden_world.current_district().get("id") == "greenhouse","a real drag transitions to the next district without a stale pinned label")
	check_header_footer("greenhouse")
	var sun: Vector2 = game.MINIMAP_INNER.position + World.district("sun_meadow")["center"] / World.WORLD_SIZE * game.MINIMAP_INNER.size
	await tap_point(sun)
	expect(game.garden_world.current_district().get("id") == "sun_meadow","minimap tap preserves the intended sun meadow at minimum zoom")
	check_header_footer("sun_meadow")
	# All six permanent aquatic locations remain reachable, including the edges.
	game.garden_world.focus_district("pond")
	await settle()
	for slot in range(6):
		await tap("pond_plot:%d" % slot)
		expect(game.active_plot_area == "pond" and game.active_plot_slot == slot and game.home_panel == "plot","each actual aquatic tap opens its own stable planting identity")
		await tap("close_home_panel")
	expect(garden_data() == original,"navigation, inspection and all aquatic taps preserve all 42 species, levels, unlocks and garden money")
	# Identical plants and levels must still have distinct persistent slot labels.
	for slot in range(8):
		game.state.nursery_plots[slot] = "nettle"
		game.state.nursery_levels[slot] = 9
	game.garden_world.set_zoom(World.DEFAULT_ZOOM)
	game.garden_world.focus_district("nursery")
	for slot in range(8):
		await tap("nursery")
		var bounds: Rect2 = hit("nursery_plot:%d" % slot)
		var identified: bool = false
		for layout in game.text_layouts:
			if str(layout["text"]) == "Клетка %d" % (slot+1) and bounds.encloses(layout["bounds"]): identified = true
		expect(identified,"identical nursery plants are named by their real permanent cell")
		await tap("nursery_plot:%d" % slot)
		expect(game.active_plot_area == "nursery" and game.active_plot_slot == slot and game.home_panel == "plot","nursery row tap opens exactly the numbered bed")
		await tap("close_home_panel")
	game.garden_world.focus_district("greenhouse")
	await tap("greenhouse")
	var glass: bool = false
	var wrong_house: bool = false
	for call in game.sprite_calls:
		if Rect2(200,285,140,120).encloses(call["rect"]):
			if call["texture"] == game.FARM_ART["greenhouse"]: glass = true
			if call["texture"] == game.FARM_ART["cottage"]: wrong_house = true
	expect(glass and not wrong_house,"the actual greenhouse menu draw uses the same glass building as the garden")
	await tap("close_home_panel")
	# Visiting a locked place changes context without pretending it is unlocked.
	game.state = GardenState.new()
	game.garden_world.set_zoom(World.ZOOM_MIN)
	game.garden_world.focus_district("pond")
	await settle()
	var closed: bool = false
	for layout in game.text_layouts:
		if str(layout["text"]).contains("закрыто"): closed = true
	expect(closed and not hit("pond_plot:0").has_area() and not hit("pond_plot:5").has_area(),"closed pond keeps its proper name and opening notice without phantom active plants")
	check_header_footer("pond")
	print("Garden critic regressions: ",checks," checks; ",failures," failures")
	game.queue_free()
	quit(0 if failures == 0 else 1)
