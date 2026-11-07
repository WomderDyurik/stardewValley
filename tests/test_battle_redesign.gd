extends SceneTree

## Presentation reads real costs, exact remaining spawns and legal coverage.
## None of these functions is allowed to advance or edit a saved attempt.
const State = preload("res://scripts/garden_state.gd")
const Battle = preload("res://scripts/battle_sim.gd")
const Routes = preload("res://scripts/battle_routes.gd")
const Placement = preload("res://scripts/battle_placement.gd")
const Encounter = preload("res://scripts/battle_encounter_art.gd")
const Presentation = preload("res://scripts/battle_presentation.gd")
const Field = preload("res://scripts/battle_field_art.gd")
const View = preload("res://scripts/battle_map_view.gd")
var checks: int = 0
var failures: int = 0


func expect(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(reason)


func _initialize() -> void:
	var profile_ids: Dictionary = {}
	for stage in range(1,4):
		var profile: Dictionary = Field.stage_profile(stage)
		expect(not profile_ids.has(profile["id"]),"each real campaign arena has a distinct landscape identity")
		profile_ids[profile["id"]] = true
		var garden := State.new()
		garden.coins = 10000
		garden.plant_plot("nursery",0,"nettle")
		var battle := Battle.new()
		var empty: Array[Vector2] = []
		battle.configure(garden,Routes.for_stage(stage),empty,stage)
		var projected: Array[Vector2] = View.project_route(battle.path_points())
		var protected: Array[Rect2] = Field.protected_ground(View.BOARD,projected)
		var road_art: Dictionary = Field._road_geometry(View.BOARD,projected)
		for stone in road_art["stones"]:
			expect(not Geometry2D.triangulate_polygon(stone["polygon"]).is_empty(),"every rendered paving stone triangulates")
			for fragment in stone["facets"]+stone["minerals"]:
				expect(not Geometry2D.triangulate_polygon(fragment["polygon"]).is_empty(),"clipped stone light and shadow planes never become degenerate draw commands")
		var stream: PackedVector2Array = Field.stream_outline(View.BOARD,projected,protected)
		expect(not Geometry2D.triangulate_polygon(stream).is_empty(),"each arena has a drawable continuous stream margin")
		expect(Geometry2D.is_point_in_polygon(projected[0]+View.BOARD.position,stream),"the real entry crosses the stream at the wooden bridge")
		for cell in protected:
			var polygon := PackedVector2Array([cell.position,Vector2(cell.end.x,cell.position.y),cell.end,Vector2(cell.position.x,cell.end.y)])
			expect(Geometry2D.intersect_polygons(polygon,stream).is_empty(),"physical water never covers any legal complete plant footprint")
		var before: Dictionary = battle.export_snapshot()
		var readout: Dictionary = Encounter.battle_readout(battle)
		expect(readout["title"].contains("Выберите") and Encounter.coverage_hints(battle).is_empty(),"before composition the next task is selection, not a phantom placement")
		expect(before==battle.export_snapshot(),"reading an uncommitted attempt cannot mutate it")
		battle.select_loadout(["nettle","tomato"])
		before = battle.export_snapshot()
		readout = Encounter.battle_readout(battle)
		expect(readout["defenders"]==0 and readout["cheapest_defender"]["kind"]=="nettle" and readout["detail"].contains("60"),"first task names an actually grown affordable defender at its actual price")
		var hints: Array[Dictionary] = Encounter.coverage_hints(battle)
		expect(hints.size()>0 and hints.size()<=2,"preparation shows one or two useful positions, not a field full of flashing cells")
		for hint in hints:
			expect(battle.placement_check(hint["position"],hint["kind"])["valid"],"suggested coverage is genuinely plantable for that saved route and budget")
			expect(float(hint["coverage"])>float(hint["range"])*1.3,"suggested cells actually cover a useful length of the real path")
			var cell: Rect2 = View.cell_at(hint["position"])
			cell.position += View.BOARD.position
			expect(View.BOARD.encloses(cell),"the full suggested cell stays within the real portrait board")
		expect(Encounter.coverage_hints(battle,"tomato").is_empty(),"income plants do not receive invented combat coverage bonuses")
		expect(before==battle.export_snapshot(),"objectives, preparation text and coverage queries leave saves unchanged")
		var at: Vector2 = hints[0]["position"]
		expect(battle.plant_at(at,"nettle")>=0,"the first highlighted position accepts the real full-price planting")
		expect(Encounter.battle_readout(battle)["defenders"]==1,"preparation immediately recognises a real planted defender")
		for hint in Encounter.coverage_hints(battle): expect(hint["position"]!=at,"a purchased cell disappears from optional position hints")
		var budget: int = battle.supplies
		battle.supplies = 0
		expect(Encounter.coverage_hints(battle).is_empty() and Encounter.battle_readout(battle,"nettle")["title"].contains("не хватает"),"hints and instruction never promise an unaffordable installation")
		battle.supplies = budget
		var second_hints: Array[Dictionary] = Encounter.coverage_hints(battle)
		expect(not second_hints.is_empty(),"the first purchase still leaves a real affordable second line")
		if not second_hints.is_empty():
			expect(battle.plant_at(second_hints[0]["position"],"nettle")>=0,"the second suggested defender is purchased at the full price")
		readout = Encounter.battle_readout(battle)
		expect(readout["defenders"]==2 and battle.supplies==120 and readout["available_defenders"]==2,"two paid defenders leave a factual reserve for two more, not a promise of winning with two")
		expect(readout["detail"].contains("усиливайте"),"preparation explicitly teaches reinvestment during the wave")
		expect(battle.start_wave(),"the ordinary purchased formation starts the unchanged authored wave")
		var plan: Dictionary = battle.preview_wave()
		expect(Encounter.remaining_counts(battle)==plan["counts"],"before the first spawn the forecast equals the exact authored enemy mix")
		for step in range(300): battle.tick(0.05)
		before = battle.export_snapshot()
		readout = Encounter.battle_readout(battle)
		var remaining: Dictionary = Encounter.remaining_counts(battle)
		var sum: int = 0
		for count in remaining.values(): sum+=int(count)
		expect(sum==battle.enemies.size()+battle.enemy_total-battle.spawned,"live forecast counts exactly the surviving attackers plus not-yet-spawned queue")
		expect(readout["living"]==battle.enemies.size() and readout["queued"]==battle.enemy_total-battle.spawned,"local pressure reports actual live and queued counts")
		expect(readout["resolved"]==battle.spawned-battle.enemies.size(),"progress counts actual resolved attackers rather than elapsed animation time")
		expect(Encounter.coverage_hints(battle).is_empty(),"optional planning marks do not distract from live combat")
		expect(before==battle.export_snapshot(),"live forecast and combat readout do not spend, reward or advance time")
		battle.paused = true
		expect(Encounter.battle_readout(battle)["title"].contains("Пауза"),"a paused attempt names its actual state")
	# A genuine version-two attempt created on the former mirrored second
	# arena keeps that exact geometry when a new attempt would use a new route.
	var saved_state := State.new()
	saved_state.coins=10000
	saved_state.claim_stage_reward(1)
	saved_state.plant_plot("nursery",0,"nettle")
	var previous_path: Array[Vector2] = []
	for at in Routes.for_stage(1): previous_path.append(Vector2(at.x,430-at.y))
	var no_anchors: Array[Vector2] = []
	var old_attempt := Battle.new()
	old_attempt.configure(saved_state,previous_path,no_anchors,2)
	old_attempt.select_loadout(["nettle"])
	for at in Placement.grid_centers():
		if old_attempt.placement_check(at,"nettle")["valid"]:
			old_attempt.plant_at(at,"nettle")
			break
	old_attempt.start_wave()
	for step in range(60): old_attempt.tick(1.0/60.0)
	var snapshot: Dictionary = old_attempt.export_snapshot()
	var resumed := Battle.new()
	expect(resumed.restore_snapshot(saved_state,Routes.for_stage(2),no_anchors,snapshot),"a current version-two checkpoint resumes after the new arena route changes")
	if resumed.state!=null:
		expect(resumed.path_points()==previous_path and resumed.path_points()!=Routes.for_stage(2),"resuming never projects living enemies onto the new route")
		old_attempt.paused=true
		expect(resumed.export_snapshot()==old_attempt.export_snapshot(),"restoring old arena geometry keeps every counter, attacker, weapon, source and RNG value")
		old_attempt.paused=false
		resumed.paused=false
		for step in range(120):
			old_attempt.tick(1.0/60.0)
			resumed.tick(1.0/60.0)
		expect(resumed.export_snapshot()==old_attempt.export_snapshot(),"the restored former arena advances identically under unchanged battle rules")

	print("Battle redesign: ",checks," checks; ",failures," failures")
	quit(0 if failures==0 else 1)
