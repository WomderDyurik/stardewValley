class_name GardenMaterials
extends RefCounted

## Small authored pixel patterns: no baked lighting, gradients or smoothing.
## All samples have one world-space phase, including adjacent soil rectangles.
const GRASS_PERIOD := Vector2(384,384)
const EARTH_PERIOD := Vector2(384,384)
const SOIL_PERIOD := Vector2(384,384)
const UV_CACHE_LIMIT: int = 256
static var _textures: Dictionary = {}
static var _uv_cache: Dictionary = {}


static func period(_kind: String) -> Vector2:
	return GRASS_PERIOD


static func _code(x: int, y: int, salt: int = 0) -> int:
	return absi((x*1973+y*9277+salt*26699+x*y*17) ^ (x*97+y*157+salt*733))


static func _pixel_rect(image: Image, rect: Rect2i, color: Color) -> void:
	var clipped: Rect2i = rect.intersection(Rect2i(0,0,image.get_width(),image.get_height()))
	if clipped.has_area(): image.fill_rect(clipped,color)


static func _wrapped_rect(image: Image, rect: Rect2i, color: Color) -> void:
	# Clusters crossing a tile edge continue at the opposite edge. This keeps
	# the meadow seamless without dark rectangular patches at the repeat.
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			image.set_pixel(posmod(x,image.get_width()),posmod(y,image.get_height()),color)


static func _make_pattern(kind: String) -> ImageTexture:
	var image := Image.create(192,192,false,Image.FORMAT_RGBA8)
	var random := RandomNumberGenerator.new()
	random.seed = 19023 if kind == "grass" else 49157
	if kind == "grass":
		image.fill(Color("579f32"))
		for patch in range(100):
			var at := Vector2i(random.randi_range(0,191),random.randi_range(0,191))
			var radius: int = random.randi_range(3,9)
			var shade := Color("509932") if patch%3 else Color("559b35")
			for row in range(-radius,radius+1):
				var half: int = maxi(1,radius-absi(row)/2-random.randi_range(0,2))
				_wrapped_rect(image,Rect2i(at+Vector2i(-half,row),Vector2i(half*2,1)),shade)
		for leaf in range(2200):
			var x: int = random.randi_range(0,191)
			var y: int = random.randi_range(0,191)
			var shade := Color("78b83c") if leaf%3 else Color("458c32")
			_wrapped_rect(image,Rect2i(x,y,1,random.randi_range(1,3)),shade)
			if leaf%4 == 0: _wrapped_rect(image,Rect2i(x+1,y-1,1,1),Color("92c44b"))
	elif kind == "stone":
		image.fill(Color("edbd54"))
		# Gray fieldstones vary in width and bevel. Gold soil remains visible
		# between chamfered edges; courses never form a modern brick bond.
		for row in range(16):
			var x: int = -random.randi_range(2,13)
			while x < 192:
				var width: int = random.randi_range(12,19)
				var y: int = row*12+random.randi_range(0,1)
				var height: int = random.randi_range(8,9)
				var face: Color = [Color("aaa184"),Color("b0a585"),Color("a29b80"),Color("b7aa88")][random.randi_range(0,3)]
				_pixel_rect(image,Rect2i(x+2,y+1,width-4,height+1),Color("c49b4a"))
				_pixel_rect(image,Rect2i(x+1,y+2,width-2,height-1),Color("8b846b"))
				_pixel_rect(image,Rect2i(x+2,y+2,width-4,height-2),face)
				_pixel_rect(image,Rect2i(x+2,y+1,width-4,1),Color("c9b990"))
				_pixel_rect(image,Rect2i(x+1,y+2,1,height-2),Color("b6aa88"))
				if width%3 == 0: _pixel_rect(image,Rect2i(x+width-4,y+3,1,1),Color("9e967c"))
				x += width
	elif kind == "soil":
		image.fill(Color("a46a33"))
		for row in range(24):
			for column in range(24):
				var code: int = _code(column,row,31)
				var at := Vector2i(column*8+code%5,row*8+(code/9)%5)
				_pixel_rect(image,Rect2i(at,Vector2i(2+code%3,1)),Color("91572e") if code%2 else Color("b87c3b"))
				if code%5 == 0: _pixel_rect(image,Rect2i(at+Vector2i(1,1),Vector2i(2,1)),Color("a97035"))
	else:
		image.fill(Color("edbd54"))
		for row in range(32):
			for column in range(32):
				var code: int = _code(column,row,43)
				if code%3: continue
				var at := Vector2i(column*6+code%4,row*6+(code/7)%4)
				_pixel_rect(image,Rect2i(at,Vector2i(2+code%2,1)),Color("d9aa48") if code%2 else Color("f6cc68"))
	return ImageTexture.create_from_image(image)


static func texture(kind: String) -> CanvasTexture:
	if not _textures.has(kind):
		var material := CanvasTexture.new()
		material.diffuse_texture = _make_pattern(kind)
		material.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		material.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_textures[kind] = material
	return _textures[kind]


static func uvs(polygon: PackedVector2Array, kind: String, cache: bool = true) -> PackedVector2Array:
	var key: int = hash([polygon,kind])
	if cache and _uv_cache.has(key): return _uv_cache[key]
	var result := PackedVector2Array()
	for point in polygon: result.append(point/period(kind))
	if cache:
		if _uv_cache.size() >= UV_CACHE_LIMIT: _uv_cache.clear()
		_uv_cache[key] = result
	return result


static func draw(canvas: Node2D, polygon: PackedVector2Array, kind: String, tint: Color = Color.WHITE) -> void:
	if polygon.size() >= 3: canvas.draw_colored_polygon(polygon,tint,uvs(polygon,kind),texture(kind))


static func draw_rect(canvas: Node2D, rect: Rect2, kind: String, tint: Color = Color.WHITE) -> void:
	var polygon := PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	canvas.draw_colored_polygon(polygon,tint,uvs(polygon,kind,false),texture(kind))
