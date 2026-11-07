class_name GardenWorld
extends RefCounted

## Persistent garden geography and a camera expressed in the game's logical
## canvas coordinates. The map viewport is independent of the fixed HUD.
const Grid = preload("res://scripts/garden_grid.gd")
const WORLD_SIZE: Vector2 = Vector2(3600, 2880)
const WORLD_RECT: Rect2 = Rect2(Vector2.ZERO, WORLD_SIZE)
const MAP_VIEW: Rect2 = Rect2(0, 100, 540, 724)
const ZOOM_MIN: float = 0.5
const ZOOM_MAX: float = 1.35
const DEFAULT_ZOOM: float = 0.8
const PLOT_SIZE := Vector2(96,96)
const PLOT_VISUAL_SIZE := Vector2(96,96)
const POND_PLOT_SIZE := Vector2(96,96)
const COTTAGE_RECT = Grid.COTTAGE_RECT
const NURSERY_RECT = Grid.NURSERY_RECT
const GREENHOUSE_RECT = Grid.GREENHOUSE_RECT
const POND_RECT = Grid.POND_RECT
const GATE_RECT = Grid.GATE_RECT
const GATE_ART_RECT = Grid.GATE_ART_RECT
const BENCH_RECTS: Array[Rect2] = [Grid.POND_BENCH_RECT]
const PROP_RECTS: Dictionary = {
	"mailbox":Rect2(576,280,28,68),
	"porch_chest":Rect2(536,336,56,48),
	"caretaker":Rect2(374,368,42,70),
	"porch_barrel":Rect2(152,320,32,40),
	"scarecrow_west":Rect2(48,1120,48,96),
	"scarecrow_east":Rect2(1360,1824,48,96),
	"garden_can":Rect2(1176,360,34,39),
	"garden_barrel":Rect2(1128,352,36,44),
	"nursery_barrel":Rect2(1944,224,32,40),"nursery_can":Rect2(1984,232,24,32),
	"nursery_hen":Rect2(1728,528,32,40),"nursery_hen_west":Rect2(1616,624,32,40),
	"nursery_lantern":Rect2(1560,384,24,72),"nursery_lantern_south":Rect2(1872,1760,24,72),
	"greenhouse_barrel":Rect2(984,2352,48,60),"greenhouse_can":Rect2(608,2344,47,55),
}
const SIGN_RECTS: Dictionary = {
	"nursery":Rect2(2304,1744,192,32),
	"greenhouse":Rect2(576,2424,192,32),
	"pond":Rect2(2496,1952,192,32),
}
const POND_LOCK_RECT := Rect2(2796,1971,360,90)
const DISTRICT_DATA: Array[Dictionary] = [
	{"id":"garden","name":"Огород","center":Vector2(480,624),"bounds":Rect2(96,0,1440,2208),"description":"Сад у дома: четыре квадрата 6×6."},
	{"id":"nursery","name":"Питомник","center":Vector2(1952,544),"bounds":Rect2(1536,0,1824,2208),"description":"Защитники: четыре квадрата 6×6 и водные грядки."},
	{"id":"greenhouse","name":"Теплица","center":Vector2(624,2448),"bounds":Rect2(96,2208,3264,672),"description":"Улучшения полива, подкормки и хранения урожая."},
]
const ACTIVE_HOME_PLOTS: int = 144
const ACTIVE_NURSERY_PLOTS: int = 144
const GARDEN_FLOOR := Rect2(192,480,1248,1248)
const NURSERY_FLOOR := Rect2(1920,384,1248,1248)
const POND_CENTER := Vector2(2976,2016)
# Saved planting indices keep their identities while their world addresses move.
static var PLOT_CENTERS: Array[Vector2] = Grid.centers("home")
static var NURSERY_PLOT_CENTERS: Array[Vector2] = Grid.centers("nursery")
static var POND_PLOT_CENTERS: Array[Vector2] = Grid.centers("pond")


static func building_hit_regions() -> Dictionary:
	# World-space, exact building/gate bounds. The greenhouse no longer owns
	# the wider yard rectangle that previously intercepted cucumber beds.
	return {"collect":COTTAGE_RECT,"nursery":NURSERY_RECT,"greenhouse":GREENHOUSE_RECT,"gate":GATE_RECT}


static func pond_plot_rect(index: int) -> Rect2:
	if index < 0 or index >= POND_PLOT_CENTERS.size():
		return Rect2()
	return Grid.planting_rect("pond",index)


static func nursery_plot_district(index: int) -> String:
	if index < 0 or index >= NURSERY_PLOT_CENTERS.size():
		return ""
	return "nursery"


static func plot_style(area: String, index: int) -> String:
	if area == "pond":
		return "water"
	if area == "nursery":
		return "nursery"
	return "vegetable"




static func nursery_plot_rect(index: int) -> Rect2:
	if index < 0 or index >= NURSERY_PLOT_CENTERS.size():
		return Rect2()
	return Grid.planting_rect("nursery",index)


static func expansion_regions() -> Array[Dictionary]:
	# Former regions have no active map surfaces or discovery notices.
	return []


static func plot_district(index: int) -> String:
	if index < 0 or index >= PLOT_CENTERS.size():
		return ""
	return "garden"


static func planting_floor(index: int) -> Rect2:
	if index < 0 or index >= PLOT_CENTERS.size():
		return Rect2()
	return Grid.block_rects("home")[Grid.block_index("home",index)]


# Use set_center/set_zoom or gesture methods when changing the camera, so the
# visible area always remains inside WORLD_RECT.
var center: Vector2 = Vector2(480,624)
var zoom: float = DEFAULT_ZOOM
var _navigation_focus: Vector2 = Vector2(480,624)


func _init() -> void:
	clamp_camera()


static func districts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for data in DISTRICT_DATA:
		result.append(data.duplicate(true))
	return result


static func subarea(id: String) -> Dictionary:
	if id == "pond":
		return {"id":"pond","parent":"nursery","name":"Водные грядки питомника","center":POND_CENTER,"bounds":POND_RECT}
	return {}


static func district(id: String) -> Dictionary:
	# Water remains an explicit shortcut inside the second planting district.
	if id == "pond":
		var parent: Dictionary = district("nursery")
		parent["center"] = POND_CENTER
		return parent
	for data in DISTRICT_DATA:
		if data["id"] == id:
			return data.duplicate(true)
	return {}


static func district_at(world_position: Vector2) -> Dictionary:
	for data in DISTRICT_DATA:
		var bounds: Rect2 = data["bounds"]
		if bounds.has_point(world_position):
			return data.duplicate(true)
	return {}


func focus_district(id: String) -> bool:
	var data: Dictionary = district(id)
	if data.is_empty():
		return false
	_navigation_focus = data["center"]
	center = _navigation_focus
	clamp_camera()
	return true


func current_district() -> Dictionary:
	# A small zoom can force the viewport center outside the place the player
	# chose. Its semantic focus follows actual panning, not boundary clamping.
	return district_at(_navigation_focus)


func navigation_context() -> Dictionary:
	return {"focus": _navigation_focus}


func restore_navigation_context(payload: Dictionary) -> void:
	var focus: Variant = payload.get("focus")
	if focus is Vector2 and focus.is_finite():
		if focus.y >= WORLD_SIZE.y:
			focus_district("greenhouse")
		else:
			_navigation_focus = focus.clamp(Vector2.ZERO, WORLD_SIZE)


func world_to_screen(world_position: Vector2) -> Vector2:
	return MAP_VIEW.get_center() + (world_position - center) * zoom


func screen_to_world(screen_position: Vector2) -> Vector2:
	return center + (screen_position - MAP_VIEW.get_center()) / zoom


func visible_world_rect() -> Rect2:
	var size: Vector2 = MAP_VIEW.size / zoom
	return Rect2(center - size / 2.0, size)


func pan_screen(delta: Vector2) -> void:
	if not delta.is_finite():
		return
	var before: Vector2 = center
	center -= delta / zoom
	clamp_camera()
	_navigation_focus = (_navigation_focus + center - before).clamp(Vector2.ZERO, WORLD_SIZE)


func zoom_at(factor: float, screen_anchor: Vector2) -> void:
	if not is_finite(factor) or factor <= 0.0 or not screen_anchor.is_finite():
		return
	var anchored_world_point: Vector2 = screen_to_world(screen_anchor)
	zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	center = anchored_world_point - (screen_anchor - MAP_VIEW.get_center()) / zoom
	clamp_camera()


func set_zoom(value: float) -> void:
	if not is_finite(value):
		return
	zoom = clampf(value, ZOOM_MIN, ZOOM_MAX)
	clamp_camera()


func set_center(value: Vector2) -> void:
	if not value.is_finite():
		return
	if value.y >= WORLD_SIZE.y:
		focus_district("greenhouse")
		return
	_navigation_focus = value.clamp(Vector2.ZERO, WORLD_SIZE)
	center = value
	clamp_camera()


func clamp_camera() -> void:
	if not is_finite(zoom):
		zoom = DEFAULT_ZOOM
	zoom = clampf(zoom, ZOOM_MIN, ZOOM_MAX)
	if not center.is_finite():
		center = WORLD_SIZE / 2.0
	var half_view: Vector2 = MAP_VIEW.size / (2.0 * zoom)
	center.x = _clamp_axis(center.x, half_view.x, WORLD_SIZE.x)
	center.y = _clamp_axis(center.y, half_view.y, WORLD_SIZE.y)


static func _clamp_axis(value: float, half_view: float, extent: float) -> float:
	# The midpoint is also well-defined if a future layout is smaller than the
	# camera's visible area on one axis.
	if half_view * 2.0 >= extent:
		return extent / 2.0
	return clampf(value, half_view, extent - half_view)


static func plot_positions() -> Array[Vector2]:
	return PLOT_CENTERS.duplicate()


static func plot_rect(index: int) -> Rect2:
	if index < 0 or index >= PLOT_CENTERS.size():
		return Rect2()
	return Grid.planting_rect("home",index)


static func plot_visual_rect(index: int) -> Rect2:
	if index < 0 or index >= PLOT_CENTERS.size():
		return Rect2()
	return Grid.planting_rect("home",index)


static func path_anchors() -> Array[PackedVector2Array]:
	return [PackedVector2Array([Vector2(1488,432),Vector2(360,432),Vector2(360,384)]),
	    PackedVector2Array([Vector2(1488,480),Vector2(1776,480)]),
	    PackedVector2Array([Vector2(1488,2544),Vector2(432,2544),Vector2(432,2496)])]
