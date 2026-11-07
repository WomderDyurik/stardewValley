extends SceneTree

## Validate painted land, water and decorative silhouettes, not just addresses.
const World = preload("res://scripts/garden_world.gd")
const Grid = preload("res://scripts/garden_grid.gd")
const Terrain = preload("res://scripts/garden_terrain.gd")
const Nursery = preload("res://scripts/nursery_environment.gd")
var checks: int = 0
var failures: int = 0


func expect(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(reason)


func rectangle(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])


func covered_by(rect: Rect2, surfaces: Array[PackedVector2Array]) -> bool:
	var remaining: Array[PackedVector2Array] = [rectangle(rect.grow(-0.01))]
	for surface in surfaces:
		var next: Array[PackedVector2Array] = []
		for fragment in remaining: next.append_array(Geometry2D.clip_polygons(fragment,surface))
		remaining = next
	return remaining.is_empty()


func _initialize() -> void:
	expect(Terrain.GARDEN_FLOOR == World.GARDEN_FLOOR,"home soil and address metadata agree")
	expect(Terrain.NURSERY_FLOOR == World.NURSERY_FLOOR,"nursery soil and address metadata agree")
	expect(Terrain.greenhouse_ground_polygons().is_empty(),"the greenhouse owns no cultivated ground")
	var beds: Array[Rect2] = []
	for entry in [["home",Terrain.garden_courtyard_polygons()],["nursery",Terrain.nursery_ground_polygons()]]:
		for surface in entry[1]:
			expect(not Geometry2D.triangulate_polygon(surface).is_empty(),"actual cultivated soil triangulates")
		for slot in range(Grid.planting_cells(entry[0]).size()):
			var bed: Rect2 = Grid.planting_rect(entry[0],slot)
			beds.append(bed)
			expect(covered_by(bed,entry[1]),"the entire real planting has painted soil: %s:%d" % [entry[0],slot])
	var pond: PackedVector2Array = Terrain.pond_outline()
	expect(not Geometry2D.triangulate_polygon(pond).is_empty(),"aquatic beds have a real stepped water surface")
	for slot in range(Grid.POND_CELLS.size()):
		var bed: Rect2 = Grid.planting_rect("pond",slot)
		beds.append(bed)
		for point in [bed.position,Vector2(bed.end.x,bed.position.y),bed.end,Vector2(bed.position.x,bed.end.y),bed.get_center()]:
			expect(Geometry2D.is_point_in_polygon(point,pond),"the complete aquatic planting lies on water")
	expect(beds.size() == 294,"all 288 dry and six aquatic planting footprints are protected")
	for bed in beds:
		for tree in Terrain.tree_rects():
			expect(not bed.intersects(tree),"tree canopies never cover complete planting cells")
		for hedge in Nursery.hedge_sprites():
			expect(not bed.intersects(hedge["rect"]),"the actual generated leaf clumps leave planting cells clear")
		for fence in Terrain.fence_segments():
			var edge := Rect2(Vector2(fence[0]).min(fence[1])-Vector2(8,32),(Vector2(fence[1])-Vector2(fence[0])).abs()+Vector2(26,44))
			expect(not bed.intersects(edge),"fence posts leave the complete planting cell clear: bed=%s fence=%s" % [bed,fence])
	var waterways: Array[PackedVector2Array] = Terrain.water_outlines()
	expect(waterways.size() == 1,"the nursery pond joins its stream and river")
	for water in waterways:
		expect(not Geometry2D.triangulate_polygon(water).is_empty(),"the combined shoreline triangulates")
		for point in water: expect(World.WORLD_RECT.grow(0.01).has_point(point),"water remains within the enlarged estate")
	for surface in Terrain.greenhouse_yard_polygons():
		expect(not Geometry2D.triangulate_polygon(surface).is_empty(),"the greenhouse upgrade apron is drawable")
		for bed in beds: expect(Geometry2D.intersect_polygons(rectangle(bed.grow(-0.01)),surface).is_empty(),"the upgrade apron contains no plantings")
	print("Large field landscape: ",checks," checks; ",failures," failures")
	quit(0 if failures == 0 else 1)
