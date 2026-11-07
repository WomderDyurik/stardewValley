class_name GardenTerrain
extends RefCounted

## A continuous rural estate: warm walking earth, turf islands and tended rows.
## Saved planting IDs and the camera remain independent of the illustration.
const World = preload("res://scripts/garden_world.gd")
const Palette = preload("res://scripts/garden_palette.gd")
const Materials = preload("res://scripts/garden_materials.gd")
const Paths = preload("res://scripts/garden_paths.gd")
const Grid = preload("res://scripts/garden_grid.gd")
const Nursery = preload("res://scripts/nursery_environment.gd")
const Experience = preload("res://scripts/garden_experience.gd")
const TILE: int = 32
const TEXTURE_TILE: float = 192.0
const EARTH = Palette.EARTH
const EARTH_LIGHT = Palette.EARTH_LIGHT
const EARTH_DARK = Palette.EARTH_DARK
const GRASS = Palette.GRASS
const GRASS_LIGHT = Palette.GRASS_LIGHT
const GRASS_DARK = Palette.GRASS_DARK
const FARM_SOIL = Palette.SOIL
const PATH = Palette.PATH
const PATH_LIGHT = Palette.EARTH_LIGHT
const PATH_DARK = Palette.EARTH_DARK
const WATER = Color("66acd0")
const WATER_LIGHT = Color("98d0e4")
const WATER_DARK = Palette.WATER_DARK
const GARDEN_FLOOR = World.GARDEN_FLOOR
const NURSERY_FLOOR = World.NURSERY_FLOOR
# The greenhouse is an upgrade yard; no planting ground belongs to it.
const GREENHOUSE_FLOOR := Rect2()
const POND_BENCH_RECT = Grid.POND_BENCH_RECT
const WELL_RECT = Grid.WELL_RECT
const GRASS_PATCHES: Array[Rect2] = [
	Rect2(32,32,1408,352), Rect2(32,384,128,928),
	Rect2(96,1376,1312,160), Rect2(1536,32,1824,320),
	Rect2(1568,1184,1056,352), Rect2(3328,352,176,1152),
	Rect2(32,1568,3360,672), Rect2(3360,1568,144,672),
]



static func draw(canvas: Node2D, elapsed: float, textures: Dictionary = {}) -> void:
	var visible: Rect2 = World.WORLD_RECT
	var camera = canvas.get("garden_world")
	if camera != null: visible = rendering_world_rect(camera).grow(96)
	# The same world-space ground continues under floating HUD surfaces. At a
	# clamped map edge the natural earth extends beyond the estate boundary;
	# it never reveals a separate screen-space top or bottom background strip.
	Materials.draw_rect(canvas, visible, "grass")
	_draw_overscan_meadow(canvas,visible)
	for index in range(GRASS_PATCHES.size()):
		_grass_patch(canvas, GRASS_PATCHES[index], visible, textures, index)
	Experience.draw_understory(canvas,visible)
	_draw_farm_courtyard(canvas,visible)
	_draw_nursery_courtyard(canvas,visible)
	# The open vegetable rows sit in the common landscape, not a walled room.
	_draw_living_beds(canvas,"home",visible)
	_draw_living_beds(canvas,"nursery",visible)
	_draw_paths(canvas, visible, textures)
	# Redraw adjoining aprons after path shoulders, so their stone surface has
	# no gold arc or seam at the door/service T junction.
	_draw_greenhouse_yard(canvas,visible)
	Materials.draw(canvas,_clearing_outline(Rect2(2592,2112,96,48),"path"),"stone")
	for water in water_outlines(): _draw_water_body(canvas, water, visible, textures, elapsed)
	_draw_bridge(canvas, Rect2(3432,2280,168,48), visible)
	_draw_fences(canvas, visible, textures)
	_draw_flower_borders(canvas, visible)
	_draw_orchards(canvas, textures, visible)
	Nursery.draw_hedges(canvas,visible)
	Nursery.draw_petals(canvas,visible,elapsed)
	_draw_pond_details(canvas, textures, visible)
	Experience.draw_landmarks(canvas,visible,elapsed)
	if textures.has("well") and WELL_RECT.intersects(visible):
		_sprite(canvas, textures["well"], WELL_RECT)


static func rendering_world_rect(camera) -> Rect2:
	var first: Vector2 = camera.screen_to_world(Vector2.ZERO)
	var last: Vector2 = camera.screen_to_world(Vector2(540,960))
	return Rect2(first,last-first)


static func _draw_overscan_meadow(canvas: Node2D, visible: Rect2) -> void:
	# The estate opens into the same meadow beyond its saved camera bounds.
	# World-anchored uneven edges overlap the first/last turf islands, so no
	# horizontal strip appears when the camera is clamped near the map edge.
	# Actual paths, cultivated ground and water are painted afterwards.
	var margin: float = 640.0
	var width: float = World.WORLD_SIZE.x
	var height: float = World.WORLD_SIZE.y
	var top := PackedVector2Array([Vector2(-margin,-margin),Vector2(width+margin,-margin),Vector2(width+margin,128)])
	var bottom := PackedVector2Array([Vector2(-margin,height+margin),Vector2(width+margin,height+margin),Vector2(width+margin,height-128)])
	for x in range(int(width+margin)-8,-int(margin)-1,-128):
		top.append(Vector2(x,120+_cell(x/128,73)%9*8))
		bottom.append(Vector2(x,height-144+_cell(x/128,91)%9*8))
	var left := PackedVector2Array([Vector2(-margin,-margin),Vector2(64,-margin)])
	var right := PackedVector2Array([Vector2(width+margin,-margin),Vector2(width-64,-margin)])
	for y in range(-int(margin),int(height+margin)+1,128):
		left.append(Vector2(48+_cell(y/128,41)%5*8,y))
		right.append(Vector2(width-48-_cell(y/128,59)%5*8,y))
	left.append(Vector2(-margin,height+margin))
	right.append(Vector2(width+margin,height+margin))
	var surfaces: Array[PackedVector2Array] = [top,bottom,left,right]
	for index in range(surfaces.size()):
		var polygon: PackedVector2Array = surfaces[index]
		var bounds := Rect2(polygon[0],Vector2.ZERO)
		for point in polygon: bounds = bounds.expand(point)
		if not bounds.intersects(visible): continue
		Materials.draw(canvas,polygon,"grass")
		var pocket: Rect2 = Rect2(-48,-224,width+96,352) if index==0 else Rect2(-48,height-72,width+96,304) if index==1 else bounds.grow(-32)
		for clipped in Geometry2D.intersect_polygons(polygon,_tonal_pocket_outline(pocket,31+index)):
			canvas.draw_colored_polygon(clipped,Color(GRASS_DARK,0.035))


static func planting_floor(index: int) -> Rect2:
	return World.planting_floor(index)


static func path_routes() -> Array[Dictionary]:
	return Paths.routes()


static func doorway_points() -> Dictionary:
	return Paths.doorway_points()


static func path_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for route in path_routes():
		var points: PackedVector2Array = route["points"]
		for index in range(1,points.size()):
			var first: Vector2 = points[index-1]
			var last: Vector2 = points[index]
			result.append(Rect2(first.min(last),(last-first).abs()).grow(float(route["width"])/2.0))
	return result


static func path_polygons(include_service: bool = true) -> Array[PackedVector2Array]:
	return Paths.polygons(include_service)


static func _has_equipment(canvas: Node2D) -> bool:
	var state = canvas.get("state")
	if state == null: return false
	for id in ["irrigation","compost","harvest_crate"]:
		if state.helper_level(id) > 0: return true
	return false


static func farm_courtyard_polygons() -> Dictionary:
	# The meadow is continuous. Only the porch, tool nook and the narrow
	# shoulders of each cultivated square expose golden walking earth.
	var earth: Array[PackedVector2Array] = [
		_clearing_outline(Rect2(160,304,576,144),"path"),
		_clearing_outline(Rect2(1088,336,160,96),"path")]
	for block in Grid.block_rects("home"): earth.append(_rect_outline(block.grow(12)))
	return {"earth":earth,"stone":[],"grass":[]}


static func _draw_farm_courtyard(canvas: Node2D, visible: Rect2) -> void:
	var surfaces: Dictionary = farm_courtyard_polygons()
	# The first two surfaces are the real porch and tool nook. The full block
	# metadata remains available to geometry checks, but empty meadow is not
	# pre-painted as a vast agricultural workload.
	for index in range(2): Materials.draw(canvas,surfaces["earth"][index],"earth")
	for polygon in surfaces["grass"]:
		Materials.draw(canvas,polygon,"grass")
		_draw_turf_edge(canvas,polygon,visible)


static func _draw_turf_edge(canvas: Node2D, polygon: PackedVector2Array, visible: Rect2) -> void:
	for index in range(polygon.size()):
		var first: Vector2 = polygon[index]
		var last: Vector2 = polygon[(index+1)%polygon.size()]
		if first.distance_to(last) < 12: continue
		for step in range(0,int(first.distance_to(last)),10):
			var at: Vector2 = first.move_toward(last,step).snapped(Vector2(2,2))
			if not visible.has_point(at): continue
			var code: int = _cell(int(at.x/2),int(at.y/2))
			at.x += code%3*2
			canvas.draw_rect(Rect2(at+Vector2(-2,-2),Vector2(2,4)),GRASS_DARK)
			canvas.draw_rect(Rect2(at+Vector2(0,-2-code%2*2),Vector2(2,4+code%2*2)),Color("69af37"))
			if code%3 == 0: canvas.draw_rect(Rect2(at+Vector2(2,0),Vector2(2,4)),GRASS)


static func _draw_paths(canvas: Node2D, visible: Rect2, textures: Dictionary) -> void:
	var include_service: bool = _has_equipment(canvas)
	# The main walk and door aprons use stone. Field access uses soft earth;
	# this material hierarchy keeps the estate from reading as a parking grid.
	for route in Paths.routes():
		if route["id"] == "helper_service" and not include_service: continue
		var kind: String = "stone" if route["id"] in ["estate_lane","garden_front","cottage_door","greenhouse_door","equipment_walk","helper_service"] else "earth"
		for polygon in Geometry2D.offset_polyline(route["points"],float(route["width"])/2.0,Geometry2D.JOIN_ROUND,Geometry2D.END_BUTT):
			for shoulder in Geometry2D.offset_polygon(polygon,4.0,Geometry2D.JOIN_SQUARE): Materials.draw(canvas,shoulder,"earth")
			Materials.draw(canvas,polygon,kind)
	for polygon in [path_polygons(include_service)[-2],path_polygons(include_service)[-1]]: Materials.draw(canvas,polygon,"stone")


static func nursery_courtyard_outline() -> PackedVector2Array:
	return _clearing_outline(Rect2(1584,384,336,208),"path")


static func _draw_nursery_courtyard(canvas: Node2D, visible: Rect2) -> void:
	if not Rect2(1568,0,1792,1824).intersects(visible): return
	Materials.draw(canvas,nursery_courtyard_outline(),"earth")
	Materials.draw(canvas,_clearing_outline(Rect2(1920,248,144,88),"path"),"earth")


static func greenhouse_yard_polygons() -> Array[PackedVector2Array]:
	# Each apron serves one entrance or a compact group of equipment.
	return [_clearing_outline(Rect2(336,2496,192,72),"path")]


static func _draw_greenhouse_yard(canvas: Node2D, visible: Rect2) -> void:
	if not Rect2(192,2176,960,576).intersects(visible): return
	for surface in greenhouse_yard_polygons(): Materials.draw(canvas,surface,"stone")
	var state = canvas.get("state")
	if state == null: return
	for id in ["irrigation","compost","harvest_crate"]:
		if state.helper_level(id) <= 0: continue
		var cell: Rect2 = Grid.helper_rect(id)
		Materials.draw(canvas,_clearing_outline(Rect2(cell.position-Vector2(8,8),cell.size+Vector2(16,48)),"path"),"stone")
	if _has_equipment(canvas):
		# A short service strip joins the three actual equipment pads.
		Materials.draw_rect(canvas,Rect2(664,2400,304,32),"stone")


static func stone_segments() -> Array[Rect2]:
	# Stone belongs to a porch or a small paved junction, not district borders.
	return []


static func _ground_pattern(canvas: Node2D, visible: Rect2) -> void:
	_material_marks(canvas,PackedVector2Array([visible.position,Vector2(visible.end.x,visible.position.y),visible.end,Vector2(visible.position.x,visible.end.y)]),visible,"earth",7)


static func _material_marks(canvas: Node2D, polygon: PackedVector2Array, visible: Rect2, material: String, seed: int = 0) -> void:
	# Deliberately placed low-contrast clusters have no rectangular image tile.
	# Jittered world anchors keep the surface continuous across camera movement.
	var bounds := Rect2(polygon[0],Vector2.ZERO)
	for point in polygon: bounds = bounds.expand(point)
	var area: Rect2 = bounds.intersection(visible)
	if not area.has_area(): return
	for row in range(floori(area.position.y/144),ceili(area.end.y/144)):
		for column in range(floori(area.position.x/144),ceili(area.end.x/144)):
			var code: int = _cell(column+seed,row+19)
			if code % (3 if material == "grass" else 4) != 0: continue
			var at := Vector2(column*144+14+_cell(column+23,row+seed)%112,row*144+14+_cell(column+seed,row+37)%112)
			if not Geometry2D.is_point_in_polygon(at,polygon): continue
			if material == "grass":
				for blade in [Vector2(-4,-3),Vector2(0,-7),Vector2(4,-4)]:
					canvas.draw_line(at+Vector2(blade.x,0),at+blade,Color(GRASS_DARK,0.53),2,false)
				canvas.draw_rect(Rect2(at+Vector2(0,-6),Vector2(2,3)),Color(GRASS_LIGHT,0.48))
				if code % 2 == 0:
					canvas.draw_rect(Rect2(at+Vector2(13,4),Vector2(3,2)),Color(GRASS_DARK,0.22))
			elif material == "path":
				canvas.draw_line(at,at+Vector2(5,0),Color(PATH_DARK,0.26),1,false)
			elif material == "mulch":
				canvas.draw_line(at,at+Vector2(5,1),Color("ad9672"),1,false)
				canvas.draw_line(at+Vector2(9,4),at+Vector2(12,5),Color("715c45"),1,false)
			else:
				canvas.draw_rect(Rect2(at,Vector2(3,2)),Color(EARTH_DARK,0.33))
				canvas.draw_rect(Rect2(at+Vector2(1,-1),Vector2(2,1)),Color(EARTH_LIGHT,0.36))


static func _grass_patch(canvas: Node2D, rect: Rect2, visible: Rect2, textures: Dictionary, seed: int = 0) -> void:
	if not rect.intersects(visible): return
	var polygon: PackedVector2Array = _turf_outline(rect,seed)
	Materials.draw(canvas,polygon,"grass")
	# Broad cool tonal pockets link foliage to the ground. Sparse clusters leave
	# actual quiet grass between them rather than a regular carpet of microdots.
	var pocket := Rect2(rect.position+rect.size*Vector2(0.12,0.2),rect.size*Vector2(0.60,0.48))
	for clipped in Geometry2D.intersect_polygons(polygon,_tonal_pocket_outline(pocket,seed+9)):
		canvas.draw_colored_polygon(clipped,Color(GRASS_DARK,0.035))


static func _tonal_pocket_outline(rect: Rect2, seed: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in range(32):
		var angle: float = index * TAU / 32.0
		var bend: float = 0.94+float(_cell(index,seed)%9)*0.008
		var at: Vector2 = rect.get_center()+Vector2(cos(angle),sin(angle))*rect.size*0.5*bend
		result.append((at/4.0).round()*4.0)
	return result


static func _turf_outline(rect: Rect2, seed: int = 0) -> PackedVector2Array:
	var rows: int = maxi(2,ceili(rect.size.y / 16))
	var points := PackedVector2Array()
	var lefts: Array[float] = []
	for row in range(rows):
		var corner: float = maxf(0,minf(40,rect.size.x*0.16)-minf(row,rows-1-row)*16)
		var tooth: float = minf(8,floorf(rect.size.x*0.06/2)*2)
		var uneven: float = float(_cell(row,seed+17)%3)*tooth
		var left: float = rect.position.x+corner+uneven
		var right: float = rect.end.x-corner-float(_cell(seed+3,row)%3)*tooth
		lefts.append(left)
		var top: float = rect.position.y+row*16
		points.append(Vector2(right,top))
		points.append(Vector2(right,minf(rect.end.y,top+16)))
	for row in range(rows-1,-1,-1):
		var top: float = rect.position.y+row*16
		points.append(Vector2(lefts[row],minf(rect.end.y,top+16)))
		points.append(Vector2(lefts[row],top))

	# Adjacent vertical steps can share a vertex. Remove repeats and straight
	# intermediate points so every narrow patch remains triangulatable.
	var unique := PackedVector2Array()
	for point in points:
		if unique.is_empty() or not point.is_equal_approx(unique[-1]): unique.append(point)
	var clean := PackedVector2Array()
	for index in range(unique.size()):
		var previous: Vector2 = unique[(index-1+unique.size())%unique.size()]
		var current: Vector2 = unique[index]
		var following: Vector2 = unique[(index+1)%unique.size()]
		if absf((current-previous).cross(following-current)) > 0.001: clean.append(current)
	return clean


static func district_ground_spec(_id: String) -> Dictionary:
	# Removed region IDs retain save records only; they own no active ground.
	return {}


static func _rect_outline(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])


static func garden_courtyard_polygons() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for block in Grid.block_rects("home"): result.append(_rect_outline(block))
	return result


static func nursery_ground_polygons() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for block in Grid.block_rects("nursery"): result.append(_rect_outline(block))
	return result


static func greenhouse_ground_polygons() -> Array[PackedVector2Array]:
	return []


static func _draw_cultivated_ground(canvas: Node2D, polygon: PackedVector2Array, style: String) -> void:
	# Six rows share one square of warm tilled earth. Fine broken furrows
	# stay quieter than the planted silhouettes at native phone scale.
	Materials.draw(canvas,polygon,"soil",Color(0.97,0.96,0.88) if style == "nursery" else Color.WHITE)
	var bounds := Rect2(polygon[0],Vector2.ZERO)
	for point in polygon: bounds = bounds.expand(point)
	canvas.draw_line(bounds.position,bounds.position+Vector2(bounds.size.x,0),Color("88542d"),3,false)
	canvas.draw_line(Vector2(bounds.position.x,bounds.end.y-2),bounds.end-Vector2(0,2),Color("c58a42"),2,false)
	for y in range(int(bounds.position.y)+48,int(bounds.end.y),48):
		for x in range(int(bounds.position.x)+8,int(bounds.end.x)-8,32):
			var code: int = _cell(x/32,y/48)
			if code%4 == 0: continue
			canvas.draw_line(Vector2(x,y),Vector2(x+18+code%8,y),Color("985e30"),2,false)
			canvas.draw_line(Vector2(x,y+2),Vector2(x+16+code%8,y+2),Color("ad7236"),2,false)


static func _draw_living_beds(canvas: Node2D, area: String, visible: Rect2) -> void:
	var state = canvas.get("state")
	if state == null: return
	var cells: Array[Vector2i] = Grid.planting_cells(area)
	var occupied: Dictionary = {}
	for slot in range(cells.size()):
		if not state.plot_kind(area,slot).is_empty(): occupied[cells[slot]] = true
		else:
			var frame: Rect2 = Grid.cell_rect(cells[slot])
			if not frame.intersects(visible): continue
			# Untended slots remain a meadow. Sparse blades and wild daisies
			# disappear as that exact paid cell is tilled; they are not crops.
			for sample in range(5):
				var code: int = _cell(slot*7+sample*19,17 if area == "home" else 29)
				var at: Vector2 = frame.position+Vector2(16+(code*13)%68,18+(code*23+sample*11)%64)
				canvas.draw_line(at+Vector2(-3,2),at+Vector2(-2,-3),Color("74ad42"),2,false)
				canvas.draw_line(at+Vector2(2,2),at+Vector2(3,-5),Color("6aa63d"),2,false)
				if code%9 == 0:
					canvas.draw_rect(Rect2(at+Vector2(-2,-3),Vector2(6,2)),Color("d1d2a0"))
					canvas.draw_rect(Rect2(at+Vector2(0,-5),Vector2(2,6)),Color("d1d2a0"))
	for block in Grid.block_rects(area):
		if not block.grow(8).intersects(visible): continue
		var count: int = 0
		for cell in occupied:
			if block.has_point(Grid.cell_center(cell)): count += 1
		if count < 36: Experience.draw_meadow_drifts(canvas,block,occupied,int(block.position.x/96+block.position.y/48))
		Experience.draw_block_boundary(canvas,block,count)
	for cell in occupied:
		var frame: Rect2 = Grid.cell_rect(cell)
		if not frame.grow(8).intersects(visible): continue
		Materials.draw_rect(canvas,frame,"soil",Color(0.97,0.96,0.88) if area == "nursery" else Color.WHITE)
		# Neighbouring occupied cells share a continuous soil surface, world UVs
		# and furrow phase; edges exist only on the outside of the planted group.
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			if occupied.has(cell+direction): continue
			var a: Vector2 = frame.position
			var b: Vector2 = frame.end
			if direction == Vector2i.UP: b.y = a.y
			elif direction == Vector2i.DOWN: a.y = b.y
			elif direction == Vector2i.LEFT: b.x = a.x
			else: a.x = b.x
			canvas.draw_line(a,b,Color("ba8a45") if direction.y > 0 else Color("8d622f"),2,false)
		for y in range(int(frame.position.y)+24,int(frame.end.y),48):
			for x in range(int(frame.position.x)+4,int(frame.end.x)-8,32):
				canvas.draw_line(Vector2(x,y),Vector2(x+22,y),Color("985e30"),2,false)


static func _draw_cell_grid(canvas: Node2D, bounds: Rect2, color: Color) -> void:
	for x in range(int(bounds.position.x),int(bounds.end.x)+1,Grid.CELL_SIZE):
		canvas.draw_line(Vector2(x,bounds.position.y),Vector2(x,bounds.end.y),color,1,false)
	for y in range(int(bounds.position.y),int(bounds.end.y)+1,Grid.CELL_SIZE):
		canvas.draw_line(Vector2(bounds.position.x,y),Vector2(bounds.end.x,y),color,1,false)


static func district_ground_polygons(id: String) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for rect in district_ground_spec(id).get("groups",[]): result.append(_rect_outline(rect))
	return result

static func _rounded_ground(controls: PackedVector2Array, radius: float) -> PackedVector2Array:
	# A few authored broad corners give calm silhouettes. Texture pixels keep
	# their shared world phase; no row-by-row random teeth are added.
	var result := PackedVector2Array()
	for index in range(controls.size()):
		var previous: Vector2 = controls[(index-1+controls.size())%controls.size()]
		var corner: Vector2 = controls[index]
		var following: Vector2 = controls[(index+1)%controls.size()]
		var amount: float = minf(radius,minf(previous.distance_to(corner),following.distance_to(corner))*0.3)
		var entry: Vector2 = corner.move_toward(previous,amount)
		var exit: Vector2 = corner.move_toward(following,amount)
		for step in range(5):
			var t: float = float(step)/4.0
			result.append(entry.lerp(corner,t).lerp(corner.lerp(exit,t),t))
	return result


static func _path(canvas: Node2D, rect: Rect2, visible: Rect2, textures: Dictionary) -> void:
	if not rect.intersects(visible): return
	_soft_surface(canvas,rect,visible,textures.get("ground_earth"),PATH,"path")
	# Only the village crossroads and greenhouse porch use small paving stones.
	var paved: Rect2 = rect.intersection(Rect2(784,624,192,96))
	if paved.has_area() and textures.has("ground_stone"):
		_textured_surface(canvas,textures["ground_stone"],paved,visible)


static func _clearing_outline(rect: Rect2, style: String) -> PackedVector2Array:
	var cut: float = 4 if style == "path" else 12
	return PackedVector2Array([rect.position+Vector2(cut,0),Vector2(rect.end.x-cut,rect.position.y),
		Vector2(rect.end.x,rect.position.y+cut),rect.end-Vector2(0,cut),rect.end-Vector2(cut,0),
		Vector2(rect.position.x+cut,rect.end.y),Vector2(rect.position.x,rect.end.y-cut),rect.position+Vector2(0,cut)])


static func _soft_surface(canvas: Node2D, rect: Rect2, visible: Rect2, texture: Texture2D, fallback: Color, style: String) -> void:
	if not rect.intersects(visible): return
	var polygon: PackedVector2Array = _clearing_outline(rect,style)
	Materials.draw(canvas,polygon,"earth",Color(1.04,1.03,0.98) if style == "path" else Color(0.96,0.96,0.92))


static func draw_planting_bed(canvas: Node2D, rect: Rect2, highlighted: bool, style: String = "vegetable", shared_ground: bool = true) -> void:
	# Compatibility name only: a planting cell never paints soil or furrows.
	if not highlighted: return
	var border: PackedVector2Array = _rect_outline(rect.grow(-2))
	border.append(border[0])
	canvas.draw_polyline(border,Color("fff2b3"),2,false)


static func _bed_outline(rect: Rect2) -> PackedVector2Array:
	return _clearing_outline(rect,"path")


static func _textured_polygon(canvas: Node2D, texture: Texture2D, polygon: PackedVector2Array, visible: Rect2) -> void:
	var bounds := Rect2(polygon[0],Vector2.ZERO)
	for point in polygon: bounds = bounds.expand(point)
	var area: Rect2 = bounds.intersection(visible)
	if not area.has_area(): return
	for y in range(floori(area.position.y/8)*8,ceili(area.end.y),8):
		var scan: float = y+4
		var xs: Array[float] = []
		for index in range(polygon.size()):
			var first: Vector2 = polygon[index]
			var last: Vector2 = polygon[(index+1)%polygon.size()]
			if (first.y <= scan and last.y > scan) or (last.y <= scan and first.y > scan):
				xs.append(first.x+(scan-first.y)/(last.y-first.y)*(last.x-first.x))
		xs.sort()
		for index in range(0,xs.size()-1,2):
			_textured_surface(canvas,texture,Rect2(xs[index],y,xs[index+1]-xs[index],8),visible)


static func _textured_surface(canvas: Node2D, texture: Texture2D, rect: Rect2, visible: Rect2) -> void:
	var area: Rect2 = rect.intersection(visible)
	if not area.has_area(): return
	var source_texture: Texture2D = texture
	var offset = Vector2.ZERO
	if texture is AtlasTexture:
		source_texture = texture.atlas
		offset = texture.region.position
	var size: Vector2 = texture.get_size()
	for row in range(floori(area.position.y/TEXTURE_TILE),ceili(area.end.y/TEXTURE_TILE)):
		for column in range(floori(area.position.x/TEXTURE_TILE),ceili(area.end.x/TEXTURE_TILE)):
			var origin: Vector2 = Vector2(column,row)*TEXTURE_TILE
			var part: Rect2 = Rect2(origin,Vector2.ONE*TEXTURE_TILE).intersection(area)
			var source := Rect2(offset+(part.position-origin)/TEXTURE_TILE*size,part.size/TEXTURE_TILE*size)
			canvas.draw_texture_rect_region(source_texture,part,source,Color.WHITE,false,true)


static func pond_outline() -> PackedVector2Array:
	var pond: Rect2 = World.POND_RECT
	var center: Vector2 = pond.get_center()
	var rows: int = int(pond.size.y/16.0)
	var points := PackedVector2Array()
	var widths: Array[float] = []
	for row in range(rows):
		var y: float = pond.position.y+row*16
		var n: float = (y+8-center.y)/(pond.size.y/2.0)
		var half_width: float = floorf(sqrt(maxf(0,1-n*n))*pond.size.x/16.0)*8.0
		widths.append(half_width)
		points.append(Vector2(center.x+half_width,y))
		points.append(Vector2(center.x+half_width,y+16))
	for row in range(rows-1,-1,-1):
		var y: float = pond.position.y+row*16
		points.append(Vector2(center.x-widths[row],y+16))
		points.append(Vector2(center.x-widths[row],y))
	return points


static func river_outline() -> PackedVector2Array:
	var points := PackedVector2Array()
	for y in range(0,int(World.WORLD_SIZE.y),32):
		var x: float = World.WORLD_SIZE.x-144+roundf(sin(y/224.0)*2)*8
		points.append(Vector2(x,y))
		points.append(Vector2(x,mini(y+32,int(World.WORLD_SIZE.y))))
	points.append(Vector2(World.WORLD_SIZE.x,World.WORLD_SIZE.y))
	points.append(Vector2(World.WORLD_SIZE.x,0))
	return points


static func pond_outlet_outline() -> PackedVector2Array:
	var offset := Vector2(0,World.POND_RECT.get_center().y-2016)
	# Small downstream steps describe one shallow bend; no rectangular canal
	# elbow is cut into the lawn between the pond and the river.
	var result := PackedVector2Array([Vector2(3240,2008),Vector2(3280,2008),Vector2(3280,2016),
		Vector2(3320,2016),Vector2(3320,2024),Vector2(3360,2024),Vector2(3360,2032),
		Vector2(3408,2032),Vector2(3408,2040),Vector2(3504,2040),Vector2(3504,2088),
		Vector2(3408,2088),Vector2(3408,2080),Vector2(3360,2080),Vector2(3360,2072),
		Vector2(3320,2072),Vector2(3320,2064),Vector2(3280,2064),Vector2(3280,2056),Vector2(3240,2056)])
	for index in range(result.size()): result[index] += offset
	return result


static func water_outlines() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = Geometry2D.merge_polygons(pond_outline(),pond_outlet_outline())
	var merged: Array[PackedVector2Array] = []
	for water in result:
		merged.append_array(Geometry2D.merge_polygons(water,river_outline()))
	return merged


static func _draw_water_body(canvas: Node2D, edge: PackedVector2Array, visible: Rect2, textures: Dictionary, elapsed: float) -> void:
	var bounds := Rect2(edge[0],Vector2.ZERO)
	for at in edge: bounds = bounds.expand(at)
	if not bounds.grow(16).intersects(visible): return
	var cliff: PackedVector2Array = []
	for at in edge: cliff.append(at+Vector2(0,10))
	canvas.draw_colored_polygon(cliff,Palette.BANK_DARK)
	canvas.draw_colored_polygon(edge,Palette.BANK)
	canvas.draw_colored_polygon(edge,WATER)
	# The source water tile contains a slight lighting ramp. Repeating it made
	# visible rectangular seams, so the surface uses one continuous blue mass.
	var depth := _turf_outline(World.POND_RECT.grow_individual(-72,-56,-72,-56),37)
	for pocket in Geometry2D.intersect_polygons(edge,depth):
		canvas.draw_colored_polygon(pocket,Color(WATER_DARK,0.10))
	var closed: PackedVector2Array = edge.duplicate()
	closed.append(closed[0])
	canvas.draw_polyline(closed,Color("d5a64b"),5,false)
	for index in range(0,edge.size(),4):
		var at: Vector2 = edge[index]
		if at.y >= World.WORLD_SIZE.y-28 or not visible.has_point(at): continue
		canvas.draw_rect(Rect2(at+Vector2(1,4),Vector2(6,4)),Palette.BANK_DARK)
	# Small reflection clusters are anchored in world space with varied offsets,
	# not the same texture repeated in a rectangular grid.
	var ripples: Rect2 = bounds.intersection(visible)
	for y in range(floori(ripples.position.y/80),ceili(ripples.end.y/80)):
		for x in range(floori(ripples.position.x/80),ceili(ripples.end.x/80)):
			if _cell(x,y)%3 != 0: continue
			var at := Vector2(x*80+18+_cell(x+3,y)%33,y*80+17+_cell(x,y+13)%37)
			if not Geometry2D.is_point_in_polygon(at,edge): continue
			var shift: float = float(int(elapsed*0.5+x+y)%2)*2
			canvas.draw_line(at+Vector2(shift,0),at+Vector2(shift+12,0),Color(WATER_LIGHT,0.65),2,false)
			if _cell(x+7,y)%2 == 0:
				canvas.draw_line(at+Vector2(5,4),at+Vector2(11,4),Color(WATER_LIGHT,0.4),1,false)



static func _draw_pond(canvas: Node2D, elapsed: float, visible: Rect2, textures: Dictionary) -> void:
	_draw_water_body(canvas,pond_outline(),visible,textures,elapsed)


static func fence_segments() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for line in [[80,480,80,960],[80,1248,80,1680],
		[192,1840,576,1840],[960,1840,1248,1840]]:
		result.append(PackedVector2Array([Vector2(line[0],line[1]),Vector2(line[2],line[3])]))
	result.append_array(Nursery.fence_segments())
	return result


static func _draw_fences(canvas: Node2D, visible: Rect2, textures: Dictionary) -> void:
	for segment in fence_segments():
		if segment[0].x >= 1536:
			Nursery.draw_fence(canvas,segment[0],segment[1],visible)
		else:
			_fence(canvas,segment[0],segment[1],visible,textures.get("fence"))


static func _fence(canvas: Node2D, first: Vector2, last: Vector2, visible: Rect2, texture: Texture2D) -> void:
	var vertical: bool = first.x == last.x
	var length: float = first.distance_to(last)
	if vertical:
		var bounds := Rect2(first-Vector2(10,24),Vector2(24,length+32))
		if not bounds.intersects(visible): return
		# Receding rails have two visible faces and thick capped posts, matching
		# the horizontal pickets instead of a single long three-pixel stripe.
		canvas.draw_rect(Rect2(first+Vector2(-6,1),Vector2(18,length+6)),Color(0.18,0.15,0.09,0.16))
		for x in [-5,3]:
			canvas.draw_rect(Rect2(first+Vector2(x,-12),Vector2(6,length+12)),Palette.WOOD)
			canvas.draw_rect(Rect2(first+Vector2(x,-12),Vector2(2,length+12)),Palette.WOOD_LIGHT)
		for step in range(ceili(length/48.0)+1):
			var at: Vector2 = first+Vector2(0,minf(step*48,length))
			canvas.draw_rect(Rect2(at-Vector2(7,22),Vector2(14,28)),Palette.WOOD)
			canvas.draw_rect(Rect2(at-Vector2(5,21),Vector2(5,25)),Palette.WOOD_LIGHT)
			canvas.draw_rect(Rect2(at-Vector2(8,24),Vector2(16,5)),Palette.WOOD_LIGHT)
		return
	for step in range(ceili(length/48)):
		var at: Vector2 = first+(Vector2(0,step*48) if vertical else Vector2(step*48,0))
		var rect := Rect2(at-Vector2(0,24),Vector2(48,32))
		if not rect.intersects(visible): continue
		if texture != null and not vertical: canvas.draw_texture_rect(texture,rect,false)
		else:
			canvas.draw_rect(Rect2(at+Vector2(-2,-18),Vector2(4,23)),Palette.WOOD)
			canvas.draw_rect(Rect2(at+Vector2(-1,-17),Vector2(2,19)),Palette.WOOD_LIGHT)
			if vertical: canvas.draw_rect(Rect2(at+Vector2(0,-2),Vector2(3,48)),Palette.WOOD)


static func _draw_bridge(canvas: Node2D, rect: Rect2, visible: Rect2) -> void:
	if not rect.intersects(visible): return
	canvas.draw_rect(rect,Palette.WOOD)
	for x in range(int(rect.position.x),int(rect.end.x),8):
		canvas.draw_rect(Rect2(x+1,rect.position.y+4,6,rect.size.y-8),Palette.WOOD_LIGHT)
	canvas.draw_rect(Rect2(rect.position,Vector2(rect.size.x,4)),Palette.BANK_DARK)
	canvas.draw_rect(Rect2(Vector2(rect.position.x,rect.end.y-4),Vector2(rect.size.x,4)),Palette.BANK_DARK)


static func _draw_flower_borders(canvas: Node2D, visible: Rect2) -> void:
	# Wild flowers stay beside paths; saved planting rows never borrow decor.
	for at in [Vector2(112,368),Vector2(1216,304),Vector2(1632,624),
		Vector2(3256,1120),Vector2(2208,1808),Vector2(192,2720),Vector2(1248,2624)]:
		if not visible.has_point(at): continue
		for offset in [Vector2(0,0),Vector2(8,-4),Vector2(16,2)]:
			canvas.draw_rect(Rect2(at+offset+Vector2(1,-1),Vector2(2,8)),GRASS_DARK)
			canvas.draw_rect(Rect2(at+offset-Vector2(1,3),Vector2(6,4)),Color("eee4b2"))
			canvas.draw_rect(Rect2(at+offset+Vector2(1,-2),Vector2(2,2)),Color("e4be55"))


static func tree_rects() -> Array[Rect2]:
	var feet: Array[Vector2] = [Vector2(96,224),Vector2(1280,272),
		Vector2(40,720),Vector2(40,1008),Vector2(40,1296),
		Vector2(2016,192),Vector2(2400,192),Vector2(2880,192),Vector2(3360,384),
		Vector2(1680,800),Vector2(1680,1344),Vector2(3360,1008),Vector2(3344,1472),
		Vector2(48,1968),Vector2(1248,2096),Vector2(1632,2016),
		Vector2(2112,2096),Vector2(2304,2016),Vector2(3344,2544),
		Vector2(160,2400),Vector2(1152,2464),Vector2(2016,2656),Vector2(2592,2608)]
	var result: Array[Rect2] = []
	for at in feet: result.append(Rect2(at-Vector2(64,176),Vector2(128,192)))
	return result


static func _draw_orchards(canvas: Node2D, textures: Dictionary, visible: Rect2) -> void:
	var trees: Array[Rect2] = tree_rects()
	for index in range(trees.size()):
		if not trees[index].intersects(visible): continue
		var key: String = "tree_pink" if index in [13,16] else "tree_pine" if index in [3,8,11,18] else "tree_round"
		var texture: Texture2D = textures.get(key,textures.get("tree"))
		if texture != null:
			canvas.draw_ellipse(Vector2(trees[index].get_center().x,trees[index].end.y-7),trees[index].size.x*0.30,7,Color(0.13,0.28,0.17,0.16))
			_sprite(canvas,texture,trees[index])
	var bush: Texture2D = textures.get("bush",textures.get("flower_bush"))
	if bush == null: return
	for at in [Vector2(48,1440),Vector2(1296,368),Vector2(1856,1256),
		Vector2(160,2112),Vector2(1184,2656),Vector2(1376,2592)]:
		var rect := Rect2(at-Vector2(24,24),Vector2(56,40))
		if rect.intersects(visible): _sprite(canvas,bush,rect)


static func _draw_pond_details(canvas: Node2D, textures: Dictionary, visible: Rect2) -> void:
	for at in [Vector2(2736,1184),Vector2(3188,1168),Vector2(2688,1432),Vector2(3200,1504)]:
		at += Vector2(0,World.POND_RECT.position.y-1152)
		if not Rect2(at-Vector2(12,32),Vector2(40,48)).intersects(visible): continue
		for index in range(3):
			canvas.draw_rect(Rect2(at+Vector2(index*6,-18-index%2*8),Vector2(2,28)),GRASS_DARK)
			canvas.draw_rect(Rect2(at+Vector2(index*6+1,-18-index%2*8),Vector2(2,14)),GRASS_LIGHT)
	if textures.has("bench") and POND_BENCH_RECT.intersects(visible):
		_sprite(canvas,textures["bench"],POND_BENCH_RECT)


static func _sprite(canvas: Node2D, texture: Texture2D, rect: Rect2) -> void:
	var factor: float = minf(rect.size.x/texture.get_width(),rect.size.y/texture.get_height())
	var dimensions: Vector2 = (texture.get_size()*factor).floor()
	canvas.draw_texture_rect(texture,Rect2(Vector2(rect.get_center().x-dimensions.x/2,rect.end.y-dimensions.y).floor(),dimensions),false)


static func _cell(x: int, y: int) -> int:
	return absi((x*37+y*71+x*y*3)%101)


static func draw_minimap(canvas: Node2D, rect: Rect2) -> void:
	canvas.draw_rect(rect,GRASS)
	var state = canvas.get("state")
	for area in ["home","nursery"]:
		for block in Grid.block_rects(area):
			var mini := Rect2(rect.position+block.position/World.WORLD_SIZE*rect.size,block.size/World.WORLD_SIZE*rect.size)
			canvas.draw_rect(mini,Color("8fa34e"),false,1.0)
		if state != null:
			for planted in Experience.soil_cells(state,area): _mini_rect(canvas,rect,planted,Color("b18a4e"))
	for outline in greenhouse_ground_polygons(): _mini_polygon(canvas,rect,outline,Color("b6a069"))
	for outline in path_polygons(_has_equipment(canvas)): _mini_polygon(canvas,rect,outline,PATH)
	for outline in water_outlines():
		var points := PackedVector2Array()
		for at in outline: points.append(rect.position+at/World.WORLD_SIZE*rect.size)
		canvas.draw_colored_polygon(points,WATER)
	_mini_rect(canvas,rect,World.NURSERY_RECT,Color("547739"))
	_mini_rect(canvas,rect,World.GREENHOUSE_RECT,Color("95c5c0"))
	_mini_rect(canvas,rect,World.COTTAGE_RECT,Color("bc7044"))


static func _mini_polygon(canvas: Node2D, rect: Rect2, outline: PackedVector2Array, color: Color) -> void:
	var points := PackedVector2Array()
	for at in outline: points.append(rect.position+at/World.WORLD_SIZE*rect.size)
	canvas.draw_colored_polygon(points,color)


static func _mini_rect(canvas: Node2D, minimap: Rect2, world: Rect2, color: Color) -> void:
	canvas.draw_rect(Rect2(minimap.position+world.position/World.WORLD_SIZE*minimap.size,world.size/World.WORLD_SIZE*minimap.size),color)
