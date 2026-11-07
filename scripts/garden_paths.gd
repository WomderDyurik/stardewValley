class_name GardenPaths
extends RefCounted
const Grid = preload("res://scripts/garden_grid.gd")

## Purposeful routes. The returned points are the actual densely sampled walk,
## shared by rendering, collision-clearance checks and the miniature map.
static var _routes: Array[Dictionary] = []
static var _polygons: Array[PackedVector2Array] = []
static var _permanent_polygons: Array[PackedVector2Array] = []


static func routes() -> Array[Dictionary]:
	if not _routes.is_empty(): return _routes
	var definitions: Array[Dictionary] = [
		{"id":"estate_lane","controls":[Vector2(1488,32),Vector2(1488,2848)],"width":64.0},
		{"id":"bridge_walk","controls":[Vector2(1488,2304),Vector2(3456,2304)],"width":48.0},
		{"id":"garden_front","controls":[Vector2(1488,432),Vector2(144,432)],"width":64.0},
		{"id":"garden_loop","controls":[Vector2(144,432),Vector2(144,1776),Vector2(1488,1776)],"width":40.0},
		{"id":"garden_middle","controls":[Vector2(816,432),Vector2(816,1776)],"width":40.0},
		{"id":"garden_cross","controls":[Vector2(144,1104),Vector2(1488,1104)],"width":40.0},
		{"id":"cottage_door","controls":[Vector2(360,432),Vector2(360,384)],"width":48.0},
		{"id":"nursery_door","controls":[Vector2(1488,480),Vector2(1776,480)],"width":32.0},
		{"id":"nursery_front","controls":[Vector2(1920,304),Vector2(3232,304)],"width":48.0},
		{"id":"nursery_west","controls":[Vector2(1776,480),Vector2(1776,1728),Vector2(3232,1728),Vector2(3232,304)],"width":48.0},
		{"id":"nursery_middle","controls":[Vector2(2544,304),Vector2(2544,1728)],"width":64.0},
		{"id":"nursery_cross","controls":[Vector2(1488,1008),Vector2(3232,1008)],"width":64.0},
		{"id":"greenhouse_door","controls":[Vector2(1488,2544),Vector2(432,2544),Vector2(432,2496)],"width":48.0},
		{"id":"equipment_walk","controls":[Vector2(624,2544),Vector2(624,2592)],"width":40.0},
		{"id":"helper_service","controls":[Vector2(816,2544),Vector2(816,2432)],"width":48.0},
		{"id":"pond_bench","controls":[Vector2(2544,1728),Vector2(2544,2136),Vector2(2640,2136),Vector2(2640,2112)],"width":40.0},
	]
	for definition in definitions:
		var controls := PackedVector2Array(definition["controls"])
		_routes.append({"id":definition["id"],"points":rounded_line(controls,12.0),"width":definition["width"]})
	return _routes


static func polygons(include_service: bool = true) -> Array[PackedVector2Array]:
	if not _polygons.is_empty(): return _polygons if include_service else _permanent_polygons
	for route in routes():
		var pieces: Array[PackedVector2Array] = Geometry2D.offset_polyline(route["points"],float(route["width"])/2.0,Geometry2D.JOIN_ROUND,Geometry2D.END_BUTT)
		_polygons.append_array(pieces)
		if route["id"] != "helper_service": _permanent_polygons.append_array(pieces)
	# The lane reaches both estate edges; two pixels of overlap keep the exit
	# faces connected under polygon clipping as well as rasterization.
	_polygons.append(PackedVector2Array([Vector2(1456,0),Vector2(1520,0),Vector2(1520,34),Vector2(1456,34)]))
	_polygons.append(PackedVector2Array([Vector2(1456,2846),Vector2(1520,2846),Vector2(1520,2880),Vector2(1456,2880)]))
	_permanent_polygons.append(_polygons[-2])
	_permanent_polygons.append(_polygons[-1])
	return _polygons if include_service else _permanent_polygons


static func doorway_points() -> Dictionary:
	return {"cottage":Vector2(360,384),"nursery":Vector2(1776,480),"greenhouse":Vector2(432,2496),"pond_bench":Vector2(2640,2112),"well":Vector2(624,2592)}


static func rounded_line(controls: PackedVector2Array, radius: float) -> PackedVector2Array:
	var result := PackedVector2Array([controls[0]])
	for index in range(1,controls.size()-1):
		var previous: Vector2 = controls[index-1]
		var corner: Vector2 = controls[index]
		var following: Vector2 = controls[index+1]
		var amount: float = minf(radius,minf(corner.distance_to(previous),corner.distance_to(following))*0.4)
		var entry: Vector2 = corner.move_toward(previous,amount)
		var exit: Vector2 = corner.move_toward(following,amount)
		_append_line(result,entry)
		var steps: int = maxi(4,ceili((entry.distance_to(corner)+corner.distance_to(exit))/6.0))
		for step in range(1,steps+1):
			var t: float = float(step)/steps
			result.append(entry.lerp(corner,t).lerp(corner.lerp(exit,t),t))
	_append_line(result,controls[-1])
	return result


static func _append_line(points: PackedVector2Array, last: Vector2) -> void:
	var first: Vector2 = points[-1]
	var steps: int = maxi(1,ceili(first.distance_to(last)/6.0))
	for step in range(1,steps+1):
		var at: Vector2 = first.lerp(last,float(step)/steps)
		if at.distance_squared_to(points[-1]) > 0.001: points.append(at)
