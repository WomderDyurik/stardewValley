extends SceneTree

const Layout = preload("res://scripts/field_layout.gd")

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var plots: Array[Vector2] = Layout.battle_plots()
	var road: Array[Rect2] = Layout.road_bounds(true)
	_expect(plots.size() >= 18, "expanded battle field supplies at least eighteen planting beds")
	for row in range(5):
		var lowest: float = INF
		var highest: float = -INF
		for index in range(row * 4, mini(row * 4 + 4, plots.size())):
			lowest = minf(lowest, plots[index].y)
			highest = maxf(highest, plots[index].y)
		_expect(highest - lowest >= 4.0, "planting rows are gently staggered instead of perfectly horizontal")
	for index in range(plots.size()):
		var bounds: Rect2 = Layout.plot_bounds(index)
		_expect(Layout.BOARD_RECT.encloses(bounds), "complete plant footprint remains inside the board: %d" % index)
		_expect(bounds.encloses(Layout.bed_bounds(index)), "footprint includes the complete soil bed: %d" % index)
		_expect(bounds.encloses(Layout.sprite_bounds(index)), "footprint includes the complete plant sprite: %d" % index)
		_expect(bounds.encloses(Layout.badge_bounds(index)), "footprint includes the income badge: %d" % index)
		_expect(not bounds.intersects(Layout.HOUSE_RECT), "greenhouse never covers a planting bed: %d" % index)
		for segment in range(road.size()):
			_expect(not bounds.intersects(road[segment]), "plant/soil/badge keeps road clearance: bed %d segment %d" % [index, segment])
		for other in range(index + 1, plots.size()):
			_expect(not bounds.intersects(Layout.plot_bounds(other)), "complete planting footprints never overlap: %d/%d" % [index, other])

	var points: Array[Vector2] = Layout.battle_route()
	_expect(points.size() > 200, "road is a densely sampled shared movement curve")
	var diagonal_segments: int = 0
	for index in range(1, points.size()):
		var difference: Vector2 = points[index] - points[index - 1]
		_expect(difference.length() > 0.0, "route has no zero-length segments")
		_expect(difference.length() <= Layout.ROUTE_SAMPLE_SPACING + 0.02, "dense route leaves no visible corner jumps")
		if not is_zero_approx(difference.x) and not is_zero_approx(difference.y):
			diagonal_segments += 1
		if index > 1:
			var previous: Vector2 = points[index - 1] - points[index - 2]
			_expect(absf(previous.angle_to(difference)) < deg_to_rad(18.0), "neighboring route samples follow smooth bends")
		for plot_index in range(plots.size()):
			var distance: float = _segment_rect_distance(points[index - 1], points[index], Layout.plot_bounds(plot_index))
			_expect(distance >= Layout.ROAD_WIDTH / 2.0 + Layout.ROAD_CLEARANCE - 0.001, "real curved road keeps full planting clearance: segment %d bed %d" % [index, plot_index])
	_expect(diagonal_segments > 100, "meanders and fillets replace an entirely orthogonal route")
	var corridor_centers: Array[float] = [113.0, 246.0, 379.0]
	var minimum_x: Array[float] = [INF, INF, INF]
	var maximum_x: Array[float] = [-INF, -INF, -INF]
	for point in points:
		if point.y < 80.0 or point.y > 360.0:
			continue
		for corridor in range(corridor_centers.size()):
			if absf(point.x - corridor_centers[corridor]) < 16.0:
				minimum_x[corridor] = minf(minimum_x[corridor], point.x)
				maximum_x[corridor] = maxf(maximum_x[corridor], point.x)
	_expect(maximum_x[0] - minimum_x[0] >= 14.0, "first corridor visibly meanders rather than staying a straight column")
	_expect(maximum_x[1] - minimum_x[1] >= 18.0, "central corridor has a visible flowing silhouette")
	_expect(maximum_x[2] - minimum_x[2] >= 14.0, "last corridor visibly meanders rather than staying a straight column")
	# A circular road stamp of any permitted radius is contained by the same
	# reserved corridors used by the actual UI hitbox checks.
	for with_clearance in [false, true]:
		var envelopes: Array[Rect2] = Layout.road_bounds(with_clearance)
		var radius: float = Layout.ROAD_WIDTH / 2.0 + (Layout.ROAD_CLEARANCE if with_clearance else 0.0)
		for point in points:
			for angle_index in range(32):
				var angle: float = TAU * float(angle_index) / 32.0
				var edge: Vector2 = point + Vector2(cos(angle), sin(angle)) * radius
				_expect(_inside_any(edge, envelopes), "round road and its clearance stay inside reserved corridors")
	for bounds in Layout.road_bounds(false):
		_expect(Layout.BOARD_RECT.encloses(bounds), "full rendered road width stays inside the field")
	_expect(Layout.BOARD_RECT.encloses(Layout.HOUSE_RECT), "greenhouse is visible within field bounds")
	_expect(Layout.HOUSE_RECT.has_point(points[-1]), "pests finish at the greenhouse entrance")
	_expect(Layout.path_length() >= 1100.0, "larger planting area does not trivialize the route length")
	_expect(Layout.path_length() <= 1800.0, "portrait route remains short enough for prototype waves")

	# Geometry callers cannot accidentally mutate the shared layout.
	var original_first: Vector2 = plots[0]
	plots[0] = Vector2.ZERO
	_expect(Layout.battle_plots()[0] == original_first, "layout returns independent position arrays")
	_expect(Layout.plot_bounds(-1) == Rect2(), "invalid negative slot is safely rejected")
	_expect(Layout.sprite_bounds(plots.size()) == Rect2(), "invalid upper slot is safely rejected")
	print("Field layout: ", checks, " checks, ", failures, " failures; beds=", plots.size(), "; route=", Layout.path_length())
	quit(0 if failures == 0 else 1)


func _inside_any(point: Vector2, rectangles: Array[Rect2]) -> bool:
	for bounds in rectangles:
		if bounds.grow(0.001).has_point(point):
			return true
	return false


func _segment_rect_distance(start: Vector2, finish: Vector2, rectangle: Rect2) -> float:
	if rectangle.has_point(start) or rectangle.has_point(finish):
		return 0.0
	var corners: Array[Vector2] = [rectangle.position, Vector2(rectangle.end.x, rectangle.position.y), rectangle.end, Vector2(rectangle.position.x, rectangle.end.y)]
	var shortest: float = minf(start.distance_to(start.clamp(rectangle.position, rectangle.end)), finish.distance_to(finish.clamp(rectangle.position, rectangle.end)))
	for index in range(4):
		if Geometry2D.segment_intersects_segment(start, finish, corners[index], corners[(index + 1) % 4]) != null:
			return 0.0
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(corners[index], start, finish)
		shortest = minf(shortest, corners[index].distance_to(nearest))
	return shortest
