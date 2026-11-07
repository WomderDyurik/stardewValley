extends SceneTree

const Battle = preload("res://scripts/battle_sim.gd")
const Director = preload("res://scripts/battle_director.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_classification_and_introduction()
	_air_is_accessible()
	_leaf_cover()
	_soil_disruption()
	_factual_disruption_hint()
	_pause_and_rates()
	print("Pest groups: ", checks, " checks; ", failures, " failures")
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _sandbox(stage: int = 3) -> BattleSim:
	var garden := GardenState.new()
	for cleared in range(1, stage): garden.claim_stage_reward(cleared)
	garden.coins = 10000
	garden.plant_plot("nursery", 0, "nettle")
	if stage >= 2:
		garden.plant_plot("nursery", 1, "lavender")
		garden.plant_plot("pond", 0, "lotus")
	if stage >= 3: garden.plant_plot("nursery", 8, "pepper")
	var battle := Battle.new()
	var path: Array[Vector2] = [Vector2.ZERO, Vector2(10000, 0)]
	var slots: Array[Vector2] = [Vector2(80, 32), Vector2(100, 32), Vector2(80, 0), Vector2(250, 32)]
	battle.configure(garden, path, slots, stage)
	var kinds: Array[String] = ["nettle", "tomato"]
	if stage >= 2: kinds.append_array(["lavender", "lotus"])
	if stage >= 3: kinds.append("pepper")
	battle.select_loadout(kinds)
	battle.supplies = 10000
	battle.reward_rng.seed = 521
	return battle

func _spawn(battle: BattleSim, kind: String, at: Vector2 = Vector2(80, 0)) -> Dictionary:
	battle._spawn_schedule.assign([{"kind":kind, "at":0.0}])
	battle._spawn_cursor = 0
	battle._spawn_left = 1
	battle._spawn_enemy()
	var enemy: Dictionary = battle.enemies[-1]
	enemy["position"] = at
	enemy["progress"] = at.x
	return enemy

func _effects(battle: BattleSim, seconds: float) -> void:
	for step in range(roundi(seconds / Battle.FIXED_STEP)):
		battle._wave_elapsed += Battle.FIXED_STEP
		battle._tick_enemy_effects(Battle.FIXED_STEP)

func _classification_and_introduction() -> void:
	var expected: Dictionary = {
		"sap_suckers":["aphid", "whitefly"], "leaf_chewers":["beetle", "locust", "leafroller"],
		"soil":["burrower", "wireworm"], "molluscs":["snail"], "special":["healer", "soldier", "queen"],
	}
	_check(Director.ENEMY_GROUPS.size() == 5 and Director.ENEMIES.size() == 11, "eleven creatures have five real-life/gameplay groups without duplicating the all-filter")
	var discovered: Dictionary = {}
	var introductions: Dictionary = {"1:1":["beetle"], "1:2":["snail"], "1:3":["aphid"], "2:1":["whitefly"], "2:2":["healer"], "2:3":["wireworm"], "2:4":["locust"], "2:5":["burrower"], "3:1":["leafroller"], "3:2":["soldier"], "3:5":["queen"]}
	for category in expected:
		var group: Dictionary = Director.ENEMY_GROUPS.get(category, {})
		_check(not group.get("name", "").is_empty() and not group.get("description", "").is_empty() and group.get("color") is Color, "each category has visible shared guide metadata")
		for kind in expected[category]:
			var profile: Dictionary = Director.enemy_profile(kind, 3, 5)
			_check(profile["category"] == category and profile["category_name"] == group["name"] and profile["category_color"] == group["color"] and profile["category_description"] == group["description"], "guide and scaled battle profile agree on category for " + kind)
			_check(not profile["real_note"].is_empty() and not profile["battle_role"].is_empty() and profile["nature"] in ["real", "inspired", "fantasy"] and profile["mobility"] in ["ground", "air"], "biology, fictional role and movement are separate for " + kind)
			_check(profile["hp"] > 0 and profile["reward"] > 0 and not profile["counter"].is_empty(), "all creatures have scaled stats and an available soft counter")
	_check(Director.enemy_profile("healer")["nature"] == "fantasy" and Director.enemy_profile("queen")["nature"] == "fantasy" and Director.enemy_profile("soldier")["nature"] == "inspired", "healing and boss powers are never presented as actual pest biology")
	for stage in range(1, 4):
		for wave in range(1, 6):
			var plan: Dictionary = Director.wave_plan(stage, wave)
			_check(plan["counts"].size() <= 6, "each forecast remains readable instead of combining every archetype")
			var new_kinds: Array[String] = []
			for kind in plan["counts"]:
				if not discovered.has(kind): new_kinds.append(kind)
				discovered[kind] = true
				_check(Director.ENEMIES.has(kind), "all authored groups refer to real implemented enemies")
				if stage == 1: _check(kind in ["beetle", "aphid", "snail"], "the opening garden keeps its original learning progression")
			_check(new_kinds == introductions.get("%d:%d" % [stage,wave], []), "each wave teaches at most one new archetype on its scheduled first encounter")
			if stage == 2: _check(not "перц" in String(plan["advice"]).to_lower(), "the second garden never demands a plant unlocked only by winning it")
	_check(discovered.size() == Director.ENEMIES.size(), "every guide creature actually appears in one of the fifteen playable waves")
	_check(Director.wave_plan(2, 1)["counts"].has("whitefly") and Director.wave_plan(2, 3)["counts"].has("wireworm") and Director.wave_plan(3, 1)["counts"].has("leafroller"), "new properties arrive gradually before their combined waves")

func _air_is_accessible() -> void:
	for kind in ["nettle", "lavender", "lotus", "pepper"]:
		var battle: BattleSim = _sandbox()
		battle.plant(0, kind)
		var fly: Dictionary = _spawn(battle, "whitefly", Vector2(80, 32))
		var hp: float = fly["hp"]
		_check(battle._choose_target(Vector2(80, 32), 100, "first") == fly, "air movement follows the common route and permits targeting by " + kind)
		battle._fire_plants(Battle.FIXED_STEP)
		_check(float(fly["hp"]) < hp, "every grown defensive species can actually hit a whitefly: " + kind)
	var battle: BattleSim = _sandbox()
	var fly: Dictionary = _spawn(battle, "whitefly")
	var aphid: Dictionary = _spawn(battle, "aphid")
	battle._apply_slow(fly, 0.55, 2.8)
	battle._apply_slow(aphid, 0.55, 2.8)
	_check(fly["slow_strength"] == 0.275 and aphid["slow_strength"] == 0.55 and fly["slow"] == 2.8, "whitefly halves slow strength, keeps its full duration and has no immunity")
	battle._apply_slow(fly, 0.4, 10)
	_check(fly["slow_strength"] == 0.275 and fly["slow"] == 2.8, "weaker resisted control cannot extend the current stronger effect")
	battle._wave_elapsed = 1
	battle._move_enemies(1)
	_check(is_equal_approx(float(fly["progress"]) - 80, float(fly["speed"]) * 0.725) and fly["position"] == Vector2(fly["progress"], 0), "a flying pest moves along the same route with the advertised reduced slow")

func _leaf_cover() -> void:
	var battle: BattleSim = _sandbox()
	var leaf: Dictionary = _spawn(battle, "leafroller")
	var threshold: float = float(leaf["max_hp"]) * 0.6
	battle._hit_enemy(leaf, float(leaf["hp"]) - threshold - 1)
	_check(not leaf["leaf_shield_used"] and leaf["leaf_shield"] == 0, "leaf cover does not trigger before the stated health threshold")
	battle._hit_enemy(leaf, 1)
	_check(leaf["leaf_shield_used"] and leaf["leaf_shield"] == 3.0 and leaf["shield_flash"] > 0, "crossing sixty percent starts one visible three-second shield")
	_check(battle._choose_target(Vector2(80, 32), 100, "first") == leaf, "leaf cover reduces damage without removing target access")
	var hp: float = leaf["hp"]
	battle._hit_enemy(leaf, 10, "nettle")
	_check(is_equal_approx(float(leaf["hp"]), hp - 5.5), "the subsequent direct hit is reduced by forty-five percent")
	hp = leaf["hp"]
	battle._hit_enemy(leaf, 10, "pepper", true)
	_check(is_equal_approx(float(leaf["hp"]), hp - 10), "area damage bypasses a live leaf shield")
	leaf["hp"] = leaf["max_hp"]
	leaf["armor"] = 99
	hp = leaf["hp"]
	battle._hit_enemy(leaf, 5)
	_check(leaf["hp"] == hp - 1, "armor and leaf cover together still allow at least one damage per positive hit")
	battle._hit_enemy(leaf, 0)
	_check(leaf["hp"] == hp - 1, "the positive-damage floor never turns a zero hit into damage")
	leaf["armor"] = 0
	_effects(battle, 3)
	hp = leaf["hp"]
	battle._hit_enemy(leaf, 10)
	_check(is_equal_approx(float(leaf["hp"]), hp - 10), "direct fire returns to normal exactly when the advertised shield expires")
	battle._hit_enemy(leaf, float(leaf["hp"]) - threshold + 1)
	_check(leaf["leaf_shield"] < 0.000000001 and leaf["leaf_shield_used"], "healing or further wounds do not regenerate the one-time shield")
	var supplies: int = battle.supplies
	battle._hit_enemy(leaf, 99999)
	battle._hit_enemy(leaf, 99999)
	_check(battle.kills == 1 and battle.supplies == supplies + int(leaf["reward"]), "a shielded enemy pays exactly one ordinary kill bounty")
	# Exercise the actual splash cannon, rather than only the helper's flag.
	var pepper: BattleSim = _sandbox()
	pepper.plant(0, "pepper")
	var covered: Dictionary = _spawn(pepper, "leafroller", Vector2(80, 32))
	covered["leaf_shield"] = 3.0
	covered["leaf_shield_used"] = true
	hp = covered["hp"]
	pepper._fire_plants(Battle.FIXED_STEP)
	_check(covered["hp"] == hp - 16, "the production pepper splash passes the shield-bypassing area-damage flag")

func _garden_snapshot(garden: GardenState) -> Dictionary:
	return {"coins":garden.coins, "home":garden.home_plots.duplicate(), "home_levels":garden.home_levels.duplicate(), "nursery":garden.nursery_plots.duplicate(), "nursery_levels":garden.nursery_levels.duplicate(), "pond":garden.pond_plots.duplicate(), "pond_levels":garden.pond_levels.duplicate(), "income":garden.home_income(), "elapsed":garden.home_elapsed, "ready":garden.home_ready}

func _soil_disruption() -> void:
	var battle: BattleSim = _sandbox()
	for pair in [[0,"nettle"], [1,"nettle"], [2,"tomato"], [3,"nettle"]]: battle.plant(pair[0], pair[1])
	var garden_before: Dictionary = _garden_snapshot(battle.state).duplicate(true)
	var harvest: int = battle.wave_income()
	var worm: Dictionary = _spawn(battle, "wireworm")
	_effects(battle, 3.9)
	_check(battle.get_plant(0)["jammed"] == 0 and worm["disruption_pulse"] == 0, "disruption waits four simulation seconds instead of striking on spawn")
	_effects(battle, 0.1)
	_check(battle.get_plant(0)["jammed"] == 1.2 and battle.get_plant(1)["jammed"] == 0 and battle.get_plant(2)["jammed"] == 0 and battle.get_plant(3)["jammed"] == 0, "exactly one nearest defensive placement is delayed; closer income plants and distant defense are untouched")
	_check(worm["disruption_pulse"] > 0 and worm["disruption_target_slot"] == 0 and battle.get_plant(0)["jam_source"] == worm["id"] and battle.battle_stats["enemy_disruptions"] == 1, "the visible source and recipient correspond to an actual single-target pulse")
	battle._disrupt_nearby_plant(worm)
	_check(battle.get_plant(0)["jammed"] == 1.2, "overlapping pulses refresh duration instead of stacking an unbounded lock")
	_check(battle.wave_income() == harvest and _garden_snapshot(battle.state) == garden_before, "a soil pest never destroys persistent plantings, changes levels or reduces a harvest")
	_check(battle.replace_plant(0, "lavender") and battle.get_plant(0)["jammed"] == 1.2, "paying for a different defender cannot erase an active disruption")
	_effects(battle, 1.2)
	_check(battle.get_plant(0)["jammed"] < 0.000000001, "the bounded delay expires on the same fixed simulation clock")
	worm["position"] = Vector2(1000, 0)
	var pulses: int = battle.battle_stats["enemy_disruptions"]
	battle._disrupt_nearby_plant(worm)
	_check(battle.battle_stats["enemy_disruptions"] == pulses, "out-of-range worms do not disable any defender")
	worm["position"] = Vector2(80, 0)
	worm["hp"] = 0
	battle._disrupt_nearby_plant(worm)
	_check(battle.battle_stats["enemy_disruptions"] == pulses, "a killed worm cannot deliver a late pulse")
	# Test actual firing and reload credit with only one defender present.
	var firing: BattleSim = _sandbox()
	firing.plant(0, "nettle")
	var source: Dictionary = _spawn(firing, "wireworm")
	var target: Dictionary = _spawn(firing, "beetle", Vector2(80, 32))
	target["hp"] = 1000
	target["max_hp"] = 1000
	target["progress"] = 100
	firing._disrupt_nearby_plant(source)
	for step in range(71):
		_effects(firing, Battle.FIXED_STEP)
		firing._fire_plants(Battle.FIXED_STEP)
	_check(firing.shots.is_empty() and target["hp"] == 1000 and firing.get_plant(0)["cooldown"] == 0, "a delayed defender neither fires nor accumulates overdue shot credit")
	_effects(firing, Battle.FIXED_STEP)
	firing._fire_plants(Battle.FIXED_STEP)
	_check(firing.shots.size() == 1 and target["hp"] == 991, "expiry permits one ordinary shot, without a stored burst")
	firing._fire_plants(Battle.FIXED_STEP)
	_check(firing.shots.size() == 1 and target["hp"] == 991, "normal reload timing follows the first resumed shot")
	var fresh: BattleSim = _sandbox()
	fresh.configure(firing.state, [Vector2.ZERO,Vector2(1000,0)], [Vector2(80,32)], 3)
	_check(fresh.supplies == 240 and fresh.plants.is_empty(), "a new battle receives the full temporary budget and no inherited disruption")

func _factual_disruption_hint() -> void:
	var battle: BattleSim = _sandbox()
	battle.phase = "running"
	battle.wave = 1
	var worm: Dictionary = _spawn(battle, "wireworm", Vector2(9999, 0))
	battle._wave_elapsed = 1
	battle._move_enemies(1)
	_check(battle.leak_report.get("wireworm", {}).get("damage", 0) == 1 and battle.battle_stats["enemy_disruptions"] == 0, "a worm can leak without ever disrupting an in-range defender")
	var hint: String = battle._diagnose_failure()
	_check("не атакуют" in hint and not "задержали" in hint, "an income-only or empty formation gets factual missing-defense advice without invented disruption")
	battle.plant(0, "nettle")
	hint = battle._diagnose_failure()
	_check(hint == "Прорвались проволочники. Усильте дальний огонь и перекройте выход.", "a zero-disruption worm leak reports the actual breach even when distant defense was purchased")
	battle.battle_stats["enemy_disruptions"] = 1
	_check("задержали" in battle._diagnose_failure(), "disruption-based advice is reserved for battles with a recorded successful pulse")

func _pause_and_rates() -> void:
	var paused: BattleSim = _rate_setup()
	var enemies_before: Array[Dictionary] = paused.enemies.duplicate(true)
	var plants_before: Array[Dictionary] = paused.plants.duplicate(true)
	paused.paused = true
	paused.tick(10)
	_check(paused.enemies == enemies_before and paused.plants == plants_before, "pause freezes flying movement, leaf shields and plant disruption together")
	var baseline: Dictionary = _rate_scenario(60, 1)
	for fps in [15, 30, 60]:
		for acceleration in [1.0, 2.0]:
			_check(_rate_scenario(fps, acceleration) == baseline, "new pest mechanics and economy are identical at %d FPS / x%d" % [fps,int(acceleration)])

func _rate_setup() -> BattleSim:
	var battle: BattleSim = _sandbox()
	battle.plant(0, "nettle")
	battle.get_plant(0)["cooldown"] = 999
	battle.phase = "running"
	battle.wave = 1
	var fly: Dictionary = _spawn(battle, "whitefly")
	battle._apply_slow(fly, 0.55, 2.8)
	var leaf: Dictionary = _spawn(battle, "leafroller")
	battle._hit_enemy(leaf, float(leaf["max_hp"]) * 0.45)
	var worm: Dictionary = _spawn(battle, "wireworm")
	worm["speed"] = 0.0
	return battle

func _rate_scenario(fps: int, acceleration: float) -> Dictionary:
	var battle: BattleSim = _rate_setup()
	battle.speed = acceleration
	for frame in range(roundi(8 * fps / acceleration)): battle.tick(1.0 / fps)
	var enemies: Array[Dictionary] = battle.enemies.duplicate(true)
	for enemy in battle.enemies: battle._hit_enemy(enemy, 99999)
	return {"enemies":enemies, "plants":battle.plants.duplicate(true), "stats":battle.battle_stats.duplicate(true), "supplies":battle.supplies, "coins":battle.state.coins, "kills":battle.kills}
