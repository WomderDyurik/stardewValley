class_name Campaign
extends RefCounted

## Permanent discoveries are granted only for the first sequential victory.
const Catalog = preload("res://scripts/catalog.gd")
const COUNT: int = 3
const STARTER_SEEDS: Array[String] = ["tomato", "marigold", "nettle", "cucumber"]
const STAGES: Array[Dictionary] = [
	{
		"stage": 1,
		"title": "Луговая тропа",
		"description": "Защитите сад и откройте водные грядки питомника.",
		"district": "garden",
		"district_name": "Огород",
		"seeds": ["lavender", "strawberry", "currant", "waterlily", "lotus"],
		"districts": ["nursery"],
		"pond_plots": 6,
		"home_plots": 0,
		"nursery_plots": 0,
	},
	{
		"stage": 2,
		"title": "Защита питомника",
		"description": "Защитите питомник и откройте новые семена для существующих посадок.",
		"district": "nursery",
		"district_name": "Питомник",
		"seeds": ["pepper", "mint"],
		"districts": ["nursery"],
		"pond_plots": 0,
		"home_plots": 0,
		"nursery_plots": 0,
	},
	{
		"stage": 3,
		"title": "Оборона теплицы",
		"description": "Защитите улучшения теплицы и откройте тыкву для большого огорода.",
		"district": "greenhouse",
		"district_name": "Теплица",
		"seeds": ["pumpkin"],
		"districts": ["greenhouse"],
		"pond_plots": 0,
		"home_plots": 0,
		"nursery_plots": 0,
	},
]


static func stage_info(stage: int) -> Dictionary:
	if stage < 1 or stage > COUNT:
		return {}
	var info: Dictionary = STAGES[stage - 1].duplicate(true)
	info["name"] = info["title"]
	return info


static func seed_unlock_stage(kind: String) -> int:
	if STARTER_SEEDS.has(kind):
		return 0
	for info in STAGES:
		if info["seeds"].has(kind):
			return int(info["stage"])
	return -1


static func district_unlock_stage(id: String) -> int:
	if id in ["garden", "nursery", "greenhouse"]:
		return 0
	if id == "pond":
		return 1
	return -1


static func seed_names(stage: int) -> Array[String]:
	var names: Array[String] = []
	var info: Dictionary = stage_info(stage)
	for kind in info.get("seeds", []):
		names.append(String(Catalog.PLANTS[kind]["name"]))
	return names
