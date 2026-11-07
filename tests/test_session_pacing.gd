extends SceneTree

const Battle = preload("res://scripts/battle_sim.gd")
const Director = preload("res://scripts/battle_director.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_assault_structure()
	_duration_invariance()
	_checkpoints()
	_reject_malformed()
	print("Session pacing/checkpoints: ",checks," checks; ",failures," failures")
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _garden(stage: int = 1) -> GardenState:
	var garden := GardenState.new()
	for cleared in range(1,stage): garden.claim_stage_reward(cleared)
	garden.coins = 10000
	garden.plant_plot("nursery",0,"nettle")
	return garden

func _battle(garden: GardenState, stage: int = 1) -> BattleSim:
	var battle := Battle.new()
	battle.configure(garden,FieldLayout.battle_route(),FieldLayout.battle_plots(),stage)
	battle.reward_rng.seed = 187
	battle.select_loadout(["nettle","tomato"])
	for slot in [1,4,5]: battle.plant(slot,"nettle")
	battle.plant(0,"tomato")
	return battle

func _assault_structure() -> void:
	_check(Director.WAVE_COUNT == 5, "five harvest decisions remain five rather than thirty duplicated crop payouts")
	for stage in range(1,4):
		var total_spawn_seconds: float = 0.0
		for wave in range(1,6):
			var plan: Dictionary = Director.wave_plan(stage,wave)
			_check(plan["assault_count"] == 6 and plan["assaults"].size() == 6, "every main wave has six visible approaches")
			var previous: float = -1.0
			for approach in plan["assaults"]:
				_check(float(approach["at"]) > previous and not approach["title"].is_empty(), "assault time and title come from actual ordered groups")
				previous = float(approach["at"])
			var declared: Dictionary = {}
			var timing: Array[float] = [0.0,0.0,0.0,0.0,0.0,0.0]
			var sum_seconds: float = 0.0
			for group in plan["groups"]:
				var approach: int = int(group["assault"])
				_check(approach >= 1 and approach <= 6 and group["delay"] <= 4.0, "short tactical breathing windows replace long empty waits")
				_check(group["interval"] >= 0.13 and group["interval"] < 2.0, "a stream is visible and neither instant nor artificially slowed")
				declared[group["kind"]] = int(declared.get(group["kind"],0)) + int(group["count"])
				var duration: float = float(group["delay"]) + float(group["count"]-1)*float(group["interval"])
				timing[approach-1] += duration
				sum_seconds += duration
			_check(declared == plan["counts"] and is_equal_approx(sum_seconds,float(plan["spawn_duration"])), "forecast totals and duration describe the real full schedule")
			_check(timing[0] != timing[2] and timing[1] != timing[4], "approaches vary density rather than literally replaying one queue")
			total_spawn_seconds += sum_seconds
		_check(total_spawn_seconds >= 400.0 and total_spawn_seconds <= 650.0, "one active battle carries seven to eleven minutes of authored activity before planning time")
	_check(Director.wave_plan(3,5)["counts"].get("queen",0) == 1, "the long final battle still has one real boss")
	for kind in Director.ENEMIES:
		var base: Dictionary = Director.enemy_profile(kind,3,5,1)
		var reinforced: Dictionary = Director.enemy_profile(kind,3,5,6)
		_check(base["hp"] == reinforced["hp"] and base["speed"] == reinforced["speed"], "duration never hides a speed reduction or an unadvertised health multiplier")
		_check(reinforced["reward"] == (14 if kind == "queen" else 1) and reinforced["reward_min"] <= reinforced["reward"] and reinforced["reward_max"] >= reinforced["reward"], "extra enemies give guaranteed supplies without multiplying the original high rewards")

func _duration_invariance() -> void:
	for stage in [1,3]:
		var normal: Dictionary = _timed_battle(stage,1.0,1 if stage == 1 else 3)
		var accelerated: Dictionary = _timed_battle(stage,2.0,1 if stage == 1 else 3)
		_check(normal["phase"] == "won" and normal["time"] >= 420.0 and normal["time"] <= 660.0, "a normal paid adaptive battle actually lasts seven to eleven active minutes on x1")
		_check(normal["hp"] == accelerated["hp"] and normal["supplies"] == accelerated["supplies"] and normal["coins"] == accelerated["coins"] and normal["simulation"] == accelerated["simulation"], "x2 keeps the same complete battle and every guaranteed/random payout")
		_check(is_equal_approx(float(normal["time"]),float(accelerated["time"])*2.0), "x2 honestly halves active wall time rather than extending queues again")
	var strong: Dictionary = _timed_battle(1,1.0,20)
	var birth_floor: float = 0.0
	for wave in range(1,6): birth_floor += float(Director.wave_plan(1,wave)["spawn_duration"])
	_check(strong["phase"] == "won" and strong["time"] >= birth_floor and strong["time"] < 660.0, "even a very strong grown defender has a measured finite minimum battle rather than five one-second clears")
	print("Timing fast/level20 first battle: ",strong)

func _timed_battle(stage: int, acceleration: float, level: int) -> Dictionary:
	var garden: GardenState = _garden(stage)
	garden.nursery_levels[0] = level
	var battle := Battle.new()
	battle.configure(garden,FieldLayout.battle_route(),FieldLayout.battle_plots(),stage)
	battle.reward_rng.seed = 187
	battle.select_loadout(["nettle","tomato"])
	battle.speed = acceleration
	for slot in ([1,4,5,8] if stage == 3 else [1,4,5]): battle.plant(slot,"nettle")
	if stage < 3: battle.plant(0,"tomato")
	var real_seconds: float = 0.0
	for wave in range(5):
		if not battle.start_wave(): break
		for step in range(20000):
			if battle.phase != "running": break
			battle.tick(0.05 / acceleration)
			real_seconds += 0.05 / acceleration
			if stage == 3 and battle.plants.size() >= 7 and battle.get_plant(0).is_empty():
				if battle.supplies >= 45: battle.plant(0,"tomato")
				continue
			for slot in [9,13,12,17,16,2,6,7,10,11,14,15,18,8,4,5]:
				if not battle.get_plant(slot).is_empty(): continue
				if battle.supplies >= 60: battle.plant(slot,"nettle")
				break
	var result: Dictionary = {"phase":battle.phase,"time":snappedf(real_seconds,0.001),"simulation":battle.active_seconds,"hp":battle.base_hp,"supplies":battle.supplies,"coins":battle.earned}
	print("Timing stage",stage," level",level," x",acceleration,": ",result)
	return result


func _checkpoints() -> void:
	var garden: GardenState = _garden(2)
	var battle: BattleSim = _battle(garden)
	var ready: BattleSim = Battle.new()
	_check(ready.restore_snapshot(garden,FieldLayout.battle_route(),FieldLayout.battle_plots(),battle.export_snapshot()) and ready.phase == "preparing" and ready.paused, "preparation can resume without rerolling the selected loadout")
	battle.start_wave()
	battle.tick(2.0)
	battle.tick(0.025)
	var snapshot: Dictionary = battle.export_snapshot()
	var restored: BattleSim = Battle.new()
	var supply_signals: Array = []
	var coin_signals: Array = []
	restored.supplies_rewarded.connect(func(_at,_amount,_source): supply_signals.append(true))
	restored.coin_rewarded.connect(func(_at,_amount,_source): coin_signals.append(true))
	var wallet: int = garden.coins
	_check(restored.restore_snapshot(garden,FieldLayout.battle_route(),FieldLayout.battle_plots(),snapshot), "a live scheduled wave round-trips with sub-frame residue")
	_check(restored.paused and supply_signals.is_empty() and coin_signals.is_empty() and garden.coins == wallet, "restore itself never advances enemies or emits/duplicates payouts")
	var paused_snapshot: Dictionary = restored.export_snapshot()
	restored.tick(10000.0)
	_check(restored.export_snapshot() == paused_snapshot, "travel interruptions cannot replay offline combat")
	_check(garden.replace_plot("nursery",0,"lavender"), "the garden source is replaced through a legitimate unlocked player action")
	var changed_source: BattleSim = Battle.new()
	_check(changed_source.restore_snapshot(garden,FieldLayout.battle_route(),FieldLayout.battle_plots(),snapshot) and changed_source.loadout == battle.loadout, "replacing a garden source never destroys the already frozen battle template")
	# Each branch receives its own persistent garden, preserving wallet effects.
	var garden_two: GardenState = _garden(2)
	garden_two.coins = garden.coins
	var branch: BattleSim = Battle.new()
	_check(branch.restore_snapshot(garden_two,FieldLayout.battle_route(),FieldLayout.battle_plots(),snapshot), "an identical atomic garden can continue the saved branch")
	branch.paused = false
	battle.paused = false
	for step in range(1200):
		battle.tick(0.05)
		branch.tick(0.05)
		if battle.phase != "running": break
	var first_result: Dictionary = battle.export_snapshot()
	var second_result: Dictionary = branch.export_snapshot()
	_check(first_result == second_result and garden.coins == garden_two.coins, "continued positions, cooldowns, random draws, coins and supplies match an uninterrupted run")
	if battle.phase == "running":
		for step in range(10000):
			battle.tick(0.1)
			for enemy in battle.enemies: battle._hit_enemy(enemy,999999)
			if battle.phase != "running": break
	_check(battle.phase == "between", "the checkpoint fixture reaches a real completed wave")
	var between: BattleSim = Battle.new()
	var before_restore: int = garden.coins
	_check(between.restore_snapshot(garden,FieldLayout.battle_route(),FieldLayout.battle_plots(),battle.export_snapshot()), "between-wave harvest flags and rewards persist")
	between._finish_wave()
	_check(garden.coins == before_restore and between.supplies == battle.supplies and between._rewarded_waves == battle._rewarded_waves, "completed wave payout cannot be re-awarded after restore")
	_ability_checkpoint()

func _ability_checkpoint() -> void:
	var garden: GardenState = _garden(3)
	var route: Array[Vector2] = [Vector2.ZERO,Vector2(4000,0)]
	var plots: Array[Vector2] = [Vector2(200,32),Vector2(260,32),Vector2(320,32)]
	var battle := Battle.new()
	battle.configure(garden,route,plots,3)
	battle.select_loadout(["nettle","tomato"])
	for wave in range(3):
		battle.start_wave()
		for step in range(10000):
			battle.tick(0.25)
			for enemy in battle.enemies: battle._hit_enemy(enemy,999999)
			if battle.phase != "running": break
	battle.plant(0,"nettle")
	battle.plant(1,"tomato")
	battle.start_wave()
	var found: bool = false
	for step in range(2000):
		battle.tick(0.05)
		if float(battle.get_plant(0).get("jammed",0.0)) <= 0.0: continue
		for enemy in battle.enemies:
			if enemy["kind"] != "leafroller" or bool(enemy["leaf_shield_used"]): continue
			battle._hit_enemy(enemy,maxf(1.0,float(enemy["hp"]) - float(enemy["max_hp"])*0.59))
			found = float(enemy["leaf_shield"]) > 0.0
			break
		if found: break
	_check(found, "the checkpoint uses a real authored wave with simultaneous leaf cover and root disruption")
	var payload: Dictionary = battle.export_snapshot()
	var restored := Battle.new()
	_check(restored.restore_snapshot(garden,route,plots,payload), "active shield, jam, enemy IDs and private ability timers round-trip")
	if restored.state == null: return
	var observed: Dictionary = restored.export_snapshot()
	observed["values"]["paused"] = false
	_check(observed == payload, "the only restore change is the explicit safe pause")
	var jam: float = float(restored.get_plant(0)["jammed"])
	restored.tick(100.0)
	_check(float(restored.get_plant(0)["jammed"]) == jam, "paused root disruption does not expire while away")

func _reject_malformed() -> void:
	var garden: GardenState = _garden()
	var live: BattleSim = _battle(garden)
	live.start_wave()
	live.tick(1.0)
	var source: Dictionary = live.export_snapshot()
	var mutations: Array[Dictionary] = []
	for key in ["rules","geometry","version","rng_seed","rng_state"]:
		var broken: Dictionary = source.duplicate(true)
		broken[key] = "invalid"
		mutations.append(broken)
	for mutation in [{"field":"supplies","value":-1},{"field":"active_seconds","value":NAN},{"field":"_spawn_cursor","value":99999},{"field":"phase","value":"unknown"},{"field":"_rewarded_waves","value":{1:true}},{"field":"plants","value":["wrong type"]}]:
		var broken: Dictionary = source.duplicate(true)
		broken["values"][mutation["field"]] = mutation["value"]
		mutations.append(broken)
	var bad_template: Dictionary = source.duplicate(true)
	bad_template["values"]["loadout"][0]["level"] = 99
	mutations.append(bad_template)
	var bad_enemy: Dictionary = source.duplicate(true)
	bad_enemy["values"]["enemies"][0]["kind"] = "imaginary"
	mutations.append(bad_enemy)
	var bad_cooldown: Dictionary = source.duplicate(true)
	bad_cooldown["values"]["plants"][0]["cooldown"] = INF
	mutations.append(bad_cooldown)
	var initial: Dictionary = live.export_snapshot()
	var wallet: int = garden.coins
	for broken in mutations:
		_check(not live.restore_snapshot(garden,FieldLayout.battle_route(),FieldLayout.battle_plots(),broken), "malformed or incompatible checkpoint is rejected")
		_check(live.export_snapshot() == initial and garden.coins == wallet, "rejection never partly changes the live battle or permanent garden")
