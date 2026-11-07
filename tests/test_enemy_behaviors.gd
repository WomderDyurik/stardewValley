extends SceneTree

const Battle = preload("res://scripts/battle_sim.gd")
const Director = preload("res://scripts/battle_director.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_profiles_and_introduction()
	_healer_pulses()
	_burrow_windows()
	_soldier_rush()
	_pause_and_rates()
	print("Enemy behaviors: ", checks, " checks; ", failures, " failures")
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _sandbox(stage: int = 2) -> BattleSim:
	var garden := GardenState.new()
	garden.coins = 1000
	var battle := Battle.new()
	var path: Array[Vector2] = [Vector2.ZERO,Vector2(10000,0)]
	var plots: Array[Vector2] = [Vector2(80,32),Vector2(200,32)]
	battle.configure(garden,path,plots,stage)
	battle.phase = "running"
	battle.wave = 1
	battle.reward_rng.seed = 456
	return battle

func _spawn(battle: BattleSim, kind: String, at: Vector2) -> Dictionary:
	battle._spawn_schedule.assign([{"kind":kind,"at":0.0}])
	battle._spawn_cursor = 0
	battle._spawn_left = 1
	battle._spawn_enemy()
	var enemy: Dictionary = battle.enemies[-1]
	enemy["position"] = at
	enemy["progress"] = at.x
	return enemy

func _effect_seconds(battle: BattleSim, seconds: float) -> void:
	for step in range(roundi(seconds / Battle.FIXED_STEP)):
		battle._wave_elapsed += Battle.FIXED_STEP
		battle._tick_enemy_effects(Battle.FIXED_STEP)

func _profiles_and_introduction() -> void:
	_check(Director.ENEMIES.size() == 11, "eleven pest archetypes preserve the existing support, burrowing and frenzy behaviors")
	for kind in ["healer","burrower","soldier"]:
		var profile: Dictionary = Director.enemy_profile(kind,3,5)
		_check(not profile.is_empty() and not profile["trait"].is_empty() and not profile["counter"].is_empty(), "every new creature advertises a true property and countermeasure")
		_check(profile["hp"] > 0.0 and profile["speed"] > 0.0 and profile["reward"] > 0 and profile["leak_damage"] == 1, "new abilities do not conceal new base-damage rules")
	for wave in range(1,6):
		var counts: Dictionary = Director.wave_plan(1,wave)["counts"]
		for kind in ["healer","burrower","soldier"]:
			_check(not counts.has(kind), "the first garden still teaches the original core threats gradually")
	_check(Director.wave_plan(2,2)["counts"].get("healer",0) > 0 and Director.wave_plan(2,5)["counts"].get("burrower",0) > 0, "support and hiding are introduced in separate second-stage waves")
	_check(Director.wave_plan(3,2)["counts"].get("soldier",0) > 0, "the third garden introduces wounded rushers before its final combination")
	_check(Director.wave_plan(3,5)["counts"].has("healer") and Director.wave_plan(3,5)["counts"].has("queen"), "the final leader has meaningful support rather than only more health")
	_check(Director.enemy_profile("healer",3,5)["heal_amount"] > Director.enemy_profile("healer",2,2)["heal_amount"], "the reference's healing amount follows the same stage-wave scaling as the actual enemy")

func _healer_pulses() -> void:
	var battle: BattleSim = _sandbox()
	var healer: Dictionary = _spawn(battle,"healer",Vector2.ZERO)
	healer["hp"] = 10.0
	var first: Dictionary = _spawn(battle,"beetle",Vector2(10,0))
	first["hp"] = 20.0
	var almost_full: Dictionary = _spawn(battle,"beetle",Vector2(15,0))
	almost_full["hp"] = float(almost_full["max_hp"]) - 2.0
	var critical: Dictionary = _spawn(battle,"beetle",Vector2(20,0))
	critical["hp"] = 2.0
	var second: Dictionary = _spawn(battle,"beetle",Vector2(30,0))
	second["hp"] = 18.0
	var distant: Dictionary = _spawn(battle,"beetle",Vector2(200,0))
	distant["hp"] = 10.0
	var other_healer: Dictionary = _spawn(battle,"healer",Vector2(20,0))
	other_healer["hp"] = 1.0
	other_healer["heal_cooldown"] = 999.0
	var dead: Dictionary = _spawn(battle,"beetle",Vector2(5,0))
	dead["hp"] = 0.0
	_effect_seconds(battle,2.0)
	_check(first["hp"] == 20.0 and healer["heal_pulse"] == 0.0, "healing waits for its actual pulse interval")
	_effect_seconds(battle,0.4)
	var amount: float = float(healer["heal_amount"])
	_check(first["hp"] == 20.0 + amount and critical["hp"] == 2.0 + amount and second["hp"] == 18.0 + amount, "one pulse restores exactly the advertised amount to three most wounded nearby allies")
	_check(almost_full["hp"] == float(almost_full["max_hp"]) - 2.0, "a fourth low-priority ally is not healed by a three-target pulse")
	_check(healer["hp"] == 10.0 and other_healer["hp"] == 1.0, "support cannot heal itself or form healer-healer regeneration loops")
	_check(distant["hp"] == 10.0 and dead["hp"] == 0.0, "healing never crosses its radius or resurrects a killed pest")
	_check(healer["heal_pulse"] > 0.0 and critical["healed"] > 0.0 and battle.battle_stats["enemy_healing"] == 3.0 * amount, "visible pulse and recipient flashes correspond to actual restored health")
	for ally in [first,critical,second]: ally["hp"] = ally["max_hp"]
	battle._heal_neighbours(healer)
	_check(almost_full["hp"] == almost_full["max_hp"] and battle.battle_stats["enemy_healing"] == 3.0 * amount + 2.0, "overhealing is capped and statistics report only restored health")
	var restored_before: float = battle.battle_stats["enemy_healing"]
	healer["hp"] = 0.0
	first["hp"] = 1.0
	battle._heal_neighbours(healer)
	_check(first["hp"] == 1.0 and battle.battle_stats["enemy_healing"] == restored_before, "a dead healer cannot apply a late pulse")

func _burrow_windows() -> void:
	var battle: BattleSim = _sandbox()
	var burrower: Dictionary = _spawn(battle,"burrower",Vector2(80,0))
	_effect_seconds(battle,1.9)
	_check(not burrower["burrowed"] and battle._choose_target(Vector2(80,32),135,"first") == burrower, "a medvedka starts visible and targetable")
	battle._apply_slow(burrower,0.55,2.8)
	_effect_seconds(battle,0.1)
	_check(burrower["burrowed"] and battle._choose_target(Vector2(80,32),135,"first").is_empty(), "the advertised first hiding window removes only direct targeting")
	_check(burrower["slow"] == 2.8 and burrower["phase_flash"] > 0.0, "entering the ground preserves existing slow and emits a visible transition")
	var before: float = burrower["progress"]
	battle._move_enemies(0.5)
	_check(is_equal_approx(float(burrower["progress"]) - before, float(burrower["speed"]) * 0.5 * 0.45) and is_equal_approx(burrower["slow"],2.3), "hidden movement still obeys normal slow rather than becoming a teleport")
	_effect_seconds(battle,1.2)
	_check(not burrower["burrowed"] and not battle._choose_target(burrower["position"],135,"first").is_empty(), "the one-point-two-second hiding window ends and restores direct fire")
	_effect_seconds(battle,3.8)
	_check(burrower["burrowed"], "subsequent hiding windows start on the exact five-second cadence")
	var splash: BattleSim = _sandbox(3)
	splash.state.claim_stage_reward(1)
	splash.state.claim_stage_reward(2)
	splash.state.plant_plot("nursery",8,"pepper")
	splash.phase = "preparing"
	splash.wave = 0
	splash.select_loadout(["pepper"])
	splash.plant(0,"pepper")
	var hidden: Dictionary = _spawn(splash,"burrower",Vector2(80,32))
	hidden["burrowed"] = true
	var visible: Dictionary = _spawn(splash,"beetle",Vector2(90,32))
	var hidden_hp: float = hidden["hp"]
	var visible_hp: float = visible["hp"]
	splash._fire_plants(Battle.FIXED_STEP)
	_check(hidden["hp"] == hidden_hp - 16.0 and visible["hp"] == visible_hp - 16.0, "a pepper explosion aimed at a visible neighbour also damages a hidden medvedka")

func _soldier_rush() -> void:
	var battle: BattleSim = _sandbox(3)
	var soldier: Dictionary = _spawn(battle,"soldier",Vector2(20,0))
	var plain: Dictionary = _spawn(battle,"beetle",Vector2(25,0))
	var speed: float = soldier["speed"]
	_check(battle._choose_target(Vector2.ZERO,135,"fast") == plain, "a full-health soldier is not secretly classified as its future enraged speed")
	var threshold: float = float(soldier["max_hp"]) * float(soldier["frenzy_threshold"])
	battle._hit_enemy(soldier,float(soldier["hp"]) - threshold - 1.0)
	_check(not soldier["enraged"], "the soldier does not rush before the advertised health threshold")
	battle._hit_enemy(soldier,2.0)
	_check(soldier["enraged"] and is_equal_approx(soldier["speed"], speed * 1.55) and soldier["rage_flash"] > 0.0, "crossing forty-five percent starts one visible permanent speed increase")
	_check(battle._choose_target(Vector2.ZERO,135,"fast") == soldier, "fast-target priority responds to the actual enraged speed")
	battle._hit_enemy(soldier,1.0)
	_check(is_equal_approx(soldier["speed"],speed * 1.55), "more hits cannot multiply the rage speed repeatedly")
	soldier["hp"] = soldier["max_hp"]
	battle._tick_enemy_effects(Battle.FIXED_STEP)
	_check(soldier["enraged"] and is_equal_approx(soldier["speed"],speed * 1.55), "healing after the trigger does not silently cancel the announced permanent rush")
	battle._apply_slow(soldier,0.55,2.8)
	battle._wave_elapsed += 0.5
	var before: float = soldier["progress"]
	battle._move_enemies(0.5)
	_check(is_equal_approx(float(soldier["progress"]) - before, speed * 1.55 * 0.45 * 0.5), "existing control remains a soft counter to the rush")
	var supplies_before: int = battle.supplies
	var coins_before: int = battle.state.coins
	battle._hit_enemy(soldier,99999)
	battle._hit_enemy(soldier,99999)
	_check(battle.kills == 1 and battle.supplies == supplies_before + int(soldier["reward"]), "an enraged enemy still pays its ordinary bounty exactly once")
	_check(battle.state.coins >= coins_before and battle.state.coins <= coins_before + int(soldier["reward"]), "the new behavior cannot create extra permanent-coin rolls")

func _pause_and_rates() -> void:
	var paused: BattleSim = _sandbox()
	var healer: Dictionary = _spawn(paused,"healer",Vector2.ZERO)
	var burrower: Dictionary = _spawn(paused,"burrower",Vector2(30,0))
	var soldier: Dictionary = _spawn(paused,"soldier",Vector2(60,0))
	var before: Array[Dictionary] = paused.enemies.duplicate(true)
	paused.paused = true
	paused.tick(10.0)
	_check(paused.enemies == before and healer["heal_cooldown"] == 2.4 and not burrower["burrowed"] and not soldier["enraged"], "pausing freezes healing, hiding, rush and movement together")
	var baseline: Dictionary = _rate_scenario(60,1.0)
	for fps in [15,30,60]:
		for acceleration in [1.0,2.0]:
			_check(_rate_scenario(fps,acceleration) == baseline, "all three new abilities and resulting reward rolls are invariant at %d FPS / x%d" % [fps,int(acceleration)])

func _rate_scenario(fps: int, acceleration: float) -> Dictionary:
	var battle: BattleSim = _sandbox(3)
	battle.speed = acceleration
	battle.reward_rng.seed = 987
	_spawn(battle,"healer",Vector2.ZERO)
	var beetle: Dictionary = _spawn(battle,"beetle",Vector2(30,0))
	beetle["hp"] = 1.0
	_spawn(battle,"burrower",Vector2(45,0))
	var soldier: Dictionary = _spawn(battle,"soldier",Vector2(60,0))
	battle._hit_enemy(soldier,float(soldier["max_hp"]) * 0.60)
	for frame in range(roundi(12.0 * fps / acceleration)):
		battle.tick(1.0 / float(fps))
	var states: Array[Dictionary] = []
	for enemy in battle.enemies:
		states.append({"kind":enemy["kind"],"hp":enemy["hp"],"speed":enemy["speed"],"progress":enemy["progress"],"burrowed":enemy["burrowed"],"enraged":enemy["enraged"],"heal_cooldown":enemy["heal_cooldown"]})
	for enemy in battle.enemies: battle._hit_enemy(enemy,99999)
	return {"states":states,"healing":battle.battle_stats["enemy_healing"],"kills":battle.kills,"supplies":battle.supplies,"coins":battle.state.coins}
