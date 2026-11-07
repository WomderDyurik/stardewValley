extends SceneTree

## Full planting capacity and real circulation are shared by rendering and taps.
const World = preload("res://scripts/garden_world.gd")
const Grid = preload("res://scripts/garden_grid.gd")
const Paths = preload("res://scripts/garden_paths.gd")
var checks: int = 0
var failures: int = 0


func expect(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(reason)


func polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])


func expected_cell(area: String, slot: int) -> Vector2i:
	var origins: Array = [Vector2i(2,5),Vector2i(9,5),Vector2i(2,12),Vector2i(9,12)] if area == "home" else [Vector2i(20,4),Vector2i(27,4),Vector2i(20,11),Vector2i(27,11)]
	var local: int = slot % 36
	return origins[slot / 36] + Vector2i(local % 6,local / 6)


func _initialize() -> void:
	_check_land_use()
	_check_circulation()
	_check_camera()
	print("Large field world: ",checks," checks; ",failures," failures")
	quit(0 if failures == 0 else 1)


func _check_land_use() -> void:
	var names: Array[String] = []
	for district in World.districts():
		names.append(district["id"])
		expect(World.WORLD_RECT.encloses(district["bounds"]),"every region remains within the expanded estate")
	expect(names == ["garden","nursery","greenhouse"],"the expanded fields do not create extra regions")
	expect(World.WORLD_SIZE == Vector2(3600,2880),"the map has enough real space for both large fields")
	expect(World.PLOT_CENTERS.size() == 144 and World.NURSERY_PLOT_CENTERS.size() == 144,"both dry fields expose all four six-by-six planting squares")
	expect(World.POND_PLOT_CENTERS.size() == 6,"all existing aquatic identities retain a water location")
	var occupied: Dictionary = {}
	var rectangles: Array[Rect2] = []
	for area in ["home","nursery","pond"]:
		var cells: Array[Vector2i] = Grid.planting_cells(area)
		for slot in range(cells.size()):
			var rect: Rect2 = Grid.planting_rect(area,slot)
			var parent: String = "garden" if area == "home" else "nursery"
			expect(not occupied.has(cells[slot]),"every paid slot owns a separate world cell")
			occupied[cells[slot]] = true
			expect(World.WORLD_RECT.encloses(rect) and World.district(parent)["bounds"].encloses(rect),"the entire plant stays inside its planting district")
			expect(rect.size == Vector2.ONE*96 and (rect.position/96).is_equal_approx((rect.position/96).round()),"planting and touch footprints retain the regular ninety-six-pixel lattice")
			expect(rect.size.x*World.ZOOM_MIN >= 44 and rect.size.y*World.ZOOM_MIN >= 44,"every cell remains a unique finger-sized target at minimum zoom")
			expect(not rect.intersects(World.district("greenhouse")["bounds"]),"the greenhouse improvement district contains no planting cell")
			if area == "home":
				expect(cells[slot] == expected_cell("home",slot),"all home identities occupy the four intended six-by-six squares")
				expect(World.plot_rect(slot) == rect and World.planting_floor(slot).encloses(rect) and World.plot_district(slot) == "garden","the former greenhouse and archived crop identities now draw in the first field")
			elif area == "nursery":
				expect(cells[slot] == expected_cell("nursery",slot),"all nursery identities occupy the four intended six-by-six squares")
				expect(World.nursery_plot_rect(slot) == rect and World.NURSERY_FLOOR.encloses(rect) and World.nursery_plot_district(slot) == "nursery","all defender identities belong to the second field")
			else:
				expect(World.pond_plot_rect(slot) == rect,"the saved aquatic identity uses its relocated cell")
				for corner in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
					var relative: Vector2 = (corner-World.POND_RECT.get_center())/(World.POND_RECT.size/2)
					expect(relative.length_squared() < 1,"each complete water cell fits comfortably inside the nursery pond")
			for building in World.building_hit_regions().values(): expect(not rect.intersects(building),"buildings cannot intercept any complete planting")
			for frame in World.PROP_RECTS.values(): expect(not rect.intersects(frame),"farm props cannot hide any complete planting")
			for frame in World.SIGN_RECTS.values(): expect(not rect.intersects(frame),"place signs leave the planting silhouette and label clear")
			for frame in Grid.occupied_areas().values(): expect(not rect.intersects(frame),"equipment, well and resting places never occupy a planting cell")
			rectangles.append(rect)
	expect(occupied.size() == 294,"144 crops, 144 defenders and six aquatic plants have distinct identities")
	for index in range(rectangles.size()):
		for other in range(index): expect(not rectangles[index].intersects(rectangles[other]),"no dry or aquatic interaction rectangle overlaps another")
	for id in ["irrigation","compost","harvest_crate"]:
		expect(World.district("greenhouse")["bounds"].encloses(Grid.helper_rect(id)),"the greenhouse contains the useful improvement equipment")
	expect(World.subarea("pond").get("parent") == "nursery" and World.district("pond").get("id") == "nursery","the water shortcut belongs to the second planting region")
	expect(World.plot_rect(144) == Rect2() and World.nursery_plot_rect(144) == Rect2() and World.pond_plot_rect(6) == Rect2(),"out-of-range slot identities create no phantom planting")


func _check_circulation() -> void:
	var routes: Array[PackedVector2Array] = Paths.polygons()
	for outline in routes:
		expect(not Geometry2D.triangulate_polygon(outline).is_empty(),"every large-field approach has drawable connected ground")
		for point in outline: expect(World.WORLD_RECT.grow(0.01).has_point(point),"the painted paths remain inside the expanded estate")
		for area in ["home","nursery","pond"]:
			for slot in range(Grid.planting_cells(area).size()):
				expect(Geometry2D.intersect_polygons(outline,polygon(Grid.planting_rect(area,slot).grow(-0.01))).is_empty(),"actual walking ground never cuts through a plant cell")
		for id in ["irrigation","compost","harvest_crate"]:
			expect(Geometry2D.intersect_polygons(outline,polygon(Grid.helper_rect(id))).is_empty(),"a path cannot pass through the improvement equipment")
	var connected: Dictionary = {0:true}
	var changed: bool = true
	while changed:
		changed = false
		for index in range(routes.size()):
			if connected.has(index): continue
			for reached in connected.keys():
				if not Geometry2D.intersect_polygons(routes[index],routes[reached]).is_empty():
					connected[index] = true
					changed = true
					break
	expect(connected.size() == routes.size(),"all two-field circulation and workshop paths form one connected network")
	var destinations: Dictionary = {"cottage":World.COTTAGE_RECT,"nursery":World.NURSERY_RECT,"greenhouse":World.GREENHOUSE_RECT,"pond_bench":Grid.POND_BENCH_RECT}
	var doors: Dictionary = Paths.doorway_points()
	for id in destinations:
		var frame: Rect2 = destinations[id]
		expect(doors[id].distance_to(Vector2(frame.get_center().x,frame.end.y)) < 0.01,"the approach reaches its real relocated entrance")
		expect(routes.any(func(outline): return Geometry2D.is_point_in_polygon(doors[id],outline)),"each entrance belongs to the connected walking network")


func _check_camera() -> void:
	var camera = World.new()
	for zoom in [World.ZOOM_MIN,World.DEFAULT_ZOOM,World.ZOOM_MAX]:
		camera.set_zoom(zoom)
		for id in ["garden","nursery","greenhouse","pond"]:
			expect(camera.focus_district(id),"each current destination has a camera shortcut")
			expect(World.WORLD_RECT.grow(0.01).encloses(camera.visible_world_rect()),"each field camera respects the expanded estate edges")
			var at: Vector2 = World.district(id)["center"]
			expect(camera.screen_to_world(camera.world_to_screen(at)).distance_to(at) < 0.002,"the expanded map keeps reversible input coordinates")
			if id == "pond": expect(camera.current_district().get("id") == "nursery","water navigation highlights the second region")
		for point in [Vector2(-100,-100),Vector2(4000,3000),Vector2(480,2448)]:
			camera.set_center(point)
			camera.restore_navigation_context({"focus":point})
			expect(World.WORLD_RECT.grow(0.01).encloses(camera.visible_world_rect()),"old camera points cannot expose a blank map border")
	var before: Vector2 = camera.center
	expect(not camera.focus_district("berry") and camera.center == before,"the former fourth and later districts remain absent")
