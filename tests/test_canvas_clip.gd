extends SceneTree

## Clip the true circular stroke; a clipped fill must not invent boundary lines.
const Clip = preload("res://scripts/canvas_clip.gd")
var checks: int = 0
var failures: int = 0


func expect(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(reason)


func _initialize() -> void:
	var bounds := Rect2(0,0,100,100)
	for example in [
		[Vector2(-20,50),Vector2(120,50),Vector2(0,50),Vector2(100,50)],
		[Vector2(50,120),Vector2(50,-20),Vector2(50,100),Vector2(50,0)],
		[Vector2(-50,-50),Vector2(150,150),Vector2(0,0),Vector2(100,100)],
		[Vector2(25,30),Vector2(60,80),Vector2(25,30),Vector2(60,80)],
	]:
		var result: PackedVector2Array = Clip.segment(example[0],example[1],bounds)
		expect(result.size() == 2,"a crossing or interior segment has two real endpoints")
		if result.size() == 2:
			expect(result[0].distance_to(example[2]) < 0.001 and result[1].distance_to(example[3]) < 0.001,"clipping retains the original direction and exact visible endpoints")
	expect(Clip.segment(Vector2(-10,-20),Vector2(120,-20),bounds).is_empty(),"a wholly invisible segment cannot leave a boundary stroke")
	for center in [Vector2(94,50),Vector2(6,50),Vector2(50,6),Vector2(50,94),Vector2(94,94)]:
		var radius: float = 60.0
		var arcs: Array[PackedVector2Array] = Clip.polyline(Clip.circle_points(center,radius),bounds,2.0)
		expect(not arcs.is_empty(),"a partially visible circle retains its actual curved arcs")
		for arc in arcs:
			for point in arc:
				expect(bounds.grow(-0.999).has_point(point),"the complete two-pixel stroke fits inside the clipping viewport")
			for index in range(1,arc.size()):
				var midpoint: Vector2 = (arc[index-1]+arc[index])/2.0
				expect(absf(midpoint.distance_to(center)-radius) < 0.1,"a visible range edge follows the real circle instead of closing across the clipping boundary")
	print("Canvas clipping: ",checks," checks; ",failures," failures")
	quit(0 if failures == 0 else 1)
