extends SceneTree

## Visual boundaries must preserve the playable world and connected approaches.
const Terrain = preload("res://scripts/garden_terrain.gd")
const World = preload("res://scripts/garden_world.gd")
const Grid = preload("res://scripts/garden_grid.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_expect(World.PLOT_CENTERS.size() == 96 and World.NURSERY_PLOT_CENTERS.size() == 96 and World.POND_PLOT_CENTERS.size() == 6,"the landscape renders two full ninety-six-cell fields and six aquatic cells")
	_expect(Terrain.GARDEN_FLOOR == World.GARDEN_FLOOR and Terrain.NURSERY_FLOOR == World.NURSERY_FLOOR,"rendered field bounds agree with the shared interaction geometry")
	for index in range(World.PLOT_CENTERS.size()):
		_expect(Terrain.planting_floor(index).encloses(World.plot_rect(index)), "every income crop sits on the enlarged first district field")
		for wall in Terrain.stone_segments():
			_expect(not wall.intersects(World.plot_visual_rect(index)), "stone walls leave each complete crop and touch footprint clear")
	for index in range(World.NURSERY_PLOT_CENTERS.size()):
		var visual: Rect2 = World.nursery_plot_rect(index)
		_expect(World.WORLD_RECT.encloses(visual), "every defender bed remains in the estate")
		var floor_rect: Rect2 = Terrain.NURSERY_FLOOR
		_expect(floor_rect.encloses(visual), "each complete defense bed remains on its own courtyard ground")
		for wall in Terrain.stone_segments():
			_expect(not wall.intersects(visual), "stone walls leave complete defender touch and sprite footprints clear")
		for path in Terrain.path_rects():
			_expect(not path.intersects(visual), "district approach %s never crosses defender planting %d" % [path, index])
	for wall in Terrain.stone_segments():
		_expect(World.WORLD_RECT.encloses(wall), "original and expanded stone walls stay inside the estate")
	_expect(World.expansion_regions().is_empty(),"retired regions supply no active discovery surfaces")
	for region in World.districts():
		var has_approach: bool = false
		var district_bounds: Rect2 = region["bounds"]
		for route in Terrain.path_routes():
			var points: PackedVector2Array = route["points"]
			if district_bounds.has_point(points[-1]): has_approach = true
		_expect(has_approach,"each active district has a real connected approach ending inside its place")
	for path in Terrain.path_rects():
		_expect(World.WORLD_RECT.encloses(path), "all connecting paths stay in the estate")
		for index in range(World.PLOT_CENTERS.size()):
			_expect(not path.intersects(World.plot_visual_rect(index)), "connecting paths do not cross the cultivated plots")
		for wall in Terrain.stone_segments():
			_expect(not path.intersects(wall), "stone walls leave the connecting routes open")
	# The reference refresh replaces stone rooms with live trees and thin wood.
	# Protect the whole productive silhouette, not only the soil rectangle.
	for area in ["home","nursery","pond"]:
		var count: int = World.PLOT_CENTERS.size() if area == "home" else World.NURSERY_PLOT_CENTERS.size() if area == "nursery" else World.POND_PLOT_CENTERS.size()
		for index in range(count):
			var visual: Rect2 = World.plot_visual_rect(index) if area == "home" else World.nursery_plot_rect(index) if area == "nursery" else World.pond_plot_rect(index)
			for tree in Terrain.tree_rects():
				_expect(not visual.intersects(tree), "tree canopy never covers a complete productive plant: %s:%d" % [area,index])
			for segment in Terrain.fence_segments():
				var edge: Rect2 = Rect2(Vector2(segment[0]).min(segment[1])-Vector2(4,24),(Vector2(segment[1])-Vector2(segment[0])).abs()+Vector2(52,56))
				_expect(not visual.intersects(edge), "wooden fence leaves the full planting and its level visible: %s:%d" % [area,index])
	_check_critic_geometry()
	_check_artist_geometry()
	var pond: PackedVector2Array = Terrain.pond_outline()
	_expect(not Geometry2D.triangulate_polygon(pond).is_empty(), "stepped shoreline forms a valid water surface")
	for index in range(pond.size()):
		var next: Vector2 = pond[(index + 1) % pond.size()]
		_expect(pond[index].x == next.x or pond[index].y == next.y, "shoreline follows the same orthogonal pixel grid as the map")
		_expect(World.WORLD_RECT.has_point(pond[index]), "water remains inside the estate")
	_expect(Geometry2D.is_point_in_polygon(World.POND_RECT.get_center(), pond), "pond district focus actually shows water")
	for index in range(World.POND_PLOT_CENTERS.size()):
		var visual: Rect2 = World.pond_plot_rect(index)
		for at in [visual.position, Vector2(visual.end.x, visual.position.y), visual.end, Vector2(visual.position.x, visual.end.y), visual.get_center()]:
			_expect(Geometry2D.is_point_in_polygon(at, pond), "every aquatic sprite and tap footprint remains fully inside water")
		for path in Terrain.path_rects():
			_expect(not path.intersects(visual), "aquatic plots remain off the walking routes")
	for style in ["vegetable", "glasshouse", "nursery"]:
		var bed := Rect2(100, 100, 122, 64)
		var outline: PackedVector2Array = Terrain._bed_outline(bed)
		_expect(not Geometry2D.triangulate_polygon(outline).is_empty(), "a tile-shaped bed outline remains a valid cultivated surface")
		for at in outline:
			_expect(bed.grow(0.01).has_point(at), "soil edge stays inside its interaction footprint")
	print("Garden terrain: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])


func _check_critic_geometry() -> void:
	var paths: Array[PackedVector2Array] = Terrain.path_polygons()
	_expect(not paths.is_empty(),"the narrower approaches still have real drawable ground")
	for polygon in paths:
		_expect(not Geometry2D.triangulate_polygon(polygon).is_empty(),"every drawn path has a valid continuous surface")
		for point in polygon:
			_expect(World.WORLD_RECT.grow(0.01).has_point(point),"actual path edges stay inside the estate")
		for area in ["home","nursery","pond"]:
			var count: int = World.PLOT_CENTERS.size() if area == "home" else World.NURSERY_PLOT_CENTERS.size() if area == "nursery" else World.POND_PLOT_CENTERS.size()
			for index in range(count):
				var visual: Rect2 = World.plot_visual_rect(index) if area == "home" else World.nursery_plot_rect(index) if area == "nursery" else World.pond_plot_rect(index)
				_expect(Geometry2D.intersect_polygons(polygon,_rect_polygon(visual)).is_empty(),"actual painted walking surface leaves the complete planting clear: %s:%d" % [area,index])
	# Every branch joins the common walk, so narrowing the old cross never
	# leaves an isolated decorative strip masquerading as an approach.
	var connected: Dictionary = {0:true}
	var changed: bool = true
	while changed:
		changed = false
		for index in range(paths.size()):
			if connected.has(index): continue
			for reached in connected.keys():
				if not Geometry2D.intersect_polygons(paths[index],paths[reached]).is_empty():
					connected[index] = true
					changed = true
					break
	_expect(connected.size() == paths.size(),"every visible district approach is connected to the common walking network")
	var water: Array[PackedVector2Array] = Terrain.water_outlines()
	_expect(water.size() == 1,"pond, natural outlet and river share one continuous shoreline rather than detached rectangular patches")
	for outline in water:
		_expect(not Geometry2D.triangulate_polygon(outline).is_empty(),"the combined water has a valid drawable surface")
		for point in outline:
			_expect(World.WORLD_RECT.grow(0.01).has_point(point),"the combined shoreline stays inside the estate")
	if water.size() == 1:
		for source in [Terrain.pond_outline(),Terrain.pond_outlet_outline(),Terrain.river_outline()]:
			for point in source:
				_expect(Geometry2D.is_point_in_polygon(point,water[0]),"the common water contains the actual pond, outlet and river without hidden clipping gaps")
	_expect(World.WORLD_RECT.encloses(Terrain.POND_BENCH_RECT),"the relocated pond bench remains in the actual garden")
	for tree in Terrain.tree_rects():
		_expect(not tree.intersects(Terrain.POND_BENCH_RECT),"the pond bench no longer collides with a tree trunk or canopy")
	for index in range(World.POND_PLOT_CENTERS.size()):
		_expect(not World.pond_plot_rect(index).intersects(Terrain.POND_BENCH_RECT),"the bank furniture never covers an aquatic planting target")
	for id in ["berry","far_garden","sun_meadow"]:
		_expect(Terrain.district_ground_spec(id).is_empty(),"retired region owns no cultivated material: " + id)
		_expect(Terrain.district_ground_polygons(id).is_empty(),"retired region paints no ground polygons: " + id)
	var doors: Dictionary = Terrain.doorway_points()
	_expect(not doors.has("berry_bench"),"the removed berry bench has no active approach")
	for route in Terrain.path_routes():
		_expect(route["id"] not in ["berry_bench","terrace_walk","sunny_rows"],"remaining routes never lead to retired regions")

func _covered_by_surfaces(rect: Rect2, surfaces: Array[PackedVector2Array]) -> bool:
	# Checking only four corners misses a notch cutting through a full soil bed.
	# Subtract the actual painted surfaces instead of trusting bounding metadata.
	var remaining: Array[PackedVector2Array] = [_rect_polygon(rect.grow(-0.01))]
	for surface in surfaces:
		var next: Array[PackedVector2Array] = []
		for fragment in remaining:
			next.append_array(Geometry2D.clip_polygons(fragment,surface))
		remaining = next
	return remaining.is_empty()


func _check_artist_geometry() -> void:
	var courtyards: Array[PackedVector2Array] = Terrain.garden_courtyard_polygons()
	_expect(courtyards.size() == 1,"the ninety-six garden cells share one connected cultivated field")
	_expect(Terrain.greenhouse_ground_polygons().is_empty() and Terrain.GREENHOUSE_FLOOR == Rect2(),"the greenhouse upgrade yard has no cultivated planting ground")
	var active_surfaces: Array = [
		["garden","home",0,96,courtyards],
		["nursery","nursery",0,96,Terrain.nursery_ground_polygons()],
	]
	for entry in active_surfaces:
		var surfaces: Array[PackedVector2Array] = entry[4]
		_expect(not surfaces.is_empty(),"each active crop place has actual painted ground: " + entry[0])
		for surface in surfaces:
			_expect(not Geometry2D.triangulate_polygon(surface).is_empty(),"the cultivated clearing has a valid drawable surface: " + entry[0])
			for point in surface:
				_expect(World.WORLD_RECT.grow(0.01).has_point(point),"the cultivated clearing stays inside the estate: " + entry[0])
		for slot in range(entry[2],entry[2]+entry[3]):
			var cell: Rect2 = World.plot_rect(slot) if entry[1] == "home" else World.nursery_plot_rect(slot)
			_expect(cell.has_area() and _covered_by_surfaces(cell,surfaces),"actual ground covers the complete active cell: %s:%d" % [entry[0],slot])
	_expect(_covered_by_surfaces(World.GARDEN_FLOOR,courtyards),"the actual first field surface covers all twelve columns and eight rows")
	_expect(_covered_by_surfaces(World.NURSERY_FLOOR,Terrain.nursery_ground_polygons()),"the actual second field surface covers all twelve columns and eight rows")
	var upgrade_yard: Array[PackedVector2Array] = Terrain.greenhouse_yard_polygons()
	_expect(not upgrade_yard.is_empty(),"the greenhouse still has a real equipment apron")
	for surface in upgrade_yard:
		_expect(not Geometry2D.triangulate_polygon(surface).is_empty(),"the upgrade apron remains a valid drawable surface")
		for point in surface:
			_expect(World.district("greenhouse")["bounds"].grow(0.01).has_point(point),"the equipment apron stays in the third district")
	var door_targets: Dictionary = Terrain.doorway_points()
	var destinations: Dictionary = {"cottage":World.COTTAGE_RECT,"nursery":World.NURSERY_RECT,"greenhouse":World.GREENHOUSE_RECT,"pond_bench":Terrain.POND_BENCH_RECT}
	var paths: Array[PackedVector2Array] = Terrain.path_polygons()
	for name in destinations:
		_expect(door_targets.has(name),"each usable building or resting place has an authored front approach: " + name)
		if not door_targets.has(name): continue
		var destination: Rect2 = destinations[name]
		var front := Vector2(destination.get_center().x,destination.end.y)
		var target: Vector2 = door_targets[name]
		_expect(target.distance_to(front) <= 4.0,"the approach reaches the real front of its building or bench: " + name)
		var on_connected_walk: bool = false
		for path in paths:
			if Geometry2D.is_point_in_polygon(target,path): on_connected_walk = true
		_expect(on_connected_walk,"the real doorway or bench front touches the connected painted walking network: " + name)
	var estate_lane: Dictionary = {}
	for route in Terrain.path_routes():
		if route["id"] == "estate_lane": estate_lane = route
	_expect(not estate_lane.is_empty(),"the connected route network retains the north-south estate lane")
	if not estate_lane.is_empty():
		var lane_points: PackedVector2Array = estate_lane["points"]
		var lane_width: float = estate_lane["width"]
		for exit_strip in [Rect2(lane_points[0].x-lane_width/2.0,0,lane_width,1),Rect2(lane_points[-1].x-lane_width/2.0,World.WORLD_SIZE.y-1,lane_width,1)]:
			_expect(_covered_by_surfaces(exit_strip,paths),"the estate lane has a full-width exit at the world boundary instead of a rounded interior stump")
