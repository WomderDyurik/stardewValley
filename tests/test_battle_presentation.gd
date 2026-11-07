extends SceneTree

const Presentation = preload("res://scripts/battle_presentation.gd")
const Director = preload("res://scripts/battle_director.gd")
const State = preload("res://scripts/garden_state.gd")
const Battle = preload("res://scripts/battle_sim.gd")
const Layout = preload("res://scripts/field_layout.gd")
var checks: int = 0
var failures: int = 0
var game: Node2D

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _battle() -> BattleSim:
	var garden := State.new()
	garden.coins = 10000
	garden.plant_plot("nursery", 0, "nettle")
	var battle := Battle.new()
	battle.configure(garden, Layout.battle_route(), Layout.battle_plots())
	battle.select_loadout(["nettle", "tomato"])
	return battle

func _test_income_projection() -> void:
	var battle := _battle()
	var early: Dictionary = Presentation.income_projection(battle, "tomato", 1)
	_expect(early["cost"] == 45 and early["yield"] == 18 and early["payback_waves"] == 3, "Base tomato shows its real supply cost, actual harvest and three-wave payback")
	_expect(early["remaining_harvests"] == 5 and early["can_payback"] and early["net_supplies"] == 45, "Early economic purchase has five potential successful harvests")
	battle.state.home_levels[0] = 20
	battle.state.coins = 0
	_expect(Presentation.income_projection(battle, "tomato", 1) == early, "Garden upgrades and wallet do not rewrite the chosen individual snapshot's payback")
	battle.wave = 4
	battle.phase = "between"
	var late: Dictionary = Presentation.income_projection(battle, "tomato", 1)
	_expect(late["remaining_harvests"] == 1 and late["net_supplies"] == -27 and not late["can_payback"], "Late economic purchase reports a real supply loss")
	_expect(String(late["summary"]).contains("Не окупится"), "Late purchase warns rather than claiming every economic plant is profitable")
	battle.phase = "running"
	_expect(Presentation.income_projection(battle, "tomato", 1)["remaining_harvests"] == 2, "Current running wave counts if a new crop receives its completion harvest")
	battle.phase = "won"
	_expect(Presentation.income_projection(battle, "tomato", 1)["remaining_harvests"] == 0, "Completed battle promises no more harvests")
	battle.phase = "lost"
	_expect(Presentation.income_projection(battle, "tomato", 1)["remaining_harvests"] == 0, "Failed battle promises no more harvests")
	_expect(not Presentation.income_projection(battle, "nettle", 1)["can_payback"], "Defenders are not presented as income generators")

func _test_roles_and_outcome() -> void:
	_expect(Presentation.role_summary("lavender") != Presentation.role_summary("lotus"), "Group control and single-target control have distinct explanations")
	_expect(Presentation.role_summary("pepper").contains("групп"), "Pepper communicates its area role")
	_expect(not Presentation.enemy_lesson("aphid", Director.enemy_profile("aphid"), 1).contains("лаванд"), "First-stage swarm advice works with the actually available initial defender")
	for stage in range(1, 4):
		var profiles: Array[Dictionary] = Presentation.guide_enemy_profiles(stage)
		var expected: Dictionary = {}
		for wave in range(1,6):
			for kind in Director.wave_plan(stage,wave)["counts"]: expected[kind] = true
		_expect(profiles.size() == expected.size(), "Enemy guide includes exactly the creatures occurring on this stage")
		for profile in profiles:
			for wave in profile["waves"]:
				_expect(Director.wave_plan(stage, wave)["counts"].has(profile["kind"]), "Health reference never uses a wave without that enemy")
			if profile["kind"] == "queen":
				_expect(profile["waves"] == [5] and profile["hp_min"] == Director.enemy_profile("queen",3,5)["hp"] and profile["hp_min"] == profile["hp_max"], "Final boss guide shows its actual final-wave health")
	var battle := _battle()
	battle.plant(1, "nettle")
	for index in range(3): battle._record_leak({"kind":"locust", "position":Vector2.ZERO}, 1)
	battle._record_leak({"kind":"snail", "position":Vector2.ZERO}, 2)
	battle._finish_battle(false)
	var outcome: Dictionary = Presentation.outcome_summary(battle)
	_expect(String(outcome["facts"]).contains("Саранча ×3") and String(outcome["facts"]).contains("Улитка ×1") and String(outcome["facts"]).contains("ущерб 5"), "Outcome reports actual leaked types, counts and applied base damage")
	_expect(String(outcome["advice"]).contains("быстрые") and not String(outcome["advice"]).contains("уровень"), "Failure advice responds to the main escaped threat instead of prescribing only upgrades")

func _test_special_enemy_guide() -> void:
	for stage in range(1,4):
		var all_profiles: Array[Dictionary] = Presentation.guide_enemy_profiles(stage)
		var first: Dictionary = Presentation.guide_enemy_page(stage,-5)
		_expect(first["page"] == 0 and first["total"] == all_profiles.size(), "Reference starts on a valid page and exposes its real total")
		var seen: Dictionary = {}
		for page in range(int(first["pages"])):
			var data: Dictionary = Presentation.guide_enemy_page(stage,page)
			_expect(data["profiles"].size() <= Presentation.ENEMY_PAGE_SIZE, "Reference never paints more cards than its checked page capacity")
			for profile in data["profiles"]:
				_expect(not seen.has(profile["kind"]), "Pagination never duplicates a creature")
				seen[profile["kind"]] = true
		_expect(seen.size() == all_profiles.size(), "All creatures remain reachable through the page controls")
		_expect(Presentation.guide_enemy_page(stage,999)["page"] == int(first["pages"]) - 1, "An out-of-range request cannot create an empty hidden page")
	var healer: Dictionary = Director.enemy_profile("healer",2,2)
	healer["heal_amount"] = 20
	healer["heal_interval"] = 3.7
	healer["heal_radius"] = 95
	healer["heal_targets"] = 2
	var lesson: String = Presentation.enemy_lesson("healer",healer,2)
	_expect(lesson.contains("3.7") and lesson.contains("20") and lesson.contains("95") and lesson.contains("до 2"), "Healer explanation reads effective numbers from its profile")
	_expect(lesson.contains("Себя и лекарей не лечит"), "Healer reference states the important healing exclusions")
	var burrower: Dictionary = Director.enemy_profile("burrower",2,3)
	lesson = Presentation.enemy_lesson("burrower",burrower,2)
	_expect(lesson.contains("%.1f" % burrower["burrow_first"]) and lesson.contains("%.1f" % burrower["burrow_cycle"]) and lesson.contains("%.1f" % burrower["burrow_duration"]), "Burrow explanation uses its actual first timing, cycle and hidden duration")
	_expect(not lesson.contains("Взрыв") and lesson.contains("резерв"), "Second-stage burrow counter does not demand the still-locked pepper")
	_expect(Presentation.enemy_lesson("burrower",burrower,3).contains("Взрыв"), "Third-stage reference explains the available area-damage answer")
	var soldier: Dictionary = Director.enemy_profile("soldier",3,3)
	soldier["frenzy_threshold"] = 0.25
	soldier["frenzy_multiplier"] = 1.8
	lesson = Presentation.enemy_lesson("soldier",soldier,3)
	_expect(lesson.contains("25%") and lesson.contains("80%") and lesson.contains("после лечения"), "Soldier explanation shows the actual trigger and persistent speed increase")
	for profile in Presentation.guide_enemy_profiles(2):
		if profile["kind"] != "healer": continue
		for wave in profile["waves"]:
			var amount: int = int(Director.enemy_profile("healer",2,wave)["heal_amount"])
			_expect(amount >= profile["heal_min"] and amount <= profile["heal_max"], "Healer guide range covers each real appearance rather than only final-wave healing")

func _test_enemy_groups() -> void:
	for stage in range(1, 4):
		var all_profiles: Array[Dictionary] = Presentation.guide_enemy_profiles(stage)
		var grouped: Dictionary = {}
		var filters: Array[Dictionary] = Presentation.guide_enemy_groups(stage)
		_expect(filters.size() == Director.ENEMY_GROUPS.size() + 1 and filters[0]["count"] == all_profiles.size(), "Filters expose all five classifications and the actual regional total")
		for filter in filters:
			var id: String = str(filter["id"])
			var profiles: Array[Dictionary] = Presentation.guide_enemy_profiles(stage, id)
			_expect(filter["count"] == profiles.size(), "Each filter count includes only actual local creatures")
			var pages: Dictionary = Presentation.guide_enemy_page(stage, 999, id)
			_expect(pages["category"] == id and pages["page"] == int(pages["pages"]) - 1, "Filtered pagination clamps independently to its actual capacity")
			for profile in profiles:
				_expect(profile.get("nature", "") in ["real", "inspired", "fantasy"] and not String(profile.get("real_note", "")).is_empty(), "Reference distinguishes the real organism from its game interpretation")
				if id == "all": continue
				_expect(profile["category"] == id and not grouped.has(profile["kind"]), "Enemy groups partition local profiles without duplicates")
				grouped[profile["kind"]] = true
		_expect(grouped.size() == all_profiles.size(), "No regional creature disappears from the classifications")
		_expect(Presentation.guide_enemy_profiles(stage, "invalid") == all_profiles and Presentation.guide_enemy_page(stage, 0, "invalid")["category"] == "all", "An unknown saved filter safely returns to all local enemies")
	var whitefly: Dictionary = Director.enemy_profile("whitefly", 2, 1)
	whitefly["slow_resistance"] = 0.35
	var lesson: String = Presentation.enemy_lesson("whitefly", whitefly, 2)
	_expect(lesson.contains("35%") and lesson.contains("Все пушки"), "Flight explanation preserves all defenders and reads actual slow resistance")
	var leafroller: Dictionary = Director.enemy_profile("leafroller", 3, 1)
	leafroller["leaf_shield_threshold"] = 0.45
	leafroller["leaf_shield_duration"] = 2.5
	leafroller["leaf_shield_reduction"] = 0.3
	lesson = Presentation.enemy_lesson("leafroller", leafroller, 3)
	_expect(lesson.contains("45%") and lesson.contains("2.5") and lesson.contains("30%") and lesson.contains("Взрыв"), "Leaf shelter guide reports actual trigger, duration, reduction and the available area answer")
	var wireworm: Dictionary = Director.enemy_profile("wireworm", 2, 1)
	wireworm["disruption_interval"] = 6.0
	wireworm["disruption_radius"] = 90
	wireworm["disruption_duration"] = 1.5
	lesson = Presentation.enemy_lesson("wireworm", wireworm, 2)
	_expect(lesson.contains("6") and lesson.contains("90") and lesson.contains("1.5") and lesson.contains("одну пушку") and lesson.contains("доходные посадки не страдают"), "Soil larva guide explains a limited temporary disruption with actual profile values")
	_expect(Presentation.enemy_category_caption(Director.enemy_profile("healer", 2, 1)).contains("вымышленные"), "Healer powers are explicitly labelled fictional rather than claimed as plant biology")

func _test_range_clipping() -> void:
	var battle := _battle()
	battle.supplies = 100000
	var board := Rect2(24, 240, 492, 430)
	for slot in range(Layout.battle_plots().size()):
		battle.plant(slot, "nettle")
		var polygon: PackedVector2Array = Presentation.range_polygon(battle, slot, board)
		_expect(not polygon.is_empty(), "A real placed defender has a drawable range")
		for point in polygon:
			_expect(board.grow(0.01).has_point(point), "Every actually rendered range vertex remains inside the battlefield")
	_expect(Presentation.range_polygon(battle, -1, board).is_empty() and Presentation.range_polygon(battle, 999, board).is_empty(), "Invalid selections cannot create a stray range")
	battle.plants.clear()
	battle.plant(0, "tomato")
	_expect(Presentation.range_polygon(battle, 0, board).is_empty(), "Income plants do not display an attack range")

func _settle(label: String) -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	for layout in game.text_layouts:
		_expect(not layout["truncated"], label + ": text remains complete: " + layout["text"])
		for run in layout["runs"]:
			_expect(layout["bounds"].grow(0.1).encloses(run["rect"]), label + ": text stays within its allocation")
	if OS.get_cmdline_user_args().has("--screenshots"):
		root.get_texture().get_image().save_png("res://artifacts/battle-design-" + label + ".png")

func _text(fragment: String) -> bool:
	for layout in game.text_layouts:
		if String(layout["text"]).contains(fragment): return true
	return false

func _has_action(action: String) -> bool:
	for hit in game.hitboxes:
		if hit["action"] == action: return true
	return false

func _test_native_layouts() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.state.plant_plot("nursery", 0, "nettle")
	game._action("battle")
	game._action("stage:1")
	game._action("confirm_loadout")
	game.toast_time = 0
	await _settle("preparation")
	_expect(_has_action("wave_preview") and _has_action("primary"), "Preparation makes the real forecast and wave start available")
	for stage in range(1, 4):
		game.battle.stage = stage
		game.current_stage = stage
		game.battle.phase = "preparing"
		game.battle.wave = 0
		for wave in range(1, 6):
			game.battle.phase = "between" if wave > 1 else "preparing"
			game.battle.wave = wave - 1
			await _settle("footer-stage%d-wave%d" % [stage, wave])
			_expect(_text(str(Director.wave_plan(stage, wave)["title"])), "Footer displays the exact authored next threat")
		game._action("wave_preview")
		await _settle("waves-stage%d" % stage)
		_expect(game.wave_guide_open and _has_action("close_wave_preview"), "Wave plan is a dismissible modal")
		for wave in range(1,6):
			_expect(_text(str(Director.wave_plan(stage,wave)["title"])), "Guide includes every authored wave")
		game._action("battle_guide_tab:enemies")
		var battle_before: BattleSim = game.battle
		var choices_before: Array[String] = game.loadout_choices.duplicate()
		var paused_before: bool = game.battle.paused
		for filter in Presentation.guide_enemy_groups(stage):
			var category: String = str(filter["id"])
			game._action("enemy_group:" + category)
			_expect(game.enemy_guide_page == 0, "Changing an enemy group starts at its first real page")
			var pages: int = int(Presentation.guide_enemy_page(stage, 0, category)["pages"])
			for page in range(pages):
				game.enemy_guide_page = page
				await _settle("enemies-stage%d-%s-page%d" % [stage,category,page+1])
				var reference: Dictionary = Presentation.guide_enemy_page(stage,page,category)
				if reference["total"] > 0:
					_expect(_text("урон теплице") and _text("броня"), "Enemy guide exposes effective armor and leak damage")
				for profile in reference["profiles"]:
					_expect(_text(profile["name"]) and _text(Presentation.enemy_category_caption(profile)), "Every creature has a complete visible name and classification")
				for group in Presentation.guide_enemy_groups(stage):
					_expect(_text("%s · %d" % [group["name"],group["count"]]), "Filter buttons always expose local counts, including empty groups")
				_expect(_has_action("enemy_guide_page:-1") == (page>0) and _has_action("enemy_guide_page:1") == (page<pages-1), "Filtered page controls only offer existing destinations")
			_expect(game.battle.paused == paused_before, "Changing a reference group preserves the player's own pause state")
		_expect(game.battle == battle_before and game.loadout_choices == choices_before, "Browsing the enemy reference never replaces the battle or selected plants")
		game._action("battle_guide_tab:rules")
		await _settle("rules-stage%d" % stage)
		_expect(_text("240 припасов") and _text("10 прочности") and _text("20% шанс"), "Rules explain the win condition, supply budget and independent permanent-coin chance")
		_expect(_text("без возврата") and _text("оставшимися выплатами"), "Rules explain paid copies and the investment horizon")
		game._action("close_wave_preview")
		_expect(not game.wave_guide_open, "Closing guide returns to the existing battle")
	game.battle.phase = "preparing"
	game.battle.wave = 0
	var defender_slot: int = -1
	for x in range(39,454,13):
		if defender_slot >= 0: break
		for y in range(39,392,13):
			var point := Vector2(float(x)+0.375,float(y)+0.125)
			if game.battle.placement_check(point,"nettle").get("valid",false):
				defender_slot = game.battle.plant_at(point,"nettle")
				break
	_expect(defender_slot >= 0,"native range fixture actually purchases a defender on valid free ground")
	game._sync_battle_geometry()
	game.active_battle_slot = defender_slot
	await _settle("range-selected")
	game.battle.battle_stats["defense_spent"] = 60
	for kind in ["beetle","aphid","snail","locust","queen"]:
		var profile: Dictionary = game.battle.enemy_info(kind)
		game.battle._record_leak({"kind":kind,"position":Vector2.ZERO},int(profile["leak_damage"]))
	game.battle._record_leak({"kind":"aphid","position":Vector2.ZERO},1)
	game.battle._record_leak({"kind":"locust","position":Vector2.ZERO},1)
	game.battle.base_hp = 0
	game.battle._finish_battle(false)
	await _settle("loss-all-types")
	_expect(_text("ущерб 10"), "Even a mixed five-type loss shows complete factual damage")
	game.result_open = false
	game.battle.leak_report.clear()
	game.battle.leaked_records.clear()
	var total_damage: int = 0
	for kind in Presentation.ENEMY_GUIDE_ORDER:
		var amount: int = 2 if kind in ["snail","queen"] else 1
		game.battle._record_leak({"kind":kind,"position":Vector2.ZERO},amount)
		total_damage += amount
	game.result_open = true
	await _settle("loss-all-eleven-types")
	_expect(_text("Медведка") and _text("Солдат") and _text("Лекарь") and _text("ущерб %d" % total_damage), "A result with every enemy type preserves each factual count and total damage")
	game.queue_free()

func _run() -> void:
	_test_income_projection()
	_test_roles_and_outcome()
	_test_special_enemy_guide()
	_test_enemy_groups()
	_test_range_clipping()
	if not OS.get_cmdline_user_args().has("--pure-only"):
		await _test_native_layouts()
	print("Battle presentation: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
