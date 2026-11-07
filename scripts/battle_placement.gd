class_name BattlePlacement
extends RefCounted

## Preview and paid placement resolve the same regular cell, then test its
## complete plant body. Existing saved anchors remain in simulation space.
const Layout = preload("res://scripts/field_layout.gd")
const FOOTPRINT_SIZE := Vector2(48, 48)
const PLANT_GAP: float = 2.0
const VIEW_SCALE: float = 1.08
const GRID_STEP: float = 52.0
const GRID_ORIGIN := Vector2(48, 27)
const GRID_COUNT := Vector2i(9, 8)
static var _grid_centers: Array[Vector2] = []


static func grid_centers() -> Array[Vector2]:
	if _grid_centers.is_empty():
		for row in range(GRID_COUNT.y):
			for column in range(GRID_COUNT.x):
				_grid_centers.append(grid_center(Vector2i(column,row)))
	return _grid_centers.duplicate()


static func grid_cell(point: Vector2) -> Vector2i:
	if not point.is_finite(): return Vector2i(-1,-1)
	var local: Vector2 = (point-GRID_ORIGIN)/GRID_STEP
	return Vector2i(floori(local.x+0.5),floori(local.y+0.5))


static func grid_center(cell: Vector2i) -> Vector2:
	return GRID_ORIGIN+Vector2(cell)*GRID_STEP


static func snap(point: Vector2) -> Vector2:
	return grid_center(grid_cell(point)) if point.is_finite() else Vector2(INF,INF)


static func grid_bounds(point: Vector2) -> Rect2:
	return Rect2(snap(point)-Vector2.ONE*GRID_STEP/2.0,Vector2.ONE*GRID_STEP) if point.is_finite() else Rect2()


static func is_grid_center(point: Vector2) -> bool:
	if not point.is_finite(): return false
	var cell: Vector2i = grid_cell(point)
	return _inside_grid(cell) and point.is_equal_approx(grid_center(cell))


static func _inside_grid(cell: Vector2i) -> bool:
	return cell.x>=0 and cell.y>=0 and cell.x<GRID_COUNT.x and cell.y<GRID_COUNT.y


static func with_cell(result: Dictionary, point: Vector2) -> Dictionary:
	result["position"] = snap(point)
	result["cell"] = grid_cell(point)
	result["cell_bounds"] = grid_bounds(point)
	return result


static func footprint(point: Vector2) -> Rect2:
	return Rect2(point - FOOTPRINT_SIZE / 2.0, FOOTPRINT_SIZE)


static func greenhouse_bounds(path: Array[Vector2]) -> Rect2:
	if path.is_empty(): return Rect2()
	# Inverse of the upright 76x76 greenhouse drawn at the route's final point.
	# Its door is 60 screen pixels below the top, 38 pixels from either side.
	return Rect2(path[-1] + Vector2(-60, -38) / VIEW_SCALE, Vector2(76, 76) / VIEW_SCALE)


static func check(point: Vector2, path: Array[Vector2], occupied: Array[Vector2], house: Rect2 = Rect2()) -> Dictionary:
	if not point.is_finite() or not Layout.BOARD_RECT.has_point(point) or not _inside_grid(grid_cell(point)):
		return with_cell(invalid("outside", "Выберите клетку на поляне"),point)
	var result: Dictionary = check_exact(snap(point),path,occupied,house)
	return with_cell(result,point)


static func check_exact(point: Vector2, path: Array[Vector2], occupied: Array[Vector2], house: Rect2 = Rect2()) -> Dictionary:
	# Raw geometry remains available for legacy-anchor compatibility checks.
	# New player placements always enter through check() and its cell resolver.
	if not point.is_finite(): return invalid("outside", "Выберите клетку на поляне")
	var bounds: Rect2 = footprint(point)
	if not Layout.BOARD_RECT.encloses(bounds):
		return invalid("outside", "Растение должно целиком помещаться на поляне")
	var greenhouse: Rect2 = greenhouse_bounds(path) if not house.has_area() else house
	if greenhouse.has_area() and bounds.intersects(greenhouse.grow(2.0)):
		return invalid("greenhouse", "Оставьте вход в теплицу свободным")
	var road_clearance: float = Layout.ROAD_WIDTH / 2.0 + Layout.ROAD_CLEARANCE
	for index in range(1, path.size()):
		if segment_rect_distance(path[index-1], path[index], bounds) < road_clearance - 0.001:
			return invalid("road", "Эту клетку пересекает дорога")
	for other in occupied:
		if footprint(other).grow(PLANT_GAP).intersects(bounds):
			return invalid("occupied", "Эта клетка занята растением")
	return {"valid": true, "reason": "", "code": "ok"}


static func invalid(code: String, reason: String) -> Dictionary:
	return {"valid": false, "reason": reason, "code": code}


static func segment_rect_distance(first: Vector2, last: Vector2, rect: Rect2) -> float:
	if rect.has_point(first) or rect.has_point(last): return 0.0
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x,rect.position.y), rect.end, Vector2(rect.position.x,rect.end.y)]
	var shortest: float = minf(first.distance_to(first.clamp(rect.position,rect.end)), last.distance_to(last.clamp(rect.position,rect.end)))
	for index in range(4):
		if Geometry2D.segment_intersects_segment(first,last,corners[index],corners[(index+1)%4]) != null: return 0.0
		shortest = minf(shortest,corners[index].distance_to(Geometry2D.get_closest_point_to_segment(corners[index],first,last)))
	return shortest
