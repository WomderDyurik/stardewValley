class_name BattleFieldArt
extends RefCounted

## Whole-field painted pixel texture, with separately shaded pavers following
## the actual movement route. Loop interiors stay grass; no preset bed grid.
const Layout = preload("res://scripts/field_layout.gd")
const View = preload("res://scripts/battle_map_view.gd")
const Placement = preload("res://scripts/battle_placement.gd")
const Clip = preload("res://scripts/canvas_clip.gd")
const MEADOW = preload("res://assets/pixel/battle_meadow_v2/meadow-v2.png")
const ROAD_EDGE := Color("8a693d")
const ROAD_GROUT := Color("c49d54")
const STONE_SHADES: Array[Color] = [Color("aaa389"),Color("bcb192"),Color("a29d85"),Color("c0b493"),Color("b5a684"),Color("ada78d")]
const DECOR_CLEARANCE: float = 7.0
static var _geometry_key: int = 0
static var _geometry: Dictionary = {}
static var _scenery_key: int = 0
static var _scenery: Array[Dictionary] = []
static var _stream_key: int = 0
static var _stream_cache := PackedVector2Array()
static var _protected_key: int = 0
static var _protected_cache: Array[Rect2] = []
static var _decoration_cache: Dictionary = {}


static func draw(canvas: Node2D, board: Rect2, route: Array[Vector2], elapsed: float = 0.0) -> void:
	if not board.has_area(): return
	# One continuous, uniformly scaled material covers the whole canvas. The
	# floating header/footer reveal the same meadow through and between them.
	var field: Rect2 = visual_bounds(board)
	var factor: float = maxf(field.size.x/MEADOW.get_width(),field.size.y/MEADOW.get_height())
	var source_size: Vector2 = field.size/factor
	var source := Rect2((MEADOW.get_size()-source_size)/2.0,source_size)
	var stage: int = int(canvas.battle.stage) if canvas.get("battle") != null else 1
	var profile: Dictionary = stage_profile(stage)
	canvas.draw_texture_rect_region(MEADOW,field,source,profile["tint"])
	var protected: Array[Rect2] = protected_ground(board,route)
	if canvas.get("battle") != null:
		var anchors: Array[Vector2] = canvas.battle.plot_positions()
		for plant in canvas.battle.plants:
			var footprint: Rect2 = View.footprint_at(anchors[int(plant["slot"])])
			footprint.position += board.position
			protected.append(footprint)
	_draw_stage_ground(canvas,board,route,stage)
	var stream: PackedVector2Array = stream_outline(board,route,protected)
	_draw_stream(canvas,stream,stage,elapsed)
	var geometry: Dictionary = _road_geometry(board,route)
	var points: PackedVector2Array = geometry.get("points",PackedVector2Array())
	var width: float = Layout.ROAD_WIDTH*View.SCALE
	if points.size() >= 2:
		# Drawing the centreline directly also handles crossing loops correctly:
		# a closed offset contour must not fill the grass inside a road loop.
		# The earth shoulder fills the already reserved road clearance. Paving
		# remains inside the simulated corridor, with no new placement obstacle.
		canvas.draw_polyline(points,Color("c19b51"),width+9.0,false)
		canvas.draw_polyline(points,Color("d0aa60"),width+6.0,false)
		canvas.draw_polyline(points,ROAD_EDGE,width,false)
		canvas.draw_polyline(points,ROAD_GROUT,width-1.6,false)
		for endpoint in [points[0],points[-1]]:
			canvas.draw_circle(endpoint,width/2.0,ROAD_EDGE)
			canvas.draw_circle(endpoint,width/2.0-0.8,ROAD_GROUT)
	for stone in geometry.get("stones",[]):
		canvas.draw_colored_polygon(stone["polygon"],stone["color"])
		for facet in stone["facets"]:
			canvas.draw_colored_polygon(facet["polygon"],facet["color"])
		for mineral in stone["minerals"]:
			canvas.draw_colored_polygon(mineral["polygon"],mineral["color"])
	_draw_entry_bridge(canvas,board,route,stream)
	_draw_goal_yard(canvas,board,route,protected,stage)
	_draw_edge_clusters(canvas,board,route,protected,stage)
	_draw_scenery(canvas,board,route,elapsed)


static func stage_profile(stage: int) -> Dictionary:
	match stage:
		2: return {"id":"nursery_edge","tint":Color(0.83,0.94,0.87),"soil":Color("829553"),"flowers":Color("eee1a1"),"tree":"tree_pine","caption":"Защита питомника"}
		3: return {"id":"warm_glasshouse","tint":Color(1.0,0.89,0.74),"soil":Color("a79b54"),"flowers":Color("e9c0a5"),"tree":"tree_pink","caption":"Оборона теплицы"}
	return {"id":"meadow_orchard","tint":Color(0.92,0.97,0.83),"soil":Color("9aa358"),"flowers":Color("f5e7b6"),"tree":"tree_round","caption":"Луговая тропа"}


static func _draw_stage_ground(canvas: Node2D, board: Rect2, _route: Array[Vector2], stage: int) -> void:
	var profile: Dictionary = stage_profile(stage)
	# Broad, quiet changes in the grass explain three places without pretending
	# there are impassable rocks or mature crops on freely plantable ground.
	var pockets: Array[Rect2] = [Rect2(12,192,154,208),Rect2(340,390,188,258),Rect2(116,570,224,128)]
	if stage==2: pockets = [Rect2(346,178,182,250),Rect2(10,410,186,214),Rect2(168,566,154,144)]
	elif stage==3: pockets = [Rect2(24,178,174,198),Rect2(310,312,214,242),Rect2(60,558,244,144)]
	for index in range(pockets.size()):
		var rect: Rect2 = pockets[index]
		var polygon := PackedVector2Array()
		for step in range(24):
			var angle: float = TAU*step/24.0
			var modulation: float = 0.87+_noise(step,stage*17+index)*0.13
			polygon.append((rect.get_center()+Vector2(cos(angle),sin(angle))*rect.size*0.5*modulation).snapped(Vector2(3,3)))
		canvas.draw_colored_polygon(polygon,Color(profile["soil"],0.13))
	# Close canopies frame the north approach. The lowest leaf is above y190;
	# the first full playable footprint starts at y194, never behind a tree.
	var tree: Texture2D = canvas.FARM_ART.get(profile["tree"])
	var shade := Color(0.17,0.26,0.15,0.15)
	for tree_rect in [Rect2(9,62,80,120),Rect2(70,62,56,84),Rect2(116,62,80,120),Rect2(371,65,62,93),Rect2(432,58,86,129)]:
		canvas.draw_rect(Rect2(tree_rect.position+Vector2(14,68),tree_rect.size*Vector2(0.75,0.1)),shade)
		if tree != null: Clip.draw_texture(canvas,tree,tree_rect,visual_bounds(board))
	# A pair of original orchard props belongs to the unplayable upper band.
	if stage==2:
		var barrel: Texture2D = canvas.FARM_ART.get("barrel")
		if barrel != null: canvas._sprite(barrel,Rect2(285,148,22,29))
	elif stage==3:
		var bush: Texture2D = canvas.FARM_ART.get("bush")
		if bush != null: canvas._sprite(bush,Rect2(277,151,66,33))


static func protected_ground(board: Rect2, projected: Array[Vector2]) -> Array[Rect2]:
	var key: int = hash([board,projected])
	if key==_protected_key: return _protected_cache.duplicate()
	_protected_key=key
	var original: Array[Vector2] = []
	for point in projected: original.append(View.simulation_point(point+board.position))
	var empty: Array[Vector2] = []
	var result: Array[Rect2] = []
	for point in Placement.grid_centers():
		if not Placement.check(point,original,empty)["valid"]: continue
		var cell: Rect2 = View.footprint_at(point)
		cell.position += board.position
		result.append(cell)
	_protected_cache=result
	return result.duplicate()


static func stream_outline(board: Rect2, projected: Array[Vector2], protected: Array[Rect2] = []) -> PackedVector2Array:
	if projected.is_empty(): return PackedVector2Array()
	var key: int = hash([board,projected,protected])
	if key==_stream_key: return _stream_cache
	_stream_key=key
	var entry: Vector2 = projected[0]+board.position
	var east: bool = entry.x>board.get_center().x
	var outer: float = 548.0 if east else -8.0
	var boundary := PackedVector2Array()
	# The channel belongs to a natural, unplantable side margin. At the actual
	# arrival it reaches the road, so a wooden bridge has a real reason to exist.
	for y in range(128,705,8):
		var bend: float = sin(float(y)*0.019)*6.0+sin(float(y)*0.043)*3.0
		var arrival: float = maxf(0,1.0-absf(float(y)-entry.y)/44.0)
		var x: float = 504.0+bend-arrival*40.0 if east else 36.0+bend+arrival*40.0
		for land in protected:
			if float(y)<land.position.y-8 or float(y)>land.end.y+8: continue
			x=maxf(x,land.end.x+6) if east else minf(x,land.position.x-6)
		boundary.append(Vector2(roundf(x/2.0)*2,float(y)))
	var result := PackedVector2Array([Vector2(outer,128)])
	result.append_array(boundary)
	result.append(Vector2(outer,704))
	_stream_cache=result
	return result


static func _draw_stream(canvas: Node2D, outline: PackedVector2Array, stage: int, elapsed: float) -> void:
	if outline.size()<3: return
	canvas.draw_colored_polygon(outline,Color("598f9e") if stage==2 else Color("619fae"))
	var edge: PackedVector2Array = outline.slice(1,outline.size()-1)
	canvas.draw_polyline(edge,Color("527347"),7,false)
	canvas.draw_polyline(edge,Color("a4a56b"),3,false)
	var east: bool = outline[0].x>270
	var direction: float = 1.0 if east else -1.0
	for index in range(2,edge.size()-2,3):
		var at: Vector2 = edge[index]+Vector2(direction*11,0)
		canvas.draw_line(at,at+Vector2(direction*(7+index%3*3),0),Color("9dc9c8"),1,false)
		if index%2==0:
			var drift: float = fposmod(elapsed*2+index*7,16)
			canvas.draw_rect(Rect2(at+Vector2(direction*7,drift),Vector2(3,1)),Color("b2d3c5"))


static func _draw_entry_bridge(canvas: Node2D, board: Rect2, projected: Array[Vector2], stream: PackedVector2Array) -> void:
	if projected.size()<2 or stream.is_empty(): return
	var entry: Vector2 = projected[0]+board.position
	if not Geometry2D.is_point_in_polygon(entry,stream): return
	var east: bool = entry.x>270
	var bank: float = entry.x
	for point in projected:
		var at: Vector2 = point+board.position
		if not Geometry2D.is_point_in_polygon(at,stream): bank=at.x;break
	var first: float = minf(bank-8,0) if not east else bank-8
	var last: float = 540 if east else bank+8
	var width: float = Layout.ROAD_WIDTH*View.SCALE
	var rect := Rect2(first,entry.y-width*0.5-3,last-first,width+6)
	canvas.draw_rect(rect,Color("654b32"))
	for x in range(int(rect.position.x)+1,int(rect.end.x)-1,7):
		canvas.draw_rect(Rect2(x,rect.position.y+2,5,rect.size.y-4),Color("bc9353") if x%3 else Color("aa8046"))
		canvas.draw_rect(Rect2(x,rect.position.y+3,1,rect.size.y-6),Color("d0ab6b"))
	for y in [rect.position.y-2,rect.end.y-1]:
		canvas.draw_rect(Rect2(rect.position.x,y,rect.size.x,3),Color("705139"))
		for x in [rect.position.x+3,rect.end.x-5]:
			canvas.draw_rect(Rect2(x,y-4,4,9),Color("84633c"))


static func _clear_decoration(rect: Rect2, protected: Array[Rect2], projected: Array[Vector2], board: Rect2) -> bool:
	var key: int = hash([rect,protected,projected,board])
	if _decoration_cache.has(key): return _decoration_cache[key]
	if _decoration_cache.size()>256: _decoration_cache.clear()
	for cell in protected:
		if rect.intersects(cell.grow(2)):
			_decoration_cache[key]=false
			return false
	for index in range(1,projected.size()):
		if Placement.segment_rect_distance(projected[index-1]+board.position,projected[index]+board.position,rect)<Layout.ROAD_WIDTH*View.SCALE*0.5+2:
			_decoration_cache[key]=false
			return false
	_decoration_cache[key]=true
	return true


static func _draw_goal_yard(canvas: Node2D, board: Rect2, projected: Array[Vector2], protected: Array[Rect2], stage: int) -> void:
	if projected.is_empty(): return
	var goal: Vector2 = projected[-1]+board.position
	var house := Rect2(goal+Vector2(-38,-60),Vector2(76,76))
	var yard: Rect2 = house.grow(11)
	var polygon := PackedVector2Array([yard.position+Vector2(8,0),Vector2(yard.end.x-8,yard.position.y),Vector2(yard.end.x,yard.position.y+8),yard.end-Vector2(0,8),yard.end-Vector2(8,0),Vector2(yard.position.x+8,yard.end.y),Vector2(yard.position.x,yard.end.y-8),yard.position+Vector2(0,8)])
	canvas.draw_colored_polygon(polygon,Color("d0a75d"))
	for row in range(5):
		for column in range(6):
			var at: Vector2 = yard.position+Vector2(3+column*16+(row%2)*4,5+row*18)
			var paver := Rect2(at,Vector2(10,12))
			if Geometry2D.is_point_in_polygon(paver.get_center(),polygon): canvas.draw_rect(paver,Color("b9ae88"))
	for offset in [Vector2(-26,28),Vector2(80,14),Vector2(-23,60)]:
		var prop := Rect2(house.position+offset,Vector2(23,28))
		if not _clear_decoration(prop,protected,projected,board): continue
		var texture: Texture2D = canvas.FARM_ART.get("barrel" if stage!=2 else "bush")
		if texture!=null: canvas._sprite(texture,prop)


static func _draw_edge_clusters(canvas: Node2D, board: Rect2, projected: Array[Vector2], protected: Array[Rect2], stage: int) -> void:
	var east_stream: bool = not projected.is_empty() and projected[0].x+board.position.x>270
	var x: float = 5.0 if east_stream else 503.0
	for index in range(4):
		var rect := Rect2(x+(index%2)*3,342+index*73,32+index%2*7,24+index%2*9)
		if not _clear_decoration(rect,protected,projected,board): continue
		var texture: Texture2D = canvas.SCENERY.get("rocks") if index%2==0 else canvas.FARM_ART.get("bush")
		if texture!=null: canvas._sprite(texture,rect,Color(0.9,0.96,0.85) if stage==2 else Color.WHITE)


static func visual_bounds(_board: Rect2) -> Rect2:
	return Rect2(0,0,540,960)


static func _road_geometry(board: Rect2, route: Array[Vector2]) -> Dictionary:
	var key: int = hash([board,route,Layout.ROAD_WIDTH*View.SCALE])
	if key == _geometry_key and not _geometry.is_empty(): return _geometry
	_geometry_key = key
	var translated := PackedVector2Array()
	for point in route: translated.append(point+board.position)
	var stones: Array[Dictionary] = []
	var distances: Array[float] = [0.0]
	for index in range(1,route.size()): distances.append(distances[-1]+route[index-1].distance_to(route[index]))
	if route.size() >= 2:
		var along: float = 1.0
		var stone_index: int = 0
		while along < distances[-1]-1.0:
			# Long flagstones alternate with much shorter, squat stones. The
			# independently chipped ends and tapered sides break the brick grid.
			var length: float = 10.0+_noise(stone_index,27)*9.0
			var end: float = minf(along+length,distances[-1]-1.0)
			var first: Dictionary = _route_frame(route,distances,along)
			var last: Dictionary = _route_frame(route,distances,end)
			var half: float = Layout.ROAD_WIDTH*View.SCALE*0.5-1.5
			var p0: Vector2 = first["point"]+board.position
			var p1: Vector2 = last["point"]+board.position
			var n0: Vector2 = first["normal"]
			var n1: Vector2 = last["normal"]
			var normal: Vector2 = (n0+n1).normalized()
			var direction: Vector2 = (p1-p0).normalized()
			var cut0: float = minf(length*0.30,2.0+_noise(stone_index,18)*5.0)
			var cut1: float = minf(length*0.35,1.5+_noise(stone_index,31)*5.0)
			var cut2: float = minf(length*0.32,2.0+_noise(stone_index,53)*4.0)
			var cut3: float = minf(length*0.27,1.0+_noise(stone_index,62)*4.0)
			var upper0: float = half-0.4-_noise(stone_index,12)*2.8
			var upper1: float = half-0.4-_noise(stone_index,13)*3.0
			var lower0: float = half-0.3-_noise(stone_index,14)*3.0
			var lower1: float = half-0.3-_noise(stone_index,15)*2.9
			var polygon := PackedVector2Array([
				(p0+n0*(upper0-cut0*0.7)).round(),
				(p0+direction*cut0+n0*upper0).round(),
				(p0.lerp(p1,0.45)+normal*(minf(upper0,upper1)-0.7)).round(),
				(p1-direction*cut1+n1*upper1).round(),
				(p1+n1*(upper1-cut1*0.8)-direction*_noise(stone_index,74)*2.0).round(),
				(p1-n1*(lower1-cut2*0.7)-direction*_noise(stone_index,75)*2.0).round(),
				(p1-direction*cut2-n1*lower1).round(),
				(p0.lerp(p1,0.52)-normal*(minf(lower0,lower1)-_noise(stone_index,76)*1.3)).round(),
				(p0+direction*cut3-n0*lower0).round(),
				(p0-n0*(lower0-cut3*0.8)+direction*_noise(stone_index,77)*1.5).round(),
			])
			var color: Color = STONE_SHADES[int(_noise(stone_index,89)*STONE_SHADES.size())%STONE_SHADES.size()]
			var local_curve: PackedVector2Array = _route_slice(route,distances,along,end,board.position)
			var local_road: Array[PackedVector2Array] = Geometry2D.offset_polyline(local_curve,Layout.ROAD_WIDTH*View.SCALE*0.5-0.8,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND)
			for corridor in local_road:
				for clipped in Geometry2D.intersect_polygons(polygon,corridor):
					if clipped.size() < 3: continue
					# Split the broad slabs into paired rural pavers. A slight
					# stagger gives the path a human scale beside upright plants.
					var seam: float = 0.4+_noise(stone_index,22)*1.2
					for side in [-1.0,1.0]:
						var split := PackedVector2Array([p0-direction*2+normal*side*seam,p1+direction*2+normal*side*seam,p1+direction*2+normal*side*half*1.5,p0-direction*2+normal*side*half*1.5])
						for paver in Geometry2D.intersect_polygons(clipped,split):
							if paver.size()>=3 and not Geometry2D.triangulate_polygon(paver).is_empty() and (stone_index%7 not in [2,3] or side<0): stones.append(_make_stone(paver,color.darkened(0.025) if side<0 else color,stone_index))
			along = end+0.9+_noise(stone_index,14)*1.8
			stone_index += 1
	_geometry = {"points":translated,"stones":stones}
	return _geometry


static func _make_stone(polygon: PackedVector2Array, color: Color, seed: int) -> Dictionary:
	var center := Vector2.ZERO
	var bounds := Rect2(polygon[0],Vector2.ZERO)
	for point in polygon:
		center += point
		bounds = bounds.expand(point)
	center /= float(polygon.size())
	var facets: Array[Dictionary] = []
	# One broad uneven mineral plane, rather than an identical inset frame.
	var top_plane := PackedVector2Array([
		(bounds.position+bounds.size*Vector2(0.04,0.17)).round(),
		(bounds.position+bounds.size*Vector2(0.58,0.04)).round(),
		(bounds.position+bounds.size*Vector2(0.87,0.29)).round(),
		(bounds.position+bounds.size*Vector2(0.55,0.53)).round(),
		(bounds.position+bounds.size*Vector2(0.09,0.48)).round(),
	])
	for clipped in Geometry2D.intersect_polygons(top_plane,polygon):
		if clipped.size() >= 3 and not Geometry2D.triangulate_polygon(clipped).is_empty(): facets.append({"polygon":clipped,"color":color.lightened(0.045+_noise(seed,81)*0.045)})
	# Only down/right facing edges have a chipped shadow face. Leaving other
	# edges unframed prevents the stones from reading as repeated UI buttons.
	for index in range(polygon.size()):
		var next: int = (index+1)%polygon.size()
		var middle: Vector2 = (polygon[index]+polygon[next])*0.5
		var light: float = (middle-center).normalized().dot(Vector2(-0.6,-0.8))
		if light > -0.34: continue
		var depth: float = 0.20+_noise(seed+index,34)*0.20
		var facet := PackedVector2Array([polygon[index],polygon[next],polygon[next].lerp(center,depth).round(),polygon[index].lerp(center,depth*0.7).round()])
		for clipped in Geometry2D.intersect_polygons(facet,polygon):
			if clipped.size() >= 3 and not Geometry2D.triangulate_polygon(clipped).is_empty(): facets.append({"polygon":clipped,"color":color.darkened(0.10+_noise(seed+index,37)*0.10)})
	var minerals: Array[Dictionary] = []
	if seed%3 != 1:
		var at: Vector2 = center+Vector2(_noise(seed,40)-0.5,_noise(seed,42)-0.5)*bounds.size*0.45
		var size: float = 2.0+_noise(seed,44)*2.0
		var patch := PackedVector2Array([(at+Vector2(-size,-1)).round(),(at+Vector2(0,-2)).round(),(at+Vector2(size,0)).round(),(at+Vector2(size-1,2)).round(),(at+Vector2(-size,1)).round()])
		for clipped in Geometry2D.intersect_polygons(patch,polygon):
			if clipped.size() >= 3 and not Geometry2D.triangulate_polygon(clipped).is_empty(): minerals.append({"polygon":clipped,"color":color.darkened(0.08) if seed%2 else color.lightened(0.08)})
	return {"polygon":polygon,"color":color,"facets":facets,"minerals":minerals}


static func _route_slice(route: Array[Vector2], distances: Array[float], first: float, last: float, offset: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array([_route_frame(route,distances,first)["point"]+offset])
	for index in range(1,route.size()-1):
		if distances[index] > first and distances[index] < last: points.append(route[index]+offset)
	points.append(_route_frame(route,distances,last)["point"]+offset)
	return points


static func _route_frame(route: Array[Vector2], distances: Array[float], along: float) -> Dictionary:
	for index in range(1,distances.size()):
		if distances[index] < along: continue
		var direction: Vector2 = (route[index]-route[index-1]).normalized()
		var weight: float = inverse_lerp(distances[index-1],distances[index],along)
		return {"point":route[index-1].lerp(route[index],weight),"normal":Vector2(-direction.y,direction.x)}
	return {"point":route[-1],"normal":Vector2.RIGHT}


static func _noise(index: int, seed: int) -> float:
	return fposmod(sin(float(index*127+seed*311))*43758.5453,1.0)


static func scenery_items(board: Rect2, route: Array[Vector2]) -> Array[Dictionary]:
	var key: int = hash([board,route])
	if key == _scenery_key: return _scenery
	_scenery_key = key
	_scenery.clear()
	var field: Rect2 = visual_bounds(board)
	# Cropped leaves live outside the playable rectangle. They never reserve
	# phantom planting spots or disappear according to an old 19-bed grid.
	var candidates: Array[Dictionary] = [
		{"kind":"tree_round","rect":Rect2(-70,field.position.y+1,88,105),"source":"farm"},
		{"kind":"tree_round","rect":Rect2(522,field.position.y+4,88,105),"source":"farm"},
		{"kind":"bush","rect":Rect2(78,field.position.y-23,84,43),"source":"farm"},
		{"kind":"bush","rect":Rect2(358,field.position.y-25,88,45),"source":"farm"},
		{"kind":"bush","rect":Rect2(-55,field.position.y+118,76,42),"source":"farm"},
		{"kind":"bush","rect":Rect2(519,field.position.y+126,78,43),"source":"farm"},
		{"kind":"tree_pine","rect":Rect2(-69,field.position.y+213,90,132),"source":"farm"},
		{"kind":"tree_round","rect":Rect2(521,field.position.y+254,90,108),"source":"farm"},
		{"kind":"bush","rect":Rect2(-58,field.end.y-145,79,43),"source":"farm"},
		{"kind":"bush","rect":Rect2(520,field.end.y-169,82,44),"source":"farm"},
		{"kind":"tree_round","rect":Rect2(-75,field.end.y-104,96,107),"source":"farm"},
		{"kind":"tree_pine","rect":Rect2(521,field.end.y-131,96,134),"source":"farm"},
		{"kind":"bush","rect":Rect2(112,board.end.y+2,74,40),"source":"farm"},
		{"kind":"bush","rect":Rect2(350,board.end.y+2,83,44),"source":"farm"},
	]
	for item in candidates:
		var rect: Rect2 = item["rect"]
		var visible: Rect2 = rect.intersection(field)
		if not visible.has_area() or visible.intersects(board): continue
		if not _scenery_is_clear(Rect2(visible.position-board.position,visible.size),route): continue
		item["visible_bounds"] = visible
		_scenery.append(item)
	_scenery.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a["rect"].end.y < b["rect"].end.y)
	return _scenery


static func _scenery_is_clear(rect: Rect2, route: Array[Vector2]) -> bool:
	for index in range(1,route.size()):
		if _segment_rect_distance(route[index-1],route[index],rect) < Layout.ROAD_WIDTH*View.SCALE*0.5+DECOR_CLEARANCE: return false
	return true


static func _segment_rect_distance(first: Vector2, last: Vector2, rect: Rect2) -> float:
	if rect.has_point(first) or rect.has_point(last): return 0.0
	var corners: Array[Vector2] = [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
	var shortest: float = minf(first.distance_to(first.clamp(rect.position,rect.end)),last.distance_to(last.clamp(rect.position,rect.end)))
	for index in range(4):
		if Geometry2D.segment_intersects_segment(first,last,corners[index],corners[(index+1)%4]) != null: return 0.0
		shortest = minf(shortest,corners[index].distance_to(Geometry2D.get_closest_point_to_segment(corners[index],first,last)))
	return shortest


static func _draw_scenery(canvas: Node2D, board: Rect2, route: Array[Vector2], _elapsed: float) -> void:
	for item in scenery_items(board,route):
		var textures: Dictionary = canvas.FARM_ART if item["source"] == "farm" else canvas.SCENERY
		var texture: Texture2D = textures.get(item["kind"])
		if texture != null: Clip.draw_texture(canvas,texture,item["rect"],visual_bounds(board))
