class_name PlantVisuals
extends RefCounted

## Individual planting maturity is visible in the world and in battle. All
## additions stay inside the caller's checked sprite footprint.
const MAX_LEVEL: int = 20
const DEFENSE_STAGE_LEVELS: Array[int] = [1, 7, 15]
const LEAF = Color("6e963c")
const LEAF_LIGHT = Color("a9bd55")
const WOOD = Color("67442b")
const WOOD_LIGHT = Color("b88c4f")
const GOLD = Color("e2b555")
const GOLD_DARK = Color("9b7134")
static var _compact_level_fonts: Dictionary = {}


static func compact_level_font(base: Font) -> Font:
	# Digit-only tags keep the real eleven-pixel glyphs. Nunito's empty top and
	# bottom line margins are removed so the complete number fits a 14px tag.
	if not _compact_level_fonts.has(base):
		var face := FontVariation.new()
		face.base_font = base
		face.spacing_top = -2
		face.spacing_bottom = -2
		_compact_level_fonts[base] = face
	return _compact_level_fonts[base]

const DEFENSE_TEXTURES = {
	"lotus": [
		preload("res://assets/pixel/botanical_refresh/lotus_1.tres"),
		preload("res://assets/pixel/botanical_refresh/lotus_2.tres"),
		preload("res://assets/pixel/botanical_refresh/lotus_3.tres"),
	],
	"nettle": [
		preload("res://assets/pixel/botanical_refresh/nettle_1.tres"),
		preload("res://assets/pixel/botanical_refresh/nettle_2.tres"),
		preload("res://assets/pixel/botanical_refresh/nettle_3.tres"),
	],
	"lavender": [
		preload("res://assets/pixel/botanical_refresh/lavender_1.tres"),
		preload("res://assets/pixel/botanical_refresh/lavender_2.tres"),
		preload("res://assets/pixel/botanical_refresh/lavender_3.tres"),
	],
	"pepper": [
		preload("res://assets/pixel/botanical_refresh/pepper_1.tres"),
		preload("res://assets/pixel/botanical_refresh/pepper_2.tres"),
		preload("res://assets/pixel/botanical_refresh/pepper_3.tres"),
	],
}


const CROP_TEXTURES = {
	"tomato": preload("res://assets/pixel/botanical_refresh/tomato.tres"),
	"marigold": preload("res://assets/pixel/botanical_refresh/marigold.tres"),
	"cucumber": preload("res://assets/pixel/botanical_refresh/cucumber.tres"),
	"strawberry": preload("res://assets/pixel/botanical_refresh/strawberry.tres"),
	"currant": preload("res://assets/pixel/botanical_refresh/currant.tres"),
	"mint": preload("res://assets/pixel/botanical_refresh/mint.tres"),
	"pumpkin": preload("res://assets/pixel/botanical_refresh/pumpkin.tres"),
	"waterlily": preload("res://assets/pixel/botanical_refresh/waterlily.tres"),
}


static func defense_stage(level: int) -> int:
	if level >= DEFENSE_STAGE_LEVELS[2]:
		return 3
	if level >= DEFENSE_STAGE_LEVELS[1]:
		return 2
	return 1


static func defense_next_milestone(kind: String, level: int) -> Dictionary:
	if not DEFENSE_TEXTURES.has(kind):
		return {}
	var safe_level: int = clampi(level, 1, MAX_LEVEL)
	for index in range(1, DEFENSE_STAGE_LEVELS.size()):
		var milestone: int = DEFENSE_STAGE_LEVELS[index]
		if safe_level < milestone:
			return {"level": milestone, "stage": index + 1, "label": defense_label(kind, milestone)}
	return {}


static func defense_texture(kind: String, level: int) -> Texture2D:
	if not DEFENSE_TEXTURES.has(kind):
		return null
	return DEFENSE_TEXTURES[kind][defense_stage(level) - 1]


static func defense_label(kind: String, level: int) -> String:
	if not DEFENSE_TEXTURES.has(kind):
		return ""
	if defense_stage(level) == 3:
		return "Два ствола"
	if kind == "lavender":
		return "Малая мортира" if defense_stage(level) == 1 else "Крупная мортира"
	return "Малая пушка" if defense_stage(level) == 1 else "Крупная пушка"


static func defense_sprite_rect(kind: String, level: int, bounds: Rect2) -> Rect2:
	if not DEFENSE_TEXTURES.has(kind) or bounds.size.x < 2.0 or bounds.size.y < 2.0:
		return Rect2()
	# Maturity grows steadily across the full chapter without resetting when a
	# new weapon is unlocked. Square cells preserve each cannon's proportions.
	var progress: float = float(clampi(level, 1, MAX_LEVEL) - 1) / float(MAX_LEVEL - 1)
	var maturity: float = lerpf(0.94, 1.0, progress)
	var side: float = floorf(minf(bounds.size.x, bounds.size.y) * maturity)
	var size: Vector2 = Vector2.ONE * side
	var at: Vector2 = Vector2(bounds.get_center().x - side / 2.0, bounds.end.y - side).floor()
	at = at.clamp(bounds.position, bounds.end - size)
	return Rect2(at, size)


static func weapon_muzzles(kind: String, level: int, bounds: Rect2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var sprite: Rect2 = defense_sprite_rect(kind, level, bounds)
	if not sprite.has_area():
		return result
	var stage: int = defense_stage(level)
	# Ratios are measured on the refreshed alpha-tight virtual frames. Firing
	# originates in the actual dark bore instead of the crown above the weapon.
	var origins: Dictionary = {
		"nettle": [[Vector2(0.81,0.68)],[Vector2(0.88,0.75)],[Vector2(0.72,0.73),Vector2(0.92,0.66)]],
		"lavender": [[Vector2(0.85,0.71)],[Vector2(0.91,0.79)],[Vector2(0.76,0.80),Vector2(0.96,0.70)]],
		"pepper": [[Vector2(0.84,0.65)],[Vector2(0.89,0.71)],[Vector2(0.75,0.70),Vector2(0.94,0.62)]],
		"lotus": [[Vector2(0.88,0.75)],[Vector2(0.89,0.80)],[Vector2(0.72,0.83),Vector2(0.92,0.73)]],
	}
	var ratios: Array = origins[kind][stage-1]

	for ratio in ratios:
		result.append(sprite.position + sprite.size * ratio)
	return result


static func draw(canvas: Node2D, texture: Texture2D, rect: Rect2, kind: String, level: int, show_badge: bool = true, portable_water: bool = false) -> void:
	if texture == null or rect.size.x < 2.0 or rect.size.y < 2.0:
		return
	var safe_level: int = clampi(level, 1, MAX_LEVEL)
	if portable_water and kind in ["waterlily", "lotus"]:
		draw_water_bowl(canvas, rect)
	var weapon_texture: Texture2D = defense_texture(kind, safe_level)
	if weapon_texture != null:
		var frame: Rect2 = defense_sprite_rect(kind, safe_level, rect)
		_draw_contact_shadow(canvas, rect, frame.size.x * 0.74)
		canvas.draw_texture_rect(weapon_texture, frame, false)
		_draw_bores(canvas, kind, safe_level, rect)
		if show_badge:
			draw_level(canvas, rect, safe_level)
		return
	var botanic: Texture2D = CROP_TEXTURES.get(kind, texture)
	var grown: Rect2 = _sprite_rect(botanic, rect, safe_level)
	_draw_contact_shadow(canvas, rect, grown.size.x * 0.80)
	canvas.draw_texture_rect(botanic, grown, false)
	if show_badge:
		draw_level(canvas, rect, safe_level)


static func _draw_bores(canvas: Node2D, kind: String, level: int, bounds: Rect2) -> void:
	var sprite: Rect2 = defense_sprite_rect(kind, level, bounds)
	var radius: float = maxf(1.0, floorf(sprite.size.x * 0.025))
	for origin in weapon_muzzles(kind, level, bounds):
		# Two simple contrast pixels remain legible when a level-one brass nozzle
		# is reduced for the garden camera. They sit on the real atlas muzzle.
		canvas.draw_circle(origin.floor(), radius + 0.8, Color("ebca82"))
		canvas.draw_circle(origin.floor() + Vector2(0, 0.5), radius, Color("463e30"))


static func garden_plant_rect(cell: Rect2) -> Rect2:
	# One silhouette stays inside one cell. Its root line leaves the bottom
	# corner free for a compact fixed-screen level tag even at minimum zoom.
	return Rect2(cell.position+Vector2(8,8),Vector2(minf(80,cell.size.x-16),minf(60,cell.size.y-16)))


static func draw_garden_plant(canvas: Node2D, texture: Texture2D, cell: Rect2, kind: String, level: int, growth: float = 1.0) -> void:
	var frame: Rect2 = garden_plant_rect(cell)
	if DEFENSE_TEXTURES.has(kind) or kind == "waterlily" or growth >= 1.0:
		draw(canvas,texture,frame,kind,level,false)
	else:
		_draw_growing_crop(canvas,frame,kind,clampf(growth,0.0,1.0))


static func draw_crop_rows(canvas: Node2D, texture: Texture2D, cell: Rect2, kind: String, level: int, growth: float = 1.0) -> void:
	# Compatibility entry point: it can never recreate the former six copies.
	draw_garden_plant(canvas,texture,cell,kind,level,growth)


static func crop_rects(cell: Rect2, kind: String) -> Array[Rect2]:
	return [garden_plant_rect(cell)]


static func _draw_growing_crop(canvas: Node2D, rect: Rect2, kind: String, growth: float) -> void:
	var root: Vector2 = Vector2(rect.get_center().x,rect.end.y-1).floor()
	var leafy: float = clampf((growth-0.18)/0.82,0.0,1.0)
	var height: float = floorf(7.0+leafy*(25.0 if kind in ["tomato","cucumber","currant"] else 19.0))
	_draw_contact_shadow(canvas,rect,12.0+leafy*12.0)
	if kind in ["tomato","cucumber"] and growth >= 0.18:
		canvas.draw_rect(Rect2(root+Vector2(-1,-34),Vector2(2,34)),Color("9e7547"))
		canvas.draw_rect(Rect2(root+Vector2(-2,-34),Vector2(1,34)),Color("65492f"))
	canvas.draw_rect(Rect2(root+Vector2(-1,-height),Vector2(2,height)),Color("3f7834"))
	var pairs: int = 1 if growth < 0.18 else 2 if growth < 0.48 else 3
	for pair in range(pairs):
		var at: Vector2 = root+Vector2(0,-height+pair*height/float(pairs+1)+2)
		var width: float = floorf(5.0+leafy*6.0-pair*0.5)
		for direction in [-1,1]:
			var leaf := PackedVector2Array([at,at+Vector2(direction*width,-4),at+Vector2(direction*(width+1),-1),at+Vector2(direction*(width-2),3),at+Vector2(direction*2,2)])
			canvas.draw_colored_polygon(leaf,Color("3e7133"))
			canvas.draw_line(at+Vector2(direction*2,0),at+Vector2(direction*(width-1),-2),Color("91b951"),2,false)


static func _draw_contact_shadow(canvas: Node2D, rect: Rect2, width: float) -> void:
	var center := Vector2(rect.get_center().x, rect.end.y - maxf(2.0, rect.size.y * 0.04))
	var radius := Vector2(minf(rect.size.x * 0.48, width / 2.0), minf(5.0, rect.size.y * 0.06))
	var points := PackedVector2Array()
	for index in range(16):
		var angle: float = index * TAU / 16.0
		points.append((center + Vector2(cos(angle), sin(angle)) * radius).floor())
	canvas.draw_colored_polygon(points, Color(0.17, 0.23, 0.17, 0.18))


static func draw_level(canvas: Node2D, rect: Rect2, level: int) -> void:
	if rect.size.x < 18.0 or rect.size.y < 14.0:
		return
	var safe_level: int = clampi(level, 1, MAX_LEVEL)
	var badge_size = Vector2(minf(30.0, rect.size.x), minf(22.0, rect.size.y))
	var badge = Rect2(rect.end - badge_size, badge_size)
	canvas.draw_rect(badge, WOOD)
	canvas.draw_rect(badge.grow(-1.0), GOLD if safe_level >= 5 else Color("edd7a0"))
	canvas.draw_rect(Rect2(badge.position + Vector2(2, 2), Vector2(badge.size.x - 4, 1)), Color("fff0bf"))
	if canvas.has_method("_center"):
		canvas.call("_center", badge.grow(-1.0), str(safe_level), 12, Color("493528"), canvas.get("bold"))
	else:
		var default_font: Font = ThemeDB.fallback_font
		var label: String = str(safe_level)
		var text_size: Vector2 = default_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		canvas.draw_string(default_font, badge.get_center() + Vector2(-text_size.x / 2.0, 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("493528"))


static func _sprite_rect(texture: Texture2D, rect: Rect2, level: int) -> Rect2:
	var maturity: float = lerpf(0.91, 1.0, float(clampi(level, 1, MAX_LEVEL) - 1) / float(MAX_LEVEL - 1))
	var available: Vector2 = rect.size * maturity
	var factor: float = minf(available.x / texture.get_width(), available.y / texture.get_height())
	var size: Vector2 = (texture.get_size() * factor).floor().max(Vector2.ONE)
	# Stable roots make upgrades visibly grow upward instead of shifting plants.
	var at: Vector2 = Vector2(rect.get_center().x - size.x / 2.0, rect.end.y - size.y).floor()
	at = at.clamp(rect.position, rect.end - size)
	return Rect2(at, size)


static func draw_water_bowl(canvas: Node2D, rect: Rect2) -> void:
	var center: Vector2 = Vector2(rect.get_center().x, rect.end.y - rect.size.y * 0.13)
	var size: Vector2 = Vector2(rect.size.x * 0.92, rect.size.y * 0.23)
	var bowl := Rect2(center - size / 2, size)
	canvas.draw_style_box(_water_style(Color("654a32")), bowl)
	canvas.draw_style_box(_water_style(Color("74b9c1")), bowl.grow(-2))


static func _water_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(10)
	return style
