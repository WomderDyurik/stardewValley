extends SceneTree

## Active geography is compact; legacy save addresses never become map targets.
const World = preload("res://scripts/garden_world.gd")
const Grid = preload("res://scripts/garden_grid.gd")
const Terrain = preload("res://scripts/garden_terrain.gd")
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


func _initialize() -> void:
	var ids: Array[String] = []
	for data in World.districts():
		ids.append(data["id"])
		expect(World.WORLD_RECT.encloses(data["bounds"]),"active region lies inside compact estate")
		expect(World.district_at(data["center"]).get("id") == data["id"],"active region owns its focus")
	expect(ids == ["garden","nursery","greenhouse"],"only the three requested districts appear in navigation")
	expect(World.expansion_regions().is_empty(),"retired regions have no discovery ground or notices")
	expect(World.WORLD_SIZE == Vector2(1800,1536),"the camera cannot pan through the removed southern districts")
	expect(World.PLOT_CENTERS.size() == 12 and World.NURSERY_PLOT_CENTERS.size() == 8 and World.POND_PLOT_CENTERS.size() == 6,"the active map contains twelve dry income, eight defense and six aquatic locations")
	expect(Grid.HOME_CELLS.size() == 24 and Grid.NURSERY_CELLS.size() == 12,"legacy planting addresses remain available to the save reader")
	var world = World.new()
	for id in ["berry","far_garden","sun_meadow"]:
		var before: Vector2 = world.center
		expect(World.district(id).is_empty() and not world.focus_district(id),"retired district cannot create a navigation target: " + id)
		expect(world.center == before,"rejected navigation preserves current camera")
		expect(Terrain.district_ground_spec(id).is_empty() and Terrain.district_ground_polygons(id).is_empty(),"retired district owns no actual cultivated surface")
	for slot in range(12,24):
		expect(World.plot_rect(slot) == Rect2() and World.plot_visual_rect(slot) == Rect2() and World.planting_floor(slot) == Rect2(),"retired income IDs create no drawable or interactive map footprint")
	for slot in range(8,12): expect(World.nursery_plot_rect(slot) == Rect2(),"retired defense IDs create no interactive map footprint")
	expect(World.district("greenhouse")["bounds"].encloses(World.POND_RECT),"the whole pond belongs to the greenhouse district")
	expect(World.subarea("pond").get("parent") == "greenhouse","pond remains a named greenhouse subarea")
	expect(World.district("pond").get("id") == "greenhouse","legacy pond links resolve to the greenhouse region")
	expect(world.focus_district("pond"),"pond shortcut still navigates to water")
	expect(world.current_district().get("id") == "greenhouse","pond camera, header and minimap agree on the greenhouse region")
	expect(world.navigation_context()["focus"] == World.POND_CENTER,"pond shortcut focuses actual water rather than the greenhouse building")
	for zoom in [World.ZOOM_MIN,World.DEFAULT_ZOOM,World.ZOOM_MAX]:
		world.set_zoom(zoom)
		for id in ids+["pond"]:
			world.focus_district(id)
			expect(World.WORLD_RECT.grow(0.01).encloses(world.visible_world_rect()),"district shortcut respects compact camera limits")
			var at: Vector2 = World.district(id)["center"]
			expect(world.screen_to_world(world.world_to_screen(at)).distance_to(at) < 0.002,"compact camera retains reversible world projection")
		for old_focus in [Vector2(480,1872),Vector2(1296,1872),Vector2(480,2448)]:
			world.set_center(old_focus)
			world.restore_navigation_context({"focus":old_focus})
			expect(World.WORLD_RECT.grow(0.01).encloses(world.visible_world_rect()),"old southern save camera cannot reveal deleted map")
			expect(world.current_district().get("id") == "greenhouse","old removed region focus restores to a real remaining district")
			expect(world.navigation_context()["focus"] == World.district("greenhouse")["center"],"old navigation context cannot overwrite the active fallback with a stale focus")
	var plant_rects: Array[Rect2] = []
	for i in range(12): plant_rects.append(World.plot_rect(i))
	for i in range(8): plant_rects.append(World.nursery_plot_rect(i))
	for i in range(6): plant_rects.append(World.pond_plot_rect(i))
	for rect in plant_rects: expect(World.WORLD_RECT.encloses(rect),"every active planting remains fully inside the compact estate")
	for outline in Terrain.path_polygons():
		expect(not Geometry2D.triangulate_polygon(outline).is_empty(),"every remaining route triangulates")
		for point in outline: expect(World.WORLD_RECT.grow(0.01).has_point(point),"every painted route stops at the new estate boundary")
		for rect in plant_rects: expect(Geometry2D.intersect_polygons(outline,polygon(rect.grow(-0.01))).is_empty(),"remaining routes never paint through productive cells")
	for route in Paths.routes(): expect(route["id"] not in ["berry_bench","terrace_walk","sunny_rows"],"no route leads to a removed region")
	for tree in Terrain.tree_rects(): expect(World.WORLD_RECT.encloses(tree),"all tree props belong to the remaining map")
	for fence in Terrain.fence_segments():
		for point in fence: expect(World.WORLD_RECT.grow(0.01).has_point(point),"all fence segments belong to the remaining map")
	var water: Array[PackedVector2Array] = Terrain.water_outlines()
	expect(water.size() == 1,"the pond and shortened river retain one connected water surface")
	for outline in water:
		expect(not Geometry2D.triangulate_polygon(outline).is_empty(),"the shortened water outline triangulates")
		for point in outline: expect(World.WORLD_RECT.grow(0.01).has_point(point),"water remains within the compact estate")
	print("Three district world: ",checks," checks; ",failures," failures")
	quit(0 if failures == 0 else 1)
