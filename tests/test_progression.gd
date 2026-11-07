extends SceneTree

const State = preload("res://scripts/garden_state.gd")
const Catalog = preload("res://scripts/catalog.gd")
const CampaignData = preload("res://scripts/campaign.gd")

var failures: int = 0
var checks: int = 0
var test_directory: String = ""
var test_save: String = ""


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	test_directory = "/private/tmp/planta2-test-progress-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	if DirAccess.make_dir_absolute(test_directory) != OK:
		push_error("Cannot create isolated progression test directory")
		quit(1)
		return
	test_save = test_directory.path_join("save.json")
	_test_wallet_and_harvest()
	_test_plot_planting_and_replacement()
	_test_individual_upgrades()
	_test_owned_roster()
	_test_campaign_discoveries()
	_test_grandfather_discovery_receipt()
	_test_battle_templates()
	_test_persistence()
	_test_legacy_migration()
	_test_legacy_paid_defenders()
	_test_version_two_migration()
	_test_invalid_saves_are_atomic()
	DirAccess.remove_absolute(test_save)
	DirAccess.remove_absolute(test_save + ".tmp")
	DirAccess.remove_absolute(test_directory)
	print("Progression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _test_wallet_and_harvest() -> void:
	var state = State.new()
	_check(not state.spend(241) and state.coins == 240, "Unaffordable purchase preserves wallet")
	_check(not state.spend(-10), "Negative purchase cannot create coins")
	_check(state.spend(240) and state.coins == 0, "Exact balance can be spent")
	state.earn(-10)
	_check(state.coins == 0, "Negative rewards are ignored")
	state.earn(25)
	_check(state.coins == 25, "Rewards use the permanent wallet")
	state.earn(State.MAX_COINS)
	_check(state.coins == State.MAX_COINS, "Coin rewards respect the saveable cap")
	state = State.new()
	_check(state.home_income() == 14, "The three initial real crops produce recovery income")
	_check(state.collect_home() == 0, "Unripe garden cannot be harvested")
	state.tick(State.HOME_CYCLE - 0.1)
	_check(not state.home_ready, "Harvest waits for a complete growth cycle")
	state.tick(0.2)
	_check(state.home_ready, "A complete growth cycle becomes collectible")
	state.tick(State.HOME_CYCLE * 100.0)
	_check(state.home_elapsed == State.HOME_CYCLE, "Uncollected production is capped at one harvest")
	_check(state.collect_home() == 14 and state.coins == 254, "Harvest pays actual planted yield into the same wallet")
	_check(state.collect_home() == 0, "A harvest cannot be collected twice")
	_check(not state.home_ready and state.home_elapsed == 0.0, "Collecting starts another growth cycle")
	for invalid_delta in [-100.0, NAN, INF]:
		state.tick(invalid_delta)
		_check(state.home_elapsed == 0.0, "Invalid deltas cannot change growth")


func _test_plot_planting_and_replacement() -> void:
	var state = State.new()
	_check(state.home_plots.size() == 24 and state.home_levels.size() == 24, "Garden stores twenty-four leveled plots including locked expansion land")
	_check(state.nursery_plots.size() == 12 and state.nursery_levels.size() == 12, "Nursery stores twelve persistent positions including locked expansion land")
	_check(state.nursery_plots.all(func(kind): return kind == ""), "Nursery has no imaginary planted defenders")
	_check(state.home_levels.all(func(level): return level == 1) and state.nursery_levels.all(func(level): return level == 1), "New planting positions begin at level one")
	_check(state.allowed_kinds("home") == ["tomato", "marigold", "pumpkin", "cucumber", "strawberry", "currant", "mint"], "Income crops are available in the harvest garden")
	_check(state.allowed_kinds("nursery") == ["nettle", "lavender", "pepper"], "Protective plants are available in the nursery")
	_check(state.allowed_kinds("unknown").is_empty(), "Unknown planting area does not expose a catalog")
	var choices: Array[String] = state.allowed_kinds("home")
	choices.clear()
	_check(state.allowed_kinds("home").size() == 7, "Catalog choices are returned by value")
	var original: Dictionary = _snapshot(state)
	for command in [
		["home", 0, "tomato"], ["home", 3, "nettle"], ["home", -1, "tomato"],
		["home", 12, "tomato"], ["nursery", 0, "tomato"], ["nursery", 8, "nettle"],
		["nursery", -1, "nettle"], ["unknown", 0, "tomato"], ["home", 3, "unknown"],
	]:
		_check(not state.plant_plot(command[0], command[1], command[2]), "Invalid or occupied planting is rejected")
		_check(_snapshot(state) == original, "Rejected planting preserves every progression field")
	_check(state.plant_home(7, "tomato"), "Last harvest plot accepts a crop")
	_check(state.home_plots[7] == "tomato" and state.home_levels[7] == 1 and state.coins == 210, "Home purchase creates one level-one planting and charges once")
	_check(state.plant_nursery(7, "nettle"), "Last nursery position accepts a defender")
	_check(state.nursery_plots[7] == "nettle" and state.nursery_levels[7] == 1 and state.coins == 170, "Nursery purchase is a real persistent planting")
	_check(not state.replace_plot("home", 3, "marigold"), "Replacement does not act as planting into an empty bed")
	_check(not state.replace_plot("home", 7, "tomato"), "Replacing a plant with itself cannot reset or charge it")
	_check(not state.replace_plot("nursery", 7, "tomato"), "Replacement respects the nursery role")
	_check(state.upgrade_plot("nursery", 7) and state.nursery_levels[7] == 2, "Defender can be upgraded before replacement")
	_check(state.coins == 80, "Individual defender upgrade costs its catalog price")
	state.unlocked_seeds.append("lavender")
	_check(state.replace_plot("nursery", 7, "lavender"), "An occupied nursery position can change its plant")
	_check(state.coins == 25 and state.nursery_plots[7] == "lavender" and state.nursery_levels[7] == 1, "Replacement pays once and gives the new plant level one without refunds")
	var before_failed: Dictionary = _snapshot(state)
	_check(not state.replace_plot("home", 0, "marigold"), "Unaffordable replacement fails")
	_check(_snapshot(state) == before_failed, "Failed replacement preserves the old plant and its level")
	_check(not state.plant_home(3, "tomato") and _snapshot(state) == before_failed, "Unaffordable planting does not partially modify a bed")
	_check(state.plot_kind("unknown", 0) == "" and state.plot_kind("home", -1) == "", "Invalid plot kind lookup is safe")
	_check(state.plot_level("unknown", 0) == 0 and state.plot_level("nursery", State.NURSERY_PLOT_COUNT) == 0, "Invalid plot level lookup is safe")
	_check(state.plot_data("home", 3).is_empty() and state.plot_data("home", 12).is_empty(), "Empty and invalid plot data never invent a plant")


func _test_individual_upgrades() -> void:
	var state = State.new()
	var old_second: Dictionary = state.plot_data("home", 1)
	var changes: Array[int] = [0]
	state.changed.connect(func(): changes[0] += 1)
	_check(state.plot_upgrade_cost("home", 0) == 75, "A level-one tomato has the expected upgrade price")
	_check(state.upgrade_plot("home", 0), "An affordable actual planting can be upgraded")
	_check(changes[0] == 1, "An upgrade emits one completed state change")
	_check(state.coins == 165 and state.plot_level("home", 0) == 2, "Upgrade changes one level and charges the shared wallet")
	_check(state.plot_data("home", 0)["home_yield"] == 5 and state.plot_data("home", 0)["battle_yield"] == 22, "Individual crop upgrade improves both home and battle yield")
	_check(state.plot_data("home", 1) == old_second, "A second crop of the same species is unchanged")
	_check(state.levels["tomato"] == 1 and state.home_income() == 15, "The upgrade is per planting, with no global yield multiplication")
	_check(state.plot_upgrade_cost("home", 0) == roundi(75.0 * 1.55), "Upgrade price grows with the selected planting level")
	_check(state.plant_home(3, "tomato") and state.plot_level("home", 3) == 1, "A newly planted copy does not inherit another bed's upgrades")
	_check(state.home_income() == 19, "Garden income sums each individual crop's current yield")
	_check(not state.upgrade_plot("home", 4) and not state.upgrade_plot("unknown", 0), "Empty and invalid plots cannot buy levels")
	_check(state.plot_upgrade_cost("home", 4) == 0 and state.plot_upgrade_cost("home", -1) == 0, "Absent plantings expose no upgrade offer")
	state.earn(1000)
	_check(state.plant_nursery(0, "nettle") and state.plant_nursery(1, "nettle"), "Several real defenders of the same species can be planted")
	var second_damage: float = state.plot_data("nursery", 1)["damage"]
	_check(state.upgrade_plot("nursery", 0), "Selected defender can gain a level")
	_check(float(state.plot_data("nursery", 0)["damage"]) > second_damage and float(state.plot_data("nursery", 1)["damage"]) == second_damage, "A defender upgrade strengthens only that planting")
	_check(not state.upgrade("pepper") and state.upgrade_cost("pepper") == 0, "Compatibility calls cannot upgrade an unplanted species")
	var wallet: int = state.coins
	state.home_levels[0] = State.MAX_PLANT_LEVEL
	_check(state.plot_upgrade_cost("home", 0) == 0 and not state.upgrade_plot("home", 0), "Maximum-level plantings cannot buy a nonexistent upgrade")
	_check(state.coins == wallet, "Maximum-level rejection does not charge coins")
	state.coins = 0
	var before_failed: Dictionary = _snapshot(state)
	_check(not state.upgrade_plot("nursery", 0) and _snapshot(state) == before_failed, "Unaffordable upgrade leaves complete progression unchanged")
	var copied_data: Dictionary = state.plot_data("home", 1)
	copied_data["cost"] = 9999
	_check(state.plot_data("home", 1)["cost"] == 30, "Plot stat lookups cannot mutate the catalog")
	_check(state.plant_data("unknown", 2).is_empty(), "Unknown catalog lookup remains safe")
	_check(state.plant_data("nettle", 3)["level"] == 3, "Battle snapshots can request an explicit individual level")


func _test_owned_roster() -> void:
	var state = State.new()
	var roster: Array[Dictionary] = state.battle_roster()
	_check(roster.size() == 3, "Only the three actually planted crops appear in a fresh battle roster")
	_check(roster[0] == {"id": "home:0", "area": "home", "slot": 0, "kind": "tomato", "level": 1}, "Each roster entry has stable plot identity and species")
	_check(roster[1]["id"] == "home:1" and roster[0]["kind"] == roster[1]["kind"], "Two planted copies remain two distinct battle units")
	_check(not roster.any(func(entry): return entry["kind"] == "nettle"), "Catalog defenders alone do not unlock battle units")
	_check(state.plant_nursery(2, "nettle") and state.upgrade_plot("nursery", 2), "A real upgraded nursery plant can be created")
	roster = state.battle_roster()
	_check(roster.size() == 4 and roster[3]["id"] == "nursery:2" and roster[3]["level"] == 2, "Nursery planting and its actual level enter the battle roster")
	roster[0]["kind"] = "pepper"
	roster.clear()
	_check(state.battle_roster()[0]["kind"] == "tomato" and state.battle_roster().size() == 4, "Roster callers cannot edit persistent ownership")
	state.earn(100)
	state.unlocked_seeds.append("lavender")
	_check(state.replace_plot("nursery", 2, "lavender"), "A nursery planting can change its battle species")
	roster = state.battle_roster()
	_check(roster[3]["id"] == "nursery:2" and roster[3]["kind"] == "lavender" and roster[3]["level"] == 1, "Replacing updates the owned unit in place and resets its level")
	_check(not roster.any(func(entry): return entry["kind"] == "nettle"), "The replaced plant does not remain available as a phantom battle unit")


func _test_campaign_discoveries() -> void:
	var state = State.new()
	_check(state.home_plot_capacity() == 12 and state.nursery_plot_capacity() == 8, "A fresh garden exposes the original land only")
	_check(state.unlocked_seeds == CampaignData.STARTER_SEEDS, "A fresh seed collection includes only the starting cultures and nettle")
	_check(state.is_seed_unlocked("nettle") and not state.is_seed_unlocked("lavender") and not state.is_seed_unlocked("pumpkin"), "Seed discovery gates new plant species")
	_check(not state.plant_nursery(0, "lavender") and not state.plant_home(3, "pumpkin"), "Money cannot bypass an undiscovered seed")
	_check(not state.plant_home(12, "tomato") and not state.plant_nursery(8, "nettle"), "Expansion plots remain unplantable until their land is won")
	_check(not state.is_plot_unlocked("unknown", 0) and not state.is_plot_unlocked("home", -1) and not state.is_plot_unlocked("home", 24), "Unknown or out-of-range land is never unlocked")
	_check(state.is_stage_unlocked(1) and not state.is_stage_unlocked(2) and not state.is_stage_unlocked(0), "The campaign starts with its first battle only")
	var original: Dictionary = _snapshot(state)
	_check(state.claim_stage_reward(2).is_empty() and state.claim_stage_reward(0).is_empty() and _snapshot(state) == original, "Out-of-order or invalid victories cannot grant discoveries")
	var changes: Array[int] = [0]
	state.changed.connect(func(): changes[0] += 1)
	var reward: Dictionary = state.claim_stage_reward(1)
	_check(changes[0] == 1 and reward["first_clear"] and reward["district"] == "berry", "First victory emits one atomic permanent discovery")
	_check(reward["seeds"] == CampaignData.STAGES[0]["seeds"] and reward["home_plots"] == 4 and reward["nursery_plots"] == 0, "First victory grants the promised seed and four farm beds")
	_check(reward["new_seeds"] == CampaignData.STAGES[0]["seeds"], "Discovery receipts distinguish a genuinely new seed from the nominal stage reward")
	_check(state.home_plot_capacity() == 16 and state.nursery_plot_capacity() == 8 and state.completed_level == 1, "First district opens four actual income positions")
	_check(state.is_seed_unlocked("lavender") and state.is_stage_unlocked(2) and not state.is_stage_unlocked(3), "First discovery unlocks the next plant and next battle")
	_check(state.coins == 240, "Permanent battle discoveries never charge or manufacture coins")
	reward["seeds"][0] = "pumpkin"
	_check(CampaignData.stage_info(1)["seeds"] == CampaignData.STAGES[0]["seeds"] and not state.is_seed_unlocked("pumpkin"), "Reward callers cannot mutate campaign data or unearned seeds")
	var first_snapshot: Dictionary = _snapshot(state)
	_check(state.claim_stage_reward(1).is_empty() and _snapshot(state) == first_snapshot, "Replaying a victory cannot duplicate land or seeds")
	_check(state.plant_home(12, "strawberry") and state.coins == 180, "Won land is a real purchasable income planting")
	_check(not state.plant_home(16, "tomato"), "The following district remains locked")
	reward = state.claim_stage_reward(2)
	_check(reward["seeds"] == ["pepper", "mint"] and reward["nursery_plots"] == 2 and reward["district"] == "far_garden", "Second victory grants pepper and the next real expansion")
	_check(state.home_plot_capacity() == 20 and state.nursery_plot_capacity() == 10 and state.is_seed_unlocked("pepper"), "Second district expands both growing areas")
	_check(state.plant_nursery(8, "pepper") and state.coins == 110, "A new defensive plot accepts its unlocked seed")
	_check(not state.plant_nursery(10, "nettle"), "The final nursery extension remains locked")
	reward = state.claim_stage_reward(3)
	_check(reward["seeds"] == ["pumpkin"] and reward["district"] == "sun_meadow", "Final victory discovers a new valuable income plant")
	_check(state.home_plot_capacity() == 24 and state.nursery_plot_capacity() == 12 and state.is_seed_unlocked("pumpkin"), "All campaign land becomes usable after three first victories")
	_check(state.plant_home(23, "pumpkin") and state.coins == 30, "The final new income bed supports the newly discovered pumpkin")
	_check(state.plot_data("home", 23)["home_yield"] == 10 and state.plot_data("home", 23)["battle_yield"] == 45, "New seed has actual income statistics at home and in battle")
	var finished: Dictionary = _snapshot(state)
	_check(state.claim_stage_reward(3).is_empty() and state.claim_stage_reward(4).is_empty() and _snapshot(state) == finished, "Finished campaign cannot generate additional permanent discoveries")
	_check(state.unlocked_seeds.size() == Catalog.ORDER.size(), "The three first victories discover each prototype seed exactly once")
	_check(CampaignData.stage_info(0).is_empty() and CampaignData.stage_info(4).is_empty(), "Unknown campaign stages have no rewards")
	_check(CampaignData.seed_unlock_stage("tomato") == 0 and CampaignData.seed_unlock_stage("lavender") == 1 and CampaignData.seed_unlock_stage("pepper") == 2 and CampaignData.seed_unlock_stage("pumpkin") == 3 and CampaignData.seed_unlock_stage("unknown") == -1, "Seed descriptions can identify their exact discovery battle")
	_check(CampaignData.district_unlock_stage("garden") == 0 and CampaignData.district_unlock_stage("berry") == 1 and CampaignData.district_unlock_stage("sun_meadow") == 3, "World areas can identify the battle required to open them")


func _test_grandfather_discovery_receipt() -> void:
	# A v2 player may already own lavender before the campaign assigns it to
	# stage one. Winning still opens land, but must not report a second unlock.
	var state = State.new()
	state.unlocked_seeds.append("lavender")
	var before: Array[String] = state.unlocked_seeds.duplicate()
	var reward: Dictionary = state.claim_stage_reward(1)
	_check(reward["first_clear"] and reward["district"] == "berry" and reward["home_plots"] == 4, "Grandfathered seeds do not prevent the first land discovery")
	_check(reward["seeds"] == CampaignData.STAGES[0]["seeds"] and reward["new_seeds"] == ["strawberry", "currant", "waterlily", "lotus"], "A grandfathered seed is not announced again while new regional seeds are discovered")
	_check(state.unlocked_seeds.slice(0, before.size()) == before and state.unlocked_seeds.count("lavender") == 1, "The old seed is retained without duplicate collection entries")
	var after: Dictionary = _snapshot(state)
	_check(state.claim_stage_reward(1).is_empty() and _snapshot(state) == after, "Replaying the grandfathered discovery does not grant another receipt or land")
	_check(state.save_game(test_save), "A first victory with an old seed remains saveable")
	var restored = State.new()
	_check(restored.load_game(test_save) and restored.claim_stage_reward(1).is_empty(), "Reloading cannot turn an already claimed old seed into a new unlock")
	reward = restored.claim_stage_reward(2)
	_check(reward["seeds"] == ["pepper", "mint"] and reward["new_seeds"] == ["pepper", "mint"], "A genuinely new seed still receives the new-unlock receipt after a grandfathered reward")
	reward["new_seeds"][0] = "pumpkin"
	_check(restored.is_seed_unlocked("pepper") and not restored.is_seed_unlocked("pumpkin"), "Editing a reward receipt cannot alter permanent seed availability")


func _test_battle_templates() -> void:
	var state = State.new()
	state.earn(1000)
	var templates: Array[Dictionary] = state.battle_templates()
	_check(templates.size() == 2 and templates[0]["kind"] == "tomato" and templates[1]["kind"] == "marigold", "A species appears once in the pre-battle choices regardless of grown copy count")
	_check(templates[0]["id"] == "tomato" and templates[0]["source_id"] == "home:0" and templates[0]["cost"] == 45, "Battle templates preserve a real origin and the deployment price")
	state.upgrade_plot("home", 1)
	state.upgrade_plot("home", 1)
	templates = state.battle_templates()
	_check(templates[0]["level"] == 3 and templates[0]["source_id"] == "home:1", "The best grown level of a species supplies its battle template")
	_check(state.plot_level("home", 0) == 1, "Choosing a strongest template does not change other individual plants")
	state.claim_stage_reward(1)
	_check(not state.battle_templates().any(func(entry): return entry["kind"] == "lavender"), "Discovering a seed alone never grants a grown battle template")
	state.plant_nursery(0, "lavender")
	state.upgrade_plot("nursery", 0)
	templates = state.battle_templates()
	_check(templates.size() == 3 and templates[2]["kind"] == "lavender" and templates[2]["level"] == 2, "A real new nursery plant adds its upgraded species to the pre-battle choices")
	_check(templates[2]["name"] == "Лаванда" and templates[2]["role"] == "defense" and templates[2]["source_id"] == "nursery:0", "Template data includes the name, role and real selected source")
	templates[0]["kind"] = "pepper"
	templates[2]["level"] = 20
	templates.clear()
	_check(state.battle_templates()[0]["kind"] == "tomato" and state.battle_templates()[2]["level"] == 2, "Pre-battle choices cannot modify persistent plants or their levels")


func _test_version_two_migration() -> void:
	var old = {
		"version": 2, "coins": 8,
		"levels": {"tomato": 1, "marigold": 1, "nettle": 3, "lavender": 1, "pepper": 1},
		"home_plots": ["tomato", "tomato", "marigold", "", "", "", "", "", "", "", "", ""],
		"home_levels": [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
		"nursery_plots": ["lavender", "pepper", "", "", "", "", "", ""],
		"nursery_levels": [4, 2, 1, 1, 1, 1, 1, 1],
		"completed_level": 0, "home_elapsed": 11.5, "home_ready": false,
	}
	_write_payload(old)
	var state = State.new()
	_check(state.load_game(test_save), "An existing version-two garden migrates without the new seed field")
	_check(state.coins == 8 and state.completed_level == 0 and state.home_elapsed == 11.5, "Version-two migration preserves money, campaign progress and growth")
	_check(state.home_plots.slice(0, 12) == old["home_plots"] and state.home_levels.slice(0, 12) == old["home_levels"], "Existing income plantings and independent levels keep their positions")
	_check(state.nursery_plots.slice(0, 8) == old["nursery_plots"] and state.nursery_levels.slice(0, 8) == old["nursery_levels"], "Existing nursery plantings and independent levels keep their positions")
	_check(state.home_plots.size() == 24 and state.nursery_plots.size() == 12 and state.home_plots.slice(12).all(func(kind): return kind == "") and state.nursery_plots.slice(8).all(func(kind): return kind == ""), "Expansion storage adds empty places without pretending the land is already won")
	_check(state.home_plot_capacity() == 12 and state.nursery_plot_capacity() == 8, "A migrated unfinished campaign retains the base usable land")
	_check(state.is_seed_unlocked("lavender") and state.is_seed_unlocked("pepper") and not state.is_seed_unlocked("pumpkin"), "Already grown species are grandfathered even before their newly assigned reward stages")
	_check(state.nursery_plots.count("nettle") == 0, "Version two does not recreate a replaced legacy planting from an obsolete global level")
	_check(state.save_game(test_save), "Migrated version-two state can be written as version three")
	var restored = State.new()
	_check(restored.load_game(test_save) and _snapshot(restored) == _snapshot(state), "A migrated garden round trips with its grandfathered seeds intact")
	old["nursery_plots"] = ["", "", "", "", "", "", "", ""]
	old["nursery_levels"] = [1, 1, 1, 1, 1, 1, 1, 1]
	old["levels"]["nettle"] = 1
	_write_payload(old)
	_check(restored.load_game(test_save) and not restored.is_seed_unlocked("lavender") and not restored.is_seed_unlocked("pepper"), "Unpurchased old catalog entries do not bypass new seed discoveries")
	old["completed_level"] = 2
	_write_payload(old)
	_check(restored.load_game(test_save) and restored.home_plot_capacity() == 20 and restored.nursery_plot_capacity() == 10 and restored.is_seed_unlocked("lavender") and restored.is_seed_unlocked("pepper"), "Previously completed campaign stages migrate with their associated land and seed rewards")


func _test_persistence() -> void:
	var state = State.new()
	state.earn(1000)
	state.claim_stage_reward(1)
	state.claim_stage_reward(2)
	state.plant_home(11, "cucumber")
	state.plant_nursery(8, "pepper")
	state.upgrade_plot("home", 0)
	state.upgrade_plot("nursery", 8)
	state.completed_level = 2
	state.tick(12.5)
	_check(state.save_game(test_save), "Version-three save is written atomically")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(test_save))
	_check(payload["version"] == State.SAVE_VERSION, "New saves record the per-plot schema version")
	_check(payload["home_plots"].size() == 24 and payload["nursery_plots"].size() == 12, "Both real planting areas are serialized")
	var restored = State.new()
	_check(restored.load_game(test_save), "A valid per-plot save reloads")
	_check(_snapshot(restored) == _snapshot(state), "Wallet, both planting areas, independent levels and growth survive reload")
	_check(restored.battle_roster() == state.battle_roster(), "The exact owned battle roster survives reload")
	state.tick(State.HOME_CYCLE)
	_check(state.save_game(test_save) and restored.load_game(test_save) and restored.home_ready, "A ripe harvest survives reload")
	_check(not restored.load_game(test_directory.path_join("missing.json")), "A missing save safely returns false")


func _test_legacy_migration() -> void:
	for count in [State.LEGACY_HOME_PLOT_COUNT, State.BASE_HOME_PLOT_COUNT]:
		var legacy: Dictionary = _legacy_payload(count)
		_write_payload(legacy)
		var restored = State.new()
		_check(restored.load_game(test_save), "A valid version-one %d-plot save migrates" % count)
		_check(restored.home_plots.size() == 24 and restored.home_plots.slice(0, 6) == legacy["home_plots"].slice(0, 6), "Migration retains existing crop positions and expands the garden")
		_check(restored.home_plots.slice(6).all(func(kind): return kind == ""), "Legacy garden expansion adds empty positions")
		_check(restored.home_levels[0] == 3 and restored.home_levels[1] == 3 and restored.home_levels[2] == 2 and restored.home_levels[3] == 1, "Each occupied old crop receives its species level; empty plots remain level one")
		_check(restored.nursery_plots[0] == "nettle" and restored.nursery_levels[0] == 4 and restored.nursery_plots.slice(1).all(func(kind): return kind == ""), "Paid old defender upgrades become one real planting; level-one decorative entries do not")
		_check(restored.battle_roster().size() == 5 and restored.battle_roster()[4] == {"id": "nursery:0", "area": "nursery", "slot": 0, "kind": "nettle", "level": 4}, "Migrated roster retains the paid defender and all actual crops")
		_check(restored.coins == 761 and restored.completed_level == 2 and restored.home_elapsed == 17.25 and not restored.home_ready, "Migration preserves money, stage progress and current growth")
		_check(restored.levels["pumpkin"] == 1 and State.LEGACY_KINDS.all(func(kind): return restored.levels[kind] == legacy["levels"][kind]), "Legacy catalog levels remain available for compatibility")
		_check(restored.save_game(test_save), "Migrated state can be written as version three")
		var migrated: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(test_save))
		_check(migrated["version"] == State.SAVE_VERSION and migrated["home_levels"].size() == 24 and migrated["nursery_levels"].size() == 12, "Migration writes the full independent planting schema")
		var round_trip = State.new()
		_check(round_trip.load_game(test_save) and _snapshot(round_trip) == _snapshot(restored), "Migrated state remains stable on a version-two round trip")
	var ready_legacy: Dictionary = _legacy_payload(6)
	ready_legacy["home_elapsed"] = State.HOME_CYCLE
	ready_legacy["home_ready"] = true
	_write_payload(ready_legacy)
	var ready = State.new()
	_check(ready.load_game(test_save) and ready.home_ready, "Legacy collectible harvest remains collectible after migration")


func _test_legacy_paid_defenders() -> void:
	# Mirrors the existing v1 player: only eight coins remain after paying for
	# nettle level three, before nursery plots existed as persistent plantings.
	var legacy: Dictionary = _legacy_payload(State.BASE_HOME_PLOT_COUNT)
	legacy["coins"] = 8
	legacy["home_plots"] = State.new().home_plots.slice(0, State.BASE_HOME_PLOT_COUNT)
	legacy["completed_level"] = 0
	for kind in State.LEGACY_KINDS:
		legacy["levels"][kind] = 1
	legacy["levels"]["nettle"] = 3
	_write_payload(legacy)
	var restored = State.new()
	_check(restored.load_game(test_save), "The existing low-wallet v1 player migrates successfully")
	_check(restored.coins == 8, "Migrating paid defender progress does not charge or credit the wallet")
	_check(restored.nursery_plots[0] == "nettle" and restored.nursery_levels[0] == 3, "Paid nettle level three becomes one real level-three nursery plant")
	_check(restored.nursery_plots.slice(1).all(func(kind): return kind == "") and restored.nursery_levels.slice(1).all(func(level): return level == 1), "Unpurchased lavender and pepper stay absent from the nursery")
	var nursery_units: Array[Dictionary] = restored.battle_roster().filter(func(entry): return entry["area"] == "nursery")
	_check(nursery_units == [{"id": "nursery:0", "area": "nursery", "slot": 0, "kind": "nettle", "level": 3}], "Exactly one owned battle unit carries the player's paid level")
	_check(restored.plot_data("nursery", 0)["damage"] == restored.plant_data("nettle", 3)["damage"], "The migrated defender retains its upgraded combat strength")
	_check(restored.save_game(test_save), "The paid migration writes a version-two save")
	var migrated: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(test_save))
	_check(migrated["version"] == State.SAVE_VERSION, "The migrated paid defender is recorded under schema three")
	var snapshot: Dictionary = _snapshot(restored)
	for index in range(3):
		var reloaded = State.new()
		_check(reloaded.load_game(test_save) and _snapshot(reloaded) == snapshot, "Reloading version three preserves the migrated planting without adding another copy")
		_check(reloaded.battle_roster().filter(func(entry): return entry["area"] == "nursery").size() == 1, "Repeated load cannot duplicate a paid legacy defender")
		_check(reloaded.save_game(test_save), "The migrated state remains saveable after repeated loads")
	legacy["levels"]["nettle"] = 1
	_write_payload(legacy)
	var unupgraded = State.new()
	_check(unupgraded.load_game(test_save) and unupgraded.coins == 8, "An unupgraded old garden migrates without changing its wallet")
	_check(unupgraded.nursery_plots.all(func(kind): return kind == "") and unupgraded.nursery_levels.all(func(level): return level == 1), "All-level-one legacy catalogs leave the nursery empty")
	_check(unupgraded.battle_roster().all(func(entry): return entry["area"] == "home"), "Decorative old defenders do not unlock battle units")
	legacy["levels"]["nettle"] = 2
	legacy["levels"]["lavender"] = 4
	legacy["levels"]["pepper"] = 6
	_write_payload(legacy)
	var upgraded_collection = State.new()
	_check(upgraded_collection.load_game(test_save), "Several paid legacy defender species can migrate together")
	_check(upgraded_collection.nursery_plots.slice(0, 3) == ["nettle", "lavender", "pepper"] and upgraded_collection.nursery_levels.slice(0, 3) == [2, 4, 6], "Each upgraded defender species receives one distinct real planting with its own paid level")
	_check(upgraded_collection.nursery_plots.slice(3).all(func(kind): return kind == "") and upgraded_collection.coins == 8, "Paid collection migration leaves remaining nursery places and wallet unchanged")


func _test_invalid_saves_are_atomic() -> void:
	var state = State.new()
	state.earn(1000)
	state.plant_nursery(0, "nettle")
	state.upgrade_plot("nursery", 0)
	state.upgrade_plot("home", 1)
	state.save_game(test_save)
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(test_save))
	var baseline: Dictionary = _snapshot(state)
	var corruptions: Array[Dictionary] = []
	for patch in [
		{"version": State.SAVE_VERSION + 1}, {"version": 0}, {"version": 1.5}, {"coins": -1}, {"coins": "100"},
		{"coins": State.MAX_COINS + 1}, {"completed_level": -1}, {"home_elapsed": "wrong"},
		{"home_elapsed": -0.5}, {"home_elapsed": State.HOME_CYCLE + 1}, {"home_ready": true},
		{"home_ready": 1}, {"home_plots": []}, {"home_levels": []}, {"nursery_plots": []},
		{"nursery_levels": []}, {"levels": {}},
	]:
		var broken: Dictionary = valid.duplicate(true)
		broken.merge(patch, true)
		corruptions.append(broken)
	for field in ["home_levels", "nursery_levels", "nursery_plots", "unlocked_seeds"]:
		var missing: Dictionary = valid.duplicate(true)
		missing.erase(field)
		corruptions.append(missing)
	for pair in [["home_plots", "nettle"], ["home_plots", "unknown"], ["nursery_plots", "tomato"], ["nursery_plots", 12]]:
		var broken: Dictionary = valid.duplicate(true)
		broken[pair[0]][0] = pair[1]
		corruptions.append(broken)
	for pair in [["home_levels", 0], ["home_levels", 1.5], ["home_levels", "2"], ["home_levels", 21], ["nursery_levels", 0], ["nursery_levels", "3"], ["nursery_levels", 21]]:
		var broken: Dictionary = valid.duplicate(true)
		broken[pair[0]][0] = pair[1]
		corruptions.append(broken)
	var upgraded_empty: Dictionary = valid.duplicate(true)
	upgraded_empty["home_levels"][3] = 2
	corruptions.append(upgraded_empty)
	for seeds in [["tomato", "marigold", "nettle", "unknown"], ["tomato", "marigold", "nettle", "nettle"], ["tomato", "marigold"], "wrong"]:
		var broken: Dictionary = valid.duplicate(true)
		broken["unlocked_seeds"] = seeds
		corruptions.append(broken)
	for area_and_slot in [["home_plots", 12, "tomato"], ["nursery_plots", 8, "nettle"]]:
		var broken: Dictionary = valid.duplicate(true)
		broken[area_and_slot[0]][area_and_slot[1]] = area_and_slot[2]
		corruptions.append(broken)
	for broken in corruptions:
		_write_payload(broken)
		_check(not state.load_game(test_save), "Invalid version-two save is rejected")
		_check(_snapshot(state) == baseline, "Invalid save preserves the complete current state atomically")
	var file = FileAccess.open(test_save, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	_check(not state.load_game(test_save) and _snapshot(state) == baseline, "Truncated JSON cannot partly replace the garden")
	for count in [0, 5, 7, 11, 13]:
		var legacy: Dictionary = _legacy_payload(6)
		var plots: Array[String] = []
		plots.resize(count)
		plots.fill("")
		legacy["home_plots"] = plots
		_write_payload(legacy)
		_check(not state.load_game(test_save) and _snapshot(state) == baseline, "Invalid legacy plot count cannot replace the current garden")


func _legacy_payload(count: int) -> Dictionary:
	var plots: Array[String] = ["tomato", "tomato", "marigold", "", "tomato", ""]
	while plots.size() < count:
		plots.append("")
	return {
		"version": 1,
		"coins": 761,
		"levels": {"tomato": 3, "marigold": 2, "nettle": 4, "lavender": 1, "pepper": 1},
		"home_plots": plots,
		"completed_level": 2,
		"home_elapsed": 17.25,
		"home_ready": false,
	}


func _snapshot(state: GardenState) -> Dictionary:
	return {
		"coins": state.coins,
		"levels": state.levels.duplicate(true),
		"home_plots": state.home_plots.duplicate(),
		"home_levels": state.home_levels.duplicate(),
		"nursery_plots": state.nursery_plots.duplicate(),
		"nursery_levels": state.nursery_levels.duplicate(),
		"pond_plots": state.pond_plots.duplicate(),
		"pond_levels": state.pond_levels.duplicate(),
		"unlocked_seeds": state.unlocked_seeds.duplicate(),
		"completed_level": state.completed_level,
		"home_elapsed": state.home_elapsed,
		"home_ready": state.home_ready,
	}


func _write_payload(payload: Dictionary) -> void:
	var file = FileAccess.open(test_save, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
