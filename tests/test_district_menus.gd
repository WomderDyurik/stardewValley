extends SceneTree

const Catalog = preload("res://scripts/catalog.gd")
const Presentation = preload("res://scripts/battle_presentation.gd")
var game: Node2D
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _has_action(action: String) -> bool:
	for hit in game.hitboxes:
		if hit["action"] == action:
			return true
	return false

func _actions(prefix: String) -> Array[String]:
	var result: Array[String] = []
	for hit in game.hitboxes:
		if String(hit["action"]).begins_with(prefix):
			result.append(String(hit["action"]).trim_prefix(prefix))
	return result

func _text_contains(fragment: String) -> bool:
	for layout in game.text_layouts:
		if String(layout["text"]).contains(fragment):
			return true
	return false

func _settle(label: String) -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	for layout in game.text_layouts:
		_expect(not layout["truncated"], label + ": text stays readable: " + layout["text"])
		for run in layout["runs"]:
			_expect(layout["bounds"].grow(0.1).encloses(run["rect"]), label + ": text respects its allocated rectangle")
	if OS.get_cmdline_user_args().has("--screenshots"):
		root.get_texture().get_image().save_png("res://artifacts/district-menu-" + label + ".png")

func _open_plot(area: String, slot: int, panel: String) -> void:
	game.active_plot_area = area
	game.active_plot_slot = slot
	game.home_panel = panel

func _free_point(kind: String = "") -> Vector2:
	for x in range(39,454,13):
		for y in range(39,392,13):
			var point := Vector2(float(x)+0.375,float(y)+0.125)
			if game.battle.placement_check(point,kind).get("valid",false): return point
	_expect(false,"district menu fixture needs a legitimate free planting position")
	return Vector2.INF

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.state.coins = 10000000
	game._action("open_districts")
	await _settle("districts-locked")
	_expect(_actions("district:").size() == 7 and _has_action("close_home_panel"), "district sheet includes all destinations and a visible close control")
	_expect(not _has_action("collect") and not _has_action("battle") and _actions("home_plot:").is_empty(), "district sheet suppresses the underlying garden controls")
	_expect(_text_contains("Откроется после задания"), "locked districts explain the mission required without hiding their destination")
	game._action("close_home_panel")
	for stage in range(1, 4):
		game.state.claim_stage_reward(stage)
	game._action("open_districts")
	await _settle("districts-unlocked")
	_expect(_actions("district:").size() == 7 and not _text_contains("Откроется после задания"), "unlocked district navigation shows actual habitat descriptions")
	game._action("close_home_panel")
	var cases: Array = [
		["home", 0, ["tomato", "marigold"], "Огород"],
		["home", 8, ["cucumber"], "Теплица"],
		["home", 12, ["strawberry", "currant"], "Ягодник"],
		["home", 16, ["mint"], "Дальний огород"],
		["home", 20, ["pumpkin"], "Тёплая поляна"],
		["nursery", 0, ["nettle", "lavender"], "Питомник"],
		["nursery", 8, ["pepper"], "Дальний огород"],
		["pond", 0, ["waterlily", "lotus"], "Пруд"],
	]
	for entry in cases:
		_open_plot(entry[0], entry[1], "plant_picker")
		await _settle("picker-" + str(entry[0]) + str(entry[1]))
		var expected: Array[String] = []
		for kind in entry[2]:
			if game.state.plot_kind(entry[0], entry[1]) != kind:
				expected.append(kind)
		_expect(_actions("plant:") == expected, "Picker offers only the selected district's compatible plants")
		_expect(_text_contains(entry[3]), "Picker identifies the actual district")
		_expect(_text_contains("Водные растения") if entry[0] == "pond" else true, "Water picker explains its habitat")
	game.state.home_plots[12] = "tomato"
	game.state.home_levels[12] = 9
	_open_plot("home", 12, "plot")
	await _settle("legacy-details")
	_expect(_text_contains("Ранняя посадка сохранена") and _has_action("upgrade_plot"), "Old out-of-profile planting remains usable and explains compatible replacement")
	game.state.home_plots[12] = ""
	var grown: Array = [
		["home", 8, "cucumber"], ["home", 12, "strawberry"], ["home", 13, "currant"],
		["home", 16, "mint"], ["home", 20, "pumpkin"], ["nursery", 0, "nettle"],
		["nursery", 1, "lavender"], ["nursery", 8, "pepper"], ["pond", 0, "waterlily"], ["pond", 1, "lotus"],
	]
	for planting in grown:
		_expect(game.state.plant_plot(planting[0], planting[1], planting[2]), "Test collection grows each species in its own district")
	for slot in [0, 1]:
		game.state.pond_levels[slot] = 20
		_open_plot("pond", slot, "plot")
		await _settle("pond-details-" + str(slot))
		_expect(_text_contains("Монет за урожай") if slot == 0 else _text_contains("Урон"), "Pond statistics use the planted species role")
	game.home_panel = ""
	game._show_screen("battle")
	game._new_battle()
	await _settle("loadout-first")
	_expect(game.battle.loadout_options().size() == 12, "All twelve actually grown species are available")
	_expect(_actions("loadout_toggle:").size() == 6 and _has_action("loadout_page:1") and not _has_action("loadout_page:-1"), "First loadout page has six cards and valid navigation")
	var chosen: Array[String] = game.loadout_choices.duplicate()
	game._action("loadout_toggle:tomato")
	chosen.erase("tomato")
	game._action("loadout_page:1")
	await _settle("loadout-second")
	_expect(game.loadout_page == 1 and _actions("loadout_toggle:").size() == 6, "Second page shows six additional species")
	_expect(game.loadout_choices == chosen and _has_action("loadout_toggle:lotus"), "Page navigation preserves previous choices and exposes aquatic species")
	game._action("loadout_page:-1")
	await _settle("loadout-return")
	_expect(game.loadout_page == 0 and game.loadout_choices == chosen, "Returning to the first page retains unchecked species")
	game.loadout_choices.assign(["lotus"])
	await _settle("loadout-defender-other-page")
	_expect(not _text_contains("возьмите хотя бы одну пушку"), "Defender on another page is counted in the whole composition")
	game.loadout_choices.assign(Catalog.ORDER)
	game._action("confirm_loadout")
	game.battle.supplies = 100000
	game.last_tap_point = game.battle_to_screen(_free_point())
	game._action("battle_ground")
	await _settle("deploy-first")
	_expect(_actions("deploy:").size() == 6 and _has_action("battle_page:1"), "Deployment also pages the full collection")
	game._action("battle_page:1")
	await _settle("deploy-second")
	_expect(_has_action("deploy:lotus") and _actions("deploy:").size() == 6, "Aquatic grown plant can be chosen from the second deployment page")
	game._action("close_battle_panel")
	var income_slot: int = game.battle.plant_at(_free_point("tomato"),"tomato")
	_expect(income_slot >= 0, "economic inspection grows a paid plant from the selected level snapshot")
	game._sync_battle_geometry()
	game._action("battle_plot:%d" % income_slot)
	await _settle("income-payback-early")
	var projection: Dictionary = Presentation.income_projection(game.battle,"tomato",1)
	_expect(projection["remaining_harvests"] == 5 and projection["can_payback"] and _text_contains(projection["summary"]), "economic inspection shows the real early-game payback horizon")
	game._action("close_battle_panel")
	game.battle.wave = 4
	game.battle.phase = "between"
	game._action("battle_plot:%d" % income_slot)
	await _settle("income-payback-late")
	projection = Presentation.income_projection(game.battle,"tomato",1)
	_expect(projection["remaining_harvests"] == 1 and not projection["can_payback"] and _text_contains("Не окупится"), "late economic inspection explains that the next installation cannot recover its supplies")
	game._action("close_battle_panel")
	game.battle.phase = "running"
	game._action("battle_plot:%d" % income_slot)
	await _settle("income-payback-current-wave")
	projection = Presentation.income_projection(game.battle,"tomato",1)
	_expect(projection["remaining_harvests"] == 2 and _text_contains(projection["summary"]), "economic horizon counts the still-running wave as a payable harvest")
	game._action("close_battle_panel")
	game.current_stage = 3
	game._new_battle()
	var reference_choices: Array[String] = game.loadout_choices.duplicate()
	game._action("wave_preview")
	game._action("battle_guide_tab:enemies")
	var profiles: Array[Dictionary] = Presentation.guide_enemy_profiles(3)
	var pages: int = ceili(float(profiles.size()) / float(Presentation.ENEMY_PAGE_SIZE))
	var reference_seen: Dictionary = {}
	for page in range(pages):
		await _settle("expanded-enemies-page-" + str(page+1))
		_expect(game.enemy_guide_page == page, "expanded bestiary renders the requested valid page")
		_expect(_has_action("enemy_guide_page:-1") == (page > 0) and _has_action("enemy_guide_page:1") == (page+1 < pages), "enemy reference never offers navigation outside its actual pages")
		for profile in Presentation.guide_enemy_page(3,page)["profiles"]:
			_expect(_text_contains(profile["name"]), "expanded regional reference exposes every enemy name")
			reference_seen[profile["kind"]] = true
		if page+1 < pages: game._action("enemy_guide_page:1")
	_expect(reference_seen.size() == profiles.size(), "all enemy mechanics are reachable across dynamic pages")
	for filter in Presentation.guide_enemy_groups(3):
		game._action("enemy_group:" + str(filter["id"]))
		await _settle("expanded-enemies-group-" + str(filter["id"]))
		_expect(game.enemy_guide_page == 0 and game.enemy_guide_category == filter["id"], "changing a regional group resets pagination without committing a composition")
	game._action("close_wave_preview")
	_expect(game.loadout_choices == reference_choices and game.battle_panel == "loadout", "enemy-reference paging does not disturb the regional plant composition")
	print("District menus: ", checks, " checks, ", failures, " failures")
	game.queue_free()
	quit(0 if failures == 0 else 1)
