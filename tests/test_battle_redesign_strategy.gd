extends SceneTree

## New arena silhouettes retain honest tactical wins with the original budget.
const State = preload("res://scripts/garden_state.gd")
const Battle = preload("res://scripts/battle_sim.gd")
const Routes = preload("res://scripts/battle_routes.gd")
const Placement = preload("res://scripts/battle_placement.gd")
var checks: int = 0
var failures: int = 0


func expect(value: bool, reason: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(reason)


func strategy(stage: int, adaptive: bool, speed: float = 1.0) -> Dictionary:
	var state := State.new()
	state.plant_plot("nursery",0,"nettle")
	state.nursery_levels[0] = 3 if stage==3 else 1
	state.coins = 0
	for victory in range(1,stage): state.claim_stage_reward(victory)
	var battle := Battle.new()
	var empty: Array[Vector2] = []
	var path: Array[Vector2] = Routes.for_stage(stage)
	battle.configure(state,path,empty,stage)
	battle.select_loadout(["nettle"])
	battle.reward_rng.seed = 11247
	battle.speed = speed
	var positions: Array[Vector2] = []
	for at in Placement.grid_centers():
		if Placement.check(at,path,positions)["valid"]: positions.append(at)
	var scores: Dictionary = {}
	var attack_range: float = float(state.plant_data("nettle",state.nursery_levels[0])["range"])
	for at in positions:
		var coverage: float = 0.0
		for index in range(1,path.size()):
			if at.distance_to(path[index])<=attack_range: coverage+=path[index-1].distance_to(path[index])
		scores[at]=coverage
	positions.sort_custom(func(a:Vector2,b:Vector2)->bool:return scores[a]>scores[b])
	for index in range(4): expect(battle.plant_at(positions[index],"nettle")>=0,"the same 240 supplies buy four legal starting cannons")
	expect(battle.supplies==0 and state.coins==0,"the new arena takes no permanent garden money")
	var next: int = 4
	for wave in range(5):
		if not battle.start_wave(): break
		var steps: int = 0
		while battle.phase=="running" and steps<24000:
			battle.tick(0.05)
			if battle.phase in ["won","lost"]: break
			if adaptive and next<positions.size() and battle.supplies>=60:
				expect(battle.plant_at(positions[next],"nettle")>=0,"earned supplies buy an actual legal reinforcement")
				next+=1
			steps+=1
		expect(steps<24000,"the authored wave ends without an unbounded wait")
	return {"phase":battle.phase,"hp":battle.base_hp,"plants":battle.plants.size(),"supplies":battle.supplies,"seconds":snappedf(battle.active_seconds,0.1),"coins":state.coins}


func _initialize() -> void:
	var signatures: Dictionary = {}
	for stage in range(1,4):
		var path: Array[Vector2] = Routes.for_stage(stage)
		var key: int = hash(path)
		expect(not signatures.has(key),"three new attempts use three different actual tactical routes")
		signatures[key]=true
		var result: Dictionary = strategy(stage,true)
		expect(result["phase"]=="won" and result["hp"]>0 and result["plants"]>4,"an accessible adaptive strategy wins each real route using the ordinary budget")
		print("Redesigned arena ",stage,": ",result)
	var fixed: Dictionary = strategy(1,false)
	expect(fixed["phase"]=="lost","the same opening needs reinvestment rather than unattended waiting")
	print("Battle redesigned strategy: ",checks," checks; ",failures," failures")
	quit(0 if failures==0 else 1)
