extends "res://tests/capture_planting_reference.gd"

## Art-only isolated previews. Every stalk derives from a real fixture slot.
func configure(label: String) -> void:
	game.state = StateScript.new()
	for stage in range(1,4): game.state.claim_stage_reward(stage)
	game.state.coins = 1000000
	game.state.home_plots.fill("")
	game.state.nursery_plots.fill("")
	game.state.pond_plots.fill("")
	if label == "empty": return
	var crops := ["tomato","cucumber","marigold","strawberry","currant","mint","pumpkin"]
	for slot in range(game.state.home_plots.size()):
		game.state.home_plots[slot] = crops[slot%crops.size()]
		game.state.home_levels[slot] = [1,7,15][slot%3]
	for slot in range(game.state.nursery_plots.size()):
		game.state.nursery_plots[slot] = ["nettle","lavender","pepper"][slot%3]
		game.state.nursery_levels[slot] = [1,7,15][slot%3]
	for slot in range(game.state.pond_plots.size()):
		game.state.pond_plots[slot] = "waterlily" if slot%2==0 else "lotus"
		game.state.pond_levels[slot] = [1,7,15][slot%3]
	game.state.home_ready = true
	game.state.home_elapsed = game.state.home_cycle()


func run() -> void:
	prefix = "large-landscape"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="): prefix = arg.trim_prefix("--prefix=")
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_process(false)
	await create_timer(0.2).timeout
	for state_name in ["empty","full"]:
		configure(state_name)
		await capture(state_name+"-garden","garden",0.6)
		await capture(state_name+"-nursery","nursery",0.6)
		await capture(state_name+"-nursery-barn","nursery",0.6,Vector2(2112,688))
		await capture(state_name+"-greenhouse","greenhouse",0.85)
	configure("full")
	await capture("full-water","pond",0.8)
	await capture("full-garden-min","garden",0.5,Vector2(768,864))
	await capture("full-nursery-min","nursery",0.5,Vector2(2496,768))
	print("Large landscape capture: ",captures," frames; issues=",errors)
	game.queue_free()
	quit(0 if errors.is_empty() else 1)
