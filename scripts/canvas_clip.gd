class_name CanvasClip
extends RefCounted

## Clip the real stroke separately from its filled shape. Closing a clipped
## polygon would add false straight edges along the viewport boundary.
static func segment(first: Vector2, last: Vector2, bounds: Rect2) -> PackedVector2Array:
	var delta: Vector2 = last-first
	var low: float = 0.0
	var high: float = 1.0
	for axis in range(2):
		if absf(delta[axis]) < 0.000001:
			if first[axis] < bounds.position[axis] or first[axis] > bounds.end[axis]: return PackedVector2Array()
			continue
		var start: float = (bounds.position[axis]-first[axis])/delta[axis]
		var finish: float = (bounds.end[axis]-first[axis])/delta[axis]
		if start>finish:
			var swap: float = start
			start=finish
			finish=swap
		low=maxf(low,start)
		high=minf(high,finish)
		if low>high: return PackedVector2Array()
	return PackedVector2Array([first+delta*low,first+delta*high])


static func polyline(points: PackedVector2Array, bounds: Rect2, width: float = 1.0) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var current := PackedVector2Array()
	var inset: Rect2 = bounds.grow(-width/2.0)
	for index in range(1,points.size()):
		var part: PackedVector2Array = segment(points[index-1],points[index],inset)
		if part.is_empty():
			if current.size()>1: result.append(current)
			current=PackedVector2Array()
			continue
		if current.is_empty(): current.append(part[0])
		elif current[-1].distance_squared_to(part[0])>0.01:
			if current.size()>1: result.append(current)
			current=PackedVector2Array([part[0]])
		current.append(part[1])
	if current.size()>1: result.append(current)
	return result


static func circle_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(97):
		var angle: float = TAU*float(index)/96.0
		points.append(center+Vector2(cos(angle),sin(angle))*radius)
	return points


static func draw_circle(canvas: Node2D, center: Vector2, radius: float, bounds: Rect2, fill: Color, edge: Color, width: float = 1.0) -> void:
	var points: PackedVector2Array = circle_points(center,radius)
	var clip := PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)])
	for polygon in Geometry2D.intersect_polygons(points,clip):
		canvas.draw_colored_polygon(polygon,fill)
	for arc in polyline(points,bounds,width):
		canvas.draw_polyline(arc,edge,width,false)


static func draw_texture(canvas: Node2D, texture: Texture2D, target: Rect2, bounds: Rect2, tint: Color = Color.WHITE) -> void:
	var visible: Rect2 = target.intersection(bounds)
	if not visible.has_area() or texture == null: return
	var source := Rect2((visible.position-target.position)/target.size*texture.get_size(),visible.size/target.size*texture.get_size())
	canvas.draw_texture_rect_region(texture,visible,source,tint,false,true)


static func draw_rect(canvas: Node2D, target: Rect2, bounds: Rect2, color: Color) -> void:
	var visible: Rect2 = target.intersection(bounds)
	if visible.has_area(): canvas.draw_rect(visible,color)
