class_name NurseryCropArt
extends RefCounted

## A nursery planting is one saved defender. Its own stalks fill the soil
## behind one recognisable weapon; weapon upgrades still use the battle art.
const Visuals = preload("res://scripts/plant_visuals.gd")
const Crops = preload("res://scripts/garden_crop_art.gd")
const TALL_KINDS: Array[String] = ["nettle","lavender","pepper"]
const SOURCE_SIZE := Vector2i(18,24)
const STALK_SIZE := Vector2(45,60)
const CACHE_LIMIT: int = 6
static var _foliage_textures: Dictionary = {}
const PALETTE: Dictionary = {
	"o":Color("143f35"), "d":Color("1b6054"), "m":Color("2a8c75"),
	"l":Color("4bb394"), "h":Color("7dcca0"), "b":Color("617c38"),
	"s":Color("58436e"), "p":Color("8f68bd"), "f":Color("c095de"),
	"r":Color("c23f2b"), "y":Color("f17c37"),
}
const NETTLE: Array[String] = [
	"....oo..oo........",
	"...olmo.olmo......",
	"..olhmodllmo.oo...",
	".olhhmmlmlmmolmo..",
	".ollhmllmlmlhlmo..",
	"..ollmlmllmmllmo..",
	"..odmlmllmlmmmo...",
	"...ommlmdlmmlmo...",
	"..olhlmmlmlmlmo...",
	".olhhmllhlmllmmo..",
	".ollmmlmmlmlmmo...",
	"..odmlmmllmmdmo...",
	"..oolmlmmlmmmoo...",
	".olhllmlmlmllmo...",
	".ollmlmllhlmlmmo..",
	"..odmlmmlmmlmmo...",
	"...ommlmdlmmlmo...",
	"..olhlmmlmlmlmo...",
	"..ollmllhlmllmo...",
	"...odlmmlmlmmo....",
	"....odmmllmmo.....",
	".....odmmdo.......",
	".......obo........",
	"........o.........",
]
const LAVENDER: Array[String] = [
	"....ss..ss........",
	"...spfs.spfs.ss...",
	"...spfsspfs.spfs..",
	"..ospfs.sppsspfs..",
	".olmppfssppfspfs..",
	".ollspfs.spfspfo..",
	"..olspfsospfsmo...",
	"..odlpsmmlpsmmo...",
	"...olmlmmlmlmmo...",
	"..olhlmllmmlhlmo..",
	".olhlmllhlmllmmo..",
	"..ollmmlmlmlmmo...",
	"..odmlmllmlmmmo...",
	".olhllmlmlmllmo...",
	".ollmlmllhlmlmmo..",
	"..odmlmmlmmlmmo...",
	"...ommlmdlmmlmo...",
	"..olhlmmlmlmlmo...",
	"..ollmllhlmllmo...",
	"...odlmmlmlmmo....",
	"....odmmllmmo.....",
	".....odmmdo.......",
	".......obo........",
	"........o.........",
]
const PEPPER: Array[String] = [
	".......oo.........",
	"....oo.olmo.oo....",
	"...olmodllmolmo...",
	"..olhmlmlmlhlmo...",
	".olhhmllmlmllmmo..",
	".ollmmlmlmlmllmo..",
	"..omrorllmlmmmo...",
	"..omryomdlmmlmo...",
	"...orommlmlmlmo...",
	"..olhlmllmllhlmo..",
	".olhmmllhlmllmmo..",
	"..ollmmlmlmlmmo...",
	"..odmlmllmlmmmo...",
	".olhllmlmlmllmo...",
	".ollmlmllmrormmo..",
	"..odmlmmlmryomo...",
	"...ommlmdmrommo...",
	"..olhlmmlmlmlmo...",
	"..ollmllhlmllmo...",
	"...odlmmlmlmmo....",
	"....odmmllmmo.....",
	".....odmmdo.......",
	".......obo........",
	"........o.........",
]


static func reserved_level_rect(cell: Rect2) -> Rect2:
	# A fixed 18×14 logical tag occupies this much world space at zoom 0.5.
	return Rect2(cell.end-Vector2(36,28),Vector2(36,28))


static func foliage_rects(cell: Rect2, kind: String) -> Array[Rect2]:
	if kind not in TALL_KINDS: return []
	return [Rect2(cell.position,STALK_SIZE),
		Rect2(cell.position+Vector2(50,0),STALK_SIZE),
		Rect2(cell.position+Vector2(4,34),STALK_SIZE)]


static func weapon_bounds(cell: Rect2, kind: String) -> Rect2:
	if kind not in TALL_KINDS: return Visuals.garden_plant_rect(cell)
	# All of the weapon, muzzle highlights and its low contact shadow end
	# above the level corner. The near-left stalk can extend below this line.
	return Rect2(cell.position+Vector2(12,12),Vector2(76,54))


static func legacy_crop_rects(cell: Rect2) -> Array[Rect2]:
	# Earlier saves may hold an economic culture here. Keep that exact kind,
	# while leaving the larger minimum-zoom level corner free for its label.
	return [Rect2(cell.position,Vector2(45,45)),
		Rect2(cell.position+Vector2(50,0),Vector2(45,45)),
		Rect2(cell.position+Vector2(4,46),Vector2(45,45))]


static func footprints(cell: Rect2, kind: String) -> Array[Rect2]:
	if kind in Crops.ECONOMIC_KINDS: return legacy_crop_rects(cell)
	var result: Array[Rect2] = foliage_rects(cell,kind)
	result.append(weapon_bounds(cell,kind).grow(2) if kind in TALL_KINDS else weapon_bounds(cell,kind))
	return result


static func sprite_rows(kind: String) -> Array[String]:
	return LAVENDER if kind == "lavender" else PEPPER if kind == "pepper" else NETTLE


static func foliage_texture(kind: String, level: int) -> ImageTexture:
	var canonical: String = kind if kind in TALL_KINDS else "nettle"
	var developed: bool = level >= 15
	var key: String = "%s:%d" % [canonical,int(developed)]
	if _foliage_textures.has(key): return _foliage_textures[key]
	var pixels := Image.create(SOURCE_SIZE.x,SOURCE_SIZE.y,false,Image.FORMAT_RGBA8)
	pixels.fill(Color.TRANSPARENT)
	var rows: Array[String] = sprite_rows(canonical)
	for y in range(SOURCE_SIZE.y):
		for x in range(SOURCE_SIZE.x):
			var pigment: String = rows[y].substr(x,1)
			if pigment == ".": continue
			var color: Color = PALETTE[pigment]
			if developed and pigment == "l" and (x+y*3)%9 == 0: color = PALETTE["h"]
			pixels.set_pixel(x,y,color)
	var texture := ImageTexture.create_from_image(pixels)
	if _foliage_textures.size() >= CACHE_LIMIT: _foliage_textures.clear()
	_foliage_textures[key] = texture
	return texture


static func draw(canvas: Node2D, texture: Texture2D, cell: Rect2, kind: String, level: int) -> void:
	if kind in Crops.ECONOMIC_KINDS:
		var legacy: ImageTexture = Crops.crop_texture(kind,1.0,level)
		for frame in legacy_crop_rects(cell):
			canvas.draw_rect(Rect2(frame.position+Vector2(12,39),Vector2(18,4)),Color(0.15,0.23,0.14,0.22))
			canvas.draw_texture_rect(legacy,frame,false)
		return
	if kind not in TALL_KINDS:
		Visuals.draw_garden_plant(canvas,texture,cell,kind,level)
		return
	var foliage: ImageTexture = foliage_texture(kind,level)
	for frame in foliage_rects(cell,kind):
		canvas.draw_rect(Rect2(frame.position+Vector2(13,54),Vector2(19,4)),Color(0.15,0.23,0.14,0.22))
		canvas.draw_texture_rect(foliage,frame,false)
	# This is the existing staged weapon renderer, including the visible bores.
	Visuals.draw(canvas,texture,weapon_bounds(cell,kind),kind,level,false)
