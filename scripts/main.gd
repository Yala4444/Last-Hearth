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
	if mode == Mode.HUB:
		_draw_hub()
	else:
		_draw_expedition()

	_draw_particles()
	_draw_floaters()
	_draw_hud()
	_draw_banner()
	_draw_joystick()
	_draw_flash()

	if mode == Mode.RESULT:
		_draw_result_overlay()


func _draw_hub() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("#142019"))
	_draw_ground_texture(Color("#1b2b21"), 56)
	_draw_light_field(HEARTH_POS, 235.0)
	_draw_hearth(HEARTH_POS, maxi(2, int(meta.get("hearth_rank", 1)) + 1))

	_draw_world_marker(HUB_MAP_POS, Color("#6d8b72"), "КАРТА")
	_draw_world_marker(HUB_CARRY_POS, Color("#856e4d"), "РЮКЗАК")
	_draw_world_marker(HUB_DAMAGE_POS, Color("#8d5148"), "ОРУЖИЕ")

	_draw_small_building(Vector2(72, 225), "дом")
	_draw_small_building(Vector2(390, 235), "кузня")
	_draw_small_building(Vector2(70, 585), "склад")
	_draw_small_building(Vector2(395, 590), "дозор")

	var resident_count := 3 if bool(meta.get("forest_cleared", false)) else 2
	for i in range(resident_count):
		var angle := float(i) * TAU / float(maxi(1, resident_count)) + 0.5
		var p := HEARTH_POS + Vector2(cos(angle), sin(angle)) * 105.0
		_draw_person(p, Color("#c7c2ae"), 0.0)

	_draw_hero(hero_pos)

	draw_string(font, Vector2(18, 128), "ПОСЛЕДНИЙ ОЧАГ", HORIZONTAL_ALIGNMENT_LEFT, 250, 22, Color("#f4ead4"))
	if bool(meta.get("forest_cleared", false)):
		draw_string(font, Vector2(18, 151), "Забытый лес очищен · Мёртвые поля впереди", HORIZONTAL_ALIGNMENT_LEFT, 430, 13, Color("#b8c8b8"))
	else:
		draw_string(font, Vector2(18, 151), "Подойди к карте, чтобы начать новую вылазку", HORIZONTAL_ALIGNMENT_LEFT, 430, 13, Color("#b8c8b8"))

	var carry_cost := 3 + int(meta.get("carry_level", 0)) * 2
	var damage_cost := 4 + int(meta.get("damage_level", 0)) * 3
	draw_string(font, HUB_CARRY_POS + Vector2(-68, 58), "ур.%d · %d угля" % [int(meta.get("carry_level", 0)), carry_cost], HORIZONTAL_ALIGNMENT_CENTER, 136, 12, Color("#d8c7a4"))
	draw_string(font, HUB_DAMAGE_POS + Vector2(-68, 58), "ур.%d · %d угля" % [int(meta.get("damage_level", 0)), damage_cost], HORIZONTAL_ALIGNMENT_CENTER, 136, 12, Color("#d8c7a4"))


func _draw_expedition() -> void:
	var night := stage in [Stage.NIGHT1, Stage.NIGHT2, Stage.NIGHT3]
	var bg := Color("#101813") if night else Color("#19251d")
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), bg)
	_draw_ground_texture(Color("#1d3023") if not night else Color("#162119"), 64)
	_draw_light_field(HEARTH_POS, light_radius)

	for node: Dictionary in resource_nodes:
		_draw_resource(node)
	for pickup: Dictionary in resource_pickups:
		_draw_resource_pickup(pickup)

	if stage == Stage.DAY1_RESCUE and not survivor_one_found:
		_draw_survivor(survivor_one_pos, "?")
	if stage == Stage.DAY2_RESCUE and not survivor_two_found:
		_draw_survivor(survivor_two_pos, "!")
	if stage == Stage.WORKSHOP_CHOICE:
		_draw_choice_shrine(left_choice_pos, "ОРУЖИЕ", Color("#a85949"))
		_draw_choice_shrine(right_choice_pos, "ЛЕС", Color("#567e58"))
	if stage == Stage.EXPEDITION_CHOICE:
		_draw_choice_shrine(left_choice_pos, "+2 БОЙЦА", Color("#6688a0"))
		_draw_choice_shrine(right_choice_pos, "+60% УРОН", Color("#b75e45"))

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
		_draw_core(hero_pos + Vector2(0, -38))

	_draw_hearth(HEARTH_POS, hearth_level)
	_draw_companions()
	_draw_hero(hero_pos)

	if night:
		draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.02, 0.035, 0.05, 0.15))


func _draw_ground_texture(color: Color, spacing: int) -> void:
	for y in range(140, 790, spacing):
		for x in range(20, 470, spacing):
			var offset := float((x * 13 + y * 7) % 17)
			draw_circle(Vector2(float(x) + offset, float(y)), 2.0, color)


func _draw_light_field(center: Vector2, radius: float) -> void:
	for i in range(9, 0, -1):
		var t := float(i) / 9.0
		var r := radius * t
		var alpha := 0.018 + (1.0 - t) * 0.018
		draw_circle(center, r, Color(0.96, 0.67, 0.30, alpha))


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


func _draw_hearth(pos: Vector2, level: int) -> void:
	draw_circle(pos + Vector2(0, 12), 48.0 + float(level) * 2.0, Color(0.03, 0.04, 0.03, 0.34))
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		var stone := pos + Vector2(cos(angle), sin(angle)) * (34.0 + float(level))
		draw_circle(stone, 8.0, Color("#55524a"))

	var flame_h := 27.0 + float(level) * 5.5
	var flame_w := 18.0 + float(level) * 2.0
	var outer := PackedVector2Array([
		pos + Vector2(0, -flame_h),
		pos + Vector2(flame_w, 9),
		pos + Vector2(0, 22),
		pos + Vector2(-flame_w, 9)
	])
	draw_colored_polygon(outer, Color("#f0a53f"))
	var inner := PackedVector2Array([
		pos + Vector2(0, -flame_h * 0.55),
		pos + Vector2(9, 8),
		pos + Vector2(0, 16),
		pos + Vector2(-9, 8)
	])
	draw_colored_polygon(inner, Color("#ffe6a0"))
	draw_string(font, pos + Vector2(-45, 66), "ОЧАГ %d" % level, HORIZONTAL_ALIGNMENT_CENTER, 90, 12, Color("#e8dec8"))


func _draw_hero(pos: Vector2) -> void:
	var bob := sin(hero_walk_phase) * 2.0
	_draw_ellipse_custom(pos + Vector2(0, 18), Vector2(18, 7), Color(0, 0, 0, 0.28))
	draw_circle(pos + Vector2(0, bob), 15.0, Color("#d6cfb8"))
	draw_circle(pos + Vector2(0, -10 + bob), 8.0, Color("#c9a48a"))
	draw_line(pos + Vector2(10, -1 + bob), pos + Vector2(23, -13 + bob), Color("#d8d2c0"), 3.0)

	var carried := carried_wood + carried_stone
	if carried > 0:
		for i in range(mini(carried, 6)):
			var p := pos + Vector2(-14 + float(i % 3) * 14.0, -30.0 - float(i / 3) * 10.0)
			if i < carried_wood:
				draw_rect(Rect2(p + Vector2(-6, -3), Vector2(12, 6)), Color("#b7824e"))
			else:
				draw_circle(p, 5.0, Color("#8e9999"))


func _draw_companions() -> void:
	for agent: Dictionary in survivor_agents:
		var role := String(agent.get("role", "guard"))
		var pos: Vector2 = agent["pos"]
		var phase := float(agent.get("phase", 0.0))
		var body_color := Color("#758d68")
		if role == "worker":
			body_color = Color("#a27a52")
		elif role == "guard":
			body_color = Color("#6c8196")

		_draw_person(pos, body_color, phase)

		if role == "hunter":
			draw_line(pos + Vector2(8, -3), pos + Vector2(18, -12), Color("#d5c39d"), 2.0)
			draw_arc(pos + Vector2(17, -8), 7.0, -1.6, 1.4, 10, Color("#d5c39d"), 1.5)
		elif role == "worker":
			draw_line(pos + Vector2(7, 0), pos + Vector2(18, -8), Color("#c8b086"), 3.0)
			draw_rect(Rect2(pos + Vector2(15, -12), Vector2(8, 7)), Color("#8f7657"))
		else:
			draw_line(pos + Vector2(8, -2), pos + Vector2(20, -11), Color("#c6ccd0"), 2.0)


func _draw_person(pos: Vector2, color: Color, phase: float) -> void:
	var bob := sin(phase) * 1.4
	_draw_ellipse_custom(pos + Vector2(0, 14), Vector2(12, 5), Color(0, 0, 0, 0.22))
	draw_circle(pos + Vector2(0, bob), 10.0, color)
	draw_circle(pos + Vector2(0, -8 + bob), 5.0, Color("#b9947c"))


func _draw_survivor(pos: Vector2, mark: String) -> void:
	draw_circle(pos, 25.0, Color(0.75, 0.80, 0.69, 0.08))
	_draw_person(pos, Color("#b9bbaa"), 0.0)
	draw_string(font, pos + Vector2(-12, -28), mark, HORIZONTAL_ALIGNMENT_CENTER, 24, 18, Color("#f4ead4"))


func _draw_enemy(enemy: Dictionary) -> void:
	var pos: Vector2 = enemy["pos"]
	var kind := String(enemy.get("kind", "basic"))
	var radius := float(enemy.get("radius", 14.0))
	var color := Color("#96534b")
	if kind == "fast":
		color = Color("#ad6a4b")
	elif kind == "elite":
		color = Color("#814c68")
	elif kind == "boss":
		color = Color("#594060")
	elif kind == "guard":
		color = Color("#725451")

	_draw_ellipse_custom(pos + Vector2(0, radius * 0.9), Vector2(radius, radius * 0.35), Color(0, 0, 0, 0.32))
	draw_circle(pos, radius, color)
	draw_circle(pos + Vector2(-radius * 0.35, -radius * 0.18), maxf(2.0, radius * 0.13), Color("#efc36d"))
	draw_circle(pos + Vector2(radius * 0.35, -radius * 0.18), maxf(2.0, radius * 0.13), Color("#efc36d"))

	var hp := float(enemy.get("hp", 1.0))
	var max_hp := float(enemy.get("max_hp", 1.0))
	var bar_w := radius * 2.2
	draw_rect(Rect2(pos + Vector2(-bar_w * 0.5, -radius - 12), Vector2(bar_w, 4)), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(pos + Vector2(-bar_w * 0.5, -radius - 12), Vector2(bar_w * clampf(hp / max_hp, 0.0, 1.0), 4)), Color("#e8d6a1"))

	if kind == "boss":
		draw_string(font, pos + Vector2(-60, -radius - 22), "ХРАНИТЕЛЬ ЛЕСА", HORIZONTAL_ALIGNMENT_CENTER, 120, 11, Color("#e9d8cf"))


func _draw_shot(shot: Dictionary) -> void:
	var pos: Vector2 = shot["pos"]
	var tower := bool(shot.get("tower", false))
	draw_circle(pos, 3.0 if not tower else 4.0, Color("#fff0b2") if not tower else Color("#f0bd68"))


func _draw_workshop() -> void:
	var pos := HEARTH_POS + Vector2(-105, -42)
	draw_rect(Rect2(pos + Vector2(-25, -18), Vector2(50, 36)), Color("#5e4c38"))
	draw_line(pos + Vector2(-30, -18), pos + Vector2(0, -38), Color("#8a6d49"), 5.0)
	draw_line(pos + Vector2(0, -38), pos + Vector2(30, -18), Color("#8a6d49"), 5.0)
	draw_string(font, pos + Vector2(-38, 34), "мастерская", HORIZONTAL_ALIGNMENT_CENTER, 76, 10, Color("#d7c9ad"))


func _draw_tower() -> void:
	var pos := HEARTH_POS + Vector2(92, -35)
	draw_rect(Rect2(pos + Vector2(-10, -40), Vector2(20, 55)), Color("#6a543b"))
	draw_rect(Rect2(pos + Vector2(-20, -50), Vector2(40, 14)), Color("#7b6041"))
	draw_line(pos + Vector2(0, -45), pos + Vector2(20, -56), Color("#d4cbaa"), 3.0)


func _draw_choice_shrine(pos: Vector2, label: String, color: Color) -> void:
	draw_circle(pos, 42.0, Color(color.r, color.g, color.b, 0.10))
	draw_circle(pos, 28.0, Color(color.r, color.g, color.b, 0.22))
	draw_arc(pos, 31.0, 0.0, TAU, 36, color, 2.0)
	draw_string(font, pos + Vector2(-70, 60), label, HORIZONTAL_ALIGNMENT_CENTER, 140, 12, Color("#f0e4cf"))


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
	draw_rect(Rect2(Vector2(0, 0), Vector2(480, 108)), Color(0.035, 0.05, 0.04, 0.93))

	if mode == Mode.HUB:
		draw_string(font, Vector2(16, 30), "УГЛИ %d" % int(meta.get("embers", 0)), HORIZONTAL_ALIGNMENT_LEFT, 120, 15, Color("#f0d298"))
		draw_string(font, Vector2(145, 30), "РЮКЗАК +%d" % int(meta.get("carry_level", 0)), HORIZONTAL_ALIGNMENT_LEFT, 115, 14, Color("#d7cab0"))
		draw_string(font, Vector2(275, 30), "УРОН +%d%%" % (int(meta.get("damage_level", 0)) * 10), HORIZONTAL_ALIGNMENT_LEFT, 120, 14, Color("#d7cab0"))
		draw_string(font, Vector2(414, 30), "v0.5", HORIZONTAL_ALIGNMENT_LEFT, 50, 12, Color("#87968a"))
		draw_string(font, Vector2(16, 70), "Хаб живёт между вылазками. Всё здесь сохраняется.", HORIZONTAL_ALIGNMENT_LEFT, 448, 13, Color("#a9b5a8"))
		return

	if mode == Mode.RESULT:
		return

	var stage_title := _stage_title()
	var objective := _objective_text()
	draw_string(font, Vector2(14, 25), stage_title, HORIZONTAL_ALIGNMENT_LEFT, 278, 15, Color("#f1e7d2"))
	draw_string(font, Vector2(304, 25), "ЛЮДИ %d" % survivors, HORIZONTAL_ALIGNMENT_LEFT, 86, 13, Color("#d8cfba"))
	draw_string(font, Vector2(396, 25), "УГЛИ %d" % run_embers, HORIZONTAL_ALIGNMENT_LEFT, 70, 12, Color("#efc071"))

	draw_string(font, Vector2(14, 50), "ДЕРЕВО %d   КАМЕНЬ %d   ГРУЗ %d/%d" % [camp_wood, camp_stone, carried_wood + carried_stone, carry_limit], HORIZONTAL_ALIGNMENT_LEFT, 450, 12, Color("#c7baa1"))
	draw_string(font, Vector2(14, 78), objective, HORIZONTAL_ALIGNMENT_LEFT, 448, 12, Color("#bac7b9"))

	if stage in [Stage.NIGHT1, Stage.NIGHT2, Stage.NIGHT3]:
		draw_rect(Rect2(Vector2(14, 90), Vector2(452, 6)), Color("#2d312c"))
		draw_rect(Rect2(Vector2(14, 90), Vector2(452.0 * clampf(hearth_hp / hearth_max_hp, 0.0, 1.0), 6)), Color("#d49154"))


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
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.01, 0.02, 0.015, 0.80))
	var panel := Rect2(Vector2(34, 245), Vector2(412, 285))
	draw_rect(panel, Color("#1b261f"))
	draw_rect(Rect2(panel.position + Vector2(0, 0), Vector2(panel.size.x, 5)), Color("#c9874e") if result_win else Color("#884f49"))

	draw_string(font, Vector2(55, 305), result_title, HORIZONTAL_ALIGNMENT_CENTER, 370, 22, Color("#f3e5ce"))
	draw_string(font, Vector2(64, 350), result_subtitle, HORIZONTAL_ALIGNMENT_CENTER, 352, 14, Color("#bcc8bb"))
	draw_string(font, Vector2(64, 407), "Получено углей: +%d" % run_embers, HORIZONTAL_ALIGNMENT_CENTER, 352, 16, Color("#efc06f"))

	if result_win:
		draw_string(font, Vector2(64, 447), "Следующий регион открыт сюжетно. В прототипе пока можно повторить лес.", HORIZONTAL_ALIGNMENT_CENTER, 352, 12, Color("#91a293"))
	else:
		draw_string(font, Vector2(64, 447), "Следующая попытка получит другую расстановку ресурсов и спасённых.", HORIZONTAL_ALIGNMENT_CENTER, 352, 12, Color("#91a293"))

	draw_string(font, Vector2(64, 500), "КОСНИСЬ ЭКРАНА · ВЕРНУТЬСЯ В ХАБ", HORIZONTAL_ALIGNMENT_CENTER, 352, 13, Color("#f0d7a1"))


func _draw_ellipse_custom(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
