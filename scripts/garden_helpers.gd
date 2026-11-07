class_name GardenHelpers
extends RefCounted

## Three permanent farm-wide conveniences. They improve voluntary tending;
## ordinary crops still grow safely without water, fuel or repair payments.
const MAX_LEVEL: int = 3
const ORDER: Array[String] = ["irrigation", "compost", "harvest_crate"]
const INFO: Dictionary = {
	"irrigation": {
		"name": "Система полива",
		"description": "Насос подаёт воду к посадкам. Все садовые культуры созревают быстрее.",
		"costs": [90, 270, 810],
		"purpose": "Быстрее урожай",
	},
	"compost": {
		"name": "Компостер",
		"description": "Питательная подкормка повышает доход каждого нового садового урожая.",
		"costs": [120, 360, 1080],
		"purpose": "Больше монет",
	},
	"harvest_crate": {
		"name": "Сборочный ящик",
		"description": "Сохраняет несколько созревших урожаев, пока вы заняты другими делами.",
		"costs": [100, 300, 900],
		"purpose": "Реже собирать",
	},
}


static func is_valid(id: String) -> bool:
	return INFO.has(id)


static func upgrade_cost(id: String, level: int) -> int:
	if not is_valid(id) or level < 0 or level >= MAX_LEVEL:
		return 0
	return int(INFO[id]["costs"][level])


static func cycle(level: int) -> float:
	return 30.0 - 3.0 * clampi(level, 0, MAX_LEVEL)


static func yield_multiplier(level: int) -> float:
	return 1.0 + 0.1 * clampi(level, 0, MAX_LEVEL)


static func capacity(level: int) -> int:
	return 1 + clampi(level, 0, MAX_LEVEL)


static func effect_text(id: String, level: int) -> String:
	var safe_level: int = clampi(level, 0, MAX_LEVEL)
	match id:
		"irrigation": return "Урожай каждые %d с" % roundi(cycle(safe_level))
		"compost": return "+%d%% монет с нового урожая" % (safe_level * 10)
		"harvest_crate": return "Запас: до %d %s" % [capacity(safe_level), "урожая" if safe_level == 0 else "урожаев"]
	return ""


static func next_effect_text(id: String, level: int) -> String:
	return effect_text(id, mini(level + 1, MAX_LEVEL)) if is_valid(id) else ""
