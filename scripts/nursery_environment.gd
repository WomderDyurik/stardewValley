class_name NurseryEnvironment
extends RefCounted

## Original pixel rail fences and wild hedges for the seed nursery. These
## leaves are the surrounding habitat, never decorative productive crops.
const Grid = preload("res://scripts/garden_grid.gd")
const Paths = preload("res://scripts/garden_paths.gd")
const OUTLINE := Color("4b2b16")
const SHADOW := Color("654021")
const WOOD := Color("895728")
const LIGHT := Color("ad7938")
static var _hedge_texture: Texture2D
static var _hedges: Array[Dictionary] = []


static func fence_segments() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	# Short rails frame the crop squares; open crosswalks connect all four.
	# Posts and rails sit beside the sidewalk, outside its full painted width.
	for line in [[1920,368,2464,368],[2624,368,3168,368],
		[1856,608,1856,848],[1856,1216,1856,1456],
		[1856,848,1888,848],[1856,1456,1888,1456],
		[3192,432,3192,912],[3192,1104,3192,1584],
		[1920,1680,2464,1680],[2624,1680,3168,1680]]:
		result.append(PackedVector2Array([Vector2(line[0],line[1]),Vector2(line[2],line[3])]))
	return result


static func draw_fence(canvas: Node2D, first: Vector2, last: Vector2, visible: Rect2) -> void:
	var vertical: bool = first.x == last.x
	var length: float = first.distance_to(last)
	var bounds := Rect2(first.min(last)-Vector2(12,34),(last-first).abs()+Vector2(26,48))
	if not bounds.intersects(visible): return
	if vertical:
		canvas.draw_rect(Rect2(first+Vector2(-6,-10),Vector2(12,length+12)),OUTLINE)
		canvas.draw_rect(Rect2(first+Vector2(-4,-10),Vector2(7,length+10)),WOOD)
		canvas.draw_rect(Rect2(first+Vector2(-4,-10),Vector2(2,length+10)),LIGHT)
	else:
		for y in [-21,-7]:
			canvas.draw_rect(Rect2(first+Vector2(0,y),Vector2(length,8)),OUTLINE)
			canvas.draw_rect(Rect2(first+Vector2(0,y+2),Vector2(length,4)),WOOD)
			canvas.draw_rect(Rect2(first+Vector2(0,y+2),Vector2(length,1)),LIGHT)
	var count: int = ceili(length/48.0)
	for step in range(count+1):
		var at: Vector2 = first+(Vector2(0,minf(step*48,length)) if vertical else Vector2(minf(step*48,length),0))
		canvas.draw_rect(Rect2(at+Vector2(-8,-31),Vector2(17,38)),OUTLINE)
		canvas.draw_rect(Rect2(at+Vector2(-6,-29),Vector2(13,34)),SHADOW)
		canvas.draw_rect(Rect2(at+Vector2(-5,-28),Vector2(8,31)),WOOD)
		canvas.draw_rect(Rect2(at+Vector2(-5,-28),Vector2(3,29)),LIGHT)
		canvas.draw_rect(Rect2(at+Vector2(-6,-32),Vector2(13,4)),WOOD)
		canvas.draw_rect(Rect2(at+Vector2(-5,-32),Vector2(9,1)),LIGHT)
		canvas.draw_rect(Rect2(at+Vector2(-1,-18),Vector2(2,2)),SHADOW)


static func hedge_rects() -> Array[Rect2]:
	return [Rect2(1920,0,1440,256),Rect2(3280,256,80,1536),
		Rect2(1568,1792,1056,64)]


static func hedge_sprites() -> Array[Dictionary]:
	if not _hedges.is_empty(): return _hedges
	# Dense broad leaves mark the outer forest. They never masquerade as
	# planted crops or squeeze a productive row behind an ornamental hedge.
	for row in range(5):
		for column in range(25):
			var code: int = absi(column*73+row*139+19)
			var width: float = 96+code%3*8
			var size := Vector2(width,width*0.625)
			var at := Vector2(1920+column*56+(row%2)*18,-24+row*44)
			at += Vector2(code%7-3,(code/7)%7-3)*2
			at.x = minf(at.x,3360-size.x)
			var frame := Rect2(at,size)
			if frame.intersects(Rect2(1920,224,224,112)): continue
			if _clear_hedge(frame): _hedges.append({"rect":frame,"seed":code%8})
	for index in range(33):
		var code: int = absi(index*47+23)
		var frame := Rect2(3280+code%3*4,256+index*46,80,60)
		# The stream outlet and the route to the bridge remain visibly open.
		if frame.intersects(Rect2(3224,1968,320,168)): continue
		if _clear_hedge(frame): _hedges.append({"rect":frame,"seed":code%8})
	for index in range(18):
		var code: int = absi(index*79+43)
		var frame := Rect2(1568+index*56,1792+code%4*4,96,60)
		if _clear_hedge(frame): _hedges.append({"rect":frame,"seed":code%8})
	return _hedges


static func _clear_hedge(frame: Rect2) -> bool:
	for area in ["home","nursery","pond"]:
		for slot in range(Grid.planting_cells(area).size()):
			if frame.intersects(Grid.planting_rect(area,slot)): return false
	if frame.intersects(Grid.NURSERY_RECT): return false
	var footprint := PackedVector2Array([frame.position,Vector2(frame.end.x,frame.position.y),frame.end,Vector2(frame.position.x,frame.end.y)])
	for path in Paths.polygons():
		if not Geometry2D.intersect_polygons(footprint,path).is_empty(): return false
	return true


static func draw_hedges(canvas: Node2D, visible: Rect2) -> void:
	for sprite in hedge_sprites():
		if sprite["rect"].intersects(visible):
			var tint := Color.WHITE if sprite["seed"]%3 else Color(0.94,0.98,0.91)
			canvas.draw_texture_rect(_leaf_texture(),sprite["rect"],false,tint)


static func draw_petals(canvas: Node2D, visible: Rect2, elapsed: float) -> void:
	# Sparse petals echo the reference without becoming a reward or a crop.
	for index in range(24):
		var code: int = index*97+43
		var phase: float = fposmod(elapsed*0.08+index*0.173,1.0)
		var at := Vector2(1584+code%1700,88+(code*7)%1656)
		at += Vector2(sin(phase*TAU+index)*8,phase*18)
		at = at.snapped(Vector2(2,2))
		if not visible.has_point(at): continue
		canvas.draw_rect(Rect2(at,Vector2(2,4)),Color("f0bfd2"))
		canvas.draw_rect(Rect2(at+Vector2(2,0),Vector2(2,2)),Color("fff0d9"))


static func _leaf_texture() -> Texture2D:
	if _hedge_texture == null:
		_hedge_texture = load("res://assets/pixel/nursery_reference/hedge.png")
	return _hedge_texture
