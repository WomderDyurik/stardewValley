extends "res://tests/test_free_placement_ui.gd"

## Native proof of the reported right-edge clipping, resized windows and saves.
const UI = preload("res://scripts/battle_presentation.gd")
const Grid = preload("res://scripts/garden_grid.gd")
var captures: int = 0
var real_copy: String = "/private/tmp/planta2-before-cell-grid.json"


func capture(label: String) -> void:
	await settle()
	var result: Error = root.get_texture().get_image().save_png("res://artifacts/cell-grid-after-"+label+".png")
	expect(result == OK,"native screenshot saves: "+label)
	captures += 1
	# Garden terrain also registers labels in world coordinates before its
	# camera transform. Tactical UI labels are already logical screen bounds.
	if game.screen == "battle":
		for layout in game.text_layouts:
			expect(Rect2(0,0,540,960).grow(0.1).encloses(layout["bounds"]),"battle label stays in portrait canvas: %s / %s / %s" % [label,layout["text"],layout["bounds"]])
	else:
		for entry in game.active_view.world_label_layouts:
			expect(game.GardenMap.MAP_VIEW.encloses(entry["rect"]),"drawn garden level/sign labels fit the camera viewport")


func check_real_copy() -> void:
	game = fresh_game()
	expect(game.state.load_game(real_copy),"the untouched real v5 backup loads")
	var wallet: int = game.state.coins
	var garden: Array = garden_progress()
	var helpers: Dictionary = game.state.helper_levels.duplicate(true)
	var source_session: Dictionary = game.state.session_data.duplicate(true)
	game._restore_session()
	expect(garden_progress() == garden and game.state.helper_levels == helpers,"restoring the real old session preserves all42 saved IDs, levels, wallet and helpers")
	game.garden_world.set_zoom(0.8)
	game.garden_world.focus_district("garden")
	await capture("real-garden")
	expect(game.battle != null and source_session.has("battle"),"the real backup contains a restorable legacy free-position battle")
	if game.battle != null and source_session.has("battle"):
		var expected: Dictionary = source_session["battle"].duplicate(true)
		expected["values"]["paused"] = true
		expect(game.battle.export_snapshot() == expected,"legacy coordinates, route, IDs, cooldowns, RNG, attackers and supplies are not snapped or rewritten")
		game._show_screen("battle")
		await capture("real-old-battle")
		var path: String = "/private/tmp/planta2-grid-real-roundtrip-%d.json" % OS.get_process_id()
		game._save(path)
		var loaded := State.new()
		expect(loaded.load_game(path),"the legacy battle and new garden grid save through the atomic reader")
		expect(loaded.coins == wallet and loaded.helper_levels == helpers and loaded.session_data["battle"] == expected,"an immediate re-save cannot spend money, grant equipment, move old anchors or duplicate rewards")
		DirAccess.remove_absolute(path)
		DirAccess.remove_absolute(path+".tmp")


func rightmost_free() -> Vector2:
	var result := Vector2(INF,INF)
	var right: float = -INF
	for point in Placement.grid_centers():
		if not game.battle.placement_check(point,"nettle").get("valid",false): continue
		if View.screen_point(point).x > right:
			right = View.screen_point(point).x
			result = point
	expect(result.is_finite(),"the authored map has a legal cell near its right edge")
	return result


func check_right_edge() -> void:
	await fixture()
	await capture("battle-empty-grid")
	var point: Vector2 = rightmost_free()
	await begin_drag("nettle",point+Vector2(4,5))
	var preview: Dictionary = game.get_battle_placement_preview()
	expect(preview.get("position",Vector2.INF).is_equal_approx(point),"the right-edge ghost snaps to the canonical cell")
	expect(View.BOARD.encloses(preview.get("rect",Rect2())),"the entire right-edge cell highlight remains inside the tactical viewport")
	await capture("battle-drag-right")
	await release(View.screen_point(point+Vector2(4,5))+TOUCH_OFFSET)
	var plant: Dictionary = placement_at(point)
	expect(not plant.is_empty(),"the right-edge drag installs the displayed cell")
	if not plant.is_empty():
		var slot: int = int(plant["slot"])
		game.active_battle_slot = slot
		var center: Vector2 = game.battle_to_screen(point)
		var radius: float = float(game.state.plant_data("nettle",int(plant["level"]))["range"])*game.battle_view_scale()
		var arcs: Array[PackedVector2Array] = UI.projected_range_strokes(game,slot)
		expect(not arcs.is_empty(),"the real selected defender exposes visible clipped range arcs")
		for arc in arcs:
			for vertex in arc: expect(View.BOARD.grow(-0.74).has_point(vertex),"the complete range stroke stays inside the tactical viewport")
			for index in range(1,arc.size()):
				var midpoint: Vector2 = (arc[index]+arc[index-1])/2.0
				expect(absf(midpoint.distance_to(center)-radius) < 0.2,"the selected range contains only circular arcs and no straight clipping wall")
		await capture("battle-range-right")
	game.active_battle_slot = -1
	var spare: Vector2 = rightmost_free()
	game.battle.supplies = 0
	game.quick_plant_kind = "nettle"
	game.battle_preview_point = spare+Vector2(3,3)
	preview = game.get_battle_placement_preview()
	expect(preview.get("active",false) and not preview.get("valid",true),"the actual insufficient-supplies ghost remains explained")
	var notice: Rect2 = View.placement_notice(preview.get("rect",Rect2()))
	expect(View.BOARD.encloses(notice),"the full right-edge insufficient-supplies notice fits inside the tactical viewport")
	await capture("battle-notice-right")
	for point_in_grid in Placement.grid_centers():
		var cell: Rect2 = View.cell_at(point_in_grid)
		cell.position += View.BOARD.position
		expect(View.BOARD.encloses(View.placement_notice(cell)),"every selectable cell has a fully visible notice location")


func check_resizes() -> void:
	for size in [Vector2i(900,600),Vector2i(486,640),Vector2i(486,864)]:
		root.size = size
		await create_timer(0.1).timeout
		await capture("battle-notice-window-%dx%d" % [size.x,size.y])
		expect(ProjectSettings.get_setting("display/window/stretch/aspect") == "keep","wide and short clients retain the full portrait canvas")
		expect(root.get_visible_rect().size.is_equal_approx(Vector2(540,960)),"resizing retains the entire540×960 logical canvas")
		var final: Transform2D = root.get_final_transform()
		for corner in [Vector2.ZERO,Vector2(540,0),Vector2(540,960),Vector2(0,960)]:
			expect(Rect2(Vector2.ZERO,Vector2(root.size)).grow(0.1).has_point(final*corner),"the full portrait canvas fits inside the actual client, including its bottom and right edge")
		print("Cell grid resized viewport: client=",root.size,"; visible=",root.get_visible_rect(),"; final=",root.get_final_transform())
	game.quick_plant_kind = ""
	game.battle_preview_point = Vector2(INF,INF)
	game._show_screen("home")
	game.garden_world.focus_district("pond")
	for zoom in [0.5,1.35]:
		game.garden_world.set_zoom(zoom)
		await capture("garden-pond-zoom-"+str(zoom))


func check_healer_pulse() -> void:
	game._show_screen("battle")
	game.quick_plant_kind = ""
	game.battle_preview_point = Vector2(INF,INF)
	game.active_battle_slot = -1
	var edge: Vector2 = game.battle.path_points()[0]
	for point in game.battle.path_points():
		if View.screen_point(point).x > View.screen_point(edge).x: edge = point
	game.battle.enemies.assign([{"id":777,"kind":"healer","position":edge,"hp":100.0,"max_hp":100.0,"slow":0.0,"heal_pulse":0.0,"heal_radius":160.0}])
	await settle()
	var without: Image = root.get_texture().get_image()
	game.battle.enemies[0]["heal_pulse"] = 0.18
	await settle()
	var with_pulse: Image = root.get_texture().get_image()
	var final: Transform2D = root.get_final_transform()
	var physical := Rect2(final*View.BOARD.position,final.basis_xform(View.BOARD.size))
	var outside_changed: int = 0
	var inside_changed: int = 0
	for y in range(with_pulse.get_height()):
		for x in range(with_pulse.get_width()):
			if with_pulse.get_pixel(x,y) == without.get_pixel(x,y): continue
			if physical.grow(1.0).has_point(Vector2(x+0.5,y+0.5)): inside_changed += 1
			else: outside_changed += 1
	expect(inside_changed > 25,"the real healer renderer emits a visible edge pulse")
	expect(outside_changed == 0,"the actual healer pulse changes no pixels outside its tactical viewport")
	await capture("enemy-healer-edge-pulse")
	game.battle.enemies.clear()


func visible_ink_rows(image: Image, rect: Rect2) -> int:
	var final: Transform2D = root.get_final_transform()
	var physical := Rect2(final*rect.position,final.basis_xform(rect.size)).grow(-1.5)
	var result: int = 0
	for y in range(ceili(physical.position.y),floori(physical.end.y)+1):
		var ink: bool = false
		for x in range(ceili(physical.position.x),floori(physical.end.x)+1):
			# The level's paper and ink are #ecdfb7 and #34452f. Require actual
			# stem pixels, not just a fitted text-layout rectangle or a serif dot.
			if (236.0-image.get_pixel(x,y).r*255.0)/184.0 > 0.2: ink = true
		if ink: result += 1
	return result


func check_digit_pixels() -> void:
	game._show_screen("home")
	game.garden_world.set_zoom(0.8)
	game.garden_world.focus_district("garden")
	for slot in range(8):
		game.state.home_plots[slot] = "tomato"
		game.state.home_levels[slot] = [1,3,20][slot%3]
	await settle()
	var image: Image = root.get_texture().get_image()
	var tested: int = 0
	for label in game.active_view.world_label_layouts:
		if label["kind"] != "level": continue
		for slot in range(8):
			if label["world_rect"] != Grid.planting_rect("home",slot): continue
			var rows: int = visible_ink_rows(image,label["rect"])
			expect(rows >= 6,"native level %s has a complete visible digit stem in column %d: %d ink rows" % [label["text"],slot%4,rows])
			tested += 1
	expect(tested == 8,"glyph-pixel proof covers all four columns and both rows with levels1/3/20")
	await capture("garden-digit-phases")


func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save-copy="): real_copy = arg.trim_prefix("--save-copy=")
	await check_real_copy()
	await check_right_edge()
	await check_resizes()
	await check_healer_pulse()
	await check_digit_pixels()
	game.queue_free()
	print("Cell grid native UI: ",checks," checks; ",captures," captures; ",failures," failures")
	quit(0 if failures == 0 else 1)
