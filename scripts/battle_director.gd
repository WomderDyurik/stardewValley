class_name BattleDirector
extends RefCounted

## Authored, deterministic threats. Only permanent-coin bonus rolls are random.
## Every preview and spawn schedule comes from these same group definitions.
const WAVE_COUNT: int = 5
const ENEMY_GROUPS: Dictionary = {
	"sap_suckers": {"name":"Сосущие", "color":Color("82af76"), "description":"Питаются соком растений. В бою — мелкие группы и порхающие цели."},
	"leaf_chewers": {"name":"Листогрызы", "color":Color("c58c50"), "description":"Объедают листья и побеги. В бою — напор, рывки и листовое укрытие."},
	"soil": {"name":"Почвенные", "color":Color("a58261"), "description":"Связаны с корнями и почвой. В бою — норы и временные помехи пушкам."},
	"molluscs": {"name":"Моллюски", "color":Color("9a98b8"), "description":"Улитки объедают нежные ткани. В бою панцирь снижает каждый удар."},
	"special": {"name":"Особые", "color":Color("c7a25b"), "description":"Игровая поддержка и главари. Их способности — художественная условность."},
}
const ENEMIES: Dictionary = {
	"beetle": {"category": "leaf_chewers", "real_note": "Листоеды и долгоносики повреждают листья.", "nature": "real", "mobility": "ground", "battle_role": "Обычный листогрыз", "name": "Жук", "hp": 30.0, "speed": 48.5, "reward": 2, "armor": 0.0, "leak_damage": 1, "trait": "Обычный вредитель", "counter": "Крапива: быстрый одиночный огонь", "tag": "обычные"},
	"aphid": {"category": "sap_suckers", "real_note": "Высасывает сок из молодых побегов.", "nature": "real", "mobility": "ground", "battle_role": "Плотный слабый рой", "name": "Тля", "hp": 12.0, "speed": 54.0, "reward": 1, "armor": 0.0, "leak_damage": 1, "trait": "Слабая, идёт плотным роем", "counter": "Групповое замедление и урон по площади", "tag": "рой"},
	"snail": {"category": "molluscs", "real_note": "Улитки и слизни объедают нежные ткани.", "nature": "real", "mobility": "ground", "battle_role": "Медленный панцирь", "name": "Панцирная улитка", "hp": 62.0, "speed": 30.0, "reward": 4, "armor": 2.0, "leak_damage": 2, "trait": "Панцирь снижает каждый удар; урон теплице 2", "counter": "Сильный удар и долгое время под огнём", "tag": "броня"},
	"locust": {"category": "leaf_chewers", "real_note": "Объедает листья и молодые побеги.", "nature": "real", "mobility": "ground", "battle_role": "Быстрый листогрыз", "name": "Саранча", "hp": 24.0, "speed": 76.0, "reward": 3, "armor": 0.0, "leak_damage": 1, "trait": "Быстро проходит зону обстрела", "counter": "Замедление и приоритет «Быстрые»", "tag": "скорость"},
	"healer": {"category": "special", "real_note": "Жук-лекарь — вымышленная поддержка.", "nature": "fantasy", "mobility": "ground", "battle_role": "Восстановление раненых", "name": "Жук-лекарь", "hp": 40.0, "speed": 42.0, "reward": 5, "armor": 0.0, "leak_damage": 1, "heal_interval": 2.4, "heal_radius": 72.0, "heal_amount": 6.0, "heal_targets": 3, "trait": "Лечит до трёх раненых соседей; лекарей не лечит", "counter": "Сосредоточьте огонь на поддержке или накройте группу", "tag": "поддержка"},
	"burrower": {"category": "soil", "real_note": "Живёт в почве, повреждает корни и стебли.", "nature": "real", "mobility": "ground", "battle_role": "Короткое скрытие под землёй", "name": "Медведка", "hp": 38.0, "speed": 43.0, "reward": 4, "armor": 0.0, "leak_damage": 1, "burrow_cycle": 5.0, "burrow_duration": 1.2, "burrow_first": 2.0, "trait": "Ненадолго скрывается от прямого прицела", "counter": "Перехват после выхода; взрыв достаёт и под землёй", "tag": "укрытие"},
	"soldier": {"category": "special", "real_note": "Некоторые муравьи охраняют колонии тли.", "nature": "inspired", "mobility": "ground", "battle_role": "Ускорение после ранения", "name": "Муравей-солдат", "hp": 44.0, "speed": 43.0, "reward": 3, "armor": 0.0, "leak_damage": 1, "frenzy_threshold": 0.45, "frenzy_multiplier": 1.55, "trait": "При 45% здоровья один раз ускоряется на 55%", "counter": "Добивайте раненых; замедление сдерживает рывок", "tag": "рывок"},
	"queen": {"category": "special", "real_note": "Матка-босс — вымышленный противник.", "nature": "fantasy", "mobility": "ground", "battle_role": "Стойкий главарь", "name": "Матка жуков", "hp": 350.0, "speed": 26.0, "reward": 14, "armor": 3.0, "leak_damage": 3, "trait": "Много здоровья; урон теплице 3", "counter": "Длинный обстрел и приоритет «Сильные»", "tag": "главарь"},
	"whitefly": {"name":"Белокрылка", "hp":16.0, "speed":58.0, "reward":2, "armor":0.0, "leak_damage":1, "slow_resistance":0.5, "category":"sap_suckers", "real_note":"Питается соком листьев; нимфы живут с нижней стороны.", "nature":"real", "mobility":"air", "battle_role":"Порхающий рой", "trait":"Летит по тропе; замедление слабее на 50%", "counter":"Любая пушка достаёт; добавьте быстрый огонь", "tag":"порхание"},
	"leafroller": {"name":"Листовёртка", "hp":48.0, "speed":34.0, "reward":5, "armor":0.0, "leak_damage":1, "leaf_shield_threshold":0.6, "leaf_shield_duration":3.0, "leaf_shield_reduction":0.45, "category":"leaf_chewers", "real_note":"Гусеницы сворачивают листья в укрытие.", "nature":"real", "mobility":"ground", "battle_role":"Временный листовой щит", "trait":"При 60% здоровья на 3 с уменьшает прямой урон на 45%", "counter":"Держите под огнём; взрыв обходит листовое укрытие", "tag":"листовой щит"},
	"wireworm": {"name":"Проволочник", "hp":48.0, "speed":37.0, "reward":5, "armor":1.0, "leak_damage":1, "disruption_interval":4.0, "disruption_radius":82.0, "disruption_duration":1.2, "disruption_targets":1, "category":"soil", "real_note":"Личинки щелкунов повреждают корни и семена.", "nature":"real", "mobility":"ground", "battle_role":"Короткая помеха пушке", "trait":"Раз в 4 с мешает одной ближней пушке 1,2 с", "counter":"Дальний огонь и разнесённые защитники", "tag":"помеха"},

}

# [kind, count, interval, pause before this group]. Groups never overlap by chance.
const PLANS: Array[Array] = [
	[
		["Разведчики", "Первые жуки проверяют оборону.", "Начните с пушек; доходная грядка поможет достроиться.", [["beetle",8,0.95,0.0]]],
		["Первый панцирь", "За жуками идут две крепкие улитки.", "Поставьте пушку у участка, который путь проходит дважды.", [["beetle",6,0.90,0.0],["snail",2,1.40,1.5]]],
		["Мелкий рой", "Тля идёт тесной группой, следом жуки.", "Добавьте быстрый огонь; несколько пушек поделят рой.", [["aphid",12,0.30,0.0],["beetle",4,0.85,1.8]]],
		["Тяжёлые гости", "Смешанная группа и четыре панциря.", "Достройте оборону на заработанные припасы.", [["beetle",7,0.80,0.0],["snail",4,1.15,1.2]]],
		["Последний натиск", "Рой, жуки и улитки проверят всю тропу.", "Остался один урожай: сравните его с ценой новой посадки.", [["aphid",10,0.28,0.0],["beetle",7,0.75,0.8],["snail",4,1.05,1.2]]],
	],
	[
		["Сосущий налёт", "Тля и порхающие белокрылки идут к урожаю.", "Белокрылку достаёт любая пушка; не полагайтесь только на замедление.", [["aphid",6,0.25,0.0],["whitefly",5,0.55,0.8],["beetle",4,0.7,0.9]]],
		["Рой под опекой", "Лекарь поддерживает сосущих вредителей.", "Сосредоточьте огонь на поддержке; белокрылка слабее поддаётся контролю.", [["healer",1,1.0,0.0],["aphid",10,0.22,0.35],["whitefly",7,0.40,0.8],["beetle",3,0.65,0.9]]],
		["Корневая помеха", "Проволочники задерживают ближнюю пушку; следом идут знакомые вредители.", "Разнесите защиту: помеха на 1,2 с действует только на одну ближнюю пушку.", [["wireworm",2,1.3,0.0],["beetle",5,0.65,0.8],["snail",2,1.1,1.0],["aphid",5,0.3,0.8]]],
		["Быстрая стая", "Саранча быстро проходит тропу под прикрытием знакомого роя.", "Замедлите саранчу и оставьте огонь у выхода; приоритет «Быстрые» поможет перехватить её.", [["healer",1,1.0,0.0],["whitefly",10,0.25,0.3],["locust",5,0.55,1.0],["beetle",3,0.75,0.9]]],
		["Первый подкоп", "Медведки ненадолго скрываются под землёй среди уже знакомых вредителей.", "Медведка выходит на ту же тропу: оставьте второй рубеж после норы.", [["burrower",3,0.95,0.0],["wireworm",2,1.3,0.8],["beetle",2,0.6,0.5],["whitefly",8,0.35,0.9],["locust",4,0.5,0.8],["snail",3,1.0,1.0]]],
	],
	[
		["Листовой дозор", "Раненые листовёртки один раз сворачивают защитное укрытие.", "Листовой щит временный; взрыв перца обходит его.", [["beetle",6,0.65,0.0],["whitefly",6,0.4,0.8],["leafroller",2,1.1,0.8],["snail",1,1.0,1.0]]],
		["Рывок дозора", "Раненые муравьи-солдаты ускоряются; следом идут листовёртки и рой.", "Добивайте раненых солдат; замедление сдержит их единственный рывок.", [["soldier",3,0.75,0.0],["leafroller",2,0.9,0.8],["healer",1,1.0,0.6],["aphid",11,0.17,0.7],["whitefly",6,0.30,0.8]]],
		["Корни под ударом", "Помехи проволочников сочетаются с норами и рывками.", "Дальняя вторая линия сохранит огонь, когда ближняя пушка задержана.", [["wireworm",3,1.1,0.0],["burrower",3,0.85,0.8],["locust",7,0.4,0.8],["soldier",3,0.65,0.9]]],
		["Три способа вредить", "Листогрызы, корневые и сосущие вредители атакуют вместе.", "Держите поддержку под прицелом; взрыв обходит листовое укрытие.", [["healer",1,1.0,0.0],["snail",3,0.75,0.3],["whitefly",8,0.22,0.8],["leafroller",3,0.9,0.7],["wireworm",2,1.1,0.8],["soldier",3,0.6,0.8]]],
		["Матка и три семейства", "Матка собирает сосущих, листогрызов и корневых вредителей.", "Часть пушек займётся маткой; остальные разберут щиты и помехи.", [["queen",1,0.7,0.0],["healer",1,1.0,0.8],["leafroller",3,0.95,0.5],["wireworm",2,1.2,0.8],["whitefly",10,0.25,0.8],["soldier",5,0.6,0.8]]],
	],
]


# Six readable assaults replace the old single ten-second queue. A whole
# wave still pays one harvest, so a longer battle never multiplies free crops.
const ASSAULT_PATTERNS: Array[Dictionary] = [
	{"title":"Первый подход", "interval":1.0, "weight":0.55, "gap":0.0},
	{"title":"Длинная цепочка", "interval":1.20, "weight":1.0, "gap":3.0},
	{"title":"Плотная группа", "interval":0.64, "weight":1.0, "gap":3.5},
	{"title":"Тяжёлый эшелон", "interval":1.05, "weight":1.0, "gap":2.5},
	{"title":"Быстрый натиск", "interval":0.72, "weight":1.0, "gap":4.0},
	{"title":"Последний натиск", "interval":0.88, "weight":1.15, "gap":3.0},
]
const WAVE_SPAWN_SECONDS: Array[Array] = [[68.0,75.0,82.0,90.0,95.0],[82.0,90.0,98.0,106.0,114.0],[90.0,98.0,106.0,114.0,125.0]]
const RULE_SIGNATURE: String = "garden-assaults-v1"


static func wave_plan(stage: int, wave: int) -> Dictionary:
	if stage < 1 or stage > PLANS.size() or wave < 1 or wave > WAVE_COUNT:
		return {}
	var source: Array = PLANS[stage - 1][wave - 1]
	var groups: Array[Dictionary] = []
	var assaults: Array[Dictionary] = []
	var counts: Dictionary = {}
	var features: Array[String] = []
	var total: int = 0
	var duration: float = 0.0
	var target: float = float(WAVE_SPAWN_SECONDS[stage - 1][wave - 1]) - 16.0
	for assault_index in range(ASSAULT_PATTERNS.size()):
		var pattern: Dictionary = ASSAULT_PATTERNS[assault_index]
		var ordered: Array = []
		for raw in source[3]:
			if raw[0] == "queen" and assault_index < ASSAULT_PATTERNS.size() - 1: continue
			ordered.append(raw.duplicate())
		# The first approach retains the authored introduction. Later approaches
		# change formation, not movement speed or hidden health multipliers.
		if assault_index == 1 and ordered.size() > 1:
			ordered.append(ordered.pop_front())
		elif assault_index == 2:
			ordered.reverse()
		elif assault_index == 3:
			ordered.sort_custom(func(a: Array,b: Array) -> bool: return float(ENEMIES[a[0]]["hp"]) > float(ENEMIES[b[0]]["hp"]))
		elif assault_index == 4:
			ordered.sort_custom(func(a: Array,b: Array) -> bool: return float(ENEMIES[a[0]]["speed"]) > float(ENEMIES[b[0]]["speed"]))
		var base_duration: float = 0.0
		for raw in ordered:
			base_duration += maxf(0, int(raw[1]) - 1) * _assault_interval(str(raw[0]),float(raw[2]),assault_index) + float(raw[3])
		var desired: float = target * float(pattern["weight"]) / 5.7
		var count_scale: float = maxf(1.0 if assault_index == 0 else 0.45, desired / maxf(1.0, base_duration))
		var starts_at: float = duration + float(pattern["gap"])
		var first_group: int = groups.size()
		assaults.append({"index":assault_index + 1,"at":starts_at,"title":pattern["title"]})
		for group_index in range(ordered.size()):
			var raw: Array = ordered[group_index]
			var kind: String = raw[0]
			var count: int = 1 if kind == "queen" else maxi(1, roundi(float(raw[1]) * count_scale))
			if kind in ["healer","snail","leafroller","wireworm","burrower","soldier"]:
				count = mini(count,int(raw[1]))
			var interval: float = _assault_interval(kind,float(raw[2]),assault_index)
			var delay: float = float(pattern["gap"]) if group_index == 0 else float(raw[3])
			groups.append({"kind":kind,"count":count,"interval":interval,"delay":delay,"assault":assault_index + 1})
			counts[kind] = int(counts.get(kind,0)) + count
			total += count
			duration += delay + maxf(0,count - 1) * interval
			if not features.has(ENEMIES[kind]["tag"]): features.append(ENEMIES[kind]["tag"])
		# Extend the readable ordinary stream, never multiply healers or shield
		# units to fill a clock. Their tactical role remains a distinct event.
		var filler: int = first_group
		for index in range(first_group,groups.size()):
			if float(ENEMIES[groups[index]["kind"]]["hp"]) < float(ENEMIES[groups[filler]["kind"]]["hp"]): filler = index
		if groups[filler]["kind"] != "queen":
			var extra: int = maxi(0,ceili((desired - (duration - starts_at)) / float(groups[filler]["interval"])))
			groups[filler]["count"] += extra
			counts[groups[filler]["kind"]] += extra
			total += extra
			duration += extra * float(groups[filler]["interval"])
	return {"stage":stage,"wave":wave,"title":source[0],"brief":source[1],"threat":source[1],"advice":source[2],"hint":source[2],"groups":groups,"assaults":assaults,"assault_count":assaults.size(),"counts":counts,"total":total,"features":features,"reward":10 + (wave - 1) * 5 + (stage - 1) * 5,"spawn_duration":duration,"reward_min":1,"reinforcement_reward":1}


static func _assault_interval(kind: String, original: float, assault_index: int) -> float:
	var interval: float = original * float(ASSAULT_PATTERNS[assault_index]["interval"])
	var floor_seconds: float = [0.13,1.0,0.45,0.95,0.55,0.75][assault_index]
	if kind in ["snail","leafroller","wireworm","burrower"]: floor_seconds = maxf(0.80,floor_seconds)
	return maxf(floor_seconds,interval)


static func enemy_profile(kind: String, stage: int = 1, wave: int = 1, assault: int = 1) -> Dictionary:
	if not ENEMIES.has(kind): return {}
	var result: Dictionary = ENEMIES[kind].duplicate(true)
	var health_scale: float = (1.0 + float(clampi(stage,1,3) - 1) * 0.40) * (1.0 + float(clampi(wave,1,WAVE_COUNT) - 1) * 0.16)
	result["kind"] = kind
	result["reward_max"] = int(result["reward"])
	result["reward_min"] = 1 if kind != "queen" else int(result["reward"])
	if assault > 1 and kind != "queen": result["reward"] = 1
	result["hp"] = roundf(float(result["hp"]) * health_scale)
	if result.has("heal_amount"):
		result["heal_amount"] = roundf(float(result["heal_amount"]) * health_scale)
	result["speed"] = float(result["speed"]) * (1.0 + float(clampi(stage,1,3) - 1) * 0.06)
	var group: Dictionary = ENEMY_GROUPS.get(result.get("category", "special"), {})
	result["category_name"] = group.get("name", "Особые")
	result["category_color"] = group.get("color", Color("c7a25b"))
	result["category_description"] = group.get("description", "")
	result["description"] = result["trait"]
	return result
