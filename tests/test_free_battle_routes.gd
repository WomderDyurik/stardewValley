extends SceneTree

const Routes = preload("res://scripts/battle_routes.gd")
const Placement = preload("res://scripts/battle_placement.gd")
const Layout = preload("res://scripts/field_layout.gd")
const Battle = preload("res://scripts/battle_sim.gd")
const State = preload("res://scripts/garden_state.gd")

# Feasible grid cells prove each authored meadow still leaves room for a long
# attempt's reinforcements without relying on obsolete arbitrary coordinates.
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func run() -> void:
	for stage in range(1,4):
		var path: Array[Vector2] = Routes.for_stage(stage)
		var length: float = 0.0
		for index in range(path.size()):
			expect(Layout.BOARD_RECT.grow(-Layout.ROAD_WIDTH/2.0).has_point(path[index]), "all of the actual road remains inside the field")
			if index == 0: continue
			var step: float = path[index-1].distance_to(path[index])
			length += step
			expect(step > 0 and step <= Routes.SAMPLE_SPACING + 0.02, "loops have continuous closely sampled movement without jumps")
			for other in range(index+2,path.size()):
				expect(Geometry2D.segment_intersects_segment(path[index-1],path[index],path[other-1],path[other]) == null, "the broad loop route never crosses itself")
		expect(length >= 1400.0 and length <= 1700.0, "loop length keeps approximately the previous session rhythm")
		expect(Layout.BOARD_RECT.encloses(Placement.greenhouse_bounds(path)), "the upright target greenhouse fits within the field")
		var occupied: Array[Vector2] = []
		for point in capacity_evidence(stage):
			expect(Placement.check(point,path,occupied)["valid"], "the actual full-footprint rule permits an eighteen-plant formation on stage " + str(stage))
			occupied.append(point)
		expect(occupied.size() >= 18, "each gridded meadow retains space for at least the original eighteen-plant formation")
		print("Loop stage ",stage,": length=",length,"; feasible full-size plants=",occupied.size())
	var fixed: Dictionary = strategy(false)
	var adaptive: Dictionary = strategy(true)
	expect(fixed["phase"] == "lost" and fixed["plants"] == 4, "a starter formation that never reinvests eventually loses")
	expect(adaptive["phase"] == "won" and adaptive["hp"] > 0 and adaptive["plants"] > 4, "the same zero-garden-coin opening can finish all five waves by buying free-position reinforcements")
	print("New-map starter strategies: fixed=",fixed,"; adaptive=",adaptive)
	print("Free battle routes: ",checks," checks; ",failures," failures")
	quit(0 if failures == 0 else 1)


func capacity_evidence(stage: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for point in Placement.grid_centers():
		if Placement.check(point,Routes.for_stage(stage),positions)["valid"]: positions.append(point)
	return positions


func strategy(adaptive: bool) -> Dictionary:
	var garden := State.new()
	garden.plant_plot("nursery",0,"nettle")
	garden.coins = 0
	var battle := Battle.new()
	var empty: Array[Vector2] = []
	var path: Array[Vector2] = Routes.for_stage(1)
	battle.configure(garden,path,empty,1)
	battle.select_loadout(["nettle"])
	battle.reward_rng.seed = 11247
	var positions: Array[Vector2] = []
	positions.assign(capacity_evidence(1))
	var scores: Dictionary = {}
	var attack_range: float = float(garden.plant_data("nettle",1)["range"])
	for point in positions:
		var covered: float = 0.0
		for index in range(1,path.size()):
			if point.distance_to(path[index]) <= attack_range:
				covered += path[index-1].distance_to(path[index])
		scores[point] = covered
	positions.sort_custom(func(a:Vector2,b:Vector2)->bool:return scores[a]>scores[b])
	for index in range(4): expect(battle.plant_at(positions[index],"nettle") >= 0, "the same four full-price opening cannons fit the ordinary 240-supply budget")
	expect(battle.supplies == 0 and garden.coins == 0, "the new loop opening never takes money from the garden")
	var next: int = 4
	for wave in range(5):
		if not battle.start_wave(): break
		var steps: int = 0
		while battle.phase == "running" and steps < 20000:
			battle.tick(0.05)
			if battle.phase in ["won","lost"]: break
			if adaptive and next < positions.size() and battle.supplies >= 60:
				expect(battle.plant_at(positions[next],"nettle") >= 0, "earned battle supplies buy another legal free-position cannon")
				next += 1
			steps += 1
		expect(steps < 20000, "a real authored wave finishes without empty waiting")
	return {"phase":battle.phase,"hp":battle.base_hp,"seconds":snappedf(battle.active_seconds,0.1),"plants":battle.plants.size(),"supplies":battle.supplies,"garden_coins":garden.coins}
