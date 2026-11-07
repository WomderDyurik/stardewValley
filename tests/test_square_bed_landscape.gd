extends SceneTree

## The painted six-by-six fields and visible foliage leave real paving clear.
## Alpha scanlines avoid mistaking transparent sprite corners for obstructions.
const World = preload("res://scripts/garden_world.gd")
const Grid = preload("res://scripts/garden_grid.gd")
const Terrain = preload("res://scripts/garden_terrain.gd")
const Paths = preload("res://scripts/garden_paths.gd")
const Nursery = preload("res://scripts/nursery_environment.gd")
const Art = preload("res://scripts/main.gd")
var checks: int = 0
var failures: int = 0
var paths: Array[PackedVector2Array] = []
var path_bounds: Array[Rect2] = []


func expect(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(reason)


func polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])


func bounds_of(outline: PackedVector2Array) -> Rect2:
	var bounds := Rect2(outline[0],Vector2.ZERO)
	for point in outline: bounds = bounds.expand(point)
	return bounds


func area_of(outline: PackedVector2Array) -> float:
	var twice: float = 0.0
	for index in range(outline.size()): twice += outline[index].cross(outline[(index+1)%outline.size()])
	return absf(twice)*0.5


func overlaps(first: PackedVector2Array, second: PackedVector2Array) -> bool:
	for fragment in Geometry2D.intersect_polygons(first,second):
		if area_of(fragment) > 0.01: return true
	return false


func covered_by(rect: Rect2, surfaces: Array[PackedVector2Array]) -> bool:
	var remaining: Array[PackedVector2Array] = [polygon(rect.grow(-0.01))]
	for surface in surfaces:
		var next: Array[PackedVector2Array] = []
		for fragment in remaining: next.append_array(Geometry2D.clip_polygons(fragment,surface))
		remaining = next
	return remaining.is_empty()


func fitted_frame(texture: Texture2D, frame: Rect2, bottom: bool) -> Rect2:
	var factor: float = minf(frame.size.x/texture.get_width(),frame.size.y/texture.get_height())
	var size: Vector2 = (texture.get_size()*factor).floor()
	var at: Vector2 = Vector2(frame.get_center().x-size.x/2.0,frame.end.y-size.y) if bottom else frame.position+(frame.size-size)/2.0
	return Rect2(at.floor(),size)


func opaque_path_overlap(texture: Texture2D, frame: Rect2) -> int:
	var candidates: Array[int] = []
	for index in range(paths.size()):
		if frame.intersects(path_bounds[index]): candidates.append(index)
	if candidates.is_empty(): return -1
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_error("Cannot inspect sprite alpha")
		return -2
	var pixel: Vector2 = frame.size/Vector2(image.get_width(),image.get_height())
	for row in range(image.get_height()):
		var column: int = 0
		while column < image.get_width():
			if image.get_pixel(column,row).a < 0.25:
				column += 1
				continue
			var start: int = column
			while column < image.get_width() and image.get_pixel(column,row).a >= 0.25: column += 1
			var run := Rect2(frame.position+Vector2(start,row)*pixel,Vector2(column-start,1)*pixel)
			for index in candidates:
				if run.intersects(path_bounds[index]) and overlaps(polygon(run),paths[index]): return index
	return -1


func _initialize() -> void:
	paths = Paths.polygons()
	for path in paths: path_bounds.append(bounds_of(path))
	_check_painted_squares()
	_check_tree_canopies()
	_check_hedges()
	_check_stationary_props()
	print("Square bed landscape: ",checks," checks; ",failures," failures")
	quit(0 if failures == 0 else 1)


func _check_painted_squares() -> void:
	for pair in [["home",Terrain.garden_courtyard_polygons()],["nursery",Terrain.nursery_ground_polygons()]]:
		var area: String = pair[0]
		var surfaces: Array[PackedVector2Array] = pair[1]
		expect(surfaces.size() == 4,area+" paints four separate tilled squares")
		for block in Grid.block_rects(area): expect(covered_by(block,surfaces),area+" paints every cell to its complete edge")
		for soil in surfaces:
			expect(not Geometry2D.triangulate_polygon(soil).is_empty(),area+" soil triangulates")
			for path in paths: expect(not overlaps(soil,path),area+" cultivated soil leaves the entire crossing sidewalk clear")
		for first in range(surfaces.size()):
			for second in range(first): expect(not overlaps(surfaces[first],surfaces[second]),area+" squares remain visibly separated")


func _check_tree_canopies() -> void:
	var trees: Array[Rect2] = Terrain.tree_rects()
	for index in range(trees.size()):
		var key: String = "tree_pink" if index in [13,16] else "tree_pine" if index in [3,8,11,18] else "tree_round"
		var texture: Texture2D = Art.FARM_ART[key]
		var route: int = opaque_path_overlap(texture,fitted_frame(texture,trees[index],true))
		expect(route == -1,"tree canopy %d at %s covers paved route %d" % [index,str(trees[index]),route])


func _check_hedges() -> void:
	var texture: Texture2D = load("res://assets/pixel/nursery_reference/hedge.png")
	for hedge in Nursery.hedge_sprites():
		var route: int = opaque_path_overlap(texture,hedge["rect"])
		expect(route == -1,"hedge at %s covers paved route %d" % [str(hedge["rect"]),route])


func _check_stationary_props() -> void:
	var textures: Dictionary = {
		"mailbox":Art.FARM_ART["mailbox"],"porch_chest":Art.FARM_ART["chest"],
		"porch_barrel":Art.FARM_ART["barrel"],"scarecrow_west":Art.FARM_ART["scarecrow"],"scarecrow_east":Art.FARM_ART["scarecrow"],
		"garden_can":Art.CAN,"garden_barrel":Art.FARM_ART["barrel"],
		"nursery_barrel":Art.FARM_ART["barrel"],"nursery_can":Art.CAN,
		"nursery_lantern":Art.FARM_ART["nursery_lantern"],"nursery_lantern_south":Art.FARM_ART["nursery_lantern"],
		"greenhouse_barrel":Art.FARM_ART["barrel"],"greenhouse_can":Art.CAN,
	}
	# The porch gardener and wandering hens are actors; this check protects the
	# stationary objects that should never narrow a walking route.
	for id in textures:
		var texture: Texture2D = textures[id]
		var route: int = opaque_path_overlap(texture,fitted_frame(texture,World.PROP_RECTS[id],false))
		expect(route == -1,"stationary prop %s covers paved route %d" % [id,route])
