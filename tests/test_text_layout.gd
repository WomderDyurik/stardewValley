extends SceneTree
const Presentation = preload("res://scripts/battle_presentation.gd")
var game: Node2D
var failures := 0
var checked := 0
func _initialize() -> void:
	run.call_deferred()
func audit(label: String, screenshot: bool = false) -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	for layout in game.text_layouts:
		checked += 1
		if layout["truncated"]:
			print("TRUNCATED ", label, " ",layout["text"], " ",layout["bounds"])
			failures += 1
		for run in layout["runs"]:
			if not layout["bounds"].grow(0.1).encloses(run["rect"]):
				print("OVERFLOW ", label," ",layout["text"]," ",layout["bounds"]," ",run["rect"])
				failures += 1
	for target in game.hitboxes:
		if bool(target.get("world",false)) or str(target["action"]) == "battle_ground": continue
		var bounds: Rect2 = target["rect"]
		if bounds.size.x < 44.0 or bounds.size.y < 44.0:
			print("SMALL TARGET ",label," ",target["action"]," ",bounds)
			failures += 1
	if screenshot and OS.get_cmdline_user_args().has("--screenshots"):
		root.get_texture().get_image().save_png("/Users/alexander/Desktop/planta2/artifacts/text-"+label+".png")
func free_position(kind: String = "") -> Vector2:
	for x in range(39,454,13):
		for y in range(39,392,13):
			var at := Vector2(float(x)+0.375,float(y)+0.125)
			if game.battle.placement_check(at,kind).get("valid",false): return at
	failures += 1
	push_error("Text fixture needs a valid free planting position for " + kind)
	return Vector2.INF
func plant_copy(kind: String) -> int:
	var slot: int = game.battle.plant_at(free_position(kind),kind)
	if slot < 0:
		failures += 1
		push_error("Text fixture must actually install " + kind)
	game._sync_battle_geometry()
	return slot
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	await create_timer(0.2).timeout
	game.set_process(false)
	game.state.coins = 1234567890
	await audit("compact-navigation", true)
	game._action("open_districts")
	await audit("districts-locked", true)
	game._action("close_home_panel")
	for stage in range(1,4): game.state.claim_stage_reward(stage)
	game._action("open_districts")
	await audit("districts-unlocked", true)
	game._action("close_home_panel")
	for district in ["garden","nursery","greenhouse","pond","berry","far_garden","sun_meadow"]:
		game._action("district:"+district)
		await audit(district, true)
	game._action("help")
	await audit("help",true)
	game._action("help")
	for fixture in [["home",0,"tomato"],["home",2,"marigold"],["home",8,"cucumber"],["home",12,"strawberry"],["home",13,"currant"],["home",16,"mint"],["home",20,"pumpkin"],["nursery",0,"nettle"],["nursery",1,"lavender"],["nursery",8,"pepper"],["pond",0,"waterlily"],["pond",1,"lotus"]]:
		var area: String = fixture[0]
		var slot: int = fixture[1]
		var kind: String = fixture[2]
		game.state.replace_plot(area,slot,kind) if not game.state.plot_kind(area,slot).is_empty() else game.state.plant_plot(area,slot,kind)
		if area == "home": game.state.home_levels[slot] = 20
		elif area == "nursery": game.state.nursery_levels[slot] = 20
		else: game.state.pond_levels[slot] = 20
		game._open_plot(area,slot)
		await audit("upgrade-"+kind,true)
		game._action("close_home_panel")
	for fixture in [["home",7],["home",9],["home",14],["home",17],["home",21],["nursery",3],["pond",2]]:
		game._open_plot(fixture[0],fixture[1])
		await audit("picker-"+fixture[0]+str(fixture[1]),true)
		game._action("close_home_panel")
	for panel in ["nursery", "greenhouse"]:
		game._action(panel)
		await audit(panel+"-menu",true)
		game._action("close_home_panel")
	game._action("battle")
	await audit("missions",true)
	game._action("stage:1")
	await audit("loadout",true)
	game._action("loadout_page:1")
	await audit("loadout2",true)
	game._action("confirm_loadout")
	game.last_tap_point = game.battle_to_screen(free_position())
	game._action("battle_ground")
	await audit("deployment",true)
	game._action("deploy:nettle")
	var defender_slot: int = int(game.battle.plants[-1]["slot"])
	game._action("battle_plot:%d" % defender_slot)
	await audit("inspect",true)
	game.battle_panel = ""
	game.battle.supplies = 500
	plant_copy("waterlily")
	plant_copy("lotus")
	plant_copy("marigold")
	game.battle.start_wave()
	game.battle._spawn_enemy()
	game.battle.enemies[0]["position"] = Vector2(240,180)
	game.battle._hit_enemy(game.battle.enemies[0],100000)
	game.battle._finish_wave()
	await audit("coin-rewards",true)
	game.coin_popups.clear()
	game.battle.wave = 5
	game.battle.phase = "running"
	game.battle._finish_wave()
	if game.result_open or game.result_delay <= 0.0:
		push_error("Final harvest must remain visible before result")
		failures += 1
	game._process(0.2)
	await audit("final-harvest",true)
	for step in range(9): game._process(0.2)
	if not game.result_open:
		push_error("Victory result must appear after reward animations")
		failures += 1
	game.coin_popups.clear()
	game.battle._finish_battle(true)
	await audit("victory",true)
	game.battle.discovery_reward = Campaign.stage_info(1)
	await audit("first-clear-many-seeds",true)
	for stage in range(1,4):
		game.current_stage = stage
		game._new_battle()
		game._action("wave_preview")
		await audit("wave-plan-stage"+str(stage),true)
		game._action("battle_guide_tab:enemies")
		for filter in Presentation.guide_enemy_groups(stage):
			var category: String = str(filter["id"])
			game._action("enemy_group:" + category)
			var pages: int = int(Presentation.guide_enemy_page(stage, 0, category)["pages"])
			for page in range(pages):
				await audit("enemy-reference-stage%d-%s-page%d" % [stage,category,page+1],true)
				if page + 1 < pages: game._action("enemy_guide_page:1")
		game._action("battle_guide_tab:rules")
		await audit("battle-rules-stage"+str(stage),true)
		game._action("close_wave_preview")
	game.current_stage = 1
	game.state.home_levels[0] = 1
	game.state.home_levels[1] = 1
	game._new_battle()
	game._action("confirm_loadout")
	var income_slot: int = plant_copy("tomato")
	game._action("battle_plot:%d" % income_slot)
	await audit("income-payback-early",true)
	game._action("close_battle_panel")
	game.battle.wave = 4
	game.battle.phase = "between"
	game._action("battle_plot:%d" % income_slot)
	await audit("income-payback-late",true)
	game._action("close_battle_panel")
	game.battle.phase = "running"
	game._action("battle_plot:%d" % income_slot)
	await audit("income-payback-current-wave",true)
	print("TEXT AUDIT ",checked," labels; ",failures," failures")
	game.queue_free()
	quit(1 if failures else 0)
