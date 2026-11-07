class_name BattleEncounterArt
extends RefCounted

## The same saved route and paid placements drive every objective, hint and
## impact. These annotations never reserve land, spend supplies or tick combat.
const View = preload("res://scripts/battle_map_view.gd")
const Placement = preload("res://scripts/battle_placement.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Clip = preload("res://scripts/canvas_clip.gd")
static var _hint_key: int = 0
static var _hint_cache: Array[Dictionary] = []


static func battle_readout(battle: Object, selected: String = "") -> Dictionary:
	if battle == null: return {}
	var plan: Dictionary = battle.preview_wave()
	var living: int = battle.enemies.size()
	var queued: int = maxi(0,int(battle.enemy_total)-int(battle.spawned)) if battle.phase == "running" else int(plan.get("total",0))
	var defenders: int = 0
	var cheapest: Dictionary = {}
	var choice: Dictionary = {}
	for plant in battle.plants:
		if Catalog.PLANTS.get(plant["kind"],{}).get("role","") == "defense": defenders += 1
	for template in battle.loadout:
		if template["kind"] == selected: choice = template
		if Catalog.PLANTS.get(template["kind"],{}).get("role","") != "defense": continue
		if cheapest.is_empty() or int(template["cost"]) < int(cheapest["cost"]): cheapest = template
	var title: String = "Сохраните теплицу · 5 волн"
	var detail: String = "Поставьте защиту у изгиба тропы"
	var available: int = floori(float(battle.supplies)/float(cheapest["cost"])) if not cheapest.is_empty() else 0
	if not battle.loadout_ready:
		title = "Выберите защитников для теплицы"
		detail = "В бой идут выращенные растения"
	elif battle.phase == "running":
		title = "Пауза · можно перестроить оборону" if battle.paused else "На тропе %d · подходят ещё %d" % [living,queued]
		var assault: int = battle.active_assault()
		var assaults: Array = plan.get("assaults",[])
		detail = "Заход %d/%d" % [assault,maxi(1,assaults.size())]
		if assault>0 and assault<=assaults.size(): detail += " · "+str(assaults[assault-1].get("title",""))
	elif battle.phase in ["won","lost"]:
		title = "Теплица сохранена" if battle.phase == "won" else "Теплица не выдержала натиск"
		detail = "Сад и выращенные растения в безопасности"
	elif defenders == 0 and not cheapest.is_empty():
		title = "Первый защитник · начните с метки 1"
		detail = "%s · %d припасов за копию" % [cheapest.get("name",Catalog.PLANTS[cheapest["kind"]]["name"]),int(cheapest["cost"])]
	elif defenders==1 and not cheapest.is_empty() and int(battle.supplies)>=int(cheapest["cost"]):
		title = "Прикройте ещё один изгиб тропы"
		detail = "Второй рубеж подхватит уцелевших вредителей"
	elif battle.phase == "between":
		title = "Волна пройдена · укрепите оборону"
		detail = "Новые припасы — на второй рубеж или урожай"
	else:
		title = "Защитников: %d · резерв %d припасов" % [defenders,int(battle.supplies)]
		detail = "Новых копий сейчас: %d · усиливайте в бою" % available if available > 0 else "Новые припасы — на усиление линии в бою"
	if not choice.is_empty() and battle.phase not in ["won","lost"]:
		var kind: String = str(choice["kind"])
		title = "%s · выберите подсвеченную клетку" % Catalog.PLANTS[kind]["name"]
		detail = "%d припасов · %s" % [int(choice["cost"]),"урожай после волны" if Catalog.PLANTS[kind]["role"] == "income" else "покрывайте несколько отрезков тропы"]
		if int(battle.supplies) < int(choice["cost"]):
			title = "Для новой копии не хватает припасов"
			detail = "Убийства и завершение волны пополняют запас"
	var resolved: int = maxi(0,int(battle.spawned)-living) if battle.phase == "running" else 0
	return {"title":title,"detail":detail,"living":living,"queued":queued,"defenders":defenders,"available_defenders":available,"total":int(battle.enemy_total) if battle.phase=="running" else int(plan.get("total",0)),"resolved":resolved,"progress":clampf(float(resolved)/maxf(1,float(battle.enemy_total)),0,1),"cheapest_defender":cheapest}


static func remaining_counts(battle: Object) -> Dictionary:
	if battle == null: return {}
	if battle.phase in ["won","lost"]: return {}
	if battle.phase != "running": return battle.preview_wave().get("counts",{}).duplicate()
	var result: Dictionary = {}
	# A forecast is the not-yet-spawned queue plus actual surviving attackers.
	for enemy in battle.enemies:
		var kind: String = str(enemy["kind"])
		result[kind] = int(result.get(kind,0))+1
	var plan: Dictionary = battle.preview_wave()
	var schedule: Array = plan.get("schedule",[])
	# Director exposes the authored groups through spawn_schedule, not a new
	# timer or an approximation based on elapsed animation time.
	if schedule.is_empty(): schedule = battle.get("_spawn_schedule")
	for index in range(int(battle.spawned),schedule.size()):
		var kind: String = str(schedule[index]["kind"])
		result[kind] = int(result.get(kind,0))+1
	return result


static func coverage_hints(battle: Object, selected: String = "") -> Array[Dictionary]:
	var empty: Array[Dictionary] = []
	if battle == null or not battle.loadout_ready or battle.phase not in ["preparing","between"]: return empty
	var chosen: Dictionary = {}
	for template in battle.loadout:
		if Catalog.PLANTS[template["kind"]]["role"] != "defense": continue
		if selected == template["kind"]: chosen = template; break
		if selected.is_empty() and (chosen.is_empty() or int(template["cost"]) < int(chosen["cost"])): chosen = template
	if chosen.is_empty() or int(battle.supplies)<int(chosen["cost"]): return empty
	var path: Array[Vector2] = battle.path_points()
	var occupied: Array[Vector2] = []
	var defenses: Array[Dictionary] = []
	var anchors: Array[Vector2] = battle.plot_positions()
	for plant in battle.plants:
		var at: Vector2 = anchors[int(plant["slot"])]; occupied.append(at)
		if Catalog.PLANTS[plant["kind"]]["role"]=="defense":
			defenses.append({"position":at,"range":float(battle.state.plant_data(plant["kind"],int(plant["level"]))["range"])})
	var data: Dictionary = battle.state.plant_data(chosen["kind"],int(chosen["level"]))
	var attack_range: float = float(data["range"])
	var key: int = hash([path,occupied,defenses,chosen["kind"],attack_range])
	if key == _hint_key: return _hint_cache.duplicate(true)
	_hint_key = key
	_hint_cache.clear()
	var scored: Array[Dictionary] = []
	for point in Placement.grid_centers():
		if not Placement.check(point,path,occupied)["valid"]: continue
		var coverage: float = 0.0
		var fresh_coverage: float = 0.0
		for index in range(1,path.size()):
			var middle: Vector2 = (path[index]+path[index-1])*0.5
			if point.distance_to(middle) <= attack_range:
				var length: float = path[index].distance_to(path[index-1])
				coverage += length
				var already_covered: bool = defenses.any(func(defense:Dictionary)->bool:return Vector2(defense["position"]).distance_to(middle)<=float(defense["range"]))
				fresh_coverage += length*(0.30 if already_covered else 1.0)
		if coverage>attack_range*1.3: scored.append({"position":point,"coverage":coverage,"score":fresh_coverage,"kind":chosen["kind"],"range":attack_range})
	scored.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a["score"]>b["score"])
	for entry in scored:
		if _hint_cache.size()>=2: break
		if _hint_cache.any(func(other:Dictionary)->bool:return Vector2(other["position"]).distance_to(entry["position"]) < Placement.GRID_STEP*2.0): continue
		_hint_cache.append(entry)
	return _hint_cache.duplicate(true)


static func draw_tactical_ground(canvas: Node2D) -> void:
	var battle: Object = canvas.battle
	if battle == null: return
	for plant in battle.plants:
		var center: Vector2 = canvas.battle_to_screen(canvas.plot_positions[int(plant["slot"])])
		var rect := Rect2(center+Vector2(-23,-13),Vector2(46,30))
		var soil := PackedVector2Array([rect.position+Vector2(5,0),rect.position+Vector2(41,0),rect.position+Vector2(46,5),rect.position+Vector2(46,24),rect.position+Vector2(41,29),rect.position+Vector2(5,29),rect.position+Vector2(0,24),rect.position+Vector2(0,5)])
		canvas.draw_colored_polygon(soil,Color("80532e"))
		for row in range(3):
			Clip.draw_rect(canvas,Rect2(rect.position+Vector2(6,5+row*8),Vector2(34,2)),View.BOARD,Color("a6743c"))
	if canvas.battle_drag_active or not canvas.battle_panel.is_empty(): return
	var hints: Array[Dictionary] = coverage_hints(battle,str(canvas.quick_plant_kind))
	for hint_index in range(hints.size()):
		var hint: Dictionary = hints[hint_index]
		var center: Vector2 = canvas.battle_to_screen(hint["position"])
		var pulse: float = (0.85 if hint_index==0 else 0.52)+sin(float(canvas.elapsed)*3.0)*0.10
		var mark := Rect2(center-Vector2(19,19),Vector2(38,38))
		canvas.draw_rect(mark,Color(0.99,0.89,0.55,0.15))
		for corner in [mark.position,Vector2(mark.end.x,mark.position.y),mark.end,Vector2(mark.position.x,mark.end.y)]:
			var toward: Vector2 = (mark.get_center()-corner).sign()
			canvas.draw_line(corner,corner+Vector2(toward.x*8,0),Color(0.99,0.91,0.61,pulse),2)
			canvas.draw_line(corner,corner+Vector2(0,toward.y*8),Color(0.99,0.91,0.61,pulse),2)
		canvas.draw_line(center-Vector2(5,0),center+Vector2(5,0),Color("fff0ac"),2)
		canvas.draw_line(center-Vector2(0,5),center+Vector2(0,5),Color("fff0ac"),2)
		var label := Rect2(mark.position-Vector2(1,5),Vector2(15,20))
		canvas.draw_rect(label,Color("e8c873") if hint_index==0 else Color("acc27d"))
		canvas._label(label,str(hint_index+1),11,Color("425637"),canvas.bold,false,true)


static func draw_objectives(canvas: Node2D) -> void:
	var battle: Object = canvas.battle
	if battle == null: return
	var path: Array[Vector2] = battle.path_points()
	if path.size()<2: return
	var entry: Vector2 = canvas.battle_to_screen(path[0])
	var direction: Vector2 = (canvas.battle_to_screen(path[1])-entry).normalized()
	var side := Vector2(-direction.y,direction.x)
	for step in [0,12]:
		var at: Vector2 = entry+direction*step
		canvas.draw_polyline(PackedVector2Array([at-direction*5-side*5,at,at-direction*5+side*5]),Color("664d2d"),5)
		canvas.draw_polyline(PackedVector2Array([at-direction*5-side*5,at,at-direction*5+side*5]),Color("f6cd6a"),2)
	var house: Rect2 = View.house_for_route(path)
	house.position += View.BOARD.position
	var danger: bool = false
	for enemy in battle.enemies:
		if float(enemy.get("hp",0)) > 0 and float(enemy.get("progress",0)) > float(battle.path_length)*0.78: danger = true; break
	var goal_color := Color("ce7050") if danger else Color("507c48")
	canvas.draw_rect(Rect2(house.position+Vector2(15,62),Vector2(46,4)),Color("314c38"))
	canvas.draw_rect(Rect2(house.position+Vector2(15,62),Vector2(46*clampf(float(battle.base_hp)/10.0,0,1),4)),goal_color)
	if danger:
		var alpha: float = 0.40+sin(float(canvas.elapsed)*7.0)*0.12
		canvas.draw_arc(house.get_center(),43,0,TAU,24,Color(0.94,0.53,0.27,alpha),2,false)
	if battle.phase in ["preparing","between"]:
		var badge := Rect2(house.position+Vector2(11,-9),Vector2(54,18))
		canvas._box(badge,Color("fff1c9"),3,Color("7b774c"))
		canvas._label(badge,"ЦЕЛЬ",12,Color("405c3b"),canvas.bold,false,true)


static func draw_impacts(canvas: Node2D) -> void:
	if canvas.battle == null: return
	for enemy in canvas.battle.enemies:
		var hit: float = float(enemy.get("hit",0))
		if hit<=0: continue
		var center: Vector2 = canvas.battle_to_screen(enemy["position"])
		var alpha: float = clampf(hit/0.12,0,1)
		for offset in [Vector2(-18,-12),Vector2(17,-9),Vector2(2,-22)]:
			Clip.draw_rect(canvas,Rect2(center+offset,Vector2(3,3)),View.BOARD,Color(1.0,0.95,0.70,alpha))
	for shot in canvas.battle.shots:
		var life: float = float(shot["life"])
		if life<=0 or life>0.085: continue
		var target: Vector2 = canvas.battle_to_screen(shot["to"])
		var age: float = 1.0-life/0.085
		var kind: String = str(shot["kind"])
		var color := Color("c3e58b") if kind=="nettle" else Color("c8a6eb") if kind=="lavender" else Color("9ae0da") if kind=="lotus" else Color("ffc873")
		var count: int = 6 if kind=="pepper" else 4
		var radius: float = (6.0+age*12.0) if kind=="pepper" else 3.0+age*6.0
		for index in range(count):
			var angle: float = TAU*index/count+0.4
			var at: Vector2 = (target+Vector2(cos(angle),sin(angle))*radius).round()
			Clip.draw_rect(canvas,Rect2(at,Vector2(3,3)),View.BOARD,Color(color,1.0-age*0.65))
		if kind in ["lavender","lotus"]:
			for arc in range(4):
				var angle: float = arc*PI*0.5
				var first: Vector2 = target+Vector2(cos(angle),sin(angle))*radius
				var last: Vector2 = target+Vector2(cos(angle+0.45),sin(angle+0.45))*radius
				if View.BOARD.has_point(first) and View.BOARD.has_point(last): canvas.draw_line(first,last,Color(color,0.7),2,false)
