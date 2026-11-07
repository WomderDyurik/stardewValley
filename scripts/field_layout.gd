class_name FieldLayout
extends RefCounted

## Battle geometry in board-local coordinates. Visual footprints include the
## entire crop/weapon, its soil bed, and the income badge, not only its center.
const BOARD_SIZE: Vector2 = Vector2(492, 430)
const BOARD_RECT: Rect2 = Rect2(Vector2.ZERO, BOARD_SIZE)
const ROAD_WIDTH: float = 28.0
const ROAD_CLEARANCE: float = 6.0
const BED_SIZE: Vector2 = Vector2(66, 34)
const PLANT_BOUNDS_SIZE: Vector2 = Vector2(66, 62)
const SPRITE_SIZE: Vector2 = Vector2(62, 48)
const HOUSE_RECT: Rect2 = Rect2(407, 326, 76, 76)
const CORNER_RADIUS: float = 26.0
const ROUTE_SAMPLE_SPACING: float = 5.0
const EDGE_MEANDER: float = 12.0
const MIDDLE_MEANDER: float = 15.0
const ROW_OFFSETS: Array[Vector4] = [
	Vector4(-3, 4, -1, 2),
	Vector4(3, -2, 4, -4),
	Vector4(-1, 3, -4, 1),
	Vector4(4, -4, 2, -2),
	Vector4(-4, 1, 3, 0),
]


static func battle_route() -> Array[Vector2]:
	# Render and simulate this same sampled route. Fillets remove hard corners;
	# small, tangent-preserving meanders stay inside the reserved corridors.
	var skeleton: Array[Vector2] = _route_skeleton()
	var route: Array[Vector2] = [skeleton[0]]
	var cursor: Vector2 = skeleton[0]
	for index in range(1, skeleton.size() - 1):
		var corner: Vector2 = skeleton[index]
		var incoming: Vector2 = (corner - skeleton[index - 1]).normalized()
		var outgoing: Vector2 = (skeleton[index + 1] - corner).normalized()
		var radius: float = minf(CORNER_RADIUS, minf(corner.distance_to(skeleton[index - 1]), corner.distance_to(skeleton[index + 1])) * 0.5)
		var entry: Vector2 = corner - incoming * radius
		var exit: Vector2 = corner + outgoing * radius
		_append_meandering_line(route, cursor, entry)
		for step in range(1, 13):
			var weight: float = float(step) / 12.0
			var point: Vector2 = entry.lerp(corner, weight).lerp(corner.lerp(exit, weight), weight)
			_append_distinct(route, point)
		cursor = exit
	_append_meandering_line(route, cursor, skeleton[-1])
	return route


static func _route_skeleton() -> Array[Vector2]:
	return [
		Vector2(113, 16), Vector2(113, 414), Vector2(246, 414),
		Vector2(246, 16), Vector2(379, 16), Vector2(379, 414),
		Vector2(444, 414), Vector2(444, 398),
	]


static func _append_meandering_line(points: Array[Vector2], start: Vector2, finish: Vector2) -> void:
	var distance: float = start.distance_to(finish)
	var steps: int = maxi(1, ceili(distance / ROUTE_SAMPLE_SPACING))
	var vertical: bool = is_equal_approx(start.x, finish.x) and distance > 100.0
	var amplitude: float = MIDDLE_MEANDER if is_equal_approx(start.x, 246.0) else EDGE_MEANDER
	for step in range(1, steps + 1):
		var weight: float = float(step) / float(steps)
		var point: Vector2 = start.lerp(finish, weight)
		if vertical:
			# Zero value and derivative at both ends retain a smooth join to curves.
			var envelope: float = pow(sin(PI * weight), 2.0)
			point.x += sin(weight * TAU * 1.25 + start.x * 0.03) * envelope * amplitude
		_append_distinct(points, point)


static func _append_distinct(points: Array[Vector2], point: Vector2) -> void:
	if points.is_empty():
		points.append(point)
		return
	var start: Vector2 = points[-1]
	var distance: float = start.distance_to(point)
	if distance <= 0.000001:
		return
	# Meandering increases a nominal vertical step's actual length slightly.
	# Subdivide that actual displacement, preserving a strict sampling limit.
	var steps: int = maxi(1, ceili(distance / ROUTE_SAMPLE_SPACING))
	for step in range(1, steps + 1):
		points.append(start.lerp(point, float(step) / float(steps)))


static func battle_plots() -> Array[Vector2]:
	var plots: Array[Vector2] = []
	for row in range(5):
		for column in range(4):
			# Reserve the bottom-right plot for the permanent greenhouse.
			if row == 4 and column == 3:
				continue
			var y: float = 74.0 + row * 71.0 + ROW_OFFSETS[row][column]
			plots.append(Vector2([48.0, 178.0, 314.0, 444.0][column], y))
	return plots


static func plot_bounds(index: int) -> Rect2:
	var plots: Array[Vector2] = battle_plots()
	if index < 0 or index >= plots.size():
		return Rect2()
	return Rect2(plots[index] - PLANT_BOUNDS_SIZE / 2.0, PLANT_BOUNDS_SIZE)


static func bed_bounds(index: int) -> Rect2:
	var plots: Array[Vector2] = battle_plots()
	if index < 0 or index >= plots.size():
		return Rect2()
	return Rect2(plots[index] - BED_SIZE / 2.0, BED_SIZE)


static func sprite_bounds(index: int) -> Rect2:
	var plots: Array[Vector2] = battle_plots()
	if index < 0 or index >= plots.size():
		return Rect2()
	return Rect2(plots[index] + Vector2(-31, -30), SPRITE_SIZE)


static func badge_bounds(index: int) -> Rect2:
	var plots: Array[Vector2] = battle_plots()
	if index < 0 or index >= plots.size():
		return Rect2()
	return Rect2(plots[index] + Vector2(-22, 20), Vector2(44, 11))


static func road_bounds(with_clearance: bool = true) -> Array[Rect2]:
	# Conservative envelopes include the complete curved road, its round caps,
	# the meander amplitude, and optional clearance. Keep them independent of
	# sampling density so touch geometry never fragments into tiny rectangles.
	var points: Array[Vector2] = _route_skeleton()
	var rectangles: Array[Rect2] = []
	var margin: float = ROAD_WIDTH / 2.0 + (ROAD_CLEARANCE if with_clearance else 0.0)
	for index in range(1, points.size()):
		var start: Vector2 = points[index - 1]
		var end: Vector2 = points[index]
		var minimum: Vector2 = Vector2(minf(start.x, end.x), minf(start.y, end.y))
		var dimensions: Vector2 = (end - start).abs()
		var wiggle: float = 0.0
		if is_equal_approx(start.x, end.x) and dimensions.y > 100.0:
			wiggle = MIDDLE_MEANDER if is_equal_approx(start.x, 246.0) else EDGE_MEANDER
		var padding: Vector2 = Vector2(margin + wiggle, margin)
		rectangles.append(Rect2(minimum - padding, dimensions + padding * 2.0))
	return rectangles


static func path_length() -> float:
	var points: Array[Vector2] = battle_route()
	var length: float = 0.0
	for index in range(1, points.size()):
		length += points[index - 1].distance_to(points[index])
	return length
