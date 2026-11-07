extends SceneTree

const Director = preload("res://scripts/battle_director.gd")
const Battle = preload("res://scripts/battle_sim.gd")
const State = preload("res://scripts/garden_state.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_plans_and_real_spawns()
	_soft_counters_and_controls()
	_target_priorities()
	_failure_reports()
	_finite_horizon_economy()
	_fixed_step_speed_and_fps()
	print("Battle design: ", checks, " checks; ", failures, " failures")
	quit(0 if failures == 0 else 1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _create(stage: int = 1) -> BattleSim:
	var garden := State.new()
	var battle := Battle.new()
	var path: Array[Vector2] = [Vector2.ZERO,Vector2(10000,0)]
	var slots: Array[Vector2] = [Vector2(80,32),Vector2(200,32),Vector2(300,32)]
	battle.configure(garden,path,slots,stage)
	return battle

func _plans_and_real_spawns() -> void:
	_expect(Director.wave_plan(0,1).is_empty() and Director.wave_plan(1,6).is_empty(), "invalid forecast requests return no imaginary wave")
	for stage in range(1,4):
		for wave in range(1,6):
			var plan: Dictionary = Director.wave_plan(stage,wave)
			_expect(not plan["title"].is_empty() and not plan["advice"].is_empty(), "each authored wave has a purpose and actionable preparation advice")
			var battle: BattleSim = _create(stage)
			battle.select_loadout(["tomato"])
			battle.wave = wave - 1
			var preview: Dictionary = battle.preview_wave()
			_expect(preview == plan and preview["total"] > 0, "the default preparation preview identifies the actual next authored wave")
			preview["groups"][0]["count"] = 999
			_expect(Director.wave_plan(stage,wave)["groups"][0]["count"] != 999, "the UI cannot mutate the director's source data")
			battle.start_wave()
			var actual: Dictionary = {}
			var guard: int = 0
			while battle.phase == "running" and guard < 10000:
				battle.tick(0.05)
				for enemy in battle.enemies:
					if float(enemy["hp"]) <= 0.0: continue
					var kind: String = enemy["kind"]
					actual[kind] = int(actual.get(kind,0)) + 1
					var profile: Dictionary = Director.enemy_profile(kind,stage,wave,int(enemy.get("assault",1)))
					_expect(enemy["max_hp"] == profile["hp"] and enemy["armor"] == profile["armor"] and enemy["reward"] == profile["reward"], "spawned enemy stats match the same profile as the forecast")
					battle._hit_enemy(enemy,999999)
				guard += 1
			_expect(guard < 10000 and actual == plan["counts"] and battle.spawned == plan["total"], "actual enemy kinds and totals exactly match all fifteen forecasts")
			_expect(battle.kills == plan["total"] and battle.battle_stats["waves_completed"] == wave, "completing a scheduled wave records its real kills and completion")
	var between: BattleSim = _create()
	between.wave = 2
	between.phase = "between"
	_expect(between.enemy_info("snail")["hp"] == Director.enemy_profile("snail",1,3)["hp"], "between-wave enemy details describe the next forecast rather than stale past health")
	var early: Dictionary = Director.wave_plan(1,1)
	_expect(early["counts"].size() == 1 and early["counts"].has("beetle"), "opening wave teaches ordinary defense before special counters")
	_expect(not Director.wave_plan(2,1)["counts"].has("queen") and Director.wave_plan(3,5)["counts"].get("queen",0) == 1, "the unique boss belongs to the final mission wave")
	var timing: BattleSim = _create()
	timing.select_loadout(["tomato"])
	timing.start_wave()
	timing.tick(0.50)
	_expect(timing.spawned == 1, "spawning respects the first group's advertised interval")
	timing.tick(0.44)
	_expect(timing.spawned == 1, "the next enemy never arrives before its scheduled time")
	timing.tick(0.02)
	_expect(timing.spawned == 2 and float(timing.enemies[1]["progress"]) < 1.0, "a just-spawned enemy moves only for its actual alive time")

func _enemy(id: int, at: Vector2, hp: float, progress: float, speed: float = 50.0) -> Dictionary:
	return {"id":id,"kind":"beetle","position":at,"hp":hp,"max_hp":hp,"progress":progress,"speed":speed,"slow":0.0,"slow_strength":0.0,"hit":0.0,"armor":0.0,"reward":2,"rewarded":false}

func _soft_counters_and_controls() -> void:
	var battle: BattleSim = _create()
	var snail: Dictionary = _enemy(1,Vector2(80,32),100,10)
	snail["armor"] = 2.0
	battle._hit_enemy(snail,9,"nettle")
	_expect(snail["hp"] == 93.0 and battle.battle_stats["damage_by_kind"]["nettle"] == 7.0, "armor reduces each hit and damage telemetry records the applied amount")
	snail["armor"] = 99.0
	battle._hit_enemy(snail,5,"lavender")
	_expect(snail["hp"] == 92.0, "armor is a soft counter: every positive hit still inflicts at least one damage")
	battle._hit_enemy(snail,0,"lavender")
	_expect(snail["hp"] == 92.0, "zero damage cannot exploit the minimum damage floor")
	for kind in ["lavender","lotus"]:
		var control: BattleSim = _create()
		control.state.claim_stage_reward(1)
		control.state.coins = 1000
		var area: String = "pond" if kind == "lotus" else "nursery"
		control.state.plant_plot(area,0,kind)
		control.select_loadout([kind])
		control.plant(0,kind)
		var leader: Dictionary = _enemy(1,Vector2(80,32),100,30)
		var neighbour: Dictionary = _enemy(2,Vector2(105,32),100,20)
		var distant: Dictionary = _enemy(3,Vector2(200,32),100,10)
		control.enemies.assign([leader,neighbour,distant])
		control._fire_plants(0.05)
		if kind == "lavender":
			_expect(leader["slow_strength"] == 0.4 and leader["slow"] == 1.8 and neighbour["slow"] == 1.8 and distant["slow"] == 0.0, "lavender controls a close group rather than becoming a second lotus")
		else:
			_expect(leader["slow_strength"] == 0.55 and leader["slow"] == 2.8 and neighbour["slow"] == 0.0 and distant["slow"] == 0.0, "lotus strongly slows one enemy for longer and never copies area control")
	var slowed: Dictionary = _enemy(4,Vector2.ZERO,100,0,100)
	battle.enemies.assign([slowed])
	battle._apply_slow(slowed,0.55,2.8)
	battle._apply_slow(slowed,0.4,10.0)
	_expect(slowed["slow"] == 2.8 and slowed["slow_strength"] == 0.55, "weak control neither multiplies nor extends a stronger slow")
	battle._move_enemies(3.0)
	_expect(is_equal_approx(slowed["progress"],146.0) and slowed["slow"] == 0.0, "slow expiry splits movement time correctly instead of slowing an entire long tick")
	var splash: BattleSim = _create()
	for stage in range(1,3): splash.state.claim_stage_reward(stage)
	splash.state.coins = 1000
	splash.state.plant_plot("nursery",8,"pepper")
	splash.select_loadout(["pepper"])
	splash.plant(0,"pepper")
	var first: Dictionary = _enemy(1,Vector2(80,32),100,30)
	var second: Dictionary = _enemy(2,Vector2(100,32),100,20)
	splash.enemies.assign([first,second])
	splash._fire_plants(0.05)
	_expect(first["hp"] == 84.0 and second["hp"] == 84.0, "pepper's damage genuinely benefits from crowded enemies")

func _target_priorities() -> void:
	var battle: BattleSim = _create()
	battle.state.plant_plot("nursery",0,"nettle")
	battle.select_loadout(["nettle","tomato"])
	battle.plant(0,"nettle")
	battle.plant(1,"tomato")
	var first: Dictionary = _enemy(1,Vector2(90,32),10,30,50)
	var strong: Dictionary = _enemy(2,Vector2(95,32),100,10,40)
	var fast: Dictionary = _enemy(3,Vector2(100,32),20,20,150)
	battle.enemies.assign([first,strong,fast])
	for pair in [["first",1],["strong",2],["fast",3]]:
		_expect(battle.set_target_mode(0,pair[0]), "a defender can adopt each supported free target priority")
		_expect(battle._choose_target(Vector2(80,32),135,pair[0])["id"] == pair[1], "target policies select meaningfully different enemies in the same range")
	_expect(not battle.set_target_mode(1,"first") and not battle.set_target_mode(0,"invalid"), "income plants and invalid priorities do not acquire targeting controls")
	battle.supplies=200
	battle.replace_plant(0,"tomato")
	battle.replace_plant(0,"nettle")
	_expect(battle.get_plant(0)["target_mode"] == "fast", "paid replacement preserves the player's deliberate priority")
	battle._finish_battle(false)
	_expect(not battle.set_target_mode(0,"strong"), "a completed battle cannot mutate target priorities")

func _failure_reports() -> void:
	var battle: BattleSim = _create()
	battle.state.plant_plot("nursery",0,"nettle")
	battle.select_loadout(["nettle"])
	battle.plant(0,"nettle")
	battle.wave=1
	for pair in [["locust",1],["snail",2],["queen",3]]:
		var enemy: Dictionary = _enemy(1,Vector2.ZERO,100,battle.path_length-1,100)
		enemy["kind"] = pair[0]
		enemy["leak_damage"] = pair[1]
		battle.enemies.assign([enemy])
		battle._move_enemies(1.0)
	_expect(battle.base_hp == 4 and battle.battle_stats["base_damage"] == 6, "fast, armored and boss leaks have their advertised consequences")
	_expect(battle.leaked_records.size() == 3 and battle.leak_report["queen"] == {"count":1,"damage":3}, "failure explanation retains actual enemy and damage records")
	battle._finish_battle(false)
	_expect(battle.preview_wave()["wave"] == 1 and battle.enemy_info("snail")["hp"] == Director.enemy_profile("snail",1,1)["hp"], "terminal forecast retains the wave that actually ended the battle")
	_expect("крепкие" in battle.last_failure_hint, "failure advice follows the most damaging recorded threat")
	var idle: BattleSim = _create()
	idle.select_loadout(["tomato"])
	idle.plant(0,"tomato")
	idle._finish_battle(false)
	_expect("не атакуют" in idle.last_failure_hint, "a pure income failure explains the missing defense rather than prescribing grinding")

func _finite_horizon_economy() -> void:
	var battle: BattleSim = _create()
	for kind in PlantCatalog.ORDER:
		var data: Dictionary = battle.state.plant_data(kind,1)
		if data["role"] != "income": continue
		var yield_amount: int = battle.plant_income(kind,1)
		var waves_to_payback: int = ceili(float(data["battle_cost"])/float(yield_amount))
		_expect(waves_to_payback == 3, "every level-one income species has a useful three-harvest payback horizon")
		_expect(yield_amount * 2 < int(data["battle_cost"]), "late income remains a real tradeoff and does not invent extra rewards")
		_expect(yield_amount * 5 > int(data["battle_cost"]), "early investment can fund additional battlefield defense")

func _fixed_step_speed_and_fps() -> void:
	# Same plans, same build decisions and the same reward seed must produce
	# the same outcomes. Rendering FPS and x2 only change real waiting time.
	for stage in [1,2,3]:
		var baseline: Dictionary = _fps_scenario(stage,60,1.0)
		for fps in [15,30,60]:
			for acceleration in [1.0,2.0]:
				var actual: Dictionary = _fps_scenario(stage,fps,acceleration)
				_expect(actual == baseline, "stage %d stays identical at %d FPS / x%d: health, spawns, kills, damage, resources and every payout" % [stage,fps,int(acceleration)])
	var paused: BattleSim = _create()
	paused.select_loadout(["tomato"])
	paused.start_wave()
	paused.tick(Battle.FIXED_STEP / 2.0)
	var residue: float = paused._time_accumulator
	paused.paused = true
	paused.tick(1000.0)
	_expect(paused.spawned == 0 and paused._time_accumulator == residue, "pausing freezes the fractional fixed-step residue instead of stockpiling elapsed time")
	paused.paused = false
	paused.tick(Battle.FIXED_STEP / 2.0)
	_expect(paused.spawned == 1, "resuming executes precisely the accumulated simulation time")
	paused._finish_wave()
	paused.tick(1000.0)
	paused.start_wave()
	paused.tick(Battle.FIXED_STEP / 2.0)
	_expect(paused.spawned == 0, "between-wave time never catches up inside the next wave")
	paused.tick(Battle.FIXED_STEP / 2.0)
	_expect(paused.spawned == 1, "a new wave starts with a clean fractional clock")
	var bounded: BattleSim = _create()
	bounded.select_loadout(["tomato"])
	bounded.start_wave()
	bounded.tick(1000.0)
	_expect(bounded._wave_elapsed <= Battle.MAX_CATCHUP_TIME + 0.00001 and bounded.spawned <= 3, "a long resumed frame has bounded work and cannot replay an entire unattended battle")
	bounded.tick(Battle.FIXED_STEP)
	_expect(bounded._wave_elapsed < Battle.MAX_CATCHUP_TIME + 0.1, "discarded stall time is not replayed on later frames")
	var reentrant: BattleSim = _create()
	reentrant.select_loadout(["tomato"])
	reentrant.start_wave()
	reentrant._spawn_left = 0
	reentrant.wave_finished.connect(func(_amount: int) -> void: reentrant.start_wave(),CONNECT_ONE_SHOT)
	reentrant.tick(1.0)
	_expect(reentrant.wave == 2 and reentrant.phase == "running" and reentrant.spawned == 0, "a completion callback cannot spend one frame's old accumulator inside a newly started wave")
	var penultimate: BattleSim = _create()
	penultimate.select_loadout(["tomato"])
	penultimate.wave = 3
	penultimate.phase = "between"
	penultimate.start_wave()
	penultimate._spawn_left = 0
	penultimate.wave_finished.connect(func(_amount: int) -> void: penultimate.start_wave(), CONNECT_ONE_SHOT)
	penultimate.tick(1.0)
	_expect(penultimate.wave == 5 and penultimate.phase == "running" and penultimate.state.completed_level == 0, "starting the final wave from a completion callback cannot award a premature victory")

	var idle: BattleSim = _create()
	idle.state.plant_plot("nursery",0,"nettle")
	idle.select_loadout(["nettle"])
	idle.plant(0,"nettle")
	for step in range(600): idle._fire_plants(Battle.FIXED_STEP)
	_expect(idle.get_plant(0)["cooldown"] == 0.0, "an idle cannon does not accumulate negative cooldown or future burst credit")
	var target: Dictionary = _enemy(1,Vector2(80,32),1000,0)
	idle.enemies.assign([target])
	idle._fire_plants(Battle.FIXED_STEP)
	_expect(target["hp"] == 991.0 and idle.get_plant(0)["cooldown"] > 0.0, "returning from idle produces one ordinary shot")

func _fps_scenario(stage: int, fps: int, acceleration: float) -> Dictionary:
	var garden := State.new()
	for cleared in range(1,stage): garden.claim_stage_reward(cleared)
	garden.coins = 10000
	garden.plant_plot("nursery",0,"nettle")
	garden.nursery_levels[0] = stage
	var kinds: Array[String] = ["nettle","tomato"]
	if stage >= 2:
		garden.plant_plot("nursery",1,"lavender")
		garden.plant_plot("pond",0,"lotus")
		garden.nursery_levels[1] = stage
		garden.pond_levels[0] = stage
		kinds.append("lavender")
		kinds.append("lotus")
	if stage == 3:
		garden.plant_plot("nursery",8,"pepper")
		garden.nursery_levels[8] = stage
		kinds.append("pepper")
	garden.coins = 0
	var battle := Battle.new()
	battle.configure(garden,FieldLayout.battle_route(),FieldLayout.battle_plots(),stage)
	battle.reward_rng.seed = 123
	battle.speed = acceleration
	battle.select_loadout(kinds)
	if stage == 1:
		for slot in [1,4,5]: battle.plant(slot,"nettle")
	else:
		battle.plant(1,"nettle")
		battle.plant(4,"pepper" if stage == 3 else "lavender")
	battle.plant(0,"tomato")
	var payouts: Array[Dictionary] = []
	var waves: Array[Dictionary] = []
	battle.supplies_rewarded.connect(func(_at: Vector2, amount: int, source: String) -> void: payouts.append({"resource":"supplies","amount":amount,"source":source}))
	battle.coin_rewarded.connect(func(_at: Vector2, amount: int, source: String) -> void: payouts.append({"resource":"coins","amount":amount,"source":source}))
	var total_spawns: int = 0
	for wave_index in range(5):
		if stage >= 2 and wave_index > 0:
			for slot in [5,4,9,8,13,12,17]:
				if not battle.get_plant(slot).is_empty(): continue
				var kind: String = "lavender" if slot == 5 and stage == 3 else "lotus" if slot == 9 else "nettle"
				if battle.plant(slot,kind): break
		if not battle.start_wave(): break
		var guard: int = 0
		while battle.phase == "running" and guard < 100000:
			battle.tick(1.0 / float(fps))
			guard += 1
		_expect(guard < 100000, "a fixed-step invariant scenario finishes in finite time")
		total_spawns += battle.spawned
		waves.append({"hp":battle.base_hp,"kills":battle.kills,"spawned":battle.spawned,"reward":battle.last_wave_reward.duplicate(true)})
	return {"phase":battle.phase,"wave":battle.wave,"hp":battle.base_hp,"kills":battle.kills,"spawned":total_spawns,"supplies":battle.supplies,"earned":battle.earned,"wallet":garden.coins,"damage":battle.battle_stats["damage_by_kind"].duplicate(true),"leaks":battle.leak_report.duplicate(true),"payouts":payouts,"waves":waves}
