class_name BattleRoutes
extends RefCounted

## Broad loop pockets leave useful grass inside bends. These paths are used by
## new attempts; a saved attempt always keeps its own exact sampled path.
const SAMPLE_SPACING: float = 5.0
const BEND_RADIUS: float = 26.0


static func for_stage(stage: int = 1) -> Array[Vector2]:
	var portrait: Array[Vector2] = [
		Vector2(414,113), Vector2(55,113), Vector2(55,260),
		Vector2(230,260), Vector2(230,180), Vector2(370,180),
		Vector2(370,379), Vector2(55,379), Vector2(55,450),
		Vector2(120,450),
	]
	# New attempts visit recognisably different places. Stage two folds back
	# toward a mid-field nursery; stage three winds around the inner glasshouse.
	# Saved attempts always restore their own path instead of these skeletons.
	if stage == 2:
		portrait = [Vector2(16,113),Vector2(360,113),Vector2(360,204),
			Vector2(166,204),Vector2(166,328),Vector2(370,328),
			Vector2(370,400),Vector2(55,400),Vector2(55,320),Vector2(110,320)]
	elif stage >= 3:
		portrait = [Vector2(414,113),Vector2(55,113),Vector2(55,379),
			Vector2(370,379),Vector2(370,180),Vector2(200,180),
			Vector2(200,300),Vector2(280,300)]
	var skeleton: Array[Vector2] = []
	for point in portrait: skeleton.append(Vector2(point.y,430.0-point.x))
	var result: Array[Vector2] = [skeleton[0]]
	var cursor: Vector2 = skeleton[0]
	for index in range(1,skeleton.size()-1):
		var corner: Vector2 = skeleton[index]
		var radius: float = minf(BEND_RADIUS,minf(corner.distance_to(skeleton[index-1]),corner.distance_to(skeleton[index+1]))*0.5)
		var entry: Vector2 = corner+(skeleton[index-1]-corner).normalized()*radius
		var exit: Vector2 = corner+(skeleton[index+1]-corner).normalized()*radius
		_append_line(result,cursor,entry)
		for step in range(1,17):
			var t: float = float(step)/16.0
			_append(result,entry.lerp(corner,t).lerp(corner.lerp(exit,t),t))
		cursor = exit
	_append_line(result,cursor,skeleton[-1])
	return result


static func _append_line(result: Array[Vector2], first: Vector2, last: Vector2) -> void:
	var steps: int = maxi(1,ceili(first.distance_to(last)/SAMPLE_SPACING))
	for step in range(1,steps+1):
		_append(result,first.lerp(last,float(step)/float(steps)))


static func _append(result: Array[Vector2], point: Vector2) -> void:
	if result.is_empty() or result[-1].distance_to(point)>0.000001:
		result.append(point)
