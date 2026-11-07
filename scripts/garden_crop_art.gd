class_name GardenCropArt
extends RefCounted

## Four stalks depict one real planting, with one saved kind/level/harvest.
## Only the garden uses these low-resolution sprites; battle weapons keep
## their original silhouettes and the three existing development stages.
const Visuals = preload("res://scripts/plant_visuals.gd")
const ECONOMIC_KINDS: Array[String] = ["tomato", "marigold", "cucumber", "strawberry", "currant", "mint", "pumpkin"]
const PIXEL: float = 2.5
const TEXTURE_CACHE_LIMIT: int = 56 # Seven crops × four growth stages × two leaf palettes.
static var _crop_textures: Dictionary = {}
const PALETTE: Dictionary = {
	"o": Color("174527"), "d": Color("236629"), "m": Color("2d8d28"),
	"l": Color("5cb62e"), "h": Color("a1d345"), "s": Color("8d321f"),
	"r": Color("df4224"), "f": Color("ff7940"), "y": Color("edb231"),
	"a": Color("ffe36c"), "b": Color("744729"), "w": Color("ad7a3d"),
	"p": Color("b64b86"), "v": Color("71365f"), "c": Color("a6d653"),
}

## Maps have the same 18×18 source frame, anchored on the last root pixel.
## Unpainted corners leave the dark soil visible between the crop rows.
const TOMATO: Array[String] = [
	"........bw........",
	"......olhmo.......",
	"...ooolmlmloo.....",
	"..olhmlmlmlhmo....",
	".olmlhlmmlmlmlo...",
	".omllmmllhlmmmo...",
	".olmlsrsmllmlmo...",
	"..ommrrfmmmsrro...",
	"..olmsrmllmrrfo...",
	"...olmlhlmmsrmo...",
	"..olhmllmllmmo....",
	"...ollmllmmmo.....",
	"....ommlmllmo.....",
	".....olmmmo.......",
	"......ommo........",
	".......bw.........",
	"......obwo........",
	"..................",
]
const MARIGOLD: Array[String] = [
	"......oyyo........",
	".....oyayyo.......",
	".....oyayyo.......",
	"...oyyoyyoyyo.....",
	"..oyayyooyayyo....",
	"..oyayyooyayyo....",
	"...oyyomloyyo.....",
	"..oolmlmlmlmoo....",
	".olhlmllmllhlmo...",
	"..odmlmlmlmmdo....",
	"...olmoyyomlmo....",
	"....moyayyommo....",
	"....moyayyomo.....",
	"....omoyyommo.....",
	".....omlmmo.......",
	"......ommo........",
	".......oo.........",
	"..................",
]
const CUCUMBER: Array[String] = [
	"........bw........",
	"...ollo.bw.oo.....",
	"...ollhobwollo....",
	"....ollobwllho....",
	".....odmbwllo.....",
	"..oolmlmbwlo......",
	"..olhlmmbw........",
	"...ollmmbw.oo.....",
	"....odmmbwollo....",
	"......ombwllho....",
	"...oollmbwllo.....",
	"...olhlmbwlo......",
	"....ollmbwo.......",
	".....odmbw........",
	".......mbw........",
	".......mbw........",
	".......obwo.......",
	"..................",
]
const STRAWBERRY: Array[String] = [
	"..................",
	"..................",
	"....oo....oo......",
	"...olmo..olmo.....",
	"..olhlmoomlhlo....",
	"...olmlmmllmo.....",
	"..oolmllmllmoo....",
	".olhlmmmllmhlmo...",
	"..odmllmllmmdo....",
	"...omssmmssmo.....",
	"..oosrrmosrroo....",
	"..olmrfo.orfmlo...",
	"...odso...sdo.....",
	".....omllmmo......",
	"......ommo........",
	".......oo.........",
	"..................",
	"..................",
]
const CURRANT: Array[String] = [
	".......oo.........",
	"......olmo........",
	"....oolhlmoo......",
	"...olmlmmllmo.....",
	"..olhmmmlllmmo....",
	".olmlmlmlmlmlmo...",
	".ommmvvmmvvmmmo...",
	"..omvppmvppmmo....",
	"..olmvpmllvlmo....",
	"..odmlmmllmmmo....",
	"...omvvmmllmo.....",
	"...ovppmmvvmo.....",
	"....ovpmvppo......",
	".....ommovpo......",
	".......bw.........",
	".......bw.........",
	"......obwo........",
	"..................",
]
const MINT: Array[String] = [
	".......oo.........",
	"......olco........",
	"......olco........",
	"...oo..m...oo.....",
	"..olco.m..olco....",
	"..olchomooclmo....",
	"...olcmmmlcmo.....",
	"....odmmmdo.......",
	"..ooo..m..ooo.....",
	".olcloomoolclmo...",
	"..olclmmmllcmo....",
	"...odlmmmlmdo.....",
	".....odmdo........",
	"...oo..m..........",
	"..olcmommo........",
	"...odmlmo.........",
	"......odmo........",
	"..................",
]
const PUMPKIN: Array[String] = [
	"..................",
	".......oo.........",
	"......olmo........",
	"...oolhlmoo.......",
	"..olhlmmllmo......",
	".olhllmmllmmo.....",
	"..odmmllmmdo......",
	"...ommllmmo.......",
	".....obwo.........",
	"....osysyso.......",
	"...osfyfyfso......",
	"..osffyfyffso.....",
	"..osfayfyffso.....",
	"...osfyfyfso......",
	"....ossssso.......",
	"......ommo........",
	".......oo.........",
	"..................",
]
const SPROUT: Array[String] = [
	"..................",
	"..................",
	"..................",
	"..................",
	"..................",
	"..................",
	"..................",
	"..................",
	"..................",
	"..................",
	"..................",
	".....oo...oo......",
	"....olmo.olmo.....",
	".....olmomlo......",
	"......ommo........",
	".......mo.........",
	".......oo.........",
	"..................",
]


static func sprite_rows(kind: String, growth: float = 1.0) -> Array[String]:
	if growth < 0.24: return SPROUT
	return {"tomato":TOMATO, "marigold":MARIGOLD, "cucumber":CUCUMBER,
		"strawberry":STRAWBERRY, "currant":CURRANT, "mint":MINT,
		"pumpkin":PUMPKIN}.get(kind,TOMATO)


static func crop_rects(cell: Rect2, kind: String) -> Array[Rect2]:
	if kind not in ECONOMIC_KINDS: return [Visuals.garden_plant_rect(cell)]
	var result: Array[Rect2] = []
	for row in range(2):
		for column in range(2):
			result.append(Rect2(cell.position+Vector2(column*46,row*46),Vector2(45,45)))
	return result


static func draw(canvas: Node2D, texture: Texture2D, cell: Rect2, kind: String, level: int, growth: float = 1.0) -> void:
	if kind not in ECONOMIC_KINDS:
		Visuals.draw_garden_plant(canvas,texture,cell,kind,level,growth)
		return
	var safe_growth: float = clampf(growth,0.0,1.0)
	var crop: ImageTexture = crop_texture(kind,safe_growth,level)
	for frame in crop_rects(cell,kind):
		# A low, hard-edged contact shadow joins the roots to the furrows.
		canvas.draw_rect(Rect2(frame.position+Vector2(12,39),Vector2(18,4)),Color(0.21,0.20,0.10,0.24))
		canvas.draw_texture_rect(crop,frame,false)


static func growth_stage(growth: float) -> int:
	return 0 if growth < 0.24 else 1 if growth < 0.52 else 2 if growth < 0.94 else 3


static func crop_texture(kind: String, growth: float, level: int) -> ImageTexture:
	# The finite stage/palette key avoids creating a texture for every elapsed
	# growth value. Four textured quads replace hundreds of per-pixel draws.
	var stage: int = growth_stage(growth)
	var developed: bool = level >= 15
	var key: String = "%s:%d:%d" % [kind,stage,int(developed)]
	if _crop_textures.has(key): return _crop_textures[key]
	var rows: Array[String] = sprite_rows(kind,growth)
	var pixels := Image.create(18,18,false,Image.FORMAT_RGBA8)
	pixels.fill(Color.TRANSPARENT)
	for y in range(rows.size()):
		# Young plants have their upper foliage folded down to the lower stem.
		if stage == 1 and y < 7: continue
		for x in range(rows[y].length()):
			var pigment: String = rows[y].substr(x,1)
			if pigment == ".": continue
			if stage != 3 and pigment in ["s","r","f","y","a","p","v"]:
				pigment = "m" if pigment in ["s","r","p","v"] else "l"
			var color: Color = PALETTE[pigment]
			# Upgraded crops gain a few pale leaf facets, without changing kind.
			if developed and pigment == "l" and (x+y*3)%7 == 0: color = PALETTE["h"]
			pixels.set_pixel(x,y,color)
	var result := ImageTexture.create_from_image(pixels)
	# Callers normally pass only the seven economic kinds. The bound also
	# protects the cache if an inspection tool requests an unknown kind.
	if _crop_textures.size() >= TEXTURE_CACHE_LIMIT: _crop_textures.clear()
	_crop_textures[key] = result
	return result
