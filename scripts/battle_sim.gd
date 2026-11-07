class_name BattleSim
extends RefCounted

## A pre-battle selection unlocks repeatable paid copies of grown species.
## Levels are snapshotted; deployments use a fresh, isolated battle budget.
signal changed
signal wave_finished(income: int)
signal supplies_rewarded(position: Vector2, amount: int, source: String)
signal coin_rewarded(position: Vector2, amount: int, source: String)
signal battle_finished(won: bool)
signal notice(message: String)

const STARTING_SUPPLIES: int = 240
const GARDEN_COIN_CHANCE: float = 0.20
const FIXED_STEP: float = 1.0 / 60.0
const MAX_CATCHUP_TIME: float = 2.0

const Catalog = preload("res://scripts/catalog.gd")
const Director = preload("res://scripts/battle_director.gd")
const Placement = preload("res://scripts/battle_placement.gd")
const LegacyLayout = preload("res://scripts/field_layout.gd")
const TARGET_MODES: Array[String] = ["first", "strong", "fast"]

var state: GardenState
var plants: Array[Dictionary] = []
var loadout: Array[Dictionary] = []
var loadout_ready: bool = false
var discovery_reward: Dictionary = {}
var last_wave_reward: Dictionary = {}
var _rewarded_waves: Dictionary = {}
var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var wave: int = 0
var total_waves: int = 5
var base_hp: int = 10
var phase: String = "preparing"
var paused: bool = false
var speed: float = 1.0
var supplies: int = STARTING_SUPPLIES
var supplies_earned: int = 0
var reward_rng := RandomNumberGenerator.new()
var earned: int = 0
var kills: int = 0
var active_seconds: float = 0.0
var stage: int = 1
var spawned: int = 0
var enemy_total: int = 0
var path_length: float = 0.0
var current_wave_plan: Dictionary = {}
var battle_stats: Dictionary = {}
var leaked_records: Array[Dictionary] = []
var leak_report: Dictionary = {}
var last_failure_hint: String = ""
var last_wave_summary: Dictionary = {}

var _path: Array[Vector2] = []
var _plots: Array[Vector2] = []
var _segments: Array[float] = []
var _spawn_left: int = 0
var _wave_elapsed: float = 0.0
var _time_accumulator: float = 0.0
var _spawn_schedule: Array[Dictionary] = []
var _spawn_cursor: int = 0
var _wave_kills: int = 0
var _next_enemy_id: int = 1


func configure(garden: GardenState, path_points: Array[Vector2], plot_positions: Array[Vector2], stage_number: int = 1) -> void:
	state = garden
	_path.assign(path_points)
	_plots.assign(plot_positions)
	stage = clampi(stage_number, 1, 3)
	plants.clear()
	loadout.clear()
	loadout_ready = false
	discovery_reward = {}
	last_wave_reward = {}
	_rewarded_waves.clear()
	enemies.clear()
	shots.clear()
	_segments.clear()
	path_length = 0.0
	for i in range(1, _path.size()):
		var length: float = _path[i - 1].distance_to(_path[i])
		_segments.append(length)
		path_length += length
	wave = 0
	base_hp = 10
	phase = "preparing"
	paused = false
	speed = 1.0
	supplies = STARTING_SUPPLIES
	supplies_earned = 0
	reward_rng.randomize()
	earned = 0
	kills = 0
	active_seconds = 0.0
	spawned = 0
	enemy_total = 0
	_spawn_left = 0
	_wave_elapsed = 0.0
	_time_accumulator = 0.0
	_spawn_schedule.clear()
	_spawn_cursor = 0
	_next_enemy_id = 1
	current_wave_plan = {}
	battle_stats = {"spent":0,"income_spent":0,"defense_spent":0,"damage_by_kind":{},"kills_by_kind":{},"leaked_by_kind":{},"base_damage":0,"waves_completed":0,"enemy_healing":0.0,"enemy_disruptions":0}
	leaked_records.clear()
	leak_report.clear()
	last_failure_hint = ""
	last_wave_summary = {}
	changed.emit()


func get_plant(slot: int) -> Dictionary:
	for placement in plants:
		if int(placement["slot"]) == slot:
			return placement
	return {}


func path_points() -> Array[Vector2]:
	return _path.duplicate()


func plot_positions() -> Array[Vector2]:
	return _plots.duplicate()


func placement_check(position: Vector2, kind: String = "") -> Dictionary:
	if state == null or not loadout_ready or phase not in ["preparing", "running", "between"]:
		return Placement.with_cell(Placement.invalid("phase", "Сначала выберите состав для обороны"),position)
	if not kind.is_empty():
		var planting: Dictionary = _selected_plant(kind)
		if planting.is_empty(): return Placement.with_cell(Placement.invalid("not_selected", "Это растение не взято в бой"),position)
		if supplies < int(planting["cost"]):
			return Placement.with_cell(Placement.invalid("supplies", "Не хватает припасов для установки растения"),position)
	var occupied: Array[Vector2] = []
	for placement in plants:
		occupied.append(_plots[int(placement["slot"])])
	return Placement.check(position, _path, occupied)


func plant_at(position: Vector2, kind: String) -> int:
	var check: Dictionary = placement_check(position, kind)
	if not check["valid"]:
		notice.emit(check["reason"])
		return -1
	# Reserving an ID and paying happen only after the final land/budget test.
	# A failed gesture never leaves an unused anchor or consumes a future ID.
	var slot: int = _plots.size()
	_plots.append(check["position"])
	if not plant(slot, kind):
		_plots.pop_back()
		return -1
	return slot


func plant_income(kind: String, level: int = 0) -> int:
	if state == null:
		return 0
	var data: Dictionary = state.plant_data(kind, level)
	return roundi(float(data.get("battle_yield", 0)) * (1.0 + float(stage - 1) * 0.15))


func wave_income() -> int:
	var income: int = 0
	for placement in plants:
		income += plant_income(String(placement["kind"]), int(placement["level"]))
	return income


func loadout_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if state == null:
		return options
	for planting in state.battle_templates():
		options.append(planting.duplicate(true))
	return options


func select_loadout(kinds: Array[String]) -> bool:
	if state == null or phase != "preparing" or wave != 0 or not plants.is_empty():
		return false
	if kinds.is_empty():
		notice.emit("Выберите хотя бы одно выращенное растение")
		return false
	var options: Array[Dictionary] = loadout_options()
	var selected: Array[Dictionary] = []
	var seen: Dictionary = {}
	for kind in kinds:
		if seen.has(kind):
			return false
		var found: Dictionary = {}
		for option in options:
			if String(option["kind"]) == kind:
				found = option
				break
		if found.is_empty():
			notice.emit("Сначала вырастите выбранное растение в саду")
			return false
		seen[kind] = true
		selected.append(found.duplicate(true))
	loadout = selected
	loadout_ready = true
	changed.emit()
	return true


func available_plants() -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	if state == null or not loadout_ready or phase not in ["preparing", "running", "between"]:
		return available
	# Selecting one grown species supplies its template for as many paid copies
	# as the player can afford and fit on the field. Placements never consume it.
	for planting in loadout:
		available.append(planting.duplicate(true))
	return available


func _selected_plant(kind: String) -> Dictionary:
	for planting in available_plants():
		if String(planting["kind"]) == kind:
			return planting
	return {}


func plant(slot: int, kind: String) -> bool:
	if state == null or not loadout_ready or phase not in ["preparing", "running", "between"]:
		return false
	if slot < 0 or slot >= _plots.size():
		return false
	if not get_plant(slot).is_empty():
		notice.emit("Эта клетка уже занята")
		return false
	var planting: Dictionary = _selected_plant(kind)
	if planting.is_empty():
		notice.emit("Это растение не взято в бой")
		return false
	var cost: int = int(planting["cost"])
	if not spend_supplies(cost):
		notice.emit("Не хватает припасов для установки растения")
		return false
	_record_purchase(kind, cost)
	plants.append({
		"slot": slot,
		"kind": kind,
		"level": int(planting["level"]),
		"source_id": String(planting["source_id"]),
		"cooldown": 0.0,
		"target_mode": "first",
		"jammed": 0.0,
		"jam_flash": 0.0,
		"jam_source": -1,
	})
	changed.emit()
	return true


func replace_plant(slot: int, kind: String) -> bool:
	if state == null or not loadout_ready or phase not in ["preparing", "running", "between"]:
		return false
	var placement_index: int = -1
	for index in range(plants.size()):
		if int(plants[index]["slot"]) == slot:
			placement_index = index
			break
	if placement_index < 0 or String(plants[placement_index]["kind"]) == kind:
		return false
	var planting: Dictionary = _selected_plant(kind)
	if planting.is_empty():
		notice.emit("Это растение не взято в бой")
		return false
	var data: Dictionary = state.plant_data(kind, int(planting["level"]))
	var incoming_cooldown: float = float(data.get("cooldown", 0.0)) if data.get("role") == "defense" else 0.0
	var cooldown: float = maxf(float(plants[placement_index]["cooldown"]), incoming_cooldown)
	if not spend_supplies(int(planting["cost"])):
		notice.emit("Не хватает припасов для замены растения")
		return false
	_record_purchase(kind, int(planting["cost"]))
	var previous: Dictionary = plants[placement_index]
	var target_mode: String = String(previous.get("target_mode", "first"))
	plants[placement_index] = {
		"slot": slot,
		"kind": kind,
		"level": int(planting["level"]),
		"source_id": String(planting["source_id"]),
		"cooldown": cooldown,
		"target_mode": target_mode,
		"jammed": previous.get("jammed", 0.0),
		"jam_flash": previous.get("jam_flash", 0.0),
		"jam_source": previous.get("jam_source", -1),
	}
	changed.emit()
	return true


func place_owned(slot: int, source_id: String) -> bool:
	# Older contextual callers may still identify the chosen garden source.
	# Resolve only within the confirmed selection and apply the same paid rules.
	for planting in available_plants():
		if String(planting["source_id"]) == source_id:
			return plant(slot, String(planting["kind"]))
	return false


func replace_owned(slot: int, source_id: String) -> bool:
	for planting in available_plants():
		if String(planting["source_id"]) == source_id:
			return replace_plant(slot, String(planting["kind"]))
	return false


func start_wave() -> bool:
	if state == null or not loadout_ready or (phase != "preparing" and phase != "between"):
		return false
	if _path.size() < 2 or path_length <= 0.0 or wave >= total_waves:
		return false
	paused = false
	wave += 1
	phase = "running"
	current_wave_plan = Director.wave_plan(stage, wave)
	_wave_kills = 0
	_spawn_schedule.clear()
	var at: float = 0.0
	for group in current_wave_plan["groups"]:
		at += float(group["delay"])
		for index in range(int(group["count"])):
			if index > 0: at += float(group["interval"])
			_spawn_schedule.append({"at":at,"kind":group["kind"],"assault":group.get("assault",1)})
	_spawn_cursor = 0
	_spawn_left = _spawn_schedule.size()
	enemy_total = _spawn_left
	spawned = 0
	_wave_elapsed = 0.0
	_time_accumulator = 0.0

	changed.emit()
	return true


func tick(delta: float) -> void:
	if paused or not is_finite(delta) or delta <= 0.0:
		return
	var scaled_delta: float = delta * clampf(speed, 0.25, 4.0)
	if phase != "running":
		_age_shots(scaled_delta)
		_time_accumulator = 0.0
		return
	# Fixed simulation time makes x2 change waiting time, never enemy strength
	# or cannon DPS. Bound resumed-frame work instead of replaying a long stall.
	_time_accumulator = minf(_time_accumulator + scaled_delta, MAX_CATCHUP_TIME)
	var active_wave: int = wave
	while _time_accumulator + 0.000000001 >= FIXED_STEP:
		_time_accumulator = maxf(0.0, _time_accumulator - FIXED_STEP)
		_tick_step(FIXED_STEP)
		if phase != "running" or wave != active_wave:
			_time_accumulator = 0.0
			break


func _age_shots(dt: float) -> void:
	for index in range(shots.size() - 1, -1, -1):
		shots[index]["life"] = float(shots[index]["life"]) - dt
		if float(shots[index]["life"]) <= 0.0:
			shots.remove_at(index)


func _tick_step(dt: float) -> void:
	_age_shots(dt)
	_wave_elapsed += dt
	active_seconds += dt
	while _spawn_left > 0 and float(_spawn_schedule[_spawn_cursor]["at"]) <= _wave_elapsed + 0.000001:
		_spawn_enemy()
	_tick_enemy_effects(dt)
	_move_enemies(dt)
	if base_hp <= 0:
		_finish_battle(false)
		return
	_fire_plants(dt)
	for i in range(enemies.size() - 1, -1, -1):
		if float(enemies[i]["hp"]) <= 0.0:
			enemies.remove_at(i)
	if _spawn_left == 0 and enemies.is_empty():
		_finish_wave()


func _spawn_enemy() -> void:
	if _spawn_cursor >= _spawn_schedule.size():
		return
	var scheduled: Dictionary = _spawn_schedule[_spawn_cursor]
	var profile: Dictionary = Director.enemy_profile(scheduled["kind"], stage, wave, int(scheduled.get("assault",1)))
	enemies.append({
		"id": _next_enemy_id,
		"assault": int(scheduled.get("assault",1)),
		"kind": scheduled["kind"],
		"progress": 0.0,
		"position": _path[0],
		"hp": profile["hp"],
		"max_hp": profile["hp"],
		"armor": profile["armor"],
		"leak_damage": profile["leak_damage"],
		"slow": 0.0,
		"slow_strength": 0.0,
		"hit": 0.0,
		"speed": profile["speed"],
		"reward": profile["reward"],
		"rewarded": false,
		"born_at": scheduled["at"],
		"age": 0.0,
		"heal_interval": profile.get("heal_interval", 0.0),
		"heal_radius": profile.get("heal_radius", 0.0),
		"heal_amount": profile.get("heal_amount", 0.0),
		"heal_targets": profile.get("heal_targets", 0),
		"heal_cooldown": profile.get("heal_interval", 0.0),
		"heal_pulse": 0.0,
		"healed": 0.0,
		"burrow_cycle": profile.get("burrow_cycle", 0.0),
		"burrow_duration": profile.get("burrow_duration", 0.0),
		"burrow_first": profile.get("burrow_first", 0.0),
		"burrowed": false,
		"phase_flash": 0.0,
		"frenzy_threshold": profile.get("frenzy_threshold", 0.0),
		"frenzy_multiplier": profile.get("frenzy_multiplier", 1.0),
		"enraged": false,
		"rage_flash": 0.0,
		"mobility": profile.get("mobility", "ground"),
		"slow_resistance": profile.get("slow_resistance", 0.0),
		"leaf_shield_threshold": profile.get("leaf_shield_threshold", 0.0),
		"leaf_shield_duration": profile.get("leaf_shield_duration", 0.0),
		"leaf_shield_reduction": profile.get("leaf_shield_reduction", 0.0),
		"leaf_shield": 0.0,
		"leaf_shield_used": false,
		"shield_flash": 0.0,
		"disruption_interval": profile.get("disruption_interval", 0.0),
		"disruption_radius": profile.get("disruption_radius", 0.0),
		"disruption_duration": profile.get("disruption_duration", 0.0),
		"disruption_targets": profile.get("disruption_targets", 0),
		"disruption_cooldown": profile.get("disruption_interval", 0.0),
		"disruption_pulse": 0.0,
		"disruption_target_slot": -1,
	})
	_next_enemy_id += 1
	_spawn_cursor += 1
	_spawn_left -= 1
	spawned += 1


func _tick_enemy_effects(dt: float) -> void:
	# A disruption belongs to the temporary battlefield placement. Garden data
	# and income harvests are never changed, and pausing freezes the same clock.
	for placement in plants:
		placement["jammed"] = maxf(0.0, float(placement.get("jammed", 0.0)) - dt)
		placement["jam_flash"] = maxf(0.0, float(placement.get("jam_flash", 0.0)) - dt)
	# Decay last-frame feedback before any pulses, so recipient order cannot
	# shorten a freshly emitted healing flash by one simulation step.
	for enemy in enemies:
		if float(enemy["hp"]) <= 0.0: continue
		var active_dt: float = minf(dt, maxf(0.0, _wave_elapsed - float(enemy.get("born_at", _wave_elapsed - dt))))
		for flag in ["heal_pulse", "healed", "phase_flash", "rage_flash", "shield_flash", "leaf_shield", "disruption_pulse"]:
			enemy[flag] = maxf(0.0, float(enemy.get(flag, 0.0)) - active_dt)
	for enemy in enemies:
		if float(enemy["hp"]) <= 0.0: continue
		var active_dt: float = minf(dt, maxf(0.0, _wave_elapsed - float(enemy.get("born_at", _wave_elapsed - dt))))
		enemy["age"] = float(enemy.get("age", 0.0)) + active_dt
		var cycle: float = float(enemy.get("burrow_cycle", 0.0))
		if cycle > 0.0:
			var was_hidden: bool = bool(enemy.get("burrowed", false))
			var since_first: float = float(enemy["age"]) - float(enemy.get("burrow_first", 0.0))
			enemy["burrowed"] = since_first >= -0.000000001 and fposmod(maxf(0.0, since_first) + 0.00000001, cycle) < float(enemy.get("burrow_duration", 0.0)) - 0.000000001
			if bool(enemy["burrowed"]) != was_hidden:
				enemy["phase_flash"] = 0.25
		var interval: float = float(enemy.get("heal_interval", 0.0))
		if interval > 0.0:
			enemy["heal_cooldown"] = float(enemy.get("heal_cooldown", interval)) - active_dt
			if float(enemy["heal_cooldown"]) <= 0.000000001:
				enemy["heal_cooldown"] = float(enemy["heal_cooldown"]) + interval
				_heal_neighbours(enemy)
		var disruption_interval: float = float(enemy.get("disruption_interval", 0.0))
		if disruption_interval > 0.0:
			enemy["disruption_cooldown"] = float(enemy.get("disruption_cooldown", disruption_interval)) - active_dt
			if float(enemy["disruption_cooldown"]) <= 0.000000001:
				enemy["disruption_cooldown"] = float(enemy["disruption_cooldown"]) + disruption_interval
				_disrupt_nearby_plant(enemy)


func _heal_neighbours(healer: Dictionary) -> void:
	var candidates: Array[Dictionary] = []
	var radius: float = float(healer.get("heal_radius", 0.0))
	var amount: float = float(healer.get("heal_amount", 0.0))
	var limit: int = int(healer.get("heal_targets", 0))
	if amount <= 0.0 or limit <= 0 or float(healer.get("hp", 0.0)) <= 0.0: return
	for ally in enemies:
		if ally == healer or ally.get("kind", "") == "healer" or float(ally["hp"]) <= 0.0 or float(ally["hp"]) >= float(ally["max_hp"]): continue
		if Vector2(ally["position"]).distance_to(healer["position"]) <= radius:
			candidates.append(ally)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var missing_a: float = 1.0 - float(a["hp"]) / float(a["max_hp"])
		var missing_b: float = 1.0 - float(b["hp"]) / float(b["max_hp"])
		return int(a.get("id", 0)) < int(b.get("id", 0)) if is_equal_approx(missing_a, missing_b) else missing_a > missing_b
	)
	var total: float = 0.0
	for index in range(mini(limit, candidates.size())):
		var ally: Dictionary = candidates[index]
		var restored: float = minf(amount, float(ally["max_hp"]) - float(ally["hp"]))
		ally["hp"] = float(ally["hp"]) + restored
		ally["healed"] = 0.35
		total += restored
	if total > 0.0:
		healer["heal_pulse"] = 0.35
		battle_stats["enemy_healing"] = float(battle_stats.get("enemy_healing", 0.0)) + total


func _disrupt_nearby_plant(enemy: Dictionary) -> void:
	if state == null or float(enemy.get("hp", 0.0)) <= 0.0:
		return
	var duration: float = float(enemy.get("disruption_duration", 0.0))
	var radius: float = float(enemy.get("disruption_radius", 0.0))
	if duration <= 0.0 or int(enemy.get("disruption_targets", 0)) <= 0:
		return
	var chosen: Dictionary = {}
	var nearest: float = radius
	for placement in plants:
		if state.plant_data(placement["kind"], placement["level"]).get("role", "") != "defense":
			continue
		var distance: float = _plots[int(placement["slot"])].distance_to(enemy["position"])
		if distance <= radius and (chosen.is_empty() or distance < nearest or (is_equal_approx(distance, nearest) and int(placement["slot"]) < int(chosen["slot"]))):
			chosen = placement
			nearest = distance
	if chosen.is_empty():
		return
	# One nearest defender, regardless of how many allies are nearby. Repeated
	# pulses refresh a bounded delay rather than summing into a permanent lock.
	chosen["jammed"] = maxf(float(chosen.get("jammed", 0.0)), duration)
	chosen["jam_flash"] = 0.4
	chosen["jam_source"] = int(enemy.get("id", -1))
	enemy["disruption_pulse"] = 0.4
	enemy["disruption_target_slot"] = int(chosen["slot"])
	battle_stats["enemy_disruptions"] = int(battle_stats.get("enemy_disruptions", 0)) + 1


func _move_enemies(dt: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		if float(enemy["hp"]) <= 0.0:
			continue
		var slow_left: float = float(enemy["slow"])
		var strength: float = float(enemy.get("slow_strength", 0.4)) if slow_left > 0.0 else 0.0
		var active_dt: float = minf(dt, maxf(0.0, _wave_elapsed - float(enemy.get("born_at", _wave_elapsed - dt))))
		enemy["slow"] = maxf(0.0, slow_left - active_dt)
		enemy["hit"] = maxf(0.0, float(enemy["hit"]) - active_dt)
		enemy["progress"] = float(enemy["progress"]) + float(enemy["speed"]) * (active_dt - strength * minf(slow_left, active_dt))
		enemy["position"] = _position_on_path(float(enemy["progress"]))
		if float(enemy["progress"]) >= path_length:
			var damage: int = mini(base_hp, int(enemy.get("leak_damage",1)))
			_record_leak(enemy, damage)
			base_hp = maxi(0, base_hp - damage)
			enemies.remove_at(i)
			changed.emit()
			if base_hp == 0:
				return


func _fire_plants(dt: float) -> void:
	for placement in plants:
		var kind: String = String(placement["kind"])
		var data: Dictionary = state.plant_data(kind, int(placement["level"]))
		if data.get("role", "") != "defense":
			continue
		placement["cooldown"] = float(placement["cooldown"]) - dt
		if float(placement.get("jammed", 0.0)) > 0.000000001:
			# Reloading may finish during the delay, but no missed shots accumulate.
			placement["cooldown"] = maxf(0.0, float(placement["cooldown"]))
			continue
		if float(placement["cooldown"]) > 0.000000001:
			continue
		var origin: Vector2 = _plots[int(placement["slot"])]
		var target: Dictionary = _choose_target(origin, float(data["range"]), String(placement.get("target_mode", "first")))
		if target.is_empty():
			# Idle time must not stockpile a burst when the next enemy arrives.
			placement["cooldown"] = 0.0
			continue
		placement["cooldown"] = maxf(0.0, float(placement["cooldown"]) + float(data["cooldown"]))
		var target_position: Vector2 = target["position"]
		shots.append({"from": origin, "to": target_position, "life": 0.17, "kind": kind, "level": int(placement["level"])})
		var splash: float = float(data.get("splash", 0.0))
		if splash > 0.0:
			for enemy in enemies:
				var enemy_position: Vector2 = enemy["position"]
				if enemy_position.distance_to(target_position) <= splash:
					_hit_enemy(enemy, float(data["damage"]), kind, true)
		else:
			_hit_enemy(target, float(data["damage"]), kind)
		var slow_strength: float = float(data.get("slow", 0.0))
		if slow_strength > 0.0:
			var duration: float = float(data.get("slow_duration", 2.0))
			var radius: float = float(data.get("slow_radius", 0.0))
			for enemy in enemies:
				if float(enemy["hp"]) <= 0.0: continue
				if enemy == target or (radius > 0.0 and Vector2(enemy["position"]).distance_to(target_position) <= radius):
					_apply_slow(enemy, slow_strength, duration)


func _hit_enemy(enemy: Dictionary, damage: float, attacker: String = "", area_damage: bool = false) -> void:
	if float(enemy["hp"]) <= 0.0 or damage <= 0.0:
		return
	var unarmored: float = damage - float(enemy.get("armor", 0.0))
	if not area_damage and float(enemy.get("leaf_shield", 0.0)) > 0.000000001:
		unarmored *= 1.0 - clampf(float(enemy.get("leaf_shield_reduction", 0.0)), 0.0, 1.0)
	var applied: float = minf(float(enemy["hp"]), maxf(1.0, unarmored))
	enemy["hp"] = maxf(0.0, float(enemy["hp"]) - applied)
	var shield_threshold: float = float(enemy.get("leaf_shield_threshold", 0.0))
	if shield_threshold > 0.0 and not bool(enemy.get("leaf_shield_used", false)) and float(enemy["hp"]) > 0.0 and float(enemy["hp"]) <= float(enemy["max_hp"]) * shield_threshold:
		enemy["leaf_shield_used"] = true
		enemy["leaf_shield"] = float(enemy.get("leaf_shield_duration", 0.0))
		enemy["shield_flash"] = 0.4
	var threshold: float = float(enemy.get("frenzy_threshold", 0.0))
	if threshold > 0.0 and not bool(enemy.get("enraged", false)) and float(enemy["hp"]) > 0.0 and float(enemy["hp"]) <= float(enemy["max_hp"]) * threshold:
		enemy["enraged"] = true
		enemy["speed"] = float(enemy["speed"]) * float(enemy.get("frenzy_multiplier", 1.0))
		enemy["rage_flash"] = 0.4
	if not attacker.is_empty():
		var damage_stats: Dictionary = battle_stats.get("damage_by_kind", {})
		damage_stats[attacker] = float(damage_stats.get(attacker,0.0)) + applied
	enemy["hit"] = 0.12
	if float(enemy["hp"]) <= 0.0 and not bool(enemy["rewarded"]):
		enemy["rewarded"] = true
		kills += 1
		_wave_kills += 1
		var kind: String = String(enemy.get("kind", "beetle"))
		var kill_stats: Dictionary = battle_stats.get("kills_by_kind", {})
		kill_stats[kind] = int(kill_stats.get(kind,0)) + 1
		var reward: int = int(enemy["reward"])
		_gain_supplies(enemy["position"], reward, "kill")
		_roll_garden_coins(enemy["position"], reward, "kill")


func spend_supplies(amount: int) -> bool:
	if amount < 0 or supplies < amount:
		return false
	supplies -= amount
	return true


func _gain_supplies(at: Vector2, amount: int, source: String) -> void:
	if amount <= 0:
		return
	supplies += amount
	supplies_earned += amount
	supplies_rewarded.emit(at, amount, source)


func _roll_garden_coins(at: Vector2, amount: int, source: String) -> void:
	if reward_rng.randf() >= GARDEN_COIN_CHANCE:
		return
	earned += amount
	state.earn(amount)
	coin_rewarded.emit(at, amount, source)


func wave_bonus(wave_number: int = 0) -> int:
	return 10 + 5 * (maxi(1, wave if wave_number == 0 else wave_number) - 1) + 5 * (stage - 1)


func _finish_wave() -> void:
	if phase != "running" or wave < 1 or _rewarded_waves.has(wave):
		return
	var completed_wave: int = wave
	_rewarded_waves[wave] = true
	phase = "between"
	battle_stats["waves_completed"] = wave
	last_wave_summary = {"wave":wave,"leaks":leaked_records.filter(func(record: Dictionary) -> bool: return record["wave"] == wave),"kills":_wave_kills,"total_kills":kills,"hp":base_hp}
	var harvest: int = wave_income()
	var bonus: int = wave_bonus()
	var income: int = harvest + bonus
	last_wave_reward = {"wave": wave, "bonus": bonus, "harvest": harvest, "total": income}
	supplies += income
	supplies_earned += income
	for placement in plants:
		var amount: int = plant_income(placement["kind"], placement["level"])
		if amount > 0:
			supplies_rewarded.emit(_plots[int(placement["slot"])], amount, "harvest")
			_roll_garden_coins(_plots[int(placement["slot"])], maxi(1, roundi(amount * 0.2)), "harvest")
	supplies_rewarded.emit(Vector2.ZERO, bonus, "wave")
	wave_finished.emit(income)
	if completed_wave >= total_waves:
		_finish_battle(true)
	else:
		changed.emit()


func _finish_battle(won: bool) -> void:
	if phase == "won" or phase == "lost":
		return
	phase = "won" if won else "lost"
	last_failure_hint = "" if won else _diagnose_failure()
	if won:
		var bonus: int = 35 + (stage - 1) * 10
		earned += bonus
		state.earn(bonus)
		discovery_reward = state.claim_stage_reward(stage).duplicate(true)
	_spawn_left = 0
	enemies.clear()
	changed.emit()
	battle_finished.emit(won)


func _position_on_path(distance: float) -> Vector2:
	var remaining: float = distance
	for i in range(_segments.size()):
		var length: float = _segments[i]
		if remaining <= length and length > 0.0:
			return _path[i].lerp(_path[i + 1], clampf(remaining / length, 0.0, 1.0))
		remaining -= length
	return _path[-1]


func preview_wave(wave_number: int = 0) -> Dictionary:
	var number: int = wave_number
	if number == 0:
		number = maxi(1,wave) if phase in ["running","won","lost"] else mini(wave + 1, total_waves)
	return Director.wave_plan(stage, number)


func forecast(wave_number: int = 0) -> Dictionary:
	return preview_wave(wave_number)


func enemy_info(kind: String, wave_number: int = 0) -> Dictionary:
	var number: int = wave_number if wave_number > 0 else int(preview_wave().get("wave",maxi(1,wave)))
	return Director.enemy_profile(kind,stage,number)


func set_target_mode(slot: int, mode: String) -> bool:
	if phase not in ["preparing", "running", "between"] or not TARGET_MODES.has(mode):
		return false
	var placement: Dictionary = get_plant(slot)
	if placement.is_empty() or state.plant_data(placement["kind"],placement["level"])["role"] != "defense":
		return false
	placement["target_mode"] = mode
	changed.emit()
	return true


static func target_mode_label(mode: String) -> String:
	return {"first":"Первые", "strong":"Сильные", "fast":"Быстрые"}.get(mode,"Первые")


func _choose_target(origin: Vector2, attack_range: float, mode: String) -> Dictionary:
	var chosen: Dictionary = {}
	var highest: float = -1.0
	var furthest: float = -1.0
	for enemy in enemies:
		if float(enemy["hp"]) <= 0.0 or bool(enemy.get("burrowed", false)) or origin.distance_to(enemy["position"]) > attack_range:
			continue
		var score: float = float(enemy["hp"]) if mode == "strong" else float(enemy["speed"]) if mode == "fast" else float(enemy["progress"])
		var progress: float = float(enemy["progress"])
		if score > highest or (is_equal_approx(score,highest) and progress > furthest):
			chosen = enemy
			highest = score
			furthest = progress
	return chosen


func _apply_slow(enemy: Dictionary, strength: float, duration: float) -> void:
	# Air is a movement silhouette, never a targeting immunity. Whiteflies keep
	# half of an incoming slow's strength; its advertised duration is unchanged.
	strength *= 1.0 - clampf(float(enemy.get("slow_resistance", 0.0)), 0.0, 1.0)
	var current: float = float(enemy.get("slow_strength",0.0)) if float(enemy.get("slow",0.0)) > 0.0 else 0.0
	if strength < current:
		return
	if strength > current:
		enemy["slow"] = duration
	else:
		enemy["slow"] = maxf(float(enemy.get("slow",0.0)),duration)
	enemy["slow_strength"] = clampf(strength,0.0,0.9)


func _record_purchase(kind: String, cost: int) -> void:
	battle_stats["spent"] = int(battle_stats.get("spent",0)) + cost
	var key: String = "income_spent" if state.plant_data(kind,1)["role"] == "income" else "defense_spent"
	battle_stats[key] = int(battle_stats.get(key,0)) + cost


func _record_leak(enemy: Dictionary, damage: int) -> void:
	var kind: String = String(enemy.get("kind","beetle"))
	leaked_records.append({"kind":kind,"wave":wave,"damage":damage,"position":enemy["position"]})
	var entry: Dictionary = leak_report.get(kind,{"count":0,"damage":0})
	entry["count"] += 1
	entry["damage"] += damage
	leak_report[kind] = entry
	battle_stats["base_damage"] = int(battle_stats.get("base_damage",0)) + damage
	battle_stats["leaked_by_kind"] = leak_report.duplicate(true)


func _diagnose_failure() -> String:
	if int(battle_stats.get("defense_spent",0)) == 0:
		return "Доходные посадки не атакуют. Начните с защитных пушек."
	var threat: String = ""
	var worst: int = -1
	for kind in leak_report:
		if int(leak_report[kind]["damage"]) > worst:
			worst = int(leak_report[kind]["damage"])
			threat = kind
	match threat:
		"aphid": return "Прорвался рой. Перекройте тропу огнём нескольких быстрых пушек." if stage == 1 else "Прорвался рой. Сочетайте групповой контроль с несколькими пушками."
		"whitefly": return "Белокрылки слабо поддаются замедлению. Добавьте быстрый огонь нескольких пушек."
		"leafroller": return "Листовой щит временный. Продлите обстрел или накройте его взрывом перца."
		"wireworm":
			return "Проволочники задержали ближние пушки. Разнесите защиту и оставьте дальний огонь." if int(battle_stats.get("enemy_disruptions", 0)) > 0 else "Прорвались проволочники. Усильте дальний огонь и перекройте выход."
		"healer": return "Прорвались лекари. Сосредоточьте огонь на поддержке и раненых целях."
		"burrower": return "Медведки прошли под землёй. Оставьте второй рубеж после выхода из нор."
		"soldier": return "Раненые солдаты ускорились. Добивайте их и добавьте замедление."
		"locust": return "Прорвались быстрые враги. Добавьте замедление и огонь у выхода."
		"snail", "queen": return "Прорвались крепкие цели. Нужны сильные удары и длинная зона обстрела."
	return "Проверьте покрытие тропы и достраивайте защиту на припасы волн."


func active_assault() -> int:
	if current_wave_plan.is_empty(): return 0
	var number: int = 1
	for assault in current_wave_plan.get("assaults", []):
		if float(assault["at"]) > _wave_elapsed + 0.000001: break
		number = int(assault["index"])
	return number


# Checkpoints contain built-in values only, never objects, scripts or signals.
# Validation happens on an isolated candidate before this live battle changes.
const SNAPSHOT_VERSION: int = 2
const SNAPSHOT_FIELDS: Array[String] = [
	"plants","loadout","loadout_ready","discovery_reward","last_wave_reward","_rewarded_waves",
	"enemies","shots","wave","total_waves","base_hp","phase","paused","speed","supplies",
	"supplies_earned","earned","kills","active_seconds","stage","spawned","enemy_total",
	"current_wave_plan","battle_stats","leaked_records","leak_report","last_failure_hint","last_wave_summary",
	"_spawn_left","_wave_elapsed","_time_accumulator","_spawn_schedule","_spawn_cursor","_wave_kills","_next_enemy_id",
]


func export_snapshot() -> Dictionary:
	if state == null or (phase == "between" and wave >= total_waves): return {}
	var values: Dictionary = {}
	for field in SNAPSHOT_FIELDS:
		var value = get(field)
		values[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	return {"version":SNAPSHOT_VERSION,"rules":_checkpoint_rules(),"geometry":_checkpoint_geometry(_path,_plots),"path":_path.duplicate(),"anchors":_plots.duplicate(),"rng_seed":reward_rng.seed,"rng_state":reward_rng.state,"values":values}


func restore_snapshot(garden: GardenState, path_points: Array[Vector2], plot_positions: Array[Vector2], payload: Dictionary) -> bool:
	if garden == null or path_points.size() < 2 or not _safe_checkpoint_value(payload) or var_to_bytes(payload).size() > 1000000: return false
	if not payload.get("version") is int or payload["version"] not in [1, SNAPSHOT_VERSION]: return false
	if not payload.get("rules") is String or payload["rules"] != _checkpoint_rules(): return false
	if not payload.get("geometry") is String: return false
	var saved_path: Array[Vector2] = []
	var saved_anchors: Array[Vector2] = []
	if payload["version"] == 1:
		# Existing attempts keep their exact old route and slot identities. Never
		# remap enemy progress or shots onto a redesigned new-attempt route.
		if not plot_positions.is_empty() and payload["geometry"] == _checkpoint_geometry(path_points,plot_positions):
			saved_path.assign(path_points)
			saved_anchors.assign(plot_positions)
		else:
			var legacy_path: Array[Vector2] = LegacyLayout.battle_route()
			var legacy_anchors: Array[Vector2] = LegacyLayout.battle_plots()
			if payload["geometry"] != _checkpoint_geometry(legacy_path,legacy_anchors): return false
			saved_path.assign(legacy_path)
			saved_anchors.assign(legacy_anchors)
	else:
		if not payload.get("path") is Array or not payload.get("anchors") is Array: return false
		for point in payload["path"]:
			if not point is Vector2: return false
			saved_path.append(point)
		for point in payload["anchors"]:
			if not point is Vector2: return false
			saved_anchors.append(point)
		if not _valid_checkpoint_geometry(saved_path,saved_anchors,path_points,plot_positions): return false
		if payload["geometry"] != _checkpoint_geometry(saved_path,saved_anchors): return false
	if not payload.get("rng_seed") is int or not payload.get("rng_state") is int or not payload.get("values") is Dictionary: return false
	var values: Dictionary = payload["values"]
	if values.size() != SNAPSHOT_FIELDS.size(): return false
	for field in SNAPSHOT_FIELDS:
		if not values.has(field): return false
	if not _checkpoint_integer(values["stage"],1,3) or not garden.is_stage_unlocked(int(values["stage"])): return false
	var candidate := BattleSim.new()
	candidate.configure(garden,saved_path,saved_anchors,int(values["stage"]))
	for field in SNAPSHOT_FIELDS:
		var expected_type: int = typeof(candidate.get(field))
		if typeof(values[field]) != expected_type:
			# Numeric counters remain integers; only clocks allow int literals.
			if expected_type != TYPE_FLOAT or not values[field] is int: return false
		var value = values[field]
		if expected_type == TYPE_ARRAY:
			for item in value:
				if not item is Dictionary: return false
			candidate.get(field).assign(value.duplicate(true))
		else:
			candidate.set(field,value.duplicate(true) if value is Dictionary else value)
	if not candidate._valid_checkpoint_state(): return false
	# The live instance is untouched until all structural and rule checks pass.
	configure(garden,saved_path,saved_anchors,int(values["stage"]))
	for field in SNAPSHOT_FIELDS:
		set(field,candidate.get(field))
	reward_rng.seed = payload["rng_seed"]
	reward_rng.state = payload["rng_state"]
	paused = true
	return true


static func _checkpoint_rules() -> String:
	return Director.RULE_SIGNATURE + ":" + var_to_bytes([Director.PLANS,Director.ASSAULT_PATTERNS,Director.WAVE_SPAWN_SECONDS,Director.ENEMIES,Catalog.PLANTS]).hex_encode().sha256_text()


static func _checkpoint_geometry(path_points: Array[Vector2], plot_positions: Array[Vector2]) -> String:
	return var_to_bytes([path_points,plot_positions]).hex_encode().sha256_text()


static func _valid_checkpoint_geometry(saved_path: Array[Vector2], saved_anchors: Array[Vector2], provided_path: Array[Vector2], provided_anchors: Array[Vector2]) -> bool:
	if saved_path.size() < 2 or saved_path.size() > 4096 or saved_anchors.size() > 1024: return false
	var supplied_route: bool = saved_path == provided_path
	var total: float = 0.0
	for index in range(saved_path.size()):
		var point: Vector2 = saved_path[index]
		if not point.is_finite() or absf(point.x) > 100000.0 or absf(point.y) > 100000.0: return false
		# Actual authored maps live in the board. Explicit matching custom
		# geometry remains usable by the deterministic ability/balance tests.
		if not supplied_route and not LegacyLayout.BOARD_RECT.grow(32).has_point(point): return false
		if index == 0: continue
		var length: float = point.distance_to(saved_path[index-1])
		if length <= 0.000001: return false
		total += length
	if total < 1.0 or total > (100000.0 if supplied_route else 10000.0): return false
	for index in range(saved_anchors.size()):
		var point: Vector2 = saved_anchors[index]
		if not point.is_finite(): return false
		if index < provided_anchors.size() and point == provided_anchors[index]: continue
		if not LegacyLayout.BOARD_RECT.encloses(Placement.footprint(point)): return false
	return true


static func _safe_checkpoint_value(value, depth: int = 0) -> bool:
	if depth > 12: return false
	match typeof(value):
		TYPE_NIL,TYPE_BOOL,TYPE_INT: return true
		TYPE_FLOAT: return is_finite(value)
		TYPE_STRING: return value.length() <= 2048
		TYPE_VECTOR2: return value.is_finite()
		TYPE_ARRAY:
			if value.size() > 4096: return false
			for item in value:
				if not _safe_checkpoint_value(item,depth + 1): return false
			return true
		TYPE_DICTIONARY:
			if value.size() > 4096: return false
			for key in value:
				if not (key is String or key is int) or not _safe_checkpoint_value(value[key],depth + 1): return false
			return true
	return false


static func _checkpoint_integer(value, low: int, high: int) -> bool:
	return value is int and value >= low and value <= high


static func _checkpoint_number(value, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high


func _valid_checkpoint_state() -> bool:
	if total_waves != Director.WAVE_COUNT or phase not in ["preparing","running","between","won","lost"]: return false
	if not _checkpoint_integer(wave,0,total_waves) or not _checkpoint_integer(base_hp,0,10): return false
	if (phase == "preparing") != (wave == 0): return false
	if phase == "between" and wave >= total_waves: return false
	if phase == "won" and (wave != total_waves or base_hp <= 0): return false
	if phase == "lost" and base_hp != 0: return false
	if phase in ["preparing","running","between"] and base_hp <= 0: return false
	for amount in [supplies,supplies_earned,earned,kills,spawned,enemy_total,_spawn_left,_spawn_cursor,_wave_kills]:
		if not _checkpoint_integer(amount,0,1000000): return false
	if not _checkpoint_integer(_next_enemy_id,1,1000000): return false
	if speed not in [1.0,2.0] or not _checkpoint_number(active_seconds,0.0,1000000.0): return false
	if not _checkpoint_number(_wave_elapsed,0.0,100000.0) or active_seconds + 0.000001 < _wave_elapsed: return false
	if not _checkpoint_number(_time_accumulator,0.0,MAX_CATCHUP_TIME): return false
	if supplies != STARTING_SUPPLIES + supplies_earned - int(battle_stats.get("spent",-1)): return false
	if loadout.size() > Catalog.ORDER.size() or plants.size() > _plots.size() or enemies.size() > 512 or shots.size() > 256: return false
	if loadout_ready != not loadout.is_empty() or (not loadout_ready and (not plants.is_empty() or wave > 0)): return false
	var templates: Dictionary = {}
	for planting in loadout:
		if not planting is Dictionary or not _valid_checkpoint_template(planting) or templates.has(planting["kind"]): return false
		templates[planting["kind"]] = planting
	var slots: Dictionary = {}
	for placement in plants:
		if not placement is Dictionary or not _checkpoint_integer(placement.get("slot"),0,_plots.size()-1): return false
		var slot: int = int(placement["slot"])
		var kind: String = str(placement.get("kind",""))
		if slots.has(slot) or not templates.has(kind): return false
		slots[slot] = true
		if not _checkpoint_integer(placement.get("level"),1,20) or not placement.get("source_id") is String: return false
		if placement["level"] != templates[kind]["level"] or placement["source_id"] != templates[kind]["source_id"]: return false
		if not placement.get("target_mode") in TARGET_MODES: return false
		if not _checkpoint_number(placement.get("cooldown"),0.0,30.0) or not _checkpoint_number(placement.get("jammed"),0.0,1.21): return false
		if not _checkpoint_number(placement.get("jam_flash"),0.0,2.0) or not _checkpoint_integer(placement.get("jam_source"),-1,_next_enemy_id-1): return false
	var plan: Dictionary = Director.wave_plan(stage,wave) if wave > 0 else {}
	if current_wave_plan != plan: return false
	var expected_schedule: Array[Dictionary] = []
	var at: float = 0.0
	for group in plan.get("groups",[]):
		at += float(group["delay"])
		for index in range(int(group["count"])):
			if index > 0: at += float(group["interval"])
			expected_schedule.append({"at":at,"kind":group["kind"],"assault":group.get("assault",1)})
	if _spawn_schedule != expected_schedule: return false
	if enemy_total != expected_schedule.size() or _spawn_cursor != spawned or _spawn_cursor > enemy_total or _wave_kills > kills: return false
	if phase not in ["won","lost"] and _spawn_left != enemy_total - _spawn_cursor: return false
	if phase in ["won","lost"] and (_spawn_left != 0 or not enemies.is_empty()): return false
	if phase in ["preparing","between"] and not enemies.is_empty(): return false
	var completed: int = wave - 1 if phase in ["running","lost"] else wave
	if _rewarded_waves.size() != completed: return false
	for number in range(1,completed+1):
		if not _rewarded_waves.get(number) is bool or not _rewarded_waves[number]: return false
	var ids: Dictionary = {}
	for enemy in enemies:
		if not enemy is Dictionary or not _valid_checkpoint_enemy(enemy) or ids.has(enemy["id"]): return false
		ids[enemy["id"]] = true
	for shot in shots:
		if not shot is Dictionary or not shot.get("from") is Vector2 or not shot.get("to") is Vector2: return false
		if not templates.has(shot.get("kind")) or not _checkpoint_number(shot.get("life"),0.0,0.18): return false
		if not _checkpoint_integer(shot.get("level"),1,20): return false
	for field in ["spent","income_spent","defense_spent","base_damage","waves_completed","enemy_disruptions"]:
		if not _checkpoint_integer(battle_stats.get(field),0,1000000): return false
	if int(battle_stats["spent"]) != int(battle_stats["income_spent"]) + int(battle_stats["defense_spent"]): return false
	if battle_stats.get("leaked_by_kind") != leak_report: return false
	if battle_stats["waves_completed"] != completed or not _checkpoint_number(battle_stats.get("enemy_healing"),0.0,100000000.0): return false
	for field in ["damage_by_kind","kills_by_kind","leaked_by_kind"]:
		if not battle_stats.get(field) is Dictionary: return false
	for kind in battle_stats["damage_by_kind"]:
		if not Catalog.PLANTS.has(kind) or not _checkpoint_number(battle_stats["damage_by_kind"][kind],0.0,100000000.0): return false
	for kind in battle_stats["kills_by_kind"]:
		if not Director.ENEMIES.has(kind) or not _checkpoint_integer(battle_stats["kills_by_kind"][kind],0,1000000): return false
	for kind in leak_report:
		if not Director.ENEMIES.has(kind) or not leak_report[kind] is Dictionary: return false
		if not _checkpoint_integer(leak_report[kind].get("count"),0,1000000) or not _checkpoint_integer(leak_report[kind].get("damage"),0,1000000): return false
	for record in leaked_records:
		if not record is Dictionary or not Director.ENEMIES.has(record.get("kind")): return false
		if not _checkpoint_integer(record.get("damage"),1,3) or not _checkpoint_integer(record.get("wave"),1,wave): return false
	if (completed > 0) != not last_wave_reward.is_empty(): return false
	if not last_wave_reward.is_empty():
		for key in ["wave","harvest","bonus","total"]:
			if not _checkpoint_integer(last_wave_reward.get(key),0,1000000): return false
		if last_wave_reward["wave"] != completed or last_wave_reward["bonus"] != wave_bonus(completed) or last_wave_reward["total"] != last_wave_reward["bonus"] + last_wave_reward["harvest"]: return false
	return true


func _valid_checkpoint_template(planting: Dictionary) -> bool:
	var kind: String = str(planting.get("kind",""))
	if not Catalog.PLANTS.has(kind) or not state.is_seed_unlocked(kind) or not _checkpoint_integer(planting.get("level"),1,20): return false
	var area: String = str(planting.get("area",""))
	var slot = planting.get("slot")
	if area not in ["home","nursery","pond"] or not _checkpoint_integer(slot,0,state.plot_count(area)-1): return false
	# Retired areas still own their paid plants. Their preserved sources can
	# resume an existing battle without reopening the retired planting ground.
	if not state.is_plot_unlocked(area,int(slot)) and state.plot_data(area,int(slot)).is_empty(): return false
	for key in ["source_id","id","role","name","habitat"]:
		if not planting.get(key) is String: return false
	if not _checkpoint_integer(planting.get("cost"),0,100000): return false
	if planting["source_id"] != "%s:%d" % [area,int(slot)] or planting["id"] != kind: return false
	var data: Dictionary = state.plant_data(kind,int(planting["level"]))
	return planting.get("cost") == data["battle_cost"] and planting.get("role") == data["role"] and planting.get("name") == data["name"] and planting.get("habitat") == data.get("habitat","dry") and ((area == "pond") == (data.get("habitat","dry") == "water"))


func _valid_checkpoint_enemy(enemy: Dictionary) -> bool:
	var kind: String = str(enemy.get("kind",""))
	if not Director.ENEMIES.has(kind) or not _checkpoint_integer(enemy.get("id"),1,_next_enemy_id-1) or not _checkpoint_integer(enemy.get("assault"),1,6): return false
	var profile: Dictionary = Director.enemy_profile(kind,stage,wave,int(enemy["assault"]))
	for key in ["max_hp","armor","leak_damage","reward"]:
		var profile_key: String = "hp" if key == "max_hp" else key
		if not _checkpoint_number(enemy.get(key),0.0,1000000.0) or enemy[key] != profile[profile_key]: return false
	if not _checkpoint_number(enemy.get("hp"),0.0,float(profile["hp"])) or not enemy.get("position") is Vector2: return false
	if not _checkpoint_number(enemy.get("progress"),0.0,path_length) or not Vector2(enemy["position"]).is_equal_approx(_position_on_path(float(enemy["progress"]))): return false
	for key in ["rewarded","burrowed","enraged","leaf_shield_used"]:
		if not enemy.get(key) is bool: return false
	if bool(enemy["rewarded"]) != (float(enemy["hp"]) <= 0.0): return false
	for key in ["slow","slow_strength","hit","born_at","age","heal_cooldown","heal_pulse","healed","phase_flash","rage_flash","leaf_shield","shield_flash","disruption_cooldown","disruption_pulse"]:
		if not _checkpoint_number(enemy.get(key),0.0,100000.0): return false
	if float(enemy["slow_strength"]) > 1.0 or float(enemy["leaf_shield"]) > 3.01 or float(enemy["born_at"]) > _wave_elapsed + 0.000001: return false
	var expected_speed: float = float(profile["speed"]) * (float(profile.get("frenzy_multiplier",1.0)) if bool(enemy["enraged"]) else 1.0)
	if not _checkpoint_number(enemy.get("speed"),0.0,1000.0) or not is_equal_approx(float(enemy["speed"]),expected_speed): return false
	for key in ["heal_interval","heal_radius","heal_amount","heal_targets","burrow_cycle","burrow_duration","burrow_first","frenzy_threshold","frenzy_multiplier","slow_resistance","leaf_shield_threshold","leaf_shield_duration","leaf_shield_reduction","disruption_interval","disruption_radius","disruption_duration","disruption_targets"]:
		var default_value: float = 1.0 if key == "frenzy_multiplier" else 0.0
		if not _checkpoint_number(enemy.get(key),0.0,1000000.0) or enemy[key] != profile.get(key,default_value): return false
	return enemy.get("mobility") is String and enemy["mobility"] == profile.get("mobility","ground") and _checkpoint_integer(enemy.get("disruption_target_slot"),-1,_plots.size()-1)
