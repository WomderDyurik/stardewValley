class_name PlantMenus
extends RefCounted

const Visuals = preload("res://scripts/plant_visuals.gd")
const PAGE_SIZE: int = 6
const SEED_PAGE_SIZE: int = 3
const NURSERY_PAGE_SIZE: int = 8
const BattleUI = preload("res://scripts/battle_presentation.gd")
const HelperMenus = preload("res://scripts/garden_helper_menus.gd")


static func _backdrop(canvas: Node2D, rect: Rect2) -> void:
	canvas.hitboxes.clear()
	canvas.draw_rect(Rect2(0, 0, 540, 960), Color(0.10, 0.18, 0.12, 0.48))
	canvas._box(rect, canvas.PAPER)


static func _choice_surface(canvas: Node2D, rect: Rect2, action: String = "", selected: bool = false, enabled: bool = true) -> void:
	# Touch cards share the same hierarchy as ordinary buttons: quiet when
	# available, a clear botanical accent when chosen, neutral when unavailable.
	var background: Color = canvas.UiTheme.SELECTED if selected else Color("faf7ed") if enabled else canvas.UiTheme.DISABLED
	var edge := Color("63845b") if selected else Color("d5d3c0")
	var pressed: bool = not action.is_empty() and canvas._is_control_pressed(action)
	if pressed: background = background.darkened(0.06)
	canvas._box(rect, background, 6, edge)
	if selected:
		canvas.draw_rect(Rect2(rect.position+Vector2(2,10),Vector2(3,rect.size.y-20)),Color("52774f"))


static func draw_home(canvas: Node2D) -> void:
	match canvas.home_panel:
		"plant_picker": _plant_picker(canvas)
		"plot": _plot_details(canvas)
		"nursery": _nursery_overview(canvas)
		"greenhouse": _greenhouse(canvas)
		"districts": _districts(canvas)


static func _districts(canvas: Node2D) -> void:
	_backdrop(canvas, Rect2(24, 260, 492, 488))
	canvas._label(Rect2(44, 274, 294, 42), "Места вашего сада", 25, canvas.GREEN, canvas.bold)
	canvas._button(Rect2(350, 276, 146, 44),"Улучшения","helpers",true,false)
	canvas._label(Rect2(45, 322, 450, 28), "Два больших поля и теплица улучшений", 16, canvas.MUTED)
	var current: Dictionary = canvas.garden_world.current_district()
	var districts: Array[Dictionary] = canvas.GardenMap.districts()
	for index in range(districts.size()):
		var data: Dictionary = districts[index]
		var needed: int = canvas.Missions.district_unlock_stage(data["id"])
		var opened: bool = needed <= canvas.state.completed_level
		var rect := Rect2(42, 364 + index * 88, 456, 78)
		var selected: bool = data["id"] == current.get("id", "")
		_choice_surface(canvas, rect, "district:"+str(data["id"]), selected)
		canvas._label(Rect2(rect.position + Vector2(14, 3), Vector2(414, 28)), data["name"] + (" · сейчас" if selected else " >"), 20, canvas.INK, canvas.bold)
		var caption: String = data["description"] if opened else "Откроется после задания %d · можно осмотреть" % needed
		canvas._label(Rect2(rect.position + Vector2(14, 33), Vector2(414, 38)), caption, 14, canvas.MUTED,null,true)
		canvas._hit(rect, "district:" + data["id"])
	canvas._button(Rect2(44, 676, 452, 49), "Вернуться в сад", "close_home_panel", true, false)


static func _plot_title(canvas: Node2D, area: String, slot: int) -> String:
	return String(canvas.state.plot_info(area, slot).get("title", "Посадочное место"))


static func _habitat_hint(info: Dictionary) -> String:
	if info.get("habitat", "") == "water":
		return "Водные грядки питомника: кувшинки и лотосы"
	match String(info.get("district", "")):
		"garden": return "Овощные и цветочные посадки"
		"nursery": return "Колючие защитники и ароматные мортиры"
	return "Выберите растение для этого места"


static func _plant_picker(canvas: Node2D) -> void:
	_backdrop(canvas, Rect2(24, 190, 492, 620))
	var area: String = canvas.active_plot_area
	var slot: int = canvas.active_plot_slot
	var existing: String = canvas.state.plot_kind(area, slot)
	canvas._label(Rect2(44, 229, 450, 40), "Что посадить?" if existing.is_empty() else "Сменить растение", 27, canvas.GREEN, canvas.bold)
	canvas._label(Rect2(45, 272, 450, 25), _plot_title(canvas, area, slot), 17, canvas.MUTED)
	var info: Dictionary = canvas.state.plot_info(area, slot)
	canvas._center(Rect2(44, 299, 452, 22), _habitat_hint(info), 14, canvas.GREEN)
	var kinds: Array[String] = canvas.state.allowed_kinds(area, slot)
	var pages: int = maxi(1,ceili(float(kinds.size())/SEED_PAGE_SIZE))
	canvas.seed_page = clampi(canvas.seed_page,0,pages-1)
	var start: int = canvas.seed_page*SEED_PAGE_SIZE
	var count: int = mini(SEED_PAGE_SIZE,kinds.size()-start)
	var width: float = minf(224.0, 448.0 / maxi(1, count))
	var left: float = 270.0 - count * width / 2.0
	for local_index in range(count):
		var kind: String = kinds[start+local_index]
		var data: Dictionary = canvas.state.plant_data(kind, 1)
		var rect = Rect2(left + local_index * width + 4, 332, width - 8, 222)
		var same: bool = existing == kind
		var affordable: bool = canvas.state.coins >= int(data["cost"])
		var unlocked: bool = canvas.state.is_seed_unlocked(kind)
		_choice_surface(canvas, rect, "plant:"+kind, same, affordable and unlocked and not same)
		Visuals.draw(canvas, canvas.PLANT_ART[kind], Rect2(rect.position + Vector2(20, 6), Vector2(rect.size.x - 40, 94)), kind, 1, false)
		canvas._center(Rect2(rect.position + Vector2(4, 106), Vector2(rect.size.x - 8, 28)), data["name"], 20, canvas.INK, canvas.bold)
		var role: String = "Урожай: +%d" % data["home_yield"] if data["role"] == "income" else "Урон %d" % data["damage"]
		canvas._center(Rect2(rect.position + Vector2(3, 142), Vector2(rect.size.x - 6, 28)), role, 15, canvas.GREEN)
		canvas._center(Rect2(rect.position + Vector2(3, 182), Vector2(rect.size.x - 6, 30)), "Уже растёт" if same else "Семена: бой %d" % canvas.Missions.seed_unlock_stage(kind) if not unlocked else "%d монет" % data["cost"], 18, canvas.INK, canvas.bold)
		if affordable and unlocked and not same:
			canvas._hit(rect, "plant:" + kind)
	if pages > 1:
		canvas._button(Rect2(44,574,112,44),"<","seed_page:-1",canvas.seed_page>0,false)
		canvas._center(Rect2(169,574,202,43),"%d / %d" % [canvas.seed_page+1,pages],19,canvas.INK,canvas.bold)
		canvas._button(Rect2(384,574,112,44),">","seed_page:1",canvas.seed_page<pages-1,false)
	canvas._center(Rect2(44, 637, 452, 25), "Цена — за водную посадку" if area == "pond" else "Цена — за растение в выбранной клетке", 15, canvas.MUTED)
	if not existing.is_empty():
		canvas._center(Rect2(44, 671, 452, 25), "Новое растение начнёт с уровня 1", 15, canvas.MUTED)
	canvas._button(Rect2(44, 733, 452, 49), "Назад", "plot_back", true, false)


static func _plot_details(canvas: Node2D) -> void:
	_backdrop(canvas, Rect2(24, 172, 492, 610))
	var area: String = canvas.active_plot_area
	var slot: int = canvas.active_plot_slot
	var data: Dictionary = canvas.state.plot_data(area, slot)
	if data.is_empty():
		canvas._button(Rect2(44, 704, 452, 50), "Вернуться в сад", "close_home_panel")
		return
	var kind: String = data["kind"]
	var level: int = int(data["level"])
	var next_level: int = mini(level + 1, canvas.State.MAX_PLANT_LEVEL)
	var next: Dictionary = canvas.state.plant_data(kind, next_level)
	var cost: int = canvas.state.plot_upgrade_cost(area, slot)
	canvas._label(Rect2(44, 183, 450, 40), data["name"] + " · уровень %d" % level, 28, canvas.GREEN, canvas.bold)
	canvas._label(Rect2(45, 226, 450, 25), _plot_title(canvas, area, slot), 16, canvas.MUTED)
	var info: Dictionary = canvas.state.plot_info(area, slot)
	var legacy: bool = not canvas.state.allowed_kinds(area, slot).has(kind)
	var detail_hint: String = _habitat_hint(info)
	if legacy:
		detail_hint = "Ранняя посадка сохранена · замена — по району"
	elif data["role"] == "defense":
		var milestone: Dictionary = Visuals.defense_next_milestone(kind, level)
		if not milestone.is_empty():
			detail_hint = "Следующая форма: %s · уровень %d" % [milestone["label"], milestone["level"]]
	canvas._center(Rect2(44, 251, 452, 22), detail_hint, 14, canvas.MUTED if legacy else canvas.GREEN)
	Visuals.draw(canvas, canvas.PLANT_ART[kind], Rect2(66, 271, 138, 145), kind, level)
	canvas._center(Rect2(222, 314, 96, 45), "→", 34, canvas.MUTED, canvas.bold)
	Visuals.draw(canvas, canvas.PLANT_ART[kind], Rect2(336, 271, 138, 145), kind, next_level)
	canvas._center(Rect2(50, 423, 164, 27), "Сейчас", 16, canvas.MUTED)
	canvas._center(Rect2(326, 423, 164, 27), "После улучшения", 16, canvas.MUTED)
	if data["role"] == "income":
		_stat(canvas, 466, "Монет за урожай", str(data["home_yield"]), str(next["home_yield"]))
		_stat(canvas, 508, "Припасов за волну", str(data["battle_yield"]), str(next["battle_yield"]))
	else:
		canvas._center(Rect2(50, 450, 164, 23), _defense_label(kind, level), 14, canvas.GREEN)
		canvas._center(Rect2(326, 450, 164, 23), _defense_label(kind, next_level), 14, canvas.GREEN)
		_stat(canvas, 480, "Урон", "%.1f" % data["damage"], "%.1f" % next["damage"])
		_stat(canvas, 520, "Дальность", str(int(data["range"])), str(int(next["range"])))
	canvas._button(Rect2(44, 568, 452, 51), "Улучшить · %d монет" % cost if cost > 0 else "Максимальный уровень", "upgrade_plot", cost > 0 and canvas.state.coins >= cost)
	canvas._button(Rect2(44, 633, 452, 49), "Сменить растение", "change_plant", true, false)
	canvas._button(Rect2(44, 704, 452, 49), "Вернуться в сад", "close_home_panel", true, false)


static func _defense_label(kind: String, level: int) -> String:
	var label: String = Visuals.defense_label(kind, level)
	return "Водный защитник" if label.is_empty() and kind == "lotus" else label


static func _stat(canvas: Node2D, y: float, label: String, current: String, next: String) -> void:
	canvas._label(Rect2(47, y, 238, 30), label, 18, canvas.INK)
	canvas._center(Rect2(291, y, 201, 30), "%s → %s" % [current, next], 22, canvas.GREEN, canvas.bold)


static func _nursery_overview(canvas: Node2D) -> void:
	_backdrop(canvas, Rect2(24, 166, 492, 674))
	canvas._label(Rect2(44, 188, 450, 40), "Питомник", 27, canvas.GREEN, canvas.bold)
	var capacity: int = canvas.state.nursery_plot_capacity()
	var occupied: int = canvas.state.nursery_plots.count("")
	canvas._label(Rect2(45, 245, 450, 25), "Занято %d из %d мест · выберите клетку" % [capacity-occupied,capacity], 16, canvas.MUTED)
	canvas._button(Rect2(44,275,452,44),"К водным грядкам >","visit_pond",true,false)
	var pages: int = maxi(1,ceili(float(capacity)/NURSERY_PAGE_SIZE))
	canvas.nursery_page = clampi(canvas.nursery_page,0,pages-1)
	var start: int = canvas.nursery_page*NURSERY_PAGE_SIZE
	for index in range(start,mini(start+NURSERY_PAGE_SIZE,capacity)):
		var local_index: int = index-start
		var rect = Rect2(40 + local_index % 2 * 238, 342 + local_index / 2 * 76, 222, 64)
		var data: Dictionary = canvas.state.plot_data("nursery", index)
		_choice_surface(canvas, rect, "nursery_plot:%d" % index)
		if data.is_empty():
			canvas._center(rect, "Клетка %d · посадить" % (index + 1), 17, canvas.INK, canvas.bold)
		else:
			Visuals.draw(canvas, canvas.PLANT_ART[data["kind"]], Rect2(rect.position + Vector2(7, 5), Vector2(53, 54)), data["kind"], data["level"], false)
			canvas._label(Rect2(rect.position + Vector2(65, 5), Vector2(150, 21)), "Клетка %d" % (index + 1), 14, canvas.MUTED)
			canvas._label(Rect2(rect.position + Vector2(65, 28), Vector2(150, 28)), "%s · ур.%d" % [data["name"], data["level"]], 16, canvas.INK, canvas.bold)
		canvas._hit(rect, "nursery_plot:%d" % index)
	canvas._button(Rect2(44,654,112,44),"<","nursery_page:-1",canvas.nursery_page>0,false)
	canvas._center(Rect2(169,654,202,43),"%d / %d" % [canvas.nursery_page+1,pages],19,canvas.INK,canvas.bold)
	canvas._button(Rect2(384,654,112,44),">","nursery_page:1",canvas.nursery_page<pages-1,false)
	canvas._button(Rect2(44, 756, 452, 49), "Вернуться в сад", "close_home_panel", true, false)


static func _greenhouse(canvas: Node2D) -> void:
	HelperMenus.draw(canvas)


static func draw_battle(canvas: Node2D) -> void:
	if canvas.battle_panel == "loadout":
		_loadout(canvas)
		return
	_backdrop(canvas, Rect2(24, 192, 492, 575))
	if canvas.battle_panel == "inspect":
		_battle_details(canvas)
		return
	canvas._label(Rect2(44, 202, 450, 40), "Ваши растения", 28, canvas.GREEN, canvas.bold)
	canvas._label(Rect2(45, 246, 450, 25), "Состав выбран перед боем · установка за припасы", 16, canvas.MUTED)
	var entries: Array[Dictionary] = canvas.battle.available_plants()
	var pages: int = maxi(1, ceili(float(entries.size()) / PAGE_SIZE))
	canvas.plant_page = clampi(canvas.plant_page, 0, pages - 1)
	var start: int = canvas.plant_page * PAGE_SIZE
	for index in range(start, mini(start + PAGE_SIZE, entries.size())):
		var local_index: int = index - start
		var entry: Dictionary = entries[index]
		var data: Dictionary = canvas.state.plant_data(entry["kind"], entry["level"])
		var rect = Rect2(42 + local_index % 3 * 155, 288 + local_index / 3 * 139, 146, 130)
		var affordable: bool = canvas.battle.supplies >= int(data["battle_cost"])
		var same: bool = canvas.battle.get_plant(canvas.active_battle_slot).get("kind", "") == entry["kind"]
		_choice_surface(canvas, rect, "deploy:"+str(entry["kind"]), same, affordable and not same)
		Visuals.draw(canvas, canvas.PLANT_ART[entry["kind"]], Rect2(rect.position + Vector2(35, 3), Vector2(76, 65)), entry["kind"], entry["level"])
		canvas._center(Rect2(rect.position + Vector2(1, 66), Vector2(144, 23)), data["name"], 17, canvas.INK, canvas.bold)
		canvas._center(Rect2(rect.position + Vector2(1, 109), Vector2(144, 20)), "Уже в клетке" if same else "%d прип." % data["battle_cost"], 15, canvas.MUTED)
		var compact: String = _compact_role(canvas, entry["kind"], int(entry["level"]))
		canvas._center(Rect2(rect.position + Vector2(1, 89), Vector2(144, 20)), compact, 14, canvas.GREEN)
		if affordable and not same:
			canvas._hit(rect, "deploy:" + entry["kind"])
	if entries.is_empty():
		canvas._paragraph(Vector2(63, 353), "Сначала выберите выращенные виды для этого боя.", 414, 20, canvas.MUTED)
	canvas._center(Rect2(44, 582, 452, 24), "Копии не ограничены · каждая установка оплачивается", 14, canvas.MUTED)
	if pages > 1:
		canvas._button(Rect2(44, 617, 112, 44), "<", "battle_page:-1", canvas.plant_page > 0, false)
		canvas._center(Rect2(169, 617, 202, 43), "%d / %d" % [canvas.plant_page + 1, pages], 19, canvas.INK, canvas.bold)
		canvas._button(Rect2(384, 617, 112, 44), ">", "battle_page:1", canvas.plant_page < pages - 1, false)
	canvas._button(Rect2(44, 692, 452, 49), "Вернуться к бою", "close_battle_panel", true, false)


static func _loadout(canvas: Node2D) -> void:
	_backdrop(canvas, Rect2(24, 150, 492, 650))
	canvas._label(Rect2(44, 161, 450, 40), "Соберите состав", 27, canvas.GREEN, canvas.bold)
	canvas._label(Rect2(45, 205, 450, 25), "Выберите виды · уровни берём из вашего сада", 16, canvas.MUTED)
	canvas._button(Rect2(44, 232, 452, 44), "План участка · враги и волны >", "wave_preview", true, false)
	var options: Array[Dictionary] = canvas.battle.loadout_options()
	var pages: int = maxi(1, ceili(float(options.size()) / PAGE_SIZE))
	canvas.loadout_page = clampi(canvas.loadout_page, 0, pages - 1)
	var start: int = canvas.loadout_page * PAGE_SIZE
	var has_defense: bool = false
	# A selected defender on another page still counts toward the whole loadout.
	for option in options:
		if canvas.loadout_choices.has(option["kind"]) and option["role"] == "defense":
			has_defense = true
	for index in range(start, mini(start + PAGE_SIZE, options.size())):
		var entry: Dictionary = options[index]
		var local_index: int = index - start
		var kind: String = entry["kind"]
		var chosen: bool = canvas.loadout_choices.has(kind)
		var data: Dictionary = canvas.state.plant_data(kind, entry["level"])
		var rect = Rect2(42 + local_index % 3 * 155, 282 + local_index / 3 * 145, 146, 132)
		_choice_surface(canvas, rect, "loadout_toggle:"+kind, chosen)
		Visuals.draw(canvas, canvas.PLANT_ART[kind], Rect2(rect.position + Vector2(33, 3), Vector2(80, 64)), kind, entry["level"])
		canvas._center(Rect2(rect.position + Vector2(1, 66), Vector2(144, 23)), data["name"], 17, canvas.INK, canvas.bold)
		canvas._center(Rect2(rect.position + Vector2(1, 109), Vector2(144, 20)), "%d прип. · %s" % [entry["cost"], "взят" if chosen else "выбрать"], 14, canvas.GREEN if chosen else canvas.MUTED, canvas.bold)
		canvas._center(Rect2(rect.position + Vector2(1, 89), Vector2(144, 20)), _compact_role(canvas, kind, int(entry["level"])), 14, canvas.GREEN)
		canvas._hit(rect, "loadout_toggle:" + kind)
	if options.is_empty():
		canvas._paragraph(Vector2(55, 321), "Посадите растения в саду и питомнике, чтобы взять их с собой в бой.", 430, 20, canvas.MUTED)
	if pages > 1:
		canvas._button(Rect2(44, 566, 112, 44), "<", "loadout_page:-1", canvas.loadout_page > 0, false)
		canvas._center(Rect2(169, 566, 202, 43), "Страница %d / %d" % [canvas.loadout_page + 1, pages], 17, canvas.INK, canvas.bold)
		canvas._button(Rect2(384, 566, 112, 44), ">", "loadout_page:1", canvas.loadout_page < pages - 1, false)
	canvas._center(Rect2(44, 612, 452, 23), "Старт: 240 припасов · монеты сада не тратятся", 15, canvas.MUTED)
	canvas._center(Rect2(44, 639, 452, 21), "Состав фиксируется после первой установки" if has_defense else "Для защиты сада возьмите хотя бы одну пушку", 14, canvas.MUTED if has_defense else Color("a45732"))
	canvas._button(Rect2(44, 663, 452, 51), "К полю боя · выбрано видов: %d" % canvas.loadout_choices.size(), "confirm_loadout", not canvas.loadout_choices.is_empty())
	canvas._button(Rect2(44, 733, 452, 44), "Назад", "loadout_back", true, false)


static func _compact_role(canvas: Node2D, kind: String, level: int) -> String:
	if canvas.state.plant_data(kind, level).get("role", "") == "income":
		var projection: Dictionary = BattleUI.income_projection(canvas.battle, kind, level)
		return "+%d · окуп. %d" % [projection["yield"], projection["payback_waves"]] if projection["can_payback"] else "+%d · поздно" % projection["yield"]
	return {"nettle": "Одиночный урон", "lavender": "Контроль группы", "pepper": "Урон по площади", "lotus": "Контроль цели"}.get(kind, "Защита")


static func _battle_details(canvas: Node2D) -> void:
	var placement: Dictionary = canvas.battle.get_plant(canvas.active_battle_slot)
	if placement.is_empty(): return
	var kind: String = placement["kind"]
	var data: Dictionary = canvas.state.plant_data(kind, placement["level"])
	canvas._label(Rect2(44, 204, 450, 40), data["name"] + " · уровень %d" % placement["level"], 28, canvas.GREEN, canvas.bold)
	Visuals.draw(canvas, canvas.PLANT_ART[kind], Rect2(190, 262, 160, 155), kind, placement["level"], true, true)
	var role: String = "Корни мешают стрелять · %.1f с" % float(placement["jammed"]) if float(placement.get("jammed", 0.0)) > 0.0 else BattleUI.role_summary(kind)
	canvas._center(Rect2(44, 426, 452, 27), role, 17, canvas.INK, canvas.bold)
	var stat: String = "+%d прип. за волну" % canvas.battle.plant_income(kind, placement["level"]) if data["role"] == "income" else "Урон %.1f · дальность %d" % [data["damage"], data["range"]]
	canvas._center(Rect2(44, 461, 452, 35), stat, 22, canvas.GREEN, canvas.bold)
	if data["role"] == "income":
		var projection: Dictionary = BattleUI.income_projection(canvas.battle, kind, placement["level"])
		canvas._label(Rect2(50, 508, 440, 55), "Новая копия: " + projection["summary"] + ". Остаток выплат: +%d прип." % (projection["yield"] * projection["remaining_harvests"]), 15, canvas.MUTED, null, true, true)
	else:
		for index in range(3):
			var mode: String = ["first", "strong", "fast"][index]
			canvas._button(Rect2(44 + 155 * index, 519, 142, 44), ["Первые", "Сильные", "Быстрые"][index], "target_mode:" + mode, true, placement.get("target_mode", "first") == mode)
	canvas._button(Rect2(44, 579, 452, 48), "Сменить растение", "change_battle_plant", not canvas.battle.available_plants().is_empty())
	canvas._button(Rect2(44, 638, 452, 46), "Открыть растение в саду", "manage_source", true, false)
	canvas._button(Rect2(44, 700, 452, 46), "Вернуться к бою", "close_battle_panel", true, false)
