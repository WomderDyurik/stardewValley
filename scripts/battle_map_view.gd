class_name BattleMapView
extends RefCounted

## Presentation only: the saved route, ranges and slot identities stay in their
## original simulation coordinates. Rotate the map, never the plant sprites.
const Layout = preload("res://scripts/field_layout.gd")
const Placement = preload("res://scripts/battle_placement.gd")
const BOARD := Rect2(24, 140, 492, 598)
const BOARD_RECT := Rect2(Vector2.ZERO, BOARD.size)
const SCALE: float = Placement.VIEW_SCALE
const OFFSET := Vector2(14, 29)
const FOOTPRINT: Vector2 = Placement.FOOTPRINT_SIZE
static var _route_cache: Array[Vector2] = []


static func local_point(point: Vector2) -> Vector2:
	return Vector2(Layout.BOARD_SIZE.y - point.y, point.x) * SCALE + OFFSET


static func screen_point(point: Vector2) -> Vector2:
	return BOARD.position + local_point(point)


static func project_route(points: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point in points: result.append(local_point(point))
	return result


static func footprint_at(point: Vector2) -> Rect2:
	return Rect2(local_point(point)-FOOTPRINT*SCALE/2.0,FOOTPRINT*SCALE)


static func bed_at(point: Vector2) -> Rect2:
	return Rect2(local_point(point)+Vector2(-31,-17)*SCALE,Vector2(62,34)*SCALE)


static func sprite_at(point: Vector2) -> Rect2:
	return Rect2(local_point(point)+Vector2(-22,-23)*SCALE,Vector2(44,44)*SCALE)


static func cell_at(point: Vector2) -> Rect2:
	var size: Vector2 = Vector2.ONE*Placement.GRID_STEP*SCALE
	return Rect2(local_point(point)-size/2.0,size)


static func placement_notice(cell: Rect2) -> Rect2:
	var size := Vector2(minf(300,BOARD.size.x-16),54)
	var x: float = clampf(cell.get_center().x-size.x/2.0,BOARD.position.x+8,BOARD.end.x-size.x-8)
	var y: float = cell.position.y-size.y-8
	if y<BOARD.position.y+8: y=cell.end.y+8
	y=clampf(y,BOARD.position.y+8,BOARD.end.y-size.y-8)
	return Rect2(Vector2(x,y).round(),size)


static func badge_at(point: Vector2) -> Rect2:
	return Rect2(cell_at(point).end-Vector2(19,15),Vector2(18,14))


static func house_for_route(points: Array[Vector2]) -> Rect2:
	if points.is_empty(): return Rect2()
	return Rect2(local_point(points[-1])+Vector2(-38,-60),Vector2(76,76))


static func simulation_point(screen: Vector2) -> Vector2:
	var local: Vector2 = (screen - BOARD.position - OFFSET) / SCALE
	return Vector2(local.y, Layout.BOARD_SIZE.y - local.x)


static func route() -> Array[Vector2]:
	if _route_cache.is_empty():
		for point in Layout.battle_route():
			_route_cache.append(local_point(point))
	return _route_cache.duplicate()


static func plot_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point in Layout.battle_plots():
		result.append(local_point(point))
	return result


static func plot_bounds(index: int) -> Rect2:
	var plots: Array[Vector2] = plot_positions()
	if index < 0 or index >= plots.size(): return Rect2()
	return Rect2(plots[index] - FOOTPRINT * SCALE / 2.0, FOOTPRINT * SCALE)


static func bed_bounds(index: int) -> Rect2:
	return _anchored_rect(index, Vector2(-31, -17), Vector2(62, 34))


static func sprite_bounds(index: int) -> Rect2:
	return _anchored_rect(index, Vector2(-29, -30), Vector2(58, 48))


static func badge_bounds(index: int) -> Rect2:
	var footprint: Rect2 = plot_bounds(index)
	if not footprint.has_area(): return Rect2()
	return Rect2(footprint.end - Vector2(26, 20), Vector2(26, 20))


static func house_rect() -> Rect2:
	# The greenhouse door meets the unchanged last route point. Its artwork is
	# upright, like the defenders, rather than being rotated with the world.
	var points: Array[Vector2] = route()
	return Rect2(points[-1] + Vector2(-38, -60), Vector2(76, 76))


static func road_bounds(with_clearance: bool = true) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for original in Layout.road_bounds(with_clearance):
		var first: Vector2 = local_point(original.position)
		var last: Vector2 = local_point(original.end)
		result.append(Rect2(first.min(last), (last - first).abs()))
	return result


static func _anchored_rect(index: int, offset: Vector2, size: Vector2) -> Rect2:
	var plots: Array[Vector2] = plot_positions()
	if index < 0 or index >= plots.size(): return Rect2()
	return Rect2(plots[index] + offset * SCALE, size * SCALE)
