class_name BattlePresentation
extends RefCounted
const Clip = preload("res://scripts/canvas_clip.gd")

## Explains actual battle rules without changing the simulation or its budget.
## Forecasts use the same authored plan as spawning; income uses the snapshot.
const Encounter = preload("res://scripts/battle_encounter_art.gd")
const Director = preload("res://scripts/battle_director.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Missions = preload("res://scripts/campaign.gd")
const FORECAST_RECT := Rect2(24, 756, 352, 46)
const PRIMARY_RECT := Rect2(24, 899, 382, 45)
const SPEED_RECT := Rect2(418, 899, 98, 45)
const QUICK_PAGE_SIZE: int = 4
const GUIDE_CARD := Rect2(24, 112, 492, 754)
const ENEMY_PAGE_SIZE: int = 3
const ENEMY_GUIDE_ORDER: Array[String] = ["beetle", "aphid", "whitefly", "snail", "locust", "leafroller", "burrower", "wireworm", "healer", "soldier", "queen"]
const ENEMY_GROUP_LABELS: Dictionary = {"sap_suckers": "Сосущие", "leaf_chewers": "Листогрызы", "soil": "Почвенные", "molluscs": "Моллюски", "special": "Особые"}


static func role_summary(kind: String) -> String:
	match kind:
		"nettle": return "Быстрый огонь по одной цели"
		"lavender": return "Замедляет плотные группы"
		"pepper": return "Взрыв по группе вредителей"
		"lotus": return "Сильное замедление одной цели"
	return "Припасы после завершённой волны" if Catalog.PLANTS.get(kind, {}).get("role", "") == "income" else "Защита вдоль тропы"


static func income_projection(battle: Object, kind: String, level: int) -> Dictionary:
	var result: Dictionary = {"yield": 0, "cost": 0, "remaining_harvests": 0, "payback_waves": 0, "net_supplies": 0, "can_payback": false, "summary": "Не производит припасы"}
	if battle == null or battle.get("state") == null:
		return result
	var data: Dictionary = battle.get("state").plant_data(kind, level)
	if data.get("role", "") != "income":
		return result
	var cost: int = int(data.get("battle_cost", 0))
	for template in battle.get("loadout"):
		if template.get("kind", "") == kind:
			cost = int(template.get("cost", cost))
			break
	var harvest: int = int(battle.plant_income(kind, level))
	var phase: String = str(battle.get("phase"))
	var remaining: int = int(battle.get("total_waves")) - int(battle.get("wave"))
	if phase == "running":
		remaining += 1
	elif phase in ["won", "lost"]:
		remaining = 0
	remaining = clampi(remaining, 0, int(battle.get("total_waves")))
	var payback: int = ceili(float(cost) / float(harvest)) if harvest > 0 else 0
	var can_payback: bool = harvest > 0 and payback <= remaining
	var summary: String = "Окупится за %s · осталось %d" % [_waves(payback), remaining] if can_payback else "Не окупится за этот бой · осталось %d" % remaining
	return {"yield": harvest, "cost": cost, "remaining_harvests": remaining, "payback_waves": payback, "net_supplies": harvest * remaining - cost, "can_payback": can_payback, "summary": summary}


static func _waves(amount: int) -> String:
	var ending: String = "волн"
	if amount % 100 < 11 or amount % 100 > 14:
		if amount % 10 == 1: ending = "волну"
		elif amount % 10 in [2, 3, 4]: ending = "волны"
	return "%d %s" % [amount, ending]


static func _preview(battle: Object) -> Dictionary:
	return battle.preview_wave() if battle != null else {}


static func _enemy_name(battle: Object, kind: String) -> String:
	return str(battle.enemy_info(kind).get("name", kind))


static func _short_enemy_name(battle: Object, kind: String) -> String:
	return {"snail": "Улитка", "queen": "Матка", "healer": "Лекарь", "soldier": "Солдат", "leafroller": "Листовёртка", "wireworm": "Проволочник", "whitefly": "Белокрылка"}.get(kind, _enemy_name(battle, kind))


static func _counts_text(battle: Object, counts: Dictionary) -> String:
	var labels: Array[String] = []
	for kind in counts:
		labels.append("%s ×%d" % [_short_enemy_name(battle, str(kind)), counts[kind]])
	return " · ".join(labels)


static func draw_header(canvas: Node2D) -> void:
	# Independent floating surfaces leave the landscape visible between HUD
	# groups. Their controls stay in the established safe area above the field.
	var battle: Object = canvas.battle
	var stage: int = int(canvas.current_stage)
	var info: Dictionary = Missions.stage_info(stage)
	canvas._hud_panel(Rect2(12,12,330,58))
	canvas._button(Rect2(20,19,44,44), "<", "home", true, false)
	canvas._label(Rect2(78,17,250,28), "Защитите теплицу", 23, canvas.INK, canvas.display_font)
	canvas._label(Rect2(79,47,250,20), "%s · %d/%d" % [info.get("title", "Участок"),stage,Missions.COUNT], 14, canvas.MUTED)
	canvas._hit(Rect2(74,16,258,50), "choose_stage")
	canvas._hud_panel(Rect2(354,12,174,58))
	canvas._draw_supply(Rect2(367,31,26,26))
	canvas._label(Rect2(405,18,111,18), "Припасы", 12, canvas.MUTED, canvas.bold)
	canvas._label(Rect2(405,36,111,28), canvas._compact_coins(int(battle.supplies)) if battle != null else "240", 22, canvas.INK, canvas.bold)
	var hp: int = int(battle.base_hp) if battle != null else 10
	var can_edit: bool = battle != null and battle.phase == "preparing" and battle.plants.is_empty()
	canvas._hud_panel(Rect2(12,78,328 if can_edit else 450,40))
	_draw_heart(canvas, Rect2(29,90,19,17), Color("b85441") if hp > 3 else Color("d03928"))
	canvas._label(Rect2(55,85,87,28), "%d / 10" % hp, 19, canvas.GREEN if hp > 3 else Color("b65233"), canvas.bold)
	var number: int = 1
	var total: int = 5
	var progress: String = "Подготовка"
	if battle != null:
		total = int(battle.total_waves)
		number = maxi(1,int(battle.wave) if battle.phase in ["running","won","lost"] else mini(int(battle.wave)+1,total))
		if battle.phase == "running": progress = "заход %d/%d" % [battle.active_assault(),int(_preview(battle).get("assault_count",1))]
		elif battle.phase == "won": progress = "Победа"
		elif battle.phase == "lost": progress = "Поражение"
	canvas._label(Rect2(153,86,179 if can_edit else 291,25), "Волна %d/%d" % [number,total] if can_edit else "Волна %d/%d · %s" % [number,total,progress],16,canvas.INK,canvas.bold)
	if battle != null and battle.phase=="running":
		var active_assault: int = battle.active_assault()
		for index in range(int(_preview(battle).get("assault_count",1))):
			canvas.draw_rect(Rect2(154+index*26,113,21,2),canvas.GREEN if index<active_assault else Color("c8cfb7"))
	if can_edit: canvas._button(Rect2(352,74,110,44), "Состав", "change_loadout", true, false)
	canvas._button(Rect2(472,74,44,44), "?", "wave_preview", true, false)


static func _draw_heart(canvas: Node2D, rect: Rect2, color: Color) -> void:
	var unit: Vector2 = rect.size / Vector2(12, 11)
	var shape := PackedVector2Array([Vector2(0,2),Vector2(2,0),Vector2(4,0),Vector2(6,2),Vector2(8,0),Vector2(10,0),Vector2(12,2),Vector2(12,5),Vector2(6,11),Vector2(0,5)])
	for index in range(shape.size()): shape[index] = rect.position + shape[index] * unit
	canvas.draw_colored_polygon(shape, color.darkened(0.28))
	var inside := PackedVector2Array()
	for point in shape: inside.append(rect.get_center() + (point-rect.get_center())*0.8)
	canvas.draw_colored_polygon(inside, color)
	canvas.draw_rect(Rect2(rect.position+Vector2(3,2)*unit,Vector2(2,2)*unit),Color("f0af8e"))


static func draw_footer(canvas: Node2D) -> void:
	var battle: Object = canvas.battle
	if battle == null:
		return
	var plan: Dictionary = _preview(battle)
	var phase: String = str(battle.phase)
	var preview_number: int = int(battle.wave) if phase in ["running", "won", "lost"] else mini(int(battle.wave) + 1, int(battle.total_waves))
	preview_number = maxi(1, preview_number)
	var readout: Dictionary = Encounter.battle_readout(battle,str(canvas.quick_plant_kind))
	canvas._hud_panel(Rect2(20,704,500,43))
	canvas._label(Rect2(32,706,476,21),readout.get("title",""),15,canvas.INK,canvas.bold,false,true)
	canvas._label(Rect2(32,727,476,18),readout.get("detail",""),12,canvas.MUTED,null,false,true)
	canvas._hud_panel(Rect2(12,752,516,50))
	var context: String = "Сейчас" if phase == "running" else "Завершена" if phase == "won" else "Прервана" if phase == "lost" else "Далее"
	canvas._label(Rect2(26, 756, 345, 24), "%s %d: %s" % [context, preview_number, plan.get("title", "Оборона сада")], 16, canvas.GREEN, canvas.bold)
	_draw_forecast_icons(canvas, Encounter.remaining_counts(battle), Rect2(26, 781, 345, 20))
	if phase=="running":
		canvas.draw_rect(Rect2(26,800,342,2),Color("d8dcc3"))
		canvas.draw_rect(Rect2(26,800,342*float(readout.get("progress",0)),2),canvas.GREEN)
	canvas._hit(FORECAST_RECT, "wave_preview")
	canvas._button(Rect2(386, 756, 130, 44), "Волны", "wave_preview", true, false)
	_draw_quick_plants(canvas)
	var action_label: String = "Бой завершён"
	if phase == "running":
		action_label = "Продолжить волну" if battle.paused else "Пауза"
	elif phase not in ["won", "lost"]:
		action_label = "Начать волну %d >" % (battle.wave + 1)
	canvas._button(PRIMARY_RECT, action_label, "primary", battle.loadout_ready and phase not in ["won", "lost"])
	canvas._button(SPEED_RECT, "×%d" % int(battle.speed), "speed", true, false)


static func _draw_forecast_icons(canvas: Node2D, counts: Dictionary, rect: Rect2) -> void:
	# The complete group mix stays visible without a permanently open briefing.
	var cell: float = minf(88, rect.size.x / maxf(1, counts.size()))
	var index: int = 0
	for kind in counts:
		var at: Vector2 = rect.position + Vector2(index*cell,0)
		var texture: Texture2D = canvas.BUG_ART.get(kind, null)
		if texture != null: canvas._sprite(texture, Rect2(at,Vector2(20,20)))
		canvas._label(Rect2(at+Vector2(22,0),Vector2(cell-24,20)), "×%d" % counts[kind], 13, canvas.INK, canvas.bold)
		index += 1


static func _draw_quick_plants(canvas: Node2D) -> void:
	var battle: Object = canvas.battle
	var choices: Array = battle.loadout
	var pages: int = maxi(1,ceili(float(choices.size())/QUICK_PAGE_SIZE))
	var page: int = clampi(int(canvas.quick_plant_page),0,pages-1)
	canvas.quick_plant_page = page
	var active: bool = battle.loadout_ready and battle.phase not in ["won","lost"]
	if pages > 1:
		canvas._button(Rect2(16, 824, 44, 44), "<", "battle_quick_page:-1", page > 0, false)
		canvas._button(Rect2(480, 824, 44, 44), ">", "battle_quick_page:1", page < pages-1, false)
	var visible: Array = choices.slice(page*QUICK_PAGE_SIZE,mini((page+1)*QUICK_PAGE_SIZE,choices.size()))
	var start_x: float = 64.0 if pages > 1 else 24.0
	var width: float = 98.0 if pages > 1 else minf(116.0,(492.0-8.0*maxi(0,visible.size()-1))/maxf(1,visible.size()))
	if pages == 1 and visible.size() in [1,2,3]:
		width = 148.0
		start_x = 24.0+(492.0-(visible.size()*width+maxi(0,visible.size()-1)*8.0))/2.0
	for index in range(visible.size()):
		var entry: Dictionary = visible[index]
		var kind: String = str(entry["kind"])
		var level: int = int(entry["level"])
		var cost: int = int(entry["cost"])
		var selected: bool = str(canvas.quick_plant_kind) == kind
		var enabled: bool = active and int(battle.supplies) >= cost
		var rect := Rect2(start_x+index*(width+8.0 if pages == 1 else 104.0),806,width,82)
		var background: Color = canvas.UiTheme.SELECTED if selected and enabled else Color("faf7ed") if enabled else canvas.UiTheme.DISABLED
		var action: String = "battle_quick_select:"+kind
		if canvas._is_control_pressed(action): background = background.darkened(0.06)
		canvas._box(rect,background,6,Color("63845b") if selected else Color("d5d3c0"))
		if selected: canvas.draw_rect(Rect2(rect.position+Vector2(8,2),Vector2(rect.size.x-16,3)),canvas.GREEN)
		var role: String = {"nettle":"ОГОНЬ","lavender":"КОНТРОЛЬ","pepper":"ВЗРЫВ","lotus":"КОНТРОЛЬ"}.get(kind,"УРОЖАЙ")
		canvas.draw_rect(Rect2(rect.position+Vector2(2,2),Vector2(3,rect.size.y-4)),Color("779665") if Catalog.PLANTS[kind]["role"]=="defense" else Color("c6a45b"))
		canvas._label(Rect2(rect.position+Vector2(6,3),Vector2(rect.size.x-12,18)),role,10,color_for_role(kind),canvas.bold,false,true)
		var icon_rect := Rect2(rect.position+Vector2((rect.size.x-40)/2.0,14),Vector2(40,29))
		canvas.Visuals.draw(canvas,canvas.PLANT_ART[kind],icon_rect,kind,level,false,true)
		var name: String = str(Catalog.PLANTS[kind]["name"])
		var color: Color = canvas.INK if enabled or selected else Color("737969")
		canvas._label(Rect2(rect.position+Vector2(4,44),Vector2(rect.size.x-8,18)),"%s · %d" % [name,level],13,color,canvas.bold,false,true)
		var price_x: float = rect.position.x+rect.size.x/2.0-25
		canvas._draw_supply(Rect2(price_x,rect.position.y+64,14,14))
		canvas._label(Rect2(price_x+19,rect.position.y+61,53,20),str(cost),16,canvas.INK if enabled else canvas.MUTED,canvas.bold)
		# The current choice may always be cancelled, even after its last
		# affordable copy was placed. Selecting a new unaffordable kind is blocked.
		if enabled or (active and selected): canvas._hit(rect,action)
	if visible.is_empty():
		canvas._center(Rect2(24,817,492,55),"Выберите выращенные растения для боя",17,canvas.MUTED)


static func color_for_role(kind: String) -> Color:
	return Color("685882") if kind in ["lavender","lotus"] else Color("97592d") if kind=="pepper" else Color("496441") if kind=="nettle" else Color("90712f")


static func enemy_lesson(kind: String, profile: Dictionary, stage: int = 1) -> String:
	match kind:
		"beetle": return "Обычная цель. Быстрый одиночный огонь крапивы."
		"aphid": return "Плотный рой: перекройте тропу огнём нескольких быстрых пушек." if stage == 1 else "Плотный рой: лаванда удержит группу под огнём пушек."
		"whitefly":
			return "Все пушки достают летающий рой. Замедление слабее на %d%%: добавьте быстрый огонь." % roundi(float(profile.get("slow_resistance", 0.5)) * 100)
		"leafroller":
			return "Один раз при %d%% здоровья укрывается на %.1f с: прямой урон −%d%%. Взрыв обходит лист; сосредоточьте огонь." % [roundi(float(profile.get("leaf_shield_threshold", 0.6)) * 100), profile.get("leaf_shield_duration", 3.0), roundi(float(profile.get("leaf_shield_reduction", 0.45)) * 100)]
		"wireworm":
			return "Раз в %.0f с глушит одну пушку в радиусе %d на %.1f с. Разнесите пушки; доходные посадки не страдают." % [profile.get("disruption_interval", 4.0), profile.get("disruption_radius", 82), profile.get("disruption_duration", 1.2)]
		"snail": return "Панцирь снижает каждый удар на %d. Держите под огнём дольше." % int(profile.get("armor", 0))
		"locust": return "Быстро выходит из обстрела. Замедлите, выберите «Быстрые»."
		"queen": return "Опасная одиночная цель: долгий обстрел и приоритет «Сильные»."
		"healer":
			var heal: String = str(profile.get("heal_amount", 6))
			if profile.has("heal_min") and profile["heal_min"] != profile["heal_max"]:
				heal = "%d–%d" % [profile["heal_min"], profile["heal_max"]]
			return "Раз в %.1f с лечит до %d соседей на %s в радиусе %d. Себя и лекарей не лечит. Сосредоточьте огонь на поддержке." % [profile.get("heal_interval", 2.4), profile.get("heal_targets", 3), heal, profile.get("heal_radius", 72)]
		"burrower":
			var attack: String = "Замедляйте; держите резерв у выхода." if stage < 3 else "Взрыв достаёт под землёй; замедление действует."
			return "Первый нырок: %.1f с, потом раз в %.1f с; скрыт от прицела %.1f с. %s" % [profile.get("burrow_first", 2.0), profile.get("burrow_cycle", 5.0), profile.get("burrow_duration", 1.2), attack]
		"soldier":
			return "При здоровье %d%% и ниже ускоряется на %d%% до конца, даже после лечения. Добивайте раненых или замедляйте." % [roundi(float(profile.get("frenzy_threshold", 0.45)) * 100), roundi((float(profile.get("frenzy_multiplier", 1.55)) - 1.0) * 100)]
	return str(profile.get("counter", ""))


static func guide_enemy_profiles(stage: int, category: String = "all") -> Array[Dictionary]:
	# Health ranges only use waves where the creature really occurs. A final
	# boss is never advertised with hypothetical opening-wave health.
	var result: Array[Dictionary] = []
	var order: Array[String] = ENEMY_GUIDE_ORDER.duplicate()
	for kind in Director.ENEMIES:
		if not order.has(kind): order.append(kind)
	for kind in order:
		var waves: Array[int] = []
		var low: int = 2147483647
		var high: int = 0
		var profile: Dictionary = {}
		var heal_low: int = 2147483647
		var heal_high: int = 0
		for wave in range(1, Director.WAVE_COUNT + 1):
			if not Director.wave_plan(stage, wave).get("counts", {}).has(kind):
				continue
			waves.append(wave)
			profile = Director.enemy_profile(kind, stage, wave)
			low = mini(low, roundi(float(profile.get("hp", 0))))
			high = maxi(high, roundi(float(profile.get("hp", 0))))
			if profile.has("heal_amount"):
				heal_low = mini(heal_low, int(profile["heal_amount"]))
				heal_high = maxi(heal_high, int(profile["heal_amount"]))
		if profile.is_empty():
			continue
		if category != "all" and Director.ENEMY_GROUPS.has(category) and profile.get("category", "") != category:
			continue
		profile["hp_min"] = low
		profile["hp_max"] = high
		profile["waves"] = waves
		if heal_high > 0:
			profile["heal_min"] = heal_low
			profile["heal_max"] = heal_high
		result.append(profile)
	return result


static func guide_enemy_groups(stage: int) -> Array[Dictionary]:
	var profiles: Array[Dictionary] = guide_enemy_profiles(stage)
	var result: Array[Dictionary] = [{"id": "all", "name": "Все", "count": profiles.size()}]
	for id in Director.ENEMY_GROUPS:
		var count: int = 0
		for profile in profiles:
			if profile.get("category", "") == id:
				count += 1
		result.append({"id": id, "name": ENEMY_GROUP_LABELS.get(id, Director.ENEMY_GROUPS[id]["name"]), "count": count})
	return result


static func guide_enemy_page(stage: int, requested_page: int, category: String = "all") -> Dictionary:
	var selected: String = category if category == "all" or Director.ENEMY_GROUPS.has(category) else "all"
	var profiles: Array[Dictionary] = guide_enemy_profiles(stage, selected)
	var pages: int = maxi(1, ceili(float(profiles.size()) / ENEMY_PAGE_SIZE))
	var page: int = clampi(requested_page, 0, pages - 1)
	return {"profiles": profiles.slice(page * ENEMY_PAGE_SIZE, mini((page + 1) * ENEMY_PAGE_SIZE, profiles.size())), "page": page, "pages": pages, "total": profiles.size(), "category": selected}


static func enemy_category_caption(profile: Dictionary) -> String:
	match str(profile.get("category", "")):
		"sap_suckers": return "Сосущие · питаются соками растений"
		"leaf_chewers": return "Листогрызы · повреждают листья и побеги"
		"soil": return "Почвенные · повреждают корни и семена"
		"molluscs": return "Моллюски · поедают мягкие части растений"
		"special": return "Особые · вымышленные способности" if profile.get("nature", "") == "fantasy" else "Особые · игровой образ насекомого"
	return str(profile.get("category_name", ""))


static func _draw_counts_row(canvas: Node2D, battle: Object, counts: Dictionary, rect: Rect2) -> void:
	var compact: bool = counts.size() >= 4
	if not compact and rect.size.y < 30:
		canvas._label(rect, _counts_text(battle, counts), 14, canvas.INK)
		return
	var width: float = minf(155.0, rect.size.x / maxf(1.0, float(counts.size())))
	var icon_size: float = minf(26.0 if counts.size() >= 6 else 31.0, rect.size.y)
	var index: int = 0
	for kind in counts:
		var card := Rect2(rect.position + Vector2(index * width, 0), Vector2(width - 3, rect.size.y))
		var texture: Texture2D = canvas.BUG_ART.get(kind, null)
		if texture != null:
			canvas._sprite(texture, Rect2(card.position, Vector2.ONE * icon_size))
		else:
			canvas._label(Rect2(card.position, Vector2(icon_size, rect.size.y)), _short_enemy_name(battle, kind).left(2), 12, canvas.MUTED, canvas.bold)
		var left: float = icon_size + 2
		canvas._label(Rect2(card.position + Vector2(left, 0), card.size - Vector2(left, 0)), "×%d" % counts[kind] if compact else "%s ×%d" % [_short_enemy_name(battle, kind), counts[kind]], 14, canvas.INK, canvas.bold, not compact)
		index += 1


static func draw_wave_guide(canvas: Node2D) -> void:
	var battle: Object = canvas.battle
	if battle == null:
		return
	canvas.hitboxes.clear()
	canvas.draw_rect(Rect2(0, 0, 540, 960), Color(0.1, 0.18, 0.12, 0.48))
	canvas._box(GUIDE_CARD, canvas.PAPER)
	canvas._label(Rect2(44, 129, 452, 42), "Вредители участка" if canvas.wave_guide_tab == "enemies" else "Как устроен бой" if canvas.wave_guide_tab == "rules" else "План обороны", 27, canvas.GREEN, canvas.bold)
	var tab: String = str(canvas.wave_guide_tab)
	canvas._button(Rect2(44, 174, 140, 44), "Волны", "battle_guide_tab:waves", true, tab == "waves")
	canvas._button(Rect2(200, 174, 140, 44), "Вредители", "battle_guide_tab:enemies", true, tab == "enemies")
	canvas._button(Rect2(356, 174, 140, 44), "Правила", "battle_guide_tab:rules", true, tab == "rules")
	if tab == "rules":
		var lessons: Array[Array] = [
			["Защитите теплицу", "Запускайте 5 волн сами. У теплицы 10 прочности: обычный вредитель отнимает 1, панцирная улитка — 2, матка — 3."],
			["Два разных ресурса", "Каждый бой: 240 припасов. Их дают убийства, волны и урожай. Убийства и урожай имеют 20% шанс монет сада; победа тоже даёт монеты."],
			["Состав и копии", "Только выращенные виды; лучший уровень фиксируется на бой. Копий сколько угодно. Установка и замена оплачиваются припасами, без возврата."],
			["Доход или огонь", "Урожай приходит за успешную волну. Сравните цену новой копии с оставшимися выплатами; не ослабляйте оборону ради дохода."],
			["Тактика и повтор", "Меняйте приоритет: первые, сильные или быстрые. Пауза даёт время подумать. Отчёт объясняет прорывы; монеты и посадки сада остаются."],
		]
		for index in range(lessons.size()):
			var rect := Rect2(42, 229 + index * 114, 456, 110)
			canvas._box(rect, canvas.PAPER)
			canvas._label(Rect2(rect.position + Vector2(12, 5), Vector2(432, 28)), lessons[index][0], 19, canvas.INK, canvas.bold)
			canvas._label(Rect2(rect.position + Vector2(12, 37), Vector2(432, 68)), lessons[index][1], 14, canvas.MUTED, null, true)
		canvas._button(Rect2(44, 803, 452, 49), "Вернуться к бою", "close_wave_preview", true, false)
		return
	if tab == "enemies":
		var page: Dictionary = guide_enemy_page(int(battle.stage), int(canvas.enemy_guide_page), str(canvas.enemy_guide_category))
		canvas.enemy_guide_page = page["page"]
		canvas.enemy_guide_category = page["category"]
		var groups: Array[Dictionary] = guide_enemy_groups(int(battle.stage))
		for index in range(groups.size()):
			var group: Dictionary = groups[index]
			canvas._button(Rect2(44 + (index % 3) * 156, 224 + (index / 3) * 48, 140, 44), "%s · %d" % [group["name"], group["count"]], "enemy_group:" + str(group["id"]), int(group["count"]) > 0, page["category"] == group["id"])
		var profiles: Array = page["profiles"]
		for index in range(profiles.size()):
			var profile: Dictionary = profiles[index]
			var kind: String = str(profile["kind"])
			var rect := Rect2(42, 322 + index * 148, 456, 144)
			canvas._box(rect, canvas.PAPER)
			var texture: Texture2D = canvas.BUG_ART.get(kind, null)
			if texture != null: canvas._sprite(texture, Rect2(rect.position + Vector2(12, 2), Vector2(30, 30)))
			canvas._label(Rect2(rect.position + Vector2(49, 3), Vector2(395, 28)), str(profile.get("name", kind)), 19, canvas.INK, canvas.bold)
			canvas._label(Rect2(rect.position + Vector2(12, 32), Vector2(432, 20)), enemy_category_caption(profile), 14, profile.get("category_color", canvas.GREEN).darkened(0.42))
			var health: String = str(profile["hp_min"]) if profile["hp_min"] == profile["hp_max"] else "%d–%d" % [profile["hp_min"], profile["hp_max"]]
			canvas._label(Rect2(rect.position + Vector2(12, 53), Vector2(432, 21)), "Здоровье %s · броня %d · урон теплице %d" % [health, int(profile.get("armor", 0)), int(profile.get("leak_damage", 1))], 14, canvas.GREEN)
			canvas._label(Rect2(rect.position + Vector2(12, 76), Vector2(432, 62)), enemy_lesson(kind, profile, int(battle.stage)), 14, canvas.MUTED, null, true)
		if profiles.is_empty():
			canvas._center(Rect2(54, 400, 432, 70), "На этом участке таких вредителей пока нет", 17, canvas.MUTED)
		if page["pages"] > 1:
			canvas._button(Rect2(44, 768, 112, 44), "<", "enemy_guide_page:-1", page["page"] > 0, false)
			canvas._center(Rect2(169, 768, 202, 44), "Виды: %d / %d" % [page["page"] + 1, page["pages"]], 17, canvas.INK, canvas.bold)
			canvas._button(Rect2(384, 768, 112, 44), ">", "enemy_guide_page:1", page["page"] < page["pages"] - 1, false)
		canvas._button(Rect2(44, 818, 452, 44), "Вернуться к бою", "close_wave_preview", true, false)
		return
	for index in range(int(battle.total_waves)):
		var number: int = index + 1
		var plan: Dictionary = Director.wave_plan(int(battle.stage), number)
		var rect := Rect2(42, 229 + index * 114, 456, 110)
		var current: bool = number == (int(battle.wave) if battle.phase == "running" else int(battle.wave) + 1)
		canvas._box(rect, canvas.LIGHT if current else canvas.PAPER)
		canvas._label(Rect2(rect.position + Vector2(12, 5), Vector2(432, 28)), "%d. %s" % [number, plan.get("title", "Волна")], 19, canvas.GREEN if current else canvas.INK, canvas.bold)
		_draw_counts_row(canvas, battle, plan.get("counts", {}), Rect2(rect.position + Vector2(12, 35), Vector2(432, 23)))
		var advice: String = str(plan.get("advice",plan.get("hint",""))).replace("доходная грядка","доходное растение")
		canvas._label(Rect2(rect.position+Vector2(12,61),Vector2(432,43)),advice,14,canvas.MUTED,null,true)
	canvas._button(Rect2(44, 803, 452, 49), "Вернуться к подготовке" if battle.phase != "running" else "Вернуться к бою", "close_wave_preview", true, false)


static func draw_range(canvas: Node2D) -> void:
	var battle: Object = canvas.battle
	if battle == null or not canvas.battle_panel.is_empty() or canvas.wave_guide_open:
		return
	if battle.phase not in ["preparing", "between"] and not battle.paused:
		return
	var slot: int = int(canvas.active_battle_slot)
	if slot < 0 or slot >= canvas.plot_positions.size():
		return
	var plant: Dictionary = battle.get_plant(slot)
	if plant.is_empty():
		return
	var data: Dictionary = battle.state.plant_data(plant["kind"], plant["level"])
	if data.get("role", "") != "defense":
		return
	var polygon: PackedVector2Array = projected_range_polygon(canvas, slot)
	if polygon.is_empty():
		return
	canvas.draw_colored_polygon(polygon, Color(0.74, 0.89, 0.52, 0.12))
	for arc in projected_range_strokes(canvas,slot):
		canvas.draw_polyline(arc,Color(0.90,0.78,0.39,0.76),1.5,false)
	canvas.draw_circle(canvas.battle_to_screen(canvas.plot_positions[slot]), 3, Color("ffe6a1"))


static func projected_range_strokes(canvas: Node2D, slot: int) -> Array[PackedVector2Array]:
	if canvas.battle == null or slot<0 or slot>=canvas.plot_positions.size(): return []
	var plant: Dictionary = canvas.battle.get_plant(slot)
	if plant.is_empty(): return []
	var data: Dictionary = canvas.state.plant_data(plant["kind"],int(plant["level"]))
	if data.get("role","")!="defense": return []
	var points: PackedVector2Array = Clip.circle_points(canvas.battle_to_screen(canvas.plot_positions[slot]),float(data["range"])*canvas.battle_view_scale())
	return Clip.polyline(points,canvas.BOARD,1.5)


static func projected_range_polygon(canvas: Node2D, slot: int) -> PackedVector2Array:
	var battle: Object = canvas.battle
	if battle == null or battle.get("state") == null or not canvas.BOARD.has_area():
		return PackedVector2Array()
	var positions: Array = battle.get("_plots")
	if slot < 0 or slot >= positions.size(): return PackedVector2Array()
	var plant: Dictionary = battle.get_plant(slot)
	if plant.is_empty(): return PackedVector2Array()
	var data: Dictionary = battle.state.plant_data(plant["kind"],plant["level"])
	if data.get("role","") != "defense": return PackedVector2Array()
	var circle := PackedVector2Array()
	for index in range(97):
		var angle: float = TAU * float(index) / 96.0
		circle.append(canvas.battle_to_screen(positions[slot] + Vector2(cos(angle),sin(angle))*float(data["range"])))
	var board: Rect2 = canvas.BOARD
	var clip := PackedVector2Array([board.position,Vector2(board.end.x,board.position.y),board.end,Vector2(board.position.x,board.end.y)])
	var polygons: Array[PackedVector2Array] = Geometry2D.intersect_polygons(circle,clip)
	return polygons[0] if not polygons.is_empty() else PackedVector2Array()


static func range_polygon(battle: Object, slot: int, board: Rect2) -> PackedVector2Array:
	if battle == null or battle.get("state") == null or not board.has_area():
		return PackedVector2Array()
	var positions: Array = battle.get("_plots")
	if slot < 0 or slot >= positions.size():
		return PackedVector2Array()
	var plant: Dictionary = battle.get_plant(slot)
	if plant.is_empty():
		return PackedVector2Array()
	var data: Dictionary = battle.state.plant_data(plant["kind"], plant["level"])
	if data.get("role", "") != "defense":
		return PackedVector2Array()
	var center: Vector2 = board.position + positions[slot]
	var circle: PackedVector2Array = []
	for index in range(97):
		var angle: float = TAU * float(index) / 96.0
		circle.append(center + Vector2(cos(angle), sin(angle)) * float(data["range"]))
	var clip := PackedVector2Array([board.position, Vector2(board.end.x, board.position.y), board.end, Vector2(board.position.x, board.end.y)])
	var polygons: Array[PackedVector2Array] = Geometry2D.intersect_polygons(circle, clip)
	return polygons[0] if not polygons.is_empty() else PackedVector2Array()


static func outcome_summary(battle: Object) -> Dictionary:
	if battle == null:
		return {"facts": "", "advice": ""}
	var report: Dictionary = battle.get("leak_report") if battle.get("leak_report") is Dictionary else {}
	var leaks: Array[String] = []
	var damage: int = 0
	for kind in report:
		var record: Dictionary = report[kind]
		leaks.append("%s ×%d" % [_short_enemy_name(battle, str(kind)), int(record.get("count", 0))])
		damage += int(record.get("damage", 0))
	if leaks.is_empty():
		return {"facts": "Вредители не прорвались" if battle.phase == "won" else "Бой завершён до удержания всех волн", "advice": "Перекрывайте тропу радиусами пушек и сверяйтесь с планом волн."}
	var hint: String = str(battle.get("last_failure_hint"))
	if hint.is_empty():
		hint = "Проверьте, какие вредители прорываются, и усилите защиту вдоль их пути."
	return {"facts": "Прорывы: %s · ущерб %d" % [", ".join(leaks), damage], "advice": hint}


static func draw_outcome_advice(canvas: Node2D, rect: Rect2) -> void:
	var summary: Dictionary = outcome_summary(canvas.battle)
	canvas._label(Rect2(rect.position, Vector2(rect.size.x, 64)), summary["facts"], 14, canvas.INK, canvas.bold, true)
	canvas._label(Rect2(rect.position + Vector2(0, 69), Vector2(rect.size.x, maxf(43.0, rect.size.y - 69))), summary["advice"], 14, canvas.MUTED, null, true)
