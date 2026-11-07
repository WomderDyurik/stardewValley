class_name GardenExperience
extends RefCounted

## A living refuge, a truthful next action, and visible changes after tending.
## All progress is derived from paid plantings and real campaign rewards.
const World = preload("res://scripts/garden_world.gd")
const Grid = preload("res://scripts/garden_grid.gd")
const Paths = preload("res://scripts/garden_paths.gd")
const Materials = preload("res://scripts/garden_materials.gd")
const FarmUi = preload("res://scripts/garden_farm_ui.gd")
const HEART_TEXTURE = preload("res://assets/pixel/garden_heart/heart-tree-v1.png")
const HEART_RECT := Rect2(608,144,192,240)
const HEART_SEAT := Rect2(656,336,96,48)
static var _flowers: Array[Dictionary] = []


static func planted_count(state, area: String) -> int:
	var total: int = 0
	for slot in range(state.plot_count(area)):
		if state.is_plot_unlocked(area,slot) and not state.plot_kind(area,slot).is_empty(): total += 1
	return total


static func next_goal(state) -> Dictionary:
	var defenders: int = 0
	for template in state.battle_templates():
		if template["role"] == "defense": defenders += 1
	if defenders == 0:
		return {"id":"first_defender","title":"Первый защитник","detail":"Вырастите крапиву для обороны","button":"В питомник >","action":"grow_defender","progress":0,"total":1}
	if state.completed_level == 0:
		return {"id":"open_water","title":"Оживите водный сад","detail":"Первая победа откроет пруд","button":"К первой обороне >","action":"battle","progress":0,"total":1}
	if planted_count(state,"pond") == 0:
		return {"id":"water_plant","title":"Жизнь на воде","detail":"Пруд открыт: посадите кувшинку","button":"К пруду >","action":"visit_pond","progress":0,"total":1}
	if state.completed_level < 3:
		return {"id":"next_defense","title":"Защитите новый уголок","detail":"Победа откроет новые семена","button":"Продолжить путь >","action":"battle","progress":state.completed_level,"total":3}
	var built: int = 0
	for id in ["irrigation","compost","harvest_crate"]:
		if state.helper_level(id) > 0: built += 1
	if built < 3:
		return {"id":"workshop","title":"Уютная мастерская","detail":"Построено установок: %d из 3" % built,"button":"К улучшениям >","action":"helpers","progress":built,"total":3}
	return {"id":"living_garden","title":"Ваш сад расцветает","detail":"Посадок: %d · рубежи: 3 из 3" % (planted_count(state,"home")+planted_count(state,"nursery")+planted_count(state,"pond")),"button":"Планы сада >","action":"garden_journal","progress":3,"total":3}


static func soil_cells(state, area: String) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for slot in range(Grid.planting_cells(area).size()):
		if not state.plot_kind(area,slot).is_empty(): result.append(Grid.planting_rect(area,slot))
	return result


static func _outline(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])


static func _natural_patch(center: Vector2, size: Vector2, seed: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(24):
		var angle: float = index*TAU/24.0
		var amount: float = 0.90+float((index*17+seed*13)%11)*0.009
		points.append((center+Vector2(cos(angle),sin(angle))*size*0.5*amount).snapped(Vector2(4,4)))
	return points


static func _clear(frame: Rect2) -> bool:
	for area in ["home","nursery"]:
		for block in Grid.block_rects(area):
			if frame.intersects(block.grow(8)): return false
	for object in World.building_hit_regions().values():
		if frame.intersects(object.grow(8)): return false
	if frame.intersects(World.POND_RECT.grow(16)) or frame.end.x > 3424: return false
	for path in Paths.polygons():
		if not Geometry2D.intersect_polygons(_outline(frame.grow(6)),path).is_empty(): return false
	return true


static func flower_clusters() -> Array[Dictionary]:
	if not _flowers.is_empty(): return _flowers
	# Distinct pockets: warm cottage flowers, cool training glade, sheltered
	# orchard and a pale waterside meadow. They never occupy planting cells.
	var pockets: Array[Dictionary] = [
		{"at":Vector2(1112,184),"size":Vector2(224,152),"color":Color("f5d19d")},
		{"at":Vector2(816,232),"size":Vector2(96,176),"color":Color("f4a9a1")},
		{"at":Vector2(1016,352),"size":Vector2(80,48),"color":Color("f9df9b")},
		{"at":Vector2(1296,1968),"size":Vector2(192,192),"color":Color("f0bd70")},
		{"at":Vector2(832,1952),"size":Vector2(448,176),"color":Color("f8dc9e")},
		{"at":Vector2(1872,1920),"size":Vector2(352,128),"color":Color("c9b3dd")},
		{"at":Vector2(2224,1856),"size":Vector2(256,104),"color":Color("d8bee8")},
		{"at":Vector2(2368,2152),"size":Vector2(160,112),"color":Color("dbe7c6")},
		{"at":Vector2(3024,2448),"size":Vector2(304,160),"color":Color("e9d5a2")},
		{"at":Vector2(1152,2672),"size":Vector2(304,112),"color":Color("ebd2a5")},
	]
	for index in range(pockets.size()):
		var pocket: Dictionary = pockets[index]
		var center: Vector2 = pocket["at"]
		var size: Vector2 = pocket["size"]
		for sample in range(100):
			var code: int = absi(sample*1973+index*9277+sample*sample*17)
			var offset := Vector2(float(code%997)/996.0-0.5,float((code/997)%991)/990.0-0.5)*size
			if (offset/(size*0.5)).length_squared() > 0.9: continue
			var at: Vector2 = (center+offset).snapped(Vector2(2,2))
			if _clear(Rect2(at-Vector2(6,10),Vector2(16,18))):
				_flowers.append({"at":at,"color":pocket["color"],"seed":code})
	return _flowers


static func draw_understory(canvas: Node2D, visible: Rect2) -> void:
	for entry in [[Vector2(1112,192),Vector2(480,320),0],[Vector2(1008,2000),Vector2(864,288),1],
		[Vector2(1936,1952),Vector2(752,272),2],[Vector2(2928,2448),Vector2(640,320),3]]:
		var center: Vector2 = entry[0]
		var size: Vector2 = entry[1]
		if not Rect2(center-size/2.0,size).intersects(visible): continue
		Materials.draw(canvas,_natural_patch(center,size,entry[2]),"grass",Color(0.95,1.01,0.90) if entry[2]%2 == 0 else Color(0.91,0.98,1.0))
	for flower in flower_clusters():
		var at: Vector2 = flower["at"]
		if not visible.grow(12).has_point(at): continue
		var color: Color = flower["color"]
		var code: int = flower["seed"]
		canvas.draw_rect(Rect2(at+Vector2(0,-5),Vector2(2,9)),Color("39813a"))
		canvas.draw_rect(Rect2(at+Vector2(-3,-5),Vector2(8,3)),color)
		canvas.draw_rect(Rect2(at+Vector2(0,-8),Vector2(3,8)),color)
		canvas.draw_rect(Rect2(at+Vector2(0,-5),Vector2(2,2)),Color("e5b84b"))
		if code%3 == 0: canvas.draw_rect(Rect2(at+Vector2(7,2),Vector2(3,2)),Color("7ab24b"))


static func heart_texture() -> Texture2D:
	return HEART_TEXTURE


static func draw_landmarks(canvas: Node2D, visible: Rect2, elapsed: float) -> void:
	if HEART_RECT.grow(64).intersects(visible):
		canvas.draw_ellipse(HEART_SEAT.get_center()+Vector2(0,16),88,14,Color(0.13,0.26,0.18,0.18))
		canvas.draw_texture_rect(heart_texture(),HEART_RECT,false)
		for index in range(7):
			var phase: float = fposmod(elapsed*0.045+index*0.17,1.0)
			var at := Vector2(628+index*21+sin(phase*TAU+index)*8,164+phase*228)
			canvas.draw_rect(Rect2(at.snapped(Vector2(2,2)),Vector2(4,2)),Color("f5c5ad"))
	# A little wash of sun over the southern clearing, a quiet reading corner
	# and stone outcrops give the routes destinations beyond equal rectangles.
	for entry in [[Rect2(1072,2064,80,56),"bench"],[Rect2(2272,1920,64,48),"rocks"],
		[Rect2(1248,2672,72,48),"rocks"],[Rect2(3088,2512,96,64),"bench"]]:
		var frame: Rect2 = entry[0]
		if frame.intersects(visible) and _clear(frame):
			var key: String = entry[1]
			canvas._sprite(canvas.SCENERY[key],frame)
	for index in range(4):
		var origin: Vector2 = [Vector2(1088,280),Vector2(832,1968),Vector2(2256,1904),Vector2(3008,2320)][index]
		var at: Vector2 = origin+Vector2(sin(elapsed*0.7+index)*36,cos(elapsed*0.5+index)*12)
		if visible.has_point(at):
			canvas._sprite(canvas.SCENERY["butterfly"],Rect2(at,Vector2(20,18)))


static func draw_block_boundary(canvas: Node2D, block: Rect2, filled: int) -> void:
	# Short six-step corner stitches preserve the square's discoverability.
	# Empty meadow never pretends to contain a full field of grown plants.
	var color := Color("b4b37a") if filled == 0 else Color("c5a568")
	for corner in [block.position,Vector2(block.end.x,block.position.y),block.end,Vector2(block.position.x,block.end.y)]:
		var toward: Vector2 = (block.get_center()-corner).sign()
		canvas.draw_rect(Rect2(corner+Vector2(-2,-2),Vector2(4,4)),Color("907542"))
		canvas.draw_line(corner,corner+Vector2(toward.x*16,0),color,2,false)
		canvas.draw_line(corner,corner+Vector2(0,toward.y*16),color,2,false)
	for step in range(1,6):
		for at in [block.position+Vector2(step*96,0),Vector2(block.position.x+step*96,block.end.y)]:
			canvas.draw_rect(Rect2(at-Vector2(2,1),Vector2(4,2)),Color(color,0.55))


static func draw_meadow_drifts(canvas: Node2D, block: Rect2, occupied: Dictionary, seed: int) -> void:
	# Low wild clover is ground cover, not a productive planting. Broad drifts
	# give the unused garden a silhouette; paid soil is drawn on top afterwards.
	var centers: Array[Vector2] = [Vector2(0.53,0.56),Vector2(0.22,0.83),Vector2(0.80,0.26)]
	var sizes: Array[Vector2] = [Vector2(0.54,0.34),Vector2(0.32,0.20),Vector2(0.28,0.22)]
	for index in range(centers.size()):
		var center: Vector2 = block.position+centers[index]*block.size
		var size: Vector2 = sizes[index]*block.size
		var polygon: PackedVector2Array = _natural_patch(center,size,seed+index*7)
		canvas.draw_colored_polygon(polygon,Color(0.22,0.45,0.20,0.18))
		for sample in range(34 if index == 0 else 18):
			var code: int = absi(seed*9277+sample*1973+sample*sample*73+index*37)
			var offset := Vector2(float(code%997)/996.0-0.5,float((code/13)%991)/990.0-0.5)*size
			var at: Vector2 = (center+offset).snapped(Vector2(2,2))
			if not Geometry2D.is_point_in_polygon(at,polygon) or occupied.has(Grid.cell_at(at)): continue
			for leaf in [Vector2(-6,-3),Vector2(3,-4),Vector2(-2,4)]:
				canvas.draw_rect(Rect2(at+leaf,Vector2(8,6)),Color("4b8e35"))
				canvas.draw_rect(Rect2(at+leaf+Vector2(0,-2),Vector2(6,6)),Color("79b54a") if code%3 else Color("6cab43"))
			if sample%4 == 0:
				canvas.draw_rect(Rect2(at+Vector2(1,-6),Vector2(6,2)),Color("e6d9ae"))
				canvas.draw_rect(Rect2(at+Vector2(3,-8),Vector2(2,6)),Color("e6d9ae"))


static func draw_goal_strip(canvas: Node2D, rect: Rect2) -> void:
	var goal: Dictionary = next_goal(canvas.state)
	FarmUi.panel(canvas,rect)
	canvas._label(Rect2(rect.position+Vector2(12,5),Vector2(rect.size.x-32,25)),goal["title"],16,FarmUi.INK,canvas.bold)
	canvas._label(Rect2(rect.position+Vector2(12,30),Vector2(rect.size.x-32,23)),goal["detail"],13,FarmUi.INK)
	canvas._draw_control_chevron(Rect2(rect.end.x-25,rect.position.y+14,18,32),true,FarmUi.INK)
	canvas._hit(rect,"garden_goal")


static func draw_journal(canvas: Node2D) -> void:
	canvas.hitboxes.clear()
	canvas.draw_rect(Rect2(0,0,540,960),Color(0.09,0.19,0.14,0.52))
	var frame := Rect2(24,208,492,552)
	canvas._box(frame,Color("f7efd8"))
	canvas._label(Rect2(48,226,444,40),"Сад, который вы оживляете",25,Color("355e40"),canvas.bold)
	canvas._label(Rect2(48,274,444,48),"Выращивайте растения, защищайте новые уголки и возвращайтесь в безопасный сад.",16,canvas.INK,null,true)
	var rows: Array[Dictionary] = [
		{"title":"Огород у дома","text":"Настоящих посадок: %d из 144" % planted_count(canvas.state,"home"),"action":"district:garden","done":planted_count(canvas.state,"home")>0},
		{"title":"Питомник защитников","text":"Настоящих посадок: %d из 144" % planted_count(canvas.state,"nursery"),"action":"district:nursery","done":planted_count(canvas.state,"nursery")>0},
		{"title":"Водный сад","text":"Открыт · посадок %d из 6" % planted_count(canvas.state,"pond") if canvas.state.completed_level>0 else "Откроется после первой победы","action":"visit_pond","done":canvas.state.completed_level>0},
	]
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var top: float = 338+index*78
		canvas.draw_rect(Rect2(48,top,444,68),Color("e4e9d1") if row["done"] else Color("eee8d7"))
		canvas._label(Rect2(62,top+5,414,25),row["title"],19,canvas.INK,canvas.bold)
		canvas._label(Rect2(62,top+33,414,24),row["text"],14,canvas.MUTED)
		canvas._hit(Rect2(48,top,444,68),row["action"])
	var goal: Dictionary = next_goal(canvas.state)
	canvas._button(Rect2(48,588,444,54),goal["button"],"garden_goal",true,true)
	canvas._label(Rect2(48,652,444,24),"Пройдено рубежей: %d из 3" % mini(3,canvas.state.completed_level),16,canvas.GREEN,canvas.bold)
	canvas._button(Rect2(48,692,444,48),"Вернуться в сад","close_home_panel",true,false)


static func note(canvas: Node2D, kind: String, point: Vector2, caption: String) -> void:
	canvas.garden_moments.append({"kind":kind,"at":point,"text":caption,"time":canvas.elapsed})
	while canvas.garden_moments.size()>8: canvas.garden_moments.pop_front()


static func draw_moments(canvas: Node2D) -> void:
	for moment in canvas.garden_moments:
		var age: float = canvas.elapsed-float(moment["time"])
		if age < 0.0 or age > 1.6: continue
		var alpha: float = minf(1.0,(1.6-age)*2.0)
		var at: Vector2 = canvas.garden_world.world_to_screen(moment["at"])+Vector2(0,-24-age*24)
		if not World.MAP_VIEW.grow(24).has_point(at): continue
		for index in range(7):
			var angle: float = index*TAU/7.0
			var petal: Vector2 = at+Vector2(cos(angle)*age*30,sin(angle)*age*18)
			canvas.draw_rect(Rect2(petal.floor(),Vector2(3,3)),Color(Color("f3ce78") if moment["kind"] == "harvest" else Color("b8d86d"),alpha))
		var label := Rect2(at-Vector2(92,14),Vector2(184,28))
		label.position.x = clampf(label.position.x,12,344)
		canvas.draw_rect(label,Color(Color("eef0d5"),alpha*0.92))
		canvas._center(label,moment["text"],17,Color(Color("5d3b24"),alpha),canvas.bold)
