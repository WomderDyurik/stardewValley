extends Node2D

## A portrait, touch-first prototype. UI and world share a 540 × 960 canvas.
const State = preload("res://scripts/garden_state.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Missions = preload("res://scripts/campaign.gd")
const Battle = preload("res://scripts/battle_sim.gd")
const Layout = preload("res://scripts/field_layout.gd")
const BattleView = preload("res://scripts/battle_map_view.gd")
const BattleRoutes = preload("res://scripts/battle_routes.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const FarmUi = preload("res://scripts/garden_farm_ui.gd")
const BattleField = preload("res://scripts/battle_field_art.gd")
const GardenMap = preload("res://scripts/garden_world.gd")
const Visuals = preload("res://scripts/plant_visuals.gd")
const Menus = preload("res://scripts/plant_menus.gd")
const HelperArt = preload("res://scripts/garden_helper_visuals.gd")
const HelperMenus = preload("res://scripts/garden_helper_menus.gd")
const BattleUI = preload("res://scripts/battle_presentation.gd")
const Encounter = preload("res://scripts/battle_encounter_art.gd")
const GardenExperience = preload("res://scripts/garden_experience.gd")
const FeelAudio = preload("res://scripts/game_feel_audio.gd")
const Placement = preload("res://scripts/battle_placement.gd")
const Clip = preload("res://scripts/canvas_clip.gd")
const EnemyDirector = preload("res://scripts/battle_director.gd")
const LEAFROLLER_GUARD = preload("res://assets/pixel/battle_enemies/leafroller_guard.tres")
const GARDEN_SCENE = preload("res://scenes/garden.tscn")
const DEFENSE_SCENE = preload("res://scenes/defense.tscn")
const BODY_FONT = preload("res://assets/fonts/NunitoSans.ttf")
const WORLD = preload("res://assets/pixel/world.png")
const FARM_ART = {
	"cottage": preload("res://assets/pixel/reference_farm/cottage.png"),
	"chest": preload("res://assets/pixel/reference_farm/chest.png"),
	"scarecrow": preload("res://assets/pixel/reference_farm/scarecrow.png"),
	"caretaker": preload("res://assets/pixel/reference_farm/caretaker.png"),
	"sprinkler": preload("res://assets/pixel/reference_farm/sprinkler.png"),
	"nursery": preload("res://assets/pixel/nursery_reference/barn.png"),
	"nursery_fence": preload("res://assets/pixel/nursery_reference/fence.png"),
	"nursery_hen": preload("res://assets/pixel/nursery_reference/hen.png"),
	"nursery_lantern": preload("res://assets/pixel/nursery_reference/lantern.png"),
	"greenhouse": preload("res://assets/pixel/valley_environment/greenhouse.tres"),
	"tree_round": preload("res://assets/pixel/reference_farm/oak.png"),
	"tree_pink": preload("res://assets/pixel/valley_environment/tree_pink.tres"),
	"tree_pine": preload("res://assets/pixel/valley_environment/tree_pine.tres"),
	"bush": preload("res://assets/pixel/valley_environment/bush.tres"),
	"fence": preload("res://assets/pixel/valley_environment/fence.tres"),
	"barrel": preload("res://assets/pixel/valley_environment/barrel.tres"),
	"well": preload("res://assets/pixel/valley_environment/well.tres"),
	"mailbox": preload("res://assets/pixel/reference_farm/mailbox.png"),
	"bench": preload("res://assets/pixel/valley_environment/bench.tres"),
	"ground_grass": preload("res://assets/pixel/valley_environment/ground_grass.tres"),
	"ground_grass_dark": preload("res://assets/pixel/valley_environment/ground_grass_dark.tres"),
	"ground_earth": preload("res://assets/pixel/valley_environment/ground_earth.tres"),
	"ground_soil": preload("res://assets/pixel/valley_environment/ground_soil.tres"),
	"ground_path": preload("res://assets/pixel/valley_environment/ground_path.tres"),
	"ground_water": preload("res://assets/pixel/valley_environment/ground_water.tres"),
	"ground_stone": preload("res://assets/pixel/valley_environment/ground_stone.tres"),
	"ground_flower_grass": preload("res://assets/pixel/valley_environment/ground_flower_grass.tres"),
	"tree": preload("res://assets/pixel/valley_environment/tree_round.tres"),
	"apple_tree": preload("res://assets/pixel/valley_environment/tree_round.tres"),
	"flower_bush": preload("res://assets/pixel/valley_environment/bush.tres"),
}

const SCENERY = {
	"bush": preload("res://assets/pixel/scenery/bush.tres"),
	"daisies": preload("res://assets/pixel/scenery/daisies.tres"),
	"mushrooms": preload("res://assets/pixel/scenery/mushrooms.tres"),
	"barrel": preload("res://assets/pixel/scenery/barrel.tres"),
	"rocks": preload("res://assets/pixel/scenery/rocks.tres"),
	"butterfly": preload("res://assets/pixel/scenery/butterfly.tres"),
	"bench": preload("res://assets/pixel/scenery/bench.tres"),
}
const PAPER = UiTheme.PAPER
const INK = UiTheme.INK
const MUTED = UiTheme.MUTED
const GREEN = UiTheme.GREEN
const LIGHT = UiTheme.LIGHT
const LINE = UiTheme.LINE
const GOLD = UiTheme.GOLD
const BOARD = BattleView.BOARD
# Keep the broad farmhouse facade visible; the overview sits above navigation.
const MINIMAP_RECT = Rect2(434, 688, 88, 124)
const MINIMAP_INNER = Rect2(442, 696, 72, 108)
const GARDEN_OCCLUDERS: Array[Rect2] = [MINIMAP_RECT,Rect2(24,814,290,60)]
const PLANT_ART = {
	"cucumber": preload("res://assets/pixel/botanical_refresh/cucumber.tres"),
	"strawberry": preload("res://assets/pixel/botanical_refresh/strawberry.tres"),
	"currant": preload("res://assets/pixel/botanical_refresh/currant.tres"),
	"mint": preload("res://assets/pixel/botanical_refresh/mint.tres"),
	"waterlily": preload("res://assets/pixel/botanical_refresh/waterlily.tres"),
	"lotus": preload("res://assets/pixel/botanical_refresh/lotus_1.tres"),
	"tomato": preload("res://assets/pixel/botanical_refresh/tomato.tres"),
	"pumpkin": preload("res://assets/pixel/botanical_refresh/pumpkin.tres"),
	"marigold": preload("res://assets/pixel/botanical_refresh/marigold.tres"),
	"nettle": preload("res://assets/pixel/botanical_refresh/nettle_1.tres"),
	"lavender": preload("res://assets/pixel/botanical_refresh/lavender_1.tres"),
	"pepper": preload("res://assets/pixel/botanical_refresh/pepper_1.tres"),
}

const BUG_ART = {
	"whitefly": preload("res://assets/pixel/battle_enemies/whitefly.tres"),
	"leafroller": preload("res://assets/pixel/battle_enemies/leafroller.tres"),
	"wireworm": preload("res://assets/pixel/battle_enemies/wireworm.tres"),

	"healer": preload("res://assets/pixel/battle_enemies/healer.tres"),
	"burrower": preload("res://assets/pixel/battle_enemies/burrower.tres"),
	"soldier": preload("res://assets/pixel/battle_enemies/soldier.tres"),

	"aphid": preload("res://assets/pixel/battle_enemies/aphid.tres"),
	"locust": preload("res://assets/pixel/battle_enemies/locust.tres"),
	"queen": preload("res://assets/pixel/battle_enemies/queen.tres"),

	"beetle": preload("res://assets/pixel/beetle.tres"),
	"snail": preload("res://assets/pixel/battle_enemies/snail.tres"),
}
const HOUSE = preload("res://assets/pixel/greenhouse.tres")
const CAN = preload("res://assets/pixel/watering_can.tres")

var state: GardenState
var battle: BattleSim
var screen: String = "home"
var active_view: Node
var current_stage: int = 1
var elapsed: float = 0.0
var toast_text: String = ""
var toast_time: float = 0.0
var help_open: bool = false
var stage_open: bool = false
var result_open: bool = false
var wave_guide_open: bool = false
var wave_guide_tab: String = "waves"
var enemy_guide_page: int = 0
var enemy_guide_category: String = "all"
var result_delay: float = 0.0
var coin_popups: Array[Dictionary] = []
var text_layouts: Array[Dictionary] = []
var save_pending: bool = false
var save_clock: float = 0.0
var save_warning_shown: bool = false
var battle_play_seconds: float = 0.0
var capture_path: String = ""
var capture_battle: bool = false
var test_mode: bool = false
var font: Font
var bold: Font
var display_font: Font
var hitboxes: Array[Dictionary] = []
var plot_positions: Array[Vector2] = Layout.battle_plots()
var route: Array[Vector2] = Layout.battle_route()
var garden_world = GardenMap.new()
var home_panel: String = ""
var active_helper_id: String = "irrigation"
var garden_moments: Array[Dictionary] = []
var audio_enabled: bool = true
var _sound_players: Array[AudioStreamPlayer] = []
var _sound_cursor: int = 0
var _last_shot_sound: float = -1.0
var active_plot_area: String = ""
var active_plot_slot: int = -1
var battle_panel: String = ""
var active_battle_slot: int = -1
var quick_plant_kind: String = ""
var quick_plant_page: int = 0
var pending_battle_point := Vector2(INF, INF)
var _grid_route_key: int = 0
var _grid_cells: Array[Dictionary] = []
var battle_drag_kind: String = ""
var battle_drag_active: bool = false
var battle_drag_touch: bool = false
var battle_drag_finger := Vector2.ZERO
var battle_preview_point := Vector2(INF, INF)
var plant_page: int = 0
var seed_page: int = 0
var nursery_page: int = 0
var loadout_page: int = 0
var loadout_choices: Array[String] = []
var last_loadout: Array[String] = []
var touch_points: Dictionary = {}
var touch_map_allowed: Dictionary = {}
var pinch_active: bool = false
var pinch_midpoint: Vector2 = Vector2.ZERO
var pinch_distance: float = 0.0
var capture_district: String = "garden"
var pointer_down: bool = false
var pointer_start: Vector2 = Vector2.ZERO
var pointer_last: Vector2 = Vector2.ZERO
var pointer_can_pan: bool = false
var pointer_dragging: bool = false
var pending_hit: Dictionary = {}
var last_tap_point: Vector2 = Vector2.ZERO


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var readable_font: FontFile = BODY_FONT.duplicate()
	readable_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	readable_font.hinting = TextServer.HINTING_LIGHT
	var text_server: TextServer = TextServerManager.get_primary_interface()
	var weight_axis: int = text_server.name_to_tag("wght")
	var optical_axis: int = text_server.name_to_tag("opsz")
	var regular_face = FontVariation.new()
	regular_face.base_font = readable_font
	regular_face.variation_opentype = {weight_axis: 550.0, optical_axis: 12.0}
	var bold_face = FontVariation.new()
	bold_face.base_font = readable_font
	bold_face.variation_opentype = {weight_axis: 750.0, optical_axis: 12.0}
	font = regular_face
	bold = bold_face
	display_font = bold_face
	state = State.new()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-home="):
			capture_path = argument.trim_prefix("--capture-home=")
		elif argument.begins_with("--capture-battle="):
			capture_path = argument.trim_prefix("--capture-battle=")
			capture_battle = true
		elif argument.begins_with("--district="):
			capture_district = argument.trim_prefix("--district=")
	if capture_path.is_empty() and not test_mode:
		_load_garden()
	else:
		state.home_elapsed = state.home_cycle()
		state.home_ready = true
	state.changed.connect(_state_changed)
	if not test_mode and capture_path.is_empty():
		for index in range(4):
			var player := AudioStreamPlayer.new()
			player.volume_db = -20.0
			add_child(player)
			_sound_players.append(player)
	garden_world.focus_district(capture_district)
	current_stage = mini(state.completed_level + 1, Missions.COUNT)
	if capture_path.is_empty() and not test_mode:
		_restore_session()
	if capture_battle:
		screen = "battle"
		_new_battle()
		state.coins = 600
		state.plant_plot("nursery", 0, "nettle")
		state.plant_plot("nursery", 1, "nettle")
		battle.select_loadout(["tomato", "marigold", "nettle"])
		for kind in ["tomato", "nettle", "marigold", "nettle"]:
			var placed: bool = false
			for x in range(36, 461, 16):
				if placed: break
				for y in range(36, 399, 16):
					var point := Vector2(x, y)
					if battle.placement_check(point, kind)["valid"]:
						battle.plant_at(point, kind)
						placed = true
						break
		_sync_battle_geometry()
		battle.start_wave()
		for index in range(145):
			battle.tick(0.05)
	_show_screen(screen)
	if not capture_path.is_empty():
		_capture.call_deferred()
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	queue_redraw()


func _load_garden(path: String = "user://garden_save.json") -> bool:
	var restored: bool = state.load_game(path)
	if not restored:
		# Existing starter crops are ready only on a new visit. Loading a saved
		# garden preserves its exact timer, stock and ready flag.
		state.home_elapsed = state.home_cycle()
		state.home_ready = true
	return restored


func _process(delta: float) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var ratio: float = minf(viewport_size.x / 540.0, viewport_size.y / 960.0)
	scale = Vector2.ONE * ratio
	position = (viewport_size - Vector2(540, 960) * ratio) / 2.0
	var safe_delta: float = minf(delta, 0.2)
	elapsed += safe_delta
	toast_time = maxf(0.0, toast_time - safe_delta)
	for popup in coin_popups:
		popup["age"] += safe_delta
	coin_popups = coin_popups.filter(func(popup: Dictionary) -> bool: return popup["age"] < 1.65)
	if result_delay > 0.0:
		result_delay = maxf(0.0, result_delay - safe_delta)
		if result_delay == 0.0:
			result_open = true
	state.tick(safe_delta)
	if screen == "home" and not help_open and not stage_open and home_panel.is_empty():
		var direction = Vector2(
			float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)),
			float(Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W))
		)
		if direction.length_squared() > 0.0:
			_cancel_pointer()
			garden_world.pan_screen(-direction.normalized() * 360.0 * safe_delta)
	if battle != null and screen == "battle" and not help_open and not stage_open and not wave_guide_open and battle_panel.is_empty():
		if battle.phase == "running" and not battle.paused:
			battle_play_seconds += safe_delta
		battle.tick(safe_delta)
		if battle.phase == "running" and not battle.paused and elapsed-_last_shot_sound >= 0.18:
			for shot in battle.shots:
				if float(shot["life"]) > 0.12:
					_play_sound("shot")
					_last_shot_sound = elapsed
					break
	save_clock += safe_delta
	if battle != null and battle.phase == "running" and save_clock >= 10.0:
		save_pending = true
	if save_pending and save_clock > 0.8 and capture_path.is_empty() and not test_mode:
		_save()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if state != null and capture_path.is_empty() and not test_mode:
			_save()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		_cancel_gesture()
		if state != null and capture_path.is_empty() and not test_mode:
			_save()
		if battle != null:
			battle.paused = true


func _state_changed() -> void:
	save_pending = true


func _save(path: String = "user://garden_save.json") -> void:
	save_clock = 0.0
	save_pending = false
	state.session_data = {
		"version": 1,
		"world_layout": 3,
		"camera_center": garden_world.center,
		"camera_zoom": garden_world.zoom,
		"camera_context": garden_world.navigation_context(),
		"audio_enabled": audio_enabled,
		"last_loadout": last_loadout.duplicate(),
		"played_seconds": battle_play_seconds,
		"battle": battle.export_snapshot() if battle != null and battle.phase not in ["won", "lost"] else {},
	}
	if not state.save_game(path) and not save_warning_shown:
		save_warning_shown = true
		_toast("Не удалось сохранить прогресс на этом устройстве")


func _restore_session() -> void:
	var data: Dictionary = state.session_data
	if data.get("version", 0) != 1:
		return
	var at: Variant = data.get("camera_center")
	var zoom_value: Variant = data.get("camera_zoom")
	var camera_context: Variant = data.get("camera_context", {})
	if data.get("audio_enabled") is bool: audio_enabled = data["audio_enabled"]
	var saved_layout: int = int(data.get("world_layout",1))
	var focus: Variant = camera_context.get("focus",at) if camera_context is Dictionary else at
	if saved_layout < 2:
		# The original compact estate used different semantic camera regions.
		# Only camera context moves; battle sources and checkpoints stay intact.
		var destination: String = "garden"
		if focus is Vector2 and focus.is_finite():
			if focus.x >= 960 and focus.y < 768: destination = "nursery"
			elif focus.y >= 768 and focus.y < 1536: destination = "pond" if focus.x >= 960 else "greenhouse"
		garden_world.set_zoom(maxf(0.8,GardenMap.DEFAULT_ZOOM) if destination == "greenhouse" else GardenMap.DEFAULT_ZOOM)
		garden_world.focus_district(destination)
	elif saved_layout == 2 and focus is Vector2 and focus.is_finite() and (focus.y >= 1536 or Rect2(2688,1152,576,384).has_point(focus)):
		# Whole six-by-six blocks moved the workshop and pond farther south.
		# A player visiting one of those places should still arrive at that place.
		var destination: String = "greenhouse" if focus.y >= 1536 else "pond"
		garden_world.set_zoom(maxf(0.8,GardenMap.DEFAULT_ZOOM) if destination == "greenhouse" else GardenMap.DEFAULT_ZOOM)
		garden_world.focus_district(destination)
	else:
		# The northern fields retain their original world origin. Preserve their
		# existing panning and zoom, along with all current-layout camera states.
		if (zoom_value is float or zoom_value is int) and is_finite(float(zoom_value)):
			garden_world.set_zoom(float(zoom_value))
		if at is Vector2 and at.is_finite():
			garden_world.set_center(at)
		if camera_context is Dictionary:
			garden_world.restore_navigation_context(camera_context)
	var choices: Variant = data.get("last_loadout", [])
	if choices is Array:
		for kind in choices:
			if kind is String and Catalog.PLANTS.has(kind) and not last_loadout.has(kind):
				last_loadout.append(kind)
	var snapshot: Variant = data.get("battle", {})
	if not snapshot is Dictionary or snapshot.is_empty():
		return
	var candidate := Battle.new()
	if not candidate.restore_snapshot(state, route, plot_positions, snapshot):
		return
	battle = candidate
	_sync_battle_geometry()
	var played: Variant = data.get("played_seconds", 0.0)
	if (played is float or played is int) and is_finite(float(played)):
		battle_play_seconds = clampf(float(played), 0.0, 1000000.0)
	current_stage = battle.stage
	_connect_battle()
	loadout_choices.clear()
	for entry in battle.loadout:
		loadout_choices.append(str(entry["kind"]))
	_toast("Бой сохранён. Продолжите, когда будете готовы")


func _connect_battle() -> void:
	battle.coin_rewarded.connect(_coin_rewarded)
	battle.supplies_rewarded.connect(_supplies_rewarded)
	battle.notice.connect(_toast)
	battle.wave_finished.connect(_wave_finished)
	battle.battle_finished.connect(_battle_finished)
	battle.changed.connect(_state_changed)


func _new_battle() -> void:
	quick_plant_kind = ""
	quick_plant_page = 0
	active_battle_slot = -1
	wave_guide_open = false
	wave_guide_tab = "waves"
	enemy_guide_page = 0
	enemy_guide_category = "all"
	battle = Battle.new()
	route = BattleRoutes.for_stage(current_stage)
	plot_positions = []
	battle.configure(state, route, plot_positions, current_stage)
	pending_battle_point = Vector2(INF, INF)
	battle_play_seconds = 0.0
	coin_popups.clear()
	result_delay = 0.0
	_connect_battle()
	loadout_page = 0
	loadout_choices.clear()
	var options: Array[Dictionary] = battle.loadout_options()
	for entry in options:
		if last_loadout.has(entry["kind"]):
			loadout_choices.append(entry["kind"])
	if loadout_choices.is_empty():
		for entry in options:
			loadout_choices.append(entry["kind"])
	battle_panel = "loadout"
	result_open = false


func _wave_finished(income: int) -> void:
	_play_sound("wave_complete")
	_toast("Припасы: волна +%d · урожай +%d · всего +%d" % [battle.last_wave_reward.get("bonus", 0), battle.last_wave_reward.get("harvest", 0), income])
	save_pending = true


func _battle_finished(_won: bool) -> void:
	if _won: _play_sound("victory")
	_cancel_gesture()
	battle_panel = ""
	result_delay = 1.7 if _won and not coin_popups.is_empty() else 0.0
	result_open = result_delay == 0.0
	save_pending = true


func _toast(message: String) -> void:
	toast_text = message
	toast_time = 3.2


func _play_sound(kind: String) -> void:
	if not audio_enabled or test_mode or not capture_path.is_empty() or _sound_players.is_empty(): return
	var player: AudioStreamPlayer = _sound_players[_sound_cursor%_sound_players.size()]
	_sound_cursor += 1
	player.stop()
	player.stream = FeelAudio.stream(kind)
	player.volume_db = -30.0 if kind == "shot" else -20.0
	if player.stream != null: player.play()


func _show_screen(id: String) -> void:
	if id not in ["home", "battle"]:
		return
	if id == "home" and battle != null:
		battle.paused = true
	screen = id
	home_panel = ""
	battle_panel = "loadout" if id == "battle" and battle != null and not battle.loadout_ready else ""
	_cancel_gesture()
	text_layouts.clear()
	hitboxes.clear()
	if active_view != null:
		remove_child(active_view)
		active_view.queue_free()
	active_view = (GARDEN_SCENE if id == "home" else DEFENSE_SCENE).instantiate()
	add_child(active_view)
	queue_redraw()


func _go_back() -> void:
	if battle_drag_active:
		_cancel_gesture()
		queue_redraw()
		return
	_cancel_gesture()
	if wave_guide_open:
		wave_guide_open = false
	elif help_open:
		help_open = false
	elif not home_panel.is_empty():
		home_panel = ""
	elif battle_panel == "loadout" and battle != null and not battle.loadout_ready:
		_show_screen("home")
	elif not battle_panel.is_empty():
		battle_panel = ""
	elif stage_open:
		stage_open = false
	elif result_open:
		_action("result_home")
	elif screen == "battle":
		_show_screen("home")
	else:
		help_open = true
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_go_back()
		elif event.keycode == KEY_SPACE and screen == "battle" and not help_open and not result_open and not stage_open and not wave_guide_open and battle_panel.is_empty():
			_action("primary")
		return
	var point: Vector2 = Vector2.ZERO
	if event is InputEventMouseButton:
		point = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if _garden_gestures_enabled() and _map_point_available(point):
				_cancel_pointer()
				garden_world.zoom_at(1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12, point)
				get_viewport().set_input_as_handled()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_pointer_press(point)
		else:
			_pointer_release(point)
	elif event is InputEventMagnifyGesture:
		point = get_global_transform_with_canvas().affine_inverse() * event.position
		if _garden_gestures_enabled() and _map_point_available(point):
			_cancel_gesture()
			garden_world.zoom_at(event.factor, point)
	elif event is InputEventScreenTouch:
		point = get_global_transform_with_canvas().affine_inverse() * event.position
		_touch_event(event.index, point, event.pressed, event.canceled)
	elif event is InputEventScreenDrag:
		point = get_global_transform_with_canvas().affine_inverse() * event.position
		_touch_move(event.index, point)
	elif event is InputEventMouseMotion:
		point = get_global_transform_with_canvas().affine_inverse() * event.position
		if pointer_down and touch_points.is_empty():
			_pointer_move(point)
		elif _battle_input_enabled() and not quick_plant_kind.is_empty():
			battle_drag_finger = point
			battle_preview_point = BattleView.simulation_point(point) if BOARD.has_point(point) else Vector2(INF, INF)
			queue_redraw()
	else:
		return
	get_viewport().set_input_as_handled()


func _garden_gestures_enabled() -> bool:
	return screen == "home" and home_panel.is_empty() and not help_open and not stage_open


func _touch_event(index: int, point: Vector2, pressed: bool, canceled: bool) -> void:
	if canceled:
		_cancel_gesture()
		return
	if pressed:
		touch_points[index] = point
		touch_map_allowed[index] = _garden_gestures_enabled() and _map_point_available(point)
		if touch_points.size() == 1:
			_pointer_press(point)
		elif touch_points.size() == 2:
			_cancel_pointer()
			var keys: Array = touch_points.keys()
			pinch_active = bool(touch_map_allowed[keys[0]]) and bool(touch_map_allowed[keys[1]])
			pinch_midpoint = (touch_points[keys[0]] + touch_points[keys[1]]) / 2.0
			pinch_distance = touch_points[keys[0]].distance_to(touch_points[keys[1]])
		else:
			_cancel_pointer()
			pinch_active = false
	else:
		if not touch_points.has(index):
			return
		var was_multi: bool = touch_points.size() > 1 or pinch_active
		touch_points.erase(index)
		touch_map_allowed.erase(index)
		if was_multi:
			_cancel_pointer()
			pinch_active = false
		else:
			_pointer_release(point)
		if touch_points.is_empty():
			pinch_active = false


func _touch_move(index: int, point: Vector2) -> void:
	if not touch_points.has(index):
		return
	touch_points[index] = point
	if pinch_active and touch_points.size() == 2 and _garden_gestures_enabled():
		var keys: Array = touch_points.keys()
		var midpoint: Vector2 = (touch_points[keys[0]] + touch_points[keys[1]]) / 2.0
		var distance: float = touch_points[keys[0]].distance_to(touch_points[keys[1]])
		if pinch_distance > 8.0 and distance > 8.0:
			garden_world.zoom_at(distance / pinch_distance, pinch_midpoint)
			garden_world.pan_screen(midpoint - pinch_midpoint)
		pinch_midpoint = midpoint
		pinch_distance = distance
	elif touch_points.size() == 1 and pointer_down:
		_pointer_move(point)
	queue_redraw()


func _cancel_gesture() -> void:
	_cancel_pointer()
	touch_points.clear()
	touch_map_allowed.clear()
	pinch_active = false
	pinch_distance = 0.0


func _pointer_press(point: Vector2) -> void:
	pointer_down = true
	pointer_start = point
	pointer_last = point
	pointer_dragging = false
	pending_hit = {}
	for index in range(hitboxes.size() - 1, -1, -1):
		if bool(hitboxes[index].get("world", false)) and not _map_point_available(point):
			continue
		if hitboxes[index]["rect"].has_point(point):
			pending_hit = hitboxes[index].duplicate()
			break
	pointer_can_pan = _garden_gestures_enabled() and _map_point_available(point) and (pending_hit.is_empty() or bool(pending_hit.get("world", false)))
	battle_drag_kind = ""
	battle_drag_active = false
	battle_drag_touch = not touch_points.is_empty()
	battle_drag_finger = point
	battle_preview_point = Vector2(INF, INF)
	if _battle_input_enabled():
		var action: String = str(pending_hit.get("action", ""))
		if action.begins_with("battle_quick_select:"):
			battle_drag_kind = action.trim_prefix("battle_quick_select:")
		elif action == "battle_ground" and not quick_plant_kind.is_empty():
			battle_preview_point = BattleView.simulation_point(point)


func _map_point_available(point: Vector2) -> bool:
	if not GardenMap.MAP_VIEW.has_point(point):
		return false
	for cover in GARDEN_OCCLUDERS:
		if cover.has_point(point):
			return false
	return true


func _pointer_move(point: Vector2) -> void:
	if not pointer_down:
		return
	if not battle_drag_kind.is_empty() and _battle_input_enabled():
		if battle_drag_active or point.distance_to(pointer_start) >= 10.0:
			battle_drag_active = true
			pointer_dragging = true
			pending_hit = {}
			battle_drag_finger = point
			var lift := Vector2(0, -56) if battle_drag_touch else Vector2.ZERO
			battle_preview_point = BattleView.simulation_point(point + lift)
	elif _battle_input_enabled() and str(pending_hit.get("action", "")) == "battle_ground" and not quick_plant_kind.is_empty():
		battle_drag_finger = point
		battle_preview_point = BattleView.simulation_point(point)
	if pointer_can_pan:
		if pointer_dragging:
			garden_world.pan_screen(point - pointer_last)
		elif point.distance_to(pointer_start) >= 12.0:
			pointer_dragging = true
			pending_hit = {}
			garden_world.pan_screen(point - pointer_start)
	pointer_last = point
	queue_redraw()


func _pointer_release(point: Vector2) -> void:
	if not pointer_down:
		return
	_pointer_move(point)
	var chosen: Dictionary = pending_hit.duplicate()
	var dragging: bool = battle_drag_active
	var kind: String = battle_drag_kind
	var destination: Vector2 = battle_preview_point
	var activate: bool = not pointer_dragging and not chosen.is_empty() and chosen["rect"].has_point(point)
	_cancel_pointer()
	last_tap_point = point
	if dragging:
		if _battle_input_enabled() and BOARD.has_point(point) and destination.is_finite():
			_deploy_battle_at(destination, kind)
		queue_redraw()
	elif activate:
		_action(chosen["action"])


func _cancel_pointer() -> void:
	pointer_down = false
	pointer_can_pan = false
	pointer_dragging = false
	pending_hit = {}
	battle_drag_kind = ""
	battle_drag_active = false
	battle_preview_point = Vector2(INF, INF)


func _battle_input_enabled() -> bool:
	return screen == "battle" and battle != null and battle.loadout_ready and battle.phase not in ["won", "lost"] and battle_panel.is_empty() and not help_open and not stage_open and not result_open and not wave_guide_open


func _sync_battle_geometry() -> void:
	if battle == null: return
	route = battle.path_points()
	plot_positions = battle.plot_positions()


func _deploy_battle_at(point: Vector2, kind: String) -> bool:
	var slot: int = battle.plant_at(point, kind)
	if slot < 0: return false
	_sync_battle_geometry()
	active_battle_slot = slot
	quick_plant_kind = kind
	pending_battle_point = Vector2(INF, INF)
	battle_panel = ""
	return true


func get_battle_placement_preview() -> Dictionary:
	var kind: String = battle_drag_kind if battle_drag_active else quick_plant_kind
	if not _battle_input_enabled() or kind.is_empty() or not battle_preview_point.is_finite():
		return {"active":false}
	var check: Dictionary = battle.placement_check(battle_preview_point,kind)
	var position: Vector2 = check.get("position",battle_preview_point)
	var bounds: Rect2 = BattleView.cell_at(position)
	bounds.position += BOARD.position
	return {"active":true,"kind":kind,"finger":battle_drag_finger,"position":position,"cell":check.get("cell",Vector2i(-1,-1)),"valid":check["valid"],"reason":check["reason"],"rect":bounds}


func _action(action: String) -> void:
	_cancel_gesture()
	var parts: PackedStringArray = action.split(":")
	if wave_guide_open and parts[0] not in ["close_wave_preview", "battle_guide_tab", "enemy_guide_page", "enemy_group"]:
		return
	match parts[0]:
		"toggle_audio":
			audio_enabled = not audio_enabled
			save_pending = true
			if not audio_enabled:
				for player in _sound_players: player.stop()
			else: _play_sound("plant")
		"garden_journal":
			home_panel = "journal"
		"garden_goal":
			var goal: Dictionary = GardenExperience.next_goal(state)
			if goal["action"] == "garden_journal": home_panel = "journal"
			else:
				home_panel = ""
				_action(goal["action"])
		"grow_defender":
			_show_screen("home")
			garden_world.set_zoom(0.8)
			garden_world.focus_district("nursery")
			for slot in range(state.nursery_plots.size()):
				if state.plot_kind("nursery",slot).is_empty():
					_open_plot("nursery",slot)
					break
		"wave_preview":
			if battle != null:
				wave_guide_open = true
				wave_guide_tab = "waves"
				enemy_guide_page = 0
				enemy_guide_category = "all"
		"close_wave_preview":
			wave_guide_open = false
		"battle_guide_tab":
			if parts.size() == 2 and parts[1] in ["waves", "enemies", "rules"]:
				wave_guide_tab = parts[1]
		"enemy_guide_page":
			if parts.size() == 2:
				enemy_guide_page = BattleUI.guide_enemy_page(current_stage, enemy_guide_page + int(parts[1]), enemy_guide_category)["page"]
		"enemy_group":
			if parts.size() == 2 and (parts[1] == "all" or EnemyDirector.ENEMY_GROUPS.has(parts[1])):
				enemy_guide_category = parts[1]
				enemy_guide_page = 0
		"target_mode":
			if battle != null and parts.size() == 2:
				battle.set_target_mode(active_battle_slot, parts[1])
		"district":
			home_panel = ""
			if parts[1] == "greenhouse": garden_world.set_zoom(maxf(0.8,garden_world.zoom))
			garden_world.focus_district(parts[1])
		"open_districts":
			home_panel = "districts"
		"visit_pond":
			home_panel = ""
			garden_world.focus_district("pond")
		"helpers":
			home_panel = "helpers"
		"helper":
			if parts.size()==2 and state.Helpers.is_valid(parts[1]):
				active_helper_id = parts[1]
				home_panel = "helper_details"
		"upgrade_helper":
			if home_panel == "helper_details" and parts.size()==2 and parts[1]==active_helper_id and state.upgrade_helper(parts[1]):
				_toast("%s · уровень %d" % [state.Helpers.INFO[parts[1]]["name"],state.helper_level(parts[1])])
		"locate_helper":
			if parts.size()==2 and state.helper_level(parts[1])>0 and HelperArt.FRAMES.has(parts[1]):
				home_panel = ""
				garden_world.set_zoom(0.8)
				garden_world.set_center(HelperArt.FRAMES[parts[1]].get_center())
		"minimap":
			var ratio: Vector2 = (last_tap_point - MINIMAP_INNER.position) / MINIMAP_INNER.size
			garden_world.set_center(ratio.clamp(Vector2.ZERO, Vector2.ONE) * GardenMap.WORLD_SIZE)
		"campaign_board":
			_action("choose_stage")
		"nursery":
			nursery_page = 0
			home_panel = "nursery"
		"greenhouse":
			home_panel = "helpers"
		"close_home_panel":
			home_panel = ""
		"gate":
			_action("battle")
		"home":
			_show_screen("home")
		"battle":
			if (battle == null or battle.phase in ["won","lost"]) and GardenExperience.next_goal(state)["id"] == "first_defender":
				_action("grow_defender")
				_toast("Вырастите крапиву — она станет оружием для обороны")
				return
			if battle == null or battle.phase in ["won", "lost"]:
				stage_open = true
			else:
				_show_screen("battle")
		"choose_stage":
			if battle != null and not battle.plants.is_empty() and battle.phase not in ["won", "lost"]:
				_toast("Сначала завершите текущий бой")
			else:
				stage_open = true
		"stage":
			var choice: int = int(parts[1])
			if battle != null and not battle.plants.is_empty() and battle.phase not in ["won", "lost"]:
				_toast("Сначала завершите текущий бой")
				return
			if state.is_stage_unlocked(choice):
				current_stage = choice
				stage_open = false
				_new_battle()
				_show_screen("battle")
		"close_stage":
			stage_open = false
		"home_plot":
			_open_plot("home", int(parts[1]))
		"nursery_plot":
			_open_plot("nursery", int(parts[1]))
		"pond_plot":
			_open_plot("pond", int(parts[1]))
		"seed_page":
			if home_panel == "plant_picker": seed_page = maxi(0,seed_page+int(parts[1]))
		"nursery_page":
			if home_panel == "nursery": nursery_page = maxi(0,nursery_page+int(parts[1]))
		"loadout_page":
			loadout_page = maxi(0, loadout_page + int(parts[1]))
		"plant":
			if home_panel != "plant_picker" or active_plot_slot < 0:
				return
			var kind: String = parts[1]
			var existing: String = state.plot_kind(active_plot_area, active_plot_slot)
			var planted: bool = state.plant_plot(active_plot_area, active_plot_slot, kind) if existing.is_empty() else state.replace_plot(active_plot_area, active_plot_slot, kind)
			if planted:
				home_panel = "plot"
				_play_sound("plant")
				var point: Vector2 = GardenMap.plot_rect(active_plot_slot).get_center() if active_plot_area == "home" else GardenMap.nursery_plot_rect(active_plot_slot).get_center() if active_plot_area == "nursery" else GardenMap.pond_plot_rect(active_plot_slot).get_center()
				GardenExperience.note(self,"plant",point,"Новая жизнь")
				_toast("%s посажен. Уровень 1" % state.plant_data(kind, 1)["name"])
			else:
				_toast("Не хватает монет для этой посадки")
		"upgrade_plot":
			if home_panel == "plot" and state.upgrade_plot(active_plot_area, active_plot_slot):
				_toast("Посадка улучшена до уровня %d" % state.plot_level(active_plot_area, active_plot_slot))
		"change_plant":
			if home_panel == "plot":
				var choices: Array[String] = state.allowed_kinds(active_plot_area,active_plot_slot)
				seed_page = maxi(0,choices.find(state.plot_kind(active_plot_area,active_plot_slot))) / Menus.SEED_PAGE_SIZE
				home_panel = "plant_picker"
		"plot_back":
			home_panel = "plot" if not state.plot_kind(active_plot_area, active_plot_slot).is_empty() else ""
		"battle_ground":
			if not _battle_input_enabled(): return
			var point: Vector2 = BattleView.simulation_point(last_tap_point)
			var check: Dictionary = battle.placement_check(point)
			if not check["valid"]:
				_toast(check["reason"])
			elif not quick_plant_kind.is_empty():
				_deploy_battle_at(point,quick_plant_kind)
			else:
				pending_battle_point = check["position"]
				active_battle_slot = -1
				plant_page = 0
				battle_panel = "plant_picker"
		"battle_plot":
			if battle == null or battle.phase in ["won", "lost"] or parts.size()!=2: return
			var slot: int = int(parts[1])
			if slot < 0 or slot >= plot_positions.size(): return
			active_battle_slot = slot
			plant_page = 0
			if not battle.get_plant(slot).is_empty():
				pending_battle_point = Vector2(INF, INF)
				battle_panel = "inspect"
			else:
				pending_battle_point = plot_positions[slot]
				battle_panel = "plant_picker"
		"battle_quick_select":
			if battle == null or not battle.loadout_ready or battle.phase in ["won", "lost"] or not battle_panel.is_empty() or parts.size() != 2:
				return
			for entry in battle.loadout:
				if entry["kind"] == parts[1] and (quick_plant_kind == parts[1] or int(entry["cost"]) <= battle.supplies):
					quick_plant_kind = "" if quick_plant_kind == parts[1] else parts[1]
					active_battle_slot = -1
					break
		"battle_quick_page":
			if battle != null and battle.loadout_ready and parts.size() == 2:
				var pages: int = maxi(1, ceili(float(battle.loadout.size()) / 4.0))
				quick_plant_page = clampi(quick_plant_page + int(parts[1]), 0, pages - 1)
		"change_battle_plant":
			battle_panel = "plant_picker"
			plant_page = 0
		"loadout_toggle":
			if battle_panel != "loadout":
				return
			var kind: String = parts[1]
			if loadout_choices.has(kind):
				loadout_choices.erase(kind)
			else:
				for entry in battle.loadout_options():
					if entry["kind"] == kind:
						loadout_choices.append(kind)
		"confirm_loadout":
			var has_defense: bool = false
			for kind in loadout_choices:
				if Catalog.PLANTS.get(kind,{}).get("role","") == "defense": has_defense = true
			if battle_panel == "loadout" and not has_defense:
				_toast("Добавьте хотя бы одного защитника для теплицы")
				return
			if battle_panel == "loadout" and battle.select_loadout(loadout_choices):
				last_loadout.assign(loadout_choices)
				quick_plant_kind = ""
				quick_plant_page = 0
				battle_panel = ""
		"change_loadout":
			if battle != null and battle.phase == "preparing" and battle.plants.is_empty():
				battle_panel = "loadout"
		"loadout_back":
			if battle != null and battle.loadout_ready:
				battle_panel = ""
			else:
				battle = null
				_show_screen("home")
				stage_open = true
		"deploy":
			if battle_panel != "plant_picker" or parts.size() != 2:
				return
			var kind: String = parts[1]
			var success: bool = false
			if not battle.get_plant(active_battle_slot).is_empty():
				success = battle.replace_plant(active_battle_slot,kind)
			elif pending_battle_point.is_finite():
				success = _deploy_battle_at(pending_battle_point,kind)
			if success:
				battle_panel = ""
				pending_battle_point = Vector2(INF, INF)
		"battle_page":
			plant_page = maxi(0, plant_page + int(parts[1]))
		"close_battle_panel":
			if battle != null and not battle.loadout_ready:
				_show_screen("home")
			else:
				battle_panel = ""
		"manage_source":
			var placement: Dictionary = battle.get_plant(active_battle_slot)
			if not placement.is_empty():
				var source: PackedStringArray = String(placement["source_id"]).split(":")
				_show_screen("home")
				if source.size() == 2 and source[1].is_valid_int() and state.is_plot_unlocked(source[0],int(source[1])):
					garden_world.focus_district(state.plot_district(source[0], int(source[1])))
					_open_plot(source[0], int(source[1]))
				else:
					garden_world.focus_district("garden")
					_toast("Растение сохранено; его участок пока недоступен")
		"collect":
			var harvest: int = state.collect_home()
			if harvest > 0:
				_play_sound("harvest")
				GardenExperience.note(self,"harvest",GardenMap.COTTAGE_RECT.get_center(),"+%d монет" % harvest)
				_toast("Собрано +%d монет. Сад снова растёт" % harvest)
		"primary":
			if battle == null:
				return
			if battle.phase == "running":
				battle.paused = not battle.paused
			else:
				battle.start_wave()
		"speed":
			battle.speed = 2.0 if battle.speed < 2.0 else 1.0
		"retry":
			_new_battle()
		"next":
			current_stage = mini(current_stage + 1, Missions.COUNT)
			_new_battle()
		"result_home":
			result_open = false
			current_stage = mini(state.completed_level + 1, Missions.COUNT)
			battle = null
			_show_screen("home")
		"help":
			help_open = not help_open
	queue_redraw()


func _open_plot(area: String, slot: int) -> void:
	var count: int = state.plot_count(area)
	if slot < 0 or slot >= count:
		return
	if not state.is_plot_unlocked(area, slot):
		_toast("Это посадочное место пока недоступно")
		return
	active_plot_area = area
	active_plot_slot = slot
	seed_page = 0
	var cell: Rect2 = GardenMap.plot_rect(slot) if area == "home" else GardenMap.nursery_plot_rect(slot) if area == "nursery" else GardenMap.pond_plot_rect(slot)
	if cell.has_area():
		var projected := Rect2(garden_world.world_to_screen(cell.position),cell.size*garden_world.zoom)
		if not GardenMap.MAP_VIEW.encloses(projected): garden_world.set_center(cell.get_center())
	home_panel = "plant_picker" if state.plot_kind(area, slot).is_empty() else "plot"


func _draw() -> void:
	if state == null:
		return
	text_layouts.clear()
	hitboxes.clear()
	if screen == "battle": _sync_battle_geometry()
	draw_rect(Rect2(0,0,540,960),Color("416334"))
	if screen == "home":
		draw_texture_rect(WORLD, Rect2(0, 0, 540, 960), false)
	else:
		draw_rect(Rect2(0, 0, 540, 960), Color("42673c"))
	_draw_landscape()
	if active_view != null:
		active_view.render(self)
	if screen == "battle":
		_draw_coin_popups()
	if toast_time > 0.0 and not result_open and not help_open and not stage_open and home_panel.is_empty() and battle_panel.is_empty() and not wave_guide_open:
		var banner := Rect2(28, 690, 484, 45) if screen == "battle" else Rect2(30, 161, 480, 43)
		_box(banner, GREEN, 12)
		_center(banner, toast_text, 14, Color.WHITE, bold)
	if result_open and screen == "battle" and battle != null:
		_draw_result()
	if stage_open:
		_draw_stage_picker()
	if screen == "home" and not home_panel.is_empty():
		if home_panel in ["helpers","helper_details"]: HelperMenus.draw(self)
		elif home_panel == "journal": GardenExperience.draw_journal(self)
		else: Menus.draw_home(self)
	if screen == "battle" and not battle_panel.is_empty() and not result_open:
		Menus.draw_battle(self)
	if wave_guide_open and screen == "battle":
		BattleUI.draw_wave_guide(self)
	if help_open:
		_draw_help()


func _draw_landscape() -> void:
	if screen == "battle":
		BattleField.draw(self, BOARD, BattleView.project_route(route), elapsed)


func battle_to_screen(point: Vector2) -> Vector2:
	return BattleView.screen_point(point)


func battle_view_scale() -> float:
	return BattleView.SCALE


func _draw_header() -> void:
	FarmUi.header(self)


func _draw_defense_header() -> void:
	BattleUI.draw_header(self)


func _draw_battle() -> void:
	if battle == null:
		return
	_draw_field()
	BattleUI.draw_footer(self)


func _draw_field() -> void:
	# These are the same curved samples used by the enemy simulation.
	BattleUI.draw_range(self)
	_draw_battle_grid()
	Encounter.draw_tactical_ground(self)
	if _battle_input_enabled(): _hit(BOARD, "battle_ground")
	for placement in battle.plants:
		var index: int = int(placement["slot"])
		var local_footprint: Rect2 = BattleView.footprint_at(plot_positions[index])
		var footprint = Rect2(BOARD.position + local_footprint.position, local_footprint.size)
		var plant: Dictionary = battle.get_plant(index)
		if not plant.is_empty():
			var kind: String = plant["kind"]
			var level: int = int(plant.get("level", 1))
			var local_sprite: Rect2 = BattleView.sprite_at(plot_positions[index])
			var sprite = Rect2(BOARD.position + local_sprite.position, local_sprite.size)
			# Every occupied cell contains one upright plant, including income.
			for shot in battle.shots:
				if shot["from"] == plot_positions[index] and shot["kind"] == kind:
					sprite.position += Vector2(-1, 1)
			Visuals.draw(self, PLANT_ART[kind], sprite, kind, level, false, true)
			var badge: Rect2 = BattleView.badge_at(plot_positions[index])
			badge.position += BOARD.position
			draw_rect(badge, Color("e7d89e"))
			_level_label(badge,level,INK)
		if not plant.is_empty() and float(plant.get("jammed", 0.0)) > 0.0:
			_draw_root_jam(footprint)
		if battle.loadout_ready and battle.phase not in ["won", "lost"]:
			_hit(footprint, "battle_plot:%d" % index)
	for enemy in battle.enemies:
		_draw_enemy(enemy)
	for shot in battle.shots:
		var slot: int = plot_positions.find(shot["from"])
		if slot < 0:
			continue
		var local_sprite: Rect2 = BattleView.sprite_at(plot_positions[slot])
		var bounds = Rect2(BOARD.position + local_sprite.position + Vector2(-1, 1), local_sprite.size)
		var kind: String = shot["kind"]
		var muzzles: Array[Vector2] = Visuals.weapon_muzzles(kind, int(shot.get("level", 1)), bounds)
		var target: Vector2 = battle_to_screen(shot["to"])
		var color: Color = Color("d1e684") if kind == "nettle" else Color("be9de1") if kind == "lavender" else Color("90e5e1") if kind == "lotus" else Color("f6953e")
		var progress: float = clampf(1.0 - float(shot["life"]) / 0.17, 0.0, 1.0)
		for origin in muzzles:
			var pellet: Vector2 = origin.lerp(target, progress).floor()
			Clip.draw_rect(self,Rect2(pellet-Vector2(2,2),Vector2(5,5)),BOARD,Color("604127"))
			Clip.draw_rect(self,Rect2(pellet-Vector2(1,1),Vector2(3,3)),BOARD,color)
			if float(shot["life"]) > 0.11:
				Clip.draw_rect(self,Rect2(origin-Vector2(4,1),Vector2(9,3)),BOARD,Color("ffe8a3"))
				Clip.draw_rect(self,Rect2(origin-Vector2(1,4),Vector2(3,9)),BOARD,Color("ffe8a3"))
		if kind == "pepper" and progress > 0.65:
			for offset in [Vector2(-8, -4), Vector2(4, -7), Vector2(6, 6)]:
				Clip.draw_rect(self,Rect2(target+offset,Vector2(4,4)),BOARD,color)
	Encounter.draw_impacts(self)
	var house: Rect2 = BattleView.house_for_route(route)
	house.position += BOARD.position
	_sprite(FARM_ART["greenhouse"], house)
	Encounter.draw_objectives(self)
	_draw_battle_placement_preview()


func _draw_battle_grid() -> void:
	var key: int = hash([route,Placement.GRID_STEP,Placement.FOOTPRINT_SIZE])
	if key!=_grid_route_key or _grid_cells.is_empty():
		_grid_route_key=key
		_grid_cells.clear()
		var empty: Array[Vector2] = []
		for point in Placement.grid_centers():
			if not Placement.check(point,route,empty)["valid"]: continue
			var rect: Rect2 = BattleView.cell_at(point)
			rect.position+=BOARD.position
			if BOARD.encloses(rect): _grid_cells.append({"position":point,"rect":rect.grow(-1)})
	var selecting: bool = _battle_input_enabled() and (battle_drag_active or not quick_plant_kind.is_empty())
	for cell in _grid_cells:
		var occupied: bool = false
		for plant in battle.plants:
			if Placement.footprint(plot_positions[int(plant["slot"])]).grow(Placement.PLANT_GAP).intersects(Placement.footprint(cell["position"])):
				occupied=true
				break
		if occupied: continue
		var rect: Rect2 = cell["rect"]
		var a: Vector2 = rect.position
		var b := Vector2(rect.end.x,rect.position.y)
		var c: Vector2 = rect.end
		var d := Vector2(rect.position.x,rect.end.y)
		var tick: float = 7.0
		var points := PackedVector2Array([a+Vector2(0,tick),a,a,a+Vector2(tick,0),b-Vector2(tick,0),b,b,b+Vector2(0,tick),c-Vector2(0,tick),c,c,c-Vector2(tick,0),d+Vector2(tick,0),d,d,d-Vector2(0,tick)])
		draw_multiline(points,Color(0.20,0.36,0.17,0.31 if selecting else 0.16),1.0,false)
	if battle.paused and battle.phase == "running":
		_box(Rect2(195, 431, 150, 45), PAPER, 0)
		_center(Rect2(195, 431, 150, 45), "Пауза", 24, INK, bold)


func _draw_enemy(enemy: Dictionary) -> void:
	var center: Vector2 = battle_to_screen(enemy["position"])
	var texture: Texture2D = LEAFROLLER_GUARD if float(enemy.get("leaf_shield", 0.0)) > 0.0 else BUG_ART.get(enemy["kind"], BUG_ART["beetle"])
	var lift: float = 6.0 if enemy.get("mobility", "ground") == "air" or enemy["kind"] == "whitefly" else 0.0
	var enraged: bool = bool(enemy.get("enraged", false))
	var hidden: bool = bool(enemy.get("burrowed", false))
	var bob: float = floor(sin(elapsed * (21 if enraged else 13) + float(enemy["id"])) * 1.2)
	var heal_pulse: float = float(enemy.get("heal_pulse", 0.0))
	if heal_pulse > 0.0:
		var progress: float = 1.0 - clampf(heal_pulse / 0.35, 0.0, 1.0)
		_enemy_pulse(center, lerpf(30, float(enemy.get("heal_radius", 72.0)), progress) * BattleView.SCALE, Color(0.56, 0.86, 0.32, (1.0 - progress) * 0.65))
	if hidden:
		# A moving earth mound stays visible while direct fire cannot select it.
		draw_ellipse(center + Vector2(0, 5), 18, 8, Color("65462f"))
		draw_ellipse(center + Vector2(0, 3), 14, 6, Color("b08550"))
		draw_polyline(PackedVector2Array([center + Vector2(-9, 4), center + Vector2(-3, 0), center + Vector2(2, 5), center + Vector2(8, 2)]), Color("765432"), 2)
	else:
		draw_rect(Rect2(center + Vector2(-13, 9), Vector2(26, 5)), Color(0.20, 0.23, 0.11, 0.22))
		var enemy_size: float = 54.0 if enemy["kind"] == "queen" else 33.0 if enemy["kind"] == "aphid" else 38.0 if enemy["kind"] == "whitefly" else 46.0 if enemy["kind"] == "wireworm" else 44.0 if enemy["kind"] in ["soldier", "leafroller"] else 42.0
		_sprite(texture, Rect2(center + Vector2(-enemy_size / 2, -enemy_size * 0.60 + bob - lift), Vector2.ONE * enemy_size), Color(1.0, 0.80, 0.64) if enraged else Color.WHITE)
	var group_id: String = EnemyDirector.ENEMIES.get(enemy["kind"], {}).get("category", "special")
	var group_color: Color = EnemyDirector.ENEMY_GROUPS.get(group_id, {}).get("color", GOLD)
	draw_circle(center + Vector2(-12, 12), 3, INK)
	draw_circle(center + Vector2(-12, 12), 2, group_color)
	if float(enemy.get("shield_flash", 0.0)) > 0.0:
		_enemy_pulse(center, 25, Color(0.62, 0.84, 0.34, 0.7))
	if float(enemy.get("disruption_pulse", 0.0)) > 0.0:
		for placement in battle.plants:
			if placement.get("jam_source", -1) != enemy["id"] or float(placement.get("jammed", 0.0)) <= 0.0: continue
			var target: Vector2 = battle_to_screen(plot_positions[int(placement["slot"])])
			var roots := PackedVector2Array([center, center.lerp(target, 0.5) + Vector2(0, 5), target])
			draw_polyline(roots, Color("65472e"), 4)
			draw_polyline(roots, Color("c19655"), 2)

	if int(enemy.get("armor", 0)) > 0:
		draw_circle(center + Vector2(14, -19), 4, Color("d4d5bc"))
		draw_circle(center + Vector2(14, -19), 2, Color("6e7270"))
	if float(enemy["hp"]) < float(enemy["max_hp"]):
		draw_rect(Rect2(center.x - 15, center.y - 29 - lift, 30, 5), Color("654729"))
		draw_rect(Rect2(center.x - 14, center.y - 28 - lift, maxf(1, 28 * float(enemy["hp"]) / float(enemy["max_hp"])), 3), Color("c5b182") if hidden else Color("efaa49") if enraged else Color("a2c452"))
	if float(enemy.get("healed", 0.0)) > 0.0:
		var plus: Vector2 = center + Vector2(-20, -20)
		draw_rect(Rect2(plus + Vector2(2, -2), Vector2(4, 12)), Color("315a35"))
		draw_rect(Rect2(plus + Vector2(-2, 2), Vector2(12, 4)), Color("315a35"))
		draw_rect(Rect2(plus + Vector2(3, -1), Vector2(2, 10)), Color("c4f085"))
		draw_rect(Rect2(plus + Vector2(-1, 3), Vector2(10, 2)), Color("c4f085"))
	if enraged:
		for offset in [Vector2(-21, -1), Vector2(-18, 5)]:
			draw_line(center + offset, center + offset + Vector2(7, -3), Color("f6b75c"), 2)
		if float(enemy.get("rage_flash", 0.0)) > 0.0:
			_enemy_pulse(center, 20, Color(1.0, 0.63, 0.24, float(enemy["rage_flash"]) * 1.5))
	if float(enemy.get("phase_flash", 0.0)) > 0.0:
		for index in range(5):
			var angle: float = index * TAU / 5.0
			var speck := Rect2(center + Vector2(cos(angle), sin(angle)) * 18, Vector2(3, 3))
			if BOARD.encloses(speck):
				draw_rect(speck, Color("c19a63"))
	if float(enemy["slow"]) > 0:
		for dot in [Vector2(-18, -4), Vector2(16, 7), Vector2(3, -22)]:
			draw_rect(Rect2(center + dot, Vector2(3, 3)), Color("b49ed6"))


func _draw_root_jam(rect: Rect2) -> void:
	var at: Vector2 = rect.get_center() + Vector2(0, 15)
	var roots := PackedVector2Array([at + Vector2(-24, -4), at + Vector2(-16, 1), at + Vector2(-8, -3), at + Vector2(0, 3), at + Vector2(10, -3), at + Vector2(20, 1)])
	draw_polyline(roots, Color("62472c"), 4)
	draw_polyline(roots, Color("b99053"), 2)
	var mark: Vector2 = rect.position + Vector2(rect.size.x - 14, 3)
	draw_rect(Rect2(mark, Vector2(13, 12)), Color("694c32"))
	draw_rect(Rect2(mark + Vector2(3, 2), Vector2(2, 8)), Color("f4d59a"))
	draw_rect(Rect2(mark + Vector2(8, 2), Vector2(2, 8)), Color("f4d59a"))


func _enemy_pulse(center: Vector2, radius: float, color: Color) -> void:
	Clip.draw_circle(self,center,radius,BOARD,Color(color,color.a*0.12),color,1.5)


func _draw_bed(rect: Rect2, occupied: bool, highlighted: bool) -> void:
	# Irregular, softly rounded soil edges keep the checked rectangular footprint
	# invisible. All artwork stays inside it, including grass at the boundary.
	var seed: int = int(rect.position.x * 11 + rect.position.y * 7)
	var outer: PackedVector2Array = _soil_outline(rect, 0.0, seed)
	var middle: PackedVector2Array = _soil_outline(rect, 2.0, seed + 3)
	var soil: PackedVector2Array = _soil_outline(rect, 4.0, seed + 7)
	draw_colored_polygon(outer, Color("59633a"))
	draw_colored_polygon(middle, Color("6c4f32"))
	draw_colored_polygon(soil, Color("83603d") if occupied else Color("987044"))
	for row in range(3):
		var ridge = PackedVector2Array()
		var y: float = rect.position.y + 11 + row * 9
		for step in range(9):
			var x: float = rect.position.x + 10 + (rect.size.x - 20) * step / 8.0
			ridge.append(Vector2(x, y + sin(step * 0.8 + seed * 0.1 + row) * 1.0))
		draw_polyline(ridge, Color("694c30"), 3.0, false)
		var raised = PackedVector2Array()
		for point in ridge:
			raised.append(point + Vector2(0, -2))
		draw_polyline(raised, Color("b18a54"), 1.5, false)
	for index in range(13):
		var x: float = rect.position.x + 8 + _noise(index, seed) * (rect.size.x - 16)
		var y: float = rect.position.y + 6 + _noise(index + 23, seed) * (rect.size.y - 12)
		draw_circle(Vector2(x, y), 0.9 + _noise(index + 71, seed), Color("bc9762") if index % 3 == 0 else Color("765633"))
	for index in range(5):
		var x: float = rect.position.x + 10 + _noise(index + 100, seed) * (rect.size.x - 20)
		var y: float = rect.position.y + (3.0 if index % 2 == 0 else rect.size.y - 4.0)
		draw_line(Vector2(x - 1, y + 2), Vector2(x, y - 2), Color("83994c"), 1.0)
		draw_line(Vector2(x, y - 2), Vector2(x + 2, y), Color("a2ae58"), 1.0)
	if highlighted:
		var edge = PackedVector2Array(middle)
		edge.append(middle[0])
		draw_polyline(edge, Color("d3b46d"), 1.0, false)


func _soil_outline(rect: Rect2, inset: float, seed: int) -> PackedVector2Array:
	var inner: Rect2 = rect.grow(-inset)
	var points = PackedVector2Array()
	var center: Vector2 = inner.get_center()
	var radius: Vector2 = inner.size / 2.0
	# A rounded superellipse, with deterministic small imperfections.
	for index in range(28):
		var angle: float = TAU * index / 28.0
		var c: float = cos(angle)
		var sn: float = sin(angle)
		var x: float = signf(c) * pow(absf(c), 0.42)
		var y: float = signf(sn) * pow(absf(sn), 0.60)
		var jitter: float = 0.94 + _noise(index, seed) * 0.06
		points.append(center + Vector2(x * radius.x, y * radius.y) * jitter)
	return points


func _draw_battle_placement_preview() -> void:
	var preview: Dictionary = get_battle_placement_preview()
	if not preview.get("active",false): return
	var point: Vector2 = preview["position"]
	var rect: Rect2 = preview["rect"]
	if not BOARD.encloses(rect): return
	var valid: bool = bool(preview["valid"])
	var color := Color("b5e17b") if valid else Color("eb8e70")
	var outline := PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y),rect.position])
	draw_rect(rect,Color(color,0.14))
	draw_polyline(outline,Color(color,0.94),2)
	var level: int = 1
	for entry in battle.loadout:
		if entry["kind"] == preview["kind"]: level = int(entry["level"])
	var data: Dictionary = state.plant_data(preview["kind"],level)
	if data["role"] == "defense":
		var radius: float = float(data["range"])*BattleView.SCALE
		Clip.draw_circle(self,battle_to_screen(point),radius,BOARD,Color(color,0.08),Color(color,0.55),1.0)
	var sprite: Rect2 = BattleView.sprite_at(point)
	sprite.position += BOARD.position
	# Modulation keeps the actual plant/weapon silhouette visible while the
	# player holds it. The drop uses the same geometry and balance as this test.
	var alpha: Color = Color(1,1,1,0.65 if valid else 0.4)
	var texture: Texture2D = Visuals.defense_texture(preview["kind"],level)
	var frame: Rect2
	if texture == null:
		texture=Visuals.CROP_TEXTURES.get(preview["kind"],PLANT_ART[preview["kind"]])
		frame=Visuals._sprite_rect(texture,sprite,level)
	else: frame=Visuals.defense_sprite_rect(preview["kind"],level,sprite)
	if preview["kind"] in ["waterlily","lotus"]: Visuals.draw_water_bowl(self,sprite)
	Clip.draw_texture(self,texture,frame,BOARD,alpha)
	if battle_drag_active:
		var anchor: Vector2 = rect.get_center()
		var line: PackedVector2Array = Clip.segment(anchor,preview["finger"],BOARD.grow(-0.5))
		if line.size()==2: draw_line(line[0],line[1],Color(color,0.7),1)
	if not valid and BOARD.has_point(rect.get_center()):
		var notice: Rect2 = BattleView.placement_notice(rect)
		_box(notice,Color("f3e3ce"))
		_label(Rect2(notice.position+Vector2(5,2),notice.size-Vector2(10,4)),preview["reason"],13,Color("8c4734"),bold,true,true)


func _noise(index: int, seed: int) -> float:
	return fposmod(sin(float(index * 127 + seed * 37) * 0.371) * 43758.5453, 1.0)


func _has_owned_defender() -> bool:
	for entry in state.battle_roster():
		if state.plant_data(entry["kind"], entry["level"])["role"] == "defense":
			return true
	return false


func _sprite(texture: Texture2D, rect: Rect2, tint: Color = Color.WHITE) -> void:
	var factor: float = minf(rect.size.x / texture.get_width(), rect.size.y / texture.get_height())
	var dimensions: Vector2 = (texture.get_size() * factor).floor()
	var at: Vector2 = (rect.position + (rect.size - dimensions) / 2).floor()
	draw_texture_rect(texture, Rect2(at, dimensions), false, tint)


func _draw_coin(rect: Rect2) -> void:
	var size: float = minf(rect.size.x, rect.size.y)
	var at: Vector2 = rect.position.floor()
	draw_rect(Rect2(at + Vector2(size * 0.2, 0), Vector2(size * 0.6, size)), Color("855522"))
	draw_rect(Rect2(at + Vector2(0, size * 0.2), Vector2(size, size * 0.6)), Color("855522"))
	draw_rect(Rect2(at + Vector2(size * 0.16, size * 0.16), Vector2(size * 0.68, size * 0.68)), Color("edbc48"))
	draw_rect(Rect2(at + Vector2(size * 0.27, size * 0.27), Vector2(size * 0.46, size * 0.13)), Color("ffe49a"))
	draw_rect(Rect2(at + Vector2(size * 0.45, size * 0.3), Vector2(size * 0.13, size * 0.45)), Color("a96e26"))


func _draw_result() -> void:
	hitboxes.clear()
	draw_rect(Rect2(0, 0, 540, 960), Color(0.1, 0.18, 0.12, 0.58))
	_box(Rect2(36, 190, 468, 594), PAPER)
	var won: bool = battle.phase == "won"
	var reward: Dictionary = battle.discovery_reward
	_sprite(PLANT_ART["marigold"], Rect2(238, 209, 64, 64))
	_center(Rect2(52, 283, 436, 42), "Новые возможности сада!" if not reward.is_empty() else "Сад под защитой!" if won else "Теплице нужна помощь", 26, GREEN, display_font)
	if not reward.is_empty():
		_center(Rect2(52, 337, 436, 32), "Водные грядки питомника" if int(reward.get("pond_plots", 0)) > 0 else "Новые культуры", 25, INK, bold)
		var effect_text: String = "+%d водных мест в питомнике" % int(reward["pond_plots"]) if int(reward.get("pond_plots",0)) > 0 else "Новые виды для огорода и питомника"
		_center(Rect2(52, 381, 436, 30), effect_text, 18, GREEN, bold)
		var seed_names: Array[String] = []
		for kind in reward.get("new_seeds", reward["seeds"]):
			seed_names.append(Catalog.PLANTS[kind]["name"])
		_label(Rect2(64, 418, 412, 57), "Новые семена: " + ", ".join(seed_names) if not seed_names.is_empty() else "Семена этого участка уже открыты", 17, INK, bold, true, true)
	else:
		BattleUI.draw_outcome_advice(self, Rect2(56, 344, 428, 125))
	_center(Rect2(52, 482, 436, 32), "За бой заработано: %d монет" % battle.earned, 22, INK, bold)
	_center(Rect2(52, 528, 436, 27), "Повторные бои помогают накопить на развитие", 14, MUTED)
	var another: bool = won and current_stage < Missions.COUNT
	_button(Rect2(60, 603, 420, 52), "Следующее задание →" if another else "Повторить бой", "next" if another else "retry")
	_button(Rect2(60, 704, 420, 49), "Вернуться в сад", "result_home", true, false)


func _draw_help() -> void:
	hitboxes.clear()
	draw_rect(Rect2(0, 0, 540, 960), Color(0.1, 0.18, 0.12, 0.5))
	_box(Rect2(40, 146, 460, 698), PAPER, 24)
	_sprite(CAN, Rect2(241, 164, 58, 58))
	_center(Rect2(60, 228, 420, 40), "Как растёт ваш сад", 26, GREEN, display_font)
	var paragraphs: Array[String] = [
		"Двигайте карту пальцем. Сведите или разведите два пальца для масштаба. Кнопки районов и миникарта помогут найти нужное место.",
		"В огороде и питомнике по четыре квадрата 6×6 — 144 места. Водные виды растут у воды. Нажмите свободную клетку, чтобы посадить.",
		"Каждый бой начинается с 240 припасами. Выберите выращенные виды и ставьте копии за припасы. Монеты сада на бой не тратятся.",
		"В теплице улучшайте полив, подкормку и хранение урожая. Победы открывают семена и водные грядки. Остаток боевых припасов исчезает.",
	]
	var y: float = 290
	for index in range(paragraphs.size()):
		_box(Rect2(64, y - 16, 25, 25), LIGHT, 12)
		_center(Rect2(64, y - 16, 25, 25), str(index + 1), 12, GREEN, bold)
		var lines: int = _paragraph(Vector2(102, y), paragraphs[index], 334, 14, INK)
		y += maxf(76, lines * 21 + 18)
	_button(Rect2(64,708,412,44),"Звуки: включены" if audio_enabled else "Звуки: выключены","toggle_audio",true,false)
	_button(Rect2(64, 770, 412, 50), "Начнём выращивать", "help", true)


func _draw_stage_picker() -> void:
	hitboxes.clear()
	draw_rect(Rect2(0, 0, 540, 960), Color(0.1, 0.18, 0.12, 0.60))
	_box(Rect2(24, 154, 492, 654), PAPER)
	_label(Rect2(44, 168, 452, 42), "Защита сада", 27, GREEN, bold)
	_label(Rect2(45, 214, 450, 28), "Длинная оборона · можно продолжить позже", 16, MUTED)
	for index in range(Missions.COUNT):
		var info: Dictionary = Missions.stage_info(index + 1)
		var unlocked: bool = state.is_stage_unlocked(index + 1)
		var completed: bool = state.completed_level >= index + 1
		var rect = Rect2(42, 258 + index * 143, 456, 128)
		var card_color: Color = LIGHT if unlocked else UiTheme.DISABLED
		if unlocked and _is_control_pressed("stage:%d" % (index+1)): card_color = card_color.darkened(0.06)
		_box(rect,card_color)
		_label(Rect2(rect.position + Vector2(14, 7), Vector2(rect.size.x - 28, 33)), "%02d  %s" % [index + 1, info["title"]], 23, INK, bold)
		var description: String = "Пройдено · повторить ради монет" if completed else "Откроется после задания %d" % index if not unlocked else "Водные грядки питомника и семена" if int(info.get("pond_plots", 0)) > 0 else "Новые семена для сада"
		_label(Rect2(rect.position + Vector2(15, 40), Vector2(rect.size.x - 30, 26)), description, 15, MUTED)
		var effect_text: String = "+%d водных мест в питомнике" % int(info["pond_plots"]) if int(info.get("pond_plots",0)) > 0 else "Развитие огорода и питомника"
		_label(Rect2(rect.position + Vector2(15, 68), Vector2(rect.size.x - 30, 26)), effect_text, 16, GREEN, bold)
		_label(Rect2(rect.position + Vector2(15, 91), Vector2(rect.size.x - 30, 34)), "Семена: " + ", ".join(Missions.seed_names(index + 1)), 14, MUTED)
		if unlocked:
			_hit(rect, "stage:%d" % (index + 1))
	_button(Rect2(44, 735, 452, 48), "Вернуться", "close_stage", true, false)


func _is_control_pressed(action: String) -> bool:
	return pointer_down and not pointer_dragging and not pending_hit.is_empty() and str(pending_hit.get("action","")) == action and pending_hit["rect"].has_point(pointer_last)


func _button(rect: Rect2, label: String, action: String, enabled: bool = true, filled: bool = true) -> void:
	var pressed: bool = enabled and _is_control_pressed(action)
	var background: Color = GREEN if filled and enabled else Color("f7f5ec") if enabled else UiTheme.DISABLED
	var foreground: Color = Color("fffdf2") if filled and enabled else INK if enabled else UiTheme.DISABLED_INK
	var border: Color = GREEN.darkened(0.13) if filled and enabled else LINE
	if pressed: background = background.darkened(0.10 if filled else 0.06)
	var drawn := Rect2(rect.position+Vector2(0,1 if pressed else 0),rect.size)
	UiTheme.panel(self,drawn,background,border,10,0 if pressed else 2)
	if label in ["<",">","←","→"]:
		_draw_control_chevron(drawn,label in [">","→"],foreground)
	else:
		var forward: bool = label.ends_with(" >") or label.ends_with(" →")
		var content: String = label.left(label.length()-2) if forward else label
		var text_rect: Rect2 = drawn.grow(-4)
		if forward:
			text_rect.size.x -= 21
			_draw_control_chevron(Rect2(drawn.end.x-30,drawn.position.y,24,drawn.size.y),true,foreground)
		_label(text_rect,content,18 if drawn.size.y>=44 else 15,foreground,bold,false,true)
	if enabled: _hit(rect,action)


func _draw_control_chevron(rect: Rect2, forward: bool, color: Color) -> void:
	var at: Vector2 = rect.get_center().round()
	var side: float = 1.0 if forward else -1.0
	draw_polyline(PackedVector2Array([at+Vector2(-side*3,-6),at+Vector2(side*3,0),at+Vector2(-side*3,6)]),color,2.5,false)


func _hud_panel(rect: Rect2) -> void:
	UiTheme.hud(self,rect)


func _box(rect: Rect2, color: Color, radius: int = 0, border: Color = Color.TRANSPARENT, _width: int = 1) -> void:
	UiTheme.panel(self,rect,color,border if border.a>0 else LINE,10 if radius==0 else radius,2 if rect.size.y>=48 else 0)


func _text(at: Vector2, text: String, size: int, color: Color = INK, face: Font = null) -> void:
	var selected_font: Font = font if face == null else face
	draw_string(selected_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _compact_coins(amount: int) -> String:
	if amount >= 1000000000:
		return "%.1f млрд" % (amount / 1000000000.0)
	if amount >= 1000000:
		return "%.1f млн" % (amount / 1000000.0)
	if amount >= 10000:
		return "%d тыс." % (amount / 1000)
	return str(amount)


func _label(rect: Rect2, text: String, size: int, color: Color = INK, face: Font = null, wrap: bool = false, centered: bool = false) -> void:
	var selected: Font = font if face == null else face
	var layout: Dictionary = UiText.layout(selected, text, rect, size, wrap, centered)
	if test_mode:
		text_layouts.append(layout)
	for run in layout["runs"]:
		_text(run["at"], run["text"], layout["font_size"], color, selected)


func _level_label(rect: Rect2, level: int, color: Color = Color("34452f")) -> void:
	var face: Font = Visuals.compact_level_font(bold)
	var layout: Dictionary = UiText.layout(face,str(level),rect,11,false,true)
	# A one-pixel stem must land on a physical pixel at fractional window
	# scales. Snapping only the logical card leaves different columns fading.
	var physical: Transform2D = get_viewport().get_final_transform()*get_global_transform_with_canvas()
	var inverse: Transform2D = physical.affine_inverse()
	for run in layout["runs"]:
		var old: Vector2 = run["at"]
		var snapped: Vector2 = inverse*(physical*old).round()
		run["at"]=snapped
		var bounds: Rect2 = run["rect"]
		bounds.position+=snapped-old
		run["rect"]=bounds
		_text(snapped,run["text"],11,color,face)
	if test_mode: text_layouts.append(layout)


func _center(rect: Rect2, text: String, size: int, color: Color = INK, face: Font = null) -> void:
	_label(Rect2(rect.position + Vector2(6, 0), rect.size - Vector2(12, 0)), text, size, color, face, false, true)


func _coin_rewarded(local_position: Vector2, amount: int, source: String) -> void:
	_reward_popup(local_position, amount, source, "coins")


func _supplies_rewarded(local_position: Vector2, amount: int, source: String) -> void:
	_reward_popup(local_position, amount, source, "supplies")


func _reward_popup(local_position: Vector2, amount: int, source: String, currency: String) -> void:
	var at: Vector2 = Vector2(270, BOARD.position.y + 60) if source == "wave" else battle_to_screen(local_position)
	# Nearby simultaneous swarm kills share a sum; currencies never get mixed.
	if source == "kill":
		for popup in coin_popups:
			if popup["source"] == source and popup["currency"] == currency and popup["age"] < 0.16 and Vector2(popup["position"]).distance_to(at) < 30:
				popup["amount"] += amount
				popup["position"] = Vector2(popup["position"]).lerp(at, 0.5)
				return
	coin_popups.append({"position": at, "amount": amount, "source": source, "age": 0.0, "currency": currency})


func _draw_supply(rect: Rect2) -> void:
	# A pixel seed pouch, legible at both HUD and floating-reward sizes.
	var unit: Vector2 = rect.size / Vector2(16, 16)
	var origin: Vector2 = rect.position
	var outline := Color("563921")
	var cloth := Color("c69248")
	var light := Color("f5ce7d")
	draw_colored_polygon(PackedVector2Array([
		origin + Vector2(4, 1) * unit, origin + Vector2(12, 1) * unit,
		origin + Vector2(10, 5) * unit, origin + Vector2(14, 9) * unit,
		origin + Vector2(14, 14) * unit, origin + Vector2(12, 16) * unit,
		origin + Vector2(3, 16) * unit, origin + Vector2(1, 13) * unit,
		origin + Vector2(2, 8) * unit, origin + Vector2(6, 5) * unit,
	]), outline)
	draw_rect(Rect2(origin + Vector2(3, 9) * unit, Vector2(9, 5) * unit), cloth)
	draw_rect(Rect2(origin + Vector2(5, 7) * unit, Vector2(5, 7) * unit), light)
	draw_rect(Rect2(origin + Vector2(5, 2) * unit, Vector2(6, 2) * unit), cloth)
	draw_rect(Rect2(origin + Vector2(5, 5) * unit, Vector2(6, 2) * unit), Color("7d542b"))
	draw_rect(Rect2(origin + Vector2(7, 10) * unit, Vector2(2, 4) * unit), Color("426b37"))
	draw_rect(Rect2(origin + Vector2(5, 9) * unit, Vector2(3, 2) * unit), Color("689447"))
	draw_rect(Rect2(origin + Vector2(9, 8) * unit, Vector2(2, 3) * unit), Color("426b37"))


func _draw_coin_popups() -> void:
	for popup in coin_popups:
		var age: float = popup["age"]
		var coins: bool = popup["currency"] == "coins"
		var at: Vector2 = popup["position"] - Vector2(0, 32 + age * 24 + (27 if coins else 0))
		var label: String = "+%d" % popup["amount"]
		var width: float = bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 30
		var rect: Rect2 = Rect2(clampf(at.x - width / 2, BOARD.position.x + 2, BOARD.end.x - width - 2), clampf(at.y, BOARD.position.y + 2, BOARD.end.y - 30), width, 30)
		var alpha: float = minf(1.0, (1.65 - age) / 0.4)
		if coins:
			_draw_coin(Rect2(rect.position + Vector2(3, 6), Vector2(18, 18)))
		else:
			_draw_supply(Rect2(rect.position + Vector2(3, 6), Vector2(18, 18)))
		var text_at := rect.position + Vector2(27, 22)
		draw_string_outline(bold, text_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0.16, 0.13, 0.08, alpha))
		draw_string(bold, text_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.87, 0.4, alpha) if coins else Color(0.74, 1, 0.95, alpha))


func _paragraph(at: Vector2, text: String, width: float, size: int, color: Color) -> int:
	var line: String = ""
	var lines: int = 0
	for word in text.split(" "):
		var next: String = word if line.is_empty() else line + " " + word
		if not line.is_empty() and font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			_text(at + Vector2(0, lines * 21), line, size, color)
			lines += 1
			line = word
		else:
			line = next
	_text(at + Vector2(0, lines * 21), line, size, color)
	return lines + 1


func _hit(rect: Rect2, action: String, world_control: bool = false) -> void:
	hitboxes.append({"rect": rect, "action": action, "world": world_control})


func _hit_world(world_rect: Rect2, action: String) -> void:
	if not home_panel.is_empty() or help_open:
		return
	# Adjacent cells must share the same projected edge. Multiplying each size
	# separately can leave a subpixel overlap after a fractional camera pan.
	var first: Vector2 = garden_world.world_to_screen(world_rect.position).round()
	var last: Vector2 = garden_world.world_to_screen(world_rect.end).round()
	var screen_rect := Rect2(first,last-first)
	var visible: Rect2 = screen_rect.intersection(GardenMap.MAP_VIEW)
	if visible.size.x < 16.0 or visible.size.y < 16.0:
		return
	for cover in GARDEN_OCCLUDERS:
		if cover.encloses(visible):
			return
	_hit(visible, action, true)


func _capture() -> void:
	await get_tree().create_timer(0.8).timeout
	if capture_battle:
		if battle.phase == "between":
			battle.start_wave()
		toast_time = 0.0
		queue_redraw()
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(capture_path)
	print("CAPTURE ", capture_path, " error=", error)
	get_tree().quit(int(error))
