extends SceneTree

## Acceptance geometry for the red-roof nursery and its dense planted rows.
const World = preload("res://scripts/garden_world.gd")
const Grid = preload("res://scripts/garden_grid.gd")
const Terrain = preload("res://scripts/garden_terrain.gd")
const Visuals = preload("res://scripts/plant_visuals.gd")
const NurseryCrops = preload("res://scripts/nursery_crop_art.gd")
const Nursery = preload("res://scripts/nursery_environment.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_check_nursery_front()
	_check_saved_row_clearance()
	_check_defense_milestones()
	_check_actual_crop_footprints()
	_check_hedge_clearance()
	print("Nursery reference geometry: ", checks, " checks; ", failures, " failures")
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


func _check_nursery_front() -> void:
	var barn: Rect2 = World.NURSERY_RECT
	expect(World.WORLD_RECT.encloses(barn), "the nursery barn remains fully inside the estate")
	expect(World.district("nursery")["bounds"].encloses(barn), "the nursery barn retains its own district")
	expect(World.building_hit_regions()["nursery"] == barn, "the complete nursery barn keeps its menu interaction")
	expect(barn.size.y > barn.size.x, "the reference nursery barn has a tall narrow silhouette")
	var field: Rect2 = Terrain.NURSERY_FLOOR
	expect(barn.end.x <= field.position.x and barn.position.y < field.position.y and barn.end.y > field.position.y, "the reference barn stands beside the field with its lower facade aligned to the upper crop rows")
	var approaches: Dictionary = Terrain.doorway_points()
	expect(approaches.has("nursery"), "the relocated nursery barn retains an authored entrance")
	if approaches.has("nursery"):
		var front := Vector2(barn.get_center().x, barn.end.y)
		expect(front.distance_to(approaches["nursery"]) <= 4.0, "the approach reaches the relocated nursery front")
		var connected: bool = false
		for polygon in Terrain.path_polygons():
			if Geometry2D.is_point_in_polygon(approaches["nursery"], polygon): connected = true
		expect(connected, "the actual drawn walking network contains the nursery entrance")


func _check_saved_row_clearance() -> void:
	expect(World.NURSERY_PLOT_CENTERS.size() == 12, "all twelve saved nursery planting identities remain available")
	var ground: Array[PackedVector2Array] = Terrain.nursery_ground_polygons()
	for surface in ground:
		expect(not Geometry2D.triangulate_polygon(surface).is_empty(), "every actual productive nursery surface triangulates")
	for slot in range(8):
		var expected_cell := Vector2i(11 + slot % 4, 4 + slot / 4)
		var cell: Rect2 = World.nursery_plot_rect(slot)
		expect(Grid.planting_cell("nursery", slot) == expected_cell, "the reference pass preserves the original paid nursery cell: " + str(slot))
		expect(cell == Grid.planting_rect("nursery", slot), "drawing and touch share the same saved nursery identity: " + str(slot))
		expect(covered_by(cell, ground), "the actual cultivated ground covers the full nursery cell: " + str(slot))
		for building in World.building_hit_regions().values(): expect(not cell.intersects(building), "the nursery plant is clear of usable buildings: " + str(slot))
		for prop in World.PROP_RECTS.values(): expect(not cell.intersects(prop), "farm props leave the complete nursery cell readable: " + str(slot))
		for tree in Terrain.tree_rects(): expect(not cell.intersects(tree), "tree canopies leave nursery rows clear: " + str(slot))
		for path in Terrain.path_polygons():
			expect(Geometry2D.intersect_polygons(rectangle_polygon(cell.grow(-0.01)), path).is_empty(), "actual walking ground never paints through the nursery plant: " + str(slot))


func _check_defense_milestones() -> void:
	# Art can gain dense foliage while all three actual weapon stages remain.
	for kind in ["nettle", "lavender"]:
		var stages: Array[Texture2D] = []
		for level in [1, 7, 15]:
			var texture: Texture2D = Visuals.defense_texture(kind, level)
			expect(texture != null, "the nursery defender retains its weapon texture: " + kind + ":" + str(level))
			expect(not stages.has(texture), "nursery weapon milestones keep distinct actual artwork: " + kind + ":" + str(level))
			stages.append(texture)
			var cell: Rect2 = World.nursery_plot_rect(0)
			expect(cell.encloses(Visuals.defense_sprite_rect(kind, level, cell)), "the defender weapon stays inside its paid nursery cell")


func _check_actual_crop_footprints() -> void:
	for slot in range(8):
		var cell: Rect2 = World.nursery_plot_rect(slot)
		var level_corner: Rect2 = NurseryCrops.reserved_level_rect(cell)
		for kind in ["nettle", "lavender", "pepper", "tomato", "marigold"]:
			var frames: Array[Rect2] = NurseryCrops.footprints(cell, kind)
			expect(not frames.is_empty(), "a planted nursery ID has real foliage or weapon footprints")
			for frame in frames:
				expect(cell.encloses(frame), "all dense foliage, legacy crops and weapons stay inside their own paid cell")
				expect(not frame.intersects(level_corner), "dense nursery artwork leaves the complete minimum-zoom level tag clear")
			for level in [1, 7, 15]:
				var weapon: Rect2 = Visuals.defense_sprite_rect(kind, level, NurseryCrops.weapon_bounds(cell, kind))
				if weapon.has_area():
					expect(cell.encloses(weapon) and not weapon.intersects(level_corner), "the actual staged weapon remains inside its own cell and clear of its level")


func _check_hedge_clearance() -> void:
	expect(not Geometry2D.triangulate_polygon(Terrain.nursery_courtyard_outline()).is_empty(), "the actual golden nursery courtyard triangulates")
	var hedges: Array[Dictionary] = Nursery.hedge_sprites()
	expect(not hedges.is_empty(), "the nursery habitat has actual surrounding leaf silhouettes")
	for hedge in hedges:
		var frame: Rect2 = hedge["rect"]
		expect(frame.has_area() and frame.position.is_finite() and frame.size.is_finite(), "each rendered hedge has a finite visible footprint")
		for area in ["home", "nursery", "pond"]:
			for slot in range(Grid.planting_cells(area).size()):
				expect(not frame.intersects(Grid.planting_rect(area, slot)), "the actual hedge silhouette never covers a saved planting: " + area + ":" + str(slot))
