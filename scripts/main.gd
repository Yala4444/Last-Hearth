extends Node2D

const VIEW_SIZE := Vector2(480.0, 800.0)
const HEARTH_POS := Vector2(240.0, 410.0)
const HUB_MAP_POS := Vector2(240.0, 160.0)
const HUB_CARRY_POS := Vector2(115.0, 430.0)
const HUB_DAMAGE_POS := Vector2(365.0, 430.0)
const HUB_HEARTH_UPGRADE_POS := Vector2(240.0, 590.0)

const HERO_SPEED := 178.0
const HERO_INTERACT_RADIUS := 46.0
const HERO_PICKUP_RADIUS := 34.0
const JOYSTICK_RADIUS := 64.0
const JOYSTICK_DEADZONE := 0.10
const TWILIGHT_DURATION := 3.4
const UNLOAD_INTERVAL := 0.16
const SAVE_PATH := "user://hearth_meta.json"

enum Mode {
	HUB,
	EXPEDITION,
	RESULT
}

enum Stage {
	DAY1_GATHER,
	DAY1_RESCUE,
	NIGHT1,
	DAY2_BUILD,
	WORKSHOP_CHOICE,
	DAY2_RESCUE,
	NIGHT2,
	DAY3_TOWER,
	EXPEDITION_CHOICE,
	NIGHT3,
	CORE_RETURN
}

var rng := RandomNumberGenerator.new()
var font: Font

var mode: Mode = Mode.HUB
var stage: Stage = Stage.DAY1_GATHER
var result_win := false

var meta: Dictionary = {
	"first_run": true,
	"embers": 0,
	"carry_level": 0,
	"damage_level": 0,
	"hearth_bonus": 0,
	"attempts": 0,
	"forest_cleared": false,
	"hearth_rank": 1
}

var hero_pos := Vector2(240.0, 650.0)
var hero_target := Vector2(240.0, 650.0)
var hero_walk_phase := 0.0
var hero_facing := Vector2(1.0, 0.0)
var hero_damage := 22.0
var hero_fire_rate := 0.52
var hero_shot_cd := 0.0
var gather_cd := 0.0
var gather_interval := 0.42
var carry_limit := 5
var carried_wood := 0
var carried_stone := 0

var camp_wood := 0
var camp_stone := 0
var survivors := 1
var survivor_agents: Array[Dictionary] = []
var hearth_level := 1
var hearth_hp := 150.0
var hearth_max_hp := 150.0
var light_radius := 165.0
var workshop_built := false
var workshop_choice := ""
var tower_built := false
var tower_cd := 0.0
var expedition_choice := ""
var run_embers := 0
var current_night := 0
var run_seed := 0

var resource_nodes: Array[Dictionary] = []
var resource_pickups: Array[Dictionary] = []
var resource_flights: Array[Dictionary] = []
var pickup_cd := 0.0
var unload_cd := 0.0
var unload_active := false
var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var floaters: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var night_queue: Array[String] = []
var night_spawn_cd := 0.0
var twilight_timer := 0.0
var camera_shake := 0.0
var hearth_pulse := 0.0
var decor_points: Array[Dictionary] = []

var survivor_one_pos := Vector2.ZERO
var survivor_two_pos := Vector2.ZERO
var survivor_one_found := false
var survivor_two_found := false

var left_choice_pos := Vector2(145.0, 250.0)
var right_choice_pos := Vector2(335.0, 250.0)

var core_active := false
var core_carried := false
var core_pos := Vector2.ZERO

var joystick_active := false
var joystick_origin := Vector2.ZERO
var joystick_knob := Vector2.ZERO
var joystick_vector := Vector2.ZERO
var joystick_touch_index := -1
var mouse_dragging := false

var banner_text := ""
var banner_timer := 0.0
var flash_timer := 0.0
var hub_zone_lock := ""
var result_title := ""
var result_subtitle := ""


func _ready() -> void:
	font = ThemeDB.fallback_font
	rng.randomize()
	_load_meta()
	if bool(meta.get("first_run", true)):
		meta["first_run"] = false
		_save_meta()
		_start_expedition()
	else:
		_enter_hub("Последний Очаг ждёт тебя.")
	queue_redraw()


func _process(delta: float) -> void:
	banner_timer = maxf(0.0, banner_timer - delta)
	flash_timer = maxf(0.0, flash_timer - delta)
	hero_shot_cd = maxf(0.0, hero_shot_cd - delta)
	gather_cd = maxf(0.0, gather_cd - delta)
	pickup_cd = maxf(0.0, pickup_cd - delta)
	unload_cd = maxf(0.0, unload_cd - delta)
	tower_cd = maxf(0.0, tower_cd - delta)
	camera_shake = maxf(0.0, camera_shake - delta * 8.0)
	hearth_pulse = maxf(0.0, hearth_pulse - delta * 2.5)
	_update_resource_flights(delta)

	if mode == Mode.HUB:
		_update_movement(delta)
		_update_hub_interactions()
	elif mode == Mode.EXPEDITION:
		_update_movement(delta)
		_update_expedition(delta)

	_update_particles(delta)
	_update_floaters(delta)
	queue_redraw()


func _load_meta() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		var saved: Dictionary = parsed
		for key: Variant in saved.keys():
			meta[key] = saved[key]


func _save_meta() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(meta))


func _enter_hub(message: String = "") -> void:
	mode = Mode.HUB
	hero_pos = Vector2(240.0, 690.0)
	hero_target = hero_pos
	_stop_joystick()
	enemies.clear()
	shots.clear()
	resource_nodes.clear()
	resource_pickups.clear()
	resource_flights.clear()
	decor_points.clear()
	core_active = false
	core_carried = false
	hub_zone_lock = ""
	if message != "":
		_banner(message, 2.4)


func _start_expedition() -> void:
	mode = Mode.EXPEDITION
	stage = Stage.DAY1_GATHER
	meta["attempts"] = int(meta.get("attempts", 0)) + 1
	_save_meta()

	run_seed = rng.randi()
	rng.seed = run_seed

	hero_pos = Vector2(rng.randf_range(175.0, 305.0), rng.randf_range(640.0, 700.0))
	hero_target = hero_pos
	hero_walk_phase = 0.0
	hero_facing = Vector2(1.0, 0.0)
	hero_damage = 22.0 * (1.0 + 0.10 * float(int(meta.get("damage_level", 0))))
	hero_fire_rate = 0.52
	hero_shot_cd = 0.0
	gather_interval = 0.42
	gather_cd = 0.0
	carry_limit = 5 + int(meta.get("carry_level", 0))
	carried_wood = 0
	carried_stone = 0

	camp_wood = 0
	camp_stone = 0
	survivors = 1
	survivor_agents.clear()
	hearth_level = 1
	var permanent_hearth := int(meta.get("hearth_bonus", 0))
	hearth_max_hp = 150.0 + float(permanent_hearth) * 18.0
	hearth_hp = hearth_max_hp
	light_radius = 165.0 + float(permanent_hearth) * 8.0
	workshop_built = false
	workshop_choice = ""
	tower_built = false
	tower_cd = 0.0
	expedition_choice = ""
	run_embers = 0
	current_night = 0

	enemies.clear()
	shots.clear()
	floaters.clear()
	particles.clear()
	resource_pickups.clear()
	resource_flights.clear()
	pickup_cd = 0.0
	unload_cd = 0.0
	unload_active = false
	night_queue.clear()
	twilight_timer = 0.0
	camera_shake = 0.0
	hearth_pulse = 0.0
	core_active = false
	core_carried = false
	survivor_one_found = false
	survivor_two_found = false
	_stop_joystick()

	_generate_layout()
	_banner("Вылазка #%d · Забытый лес" % int(meta.get("attempts", 1)), 2.2)


func _generate_layout() -> void:
	resource_nodes.clear()
	var tree_slots: Array[Vector2] = [
		Vector2(95, 235), Vector2(175, 205), Vector2(290, 210), Vector2(385, 240),
		Vector2(80, 360), Vector2(400, 355), Vector2(105, 560), Vector2(385, 565),
		Vector2(175, 620), Vector2(315, 620), Vector2(70, 690), Vector2(410, 685)
	]
	var rock_slots: Array[Vector2] = [
		Vector2(125, 290), Vector2(355, 300), Vector2(135, 510),
		Vector2(345, 505), Vector2(235, 655), Vector2(420, 455)
	]

	for i in range(9):
		var index: int = rng.randi_range(0, tree_slots.size() - 1)
		var base: Vector2 = tree_slots[index]
		tree_slots.remove_at(index)
		var pos := base + Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(-14.0, 14.0))
		resource_nodes.append({
			"kind": "tree",
			"pos": pos,
			"hits": 3,
			"max_hits": 3,
			"alive": true,
			"fall_timer": 0.0,
			"drop_spawned": false
		})

	for i in range(5):
		var index: int = rng.randi_range(0, rock_slots.size() - 1)
		var base: Vector2 = rock_slots[index]
		rock_slots.remove_at(index)
		var pos := base + Vector2(rng.randf_range(-15.0, 15.0), rng.randf_range(-12.0, 12.0))
		resource_nodes.append({
			"kind": "rock",
			"pos": pos,
			"hits": 4,
			"max_hits": 4,
			"alive": true,
			"fall_timer": 0.0,
			"drop_spawned": false
		})

	decor_points.clear()
	for i in range(46):
		var dpos := Vector2(rng.randf_range(28.0, 452.0), rng.randf_range(128.0, 770.0))
		if dpos.distance_to(HEARTH_POS) < 82.0:
			continue
		var roll := rng.randf()
		var kind := "grass"
		if roll > 0.72:
			kind = "pebble"
		if roll > 0.90:
			kind = "branch"
		decor_points.append({
			"pos": dpos,
			"kind": kind,
			"scale": rng.randf_range(0.75, 1.25)
		})

	var rescue_slots: Array[Vector2] = [
		Vector2(95, 180), Vector2(380, 185), Vector2(80, 520), Vector2(400, 525)
	]
	var first_index: int = rng.randi_range(0, rescue_slots.size() - 1)
	survivor_one_pos = rescue_slots[first_index] + Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-10.0, 10.0))
	rescue_slots.remove_at(first_index)
	var second_index: int = rng.randi_range(0, rescue_slots.size() - 1)
	survivor_two_pos = rescue_slots[second_index] + Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-10.0, 10.0))

	if rng.randf() < 0.5:
		left_choice_pos = Vector2(130.0, 285.0)
		right_choice_pos = Vector2(350.0, 285.0)
	else:
		left_choice_pos = Vector2(125.0, 540.0)
		right_choice_pos = Vector2(355.0, 540.0)


func _update_movement(delta: float) -> void:
	var movement := Vector2.ZERO
	var strength := 0.0

	if joystick_active and joystick_vector.length() > JOYSTICK_DEADZONE:
		strength = clampf(joystick_vector.length(), 0.0, 1.0)
		movement = joystick_vector.normalized() * HERO_SPEED * strength
	else:
		var to_target := hero_target - hero_pos
		if to_target.length() > 3.0:
			movement = to_target.normalized() * HERO_SPEED

	if movement.length() > 0.0:
		hero_facing = movement.normalized()
		hero_pos += movement * delta
		hero_pos.x = clampf(hero_pos.x, 22.0, VIEW_SIZE.x - 22.0)
		hero_pos.y = clampf(hero_pos.y, 118.0, VIEW_SIZE.y - 24.0)
		hero_walk_phase += delta * (6.0 + strength * 5.0)


func _update_hub_interactions() -> void:
	var near_map := hero_pos.distance_to(HUB_MAP_POS) < 54.0
	var near_carry := hero_pos.distance_to(HUB_CARRY_POS) < 48.0
	var near_damage := hero_pos.distance_to(HUB_DAMAGE_POS) < 48.0
	var near_hearth := hero_pos.distance_to(HUB_HEARTH_UPGRADE_POS) < 46.0

	if not near_map and not near_carry and not near_damage and not near_hearth:
		hub_zone_lock = ""

	if near_map and hub_zone_lock != "map":
		hub_zone_lock = "map"
		_start_expedition()
		return

	if near_carry and hub_zone_lock != "carry":
		hub_zone_lock = "carry"
		var level := int(meta.get("carry_level", 0))
		var cost := 3 + level * 2
		if int(meta.get("embers", 0)) >= cost:
			meta["embers"] = int(meta.get("embers", 0)) - cost
			meta["carry_level"] = level + 1
			_save_meta()
			_banner("Склад улучшен · перенос +1", 2.0)
		else:
			_banner("Для склада нужно %d углей" % cost, 1.7)

	if near_damage and hub_zone_lock != "damage":
		hub_zone_lock = "damage"
		var level := int(meta.get("damage_level", 0))
		var cost := 4 + level * 3
		if int(meta.get("embers", 0)) >= cost:
			meta["embers"] = int(meta.get("embers", 0)) - cost
			meta["damage_level"] = level + 1
			_save_meta()
			_banner("Кузница усилена · урон +10%", 2.0)
		else:
			_banner("Для кузницы нужно %d углей" % cost, 1.7)

	if near_hearth and hub_zone_lock != "hearth":
		hub_zone_lock = "hearth"
		var level := int(meta.get("hearth_bonus", 0))
		var cost := 5 + level * 4
		if level >= 3:
			_banner("Очаг уже усилен до предела этой главы", 1.9)
		elif int(meta.get("embers", 0)) >= cost:
			meta["embers"] = int(meta.get("embers", 0)) - cost
			meta["hearth_bonus"] = level + 1
			_save_meta()
			hearth_pulse = 1.0
			camera_shake = 2.0
			_banner("Сердце Очагa усилено · больше света и прочности", 2.3)
		else:
			_banner("Для Очагa нужно %d углей" % cost, 1.7)


func _update_expedition(delta: float) -> void:
	_deposit_resources_if_close(delta)
	_update_resource_gathering()
	_update_resource_pickups(delta)
	_update_survivor_agents(delta)

	if enemies.size() > 0:
		_update_combat()
		_update_shots(delta)
		_update_enemies(delta)
		if tower_built:
			_update_tower()

	match stage:
		Stage.DAY1_RESCUE:
			if hero_pos.distance_to(survivor_one_pos) < 42.0:
				survivor_one_found = true
				_add_survivor("hunter", survivor_one_pos)
				_banner("Охотник присоединился и идёт к огню", 2.0)
				_start_night(1)
		Stage.WORKSHOP_CHOICE:
			_update_workshop_choice()
		Stage.DAY2_RESCUE:
			if enemies.is_empty() and hero_pos.distance_to(survivor_two_pos) < 44.0:
				survivor_two_found = true
				_add_survivor("worker", survivor_two_pos)
				_banner("Рабочий спасён и возвращается в лагерь", 2.0)
				_start_night(2)
		Stage.EXPEDITION_CHOICE:
			_update_expedition_choice()
		Stage.NIGHT1, Stage.NIGHT2, Stage.NIGHT3:
			_update_night_spawner(delta)
		Stage.CORE_RETURN:
			_update_core_return()

	if hearth_hp <= 0.0:
		_finish_run(false)


func _update_resource_gathering() -> void:
	if stage in [Stage.NIGHT1, Stage.NIGHT2, Stage.NIGHT3, Stage.CORE_RETURN]:
		return
	if gather_cd > 0.0:
		return

	for i in range(resource_nodes.size()):
		var node: Dictionary = resource_nodes[i]
		if not bool(node.get("alive", false)):
			continue
		var node_pos: Vector2 = node["pos"]
		if hero_pos.distance_to(node_pos) > HERO_INTERACT_RADIUS:
			continue

		var kind := String(node.get("kind", "tree"))
		if stage in [Stage.DAY1_GATHER, Stage.DAY1_RESCUE] and kind != "tree":
			continue

		var hits := int(node.get("hits", 1)) - 1
		node["hits"] = hits
		gather_cd = gather_interval
		_burst(node_pos, 5)

		if hits > 0:
			var action_text := "РУБИМ" if kind == "tree" else "ДОБЫВАЕМ"
			_float_text(node_pos + Vector2(0, -24), action_text, Color(0.86, 0.78, 0.62))
		else:
			node["alive"] = false
			node["fall_timer"] = 0.34 if kind == "tree" else 0.16
			node["drop_spawned"] = false
			_burst(node_pos, 14)
			_float_text(
				node_pos + Vector2(0, -25),
				"ДЕРЕВО ПАДАЕТ" if kind == "tree" else "КАМЕНЬ РАСКОЛОТ",
				Color(0.95, 0.76, 0.42) if kind == "tree" else Color(0.75, 0.80, 0.84)
			)

		resource_nodes[i] = node
		break


func _update_resource_pickups(delta: float) -> void:
	for i in range(resource_nodes.size()):
		var node: Dictionary = resource_nodes[i]
		if bool(node.get("alive", true)):
			continue
		if bool(node.get("drop_spawned", true)):
			continue

		var timer := maxf(0.0, float(node.get("fall_timer", 0.0)) - delta)
		node["fall_timer"] = timer
		if timer <= 0.0:
			node["drop_spawned"] = true
			_spawn_resource_drops(String(node.get("kind", "tree")), node["pos"])
		resource_nodes[i] = node

	if pickup_cd > 0.0:
		return
	if carried_wood + carried_stone >= carry_limit:
		return

	var nearest_index := -1
	var nearest_distance := INF
	for i in range(resource_pickups.size()):
		var pickup: Dictionary = resource_pickups[i]
		var pickup_pos: Vector2 = pickup["pos"]
		var distance := hero_pos.distance_to(pickup_pos)
		if distance <= HERO_PICKUP_RADIUS and distance < nearest_distance:
			nearest_distance = distance
			nearest_index = i

	if nearest_index < 0:
		return

	var pickup: Dictionary = resource_pickups[nearest_index]
	var kind := String(pickup.get("kind", "wood"))
	var pickup_pos: Vector2 = pickup["pos"]
	if kind == "wood":
		carried_wood += 1
	else:
		carried_stone += 1

	resource_flights.append({
		"kind": kind,
		"mode": "pickup",
		"from": pickup_pos,
		"to": hero_pos,
		"t": 0.0,
		"duration": 0.24
	})
	_burst(pickup_pos, 4)
	resource_pickups.remove_at(nearest_index)
	pickup_cd = 0.11


func _update_resource_flights(delta: float) -> void:
	for i in range(resource_flights.size() - 1, -1, -1):
		var flight: Dictionary = resource_flights[i]
		var duration := maxf(0.01, float(flight.get("duration", 0.24)))
		var t := float(flight.get("t", 0.0)) + delta / duration
		flight["t"] = t
		resource_flights[i] = flight
		if t >= 1.0:
			resource_flights.remove_at(i)


func _spawn_resource_drops(source_kind: String, source_pos: Vector2) -> void:
	var drop_kind := "wood" if source_kind == "tree" else "stone"
	var count := 3
	for i in range(count):
		var angle := -0.95 + float(i) * 0.95 + rng.randf_range(-0.16, 0.16)
		var distance := rng.randf_range(22.0, 36.0)
		resource_pickups.append({
			"kind": drop_kind,
			"pos": source_pos + Vector2(cos(angle), sin(angle)) * distance,
			"spin": rng.randf_range(-0.22, 0.22)
		})


func _deposit_resources_if_close(delta: float) -> void:
	var near_hearth := hero_pos.distance_to(HEARTH_POS) <= 70.0
	if not near_hearth:
		unload_active = false
		unload_cd = 0.0
		return

	if carried_wood <= 0 and carried_stone <= 0:
		unload_active = false
		return

	unload_active = true
	unload_cd -= delta
	if unload_cd > 0.0:
		return

	var kind := "wood" if carried_wood > 0 else "stone"
	if kind == "wood":
		carried_wood -= 1
		camp_wood += 1
	else:
		carried_stone -= 1
		camp_stone += 1

	resource_flights.append({
		"kind": kind,
		"mode": "unload",
		"from": hero_pos + Vector2(0, -16),
		"to": HEARTH_POS + Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(-10.0, 12.0)),
		"t": 0.0,
		"duration": 0.22
	})
	hearth_pulse = minf(1.0, hearth_pulse + 0.18)
	_burst(HEARTH_POS + Vector2(rng.randf_range(-12.0, 12.0), 4), 3)
	unload_cd = UNLOAD_INTERVAL
	_check_day_progress()


func _check_day_progress() -> void:
	if stage == Stage.DAY1_GATHER and camp_wood >= 5:
		camp_wood -= 5
		hearth_level = 2
		hearth_max_hp = 170.0
		hearth_hp = hearth_max_hp
		light_radius = 225.0
		stage = Stage.DAY1_RESCUE
		flash_timer = 0.75
		hearth_pulse = 1.0
		camera_shake = 4.0
		_banner("ОЧАГ II · свет открыл новую часть леса", 2.4)

	elif stage == Stage.DAY2_BUILD and camp_wood >= 8 and camp_stone >= 5:
		camp_wood -= 8
		camp_stone -= 5
		workshop_built = true
		stage = Stage.WORKSHOP_CHOICE
		light_radius = 255.0
		flash_timer = 0.55
		camera_shake = 2.0
		_banner("Мастерская восстановлена · выбери специализацию", 2.1)

	elif stage == Stage.DAY3_TOWER and camp_wood >= 6 and camp_stone >= 6:
		camp_wood -= 6
		camp_stone -= 6
		tower_built = true
		stage = Stage.EXPEDITION_CHOICE
		light_radius = 300.0
		flash_timer = 0.55
		camera_shake = 2.2
		_banner("Башня готова · лагерь защищён лучше", 2.1)


func _update_workshop_choice() -> void:
	if hero_pos.distance_to(left_choice_pos) < 48.0:
		workshop_choice = "armory"
		hero_damage *= 1.28
		stage = Stage.DAY2_RESCUE
		_spawn_rescue_guards()
		_banner("Оружейник · урон +28%", 2.0)
	elif hero_pos.distance_to(right_choice_pos) < 48.0:
		workshop_choice = "lumber"
		carry_limit += 2
		gather_interval = 0.30
		stage = Stage.DAY2_RESCUE
		_spawn_rescue_guards()
		_banner("Лесопилка · перенос +2", 2.0)


func _spawn_rescue_guards() -> void:
	for offset: Vector2 in [Vector2(-42, 10), Vector2(38, -18), Vector2(8, 46)]:
		_spawn_enemy_at("guard", survivor_two_pos + offset)


func _update_expedition_choice() -> void:
	if hero_pos.distance_to(left_choice_pos) < 50.0:
		expedition_choice = "people"
		_add_survivor("guard", left_choice_pos + Vector2(-20, 16))
		_add_survivor("guard", left_choice_pos + Vector2(20, 16))
		_banner("Два бойца вышли к свету", 2.0)
		_start_night(3)
	elif hero_pos.distance_to(right_choice_pos) < 50.0:
		expedition_choice = "damage"
		hero_damage *= 1.60
		_banner("Огненная метка · урон +60%", 2.0)
		_start_night(3)


func _start_night(number: int) -> void:
	current_night = number
	night_queue.clear()
	night_spawn_cd = 0.55
	twilight_timer = TWILIGHT_DURATION
	hearth_hp = hearth_max_hp

	if number == 1:
		stage = Stage.NIGHT1
		for i in range(8):
			night_queue.append("basic")
		night_queue.append("guard")
		_banner("СУМЕРКИ · охотник занимает позицию", 2.5)
	elif number == 2:
		stage = Stage.NIGHT2
		for i in range(9):
			night_queue.append("fast" if i % 3 == 2 else "basic")
		night_queue.append("elite")
		_banner("СУМЕРКИ · вернись к свету", 2.5)
	else:
		stage = Stage.NIGHT3
		for i in range(12):
			if i % 4 == 2:
				night_queue.append("fast")
			else:
				night_queue.append("basic")
		night_queue.append("boss")
		_banner("СУМЕРКИ · лес вокруг Очагa замолчал", 2.8)


func _update_night_spawner(delta: float) -> void:
	if twilight_timer > 0.0:
		twilight_timer = maxf(0.0, twilight_timer - delta)
		if twilight_timer <= 0.0:
			_banner("НОЧЬ %d · защити Последний Очаг" % current_night, 2.0)
			camera_shake = 1.5
		return

	night_spawn_cd -= delta
	if night_queue.size() > 0 and night_spawn_cd <= 0.0:
		var kind: String = night_queue.pop_front()
		_spawn_enemy(kind)
		if kind == "boss":
			night_spawn_cd = 2.0
		else:
			night_spawn_cd = 0.72 if current_night >= 2 else 0.95

	if night_queue.is_empty() and enemies.is_empty():
		if current_night == 1:
			_complete_night_one()
		elif current_night == 2:
			_complete_night_two()


func _complete_night_one() -> void:
	run_embers += 1
	hearth_level = 3
	hearth_max_hp = 185.0
	hearth_hp = hearth_max_hp
	light_radius = 250.0
	stage = Stage.DAY2_BUILD
	flash_timer = 0.45
	_banner("Утро · найден камень и руины мастерской", 2.4)


func _complete_night_two() -> void:
	run_embers += 2
	hearth_level = 4
	hearth_max_hp = 215.0
	hearth_hp = hearth_max_hp
	light_radius = 285.0
	stage = Stage.DAY3_TOWER
	flash_timer = 0.45
	_banner("Утро · восстанови сторожевую башню", 2.4)


func _spawn_enemy(kind: String) -> void:
	var side := rng.randi_range(0, 3)
	var pos := Vector2.ZERO
	if side == 0:
		pos = Vector2(rng.randf_range(20.0, 460.0), 105.0)
	elif side == 1:
		pos = Vector2(465.0, rng.randf_range(145.0, 735.0))
	elif side == 2:
		pos = Vector2(rng.randf_range(20.0, 460.0), 755.0)
	else:
		pos = Vector2(15.0, rng.randf_range(145.0, 735.0))
	_spawn_enemy_at(kind, pos)


func _spawn_enemy_at(kind: String, pos: Vector2) -> void:
	var hp := 52.0
	var speed := 39.0
	var damage := 8.0
	var radius := 14.0

	match kind:
		"fast":
			hp = 38.0
			speed = 68.0
			damage = 7.0
			radius = 11.0
		"elite":
			hp = 210.0
			speed = 31.0
			damage = 13.0
			radius = 20.0
		"boss":
			hp = 720.0
			speed = 21.0
			damage = 18.0
			radius = 32.0
		"guard":
			hp = 58.0
			speed = 34.0
			damage = 7.0
			radius = 13.0

	enemies.append({
		"kind": kind,
		"pos": pos,
		"hp": hp,
		"max_hp": hp,
		"speed": speed,
		"damage": damage,
		"radius": radius,
		"hit_cd": 0.0,
		"hit_flash": 0.0
	})


func _add_survivor(role: String, spawn_pos: Vector2) -> void:
	var index := survivor_agents.size()
	survivor_agents.append({
		"role": role,
		"pos": spawn_pos,
		"phase": float(index) * 1.7,
		"shot_cd": rng.randf_range(0.08, 0.35)
	})
	survivors = 1 + survivor_agents.size()
	_burst(spawn_pos, 8)


func _survivor_day_target(index: int, role: String) -> Vector2:
	if role == "hunter":
		return HEARTH_POS + Vector2(-84.0, 54.0)
	if role == "worker":
		return HEARTH_POS + (Vector2(-110.0, -48.0) if workshop_built else Vector2(88.0, 60.0))

	var guard_slots: Array[Vector2] = [
		Vector2(96, -54), Vector2(112, 36), Vector2(70, 88), Vector2(-68, 90)
	]
	return HEARTH_POS + guard_slots[index % guard_slots.size()]


func _survivor_defense_target(index: int) -> Vector2:
	var count := maxi(1, survivor_agents.size())
	var angle := -PI * 0.78 + TAU * float(index) / float(count)
	return HEARTH_POS + Vector2(cos(angle), sin(angle)) * 78.0


func _update_survivor_agents(delta: float) -> void:
	var night := stage in [Stage.NIGHT1, Stage.NIGHT2, Stage.NIGHT3]

	for i in range(survivor_agents.size()):
		var agent: Dictionary = survivor_agents[i]
		var role := String(agent.get("role", "guard"))
		var pos: Vector2 = agent["pos"]
		var target := _survivor_defense_target(i) if night else _survivor_day_target(i, role)
		var to_target := target - pos

		var moving := to_target.length() > 5.0
		if moving:
			var move_speed := 100.0 if night else 68.0
			pos += to_target.normalized() * minf(to_target.length(), move_speed * delta)
		var phase_speed := 6.0 if moving else (4.2 if role == "worker" and not night else 1.8)
		agent["phase"] = float(agent.get("phase", 0.0)) + delta * phase_speed

		var cd := maxf(0.0, float(agent.get("shot_cd", 0.0)) - delta)
		var can_fight := enemies.size() > 0 and (night or role == "hunter" or role == "guard")
		if can_fight and cd <= 0.0:
			var attack_range := 330.0 if role == "hunter" else (290.0 if role == "guard" else 220.0)
			var targets := _nearest_enemy_indices(pos, attack_range, 1)
			if targets.size() > 0:
				var damage_scale := 0.70 if role == "hunter" else (0.55 if role == "guard" else 0.35)
				shots.append({
					"pos": pos + Vector2(0, -7),
					"target": targets[0],
					"damage": hero_damage * damage_scale,
					"speed": 500.0,
					"tower": false,
					"ally": true
				})
				cd = 0.72 if role == "hunter" else (0.88 if role == "guard" else 1.15)

		agent["pos"] = pos
		agent["shot_cd"] = cd
		survivor_agents[i] = agent

	survivors = 1 + survivor_agents.size()


func _update_combat() -> void:
	if hero_shot_cd <= 0.0:
		var targets: Array[int] = _nearest_enemy_indices(hero_pos, 285.0, 1)
		for j in range(targets.size()):
			var index: int = targets[j]
			if index < 0 or index >= enemies.size():
				continue
			var origin := hero_pos + Vector2((float(j) - float(targets.size() - 1) * 0.5) * 10.0, -8.0)
			shots.append({
				"pos": origin,
				"target": index,
				"damage": hero_damage,
				"speed": 520.0,
				"tower": false
			})
		hero_shot_cd = hero_fire_rate


func _update_tower() -> void:
	if tower_cd > 0.0 or enemies.is_empty():
		return
	var tower_pos := HEARTH_POS + Vector2(92.0, -35.0)
	var targets := _nearest_enemy_indices(tower_pos, 340.0, 1)
	if targets.size() > 0:
		shots.append({
			"pos": tower_pos,
			"target": targets[0],
			"damage": 34.0,
			"speed": 580.0,
			"tower": true
		})
		tower_cd = 0.62


func _nearest_enemy_indices(from_pos: Vector2, max_distance: float, count: int) -> Array[int]:
	var choices: Array[Dictionary] = []
	for i in range(enemies.size()):
		var enemy: Dictionary = enemies[i]
		if float(enemy.get("hp", 0.0)) <= 0.0:
			continue
		var enemy_pos: Vector2 = enemy["pos"]
		var distance := from_pos.distance_to(enemy_pos)
		if distance <= max_distance:
			choices.append({"index": i, "distance": distance})
	choices.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["distance"]) < float(b["distance"]))
	var result: Array[int] = []
	for i in range(mini(count, choices.size())):
		result.append(int(choices[i]["index"]))
	return result


func _update_shots(delta: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var shot: Dictionary = shots[i]
		var target_index := int(shot.get("target", -1))
		if target_index < 0 or target_index >= enemies.size():
			shots.remove_at(i)
			continue

		var enemy: Dictionary = enemies[target_index]
		if float(enemy.get("hp", 0.0)) <= 0.0:
			shots.remove_at(i)
			continue

		var shot_pos: Vector2 = shot["pos"]
		var enemy_pos: Vector2 = enemy["pos"]
		var to_enemy := enemy_pos - shot_pos
		var distance := to_enemy.length()
		var speed := float(shot.get("speed", 500.0))

		if distance < 17.0:
			enemy["hp"] = float(enemy["hp"]) - float(shot.get("damage", 10.0))
			enemy["hit_flash"] = 0.11
			if distance > 0.001:
				enemy["pos"] = enemy_pos + to_enemy.normalized() * 3.5
			enemies[target_index] = enemy
			if String(enemy.get("kind", "basic")) in ["elite", "boss"]:
				camera_shake = maxf(camera_shake, 1.2)
			shots.remove_at(i)
		else:
			shot_pos += to_enemy.normalized() * minf(distance, speed * delta)
			shot["pos"] = shot_pos
			shots[i] = shot


func _update_enemies(delta: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		var hp := float(enemy.get("hp", 0.0))
		if hp <= 0.0:
			enemies.remove_at(i)
			_on_enemy_killed(enemy)
			continue

		var pos: Vector2 = enemy["pos"]
		var to_hearth := HEARTH_POS - pos
		var distance := to_hearth.length()
		var radius := float(enemy.get("radius", 14.0))
		var speed := float(enemy.get("speed", 35.0))
		var hit_cd := maxf(0.0, float(enemy.get("hit_cd", 0.0)) - delta)
		var hit_flash := maxf(0.0, float(enemy.get("hit_flash", 0.0)) - delta)

		if distance > 48.0 + radius * 0.35:
			pos += to_hearth.normalized() * speed * delta
		elif hit_cd <= 0.0:
			hearth_hp -= float(enemy.get("damage", 7.0))
			hit_cd = 0.88
			flash_timer = 0.08
			camera_shake = maxf(camera_shake, 2.2)
			hearth_pulse = maxf(hearth_pulse, 0.35)
			_float_text(HEARTH_POS + Vector2(0, -72), "-%d ОЧАГ" % int(enemy.get("damage", 0)), Color(1.0, 0.48, 0.38))

		enemy["pos"] = pos
		enemy["hit_cd"] = hit_cd
		enemy["hit_flash"] = hit_flash
		enemies[i] = enemy


func _on_enemy_killed(enemy: Dictionary) -> void:
	var pos: Vector2 = enemy["pos"]
	var kind := String(enemy.get("kind", "basic"))
	_burst(pos, 10 if kind != "boss" else 34)
	if kind == "elite":
		camera_shake = maxf(camera_shake, 3.0)
	elif kind == "boss":
		camera_shake = 6.0

	if kind == "elite":
		_float_text(pos + Vector2(0, -25), "ЭЛИТА ПОВЕРЖЕНА", Color(1.0, 0.72, 0.38))
	elif kind == "boss":
		run_embers += 3
		core_active = true
		core_carried = false
		core_pos = pos
		stage = Stage.CORE_RETURN
		night_queue.clear()
		enemies.clear()
		shots.clear()
		flash_timer = 0.7
		_banner("Хранитель пал · забери его ядро", 2.6)


func _update_core_return() -> void:
	if core_active and not core_carried and hero_pos.distance_to(core_pos) < 38.0:
		core_carried = true
		core_active = false
		_banner("Ядро у тебя · неси к очагу", 1.8)

	if core_carried and hero_pos.distance_to(HEARTH_POS) < 68.0:
		core_carried = false
		hearth_level = 5
		light_radius = 380.0
		flash_timer = 1.25
		hearth_pulse = 1.0
		camera_shake = 6.0
		_finish_run(true)


func _finish_run(win: bool) -> void:
	if mode != Mode.EXPEDITION:
		return
	mode = Mode.RESULT
	result_win = win
	meta["embers"] = int(meta.get("embers", 0)) + run_embers

	if win:
		meta["forest_cleared"] = true
		meta["hearth_rank"] = maxi(int(meta.get("hearth_rank", 1)), 2)
		result_title = "ЗАБЫТЫЙ ЛЕС ОЧИЩЕН"
		result_subtitle = "Ядро усилило Последний Очаг. За тьмой уже видны Мёртвые поля."
	else:
		result_title = "ОЧАГ ПОГАС"
		result_subtitle = "Временные усиления потеряны. Угли и постоянные улучшения остались."

	_save_meta()
	_stop_joystick()


func _update_particles(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		var life := float(p.get("life", 0.0)) - delta
		var pos: Vector2 = p["pos"]
		var vel: Vector2 = p["vel"]
		pos += vel * delta
		vel *= 0.93
		p["life"] = life
		p["pos"] = pos
		p["vel"] = vel
		particles[i] = p
		if life <= 0.0:
			particles.remove_at(i)


func _update_floaters(delta: float) -> void:
	for i in range(floaters.size() - 1, -1, -1):
		var f: Dictionary = floaters[i]
		var life := float(f.get("life", 0.0)) - delta
		var pos: Vector2 = f["pos"]
		pos.y -= 24.0 * delta
		f["life"] = life
		f["pos"] = pos
		floaters[i] = f
		if life <= 0.0:
			floaters.remove_at(i)


func _float_text(pos: Vector2, text: String, color: Color) -> void:
	floaters.append({"pos": pos, "text": text, "color": color, "life": 1.0})


func _burst(pos: Vector2, count: int) -> void:
	for i in range(count):
		var angle := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(35.0, 115.0)
		particles.append({
			"pos": pos,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": rng.randf_range(0.3, 0.7)
		})


func _banner(text: String, duration: float = 1.8) -> void:
	banner_text = text
	banner_timer = duration


func _stop_joystick() -> void:
	joystick_active = false
	joystick_vector = Vector2.ZERO
	joystick_touch_index = -1
	mouse_dragging = false
	hero_target = hero_pos


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.RESULT:
		if event is InputEventScreenTouch and event.pressed:
			_enter_hub("Ты вернулся к Последнему Очагу.")
		elif event is InputEventMouseButton and event.pressed:
			_enter_hub("Ты вернулся к Последнему Очагу.")
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if not joystick_active:
				joystick_touch_index = event.index
				_start_joystick(event.position)
		elif joystick_active and event.index == joystick_touch_index:
			_stop_joystick()
	elif event is InputEventScreenDrag:
		if joystick_active and event.index == joystick_touch_index:
			_update_joystick(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_dragging = event.pressed
			if event.pressed:
				joystick_touch_index = -2
				_start_joystick(event.position)
			else:
				_stop_joystick()
	elif event is InputEventMouseMotion:
		if mouse_dragging and joystick_active:
			_update_joystick(event.position)
	elif event is InputEventKey and event.pressed:
		var delta_target := Vector2.ZERO
		if event.keycode == KEY_A or event.keycode == KEY_LEFT:
			delta_target.x = -80.0
		elif event.keycode == KEY_D or event.keycode == KEY_RIGHT:
			delta_target.x = 80.0
		elif event.keycode == KEY_W or event.keycode == KEY_UP:
			delta_target.y = -80.0
		elif event.keycode == KEY_S or event.keycode == KEY_DOWN:
			delta_target.y = 80.0
		if delta_target != Vector2.ZERO:
			hero_target += delta_target
			hero_target.x = clampf(hero_target.x, 22.0, VIEW_SIZE.x - 22.0)
			hero_target.y = clampf(hero_target.y, 118.0, VIEW_SIZE.y - 24.0)


func _start_joystick(screen_pos: Vector2) -> void:
	joystick_active = true
	joystick_origin = screen_pos
	joystick_knob = screen_pos
	joystick_vector = Vector2.ZERO
	hero_target = hero_pos


func _update_joystick(screen_pos: Vector2) -> void:
	var offset := screen_pos - joystick_origin
	if offset.length() > JOYSTICK_RADIUS:
		offset = offset.normalized() * JOYSTICK_RADIUS
	joystick_knob = joystick_origin + offset
	joystick_vector = offset / JOYSTICK_RADIUS
	if joystick_vector.length() < JOYSTICK_DEADZONE:
		joystick_vector = Vector2.ZERO


func _draw() -> void:
	var shake_offset := Vector2.ZERO
	if camera_shake > 0.0:
		var now := float(Time.get_ticks_msec())
		shake_offset = Vector2(sin(now * 0.071), cos(now * 0.093)) * camera_shake
	draw_set_transform(shake_offset, 0.0, Vector2.ONE)

	if mode == Mode.HUB:
		_draw_hub()
	else:
		_draw_expedition()

	_draw_particles()
	_draw_floaters()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_draw_hud()
	_draw_banner()
	_draw_joystick()
	_draw_flash()

	if mode == Mode.RESULT:
		_draw_result_overlay()


func _draw_hub() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("#111c17"))
	_draw_ground_texture(Color("#1a2a21"), 58)
	_draw_light_field(HEARTH_POS, 250.0)

	# The hub is a place, not a menu: every upgrade has a physical object.
	_draw_hub_building(Vector2(92, 226), "home", "ДОМ ОХОТНИКА", "")
	_draw_hub_building(HUB_CARRY_POS, "store", "СКЛАД", "перенос")
	_draw_hub_building(HUB_DAMAGE_POS, "forge", "КУЗНИЦА", "урон")
	_draw_hub_building(Vector2(390, 620), "watch", "ДОЗОР", "")
	_draw_map_table(HUB_MAP_POS)
	_draw_hearth(HEARTH_POS, maxi(2, int(meta.get("hearth_rank", 1)) + 1))
	_draw_hearth_altar(HUB_HEARTH_UPGRADE_POS)

	var resident_roles: Array[String] = ["hunter", "worker", "guard"]
	var resident_count := 3 if bool(meta.get("forest_cleared", false)) else 2
	for i in range(resident_count):
		var angle := 0.4 + float(i) * 2.25
		var p := HEARTH_POS + Vector2(cos(angle), sin(angle)) * 105.0
		_draw_humanoid(p, Color("#8a8c72") if i == 0 else Color("#9b7856"), float(i), resident_roles[i], 1.0)

	_draw_hero(hero_pos)

	draw_string(font, Vector2(18, 116), "ПОСЛЕДНИЙ ОЧАГ", HORIZONTAL_ALIGNMENT_LEFT, 300, 22, Color("#f4ead4"))
	var subtitle := "Забытый лес очищен · новый путь открыт" if bool(meta.get("forest_cleared", false)) else "Соберись у карты и отправляйся в лес"
	draw_string(font, Vector2(18, 139), subtitle, HORIZONTAL_ALIGNMENT_LEFT, 440, 12, Color("#9eafa2"))

	var carry_level := int(meta.get("carry_level", 0))
	var damage_level := int(meta.get("damage_level", 0))
	var hearth_bonus := int(meta.get("hearth_bonus", 0))
	var carry_cost := 3 + carry_level * 2
	var damage_cost := 4 + damage_level * 3
	var hearth_cost := 5 + hearth_bonus * 4

	draw_string(font, HUB_CARRY_POS + Vector2(-63, 62), "ур.%d · %d углей" % [carry_level, carry_cost], HORIZONTAL_ALIGNMENT_CENTER, 126, 11, Color("#d7c7a8"))
	draw_string(font, HUB_DAMAGE_POS + Vector2(-63, 62), "ур.%d · %d углей" % [damage_level, damage_cost], HORIZONTAL_ALIGNMENT_CENTER, 126, 11, Color("#d7c7a8"))
	var hearth_label := "максимум" if hearth_bonus >= 3 else "ур.%d · %d углей" % [hearth_bonus, hearth_cost]
	draw_string(font, HUB_HEARTH_UPGRADE_POS + Vector2(-72, 49), hearth_label, HORIZONTAL_ALIGNMENT_CENTER, 144, 11, Color("#e6c583"))

	# Strongest call-to-action is always the next expedition.
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.08
	draw_arc(HUB_MAP_POS, 46.0 * pulse, 0.0, TAU, 44, Color(0.78, 0.88, 0.70, 0.55), 2.0)
	draw_string(font, HUB_MAP_POS + Vector2(-90, 69), "НОВАЯ ВЫЛАЗКА", HORIZONTAL_ALIGNMENT_CENTER, 180, 13, Color("#f3e4c8"))


func _draw_hub_building(pos: Vector2, kind: String, label: String, subtitle: String) -> void:
	_draw_ellipse_custom(pos + Vector2(0, 25), Vector2(38, 11), Color(0.01, 0.02, 0.015, 0.28))
	var wall := Color("#5d4e3b")
	var roof := Color("#7b6243")
	if kind == "forge":
		wall = Color("#594642")
		roof = Color("#7b5148")
	elif kind == "store":
		wall = Color("#5d513d")
		roof = Color("#7d6945")
	elif kind == "watch":
		wall = Color("#4e4b3b")
		roof = Color("#6f6846")
	draw_rect(Rect2(pos + Vector2(-28, -12), Vector2(56, 40)), wall)
	var roof_pts := PackedVector2Array([
		pos + Vector2(-34, -12), pos + Vector2(0, -39), pos + Vector2(34, -12)
	])
	draw_colored_polygon(roof_pts, roof)
	draw_rect(Rect2(pos + Vector2(-6, 7), Vector2(12, 21)), Color("#292821"))
	if kind == "forge":
		draw_rect(Rect2(pos + Vector2(18, -33), Vector2(8, 27)), Color("#443c34"))
		draw_circle(pos + Vector2(22, -38), 6.0, Color(0.72, 0.45, 0.30, 0.16))
	elif kind == "store":
		for i in range(3):
			draw_line(pos + Vector2(-20, 14 - i * 8), pos + Vector2(-2, 14 - i * 8), Color("#a87b48"), 5.0, true)
	draw_string(font, pos + Vector2(-70, 47), label, HORIZONTAL_ALIGNMENT_CENTER, 140, 11, Color("#e6dcc6"))
	if subtitle != "":
		draw_string(font, pos + Vector2(-70, 60), subtitle, HORIZONTAL_ALIGNMENT_CENTER, 140, 10, Color("#9aa79a"))


func _draw_map_table(pos: Vector2) -> void:
	draw_rect(Rect2(pos + Vector2(-34, -13), Vector2(68, 30)), Color("#67533b"))
	draw_line(pos + Vector2(-25, 17), pos + Vector2(-30, 36), Color("#514231"), 6.0)
	draw_line(pos + Vector2(25, 17), pos + Vector2(30, 36), Color("#514231"), 6.0)
	var map_pts := PackedVector2Array([
		pos + Vector2(-25, -8), pos + Vector2(22, -10), pos + Vector2(28, 7), pos + Vector2(-20, 10)
	])
	draw_colored_polygon(map_pts, Color("#c8b48b"))
	draw_line(pos + Vector2(-12, 0), pos + Vector2(10, -3), Color("#74866c"), 2.0)
	draw_circle(pos + Vector2(14, 2), 3.0, Color("#9c5b43"))
	draw_string(font, pos + Vector2(-50, 52), "КАРТА", HORIZONTAL_ALIGNMENT_CENTER, 100, 11, Color("#d9d0ba"))


func _draw_hearth_altar(pos: Vector2) -> void:
	var pulse := 1.0 + hearth_pulse * 0.14
	draw_circle(pos, 26.0 * pulse, Color(0.92, 0.62, 0.25, 0.10 + hearth_pulse * 0.10))
	for i in range(5):
		var a := TAU * float(i) / 5.0
		draw_circle(pos + Vector2(cos(a), sin(a)) * 19.0, 4.0, Color("#6c6656"))
	var crystal := PackedVector2Array([
		pos + Vector2(0, -16), pos + Vector2(10, 0), pos + Vector2(0, 17), pos + Vector2(-10, 0)
	])
	draw_colored_polygon(crystal, Color("#d89145"))
	draw_string(font, pos + Vector2(-70, 36), "УСИЛИТЬ ОЧАГ", HORIZONTAL_ALIGNMENT_CENTER, 140, 11, Color("#ead7b0"))


func _draw_expedition() -> void:
	var night_stage := stage in [Stage.NIGHT1, Stage.NIGHT2, Stage.NIGHT3]
	var night_mix := 0.0
	if night_stage:
		night_mix = 1.0 - clampf(twilight_timer / TWILIGHT_DURATION, 0.0, 1.0)

	var day_bg := Color("#1a2a21")
	var night_bg := Color("#0a1211")
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), day_bg.lerp(night_bg, night_mix))
	_draw_ground_texture(Color("#213529").lerp(Color("#13201a"), night_mix), 64)
	_draw_environment_decor()
	_draw_light_field(HEARTH_POS, light_radius)

	for node: Dictionary in resource_nodes:
		_draw_resource(node)
	for pickup: Dictionary in resource_pickups:
		_draw_resource_pickup(pickup)
	_draw_resource_flights()

	_draw_revealed_landmarks()

	if stage == Stage.DAY1_RESCUE and not survivor_one_found:
		_draw_survivor(survivor_one_pos, "?")
	if stage == Stage.DAY2_RESCUE and not survivor_two_found:
		_draw_survivor(survivor_two_pos, "!")
	if stage == Stage.WORKSHOP_CHOICE:
		_draw_choice_shrine(left_choice_pos, "ОРУЖЕЙНАЯ · +28% УРОН", Color("#a85949"))
		_draw_choice_shrine(right_choice_pos, "ЛЕСОПИЛКА · +2 ГРУЗ", Color("#567e58"))
	if stage == Stage.EXPEDITION_CHOICE:
		_draw_choice_shrine(left_choice_pos, "ДВА БОЙЦА", Color("#6688a0"))
		_draw_choice_shrine(right_choice_pos, "ОГНЕННЫЕ СТРЕЛЫ", Color("#b75e45"))

	if workshop_built:
		_draw_workshop()
	if tower_built:
		_draw_tower()

	for enemy: Dictionary in enemies:
		_draw_enemy(enemy)
	for shot: Dictionary in shots:
		_draw_shot(shot)

	if core_active:
		_draw_core(core_pos)
	if core_carried:
		_draw_core(hero_pos + Vector2(0, -46))

	_draw_hearth(HEARTH_POS, hearth_level)
	_draw_world_progress()
	_draw_companions()
	_draw_hero(hero_pos)
	_draw_guidance_marker()

	if night_mix > 0.0:
		draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.015, 0.03, 0.035, 0.10 * night_mix))
		_draw_night_edge_eyes(night_mix)


func _draw_environment_decor() -> void:
	for item: Dictionary in decor_points:
		var pos: Vector2 = item["pos"]
		var kind := String(item.get("kind", "grass"))
		var scale := float(item.get("scale", 1.0))
		var in_light := pos.distance_to(HEARTH_POS) <= light_radius + 18.0
		var alpha := 0.62 if in_light else 0.18
		if kind == "grass":
			draw_line(pos, pos + Vector2(-3 * scale, -7 * scale), Color(0.27, 0.43, 0.29, alpha), 1.4)
			draw_line(pos, pos + Vector2(2 * scale, -8 * scale), Color(0.29, 0.46, 0.31, alpha), 1.4)
			draw_line(pos, pos + Vector2(5 * scale, -5 * scale), Color(0.24, 0.39, 0.27, alpha), 1.2)
		elif kind == "pebble":
			draw_circle(pos, 2.7 * scale, Color(0.35, 0.39, 0.36, alpha))
		else:
			draw_line(pos + Vector2(-6, 2), pos + Vector2(7, -2), Color(0.34, 0.25, 0.17, alpha), 2.2)


func _draw_revealed_landmarks() -> void:
	# The rescued people live in actual places revealed by the firelight.
	if survivor_one_pos.distance_to(HEARTH_POS) <= light_radius + 28.0:
		_draw_ruined_shelter(survivor_one_pos + Vector2(-18, 20), Color("#5f543f"))
	if survivor_two_pos.distance_to(HEARTH_POS) <= light_radius + 28.0:
		_draw_ruined_shelter(survivor_two_pos + Vector2(22, 18), Color("#5a4c3d"))
	if light_radius >= 245.0:
		_draw_ruined_shelter(HEARTH_POS + Vector2(-112, -44), Color("#574c3c"))


func _draw_ruined_shelter(pos: Vector2, color: Color) -> void:
	draw_rect(Rect2(pos + Vector2(-17, -4), Vector2(34, 22)), Color(color.r, color.g, color.b, 0.75))
	draw_line(pos + Vector2(-22, -4), pos + Vector2(-4, -22), Color("#76634a"), 4.0)
	draw_line(pos + Vector2(-4, -22), pos + Vector2(20, -5), Color("#76634a"), 4.0)
	draw_line(pos + Vector2(4, -18), pos + Vector2(22, -10), Color("#4c4438"), 3.0)


func _draw_night_edge_eyes(alpha: float) -> void:
	if twilight_timer > 0.0:
		return
	var positions := [Vector2(34, 210), Vector2(445, 300), Vector2(52, 690), Vector2(432, 650)]
	for i in range(positions.size()):
		var p: Vector2 = positions[i]
		var pulse := 0.35 + 0.25 * sin(Time.get_ticks_msec() * 0.004 + float(i))
		draw_circle(p + Vector2(-4, 0), 1.7, Color(0.94, 0.60, 0.24, alpha * pulse))
		draw_circle(p + Vector2(4, 0), 1.7, Color(0.94, 0.60, 0.24, alpha * pulse))


func _draw_ground_texture(color: Color, spacing: int) -> void:
	for y in range(140, 790, spacing):
		for x in range(20, 470, spacing):
			var offset := float((x * 13 + y * 7) % 17)
			draw_circle(Vector2(float(x) + offset, float(y)), 2.0, color)


func _draw_light_field(center: Vector2, radius: float) -> void:
	for i in range(12, 0, -1):
		var t := float(i) / 12.0
		var r := radius * t
		var alpha := 0.012 + (1.0 - t) * 0.032
		draw_circle(center, r, Color(0.98, 0.68, 0.29, alpha))
	var boundary_alpha := 0.10 + hearth_pulse * 0.16
	draw_arc(center, radius, 0.0, TAU, 80, Color(0.96, 0.68, 0.30, boundary_alpha), 2.0 + hearth_pulse * 2.0)


func _draw_resource(node: Dictionary) -> void:
	var pos: Vector2 = node["pos"]
	var alive := bool(node.get("alive", false))
	var kind := String(node.get("kind", "tree"))
	var in_light := pos.distance_to(HEARTH_POS) <= light_radius + 35.0
	var alpha := 1.0 if in_light else 0.32

	if kind == "tree":
		if alive:
			draw_rect(Rect2(pos + Vector2(-5, 8), Vector2(10, 26)), Color(0.33, 0.22, 0.14, alpha))
			draw_circle(pos, 22.0, Color(0.16, 0.34, 0.20, alpha))
			draw_circle(pos + Vector2(-14, 4), 14.0, Color(0.18, 0.39, 0.23, alpha))
			draw_circle(pos + Vector2(14, 4), 14.0, Color(0.18, 0.39, 0.23, alpha))
		elif not bool(node.get("drop_spawned", true)):
			var progress := 1.0 - clampf(float(node.get("fall_timer", 0.0)) / 0.34, 0.0, 1.0)
			var fall_x := 14.0 + progress * 34.0
			draw_line(pos + Vector2(0, 16), pos + Vector2(fall_x, -4 + progress * 18.0), Color(0.33, 0.22, 0.14, alpha), 9.0)
			draw_circle(pos + Vector2(fall_x, -8 + progress * 18.0), 19.0, Color(0.16, 0.34, 0.20, alpha))
		else:
			draw_circle(pos + Vector2(0, 14), 8.0, Color(0.30, 0.22, 0.16, alpha))
	else:
		if alive:
			var pts := PackedVector2Array([
				pos + Vector2(-18, 10), pos + Vector2(-10, -12), pos + Vector2(8, -16),
				pos + Vector2(19, 2), pos + Vector2(11, 15), pos + Vector2(-7, 17)
			])
			draw_colored_polygon(pts, Color(0.42, 0.46, 0.45, alpha))
		elif not bool(node.get("drop_spawned", true)):
			draw_circle(pos + Vector2(-9, 2), 11.0, Color(0.42, 0.46, 0.45, alpha))
			draw_circle(pos + Vector2(11, 6), 9.0, Color(0.38, 0.42, 0.41, alpha))
		else:
			draw_circle(pos, 7.0, Color(0.33, 0.36, 0.35, alpha))


func _draw_resource_pickup(pickup: Dictionary) -> void:
	var pos: Vector2 = pickup["pos"]
	var kind := String(pickup.get("kind", "wood"))
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.006 + pos.x * 0.04) * 0.06
	draw_circle(pos + Vector2(0, 5), 11.0, Color(0.02, 0.03, 0.02, 0.20))
	if kind == "wood":
		var spin := float(pickup.get("spin", 0.0))
		var axis := Vector2(cos(spin), sin(spin))
		draw_line(pos - axis * 10.0, pos + axis * 10.0, Color("#9b6a3d"), 7.0 * pulse, true)
		draw_circle(pos - axis * 10.0, 3.5, Color("#c18b54"))
		draw_circle(pos + axis * 10.0, 3.5, Color("#c18b54"))
	else:
		var pts := PackedVector2Array([
			pos + Vector2(-7, 4), pos + Vector2(-4, -7), pos + Vector2(6, -6),
			pos + Vector2(9, 2), pos + Vector2(3, 8), pos + Vector2(-5, 7)
		])
		draw_colored_polygon(pts, Color("#8d9694"))


func _draw_resource_flights() -> void:
	for flight: Dictionary in resource_flights:
		var t := clampf(float(flight.get("t", 0.0)), 0.0, 1.0)
		var from: Vector2 = flight["from"]
		var to: Vector2 = hero_pos + Vector2(0, -22) if String(flight.get("mode", "pickup")) == "pickup" else flight["to"]
		var mid := (from + to) * 0.5 + Vector2(0, -30.0)
		var inv := 1.0 - t
		var p := from * inv * inv + mid * 2.0 * inv * t + to * t * t
		var kind := String(flight.get("kind", "wood"))
		if kind == "wood":
			draw_line(p + Vector2(-8, 0), p + Vector2(8, 0), Color("#a87342"), 6.0, true)
			draw_circle(p + Vector2(-8, 0), 2.8, Color("#d09a61"))
			draw_circle(p + Vector2(8, 0), 2.8, Color("#d09a61"))
		else:
			draw_circle(p, 5.5, Color("#929b98"))


func _draw_hearth(pos: Vector2, level: int) -> void:
	var pulse := 1.0 + hearth_pulse * 0.10 + sin(Time.get_ticks_msec() * 0.007) * 0.025
	var ring_radius := 34.0 + float(level) * 3.5
	draw_circle(pos + Vector2(0, 15), 50.0 + float(level) * 3.0, Color(0.02, 0.025, 0.02, 0.34))
	draw_circle(pos, (44.0 + float(level) * 4.0) * pulse, Color(0.95, 0.58, 0.18, 0.035 + hearth_pulse * 0.035))

	# Heavy stone ring and burning logs make the hearth feel built, not icon-like.
	for i in range(9):
		var angle := TAU * float(i) / 9.0
		var stone := pos + Vector2(cos(angle), sin(angle)) * ring_radius
		draw_circle(stone, 7.5 + float(level) * 0.4, Color("#5b5950"))
		draw_circle(stone + Vector2(-2, -2), 2.0, Color(0.45, 0.44, 0.39, 0.45))
	for a in [-0.45, 0.45]:
		var axis := Vector2(cos(a), sin(a))
		draw_line(pos - axis * 20.0, pos + axis * 20.0, Color("#704326"), 8.0, true)

	var flame_h := (29.0 + float(level) * 7.0) * pulse
	var flame_w := 17.0 + float(level) * 2.4
	var outer := PackedVector2Array([
		pos + Vector2(0, -flame_h),
		pos + Vector2(flame_w, 8),
		pos + Vector2(8, 22),
		pos + Vector2(-8, 22),
		pos + Vector2(-flame_w, 8)
	])
	draw_colored_polygon(outer, Color("#ee8e32"))
	var middle := PackedVector2Array([
		pos + Vector2(2, -flame_h * 0.72),
		pos + Vector2(flame_w * 0.62, 9),
		pos + Vector2(0, 20),
		pos + Vector2(-flame_w * 0.62, 8)
	])
	draw_colored_polygon(middle, Color("#ffc45e"))
	var inner := PackedVector2Array([
		pos + Vector2(0, -flame_h * 0.42),
		pos + Vector2(7, 8),
		pos + Vector2(0, 16),
		pos + Vector2(-7, 8)
	])
	draw_colored_polygon(inner, Color("#fff0b1"))

	if level >= 3:
		draw_line(pos + Vector2(-52, 30), pos + Vector2(-52, -28), Color("#6a5135"), 6.0)
		draw_line(pos + Vector2(52, 30), pos + Vector2(52, -28), Color("#6a5135"), 6.0)
		draw_line(pos + Vector2(-52, -25), pos + Vector2(52, -25), Color("#7a5b39"), 5.0)
	if level >= 4:
		draw_line(pos + Vector2(-68, 35), pos + Vector2(-68, -10), Color("#75583a"), 5.0)
		draw_line(pos + Vector2(68, 35), pos + Vector2(68, -10), Color("#75583a"), 5.0)
		draw_circle(pos + Vector2(-68, -15), 6.0, Color("#e6963c"))
		draw_circle(pos + Vector2(68, -15), 6.0, Color("#e6963c"))
	if level >= 5:
		draw_arc(pos, ring_radius + 22.0, -2.8, -0.35, 22, Color(0.95, 0.71, 0.36, 0.38), 3.0)
		draw_arc(pos, ring_radius + 22.0, 0.35, 2.8, 22, Color(0.95, 0.71, 0.36, 0.38), 3.0)

	draw_string(font, pos + Vector2(-55, 70), "ОЧАГ %d" % level, HORIZONTAL_ALIGNMENT_CENTER, 110, 12, Color("#eadfc8"))


func _draw_hero(pos: Vector2) -> void:
	var bob := sin(hero_walk_phase) * 1.8
	_draw_back_cargo(pos + Vector2(0, bob))
	_draw_humanoid(pos, Color("#c4ad79"), hero_walk_phase, "hero", 1.0 if hero_facing.x >= 0.0 else -1.0)

	var work_kind := _nearby_resource_kind()
	var hand := pos + Vector2((12.0 if hero_facing.x >= 0.0 else -12.0), -3.0 + bob)
	var direction := 1.0 if hero_facing.x >= 0.0 else -1.0
	if work_kind != "":
		var swing_phase := 1.0 - clampf(gather_cd / maxf(0.01, gather_interval), 0.0, 1.0)
		var swing := sin(swing_phase * PI) * 0.95
		var angle := -1.15 + swing * direction
		var tip := hand + Vector2(cos(angle) * direction, sin(angle)) * 29.0
		draw_line(hand, tip, Color("#b98b5b"), 3.0, true)
		if work_kind == "tree":
			draw_line(tip + Vector2(-6, -4), tip + Vector2(6, 4), Color("#bcc1bb"), 5.0, true)
		else:
			draw_line(tip + Vector2(-7, 1), tip + Vector2(7, -1), Color("#aeb5b1"), 4.0, true)
	else:
		# Compact crossbow-like weapon: readable, but does not clutter movement.
		draw_line(hand, hand + Vector2(20.0 * direction, -7.0), Color("#c9b58b"), 3.0, true)
		draw_line(hand + Vector2(10.0 * direction, -8.0), hand + Vector2(10.0 * direction, 3.0), Color("#8c6d47"), 2.0, true)


func _nearby_resource_kind() -> String:
	for node: Dictionary in resource_nodes:
		if not bool(node.get("alive", false)):
			continue
		var kind := String(node.get("kind", "tree"))
		if stage in [Stage.DAY1_GATHER, Stage.DAY1_RESCUE] and kind != "tree":
			continue
		if hero_pos.distance_to(node["pos"]) <= HERO_INTERACT_RADIUS + 2.0:
			return kind
	return ""


func _draw_back_cargo(pos: Vector2) -> void:
	# The load must be readable from the character itself, not only from HUD.
	var visible_logs := mini(carried_wood, 7)
	for i in range(visible_logs):
		var row := i / 2
		var side := -1.0 if i % 2 == 0 else 1.0
		var center := pos + Vector2(side * 5.0, -12.0 - float(row) * 6.5)
		var tilt := 0.10 * side
		var axis := Vector2(cos(tilt), sin(tilt))
		draw_line(center - axis * 15.0, center + axis * 15.0, Color("#8f5d33"), 6.5, true)
		draw_circle(center - axis * 15.0, 3.1, Color("#c28a54"))
		draw_circle(center + axis * 15.0, 3.1, Color("#c28a54"))
	if visible_logs > 0:
		draw_line(pos + Vector2(-12, -6), pos + Vector2(11, -30), Color(0.72, 0.58, 0.36, 0.8), 2.0)

	if carried_stone > 0:
		var sack := pos + Vector2(-18, 5)
		draw_circle(sack, 9.0, Color("#766f60"))
		draw_line(sack + Vector2(-5, -5), sack + Vector2(5, -5), Color("#a6977e"), 2.0)
		for i in range(mini(carried_stone, 4)):
			var p := sack + Vector2(-4 + float(i % 2) * 8.0, -2 + float(i / 2) * 6.0)
			draw_circle(p, 2.6, Color("#a4aaa7"))


func _draw_companions() -> void:
	for agent: Dictionary in survivor_agents:
		var role := String(agent.get("role", "guard"))
		var pos: Vector2 = agent["pos"]
		var phase := float(agent.get("phase", 0.0))
		var body_color := Color("#6f8663")
		if role == "worker":
			body_color = Color("#a07149")
		elif role == "guard":
			body_color = Color("#667d91")
		_draw_humanoid(pos, body_color, phase, role, 1.0)


func _draw_humanoid(pos: Vector2, coat: Color, phase: float, role: String, facing: float = 1.0) -> void:
	var moving_stride: float = sin(phase) * 4.0
	var bob: float = absf(sin(phase * 0.5)) * 1.4
	var base: Vector2 = pos + Vector2(0, -bob)
	_draw_ellipse_custom(pos + Vector2(0, 18), Vector2(14, 5), Color(0.01, 0.02, 0.015, 0.30))

	# Legs and boots.
	draw_line(base + Vector2(-5, 8), base + Vector2(-7 + moving_stride, 19), Color("#403c34"), 4.0, true)
	draw_line(base + Vector2(5, 8), base + Vector2(7 - moving_stride, 19), Color("#403c34"), 4.0, true)
	draw_line(base + Vector2(-10 + moving_stride, 19), base + Vector2(-4 + moving_stride, 19), Color("#272824"), 4.0, true)
	draw_line(base + Vector2(4 - moving_stride, 19), base + Vector2(10 - moving_stride, 19), Color("#272824"), 4.0, true)

	# Torso / coat.
	var torso := PackedVector2Array([
		base + Vector2(-10, -10), base + Vector2(10, -10),
		base + Vector2(12, 9), base + Vector2(-12, 9)
	])
	draw_colored_polygon(torso, coat)
	draw_rect(Rect2(base + Vector2(-11, 4), Vector2(22, 3)), Color(0.30, 0.24, 0.17, 0.85))

	# Arms.
	var arm_sway := sin(phase + 1.2) * 3.0
	draw_line(base + Vector2(-9, -5), base + Vector2(-14 - arm_sway, 6), coat.lightened(0.08), 4.0, true)
	draw_line(base + Vector2(9, -5), base + Vector2(14 + arm_sway, 5), coat.lightened(0.08), 4.0, true)

	# Head, hair/hood and a tiny face mark: these make units read as people at phone scale.
	draw_circle(base + Vector2(0, -17), 7.2, Color("#c69c7d"))
	draw_arc(base + Vector2(0, -18), 7.0, PI, TAU, 16, Color("#5b4737"), 4.0)
	draw_circle(base + Vector2(2.5 * facing, -17), 0.9, Color("#342f28"))

	if role == "hunter":
		var hand := base + Vector2(13, 0)
		draw_arc(hand + Vector2(7, -2), 9.0, -1.55, 1.55, 12, Color("#d1b989"), 2.0)
		draw_line(hand + Vector2(7, -11), hand + Vector2(7, 7), Color("#b69a6c"), 1.5)
	elif role == "worker":
		var work := 0.25 + sin(phase) * 0.45
		var hand := base + Vector2(13, 0)
		var tip := hand + Vector2(cos(-0.8 + work), sin(-0.8 + work)) * 20.0
		draw_line(hand, tip, Color("#b2875b"), 3.0)
		draw_rect(Rect2(tip + Vector2(-4, -4), Vector2(8, 6)), Color("#8d8c83"))
	elif role == "guard":
		draw_line(base + Vector2(11, -1), base + Vector2(24, -13), Color("#c5c9c4"), 2.5)
		draw_line(base + Vector2(19, -14), base + Vector2(26, -9), Color("#c5c9c4"), 2.0)


func _draw_person(pos: Vector2, color: Color, phase: float) -> void:
	_draw_humanoid(pos, color, phase, "civilian", 1.0)


func _draw_survivor(pos: Vector2, mark: String) -> void:
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.007) * 0.06
	draw_circle(pos, 26.0 * pulse, Color(0.77, 0.83, 0.70, 0.07))
	_draw_humanoid(pos, Color("#8c8974"), Time.get_ticks_msec() * 0.002, "civilian", 1.0)
	draw_string(font, pos + Vector2(-12, -40), mark, HORIZONTAL_ALIGNMENT_CENTER, 24, 16, Color("#f4ead4"))


func _draw_enemy(enemy: Dictionary) -> void:
	var pos: Vector2 = enemy["pos"]
	var kind := String(enemy.get("kind", "basic"))
	var radius := float(enemy.get("radius", 14.0))
	var flash := float(enemy.get("hit_flash", 0.0)) > 0.0
	var body := Color("#70484a")
	if kind == "fast":
		body = Color("#83513f")
	elif kind == "elite":
		body = Color("#60425d")
	elif kind == "boss":
		body = Color("#413443")
	elif kind == "guard":
		body = Color("#5e4945")
	if flash:
		body = body.lightened(0.55)

	_draw_ellipse_custom(pos + Vector2(0, radius * 0.75), Vector2(radius * 1.15, radius * 0.38), Color(0.01, 0.015, 0.012, 0.38))

	if kind == "fast":
		# Low, animal-like silhouette.
		_draw_ellipse_custom(pos + Vector2(0, 1), Vector2(radius * 1.35, radius * 0.70), body)
		draw_circle(pos + Vector2(radius * 0.85, -4), radius * 0.46, body)
		draw_line(pos + Vector2(-7, 6), pos + Vector2(-14, 15), body.darkened(0.15), 4.0)
		draw_line(pos + Vector2(7, 6), pos + Vector2(15, 15), body.darkened(0.15), 4.0)
	elif kind == "boss":
		# The Forest Guardian needs a silhouette you can recognise before reading a label.
		_draw_ellipse_custom(pos + Vector2(0, 3), Vector2(radius * 1.05, radius * 1.15), body)
		draw_circle(pos + Vector2(0, -radius * 0.75), radius * 0.62, body.darkened(0.08))
		draw_line(pos + Vector2(-18, -23), pos + Vector2(-34, -43), Color("#5e4b38"), 6.0)
		draw_line(pos + Vector2(-34, -43), pos + Vector2(-42, -55), Color("#5e4b38"), 4.0)
		draw_line(pos + Vector2(18, -23), pos + Vector2(34, -43), Color("#5e4b38"), 6.0)
		draw_line(pos + Vector2(34, -43), pos + Vector2(44, -54), Color("#5e4b38"), 4.0)
		draw_line(pos + Vector2(-17, 24), pos + Vector2(-25, 42), body.darkened(0.15), 8.0)
		draw_line(pos + Vector2(17, 24), pos + Vector2(25, 42), body.darkened(0.15), 8.0)
	else:
		# Upright shadow-creatures instead of coloured circles.
		_draw_ellipse_custom(pos + Vector2(0, 3), Vector2(radius * 0.78, radius * 1.05), body)
		draw_circle(pos + Vector2(0, -radius * 0.72), radius * 0.55, body.darkened(0.05))
		draw_line(pos + Vector2(-6, 10), pos + Vector2(-9, radius + 8), body.darkened(0.18), 5.0)
		draw_line(pos + Vector2(6, 10), pos + Vector2(9, radius + 8), body.darkened(0.18), 5.0)
		if kind == "elite":
			draw_line(pos + Vector2(-8, -17), pos + Vector2(-17, -28), Color("#6c5542"), 4.0)
			draw_line(pos + Vector2(8, -17), pos + Vector2(17, -28), Color("#6c5542"), 4.0)

	var eye_sep := radius * 0.28
	var eye_y := -radius * 0.58
	draw_circle(pos + Vector2(-eye_sep, eye_y), maxf(1.6, radius * 0.09), Color("#efad51"))
	draw_circle(pos + Vector2(eye_sep, eye_y), maxf(1.6, radius * 0.09), Color("#efad51"))

	var hp := float(enemy.get("hp", 1.0))
	var max_hp := float(enemy.get("max_hp", 1.0))
	if kind in ["elite", "boss"] or hp < max_hp:
		var bar_w := radius * 2.4
		draw_rect(Rect2(pos + Vector2(-bar_w * 0.5, -radius - 18), Vector2(bar_w, 5)), Color(0, 0, 0, 0.48))
		draw_rect(Rect2(pos + Vector2(-bar_w * 0.5, -radius - 18), Vector2(bar_w * clampf(hp / max_hp, 0.0, 1.0), 5)), Color("#d7b872"))

	if kind == "boss":
		draw_string(font, pos + Vector2(-80, -radius - 28), "ХРАНИТЕЛЬ ЛЕСА", HORIZONTAL_ALIGNMENT_CENTER, 160, 11, Color("#ead7c7"))


func _draw_shot(shot: Dictionary) -> void:
	var pos: Vector2 = shot["pos"]
	var tower := bool(shot.get("tower", false))
	draw_circle(pos, 3.0 if not tower else 4.0, Color("#fff0b2") if not tower else Color("#f0bd68"))


func _draw_workshop() -> void:
	var pos := HEARTH_POS + Vector2(-112, -48)
	_draw_ellipse_custom(pos + Vector2(0, 23), Vector2(38, 10), Color(0.01, 0.02, 0.015, 0.26))
	draw_rect(Rect2(pos + Vector2(-31, -14), Vector2(62, 42)), Color("#5c4935"))
	var roof := PackedVector2Array([
		pos + Vector2(-38, -14), pos + Vector2(0, -43), pos + Vector2(38, -14)
	])
	draw_colored_polygon(roof, Color("#7b5f3c"))
	draw_rect(Rect2(pos + Vector2(-20, 4), Vector2(17, 13)), Color("#302d27"))
	draw_line(pos + Vector2(12, 5), pos + Vector2(28, -7), Color("#c0a574"), 3.0)
	draw_rect(Rect2(pos + Vector2(25, -11), Vector2(8, 7)), Color("#8f8c81"))
	draw_string(font, pos + Vector2(-52, 45), "МАСТЕРСКАЯ", HORIZONTAL_ALIGNMENT_CENTER, 104, 10, Color("#ded1b7"))


func _draw_tower() -> void:
	var pos := HEARTH_POS + Vector2(104, -39)
	_draw_ellipse_custom(pos + Vector2(0, 22), Vector2(30, 9), Color(0.01, 0.02, 0.015, 0.25))
	draw_line(pos + Vector2(-13, 25), pos + Vector2(-8, -38), Color("#604a31"), 7.0)
	draw_line(pos + Vector2(13, 25), pos + Vector2(8, -38), Color("#604a31"), 7.0)
	draw_rect(Rect2(pos + Vector2(-24, -48), Vector2(48, 17)), Color("#765939"))
	draw_line(pos + Vector2(-18, -33), pos + Vector2(18, -33), Color("#8f7048"), 4.0)
	draw_line(pos + Vector2(0, -44), pos + Vector2(25, -56), Color("#d5c49d"), 3.0)
	draw_string(font, pos + Vector2(-48, 42), "ДОЗОР", HORIZONTAL_ALIGNMENT_CENTER, 96, 10, Color("#ded1b7"))


func _draw_choice_shrine(pos: Vector2, label: String, color: Color) -> void:
	# A choice is represented as a build site in the world, not as a menu button.
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.006 + pos.x) * 0.05
	draw_rect(Rect2(pos + Vector2(-34, -17), Vector2(68, 42)), Color(color.r, color.g, color.b, 0.13))
	draw_line(pos + Vector2(-33, 24), pos + Vector2(-33, -25), Color("#7b684a"), 4.0)
	draw_line(pos + Vector2(33, 24), pos + Vector2(33, -25), Color("#7b684a"), 4.0)
	draw_line(pos + Vector2(-35, -22), pos + Vector2(35, -22), Color("#9d8052"), 4.0)
	draw_arc(pos, 42.0 * pulse, 0.0, TAU, 36, Color(color.r, color.g, color.b, 0.42), 2.0)
	draw_string(font, pos + Vector2(-86, 54), label, HORIZONTAL_ALIGNMENT_CENTER, 172, 11, Color("#f0e4cf"))


func _draw_core(pos: Vector2) -> void:
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.10
	draw_circle(pos, 24.0 * pulse, Color(1.0, 0.42, 0.18, 0.12))
	draw_circle(pos, 13.0 * pulse, Color("#ef6d38"))
	draw_circle(pos, 6.0 * pulse, Color("#ffd57e"))


func _draw_world_marker(pos: Vector2, color: Color, label: String) -> void:
	draw_circle(pos, 43.0, Color(color.r, color.g, color.b, 0.12))
	draw_arc(pos, 34.0, 0.0, TAU, 36, color, 2.0)
	draw_circle(pos, 12.0, Color(color.r, color.g, color.b, 0.65))
	draw_string(font, pos + Vector2(-65, 58), label, HORIZONTAL_ALIGNMENT_CENTER, 130, 12, Color("#eee2cb"))


func _draw_small_building(pos: Vector2, _kind: String) -> void:
	draw_rect(Rect2(pos + Vector2(-22, -15), Vector2(44, 30)), Color("#4f4435"))
	var roof := PackedVector2Array([
		pos + Vector2(-28, -15), pos + Vector2(0, -35), pos + Vector2(28, -15)
	])
	draw_colored_polygon(roof, Color("#6a563d"))
	draw_rect(Rect2(pos + Vector2(-5, 1), Vector2(10, 14)), Color("#2b2923"))


func _draw_world_progress() -> void:
	if stage == Stage.DAY1_GATHER:
		var need := 5
		draw_string(font, HEARTH_POS + Vector2(-72, -78), "БРЁВНА %d/%d" % [mini(camp_wood, need), need], HORIZONTAL_ALIGNMENT_CENTER, 144, 12, Color("#f1d79f"))
	elif stage == Stage.DAY2_BUILD:
		var pos := HEARTH_POS + Vector2(-112, -48)
		draw_string(font, pos + Vector2(-78, -55), "МАСТЕРСКАЯ", HORIZONTAL_ALIGNMENT_CENTER, 156, 11, Color("#e7dbc4"))
		draw_string(font, pos + Vector2(-78, -40), "дерево %d/8  ·  камень %d/5" % [mini(camp_wood, 8), mini(camp_stone, 5)], HORIZONTAL_ALIGNMENT_CENTER, 156, 10, Color("#d4ba88"))
	elif stage == Stage.DAY3_TOWER:
		var pos := HEARTH_POS + Vector2(104, -39)
		draw_string(font, pos + Vector2(-78, -62), "ДОЗОРНАЯ БАШНЯ", HORIZONTAL_ALIGNMENT_CENTER, 156, 11, Color("#e7dbc4"))
		draw_string(font, pos + Vector2(-78, -47), "дерево %d/6  ·  камень %d/6" % [mini(camp_wood, 6), mini(camp_stone, 6)], HORIZONTAL_ALIGNMENT_CENTER, 156, 10, Color("#d4ba88"))


func _guidance_info() -> Dictionary:
	if stage == Stage.DAY1_GATHER:
		if carried_wood + carried_stone > 0:
			return {"pos": HEARTH_POS, "text": "ОТНЕСИ К ОЧАГУ"}
		if resource_pickups.size() > 0:
			var best := resource_pickups[0]
			var best_d := hero_pos.distance_to(best["pos"])
			for pickup: Dictionary in resource_pickups:
				var d := hero_pos.distance_to(pickup["pos"])
				if d < best_d:
					best = pickup
					best_d = d
			return {"pos": best["pos"], "text": "ПОДБЕРИ"}
		var found := false
		var best_pos := HEARTH_POS
		var best_d := INF
		for node: Dictionary in resource_nodes:
			if not bool(node.get("alive", false)) or String(node.get("kind", "")) != "tree":
				continue
			var d := hero_pos.distance_to(node["pos"])
			if d < best_d:
				best_pos = node["pos"]
				best_d = d
				found = true
		if found:
			return {"pos": best_pos, "text": "СРУБИ ДЕРЕВО"}
	elif stage == Stage.DAY1_RESCUE and not survivor_one_found:
		return {"pos": survivor_one_pos, "text": "ВЫЖИВШИЙ"}
	elif stage == Stage.DAY2_RESCUE and not survivor_two_found:
		return {"pos": survivor_two_pos, "text": "ОСВОБОДИ"}
	elif stage == Stage.CORE_RETURN:
		if core_carried:
			return {"pos": HEARTH_POS, "text": "НЕСИ ЯДРО"}
		if core_active:
			return {"pos": core_pos, "text": "ЗАБЕРИ ЯДРО"}
	return {}


func _draw_guidance_marker() -> void:
	var info := _guidance_info()
	if info.is_empty():
		return
	var pos: Vector2 = info["pos"]
	var label := String(info["text"])
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.09
	var marker_y := pos.y - 46.0 - 4.0 * pulse
	var tri := PackedVector2Array([
		Vector2(pos.x, marker_y + 10), Vector2(pos.x - 7, marker_y), Vector2(pos.x + 7, marker_y)
	])
	draw_colored_polygon(tri, Color("#f1c979"))
	draw_string(font, Vector2(pos.x - 70, marker_y - 8), label, HORIZONTAL_ALIGNMENT_CENTER, 140, 10, Color("#f0dfbd"))


func _draw_particles() -> void:
	for p: Dictionary in particles:
		var pos: Vector2 = p["pos"]
		var life := clampf(float(p.get("life", 0.0)), 0.0, 1.0)
		draw_circle(pos, 3.0, Color(0.95, 0.74, 0.36, life))


func _draw_floaters() -> void:
	for f: Dictionary in floaters:
		var pos: Vector2 = f["pos"]
		var life := clampf(float(f.get("life", 0.0)), 0.0, 1.0)
		var color: Color = f["color"]
		color.a = life
		draw_string(font, pos + Vector2(-55, 0), String(f.get("text", "")), HORIZONTAL_ALIGNMENT_CENTER, 110, 12, color)


func _draw_hud() -> void:
	draw_rect(Rect2(Vector2(0, 0), Vector2(480, 82)), Color(0.025, 0.04, 0.032, 0.90))

	if mode == Mode.HUB:
		draw_string(font, Vector2(14, 28), "ПОСЛЕДНИЙ ОЧАГ", HORIZONTAL_ALIGNMENT_LEFT, 235, 17, Color("#f0e4cd"))
		draw_string(font, Vector2(310, 28), "УГЛИ  %d" % int(meta.get("embers", 0)), HORIZONTAL_ALIGNMENT_RIGHT, 150, 14, Color("#e6c57e"))
		draw_string(font, Vector2(14, 55), "Подойди к зданию — действие произойдёт в мире", HORIZONTAL_ALIGNMENT_LEFT, 410, 11, Color("#98a89c"))
		draw_string(font, Vector2(430, 55), "v0.5", HORIZONTAL_ALIGNMENT_RIGHT, 34, 10, Color("#728077"))
		return

	if mode == Mode.RESULT:
		return

	var stage_title := _stage_title()
	var short_goal := _short_objective_text()
	draw_string(font, Vector2(14, 27), stage_title, HORIZONTAL_ALIGNMENT_LEFT, 292, 15, Color("#f1e7d2"))
	draw_string(font, Vector2(328, 27), "ЛЮДИ %d" % survivors, HORIZONTAL_ALIGNMENT_LEFT, 72, 12, Color("#d8cfba"))
	draw_string(font, Vector2(408, 27), "УГЛИ %d" % run_embers, HORIZONTAL_ALIGNMENT_LEFT, 58, 11, Color("#efc071"))

	var cargo := carried_wood + carried_stone
	draw_string(font, Vector2(14, 56), short_goal, HORIZONTAL_ALIGNMENT_LEFT, 320, 11, Color("#aebcaf"))
	draw_string(font, Vector2(351, 56), "ГРУЗ %d/%d" % [cargo, carry_limit], HORIZONTAL_ALIGNMENT_LEFT, 112, 11, Color("#d9c39a"))

	if stage in [Stage.NIGHT1, Stage.NIGHT2, Stage.NIGHT3]:
		draw_rect(Rect2(Vector2(14, 70), Vector2(450, 5)), Color("#2b302b"))
		draw_rect(Rect2(Vector2(14, 70), Vector2(450.0 * clampf(hearth_hp / hearth_max_hp, 0.0, 1.0), 5)), Color("#d18c51"))


func _short_objective_text() -> String:
	match stage:
		Stage.DAY1_GATHER: return "Сруби дерево → подбери брёвна → вернись к огню"
		Stage.DAY1_RESCUE: return "Свет открыл выжившего"
		Stage.NIGHT1: return "Держись у света"
		Stage.DAY2_BUILD: return "Восстанови мастерскую"
		Stage.WORKSHOP_CHOICE: return "Выбери одну постройку"
		Stage.DAY2_RESCUE: return "Освободи рабочего"
		Stage.NIGHT2: return "Береги Очаг от быстрых"
		Stage.DAY3_TOWER: return "Построй дозорную башню"
		Stage.EXPEDITION_CHOICE: return "Выбери силу перед последней ночью"
		Stage.NIGHT3: return "Хранитель уже близко"
		Stage.CORE_RETURN: return "Верни ядро в Очаг"
	return ""


func _stage_title() -> String:
	match stage:
		Stage.DAY1_GATHER: return "ДЕНЬ 1 · разожги очаг"
		Stage.DAY1_RESCUE: return "ДЕНЬ 1 · найден выживший"
		Stage.NIGHT1: return "НОЧЬ 1"
		Stage.DAY2_BUILD: return "ДЕНЬ 2 · восстанови мастерскую"
		Stage.WORKSHOP_CHOICE: return "ДЕНЬ 2 · выбери развитие"
		Stage.DAY2_RESCUE: return "ДЕНЬ 2 · освободи рабочего"
		Stage.NIGHT2: return "НОЧЬ 2"
		Stage.DAY3_TOWER: return "ДЕНЬ 3 · построй башню"
		Stage.EXPEDITION_CHOICE: return "ДЕНЬ 3 · древний алтарь"
		Stage.NIGHT3: return "НОЧЬ 3 · хранитель идёт"
		Stage.CORE_RETURN: return "ПОСЛЕ БОЯ · ядро хранителя"
	return ""


func _objective_text() -> String:
	match stage:
		Stage.DAY1_GATHER:
			return "Сруби дерево, подбери брёвна с земли и отнеси 5 к очагу."
		Stage.DAY1_RESCUE:
			return "Подойди к найденному выжившему."
		Stage.NIGHT1:
			return "Защити огонь. Чем ближе ты к врагам, тем раньше начнёшь стрелять."
		Stage.DAY2_BUILD:
			return "Мастерская: 8 дерева + 5 камня."
		Stage.WORKSHOP_CHOICE:
			return "Подойди к одному из двух улучшений."
		Stage.DAY2_RESCUE:
			return "Уничтожь стражей и подойди к рабочему."
		Stage.NIGHT2:
			return "Перехватывай быстрых. В конце придёт элита."
		Stage.DAY3_TOWER:
			return "Башня: 6 дерева + 6 камня."
		Stage.EXPEDITION_CHOICE:
			return "Выбери: больше бойцов или сильнее каждый выстрел."
		Stage.NIGHT3:
			return "Переживи волну и останови Хранителя леса."
		Stage.CORE_RETURN:
			return "Подбери ядро и физически отнеси его к очагу."
	return ""


func _draw_banner() -> void:
	if banner_timer <= 0.0 or banner_text == "":
		return
	var alpha := clampf(banner_timer * 1.5, 0.0, 1.0)
	draw_rect(Rect2(Vector2(56, 120), Vector2(368, 54)), Color(0.02, 0.03, 0.025, 0.82 * alpha))
	draw_string(font, Vector2(70, 153), banner_text, HORIZONTAL_ALIGNMENT_CENTER, 340, 15, Color(0.96, 0.91, 0.80, alpha))


func _draw_joystick() -> void:
	if not joystick_active or mode == Mode.RESULT:
		return
	draw_circle(joystick_origin, JOYSTICK_RADIUS + 8.0, Color(0.01, 0.02, 0.015, 0.24))
	draw_circle(joystick_origin, JOYSTICK_RADIUS, Color(0.92, 0.94, 0.89, 0.12))
	draw_arc(joystick_origin, JOYSTICK_RADIUS, 0.0, TAU, 40, Color(0.95, 0.86, 0.62, 0.46), 2.5)
	draw_circle(joystick_knob, 24.0, Color(0.95, 0.86, 0.62, 0.30))
	draw_circle(joystick_knob, 15.0, Color(0.98, 0.91, 0.72, 0.68))


func _draw_flash() -> void:
	if flash_timer <= 0.0:
		return
	var alpha := clampf(flash_timer * 0.7, 0.0, 0.45)
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(1.0, 0.78, 0.42, alpha))


func _draw_result_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.005, 0.012, 0.009, 0.84))
	var panel := Rect2(Vector2(30, 224), Vector2(420, 330))
	draw_rect(panel, Color("#16231c"))
	draw_rect(Rect2(panel.position, Vector2(panel.size.x, 5)), Color("#d29550") if result_win else Color("#824842"))

	draw_string(font, Vector2(50, 286), result_title, HORIZONTAL_ALIGNMENT_CENTER, 380, 22, Color("#f4e6ce"))
	draw_string(font, Vector2(62, 333), result_subtitle, HORIZONTAL_ALIGNMENT_CENTER, 356, 13, Color("#b8c7bb"))
	draw_string(font, Vector2(62, 392), "УГЛИ ЗА ВЫЛАЗКУ  +%d" % run_embers, HORIZONTAL_ALIGNMENT_CENTER, 356, 15, Color("#ecc178"))

	if result_win:
		draw_string(font, Vector2(62, 434), "Лес отступил. Поселение стало сильнее.", HORIZONTAL_ALIGNMENT_CENTER, 356, 12, Color("#9eb09f"))
	else:
		draw_string(font, Vector2(62, 434), "Постоянные улучшения сохранены. Лес изменится в новой попытке.", HORIZONTAL_ALIGNMENT_CENTER, 356, 11, Color("#9eb09f"))

	draw_rect(Rect2(Vector2(93, 480), Vector2(294, 44)), Color("#2a382e"))
	draw_string(font, Vector2(105, 507), "КОСНИСЬ · ВЕРНУТЬСЯ К ОЧАГУ", HORIZONTAL_ALIGNMENT_CENTER, 270, 12, Color("#f0d7a1"))


func _draw_ellipse_custom(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
