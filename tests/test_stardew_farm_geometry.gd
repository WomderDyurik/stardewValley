extends SceneTree

## Rendering geometry acceptance for the farmhouse reference pass.
const World = preload("res://scripts/garden_world.gd")
const Grid = preload("res://scripts/garden_grid.gd")
const Terrain = preload("res://scripts/garden_terrain.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_check_farmhouse()
	_check_drawn_courtyard_surfaces()
	_check_crop_and_equipment_clearance()
	print("Stardew farm geometry: ", checks, " checks; ", failures, " failures")
	quit(0 if failures == 0 else 1)


func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func rectangle_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


func covered_by(rect: Rect2, surfaces: Array[PackedVector2Array]) -> bool:
	var remainder: Array[PackedVector2Array] = [rectangle_polygon(rect.grow(-0.01))]
	for surface in surfaces:
		var next: Array[PackedVector2Array] = []
		for piece in remainder: next.append_array(Geometry2D.clip_polygons(piece, surface))
		remainder = next
	return remainder.is_empty()


func _check_farmhouse() -> void:
	expect(World.COTTAGE_RECT.size.x > World.COTTAGE_RECT.size.y, "the reference farmhouse has a wide facade")
	expect(World.building_hit_regions()["collect"] == World.COTTAGE_RECT, "the full new farmhouse retains its collect interaction")
	expect(World.WORLD_RECT.encloses(World.COTTAGE_RECT), "the wider farmhouse remains within the saved world")
	var approaches: Dictionary = Terrain.doorway_points()
	expect(approaches.has("cottage"), "the new farmhouse retains a real entrance approach")
	if approaches.has("cottage"):
		var front := Vector2(World.COTTAGE_RECT.get_center().x, World.COTTAGE_RECT.end.y)
		expect(front.distance_to(approaches["cottage"]) <= 4.0, "the path reaches the actual relocated farmhouse front")
		var reaches: bool = false
		for polygon in Terrain.path_polygons():
			if Geometry2D.is_point_in_polygon(approaches["cottage"], polygon): reaches = true
		expect(reaches, "the drawn paving contains the farmhouse entrance")


func _check_drawn_courtyard_surfaces() -> void:
	# These are the actual draw-time surfaces, including narrow turf strips.
	# Cultivated-bed tests alone miss a self-crossing ornamental yard polygon.
	var surfaces: Dictionary = Terrain.farm_courtyard_polygons()
	expect(surfaces.has("earth") and not surfaces["earth"].is_empty(), "the farmhouse has actual authored walking ground")
	for material in surfaces:
		for index in range(surfaces[material].size()):
			var polygon: PackedVector2Array = surfaces[material][index]
			var label: String = str(material) + ":" + str(index)
			expect(polygon.size() >= 3, "the drawn courtyard surface has a complete outline: " + label)
			expect(not Geometry2D.triangulate_polygon(polygon).is_empty(), "the actual drawn courtyard polygon triangulates: " + label)
			for point in polygon: expect(point.is_finite(), "the drawn courtyard has finite vertices: " + label)


func _check_crop_and_equipment_clearance() -> void:
	expect(World.PLOT_CENTERS.size() == 24 and World.NURSERY_PLOT_CENTERS.size() == 12 and World.POND_PLOT_CENTERS.size() == 6, "the reference pass preserves every saved planting identity")
	var surfaces: Array[PackedVector2Array] = Terrain.garden_courtyard_polygons()
	var paths: Array[PackedVector2Array] = Terrain.path_polygons()
	var equipment: Array[Rect2] = []
	for id in ["irrigation", "compost", "harvest_crate"]:
		var footprint: Rect2 = Grid.helper_rect(id)
		expect(footprint.has_area() and World.WORLD_RECT.encloses(footprint), "equipment retains a complete world cell: " + id)
		expect(not footprint.intersects(World.COTTAGE_RECT), "the wider farmhouse leaves equipment clear: " + id)
		for existing in equipment: expect(not footprint.intersects(existing), "equipment cells remain distinct: " + id)
		for path in paths:
			expect(Geometry2D.intersect_polygons(rectangle_polygon(footprint.grow(-0.01)), path).is_empty(), "the painted path leaves the equipment cell clear: " + id)
		equipment.append(footprint)
	for index in range(8):
		var plot: Rect2 = World.plot_rect(index)
		var expected_cell := Vector2i(2 + index % 4, 5 + index / 4)
		expect(Grid.planting_cell("home", index) == expected_cell, "the stable garden slot occupies its new row below the porch: " + str(index))
		expect(plot == Grid.planting_rect("home", index), "drawing and touch use the same relocated cell: " + str(index))
		expect(covered_by(plot, surfaces), "the actual cultivated surface covers the entire relocated planting: " + str(index))
		expect(World.planting_floor(index).encloses(plot), "the declared garden floor includes the complete relocated planting: " + str(index))
		expect(not plot.intersects(World.COTTAGE_RECT), "the porch does not cover the planting: " + str(index))
		for other in range(index): expect(not plot.intersects(World.plot_rect(other)), "relocated planting cells never overlap")
		for footprint in equipment: expect(not plot.intersects(footprint), "equipment never occupies a saved planting cell: " + str(index))
		for path in paths:
			expect(Geometry2D.intersect_polygons(rectangle_polygon(plot.grow(-0.01)), path).is_empty(), "the actual painted path never cuts into the planting: " + str(index))
		for tree in Terrain.tree_rects(): expect(not plot.intersects(tree), "tree artwork leaves the planting readable: " + str(index))
