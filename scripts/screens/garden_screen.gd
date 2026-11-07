extends Node

## World objects use the garden camera; navigation and the wallet stay fixed.
const World = preload("res://scripts/garden_world.gd")
const Terrain = preload("res://scripts/garden_terrain.gd")
const Visuals = preload("res://scripts/plant_visuals.gd")
const Crops = preload("res://scripts/garden_crop_art.gd")
const NurseryCrops = preload("res://scripts/nursery_crop_art.gd")
const FarmUi = preload("res://scripts/garden_farm_ui.gd")
const Experience = preload("res://scripts/garden_experience.gd")
const GATE_RECT = World.GATE_RECT


var world_label_layouts: Array[Dictionary] = []
var _level_labels: Array[Dictionary] = []
var _sign_labels: Array[Dictionary] = []


func render(canvas: Node2D) -> void:
	world_label_layouts.clear()
	_level_labels.clear()
	_sign_labels.clear()
	var camera = canvas.garden_world
	var origin: Vector2 = World.MAP_VIEW.get_center() - camera.center * camera.zoom
	canvas.draw_set_transform(origin, 0.0, Vector2.ONE * camera.zoom)
	Terrain.draw(canvas, canvas.elapsed, canvas.FARM_ART)
	_draw_plots(canvas)
	_draw_buildings(canvas)
	_draw_pond(canvas)
	canvas.HelperArt.draw_world(canvas,self)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Experience.draw_moments(canvas)
	_draw_world_labels(canvas)
	canvas._draw_header()
	_draw_navigation(canvas)


func _draw_plots(canvas: Node2D) -> void:
	var cycle: float = maxf(1.0,float(canvas.state.home_cycle()))
	var growth: float = 1.0 if canvas.state.home_ready else clampf(float(canvas.state.home_elapsed)/cycle,0.0,0.999)
	var visible: Rect2 = Terrain.rendering_world_rect(canvas.garden_world).grow(96)
	for index in range(World.PLOT_CENTERS.size()):
		if not canvas.state.is_plot_unlocked("home", index):
			continue
		var bed: Rect2 = World.plot_rect(index)
		if not bed.intersects(visible): continue
		var kind: String = canvas.state.home_plots[index]
		Terrain.draw_planting_bed(canvas, bed, canvas.active_plot_area == "home" and canvas.active_plot_slot == index and not canvas.home_panel.is_empty(), World.plot_style("home", index),true)
		if kind.is_empty():
			_draw_empty_soil_marker(canvas, bed)
		else:
			Crops.draw(canvas,canvas.PLANT_ART[kind],bed,kind,canvas.state.plot_level("home",index),growth)
			_queue_level(World.plot_visual_rect(index), canvas.state.plot_level("home", index))
		canvas._hit_world(World.plot_visual_rect(index), "home_plot:%d" % index)
	canvas._sprite(canvas.CAN, World.PROP_RECTS["garden_can"])
	canvas._sprite(canvas.FARM_ART.get("barrel",canvas.SCENERY["barrel"]), World.PROP_RECTS["garden_barrel"])




func _draw_buildings(canvas: Node2D) -> void:
	canvas._hit_world(Experience.HEART_RECT,"garden_journal")
	_building_shadow(canvas,World.COTTAGE_RECT)
	canvas._sprite(canvas.FARM_ART.get("cottage",canvas.HOUSE),World.COTTAGE_RECT)
	canvas._hit_world(World.building_hit_regions()["collect"],"collect")
	if canvas.FARM_ART.has("mailbox"):
		canvas._sprite(canvas.FARM_ART["mailbox"],World.PROP_RECTS["mailbox"])
	# Small useful farm props cluster around the porch and row ends.
	canvas._sprite(canvas.FARM_ART["chest"],World.PROP_RECTS["porch_chest"])
	canvas._sprite(canvas.FARM_ART["caretaker"],World.PROP_RECTS["caretaker"])
	for key in ["scarecrow_west","scarecrow_east"]:
		canvas._sprite(canvas.FARM_ART["scarecrow"],World.PROP_RECTS[key])
	canvas._sprite(canvas.FARM_ART["barrel"],World.PROP_RECTS["porch_barrel"])
	_building_shadow(canvas,World.NURSERY_RECT)
	canvas._sprite(canvas.FARM_ART.get("nursery", canvas.HOUSE), World.NURSERY_RECT)
	canvas._sprite(canvas.FARM_ART.get("barrel",canvas.SCENERY["barrel"]),World.PROP_RECTS["nursery_barrel"])
	canvas._sprite(canvas.CAN,World.PROP_RECTS["nursery_can"])
	for key in ["nursery_hen","nursery_hen_west"]:
		canvas._sprite(canvas.FARM_ART["nursery_hen"],World.PROP_RECTS[key])
	for key in ["nursery_lantern","nursery_lantern_south"]:
		canvas._sprite(canvas.FARM_ART["nursery_lantern"],World.PROP_RECTS[key])
	_draw_nursery_beds(canvas)
	_sign(canvas, World.SIGN_RECTS["nursery"], "Питомник")
	canvas._hit_world(World.building_hit_regions()["nursery"], "nursery")
	_building_shadow(canvas,World.GREENHOUSE_RECT)
	canvas._sprite(canvas.FARM_ART.get("greenhouse", canvas.FARM_ART.get("cottage", canvas.HOUSE)), World.GREENHOUSE_RECT)
	canvas._sprite(canvas.FARM_ART.get("barrel",canvas.SCENERY["barrel"]), World.PROP_RECTS["greenhouse_barrel"])
	canvas._sprite(canvas.CAN, World.PROP_RECTS["greenhouse_can"])
	_sign(canvas, World.SIGN_RECTS["greenhouse"], "Теплица")
	canvas._hit_world(World.building_hit_regions()["greenhouse"], "greenhouse")
	var gate_art: Rect2 = World.GATE_ART_RECT
	for x in [gate_art.position.x+6,gate_art.end.x-17]:
		canvas.draw_rect(Rect2(x,gate_art.position.y,12,92), Color("654b30"))
		canvas.draw_circle(Vector2(x+6,gate_art.position.y), 10, Color("53753b"))
	_sign(canvas, Rect2(gate_art.position+Vector2(-24,8),Vector2(128,36)), "Защита >")
	canvas._hit_world(World.building_hit_regions()["gate"], "gate")


func _building_shadow(canvas: Node2D, rect: Rect2) -> void:
	canvas.draw_ellipse(Vector2(rect.get_center().x,rect.end.y-3),rect.size.x*0.4,7,Color(0.18,0.27,0.14,0.20))


func _draw_nursery_beds(canvas: Node2D) -> void:
	var visible: Rect2 = Terrain.rendering_world_rect(canvas.garden_world).grow(96)
	for index in range(World.NURSERY_PLOT_CENTERS.size()):
		if not canvas.state.is_plot_unlocked("nursery", index):
			continue
		var rect: Rect2 = World.nursery_plot_rect(index)
		if not rect.intersects(visible): continue
		var selected: bool = canvas.active_plot_area == "nursery" and canvas.active_plot_slot == index and not canvas.home_panel.is_empty()
		Terrain.draw_planting_bed(canvas,rect,selected,World.plot_style("nursery",index))
		var kind: String = canvas.state.plot_kind("nursery", index)
		if not kind.is_empty():
			NurseryCrops.draw(canvas,canvas.PLANT_ART[kind],rect,kind,canvas.state.plot_level("nursery",index))
			_queue_level(rect, canvas.state.plot_level("nursery", index))
		else:
			_draw_empty_soil_marker(canvas,rect)
		canvas._hit_world(rect, "nursery_plot:%d" % index)


func _draw_pond(canvas: Node2D) -> void:
	var flutter: float = 0.8 + absf(sin(canvas.elapsed * 5.0)) * 0.2
	var visible: Rect2 = Terrain.rendering_world_rect(canvas.garden_world).grow(96)
	if not World.POND_RECT.grow(160).intersects(visible): return
	canvas._sprite(canvas.SCENERY["butterfly"], Rect2(World.POND_RECT.end.x-68 + sin(canvas.elapsed * 0.6) * 18, World.POND_RECT.position.y+18 + cos(canvas.elapsed) * 8, 24 * flutter, 23))
	if not canvas.state.is_district_unlocked("pond"):
		var notice: Rect2 = World.POND_LOCK_RECT
		canvas._box(notice, canvas.PAPER)
		canvas._center(Rect2(notice.position + Vector2(6,5),Vector2(348,34)), "Водные грядки · закрыты", 23, canvas.GREEN, canvas.bold)
		canvas._center(Rect2(notice.position + Vector2(6,40),Vector2(348,40)), "Откроется после задания 1", 18, canvas.INK)
		canvas._hit_world(notice, "campaign_board")
		return
	for index in range(World.POND_PLOT_CENTERS.size()):
		var rect: Rect2 = World.pond_plot_rect(index)
		if not rect.intersects(visible): continue
		var at: Vector2 = rect.get_center()
		var selected: bool = canvas.active_plot_area == "pond" and canvas.active_plot_slot == index and not canvas.home_panel.is_empty()
		if selected:
			var ripple := PackedVector2Array()
			for step in range(25):
				var angle: float = step * TAU / 24.0
				ripple.append(at+Vector2(cos(angle)*43,sin(angle)*23+7))
			canvas.draw_polyline(ripple,Color("d9f0d4"),2.0)
		var kind: String = canvas.state.plot_kind("pond", index)
		if kind.is_empty():
			# A small cork buoy and a short ripple belong to the water. The full
			# tap target remains invisible until this particular slot is selected.
			canvas.draw_ellipse(at+Vector2(0,8),12,3,Color(0.7,0.88,0.88,0.38))
			canvas.draw_rect(Rect2(at+Vector2(-4,4),Vector2(8,6)),Color("7d6543"))
			canvas.draw_rect(Rect2(at+Vector2(-3,3),Vector2(6,3)),Color("dec78b"))
		else:
			Visuals.draw_garden_plant(canvas,canvas.PLANT_ART[kind],rect,kind,canvas.state.plot_level("pond",index))
			_queue_level(rect, canvas.state.plot_level("pond", index))

		canvas._hit_world(rect, "pond_plot:%d" % index)
	_sign(canvas, World.SIGN_RECTS["pond"], "Водные грядки")


func _sign(_canvas: Node2D, rect: Rect2, title: String) -> void:
	_sign_labels.append({"world_rect":rect,"text":title})


func _queue_level(bounds: Rect2, level: int, offset: Vector2 = Vector2.ZERO) -> void:
	_level_labels.append({"world_rect":bounds,"level":level,"offset":offset})


static func level_screen_rect(camera, bounds: Rect2) -> Rect2:
	return Rect2((camera.world_to_screen(bounds.end)-Vector2(18,14)).round(),Vector2(18,14))


static func sign_screen_rect(camera, bounds: Rect2) -> Rect2:
	var size := Vector2(clampf(bounds.size.x * camera.zoom,110,190),26)
	return Rect2((camera.world_to_screen(bounds.get_center())-size/2.0).round(),size.round())


func _draw_world_labels(canvas: Node2D) -> void:
	# Text is drawn on the fixed logical canvas after resetting the map's
	# transform. Camera zoom moves anchors, never shrinks or stretches glyphs.
	for entry in _level_labels:
		var rect: Rect2 = level_screen_rect(canvas.garden_world,entry["world_rect"])
		rect.position += Vector2(entry.get("offset",Vector2.ZERO))
		if not World.MAP_VIEW.encloses(rect) or canvas.MINIMAP_RECT.intersects(rect): continue
		canvas.draw_rect(rect,Color("65704a"))
		canvas.draw_rect(rect.grow(-1),Color("ecdfb7") if entry["level"] < 7 else Color("dfc58b"))
		canvas._level_label(rect,int(entry["level"]))
		world_label_layouts.append({"kind":"level","rect":rect,"text":str(entry["level"]),"world_rect":entry["world_rect"]})
	for entry in _sign_labels:
		var rect: Rect2 = sign_screen_rect(canvas.garden_world,entry["world_rect"])
		if not World.MAP_VIEW.encloses(rect) or canvas.MINIMAP_RECT.intersects(rect): continue
		canvas.draw_rect(rect,Color("795e3d"))
		canvas.draw_rect(rect.grow(-1),Color("cba36d"))
		canvas.draw_line(rect.position+Vector2(3,3),Vector2(rect.end.x-3,rect.position.y+3),Color("e1c28c"),1)
		canvas._label(rect.grow(-3),entry["text"],14,Color("3f3c2b"),canvas.bold,false,true)
		world_label_layouts.append({"kind":"sign","rect":rect,"text":entry["text"],"world_rect":entry["world_rect"]})


func _draw_empty_soil_marker(canvas: Node2D, bed: Rect2) -> void:
	var at: Vector2 = (bed.position+Vector2(10,5)).floor()
	canvas.draw_line(at+Vector2(2,0),at+Vector2(2,8),Color("6e7c44"),2)
	canvas.draw_rect(Rect2(at+Vector2(0,-1),Vector2(5,3)),Color("b6b77b"))
	if canvas.garden_world.zoom >= 0.8:
		canvas.draw_line(at+Vector2(12,5),at+Vector2(28,5),Color("a5ad71"),2)
		canvas.draw_line(at+Vector2(12,11),at+Vector2(28,11),Color("a5ad71"),2)


func _draw_navigation(canvas: Node2D) -> void:
	var district: Dictionary = canvas.garden_world.current_district()
	_draw_minimap(canvas)
	# Independent floating controls leave the actual garden visible between
	# them. Their familiar touch geometry remains outside the map viewport.
	Experience.draw_goal_strip(canvas,Rect2(24,814,290,60))
	FarmUi.button(canvas,Rect2(330, 830, 176, 44), "Районы >", "open_districts")
	var wait_seconds: int = maxi(0, ceili(canvas.state.home_cycle() - canvas.state.home_elapsed))
	var harvest_label: String = "Собрать +%d монет" % canvas.state.collectable_home_income() if canvas.state.home_ready else "Урожай через %d с" % wait_seconds
	FarmUi.button(canvas,Rect2(24, 886, 278, 58), harvest_label, "collect", canvas.state.home_ready,true)
	var battle_label: String = "Задания >" if canvas.battle == null else "Продолжить бой"
	FarmUi.button(canvas,Rect2(314, 886, 202, 58), battle_label, "battle")


func _draw_minimap(canvas: Node2D) -> void:
	FarmUi.panel(canvas,canvas.MINIMAP_RECT)
	var inner: Rect2 = canvas.MINIMAP_INNER
	Terrain.draw_minimap(canvas, inner)
	var context: Dictionary = canvas.garden_world.current_district()
	for district in World.districts():
		var at: Vector2 = inner.position + district["center"] / World.WORLD_SIZE * inner.size
		var active: bool = district["id"] == context.get("id", "")
		canvas.draw_circle(at, 5 if active else 3, Color("fff0ba") if active else Color("4d6135"))
		canvas.draw_circle(at, 3 if active else 1.5, Color("345d46") if active else Color("ffe5a0"))
	var visible: Rect2 = canvas.garden_world.visible_world_rect()
	var frame = Rect2(inner.position + visible.position / World.WORLD_SIZE * inner.size, visible.size / World.WORLD_SIZE * inner.size)
	canvas.draw_rect(frame, Color(1, 0.94, 0.7, 0.14))
	canvas.draw_rect(frame, Color("fff0be"), false, 2.0)
	canvas._hit(canvas.MINIMAP_RECT, "minimap")


