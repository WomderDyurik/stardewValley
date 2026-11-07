extends SceneTree

const State = preload("res://scripts/garden_state.gd")
const Battle = preload("res://scripts/battle_sim.gd")
const Layout = preload("res://scripts/field_layout.gd")

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _create(garden: GardenState, length: float = 1000.0) -> BattleSim:
	var battle: BattleSim = Battle.new()
	var path: Array[Vector2] = [Vector2.ZERO, Vector2(length, 0.0)]
	var plots: Array[Vector2] = []
	for index in range(8):
		plots.append(Vector2(80.0 + float(index) * 120.0, 32.0))
	battle.configure(garden, path, plots)
	return battle


func _select_all(battle: BattleSim) -> bool:
	var kinds: Array[String] = []
	for option in battle.loadout_options():
		kinds.append(String(option["kind"]))
	return battle.select_loadout(kinds)


func _unlock_all(garden: GardenState) -> void:
	while garden.completed_level < 3:
		garden.claim_stage_reward(garden.completed_level + 1)


func _advance_wave(battle: BattleSim) -> void:
	var remaining_steps: int = 12000
	while battle.phase == "running" and remaining_steps > 0:
		battle.tick(0.05)
		remaining_steps -= 1
	_expect(remaining_steps > 0, "wave finishes in finite simulation time")


func _run() -> void:
	_test_preparation_and_paid_copies()
	_test_selection_snapshots()
	_test_paid_replacement()
	_test_pause_and_wave_income()
	_test_defeat_preserves_earnings()
	_test_full_victory()
	_test_first_clear_and_repeat_rewards()
	_test_stage_income_matches_prediction()
	_test_wave_start_clears_pause()
	_test_curved_route_movement()
	_test_actual_starter_battle()
	_test_reward_events()
	_test_separate_wallet_and_random_drops()
	if failures == 0:
		print("Battle tests passed: ", checks, " checks; pre-battle loadout, paid repeated copies, snapshots, paid swaps, first-clear rewards, replay income, five-wave starter victory.")
	else:
		print("Battle tests failed: ", failures)
	quit(0 if failures == 0 else 1)


func _test_preparation_and_paid_copies() -> void:
	var garden: GardenState = State.new()
	var battle: BattleSim = _create(garden)
	_expect(not battle.loadout_ready and battle.available_plants().is_empty(), "deployment list remains hidden until selection is confirmed")
	_expect(battle.loadout_options().size() == 2, "two tomato beds produce one species option plus the grown marigolds")
	_expect(not battle.start_wave() and not battle.plant(0, "tomato"), "neither deployment nor combat bypasses preparation")
	_expect(not battle.select_loadout([]), "empty selection is rejected")
	_expect(not battle.select_loadout(["tomato", "tomato"]), "duplicate species cannot inflate a selection")
	_expect(not battle.select_loadout(["nettle"]), "catalogue or seed ownership alone cannot supply an ungrown defender")
	_expect(garden.plant_plot("nursery", 0, "nettle"), "growing one permanent defender makes it available for preparation")
	var coins_before: int = battle.supplies
	_expect(battle.select_loadout(["tomato"]), "player may bring only some grown species")
	_expect(battle.supplies == coins_before, "pre-battle selection has no deployment charge")
	_expect(battle.select_loadout(["tomato", "nettle"]), "selection can change before the first deployment")
	_expect(battle.available_plants().size() == 2, "confirmed selection supplies distinct repeatable templates")
	var options: Array[Dictionary] = battle.available_plants()
	options[0]["level"] = 20
	_expect(battle.available_plants()[0]["level"] == 1, "selection returned to UI cannot mutate the stored level snapshot")
	_expect(battle.plant(0, "nettle") and battle.plant(1, "nettle"), "one grown defender supplies multiple paid copies")
	_expect(battle.supplies == coins_before - 120, "each defender copy independently costs sixty supplies")
	_expect(battle.available_plants().size() == 2, "deploying copies never exhausts their species")
	var before_invalid: int = battle.supplies
	_expect(not battle.plant(2, "marigold"), "grown but unselected species cannot be installed")
	_expect(not battle.plant(2, "lavender"), "ungrown unselected species is rejected")
	_expect(not battle.plant(-1, "tomato") and not battle.plant(99, "tomato"), "invalid field indices are rejected before charging")
	_expect(not battle.plant(0, "tomato") and not battle.plant(2, "unknown"), "occupied or unknown placements are rejected")
	_expect(battle.supplies == before_invalid, "failed validation never spends coins")
	_expect(not battle.select_loadout(["marigold"]), "composition freezes after the first paid deployment")
	_expect(battle.place_owned(2, "nursery:0"), "source-id compatibility still allows repeated paid copies")
	_expect(battle.supplies == before_invalid - 60, "compatibility wrapper cannot bypass the price")
	battle.supplies = 0
	var placements_before: Array[Dictionary] = battle.plants.duplicate(true)
	_expect(not battle.plant(3, "nettle") and not battle.place_owned(3, "home:0"), "an empty wallet cannot install either kind of copy")
	_expect(battle.plants == placements_before and battle.supplies == 0, "insufficient-funds failures are atomic")
	_expect(not battle.place_owned(3, "nursery:7"), "unknown source cannot bypass the chosen composition")
	_expect(garden.nursery_plots[0] == "nettle", "installing copies never removes their garden source")
	var retry: BattleSim = _create(garden)
	_expect(not retry.loadout_ready and retry.loadout.is_empty(), "a fresh battle requires a new preparation step")
	_expect(_select_all(retry), "preparation itself remains available at zero coins")
	_expect(retry.plant(0, "tomato"), "fresh battle restores supplies even with no garden money")
	_expect(not Battle.new().plant(0, "tomato"), "an unconfigured battle cannot install a plant")
	var full: BattleSim = _create(garden)
	full.supplies = 360
	_expect(full.select_loadout(["tomato"]), "unlimited-copy field setup selects one species")
	for slot in range(8):
		_expect(full.plant(slot, "tomato"), "the same template can fill every free field slot")
	_expect(full.available_plants().size() == 1 and full.plants.size() == 8, "only physical field space limits repeated copies")
	_expect(full.supplies == 0, "every copy on a full field is charged")


func _test_selection_snapshots() -> void:
	var garden: GardenState = State.new()
	garden.coins = 10000
	_expect(garden.plant_plot("nursery", 0, "nettle") and garden.plant_plot("nursery", 1, "nettle"), "snapshot setup grows two copies of a species")
	_expect(garden.upgrade_plot("nursery", 0), "first nursery copy reaches level two")
	_expect(garden.upgrade_plot("nursery", 1) and garden.upgrade_plot("nursery", 1), "second nursery copy reaches level three")
	_expect(garden.upgrade_plot("home", 0), "one tomato source is upgraded independently")
	var battle: BattleSim = _create(garden)
	_expect(battle.select_loadout(["nettle", "tomato"]), "preparation selects upgraded garden species")
	_expect(garden.upgrade_plot("nursery", 1) and garden.upgrade_plot("home", 0), "garden progression can continue after preparation")
	_expect(battle.plant(0, "nettle") and battle.plant(1, "nettle") and battle.plant(2, "tomato"), "prepared templates install repeated upgraded copies")
	_expect(battle.get_plant(0)["level"] == 3 and battle.get_plant(1)["level"] == 3, "copies use the highest grown level recorded when choosing the composition")
	_expect(battle.get_plant(0)["source_id"] == "nursery:1", "template identifies the strongest real source")
	_expect(battle.get_plant(2)["level"] == 2, "income snapshot also freezes at preparation rather than deployment")
	var expected_income: int = battle.plant_income("tomato", 2)
	_expect(battle.wave_income() == expected_income, "wave harvest uses the selected level snapshot")
	var enemy: Dictionary = {"hp": 100.0, "position": Vector2(80, 32), "progress": 1.0, "slow": 0.0, "rewarded": false, "reward": 2}
	battle.enemies.append(enemy)
	battle.get_plant(1)["cooldown"] = 5.0
	battle._fire_plants(0.1)
	var damage: float = float(garden.plant_data("nettle", 3)["damage"])
	_expect(is_equal_approx(float(enemy["hp"]), 100.0 - damage), "firing uses snapshot damage and not later garden levels")
	garden.claim_stage_reward(1)
	_expect(garden.replace_plot("nursery", 1, "lavender"), "the prepared strongest source can later be changed in the garden")
	_expect(battle.plant(3, "nettle") and battle.get_plant(3)["level"] == 3, "confirmed composition remains a coherent snapshot after a source changes")
	var next_battle: BattleSim = _create(garden)
	_expect(_select_all(next_battle), "next preparation reads the current garden")
	_expect(next_battle.plant(0, "nettle") and next_battle.get_plant(0)["level"] == 2, "next battle chooses the remaining best nettle instead of a stale removed source")
	_expect(next_battle.plant(1, "lavender") and next_battle.get_plant(1)["level"] == 1, "newly grown species appears in the next prepared composition")


func _test_paid_replacement() -> void:
	var garden: GardenState = State.new()
	garden.coins = 1000
	garden.claim_stage_reward(1)
	_expect(garden.plant_plot("nursery", 0, "nettle") and garden.plant_plot("nursery", 1, "lavender"), "swap setup grows both chosen species")
	var battle: BattleSim = _create(garden)
	_expect(battle.select_loadout(["nettle", "lavender", "tomato"]), "swap setup prepares a composition")
	_expect(battle.plant(0, "nettle") and battle.plant(1, "tomato"), "swap setup pays for occupied slots")
	battle.get_plant(0)["cooldown"] = 2.0
	var before: Array[Dictionary] = battle.plants.duplicate(true)
	var coins_before: int = battle.supplies
	_expect(not battle.replace_plant(0, "nettle"), "same-species replacement cannot reset attack timing")
	_expect(not battle.replace_plant(7, "lavender") and not battle.replace_plant(0, "marigold"), "replacement needs an occupied slot and a selected species")
	_expect(battle.plants == before and battle.supplies == coins_before, "rejected swaps preserve field and wallet")
	battle.supplies = 54
	_expect(not battle.replace_owned(0, "nursery:1"), "compatibility replacement cannot skip insufficient funds")
	_expect(battle.plants == before and battle.supplies == 54, "failed replacement cannot discard the existing defender")
	battle.supplies = 1000
	_expect(battle.replace_owned(0, "nursery:1"), "a selected replacement can be purchased through its source identity")
	_expect(battle.get_plant(0)["kind"] == "lavender" and battle.supplies == 915, "replacement pays the full new price without refunding the old plant")
	_expect(is_equal_approx(float(battle.get_plant(0)["cooldown"]), 2.0), "swap keeps the longer existing attack cooldown")
	battle.get_plant(0)["cooldown"] = 0.0
	_expect(battle.replace_plant(0, "nettle") and battle.supplies == 855, "switching back is another paid installation")
	_expect(is_equal_approx(float(battle.get_plant(0)["cooldown"]), float(garden.plant_data("nettle", 1)["cooldown"])), "a replacement starts with at least the incoming attack interval")
	for phase in ["running", "between"]:
		battle.phase = phase
		var next_kind: String = "lavender" if battle.get_plant(0)["kind"] == "nettle" else "nettle"
		coins_before = battle.supplies
		_expect(battle.replace_plant(0, next_kind), "replacement remains available in each active phase")
		_expect(battle.supplies == coins_before - int(garden.plant_data(next_kind, 1)["battle_cost"]), "active-phase replacement still charges its installation price")
	battle.phase = "won"
	before = battle.plants.duplicate(true)
	coins_before = battle.supplies
	_expect(not battle.replace_plant(0, "lavender") and battle.plants == before and battle.supplies == coins_before, "terminal battle rejects paid replacements atomically")


func _test_pause_and_wave_income() -> void:
	var garden: GardenState = State.new()
	var battle: BattleSim = _create(garden, 1000000.0)
	_expect(battle.select_loadout(["marigold"]) and battle.plant(0, "marigold"), "pause setup selects and buys one income plant")
	var after_planting: int = battle.supplies
	_expect(battle.start_wave(), "first wave starts after preparation")
	_expect(not battle.start_wave(), "running wave cannot be started twice")
	battle.tick(0.1)
	var before_pause: Array[Dictionary] = battle.enemies.duplicate(true)
	var before_spawn: int = battle.spawned
	battle.paused = true
	battle.tick(60.0)
	_expect(battle.enemies == before_pause and battle.spawned == before_spawn, "pause freezes enemies and spawning")
	battle.paused = false
	for index in range(600):
		battle.tick(0.1)
	_expect(battle.phase == "running" and battle.earned == 0, "holding an unfinished wave never generates rewards")
	_expect(battle.supplies == after_planting, "elapsed time alone never pays battle crops")


func _test_defeat_preserves_earnings() -> void:
	var garden: GardenState = State.new()
	var battle: BattleSim = _create(garden)
	battle.select_loadout(["tomato"])
	battle.plant(0, "tomato")
	var after_planting: int = battle.supplies
	var payouts: Array[int] = []
	battle.wave_finished.connect(func(income: int) -> void: payouts.append(income))
	# Isolate payout transitions from the changed length of the first queue.
	# The ordinary ten-health income-only loss is covered by the balance test.
	battle.base_hp = int(battle.preview_wave()["total"]) + 2
	battle.start_wave()
	_advance_wave(battle)
	_expect(battle.phase == "between" and battle.base_hp == 2, "a completed leaking-wave fixture reaches its single harvest before a later defeat")
	_expect(payouts == [28] and battle.supplies == after_planting + 28, "completed wave pays the crop exactly once")
	battle.tick(10.0)
	_expect(payouts.size() == 1, "between-wave waiting cannot duplicate harvest")
	battle.start_wave()
	_advance_wave(battle)
	_expect(battle.phase == "lost" and battle.base_hp == 0, "undefended greenhouse loses without negative health")
	_expect(battle.supplies == after_planting + 28 and payouts.size() == 1, "defeat preserves earned money and skips the failed wave's harvest")
	_expect(garden.completed_level == 0 and battle.discovery_reward.is_empty(), "defeat grants no territory or seeds")
	_expect(battle.plants.size() == 1 and garden.home_plots[0] == "tomato", "pests never destroy permanent garden sources")
	_expect(not battle.plant(1, "tomato") and not battle.start_wave(), "defeated battle cannot deploy or resume")
	_expect(not battle.select_loadout(["marigold"]), "terminal phase cannot change its composition")


func _test_full_victory() -> void:
	var garden: GardenState = State.new()
	_unlock_all(garden)
	garden.coins = 1000
	for pair in [[0, "nettle"], [1, "lavender"], [8, "pepper"]]:
		_expect(garden.plant_plot("nursery", pair[0], pair[1]), "full victory setup actually grows each required species")
	var battle: BattleSim = _create(garden)
	battle.supplies = 1000
	_expect(_select_all(battle), "full victory setup confirms its grown species")
	var before_deployment: int = battle.supplies
	var kinds: Array[String] = ["nettle", "nettle", "pepper", "lavender", "nettle", "pepper", "tomato", "marigold"]
	var spent: int = 0
	for index in range(kinds.size()):
		spent += int(garden.plant_data(kinds[index], 1)["battle_cost"])
		_expect(battle.plant(index, kinds[index]), "mixed roster installs another paid copy")
	var after_planting: int = battle.supplies
	_expect(before_deployment - after_planting == spent, "wallet records the sum of every installation price")
	var payouts: Array[int] = []
	var results: Array[bool] = []
	battle.wave_finished.connect(func(income: int) -> void: payouts.append(income))
	battle.battle_finished.connect(func(won: bool) -> void: results.append(won))
	for index in range(5):
		_expect(battle.start_wave(), "each next victory wave starts")
		_advance_wave(battle)
	_expect(battle.phase == "won" and battle.wave == 5 and battle.base_hp > 0, "mixed defense completes all five waves")
	_expect(payouts == [53, 58, 63, 68, 73] and results == [true], "income plants pay once per completed wave and victory emits once")
	_expect(garden.coins - 835 == battle.earned, "earned total matches kill, crop and victory payouts")
	_expect(garden.completed_level == 3 and battle.discovery_reward.is_empty(), "replaying an older stage does not create first-clear rewards")
	var after_victory: int = battle.supplies
	battle.tick(1000.0)
	battle._finish_battle(true)
	_expect(battle.supplies == after_victory and results.size() == 1, "finished battle cannot repeatedly award money")


func _test_first_clear_and_repeat_rewards() -> void:
	var garden: GardenState = State.new()
	var first: BattleSim = _create(garden)
	first._finish_battle(true)
	_expect(garden.completed_level == 1 and not first.discovery_reward.is_empty(), "first stage victory records a permanent discovery")
	_expect(garden.is_seed_unlocked("lavender") and garden.home_plot_capacity() == 16, "first victory opens real lavender seeds and four home plots")
	_expect(first.discovery_reward.get("seeds", []) == State.CampaignData.STAGES[0]["seeds"], "result reports the exact first-clear seed reward")
	var coins_before: int = garden.coins
	var replay: BattleSim = _create(garden)
	replay._finish_battle(true)
	_expect(replay.discovery_reward.is_empty() and garden.home_plot_capacity() == 16, "repeat victory does not duplicate land or seeds")
	_expect(garden.coins == coins_before + 35, "repeat victory still grants its ordinary coin bonus")
	var future: BattleSim = _create(State.new())
	future.stage = 3
	future._finish_battle(true)
	_expect(future.discovery_reward.is_empty() and future.state.completed_level == 0, "out-of-order stage cannot bypass campaign reward progression")
	_expect(not Battle.new().start_wave(), "unconfigured battle cannot start combat")


func _test_stage_income_matches_prediction() -> void:
	for stage_number in range(1, 4):
		var garden: GardenState = State.new()
		garden.home_levels[0] = 2
		garden.home_levels[2] = 3
		var battle: BattleSim = _create(garden, 200.0)
		battle.stage = stage_number
		battle.base_hp = int(battle.preview_wave()["total"]) * 3 + 10
		battle.select_loadout(["tomato", "marigold"])
		battle.plant(0, "tomato")
		battle.plant(1, "marigold")
		var expected: int = battle.plant_income("tomato", 2) + battle.plant_income("marigold", 3)
		_expect(battle.wave_income() == expected, "displayed harvest sums the chosen individual levels")
		var wallet_before: int = battle.supplies
		battle.start_wave()
		_advance_wave(battle)
		_expect(battle.supplies - wallet_before == expected + battle.wave_bonus(), "actual stage-scaled harvest matches prediction")


func _test_wave_start_clears_pause() -> void:
	var garden: GardenState = State.new()
	var battle: BattleSim = _create(garden)
	battle.select_loadout(["tomato"])
	battle.paused = true
	battle.base_hp = int(battle.preview_wave()["total"]) + 10
	_expect(battle.start_wave() and not battle.paused, "starting a prepared battle clears inherited pause")
	_expect(not battle.select_loadout(["marigold"]), "composition freezes when combat starts even without paid placements")
	battle.tick(0.1)
	_expect(not battle.enemies.is_empty(), "newly started wave advances immediately")
	_advance_wave(battle)
	_expect(battle.phase == "between", "pause reset setup reaches the next preparation")
	battle.paused = true
	_expect(battle.start_wave() and not battle.paused, "next wave also clears inherited pause")


func _test_actual_starter_battle() -> void:
	var garden: GardenState = State.new()
	_expect(garden.coins == 240, "starter garden begins with the normal budget")
	_expect(garden.plant_plot("nursery", 0, "nettle") and garden.coins == 200, "starter grows one permanent forty-coin defender")
	var battle: BattleSim = Battle.new()
	battle.configure(garden, Layout.battle_route(), Layout.battle_plots())
	_expect(battle.select_loadout(["nettle", "tomato", "marigold"]), "starter selects its three actually grown species")
	_expect(battle.plant(1, "nettle") and battle.plant(5, "nettle") and battle.plant(4, "nettle"), "one grown nettle supplies three paid defending copies")
	_expect(battle.plant(0, "tomato"), "starter balances three defenders with one affordable income planting")
	_expect(garden.coins == 200 and battle.supplies == 15, "battle deployment spends supplies while preserving garden money")
	var harvests: Array[int] = []
	battle.wave_finished.connect(func(income: int) -> void: harvests.append(int(battle.last_wave_reward["harvest"])))
	var simulated_seconds: float = 0.0
	for wave_index in range(5):
		_expect(battle.start_wave(), "real starter setup starts each wave")
		var remaining_steps: int = 12000
		while battle.phase == "running" and remaining_steps > 0:
			battle.tick(0.05)
			if battle.wave >= 2 and battle.get_plant(3).is_empty() and battle.supplies >= 65:
				battle.plant(3,"marigold")
			if battle.supplies >= 60:
				for slot in [9,8,13,12,17,16,2,6,7,10,11,14,15,18]:
					if battle.get_plant(slot).is_empty():
						battle.plant(slot,"nettle")
						break
			simulated_seconds += 0.05
			remaining_steps -= 1
		_expect(remaining_steps > 0, "real-board wave finishes without stalling")
	_expect(battle.phase == "won" and battle.base_hp > 0, "real first stage is winnable from 240 supplies without upgrades or locked seeds")
	_expect(garden.completed_level == 1 and garden.is_seed_unlocked("lavender"), "starter victory opens the next real plant")
	_expect(garden.coins > 200, "starter victory leaves a net profit for long-term garden upgrades")
	var crop_income: int = 0
	for amount in harvests:
		crop_income += amount
	var planting_cost: int = int(garden.plant_data("tomato",1)["battle_cost"]) + int(garden.plant_data("marigold",1)["battle_cost"])
	_expect(battle.get_plant(3).get("kind", "") == "marigold" and crop_income > planting_cost, "early battle crops finance a real reinvestment and repay both supply costs within the fight")
	print("Actual first battle: phase=", battle.phase, "; hp=", battle.base_hp, "; time=", snappedf(simulated_seconds, 0.1), "s; crop supplies=", crop_income, "; crop supply cost=", planting_cost, "; garden wallet=", garden.coins)


func _test_curved_route_movement() -> void:
	var garden: GardenState = State.new()
	var battle: BattleSim = Battle.new()
	battle.configure(garden, Layout.battle_route(), Layout.battle_plots())
	battle.select_loadout(["tomato"])
	_expect(is_equal_approx(battle.path_length, Layout.path_length()), "simulation follows the renderer's actual curved route")
	battle.start_wave()
	for step in range(81):
		battle.tick(0.1)
	_expect(not battle.enemies.is_empty(), "route test has a live pest")
	if battle.enemies.is_empty():
		return
	var position: Vector2 = battle.enemies[0]["position"]
	_expect(position.x > 114.0 and position.x < 127.0 and position.y > 400.0 and position.y < 415.0, "pest physically rounds the sampled bend")


func _test_reward_events() -> void:
	var garden: GardenState = State.new()
	var battle: BattleSim = _create(garden)
	var events: Array[Dictionary] = []
	battle.supplies_rewarded.connect(func(at: Vector2, amount: int, source: String) -> void: events.append({"at": at, "amount": amount, "source": source}))
	battle.select_loadout(["tomato"])
	battle.start_wave()
	var before: int = battle.supplies
	battle._finish_wave()
	_expect(battle.supplies == before + 10 and battle.last_wave_reward["harvest"] == 0, "wave without crops still pays its guaranteed reward")
	_expect(events.size() == 1 and events[0]["source"] == "wave" and events[0]["amount"] == 10, "wave bonus produces its own coin event")
	battle._finish_wave()
	_expect(battle.supplies == before + 10 and events.size() == 1, "duplicate wave completion cannot pay or animate twice")
	battle.plant(0,"tomato")
	battle.plant(1,"tomato")
	battle.start_wave()
	battle._spawn_enemy()
	var enemy: Dictionary = battle.enemies[0]
	enemy["position"] = Vector2(123, 45)
	var kill_before: int = battle.supplies
	battle._hit_enemy(enemy, 9999)
	battle._hit_enemy(enemy, 9999)
	_expect(battle.supplies == kill_before + int(enemy["reward"]), "one killed monster credits its actual reward only once")
	_expect(events.size() == 2 and events[1]["at"] == Vector2(123,45) and events[1]["amount"] == enemy["reward"] and events[1]["source"] == "kill", "kill popup retains monster position and exact credited amount")
	before = battle.supplies
	battle._finish_wave()
	_expect(battle.supplies == before + 51, "second wave pays fifteen bonus plus both eighteen-supply harvests")
	_expect(events.size() == 5 and events[2]["source"] == "harvest" and events[3]["source"] == "harvest", "every income planting produces a separate harvest event")
	_expect(events[2]["at"] == Vector2(80,32) and events[3]["at"] == Vector2(200,32) and events[2]["amount"] == 18 and events[3]["amount"] == 18, "harvest popups belong to the paid plants and match their individual yield")
	battle.start_wave()
	before = battle.supplies
	battle._finish_battle(false)
	battle._finish_wave()
	_expect(battle.supplies == before and events.size() == 5, "a failed wave cannot produce any wave bonus or harvest events")


func _test_separate_wallet_and_random_drops() -> void:
	var garden: GardenState = State.new()
	garden.plant_plot("nursery",0,"nettle")
	garden.coins = 0
	var battle: BattleSim = _create(garden)
	battle.reward_rng.seed = 12345
	_expect(battle.supplies == 240 and battle.select_loadout(["nettle","tomato"]), "empty garden wallet still receives a complete battle budget")
	_expect(battle.plant(0,"nettle") and battle.plant(1,"tomato") and garden.coins == 0 and battle.supplies == 135, "deployment exclusively spends supplies")
	var drops: Array[Dictionary] = []
	battle.coin_rewarded.connect(func(at: Vector2, amount: int, source: String) -> void: drops.append({"at":at,"amount":amount,"source":source}))
	battle.start_wave()
	for index in range(1000):
		var enemy: Dictionary = {"hp":1.0,"rewarded":false,"reward":2,"position":Vector2(index,5)}
		battle._hit_enemy(enemy,2)
		battle._hit_enemy(enemy,2)
	_expect(drops.size() > 150 and drops.size() < 250, "seeded kill drops include both successes and misses around the configured twenty percent chance")
	_expect(garden.coins == drops.size() * 2 and battle.earned == garden.coins and battle.supplies == 2135, "random garden money is additional to guaranteed kill supplies and never duplicates")
	var kill_drops: int = drops.size()
	var before: int = garden.coins
	for index in range(1000):
		battle._roll_garden_coins(Vector2(index,32),2,"harvest")
	var crop_drops: int = drops.size() - kill_drops
	_expect(crop_drops > 150 and crop_drops < 250 and garden.coins - before == crop_drops * 2, "harvest uses the same chance and credits every visible coin drop")
	battle._finish_battle(false)
	var retry: BattleSim = _create(garden)
	_expect(retry.supplies == 240 and retry.earned == 0 and retry.plants.is_empty(), "new attempts reset temporary supplies and keep permanent coin earnings")
	_expect(garden.coins == battle.earned, "loss retains lucky permanent drops")
