extends SceneTree

var failures: int = 0
var checks: int = 0
var scenario_results: Dictionary = {}

func _initialize() -> void:
	# Test decisions, not a mandatory grind threshold: building and composition
	# can outperform a much higher-level formation that never adapts.
	for scenario in [[1,1,"fixed",false],[1,1,"expand",true],[2,1,"fixed",false],[2,1,"expand",true],[2,2,"mixed",true],[3,5,"fixed",false],[3,7,"fixed",true],[3,3,"expand",true],[3,3,"mixed",true]]:
		_run_scenario(scenario[0],scenario[1],scenario[2],scenario[3])
	_check(scenario_results["3:3:mixed"]["hp"] > 0 and scenario_results["3:3:expand"]["hp"] > 0 and scenario_results["3:3:mixed"]["damage"].get("pepper",0.0) > 0.0, "the same garden level and initial budget support both ordinary expanding fire and an actual mixed-control alternative")
	_check(scenario_results["2:2:mixed"]["healing"] > 0.0, "the healer actually restores health during an ordinary playable wave")
	_check(scenario_results["2:1:expand"]["burrows"] > 0, "burrowers actually hide during playable second-stage waves")
	_check(scenario_results["3:3:expand"]["rages"] > 0, "wounded soldiers actually enter their rush during a playable third-stage strategy")
	_check(scenario_results["2:1:expand"]["disruptions"] > 0, "root pests actually delay a battlefield defender during a viable second-stage strategy")
	_check(scenario_results["3:3:expand"]["shields"] > 0, "leafrollers actually form their one-time leaf cover in a viable third-stage strategy")
	for key in ["2:1:expand","3:3:expand","3:3:mixed"]:
		_check(scenario_results[key]["fill_times"].get("can_fill_last",{}).get("wave",0) == 5, "normal strategy cannot finish filling the whole field until the final wave: " + key)
	_economy_policies()
	print("Battle balance: ",checks," checks; ",failures," failures")
	quit(0 if failures == 0 else 1)

func _run_scenario(stage: int, level: int, policy: String, should_win: bool) -> void:
	var garden := GardenState.new()
	for cleared in range(1,stage): garden.claim_stage_reward(cleared)
	garden.coins = 10000
	garden.plant_plot("nursery",0,"nettle")
	garden.nursery_levels[0] = level
	var kinds: Array[String] = ["nettle","tomato"]
	if stage >= 2:
		garden.plant_plot("nursery",1,"lavender")
		garden.plant_plot("pond",0,"lotus")
		garden.nursery_levels[1] = level
		garden.pond_levels[0] = level
		kinds.append("lavender")
		kinds.append("lotus")
	if stage == 3:
		garden.plant_plot("nursery",8,"pepper")
		garden.nursery_levels[8] = level
		kinds.append("pepper")
	garden.coins = 0
	var battle := BattleSim.new()
	battle.configure(garden,FieldLayout.battle_route(),FieldLayout.battle_plots(),stage)
	_check(battle.select_loadout(kinds), "the scenario only brings plants legitimately available before this mission")
	for slot in ([1,4,5,8] if stage == 3 else [1,4,5]): _check(battle.plant(slot,"nettle"), "the known opening threat fits the same 240-supply budget")
	if stage < 3: _check(battle.plant(0,"tomato") and garden.coins == 0, "opening income competes with defense while never spending garden coins")
	var hidden_ids: Dictionary = {}
	var enraged_ids: Dictionary = {}
	var shielded_ids: Dictionary = {}
	var fill_times: Dictionary = {}
	var waves_timing: Array = []
	for wave in range(5):
		if not battle.start_wave(): break
		var steps: int = 0
		while battle.phase == "running" and steps < 10000:
			battle.tick(0.05)
			if policy != "fixed": _reinforce(battle,stage,policy)
			for threshold in [12,16,18,19]:
				if battle.plants.size() >= threshold and not fill_times.has(threshold): fill_times[threshold] = {"seconds":snappedf(battle.active_seconds,0.1),"wave":battle.wave}
			if battle.supplies >= 60 and battle.plants.size() >= 18 and not fill_times.has("can_fill_last"):
				fill_times["can_fill_last"] = {"seconds":snappedf(battle.active_seconds,0.1),"wave":battle.wave}
			for enemy in battle.enemies:
				if enemy.get("burrowed", false): hidden_ids[enemy["id"]] = true
				if enemy.get("enraged", false): enraged_ids[enemy["id"]] = true
				if enemy.get("leaf_shield_used", false): shielded_ids[enemy["id"]] = true
			steps += 1
		waves_timing.append(snappedf(battle.active_seconds,0.1))
		_check(steps < 10000, "an authored wave finishes without stalling")
	_check((battle.phase == "won") == should_win, "stage %d / level %d / %s has the intended decision-sensitive outcome" % [stage,level,policy])
	if should_win:
		_check(battle.wave == 5 and battle.base_hp > 0, "a successful strategy actually finishes all five waves")
	else:
		_check(battle.base_hp == 0 and not battle.last_failure_hint.is_empty(), "a failed strategy produces an explained defeat")
	_check(garden.coins == battle.earned, "winning or losing keeps precisely the permanently earned coins")
	scenario_results["%d:%d:%s" % [stage,level,policy]] = {"hp":battle.base_hp,"healing":float(battle.battle_stats.get("enemy_healing", 0.0)),"burrows":hidden_ids.size(),"rages":enraged_ids.size(),"shields":shielded_ids.size(),"disruptions":int(battle.battle_stats.get("enemy_disruptions",0)),"duration":battle.active_seconds,"damage":battle.battle_stats["damage_by_kind"].duplicate(true),"placements":battle.plants.size(),"fill_times":fill_times,"wave_ends":waves_timing}
	print("Balance: stage=",stage," plant level=",level," policy=",policy," result=",battle.phase," observed=",scenario_results["%d:%d:%s" % [stage,level,policy]])

func _reinforce(battle: BattleSim, stage: int, policy: String) -> void:
	# Five large waves now require decisions between their six approaches.
	# The third garden starts with four guns, then invests in income after the
	# first line can handle the demonstrated leaf cover. Garden coins stay zero.
	if stage == 3 and battle.plants.size() >= 7 and battle.get_plant(0).is_empty():
		if battle.supplies >= 45: battle.plant(0,"tomato")
		return
	for slot in [9,13,12,17,16,2,6,7,10,11,14,15,18,8,4,5]:
		if not battle.get_plant(slot).is_empty(): continue
		var kind: String = "nettle"
		if policy == "mixed":
			if slot == 17: kind = "lavender"
			elif slot == 16 and stage == 3: kind = "pepper"
			elif slot == 2: kind = "lotus"
		var cost: int = int(battle.state.plant_data(kind,1)["battle_cost"])
		if battle.supplies >= cost: battle.plant(slot,kind)
		return


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _economy_policies() -> void:
	var outcomes: Dictionary = {}
	for policy in ["fire", "balanced", "economy", "greedy"]:
		var garden := GardenState.new()
		garden.plant_plot("nursery", 0, "nettle")
		garden.coins = 0
		var battle := BattleSim.new()
		battle.configure(garden, FieldLayout.battle_route(), FieldLayout.battle_plots(), 1)
		battle.select_loadout(["nettle", "tomato"])
		var cannons: int = 4 if policy == "fire" else 3 if policy == "balanced" else 2 if policy == "economy" else 0
		for index in range(cannons): battle.plant([1, 5, 4, 8][index], "nettle")
		if policy == "balanced": battle.plant(0, "tomato")
		elif policy == "economy":
			battle.plant(0, "tomato")
			battle.plant(3, "tomato")
		elif policy == "greedy":
			for slot in [0, 1, 3, 4, 5]: battle.plant(slot, "tomato")
		for wave in range(5):
			if wave > 0:
				for slot in [4, 9, 8, 13, 12, 17]:
					if not battle.get_plant(slot).is_empty(): continue
					if battle.plant(slot, "nettle"): break
			if not battle.start_wave(): break
			var steps: int = 0
			while battle.phase == "running" and steps < 10000:
				battle.tick(0.05)
				_reinforce(battle,1,"expand")
				steps += 1
			_check(steps < 10000, "economy alternatives must terminate")
		outcomes[policy] = {"won": battle.phase == "won", "hp": battle.base_hp, "supplies": battle.supplies, "earned": battle.supplies_earned, "placements": battle.plants.size()}
	_check(outcomes["fire"]["won"] and outcomes["balanced"]["won"] and outcomes["economy"]["won"], "the same level-one garden and initial budget support multiple viable openings")
	_check(outcomes["economy"]["earned"] > outcomes["balanced"]["earned"] and outcomes["balanced"]["earned"] > outcomes["fire"]["earned"], "early economic risk actually increases guaranteed battle supplies")
	_check(outcomes["economy"]["supplies"] > outcomes["fire"]["supplies"], "early income retains a real supply advantage even after the finite field fills")
	_check(not outcomes["greedy"]["won"], "buying only income leaves a real defensive weakness rather than a free-profit strategy")
	print("Economy alternatives, same level and budget: ", outcomes)
