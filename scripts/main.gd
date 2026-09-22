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
const ROUTE_HUNTER_GATE := Vector2(42.0, 350.0)
const ROUTE_SAWMILL_GATE := Vector2(438.0, 285.0)
const ROUTE_WORKER_GATE := Vector2(438.0, 345.0)
const ROUTE_WATCH_GATE := Vector2(42.0, 330.0)
const ROUTE_ALTAR_GATE := Vector2(438.0, 330.0)
const ROUTE_RETURN_GATE := Vector2(240.0, 748.0)

const TEX_HERO_IDLE: Texture2D = preload("res://assets/v08/sprint1/hero_idle.svg")
const TEX_HERO_WALK: Texture2D = preload("res://assets/v08/sprint1/hero_walk.svg")
const TEX_HERO_ATTACK: Texture2D = preload("res://assets/v08/sprint1/hero_attack.svg")
const TEX_HERO_CARRY_1: Texture2D = preload("res://assets/v08/sprint1/hero_carry_1.svg")
const TEX_HERO_CARRY_2: Texture2D = preload("res://assets/v08/sprint1/hero_carry_2.svg")
const TEX_HERO_CARRY_3: Texture2D = preload("res://assets/v08/sprint1/hero_carry_3.svg")
const TEX_TREE_A: Texture2D = preload("res://assets/v08/sprint1/tree_a.svg")
const TEX_TREE_B: Texture2D = preload("res://assets/v08/sprint1/tree_b.svg")
const TEX_TREE_C: Texture2D = preload("res://assets/v08/sprint1/tree_c.svg")
const TEX_TREE_FALLING: Texture2D = preload("res://assets/v08/sprint1/tree_falling.svg")
const TEX_STUMP: Texture2D = preload("res://assets/v08/sprint1/stump.svg")
const TEX_LOG: Texture2D = preload("res://assets/v08/sprint1/log.svg")
const TEX_HEARTH_1: Texture2D = preload("res://assets/v08/sprint1/hearth_1.svg")
const TEX_HEARTH_2: Texture2D = preload("res://assets/v08/sprint1/hearth_2.svg")
const TEX_ROCK: Texture2D = preload("res://assets/v08/sprint1/rock.svg")
const TEX_GRASS: Texture2D = preload("res://assets/v08/sprint1/grass.svg")

enum Mode {
	HUB,
	EXPEDITION,
	RESULT
}

enum Area {
	CAMP,
	HUNTER_TRAIL,
	SAWMILL,
	WORKER_RUINS,
	WATCH_RIDGE,
	ALTAR_GLADE
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
	"build_version": 10,
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
var hero_max_hp := 100.0
var hero_hp := 100.0
var route_grace_timer := 0.0
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
var map_variant := 0
var map_variant_name := "Тихая поляна"
var area: Area = Area.CAMP
var day1_route := ""
var day1_route_complete := false
var sawmill_claimed := false
var worker_route_complete := false
var worker_clear_announced := false
var day3_route := ""
var day3_route_complete := false
var watch_repair_started := false
var final_altar_claimed := false
var camp_resource_backup: Array = []
var camp_event_backup: Array = []
var camp_decor_backup: Array = []
var events: Array[Dictionary] = []
var story_hint := ""
var story_hint_timer := 0.0
var stage_transition_lock := false
var hub_feedback_text := ""
var hub_feedback_pos := Vector2.ZERO
var hub_feedback_timer := 0.0
var region_map_open := false
var dawn_timer := 0.0
var dawn_pending := 0
var boss_delay_timer := 0.0
var boss_announced := false
var active_night_sides: Array[int] = []
var enemy_deaths: Array[Dictionary] = []
var current_stage_wood_start := 0
var current_stage_stone_start := 0

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
var light_display_radius := 165.0
var upgrade_wave := 0.0
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
	story_hint_timer = maxf(0.0, story_hint_timer - delta)
	hub_feedback_timer = maxf(0.0, hub_feedback_timer - delta)
	flash_timer = maxf(0.0, flash_timer - delta)
	route_grace_timer = maxf(0.0, route_grace_timer - delta)
	_update_enemy_deaths(delta)
	hero_shot_cd = maxf(0.0, hero_shot_cd - delta)
	gather_cd = maxf(0.0, gather_cd - delta)
	pickup_cd = maxf(0.0, pickup_cd - delta)
	unload_cd = maxf(0.0, unload_cd - delta)
	tower_cd = maxf(0.0, tower_cd - delta)
	camera_shake = maxf(0.0, camera_shake - delta * 8.0)
	hearth_pulse = maxf(0.0, hearth_pulse - delta * 2.5)
	upgrade_wave = maxf(0.0, upgrade_wave - delta * 0.72)
	light_display_radius = lerpf(light_display_radius, light_radius, 1.0 - exp(-delta * 2.8))
	_update_resource_flights(delta)

	if mode == Mode.HUB:
		_update_movement(delta)
		_update_hub_interactions()
	elif mode == Mode.EXPEDITION:
		_update_movement(delta)
		_update_expedition(delta)
		_check_day_progress()

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

	# v0.9 turns the Forgotten Forest into a small adventure chapter.
	# Existing testers get a fresh expedition while permanent hub upgrades remain.
	var loaded_version := int(meta.get("build_version", 0))
	if loaded_version < 9:
		meta["build_version"] = 9
		meta["first_run"] = true


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
	region_map_open = false
	hub_feedback_text = ""
	hub_feedback_timer = 0.0
	if message != "":
		_hub_feedback("ВОЗВРАЩЕНИЕ В ПОСЕЛЕНИЕ", HEARTH_POS, 1.8)


func _start_expedition() -> void:
	mode = Mode.EXPEDITION
	stage = Stage.DAY1_GATHER
	meta["attempts"] = int(meta.get("attempts", 0)) + 1
	_save_meta()

	run_seed = rng.randi()
	rng.seed = run_seed

	if int(meta.get("attempts", 1)) <= 1:
		hero_pos = Vector2(240.0, 688.0)
	else:
		hero_pos = Vector2(rng.randf_range(175.0, 305.0), rng.randf_range(640.0, 700.0))
	hero_target = hero_pos
	hero_walk_phase = 0.0
	hero_facing = Vector2(1.0, 0.0)
	hero_damage = 22.0 * (1.0 + 0.10 * float(int(meta.get("damage_level", 0))))
	hero_fire_rate = 0.52
	hero_shot_cd = 0.0
	hero_max_hp = 100.0
	hero_hp = hero_max_hp
	route_grace_timer = 0.0
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
	light_display_radius = light_radius
	upgrade_wave = 0.0
	workshop_built = false
	workshop_choice = ""
	tower_built = false
	tower_cd = 0.0
	expedition_choice = ""
	run_embers = 0
	current_night = 0
	map_variant = 0
	map_variant_name = "Тихая поляна"
	area = Area.CAMP
	day1_route = ""
	day1_route_complete = false
	sawmill_claimed = false
	worker_route_complete = false
	worker_clear_announced = false
	day3_route = ""
	day3_route_complete = false
	watch_repair_started = false
	final_altar_claimed = false
	camp_resource_backup.clear()
	camp_event_backup.clear()
	camp_decor_backup.clear()
	events.clear()
	story_hint = ""
	story_hint_timer = 0.0
	stage_transition_lock = false
	hub_feedback_text = ""
	hub_feedback_timer = 0.0
	region_map_open = false
	dawn_timer = 0.0
	dawn_pending = 0
	boss_delay_timer = 0.0
	boss_announced = false
	active_night_sides.clear()
	enemy_deaths.clear()
	current_stage_wood_start = 0
	current_stage_stone_start = 0

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
	_banner("Вылазка #%d | %s" % [int(meta.get("attempts", 1)), map_variant_name], 2.4)


func _generate_layout() -> void:
	resource_nodes.clear()
	events.clear()
	decor_points.clear()

	map_variant = 0 if int(meta.get("attempts", 1)) <= 1 else rng.randi_range(0, 3)
	var tree_slots: Array[Vector2] = []
	var rock_slots: Array[Vector2] = []

	match map_variant:
		0:
			map_variant_name = "Тихая поляна"
			tree_slots = [
				Vector2(90, 245), Vector2(175, 205), Vector2(300, 215), Vector2(392, 250),
				Vector2(82, 365), Vector2(398, 365), Vector2(105, 560), Vector2(380, 560),
				Vector2(170, 630), Vector2(315, 625), Vector2(75, 690), Vector2(410, 690)
			]
			rock_slots = [
				Vector2(130, 300), Vector2(355, 305), Vector2(135, 505),
				Vector2(345, 505), Vector2(240, 655), Vector2(420, 455)
			]
			_add_event("dead_camp", Vector2(92, 205))
			_add_event("altar", Vector2(392, 610))
			_add_event("tracks", Vector2(350, 315))
		1:
			map_variant_name = "Разорённая дорога"
			tree_slots = [
				Vector2(72, 225), Vector2(155, 250), Vector2(335, 225), Vector2(420, 260),
				Vector2(90, 405), Vector2(390, 410), Vector2(112, 585), Vector2(370, 590),
				Vector2(178, 680), Vector2(310, 675), Vector2(65, 730), Vector2(420, 720)
			]
			rock_slots = [
				Vector2(115, 320), Vector2(365, 335), Vector2(105, 520),
				Vector2(380, 510), Vector2(225, 620), Vector2(430, 445)
			]
			_add_event("wagon", Vector2(95, 315))
			_add_event("wounded", Vector2(386, 330))
			_add_event("broken_watch", Vector2(372, 585))
		2:
			map_variant_name = "Каменная низина"
			tree_slots = [
				Vector2(78, 245), Vector2(155, 205), Vector2(330, 205), Vector2(408, 250),
				Vector2(92, 400), Vector2(388, 395), Vector2(105, 590), Vector2(375, 600),
				Vector2(180, 690), Vector2(300, 690), Vector2(68, 735), Vector2(422, 730)
			]
			rock_slots = [
				Vector2(120, 300), Vector2(350, 290), Vector2(155, 470),
				Vector2(325, 465), Vector2(225, 585), Vector2(420, 520)
			]
			_add_event("altar", Vector2(98, 520))
			_add_event("black_tree", Vector2(390, 535))
			_add_event("tracks", Vector2(105, 645))
			_add_event("whisper", Vector2(398, 230))
		_:
			map_variant_name = "Сгоревшая усадьба"
			tree_slots = [
				Vector2(85, 230), Vector2(170, 215), Vector2(310, 215), Vector2(405, 230),
				Vector2(70, 390), Vector2(410, 400), Vector2(100, 565), Vector2(385, 560),
				Vector2(165, 650), Vector2(320, 650), Vector2(75, 725), Vector2(415, 715)
			]
			rock_slots = [
				Vector2(125, 300), Vector2(355, 300), Vector2(140, 505),
				Vector2(340, 500), Vector2(240, 640), Vector2(425, 455)
			]
			_add_event("dead_camp", Vector2(105, 345))
			_add_event("wagon", Vector2(382, 345))
			_add_event("wounded", Vector2(390, 610))
			_add_event("broken_watch", Vector2(110, 615))
			_add_event("whisper", Vector2(390, 225))

	var tree_count := 9
	if int(meta.get("attempts", 1)) <= 1 and map_variant == 0:
		resource_nodes.append({
			"kind": "tree",
			"pos": Vector2(240.0, 590.0),
			"hits": 3,
			"max_hits": 3,
			"alive": true,
			"fall_timer": 0.0,
			"drop_spawned": false,
			"variant": 1,
			"hit_flash": 0.0
		})
		tree_count = 8

	for i in range(tree_count):
		var index: int = rng.randi_range(0, tree_slots.size() - 1)
		var base: Vector2 = tree_slots[index]
		tree_slots.remove_at(index)
		var pos: Vector2 = base + Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-12.0, 12.0))
		resource_nodes.append({
			"kind": "tree",
			"pos": pos,
			"hits": 3,
			"max_hits": 3,
			"alive": true,
			"fall_timer": 0.0,
			"drop_spawned": false,
			"variant": rng.randi_range(0, 2),
			"hit_flash": 0.0
		})

	for i in range(5):
		var index: int = rng.randi_range(0, rock_slots.size() - 1)
		var base: Vector2 = rock_slots[index]
		rock_slots.remove_at(index)
		var pos: Vector2 = base + Vector2(rng.randf_range(-13.0, 13.0), rng.randf_range(-10.0, 10.0))
		resource_nodes.append({
			"kind": "rock",
			"pos": pos,
			"hits": 4,
			"max_hits": 4,
			"alive": true,
			"fall_timer": 0.0,
			"drop_spawned": false,
			"hit_flash": 0.0
		})

	for i in range(56):
		var dpos := Vector2(rng.randf_range(26.0, 454.0), rng.randf_range(128.0, 770.0))
		if dpos.distance_to(HEARTH_POS) < 80.0:
			continue
		var roll := rng.randf()
		var kind := "grass"
		if roll > 0.68:
			kind = "pebble"
		if roll > 0.88:
			kind = "branch"
		if map_variant == 3 and roll > 0.78:
			kind = "ash"
		decor_points.append({
			"pos": dpos,
			"kind": kind,
			"scale": rng.randf_range(0.72, 1.28)
		})

	var first_rescue_slots: Array[Vector2] = [
		Vector2(96, 520), Vector2(384, 525), Vector2(112, 335), Vector2(368, 338)
	]
	var second_rescue_slots: Array[Vector2] = [
		Vector2(92, 182), Vector2(388, 188), Vector2(78, 660), Vector2(404, 655)
	]
	var first_index: int = rng.randi_range(0, first_rescue_slots.size() - 1)
	survivor_one_pos = first_rescue_slots[first_index] + Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-8.0, 8.0))
	var second_index: int = rng.randi_range(0, second_rescue_slots.size() - 1)
	survivor_two_pos = second_rescue_slots[second_index] + Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-8.0, 8.0))

	if rng.randf() < 0.5:
		left_choice_pos = Vector2(130.0, 285.0)
		right_choice_pos = Vector2(350.0, 285.0)
	else:
		left_choice_pos = Vector2(125.0, 540.0)
		right_choice_pos = Vector2(355.0, 540.0)


func _add_event(kind: String, pos: Vector2) -> void:
	var required := 1.25
	if kind == "altar":
		required = 1.65
	elif kind == "wounded":
		required = 1.45
	elif kind == "dead_camp":
		required = 1.35
	elif kind == "tracks":
		required = 1.05
	elif kind == "broken_watch":
		required = 1.55
	elif kind == "whisper":
		required = 1.10
	elif kind == "sawmill":
		required = 1.85
	elif kind == "watch_repair":
		required = 1.90
	elif kind == "final_altar":
		required = 1.70
	events.append({
		"kind": kind,
		"pos": pos,
		"triggered": false,
		"outcome": "",
		"progress": 0.0,
		"required": required,
		"hits": 5
	})


func _active_light_center() -> Vector2:
	if area == Area.CAMP:
		return HEARTH_POS
	return hero_pos


func _active_light_radius() -> float:
	if area == Area.CAMP:
		return light_display_radius
	return 142.0


func _stash_camp_area() -> void:
	camp_resource_backup = resource_nodes.duplicate(true)
	camp_event_backup = events.duplicate(true)
	camp_decor_backup = decor_points.duplicate(true)


func _restore_camp_area() -> void:
	resource_nodes.clear()
	for item: Variant in camp_resource_backup:
		var restored_resource: Dictionary = item
		resource_nodes.append(restored_resource.duplicate(true))
	events.clear()
	for item: Variant in camp_event_backup:
		var restored_event: Dictionary = item
		events.append(restored_event.duplicate(true))
	decor_points.clear()
	for item: Variant in camp_decor_backup:
		var restored_decor: Dictionary = item
		decor_points.append(restored_decor.duplicate(true))
	enemies.clear()
	shots.clear()
	resource_pickups.clear()
	resource_flights.clear()
	area = Area.CAMP
	hero_pos = Vector2(240.0, 690.0)
	hero_target = hero_pos
	hero_hp = hero_max_hp
	route_grace_timer = 0.0
	_stop_joystick()


func _route_add_tree(pos: Vector2, variant: int) -> void:
	resource_nodes.append({
		"kind": "tree",
		"pos": pos,
		"hits": 3,
		"max_hits": 3,
		"alive": true,
		"fall_timer": 0.0,
		"drop_spawned": false,
		"variant": variant,
		"hit_flash": 0.0
	})


func _route_add_rock(pos: Vector2) -> void:
	resource_nodes.append({
		"kind": "rock",
		"pos": pos,
		"hits": 4,
		"max_hits": 4,
		"alive": true,
		"fall_timer": 0.0,
		"drop_spawned": false,
		"hit_flash": 0.0
	})


func _enter_day1_route(route_name: String) -> void:
	if area != Area.CAMP or stage != Stage.DAY1_RESCUE or day1_route != "":
		return
	_stash_camp_area()
	day1_route = route_name
	resource_nodes.clear()
	resource_pickups.clear()
	resource_flights.clear()
	events.clear()
	decor_points.clear()
	enemies.clear()
	shots.clear()
	hero_pos = Vector2(240.0, 690.0)
	hero_target = hero_pos
	hero_hp = hero_max_hp
	route_grace_timer = 3.0
	_stop_joystick()

	if route_name == "hunter":
		area = Area.HUNTER_TRAIL
		survivor_one_pos = Vector2(245.0, 205.0)
		for p: Vector2 in [Vector2(78, 185), Vector2(390, 205), Vector2(100, 360), Vector2(382, 390), Vector2(90, 585), Vector2(390, 600)]:
			_route_add_tree(p, rng.randi_range(0, 2))
		for p: Vector2 in [Vector2(150, 285), Vector2(335, 300), Vector2(300, 560)]:
			_route_add_rock(p)
		for i in range(44):
			decor_points.append({
				"pos": Vector2(rng.randf_range(30.0, 450.0), rng.randf_range(120.0, 755.0)),
				"kind": "grass" if i % 4 != 0 else "branch",
				"scale": rng.randf_range(0.75, 1.25)
			})
		_spawn_enemy_at("guard", Vector2(190, 285))
		_spawn_enemy_at("guard", Vector2(295, 300))
		_spawn_enemy_at("fast", Vector2(245, 340))
		_story("ТРОПА ОХОТНИКА
Крик оборвался. Между деревьями движутся тени.", 3.6)
	else:
		area = Area.SAWMILL
		for p: Vector2 in [Vector2(78, 185), Vector2(400, 190), Vector2(88, 385), Vector2(392, 400), Vector2(100, 610), Vector2(385, 620)]:
			_route_add_tree(p, rng.randi_range(0, 2))
		for p: Vector2 in [Vector2(135, 300), Vector2(350, 315), Vector2(330, 570)]:
			_route_add_rock(p)
		for i in range(38):
			decor_points.append({
				"pos": Vector2(rng.randf_range(30.0, 450.0), rng.randf_range(120.0, 755.0)),
				"kind": "branch" if i % 3 == 0 else "grass",
				"scale": rng.randf_range(0.75, 1.25)
			})
		_add_event("sawmill", Vector2(240.0, 220.0))
		_story("СТАРАЯ ЛЕСОПИЛКА
Здесь можно укрепить Очаг, но механизм заржавел.", 3.6)


func _return_from_day1_route() -> void:
	if area == Area.CAMP or not day1_route_complete:
		return
	_restore_camp_area()
	if day1_route == "hunter":
		_story("Охотник показывает путь назад. Солнце уже садится.", 2.8)
	else:
		_story("Ты возвращаешься с досками. Баррикады готовы встретить ночь.", 2.8)
	_start_night(1)


func _update_day1_route() -> void:
	if stage != Stage.DAY1_RESCUE:
		return

	if area == Area.HUNTER_TRAIL and not day1_route_complete:
		if enemies.is_empty() and hero_pos.distance_to(survivor_one_pos) < 48.0:
			survivor_one_found = true
			_add_survivor("hunter", survivor_one_pos)
			day1_route_complete = true
			run_embers += 1
			_story("ОХОТНИК СПАСЁН
«Ночью они идут на огонь. Я останусь у края света.»", 3.7)

	if area == Area.SAWMILL and sawmill_claimed and not day1_route_complete and enemies.is_empty():
		day1_route_complete = true
		carry_limit += 1
		hearth_max_hp += 38.0
		hearth_hp = hearth_max_hp
		run_embers += 1
		_story("ЛЕСОПИЛКА ОЧИЩЕНА
Доски укрепят Очаг. Перенос +1, прочность выше.", 3.6)


func _update_area_transitions() -> void:
	if stage == Stage.DAY1_RESCUE:
		if area == Area.CAMP and day1_route == "":
			if hero_pos.distance_to(ROUTE_HUNTER_GATE) < 46.0:
				_enter_day1_route("hunter")
			elif hero_pos.distance_to(ROUTE_SAWMILL_GATE) < 46.0:
				_enter_day1_route("sawmill")
		elif area != Area.CAMP and day1_route_complete and hero_pos.distance_to(ROUTE_RETURN_GATE) < 50.0:
			_return_from_day1_route()
		return

	if stage == Stage.DAY2_RESCUE:
		if area == Area.CAMP and not worker_route_complete and hero_pos.distance_to(ROUTE_WORKER_GATE) < 48.0:
			_enter_worker_ruins()
		elif area == Area.WORKER_RUINS and worker_route_complete and hero_pos.distance_to(ROUTE_RETURN_GATE) < 50.0:
			_return_from_worker_ruins()
		return

	if stage == Stage.DAY3_TOWER:
		if area == Area.CAMP and day3_route == "":
			if hero_pos.distance_to(ROUTE_WATCH_GATE) < 46.0:
				_enter_day3_route("watch")
			elif hero_pos.distance_to(ROUTE_ALTAR_GATE) < 46.0:
				_enter_day3_route("altar")
		elif area in [Area.WATCH_RIDGE, Area.ALTAR_GLADE] and day3_route_complete and hero_pos.distance_to(ROUTE_RETURN_GATE) < 50.0:
			_return_from_day3_route()




func _enter_worker_ruins() -> void:
	if area != Area.CAMP or stage != Stage.DAY2_RESCUE or worker_route_complete:
		return
	_stash_camp_area()
	area = Area.WORKER_RUINS
	resource_nodes.clear()
	resource_pickups.clear()
	resource_flights.clear()
	events.clear()
	decor_points.clear()
	enemies.clear()
	shots.clear()
	hero_pos = Vector2(240.0, 690.0)
	hero_target = hero_pos
	hero_hp = hero_max_hp
	route_grace_timer = 3.2
	worker_clear_announced = false
	survivor_two_pos = Vector2(250.0, 185.0)
	_stop_joystick()

	for p: Vector2 in [Vector2(72, 190), Vector2(410, 205), Vector2(90, 380), Vector2(390, 410), Vector2(86, 600), Vector2(398, 620)]:
		_route_add_tree(p, rng.randi_range(0, 2))
	for p: Vector2 in [Vector2(145, 270), Vector2(345, 275), Vector2(118, 520), Vector2(355, 545)]:
		_route_add_rock(p)
	for i in range(42):
		decor_points.append({
			"pos": Vector2(rng.randf_range(30.0, 450.0), rng.randf_range(120.0, 755.0)),
			"kind": "pebble" if i % 4 == 0 else ("branch" if i % 5 == 0 else "grass"),
			"scale": rng.randf_range(0.75, 1.25)
		})

	_spawn_enemy_at("guard", Vector2(182, 270))
	_spawn_enemy_at("guard", Vector2(315, 275))
	_spawn_enemy_at("fast", Vector2(215, 350))
	_spawn_enemy_at("fast", Vector2(292, 365))
	_story("РУИНЫ МАСТЕРСКОЙ\nЗа стеной кто-то стучит по металлу. Твари уже внутри.", 3.8)


func _update_worker_route() -> void:
	if stage != Stage.DAY2_RESCUE or area != Area.WORKER_RUINS or worker_route_complete:
		return
	if enemies.is_empty() and not worker_clear_announced:
		worker_clear_announced = true
		_banner("РУИНЫ ОЧИЩЕНЫ", 1.5)
		_story("Твари стихли. За завалом снова слышен стук — рабочий ещё жив.", 2.8)
		return
	if enemies.is_empty() and hero_pos.distance_to(survivor_two_pos) < 48.0:
		survivor_two_found = true
		_add_survivor("worker", survivor_two_pos)
		worker_route_complete = true
		run_embers += 1
		_story("РАБОЧИЙ СПАСЁН\n«Я починю мастерскую. Но эти твари знали, где мы прячемся.»", 3.8)


func _return_from_worker_ruins() -> void:
	if area != Area.WORKER_RUINS or not worker_route_complete:
		return
	_restore_camp_area()
	workshop_built = true
	light_radius = maxf(light_radius, 255.0)
	hearth_level = maxi(hearth_level, 3)
	stage = Stage.WORKSHOP_CHOICE
	left_choice_pos = Vector2(135.0, 285.0)
	right_choice_pos = Vector2(345.0, 285.0)
	camera_shake = 2.0
	flash_timer = 0.45
	_story("Рабочий вернул мастерскую к жизни. Теперь реши, чем станет это место.", 3.6)
	_banner("МАСТЕРСКАЯ ВОССТАНОВЛЕНА", 2.0)


func _enter_day3_route(route_name: String) -> void:
	if area != Area.CAMP or stage != Stage.DAY3_TOWER or day3_route != "":
		return
	_stash_camp_area()
	day3_route = route_name
	resource_nodes.clear()
	resource_pickups.clear()
	resource_flights.clear()
	events.clear()
	decor_points.clear()
	enemies.clear()
	shots.clear()
	hero_pos = Vector2(240.0, 690.0)
	hero_target = hero_pos
	hero_hp = hero_max_hp
	route_grace_timer = 2.4
	_stop_joystick()

	if route_name == "watch":
		area = Area.WATCH_RIDGE
		for p: Vector2 in [Vector2(75, 190), Vector2(405, 195), Vector2(92, 400), Vector2(388, 405), Vector2(105, 610), Vector2(382, 625)]:
			_route_add_tree(p, rng.randi_range(0, 2))
		for p: Vector2 in [Vector2(145, 285), Vector2(340, 305), Vector2(305, 565)]:
			_route_add_rock(p)
		for i in range(38):
			decor_points.append({
				"pos": Vector2(rng.randf_range(30.0, 450.0), rng.randf_range(120.0, 755.0)),
				"kind": "pebble" if i % 3 == 0 else "grass",
				"scale": rng.randf_range(0.75, 1.25)
			})
		_add_event("watch_repair", Vector2(240.0, 205.0))
		_story("СЛОМАННЫЙ ДОЗОР\nЕсли поднять башню, она прикроет Очаг в последнюю ночь.", 3.6)
	else:
		area = Area.ALTAR_GLADE
		for p: Vector2 in [Vector2(80, 190), Vector2(400, 190), Vector2(82, 410), Vector2(398, 415), Vector2(115, 625), Vector2(365, 625)]:
			_route_add_tree(p, rng.randi_range(0, 2))
		for p: Vector2 in [Vector2(135, 300), Vector2(345, 300), Vector2(240, 570)]:
			_route_add_rock(p)
		for i in range(40):
			decor_points.append({
				"pos": Vector2(rng.randf_range(30.0, 450.0), rng.randf_range(120.0, 755.0)),
				"kind": "ash" if i % 5 == 0 else "grass",
				"scale": rng.randf_range(0.72, 1.20)
			})
		_add_event("final_altar", Vector2(240.0, 210.0))
		_story("ДРЕВНИЙ АЛТАРЬ\nПламя здесь старше нашего Очагa. Оно может изменить оружие.", 3.6)


func _update_day3_route() -> void:
	if stage != Stage.DAY3_TOWER or day3_route_complete:
		return
	if day3_route == "watch" and watch_repair_started and enemies.is_empty():
		tower_built = true
		day3_route_complete = true
		run_embers += 1
		_story("ДОЗОР ПОДНЯТ\nБашня снова смотрит в темноту. Ночью она будет стрелять сама.", 3.5)
	elif day3_route == "altar" and final_altar_claimed and enemies.is_empty():
		expedition_choice = "damage"
		hero_damage *= 1.55
		day3_route_complete = true
		run_embers += 1
		_story("ОГОНЬ ПРИНЯТ\nСтрелы вспыхивают от прикосновения. Урон значительно выше.", 3.5)


func _return_from_day3_route() -> void:
	if area == Area.CAMP or not day3_route_complete:
		return
	_restore_camp_area()
	if day3_route == "watch":
		_story("Рабочий остаётся у механизма башни. Что-то огромное движется за деревьями.", 3.0)
	else:
		if day1_route == "hunter":
			_story("Охотник молча смотрит на горящие стрелы. Лес вокруг Очагa внезапно стих.", 3.0)
		else:
			_story("Рабочий отступает от горящих стрел. Лес вокруг Очагa внезапно стих.", 3.0)
	_start_night(3)


func _event_is_visible(pos: Vector2) -> bool:
	return pos.distance_to(_active_light_center()) <= _active_light_radius() - 6.0


func _update_world_events(delta: float) -> void:
	for i in range(events.size()):
		var event: Dictionary = events[i]
		if bool(event.get("triggered", false)):
			continue

		var kind := String(event.get("kind", ""))
		var pos: Vector2 = event["pos"]

		if kind == "black_tree":
			continue

		if kind == "whisper":
			if not (stage in [Stage.NIGHT1, Stage.NIGHT2, Stage.NIGHT3] and twilight_timer > 0.0):
				continue
		else:
			if stage in [Stage.NIGHT1, Stage.NIGHT2, Stage.NIGHT3, Stage.CORE_RETURN]:
				continue

		if not _event_is_visible(pos):
			continue

		var distance := hero_pos.distance_to(pos)
		var progress := float(event.get("progress", 0.0))
		var required := float(event.get("required", 1.25))

		if distance <= 44.0 and enemies.is_empty():
			progress += delta
		else:
			progress = maxf(0.0, progress - delta * 0.65)

		event["progress"] = progress
		events[i] = event

		if progress < required:
			continue

		event["triggered"] = true
		event["progress"] = required

		match kind:
			"wagon":
				if rng.randf() < 0.68:
					camp_wood += 2
					camp_stone += 1
					event["outcome"] = "loot"
					_story("БРОШЕННАЯ ТЕЛЕГА\nПод досками нашлись дерево и камень.", 3.0)
				else:
					event["outcome"] = "ambush"
					_spawn_enemy_at("guard", pos + Vector2(-34, 12))
					_spawn_enemy_at("guard", pos + Vector2(34, -10))
					_story("БРОШЕННАЯ ТЕЛЕГА\nСледы были слишком свежими. Засада.", 3.0)
			"wounded":
				run_embers += 1
				event["outcome"] = "helped"
				_story("РАНЕНЫЙ СТРАННИК\n«Они идут за светом... Береги огонь.»", 3.2)
			"altar":
				if rng.randf() < 0.5:
					hero_damage *= 1.12
					event["outcome"] = "damage"
					_story("СТАРЫЙ АЛТАРЬ\nПламя коснулось оружия. Урон выше.", 3.0)
				else:
					carry_limit += 1
					event["outcome"] = "carry"
					_story("СТАРЫЙ АЛТАРЬ\nНоша кажется легче. Перенос +1.", 3.0)
			"dead_camp":
				run_embers += 1
				event["outcome"] = "memory"
				_story("ПОТУХШИЙ КОСТЁР\nНа камне вырезан знак нашего Очагa.", 3.2)
			"tracks":
				event["outcome"] = "trail"
				_story("СЛЕДЫ В ГРЯЗИ\nОни ведут глубже в лес — и не похожи на человеческие.", 3.1)
			"broken_watch":
				hero_damage *= 1.08
				event["outcome"] = "arrows"
				_story("СЛОМАННЫЙ ДОЗОР\nВ ящике сохранилась связка хороших стрел.", 3.0)
			"whisper":
				_add_survivor("guard", pos)
				event["outcome"] = "rescued"
				_story("ШЁПОТ ИЗ ТЬМЫ\nЕщё один человек успел добежать до света.", 3.0)
			"sawmill":
				sawmill_claimed = true
				event["outcome"] = "started"
				_spawn_enemy_at("guard", pos + Vector2(-68, 55))
				_spawn_enemy_at("guard", pos + Vector2(66, 48))
				_spawn_enemy_at("fast", pos + Vector2(0, 82))
				route_grace_timer = 0.9
				camera_shake = 2.2
				_story("МЕХАНИЗМ ЗАРАБОТАЛ\nСкрип пилы разбудил тех, кто прятался рядом.", 3.2)
			"watch_repair":
				watch_repair_started = true
				event["outcome"] = "repairing"
				_spawn_enemy_at("elite", pos + Vector2(0, 92))
				_spawn_enemy_at("guard", pos + Vector2(-72, 64))
				_spawn_enemy_at("guard", pos + Vector2(72, 64))
				route_grace_timer = 1.0
				camera_shake = 2.6
				_story("ДОЗОР ЗАСКРИПЕЛ\nШум поднял старую тварь из оврага. Сначала переживи нападение.", 3.3)
			"final_altar":
				final_altar_claimed = true
				event["outcome"] = "fire"
				_spawn_enemy_at("fast", pos + Vector2(-62, 70))
				_spawn_enemy_at("fast", pos + Vector2(62, 70))
				_spawn_enemy_at("elite", pos + Vector2(0, 96))
				route_grace_timer = 1.0
				camera_shake = 2.8
				_story("АЛТАРЬ ВСПЫХНУЛ\nОгонь ответил — и вместе с ним проснулось то, что лежало под камнями.", 3.3)

		events[i] = event
		_check_day_progress()
		break


func _complete_black_tree_event(index: int) -> void:
	if index < 0 or index >= events.size():
		return
	var event: Dictionary = events[index]
	if bool(event.get("triggered", false)):
		return
	var pos: Vector2 = event["pos"]
	event["triggered"] = true
	event["outcome"] = "opened"
	event["progress"] = 1.0
	events[index] = event

	for j in range(5):
		var angle := TAU * float(j) / 5.0
		resource_pickups.append({
			"kind": "wood",
			"pos": pos + Vector2(cos(angle), sin(angle)) * 28.0,
			"spin": rng.randf_range(-0.2, 0.2)
		})
	_spawn_enemy_at("fast", pos + Vector2(-38, 16))
	_spawn_enemy_at("fast", pos + Vector2(38, -14))
	route_grace_timer = 0.8
	camera_shake = 3.2
	_story("ЧЁРНОЕ ДЕРЕВО\nСтвол раскололся. Шум разбудил тварей.", 3.0)


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
	if region_map_open:
		return

	var near_map := hero_pos.distance_to(HUB_MAP_POS) < 54.0
	var near_carry := hero_pos.distance_to(HUB_CARRY_POS) < 48.0
	var near_damage := hero_pos.distance_to(HUB_DAMAGE_POS) < 48.0
	var near_hearth := hero_pos.distance_to(HUB_HEARTH_UPGRADE_POS) < 46.0

	if not near_map and not near_carry and not near_damage and not near_hearth:
		hub_zone_lock = ""

	if near_map and hub_zone_lock != "map":
		hub_zone_lock = "map"
		if bool(meta.get("forest_cleared", false)):
			region_map_open = true
			_stop_joystick()
		else:
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
			_hub_feedback("ПЕРЕНОС +1", HUB_CARRY_POS, 2.0)
		else:
			_hub_feedback("НУЖНО %d УГЛЕЙ" % cost, HUB_CARRY_POS, 1.8)

	if near_damage and hub_zone_lock != "damage":
		hub_zone_lock = "damage"
		var level := int(meta.get("damage_level", 0))
		var cost := 4 + level * 3
		if int(meta.get("embers", 0)) >= cost:
			meta["embers"] = int(meta.get("embers", 0)) - cost
			meta["damage_level"] = level + 1
			_save_meta()
			_hub_feedback("УРОН +10%", HUB_DAMAGE_POS, 2.0)
		else:
			_hub_feedback("НУЖНО %d УГЛЕЙ" % cost, HUB_DAMAGE_POS, 1.8)

	if near_hearth and hub_zone_lock != "hearth":
		hub_zone_lock = "hearth"
		var level := int(meta.get("hearth_bonus", 0))
		var cost := 5 + level * 4
		if level >= 3:
			_hub_feedback("ПРЕДЕЛ ЭТОЙ ГЛАВЫ", HUB_HEARTH_UPGRADE_POS, 1.9)
		elif int(meta.get("embers", 0)) >= cost:
			meta["embers"] = int(meta.get("embers", 0)) - cost
			meta["hearth_bonus"] = level + 1
			_save_meta()
			hearth_pulse = 1.0
			camera_shake = 2.0
			_hub_feedback("СВЕТ И ПРОЧНОСТЬ +", HUB_HEARTH_UPGRADE_POS, 2.2)
		else:
			_hub_feedback("НУЖНО %d УГЛЕЙ" % cost, HUB_HEARTH_UPGRADE_POS, 1.8)


func _update_expedition(delta: float) -> void:
	_deposit_resources_if_close(delta)
	_update_resource_gathering()
	_update_resource_pickups(delta)
	_update_world_events(delta)
	_update_survivor_agents(delta)
	_update_day1_route()
	_update_worker_route()
	_update_day3_route()
	_update_area_transitions()
	if area == Area.CAMP:
		_keep_hero_out_of_hearth()

	if enemies.size() > 0:
		_update_combat()
		_update_shots(delta)
		_update_enemies(delta)
		if mode != Mode.EXPEDITION:
			return
		if tower_built:
			_update_tower()

	match stage:
		Stage.DAY1_RESCUE:
			pass
		Stage.WORKSHOP_CHOICE:
			_update_workshop_choice()
		Stage.DAY2_RESCUE:
			pass
		Stage.EXPEDITION_CHOICE:
			_update_expedition_choice()
		Stage.NIGHT1, Stage.NIGHT2, Stage.NIGHT3:
			_update_night_spawner(delta)
		Stage.CORE_RETURN:
			_update_core_return()

	if hearth_hp <= 0.0:
		_finish_run(false)


func _gathering_enabled() -> bool:
	# v0.9 deliberately removes the old Day 3 resource grind.
	return stage in [Stage.DAY1_GATHER, Stage.DAY2_BUILD]


func _resource_kind_needed(kind: String) -> bool:
	if stage == Stage.DAY1_GATHER:
		return kind == "tree" and camp_wood + carried_wood < 5
	if stage == Stage.DAY2_BUILD:
		if kind == "tree":
			return camp_wood + carried_wood < current_stage_wood_start + 8
		return camp_stone + carried_stone < current_stage_stone_start + 5
	if stage == Stage.DAY3_TOWER:
		if kind == "tree":
			return camp_wood + carried_wood < current_stage_wood_start + 6
		return camp_stone + carried_stone < current_stage_stone_start + 6
	return false


func _update_resource_gathering() -> void:
	for i in range(resource_nodes.size()):
		var feedback_node: Dictionary = resource_nodes[i]
		var hit_flash := maxf(0.0, float(feedback_node.get("hit_flash", 0.0)) - get_process_delta_time() * 5.5)
		feedback_node["hit_flash"] = hit_flash
		resource_nodes[i] = feedback_node

	if not _gathering_enabled():
		return
	if gather_cd > 0.0:
		return

	# Black Tree is an actual chopping interaction, not a touch-trigger.
	for e in range(events.size()):
		var event: Dictionary = events[e]
		if String(event.get("kind", "")) != "black_tree" or bool(event.get("triggered", false)):
			continue
		var event_pos: Vector2 = event["pos"]
		if event_pos.distance_to(HEARTH_POS) > light_radius - 8.0:
			continue
		if hero_pos.distance_to(event_pos) > HERO_INTERACT_RADIUS:
			continue
		var hits_left := int(event.get("hits", 5)) - 1
		event["hits"] = hits_left
		event["progress"] = 1.0 - float(maxi(0, hits_left)) / 5.0
		events[e] = event
		gather_cd = gather_interval * 1.12
		_burst(event_pos, 5)
		camera_shake = maxf(camera_shake, 0.8)
		if hits_left <= 0:
			_complete_black_tree_event(e)
		return

	for i in range(resource_nodes.size()):
		var node: Dictionary = resource_nodes[i]
		if not bool(node.get("alive", false)):
			continue
		var node_pos: Vector2 = node["pos"]
		if hero_pos.distance_to(node_pos) > HERO_INTERACT_RADIUS:
			continue

		var kind := String(node.get("kind", "tree"))
		if not _resource_kind_needed(kind):
			continue

		var hits := int(node.get("hits", 1)) - 1
		node["hits"] = hits
		node["hit_flash"] = 1.0
		gather_cd = gather_interval
		_burst_typed(node_pos, 6, "wood" if kind == "tree" else "stone")

		if hits > 0:
			camera_shake = maxf(camera_shake, 0.7)
		else:
			node["alive"] = false
			node["fall_timer"] = 0.34 if kind == "tree" else 0.16
			node["drop_spawned"] = false
			_burst_typed(node_pos, 16 if kind == "tree" else 10, "wood" if kind == "tree" else "stone")
			camera_shake = maxf(camera_shake, 3.2 if kind == "tree" else 1.8)

		resource_nodes[i] = node
		break


func _pickup_kind_allowed(kind: String) -> bool:
	if not _gathering_enabled():
		# Already-felled resources may be collected, but only if they are useful to the current active stage.
		return false
	if kind == "wood":
		return _resource_kind_needed("tree")
	return _resource_kind_needed("rock")


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
		var kind := String(pickup.get("kind", "wood"))
		if not _pickup_kind_allowed(kind):
			continue
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
	if area != Area.CAMP:
		unload_active = false
		return
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
	if stage_transition_lock:
		return

	if stage == Stage.DAY1_GATHER and camp_wood >= 5:
		stage_transition_lock = true
		camp_wood -= 5
		hearth_level = 2
		hearth_max_hp = 170.0
		hearth_hp = hearth_max_hp
		light_radius = 225.0
		stage = Stage.DAY1_RESCUE
		current_stage_wood_start = camp_wood
		current_stage_stone_start = camp_stone
		flash_timer = 0.75
		hearth_pulse = 1.0
		upgrade_wave = 1.0
		camera_shake = 4.8
		_burst_typed(HEARTH_POS, 24, "ember")
		_banner("ОЧАГ II | свет открыл две тропы", 2.4)
		_story("До темноты хватит времени только на один путь: слева слышен крик, справа тянется дым.", 4.2)
		stage_transition_lock = false

	elif stage == Stage.DAY2_BUILD and camp_wood >= current_stage_wood_start + 8 and camp_stone >= current_stage_stone_start + 5:
		stage_transition_lock = true
		camp_wood -= 8
		camp_stone -= 5
		workshop_built = true
		stage = Stage.WORKSHOP_CHOICE
		current_stage_wood_start = camp_wood
		current_stage_stone_start = camp_stone
		light_radius = 255.0
		flash_timer = 0.55
		camera_shake = 2.0
		_banner("Мастерская восстановлена | выбери специализацию", 2.2)
		stage_transition_lock = false

	elif stage == Stage.DAY3_TOWER and day3_route == "legacy_build" and camp_wood >= current_stage_wood_start + 6 and camp_stone >= current_stage_stone_start + 6:
		stage_transition_lock = true
		camp_wood -= 6
		camp_stone -= 6
		tower_built = true
		stage = Stage.EXPEDITION_CHOICE
		current_stage_wood_start = camp_wood
		current_stage_stone_start = camp_stone
		light_radius = 300.0
		flash_timer = 0.65
		camera_shake = 2.8
		_banner("Дозорная башня готова | выбери силу перед ночью", 2.4)
		stage_transition_lock = false


func _update_workshop_choice() -> void:
	if hero_pos.distance_to(left_choice_pos) < 48.0:
		workshop_choice = "armory"
		hero_damage *= 1.28
		_banner("ОРУЖЕЙНАЯ | урон +28%", 2.0)
		_story("Рабочий укрепил оружие. Ночью можно встретить врага дальше от огня.", 2.8)
		_start_night(2)
	elif hero_pos.distance_to(right_choice_pos) < 48.0:
		workshop_choice = "lumber"
		carry_limit += 2
		gather_interval = 0.30
		hearth_max_hp += 22.0
		hearth_hp = hearth_max_hp
		_banner("ЛЕСОПИЛКА | перенос +2", 2.0)
		_story("Рабочий усилил лагерь досками. Очаг выдержит больше ударов.", 2.8)
		_start_night(2)


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
		_banner("Огненная метка | урон +60%", 2.0)
		_start_night(3)


func _start_night(number: int) -> void:
	current_night = number
	night_queue.clear()
	night_spawn_cd = 0.65
	twilight_timer = TWILIGHT_DURATION + 0.8
	dawn_timer = 0.0
	dawn_pending = 0
	boss_delay_timer = 0.0
	boss_announced = false
	active_night_sides.clear()
	hearth_hp = hearth_max_hp

	if number == 1:
		stage = Stage.NIGHT1
		if day1_route == "hunter":
			active_night_sides = [2]
			for i in range(8):
				night_queue.append("fast" if i == 6 else "basic")
			_story("Охотник: «Они придут с юга. Я прикрою край света.»", 2.9)
		else:
			active_night_sides = [2, 3]
			for i in range(10):
				night_queue.append("fast" if i in [6, 9] else "basic")
			_story("Баррикады крепки, но без охотника придётся держать две стороны.", 2.9)
		_banner("СУМЕРКИ", 1.8)
	elif number == 2:
		stage = Stage.NIGHT2
		active_night_sides = [0, 1]
		for i in range(12):
			night_queue.append("fast" if i % 3 == 2 else "basic")
		night_queue.append("elite")
		_banner("СУМЕРКИ", 1.8)
		_story("Две стороны леса ожили одновременно.", 2.7)
	else:
		stage = Stage.NIGHT3
		active_night_sides = [0, 1, 3]
		for i in range(14):
			if i % 4 == 2:
				night_queue.append("fast")
			else:
				night_queue.append("basic")
		night_queue.append("boss")
		_banner("СУМЕРКИ", 1.8)
		_story("Охотник: «Слышишь?.. Лес затих. Он идёт за огнём.»", 3.2)


func _update_night_spawner(delta: float) -> void:
	if twilight_timer > 0.0:
		twilight_timer = maxf(0.0, twilight_timer - delta)
		if twilight_timer <= 0.0:
			_banner("НОЧЬ %d" % current_night, 1.6)
			camera_shake = 1.4
		return

	if dawn_pending > 0:
		dawn_timer = maxf(0.0, dawn_timer - delta)
		if dawn_timer <= 0.0:
			var finished := dawn_pending
			dawn_pending = 0
			if finished == 1:
				_complete_night_one()
			elif finished == 2:
				_complete_night_two()
		return

	if boss_delay_timer > 0.0:
		boss_delay_timer = maxf(0.0, boss_delay_timer - delta)
		return

	night_spawn_cd -= delta
	if night_queue.size() > 0 and night_spawn_cd <= 0.0:
		var next_kind := String(night_queue[0])
		if next_kind == "boss" and not boss_announced:
			boss_announced = true
			boss_delay_timer = 2.6
			_story("Тишина. Даже твари отступили от края света.", 2.5)
			return

		var kind: String = night_queue.pop_front()
		_spawn_enemy(kind)
		if kind == "boss":
			night_spawn_cd = 2.2
			_banner("ХРАНИТЕЛЬ ЛЕСА", 2.2)
			camera_shake = 3.0
		else:
			night_spawn_cd = 0.92 if current_night >= 2 else 1.12

	if night_queue.is_empty() and enemies.is_empty() and current_night < 3 and dawn_pending == 0:
		dawn_pending = current_night
		dawn_timer = 1.8
		_banner("РАССВЕТ", 1.7)


func _complete_night_one() -> void:
	run_embers += 1
	hearth_level = 3
	var route_bonus := 38.0 if day1_route == "sawmill" else 0.0
	hearth_max_hp = 185.0 + route_bonus
	hearth_hp = hearth_max_hp
	light_radius = 250.0
	stage = Stage.DAY2_RESCUE
	current_stage_wood_start = camp_wood
	current_stage_stone_start = camp_stone
	flash_timer = 0.45
	if day1_route == "hunter":
		_story("РАССВЕТ\nОхотник нашёл свежие следы. Они ведут к руинам старой мастерской.", 3.7)
	else:
		_story("РАССВЕТ\nНа досках лесопилки есть тот же знак. След ведёт к старой мастерской.", 3.7)




func _complete_night_two() -> void:
	run_embers += 2
	hearth_level = 4
	hearth_max_hp = maxf(215.0, hearth_max_hp + 12.0)
	hearth_hp = hearth_max_hp
	light_radius = 285.0
	stage = Stage.DAY3_TOWER
	day3_route = ""
	day3_route_complete = false
	flash_timer = 0.45
	_story("РАССВЕТ\nПоследняя ночь близко. Можно успеть только к дозору или к древнему алтарю.", 4.0)


func _spawn_enemy(kind: String) -> void:
	var side := 0
	if kind == "boss":
		side = 0
	elif active_night_sides.size() > 0:
		side = active_night_sides[rng.randi_range(0, active_night_sides.size() - 1)]
	else:
		side = rng.randi_range(0, 3)

	var pos := Vector2.ZERO
	if side == 0:
		pos = Vector2(rng.randf_range(90.0, 390.0), 104.0)
	elif side == 1:
		pos = Vector2(466.0, rng.randf_range(205.0, 700.0))
	elif side == 2:
		pos = Vector2(rng.randf_range(75.0, 405.0), 756.0)
	else:
		pos = Vector2(14.0, rng.randf_range(205.0, 700.0))
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
		"hit_flash": 0.0,
		"move_phase": rng.randf_range(0.0, TAU)
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


func _workshop_pos() -> Vector2:
	return HEARTH_POS + Vector2(-148.0, -62.0)


func _tower_pos() -> Vector2:
	return HEARTH_POS + Vector2(148.0, -55.0)


func _survivor_day_target(index: int, role: String) -> Vector2:
	if area != Area.CAMP:
		var travel_slots: Array[Vector2] = [
			Vector2(-34, 24), Vector2(34, 26), Vector2(-46, 54),
			Vector2(46, 56), Vector2(0, 68)
		]
		return hero_pos + travel_slots[index % travel_slots.size()]
	var camp_scale := 1.0 + float(maxi(0, hearth_level - 2)) * 0.08
	var time := float(Time.get_ticks_msec()) * 0.001
	if role == "hunter":
		var patrol := Vector2(sin(time * 0.55 + float(index)) * 18.0, cos(time * 0.42 + float(index)) * 10.0)
		return HEARTH_POS + Vector2(-118.0, 58.0) * camp_scale + patrol
	if role == "worker":
		var work_shift := Vector2(sin(time * 0.8 + float(index)) * 8.0, cos(time * 0.6) * 5.0)
		return (_workshop_pos() + Vector2(18, 20) + work_shift) if workshop_built else HEARTH_POS + Vector2(112.0, 72.0) * camp_scale

	var guard_slots: Array[Vector2] = [
		Vector2(122, -78), Vector2(142, 30), Vector2(88, 118),
		Vector2(-88, 118), Vector2(-142, 26), Vector2(-122, -78)
	]
	return HEARTH_POS + guard_slots[index % guard_slots.size()] * camp_scale


func _survivor_defense_target(index: int) -> Vector2:
	var count := maxi(1, survivor_agents.size())
	var angle := -PI * 0.78 + TAU * float(index) / float(count)
	var radius := 104.0 + float(maxi(0, hearth_level - 2)) * 7.0
	return HEARTH_POS + Vector2(cos(angle), sin(angle)) * radius


func _separate_survivor_position(pos: Vector2, index: int) -> Vector2:
	var result := pos
	var from_hearth := result - HEARTH_POS
	var minimum := 74.0
	if from_hearth.length() < minimum:
		if from_hearth.length() < 0.01:
			from_hearth = Vector2(1, 0)
		result = HEARTH_POS + from_hearth.normalized() * minimum

	for j in range(survivor_agents.size()):
		if j == index:
			continue
		var other: Vector2 = survivor_agents[j]["pos"]
		var diff := result - other
		if diff.length() < 25.0 and diff.length() > 0.01:
			result += diff.normalized() * (25.0 - diff.length()) * 0.45
	return result


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
		pos = _separate_survivor_position(pos, i)
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


func _keep_hero_out_of_hearth() -> void:
	var diff := hero_pos - HEARTH_POS
	var min_radius := 58.0 + float(maxi(0, hearth_level - 2)) * 3.0
	if diff.length() < min_radius:
		if diff.length() < 0.01:
			diff = Vector2(0, 1)
		hero_pos = HEARTH_POS + diff.normalized() * min_radius
		hero_target = hero_pos


func _update_combat() -> void:
	if hero_shot_cd <= 0.0:
		var combat_range := 185.0 if area != Area.CAMP else 285.0
		var targets: Array[int] = _nearest_enemy_indices(hero_pos, combat_range, 1)
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
	var tower_pos := _tower_pos()
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
		var route_combat := area != Area.CAMP
		var target_pos := hero_pos if route_combat else HEARTH_POS
		var to_target := target_pos - pos
		var distance := to_target.length()
		var radius := float(enemy.get("radius", 14.0))
		var speed := float(enemy.get("speed", 35.0))
		var hit_cd := maxf(0.0, float(enemy.get("hit_cd", 0.0)) - delta)
		var hit_flash := maxf(0.0, float(enemy.get("hit_flash", 0.0)) - delta)

		var move_phase := float(enemy.get("move_phase", 0.0)) + delta * (8.5 if String(enemy.get("kind", "basic")) == "fast" else 3.5)
		var speed_scale := 1.0
		var enemy_kind := String(enemy.get("kind", "basic"))
		if enemy_kind == "fast":
			speed_scale = 0.78 + maxf(0.0, sin(move_phase)) * 0.52
		elif enemy_kind == "boss":
			speed_scale = 0.80 + maxf(0.0, sin(move_phase)) * 0.28

		if route_combat and route_grace_timer > 0.0:
			enemy["hit_cd"] = hit_cd
			enemy["hit_flash"] = hit_flash
			enemy["move_phase"] = move_phase
			enemies[i] = enemy
			continue

		if distance > 39.0 + radius * 0.35:
			pos += to_target.normalized() * speed * speed_scale * delta
		elif hit_cd <= 0.0:
			var damage := float(enemy.get("damage", 7.0))
			hit_cd = 0.88
			flash_timer = 0.08
			camera_shake = maxf(camera_shake, 2.2)
			if route_combat:
				hero_hp -= damage
				_float_text(hero_pos + Vector2(0, -48), "-%d" % int(damage), Color(1.0, 0.48, 0.38))
				var knock := hero_pos - pos
				if knock.length() > 0.001:
					hero_pos += knock.normalized() * 18.0
					hero_pos.x = clampf(hero_pos.x, 22.0, VIEW_SIZE.x - 22.0)
					hero_pos.y = clampf(hero_pos.y, 118.0, VIEW_SIZE.y - 24.0)
			else:
				hearth_hp -= damage
				hearth_pulse = maxf(hearth_pulse, 0.35)
				_float_text(HEARTH_POS + Vector2(0, -72), "-%d ОЧАГ" % int(damage), Color(1.0, 0.48, 0.38))

		enemy["pos"] = pos
		enemy["hit_cd"] = hit_cd
		enemy["hit_flash"] = hit_flash
		enemy["move_phase"] = move_phase
		enemies[i] = enemy

		if route_combat and hero_hp <= 0.0 and mode == Mode.EXPEDITION:
			_finish_run(false, "hero")
			return

func _on_enemy_killed(enemy: Dictionary) -> void:
	var pos: Vector2 = enemy["pos"]
	var kind := String(enemy.get("kind", "basic"))
	enemy_deaths.append({
		"pos": pos,
		"kind": kind,
		"radius": float(enemy.get("radius", 14.0)),
		"life": 0.34,
		"max_life": 0.34
	})
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
		_banner("Хранитель пал | забери его ядро", 2.6)


func _update_core_return() -> void:
	if core_active and not core_carried and hero_pos.distance_to(core_pos) < 38.0:
		core_carried = true
		core_active = false
		_banner("Ядро у тебя | неси к очагу", 1.8)

	if core_carried and hero_pos.distance_to(HEARTH_POS) < 68.0:
		core_carried = false
		hearth_level = 5
		light_radius = 380.0
		flash_timer = 1.25
		hearth_pulse = 1.0
		camera_shake = 6.0
		_finish_run(true)


func _finish_run(win: bool, reason: String = "") -> void:
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
		if reason == "hero":
			result_title = "ВЫЛАЗКА ОБОРВАЛАСЬ"
			result_subtitle = "Ты не вернулся к свету. Угли и постоянные улучшения остались."
		else:
			result_title = "ОЧАГ ПОГАС"
			result_subtitle = "Временные усиления потеряны. Угли и постоянные улучшения остались."

	_save_meta()
	_stop_joystick()


func _update_enemy_deaths(delta: float) -> void:
	for i in range(enemy_deaths.size() - 1, -1, -1):
		var death: Dictionary = enemy_deaths[i]
		var life := float(death.get("life", 0.0)) - delta
		death["life"] = life
		enemy_deaths[i] = death
		if life <= 0.0:
			enemy_deaths.remove_at(i)


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
	_burst_typed(pos, count, "ember")


func _burst_typed(pos: Vector2, count: int, kind: String) -> void:
	for i in range(count):
		var angle := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(34.0, 118.0)
		var life := rng.randf_range(0.30, 0.72)
		if kind == "wood":
			angle = rng.randf_range(-2.85, -0.30)
			speed = rng.randf_range(45.0, 125.0)
			life = rng.randf_range(0.25, 0.55)
		elif kind == "stone":
			speed = rng.randf_range(25.0, 72.0)
			life = rng.randf_range(0.22, 0.46)
		elif kind == "ember":
			angle = rng.randf_range(-2.75, -0.40)
			speed = rng.randf_range(28.0, 78.0)
			life = rng.randf_range(0.38, 0.85)
		particles.append({
			"pos": pos,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": life,
			"max_life": life,
			"kind": kind,
			"size": rng.randf_range(1.8, 3.7)
		})


func _story(text: String, duration: float = 3.0) -> void:
	story_hint = text
	story_hint_timer = duration


func _hub_feedback(text: String, pos: Vector2, duration: float = 1.8) -> void:
	hub_feedback_text = text
	hub_feedback_pos = pos
	hub_feedback_timer = duration


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

	if mode == Mode.HUB and region_map_open:
		if event is InputEventScreenTouch and event.pressed:
			_handle_region_map_press(event.position)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_region_map_press(event.position)
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


func _handle_region_map_press(pos: Vector2) -> void:
	var forest_rect := Rect2(Vector2(50, 292), Vector2(172, 150))
	var dead_rect := Rect2(Vector2(258, 292), Vector2(172, 150))
	if forest_rect.has_point(pos):
		region_map_open = false
		_start_expedition()
	elif dead_rect.has_point(pos):
		_hub_feedback("МЁРТВЫЕ ПОЛЯ | СЛЕДУЮЩАЯ ГЛАВА", HUB_MAP_POS + Vector2(0, 120), 2.4)
	elif pos.y < 180.0 or pos.y > 560.0:
		region_map_open = false


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

	_draw_enemy_deaths()
	_draw_particles()
	_draw_floaters()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_draw_hud()
	_draw_banner()
	_draw_story_card()
	_draw_hub_feedback()
	_draw_joystick()
	_draw_flash()

	if mode == Mode.HUB and region_map_open:
		_draw_region_map_overlay()
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
	var resident_positions: Array[Vector2] = [Vector2(145, 332), Vector2(338, 336), Vector2(240, 690)]
	var resident_count := 3 if bool(meta.get("forest_cleared", false)) else 2
	for i in range(resident_count):
		var p: Vector2 = resident_positions[i]
		_draw_humanoid(p, Color("#7f886a") if i == 0 else Color("#9b7856"), float(i), resident_roles[i], 1.0)

	_draw_hero(hero_pos)

	draw_string(font, Vector2(18, 116), "ПОСЛЕДНИЙ ОЧАГ", HORIZONTAL_ALIGNMENT_LEFT, 300, 22, Color("#f4ead4"))
	var subtitle := "Мёртвые поля открыты | вдалеке снова виден огонь" if bool(meta.get("forest_cleared", false)) else "Соберись у карты и отправляйся в лес"
	draw_string(font, Vector2(18, 139), subtitle, HORIZONTAL_ALIGNMENT_LEFT, 440, 12, Color("#9eafa2"))

	var carry_level := int(meta.get("carry_level", 0))
	var damage_level := int(meta.get("damage_level", 0))
	var hearth_bonus := int(meta.get("hearth_bonus", 0))
	var carry_cost := 3 + carry_level * 2
	var damage_cost := 4 + damage_level * 3
	var hearth_cost := 5 + hearth_bonus * 4

	draw_string(font, HUB_CARRY_POS + Vector2(-63, 70), "ур.%d | %d углей" % [carry_level, carry_cost], HORIZONTAL_ALIGNMENT_CENTER, 126, 10, Color("#d7c7a8"))
	draw_string(font, HUB_DAMAGE_POS + Vector2(-63, 70), "ур.%d | %d углей" % [damage_level, damage_cost], HORIZONTAL_ALIGNMENT_CENTER, 126, 10, Color("#d7c7a8"))
	var hearth_label := "максимум" if hearth_bonus >= 3 else "ур.%d | %d углей" % [hearth_bonus, hearth_cost]
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
	if area == Area.CAMP:
		_draw_map_variant_decor()
	else:
		_draw_route_area_decor()
	_draw_environment_decor()
	_draw_light_field(_active_light_center(), _active_light_radius())
	_draw_world_events()

	for node: Dictionary in resource_nodes:
		_draw_resource(node)
	for pickup: Dictionary in resource_pickups:
		_draw_resource_pickup(pickup)
	_draw_resource_flights()

	if area == Area.CAMP:
		_draw_revealed_landmarks()

	if stage == Stage.DAY1_RESCUE and area == Area.HUNTER_TRAIL and not survivor_one_found:
		var survivor_visibility := _light_visibility(survivor_one_pos)
		if survivor_visibility > 0.72:
			_draw_survivor(survivor_one_pos, "?")
		elif survivor_visibility > 0.18:
			_draw_survivor_silhouette(survivor_one_pos, survivor_visibility)
	if stage == Stage.DAY2_RESCUE and area == Area.WORKER_RUINS and not survivor_two_found and _light_visibility(survivor_two_pos) > 0.72:
		_draw_survivor(survivor_two_pos, "!")
	if stage == Stage.WORKSHOP_CHOICE:
		_draw_choice_shrine(left_choice_pos, "ОРУЖЕЙНАЯ | +28% УРОН", Color("#a85949"))
		_draw_choice_shrine(right_choice_pos, "ЛЕСОПИЛКА | +2 ГРУЗ", Color("#567e58"))
	if stage == Stage.EXPEDITION_CHOICE:
		_draw_choice_shrine(left_choice_pos, "ДВА БОЙЦА", Color("#6688a0"))
		_draw_choice_shrine(right_choice_pos, "ОГНЕННЫЕ СТРЕЛЫ", Color("#b75e45"))

	if area == Area.CAMP and workshop_built:
		_draw_workshop()
	if area == Area.CAMP and tower_built:
		_draw_tower()
	if stage in [Stage.DAY1_RESCUE, Stage.DAY2_RESCUE, Stage.DAY3_TOWER]:
		_draw_day1_route_navigation()

	for enemy: Dictionary in enemies:
		_draw_enemy(enemy)
	for shot: Dictionary in shots:
		_draw_shot(shot)

	if core_active:
		_draw_core(core_pos)
	if core_carried:
		_draw_core(hero_pos + Vector2(0, -46))

	if area == Area.CAMP:
		_draw_hearth(HEARTH_POS, hearth_level)
		_draw_stockpile()
		_draw_world_progress()
	else:
		_draw_explorer_lantern()
	_draw_companions()
	_draw_hero(hero_pos)
	_draw_guidance_marker()

	if night_mix > 0.0:
		draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.015, 0.03, 0.035, 0.10 * night_mix))
		_draw_night_edge_eyes(night_mix)
	_draw_world_vignette(night_mix)


func _draw_day1_route_navigation() -> void:
	if stage == Stage.DAY1_RESCUE:
		if area == Area.CAMP and day1_route == "":
			_draw_route_gate(ROUTE_HUNTER_GATE, "КРИК О ПОМОЩИ", Color("#d8b06b"), true)
			_draw_route_gate(ROUTE_SAWMILL_GATE, "ДЫМ ЛЕСОПИЛКИ", Color("#91a977"), false)
		elif area != Area.CAMP and day1_route_complete:
			_draw_route_gate(ROUTE_RETURN_GATE, "ВЕРНУТЬСЯ К ОЧАГУ", Color("#e0bc73"), false)
	elif stage == Stage.DAY2_RESCUE:
		if area == Area.CAMP and not worker_route_complete:
			_draw_route_gate(ROUTE_WORKER_GATE, "СЛЕД К РУИНАМ", Color("#b3a177"), false)
		elif area == Area.WORKER_RUINS and worker_route_complete:
			_draw_route_gate(ROUTE_RETURN_GATE, "ВЕРНУТЬСЯ С РАБОЧИМ", Color("#e0bc73"), false)
	elif stage == Stage.DAY3_TOWER:
		if area == Area.CAMP and day3_route == "":
			_draw_route_gate(ROUTE_WATCH_GATE, "СЛОМАННЫЙ ДОЗОР", Color("#7f98a0"), true)
			_draw_route_gate(ROUTE_ALTAR_GATE, "ДРЕВНИЙ АЛТАРЬ", Color("#c07a52"), false)
		elif area in [Area.WATCH_RIDGE, Area.ALTAR_GLADE] and day3_route_complete:
			_draw_route_gate(ROUTE_RETURN_GATE, "ПОСЛЕДНЯЯ НОЧЬ ЖДЁТ", Color("#e0bc73"), false)


func _draw_route_gate(pos: Vector2, label: String, color: Color, points_left: bool) -> void:
	var pulse := 0.82 + sin(Time.get_ticks_msec() * 0.006) * 0.12
	draw_circle(pos, 28.0, Color(color.r, color.g, color.b, 0.055 * pulse))
	var dir := Vector2(-1, 0) if points_left else Vector2(1, 0)
	if pos == ROUTE_RETURN_GATE:
		dir = Vector2(0, 1)
	var tip := pos + dir * 18.0
	var side := Vector2(-dir.y, dir.x) * 7.0
	draw_colored_polygon(PackedVector2Array([tip + dir * 7.0, tip - dir * 5.0 + side, tip - dir * 5.0 - side]), color)
	var text_x := clampf(pos.x - 88.0, 8.0, VIEW_SIZE.x - 184.0)
	var text_pos := Vector2(text_x, pos.y - 38.0)
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_CENTER, 176, 10, Color("#ead9b6"))


func _draw_route_area_decor() -> void:
	if area == Area.HUNTER_TRAIL:
		draw_line(Vector2(238, 745), Vector2(250, 585), Color(0.35, 0.30, 0.21, 0.20), 18.0)
		draw_line(Vector2(250, 585), Vector2(225, 410), Color(0.35, 0.30, 0.21, 0.18), 15.0)
		draw_line(Vector2(225, 410), Vector2(245, 205), Color(0.35, 0.30, 0.21, 0.16), 12.0)
		for p: Vector2 in [Vector2(202, 420), Vector2(275, 510), Vector2(218, 315)]:
			for i in range(3):
				draw_circle(p + Vector2(float(i) * 8.0, float(i % 2) * 6.0), 2.6, Color(0.39, 0.30, 0.20, 0.48))
	elif area == Area.SAWMILL:
		draw_rect(Rect2(Vector2(122, 145), Vector2(236, 108)), Color(0.14, 0.13, 0.10, 0.34))
		for x in [140.0, 188.0, 292.0, 340.0]:
			draw_line(Vector2(x, 145), Vector2(x + 12.0, 250), Color(0.34, 0.25, 0.16, 0.35), 6.0)
		draw_line(Vector2(120, 258), Vector2(360, 258), Color(0.39, 0.29, 0.18, 0.42), 6.0)
		for y in [350.0, 470.0, 590.0]:
			draw_line(Vector2(90, y), Vector2(150, y - 12), Color(0.33, 0.24, 0.16, 0.28), 4.0)
			draw_line(Vector2(330, y + 8), Vector2(395, y - 4), Color(0.33, 0.24, 0.16, 0.28), 4.0)
	elif area == Area.WORKER_RUINS:
		draw_rect(Rect2(Vector2(135, 140), Vector2(215, 98)), Color(0.12, 0.13, 0.12, 0.32))
		draw_line(Vector2(145, 235), Vector2(165, 160), Color(0.35, 0.29, 0.21, 0.42), 7.0)
		draw_line(Vector2(340, 235), Vector2(318, 160), Color(0.35, 0.29, 0.21, 0.42), 7.0)
		draw_line(Vector2(160, 165), Vector2(320, 165), Color(0.40, 0.33, 0.24, 0.46), 7.0)
		draw_line(Vector2(180, 230), Vector2(300, 180), Color(0.25, 0.22, 0.18, 0.36), 5.0)
		if not worker_route_complete:
			var barricade_alpha := 0.58 if enemies.size() > 0 else 0.26
			draw_line(Vector2(202, 205), Vector2(300, 205), Color(0.48, 0.34, 0.21, barricade_alpha), 8.0)
			draw_line(Vector2(215, 184), Vector2(285, 224), Color(0.39, 0.28, 0.18, barricade_alpha), 6.0)
			if enemies.size() > 0:
				draw_string(font, Vector2(180, 252), "ПРОХОД ЗАБЛОКИРОВАН", HORIZONTAL_ALIGNMENT_CENTER, 144, 9, Color("#c8ad7c"))
		for p: Vector2 in [Vector2(125, 350), Vector2(360, 390), Vector2(155, 540)]:
			draw_circle(p, 34.0, Color(0.12, 0.14, 0.13, 0.20))
			draw_line(p + Vector2(-22, 8), p + Vector2(24, -6), Color(0.36, 0.31, 0.24, 0.25), 4.0)
	elif area == Area.WATCH_RIDGE:
		for p: Vector2 in [Vector2(105, 250), Vector2(375, 275), Vector2(130, 540), Vector2(350, 560)]:
			draw_circle(p, 46.0, Color(0.10, 0.13, 0.13, 0.23))
		draw_line(Vector2(212, 250), Vector2(228, 152), Color(0.35, 0.28, 0.20, 0.45), 7.0)
		draw_line(Vector2(270, 250), Vector2(255, 154), Color(0.35, 0.28, 0.20, 0.45), 7.0)
		draw_line(Vector2(215, 168), Vector2(270, 180), Color(0.42, 0.33, 0.22, 0.48), 7.0)
	elif area == Area.ALTAR_GLADE:
		draw_circle(Vector2(240, 215), 82.0, Color(0.15, 0.12, 0.10, 0.28))
		for i in range(10):
			var a := TAU * float(i) / 10.0
			var p := Vector2(240, 215) + Vector2(cos(a), sin(a)) * 58.0
			draw_circle(p, 5.0, Color(0.34, 0.34, 0.30, 0.46))
		draw_line(Vector2(150, 420), Vector2(330, 420), Color(0.30, 0.23, 0.18, 0.18), 5.0)


func _draw_explorer_lantern() -> void:
	var glow := 0.055 + sin(Time.get_ticks_msec() * 0.007) * 0.012
	draw_circle(hero_pos + Vector2(0, -10), 32.0, Color(1.0, 0.58, 0.22, glow))
	draw_circle(hero_pos + Vector2(13, -4), 4.0, Color("#efae55"))
	draw_circle(hero_pos + Vector2(13, -4), 9.0, Color(1.0, 0.66, 0.28, 0.08))


func _draw_map_variant_decor() -> void:
	if map_variant == 0:
		# Quiet clearing: open ground with a faint circular animal trail.
		draw_arc(HEARTH_POS, 178.0, 0.2, TAU - 0.35, 72, Color(0.28, 0.32, 0.24, 0.13), 6.0)

	elif map_variant == 1:
		# Ruined road: a broad, broken lane runs across the entire map.
		var road_left := PackedVector2Array([
			Vector2(162, 110), Vector2(185, 245), Vector2(171, 390),
			Vector2(198, 535), Vector2(188, 760)
		])
		var road_right := PackedVector2Array([
			Vector2(292, 110), Vector2(315, 245), Vector2(300, 390),
			Vector2(327, 535), Vector2(318, 760)
		])
		for i in range(road_left.size() - 1):
			draw_line(road_left[i], road_left[i + 1], Color(0.30, 0.28, 0.22, 0.24), 18.0)
			draw_line(road_right[i], road_right[i + 1], Color(0.30, 0.28, 0.22, 0.24), 18.0)
			var middle_a := (road_left[i] + road_right[i]) * 0.5
			var middle_b := (road_left[i + 1] + road_right[i + 1]) * 0.5
			draw_line(middle_a, middle_b, Color(0.39, 0.35, 0.27, 0.09), 42.0)
		for y in range(175, 735, 105):
			draw_line(Vector2(205, y), Vector2(270, y + 6), Color(0.43, 0.36, 0.25, 0.16), 3.0)

	elif map_variant == 2:
		# Stone hollow: shelves, quarry scars and darker exposed ground.
		for p: Vector2 in [Vector2(86, 255), Vector2(394, 270), Vector2(98, 608), Vector2(374, 626)]:
			draw_circle(p, 52.0, Color(0.15, 0.19, 0.17, 0.22))
			draw_arc(p, 38.0, 0.10, 3.02, 24, Color(0.42, 0.45, 0.42, 0.25), 5.0)
			draw_line(p + Vector2(-29, 12), p + Vector2(28, 4), Color(0.31, 0.34, 0.33, 0.21), 4.0)
		draw_line(Vector2(65, 448), Vector2(158, 426), Color(0.32, 0.35, 0.33, 0.17), 8.0)
		draw_line(Vector2(323, 448), Vector2(430, 430), Color(0.32, 0.35, 0.33, 0.17), 8.0)

	elif map_variant == 3:
		# Burnt homestead: large ash patches, broken fences and charred beams.
		for p: Vector2 in [Vector2(102, 300), Vector2(380, 330), Vector2(118, 602), Vector2(350, 655)]:
			draw_circle(p, 48.0, Color(0.07, 0.06, 0.055, 0.29))
			draw_circle(p + Vector2(10, -6), 26.0, Color(0.11, 0.085, 0.065, 0.20))
		var fence_segments: Array[Array] = [
			[Vector2(42, 294), Vector2(148, 318)],
			[Vector2(332, 300), Vector2(444, 322)],
			[Vector2(55, 605), Vector2(151, 574)]
		]
		for segment: Array in fence_segments:
			var start: Vector2 = segment[0]
			var finish: Vector2 = segment[1]
			draw_line(start, finish, Color(0.29, 0.22, 0.16, 0.52), 5.0)
			var mid: Vector2 = (start + finish) * 0.5
			draw_line(mid + Vector2(0, -14), mid + Vector2(0, 15), Color(0.24, 0.18, 0.13, 0.46), 4.0)


func _draw_environment_decor() -> void:
	for item: Dictionary in decor_points:
		var pos: Vector2 = item["pos"]
		var kind := String(item.get("kind", "grass"))
		var scale := float(item.get("scale", 1.0))
		var visibility := _light_visibility(pos)
		var alpha := lerpf(0.035, 0.64, visibility)
		if kind == "grass":
			_draw_centered_texture(TEX_GRASS, pos + Vector2(0, -3), Vector2(20, 16) * scale, Color(0.78, 0.92, 0.76, alpha))
		elif kind == "pebble":
			draw_circle(pos, 2.7 * scale, Color(0.35, 0.39, 0.36, alpha))
		elif kind == "ash":
			draw_circle(pos, 3.2 * scale, Color(0.18, 0.17, 0.15, alpha * 0.8))
			draw_line(pos + Vector2(-5, 2), pos + Vector2(5, -2), Color(0.20, 0.17, 0.14, alpha), 1.8)
		else:
			draw_line(pos + Vector2(-6, 2), pos + Vector2(7, -2), Color(0.34, 0.25, 0.17, alpha), 2.2)


func _draw_world_events() -> void:
	for event: Dictionary in events:
		var pos: Vector2 = event["pos"]
		var visibility := _light_visibility(pos)
		if visibility < 0.11:
			continue

		var kind := String(event.get("kind", ""))
		var triggered := bool(event.get("triggered", false))
		if kind == "whisper" and not (stage in [Stage.NIGHT1, Stage.NIGHT2, Stage.NIGHT3] and twilight_timer > 0.0):
			continue

		if visibility < 0.58 and not triggered:
			# Unknown things stay unknown until the fire actually reaches them.
			draw_circle(pos, 18.0, Color(0.06, 0.08, 0.075, 0.22 * visibility))
			if kind in ["black_tree", "broken_watch"]:
				draw_line(pos + Vector2(0, 15), pos + Vector2(0, -22), Color(0.08, 0.10, 0.09, 0.28 * visibility), 7.0)
			continue

		var alpha := (0.40 if triggered else 1.0) * visibility
		match kind:
			"wagon":
				_draw_event_wagon(pos, alpha, triggered)
			"wounded":
				_draw_event_wounded(pos, alpha, triggered)
			"altar":
				_draw_event_altar(pos, alpha, triggered)
			"black_tree":
				_draw_event_black_tree(pos, alpha, triggered)
			"dead_camp":
				_draw_event_dead_camp(pos, alpha, triggered)
			"tracks":
				_draw_event_tracks(pos, alpha, triggered)
			"broken_watch":
				_draw_event_broken_watch(pos, alpha, triggered)
			"whisper":
				_draw_event_whisper(pos, alpha, triggered)
			"sawmill":
				_draw_event_sawmill(pos, alpha, triggered)
			"watch_repair":
				_draw_event_broken_watch(pos, alpha, triggered)
			"final_altar":
				_draw_event_altar(pos, alpha, triggered)

		if not triggered:
			var progress := 0.0
			if kind == "black_tree":
				progress = clampf(float(event.get("progress", 0.0)), 0.0, 1.0)
			else:
				progress = clampf(float(event.get("progress", 0.0)) / maxf(0.01, float(event.get("required", 1.0))), 0.0, 1.0)
			if progress > 0.01:
				draw_arc(pos, 29.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 30, Color(0.94, 0.76, 0.42, 0.85), 3.0)




func _draw_event_wagon(pos: Vector2, alpha: float, triggered: bool) -> void:
	draw_rect(Rect2(pos + Vector2(-24, -8), Vector2(48, 20)), Color(0.40, 0.29, 0.18, alpha))
	draw_circle(pos + Vector2(-17, 15), 8.0, Color(0.17, 0.16, 0.14, alpha))
	draw_circle(pos + Vector2(17, 15), 8.0, Color(0.17, 0.16, 0.14, alpha))
	draw_line(pos + Vector2(22, -2), pos + Vector2(38, -14), Color(0.43, 0.31, 0.20, alpha), 4.0)
	if not triggered:
		draw_string(font, pos + Vector2(-58, -28), "БРОШЕННАЯ ТЕЛЕГА", HORIZONTAL_ALIGNMENT_CENTER, 116, 9, Color(0.83, 0.77, 0.64, 0.80))


func _draw_event_wounded(pos: Vector2, alpha: float, triggered: bool) -> void:
	if not triggered:
		_draw_humanoid(pos, Color(0.48, 0.43, 0.39, alpha), 0.0, "civilian", 1.0)
		draw_line(pos + Vector2(-18, 12), pos + Vector2(20, 12), Color(0.28, 0.23, 0.19, alpha), 3.0)
		draw_string(font, pos + Vector2(-52, -36), "РАНЕНЫЙ", HORIZONTAL_ALIGNMENT_CENTER, 104, 9, Color(0.84, 0.78, 0.67, 0.82))


func _draw_event_altar(pos: Vector2, alpha: float, triggered: bool) -> void:
	for i in range(5):
		var a := TAU * float(i) / 5.0
		draw_circle(pos + Vector2(cos(a), sin(a)) * 18.0, 4.0, Color(0.38, 0.40, 0.36, alpha))
	var glow := 0.05 if triggered else 0.15 + 0.05 * sin(Time.get_ticks_msec() * 0.005)
	draw_circle(pos, 12.0, Color(0.62, 0.50, 0.34, glow * alpha))
	draw_string(font, pos + Vector2(-54, -31), "СТАРЫЙ АЛТАРЬ", HORIZONTAL_ALIGNMENT_CENTER, 108, 9, Color(0.82, 0.76, 0.63, 0.76 * alpha))


func _draw_event_black_tree(pos: Vector2, alpha: float, triggered: bool) -> void:
	if triggered:
		draw_circle(pos + Vector2(0, 14), 8.0, Color(0.20, 0.15, 0.12, alpha))
		return
	draw_rect(Rect2(pos + Vector2(-5, 3), Vector2(10, 32)), Color(0.16, 0.12, 0.10, alpha))
	draw_circle(pos + Vector2(0, -10), 22.0, Color(0.12, 0.16, 0.13, alpha))
	draw_circle(pos + Vector2(-15, -2), 14.0, Color(0.10, 0.14, 0.11, alpha))
	draw_circle(pos + Vector2(15, -1), 14.0, Color(0.10, 0.14, 0.11, alpha))
	draw_circle(pos + Vector2(3, -11), 3.0, Color(0.55, 0.27, 0.18, 0.75 * alpha))
	draw_string(font, pos + Vector2(-58, -43), "ЧЁРНОЕ ДЕРЕВО", HORIZONTAL_ALIGNMENT_CENTER, 116, 9, Color(0.77, 0.70, 0.60, 0.80 * alpha))


func _draw_event_dead_camp(pos: Vector2, alpha: float, triggered: bool) -> void:
	draw_circle(pos, 16.0, Color(0.20, 0.18, 0.15, 0.7 * alpha))
	for i in range(6):
		var a := TAU * float(i) / 6.0
		draw_circle(pos + Vector2(cos(a), sin(a)) * 15.0, 3.4, Color(0.35, 0.34, 0.31, alpha))
	draw_line(pos + Vector2(-12, 7), pos + Vector2(12, -7), Color(0.26, 0.18, 0.13, alpha), 4.0)
	if not triggered:
		draw_string(font, pos + Vector2(-62, -29), "ПОТУХШИЙ КОСТЁР", HORIZONTAL_ALIGNMENT_CENTER, 124, 9, Color(0.78, 0.73, 0.64, 0.80))


func _draw_event_tracks(pos: Vector2, alpha: float, triggered: bool) -> void:
	for i in range(4):
		var p := pos + Vector2(-20 + float(i) * 13.0, -8 + float(i % 2) * 11.0)
		draw_circle(p, 3.0, Color(0.38, 0.31, 0.23, alpha))
		draw_circle(p + Vector2(3, -3), 1.5, Color(0.38, 0.31, 0.23, alpha))
	if not triggered:
		draw_string(font, pos + Vector2(-52, -30), "СЛЕДЫ", HORIZONTAL_ALIGNMENT_CENTER, 104, 9, Color(0.80, 0.74, 0.63, 0.76 * alpha))


func _draw_event_broken_watch(pos: Vector2, alpha: float, triggered: bool) -> void:
	draw_line(pos + Vector2(-13, 22), pos + Vector2(-8, -24), Color(0.35, 0.28, 0.20, alpha), 5.0)
	draw_line(pos + Vector2(15, 22), pos + Vector2(6, -20), Color(0.35, 0.28, 0.20, alpha), 5.0)
	draw_line(pos + Vector2(-16, -18), pos + Vector2(17, -10), Color(0.45, 0.35, 0.23, alpha), 5.0)
	if not triggered:
		draw_string(font, pos + Vector2(-62, -36), "СЛОМАННЫЙ ДОЗОР", HORIZONTAL_ALIGNMENT_CENTER, 124, 9, Color(0.80, 0.74, 0.63, 0.76 * alpha))


func _draw_event_whisper(pos: Vector2, alpha: float, triggered: bool) -> void:
	if triggered:
		return
	var pulse := 0.55 + sin(Time.get_ticks_msec() * 0.008) * 0.18
	draw_circle(pos, 18.0, Color(0.55, 0.66, 0.58, 0.06 * alpha * pulse))
	draw_circle(pos + Vector2(-4, -4), 1.5, Color(0.86, 0.75, 0.49, alpha * pulse))
	draw_circle(pos + Vector2(4, -4), 1.5, Color(0.86, 0.75, 0.49, alpha * pulse))


func _draw_event_sawmill(pos: Vector2, alpha: float, triggered: bool) -> void:
	var beam := Color(0.43, 0.31, 0.19, alpha)
	draw_rect(Rect2(pos + Vector2(-48, -18), Vector2(96, 36)), Color(0.24, 0.19, 0.13, 0.72 * alpha))
	draw_line(pos + Vector2(-44, -20), pos + Vector2(-32, -52), beam, 7.0)
	draw_line(pos + Vector2(44, -20), pos + Vector2(32, -52), beam, 7.0)
	draw_line(pos + Vector2(-36, -50), pos + Vector2(38, -50), beam, 7.0)
	draw_circle(pos + Vector2(0, -3), 20.0, Color(0.38, 0.40, 0.36, 0.85 * alpha))
	for i in range(8):
		var a := TAU * float(i) / 8.0
		draw_line(pos + Vector2(cos(a), sin(a)) * 5.0, pos + Vector2(cos(a), sin(a)) * 18.0, Color(0.64, 0.64, 0.56, alpha), 2.0)
	if not triggered:
		draw_string(font, pos + Vector2(-72, -72), "СТАРАЯ ЛЕСОПИЛКА", HORIZONTAL_ALIGNMENT_CENTER, 144, 10, Color(0.86, 0.78, 0.63, 0.86 * alpha))


func _draw_revealed_landmarks() -> void:
	# The rescued people live in actual places revealed by the firelight.
	if _light_visibility(survivor_one_pos) > 0.66:
		_draw_ruined_shelter(survivor_one_pos + Vector2(-18, 20), Color("#5f543f"))
	if _light_visibility(survivor_two_pos) > 0.66:
		_draw_ruined_shelter(survivor_two_pos + Vector2(22, 18), Color("#5a4c3d"))
	if light_radius >= 245.0:
		_draw_ruined_shelter(HEARTH_POS + Vector2(-112, -44), Color("#574c3c"))


func _draw_ruined_shelter(pos: Vector2, color: Color) -> void:
	draw_rect(Rect2(pos + Vector2(-17, -4), Vector2(34, 22)), Color(color.r, color.g, color.b, 0.75))
	draw_line(pos + Vector2(-22, -4), pos + Vector2(-4, -22), Color("#76634a"), 4.0)
	draw_line(pos + Vector2(-4, -22), pos + Vector2(20, -5), Color("#76634a"), 4.0)
	draw_line(pos + Vector2(4, -18), pos + Vector2(22, -10), Color("#4c4438"), 3.0)


func _draw_night_edge_eyes(alpha: float) -> void:
	if twilight_timer > 0.0 or active_night_sides.is_empty():
		return

	var side_positions := {
		0: [Vector2(176, 112), Vector2(302, 112)],
		1: [Vector2(452, 318), Vector2(452, 584)],
		2: [Vector2(178, 750), Vector2(316, 750)],
		3: [Vector2(28, 326), Vector2(28, 606)]
	}

	for side_variant: Variant in active_night_sides:
		var side := int(side_variant)
		if not side_positions.has(side):
			continue
		var positions: Array = side_positions[side]
		for j in range(positions.size()):
			var p: Vector2 = positions[j]
			var pulse := 0.30 + 0.30 * sin(Time.get_ticks_msec() * 0.004 + float(side) + float(j) * 0.9)
			draw_circle(p + Vector2(-4, 0), 1.8, Color(0.94, 0.60, 0.24, alpha * pulse))
			draw_circle(p + Vector2(4, 0), 1.8, Color(0.94, 0.60, 0.24, alpha * pulse))


func _draw_ground_texture(color: Color, spacing: int) -> void:
	for y in range(140, 790, spacing):
		for x in range(20, 470, spacing):
			var offset := float((x * 13 + y * 7) % 17)
			var p := Vector2(float(x) + offset, float(y))
			draw_circle(p, 2.0, color)
			if int((x + y) / spacing) % 3 == 0:
				draw_circle(p + Vector2(9, 7), 7.0, Color(0.07, 0.12, 0.09, 0.055))


func _light_visibility(pos: Vector2) -> float:
	if mode == Mode.HUB:
		return 1.0
	var center := _active_light_center()
	var radius := _active_light_radius()
	var distance := pos.distance_to(center)
	var full_radius := maxf(60.0, radius - 34.0)
	var edge_radius := radius + 6.0
	if distance <= full_radius:
		return 1.0
	if distance >= edge_radius:
		return 0.035
	return lerpf(0.035, 1.0, 1.0 - (distance - full_radius) / maxf(1.0, edge_radius - full_radius))


func _lit_world_color(base: Color, pos: Vector2, alpha_scale: float = 1.0) -> Color:
	var visibility := _light_visibility(pos)
	var center := _active_light_center()
	var radius := _active_light_radius()
	var distance := pos.distance_to(center)
	var warmth := clampf(1.0 - distance / maxf(1.0, radius), 0.0, 1.0)
	var warm := base.lerp(Color("#f2b86a"), warmth * 0.14)
	var cold := Color(warm.r * 0.54, warm.g * 0.66, warm.b * 0.72, warm.a)
	var result := cold.lerp(warm, visibility)
	result.a = visibility * alpha_scale
	return result


func _draw_world_vignette(night_mix: float) -> void:
	var strength := 0.10 + night_mix * 0.15
	for i in range(5):
		var inset := float(i) * 13.0
		var a := strength * (1.0 - float(i) / 6.0)
		draw_rect(Rect2(Vector2(inset, 82 + inset), Vector2(480.0 - inset * 2.0, 17.0)), Color(0.0, 0.02, 0.025, a))
		draw_rect(Rect2(Vector2(inset, 783.0 - inset), Vector2(480.0 - inset * 2.0, 17.0)), Color(0.0, 0.02, 0.025, a))
		draw_rect(Rect2(Vector2(inset, 82 + inset), Vector2(15.0, 718.0 - inset * 2.0)), Color(0.0, 0.02, 0.025, a))
		draw_rect(Rect2(Vector2(465.0 - inset, 82 + inset), Vector2(15.0, 718.0 - inset * 2.0)), Color(0.0, 0.02, 0.025, a))


func _draw_light_field(center: Vector2, radius: float) -> void:
	# Dense, low-alpha layers remove the visible ring effect and create a softer falloff.
	var time := float(Time.get_ticks_msec()) * 0.001
	var flicker := 1.0 + sin(time * 3.7) * 0.010 + sin(time * 7.9 + 1.2) * 0.006
	var effective_radius := radius * flicker

	draw_circle(center, effective_radius * 1.06, Color(0.88, 0.55, 0.23, 0.010))
	for i in range(42, 0, -1):
		var t := float(i) / 42.0
		var r := effective_radius * t
		var inner := 1.0 - t
		var alpha := 0.0018 + pow(inner, 1.85) * 0.0105
		var warmth := 0.50 + inner * 0.24
		draw_circle(center, r, Color(1.0, warmth, 0.20, alpha))

	# Brighter central pool near the flame.
	draw_circle(center, effective_radius * 0.34, Color(1.0, 0.55, 0.18, 0.022 + hearth_pulse * 0.010))
	draw_circle(center, effective_radius * 0.15, Color(1.0, 0.67, 0.27, 0.030 + hearth_pulse * 0.016))


func _draw_survivor_silhouette(pos: Vector2, visibility: float) -> void:
	var a := clampf((visibility - 0.18) / 0.54, 0.0, 1.0) * 0.45
	draw_circle(pos + Vector2(0, -14), 7.0, Color(0.05, 0.07, 0.065, a))
	draw_rect(Rect2(pos + Vector2(-8, -7), Vector2(16, 24)), Color(0.05, 0.07, 0.065, a))
	draw_circle(pos, 24.0, Color(0.92, 0.65, 0.28, 0.018 * a))


func _draw_resource(node: Dictionary) -> void:
	var pos: Vector2 = node["pos"]
	var alive := bool(node.get("alive", false))
	var kind := String(node.get("kind", "tree"))
	var visibility := _light_visibility(pos)
	var modulate := _asset_modulate(pos, 0.035)

	if kind == "tree":
		var variant := int(node.get("variant", 0)) % 3
		if alive:
			var tree_tex: Texture2D = TEX_TREE_A
			if variant == 1:
				tree_tex = TEX_TREE_B
			elif variant == 2:
				tree_tex = TEX_TREE_C
			var hit_flash := float(node.get("hit_flash", 0.0))
			var sway := sin(Time.get_ticks_msec() * 0.0012 + pos.x * 0.013) * 0.7
			if hit_flash > 0.0:
				sway += sin(Time.get_ticks_msec() * 0.065) * 3.2 * hit_flash
				modulate = modulate.lerp(Color(1.0, 0.86, 0.58, modulate.a), hit_flash * 0.34)
			var tree_size := Vector2(78, 86) * (1.0 + hit_flash * 0.018)
			_draw_centered_texture(tree_tex, pos + Vector2(sway, -22), tree_size, modulate)

			if gather_cd > 0.0 and hero_pos.distance_to(pos) <= HERO_INTERACT_RADIUS + 4.0:
				var hit_t := 1.0 - clampf(gather_cd / maxf(0.01, gather_interval), 0.0, 1.0)
				var shake := sin(hit_t * PI * 3.0) * 2.2
				draw_line(pos + Vector2(shake - 12, -11), pos + Vector2(shake + 13, -17), Color(0.95, 0.70, 0.34, 0.20 * visibility), 2.0)
		elif not bool(node.get("drop_spawned", true)):
			var progress := 1.0 - clampf(float(node.get("fall_timer", 0.0)) / 0.34, 0.0, 1.0)
			var falling_pos := pos + Vector2(22.0 * progress, -10.0 + progress * 13.0)
			_draw_centered_texture(TEX_TREE_FALLING, falling_pos, Vector2(112, 78), modulate)
		else:
			_draw_centered_texture(TEX_STUMP, pos + Vector2(0, 4), Vector2(39, 39), modulate)
	else:
		if alive:
			_draw_centered_texture(TEX_ROCK, pos + Vector2(0, -2), Vector2(46, 42), modulate)
		elif not bool(node.get("drop_spawned", true)):
			_draw_centered_texture(TEX_ROCK, pos + Vector2(-7, 2), Vector2(30, 28), modulate)
			_draw_centered_texture(TEX_ROCK, pos + Vector2(9, 7), Vector2(23, 21), modulate)
		else:
			draw_circle(pos, 5.5, Color(0.42, 0.47, 0.45, maxf(0.08, visibility * 0.6)))


func _draw_resource_pickup(pickup: Dictionary) -> void:
	var pos: Vector2 = pickup["pos"]
	var kind := String(pickup.get("kind", "wood"))
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.006 + pos.x * 0.04) * 0.05
	draw_circle(pos + Vector2(0, 7), 10.0, Color(0.02, 0.03, 0.02, 0.20))
	if kind == "wood":
		_draw_centered_texture(TEX_LOG, pos, Vector2(36, 18) * pulse, _asset_modulate(pos, 0.20))
	else:
		_draw_centered_texture(TEX_ROCK, pos, Vector2(27, 24) * pulse, _asset_modulate(pos, 0.18))


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
			_draw_centered_texture(TEX_LOG, p, Vector2(29, 15), Color.WHITE)
		else:
			_draw_centered_texture(TEX_ROCK, p, Vector2(19, 17), Color.WHITE)


func _draw_hearth(pos: Vector2, level: int) -> void:
	var time := float(Time.get_ticks_msec()) * 0.001
	var pulse := 1.0 + hearth_pulse * 0.08 + sin(time * 6.5) * 0.018
	var glow_alpha := 0.045 + hearth_pulse * 0.040
	var ring_radius := 34.0 + float(level) * 3.5
	draw_circle(pos, 58.0 * pulse + float(level) * 5.0, Color(1.0, 0.50, 0.12, glow_alpha))
	draw_circle(pos, 35.0 * pulse + float(level) * 3.0, Color(1.0, 0.68, 0.22, 0.055 + hearth_pulse * 0.05))

	if level <= 1:
		_draw_centered_texture(TEX_HEARTH_1, pos + Vector2(0, -1), Vector2(92, 92) * pulse, Color.WHITE)
	elif level == 2:
		_draw_centered_texture(TEX_HEARTH_2, pos + Vector2(0, -2), Vector2(104, 104) * pulse, Color.WHITE)
	else:
		# Higher levels retain the existing built structure until Sprint 3 replaces them with dedicated assets.
		draw_circle(pos + Vector2(0, 15), 50.0 + float(level) * 3.0, Color(0.02, 0.025, 0.02, 0.34))
		for i in range(9):
			var angle := TAU * float(i) / 9.0
			var stone := pos + Vector2(cos(angle), sin(angle)) * ring_radius
			draw_circle(stone, 7.5 + float(level) * 0.4, Color("#5b5950"))
		for a in [-0.45, 0.45]:
			var axis := Vector2(cos(a), sin(a))
			draw_line(pos - axis * 20.0, pos + axis * 20.0, Color("#704326"), 8.0, true)
		var flame_h := (29.0 + float(level) * 7.0) * pulse
		var flame_w := 17.0 + float(level) * 2.4
		var outer := PackedVector2Array([
			pos + Vector2(0, -flame_h), pos + Vector2(flame_w, 8),
			pos + Vector2(8, 22), pos + Vector2(-8, 22), pos + Vector2(-flame_w, 8)
		])
		draw_colored_polygon(outer, Color("#ee8e32"))
		var middle := PackedVector2Array([
			pos + Vector2(2, -flame_h * 0.72), pos + Vector2(flame_w * 0.62, 9),
			pos + Vector2(0, 20), pos + Vector2(-flame_w * 0.62, 8)
		])
		draw_colored_polygon(middle, Color("#ffc45e"))
		var inner := PackedVector2Array([
			pos + Vector2(0, -flame_h * 0.42), pos + Vector2(7, 8),
			pos + Vector2(0, 16), pos + Vector2(-7, 8)
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

	# Smoke, sparks and a short expanding wave make the first upgrade a real payoff.
	var smoke_strength := 0.11 if level <= 1 else 0.16
	for i in range(3):
		var phase := time * (0.38 + float(i) * 0.07) + float(i) * 2.1
		var smoke_pos := pos + Vector2(sin(phase) * (4.0 + float(i) * 2.0), -38.0 - fmod(time * (10.0 + float(i) * 2.0) + float(i) * 17.0, 38.0))
		var smoke_alpha := smoke_strength * (1.0 - float(i) * 0.18)
		draw_circle(smoke_pos, 6.0 + float(i) * 1.7, Color(0.40, 0.43, 0.39, smoke_alpha))
	for i in range(4):
		var spark_phase := time * (1.4 + float(i) * 0.12) + float(i) * 1.7
		var spark_y := fmod(time * (18.0 + float(i) * 3.0) + float(i) * 13.0, 46.0)
		var spark_pos := pos + Vector2(sin(spark_phase) * 12.0, -22.0 - spark_y)
		draw_circle(spark_pos, 1.4 + float(i % 2), Color(1.0, 0.70, 0.28, 0.55))

	if upgrade_wave > 0.0:
		var wave_t := 1.0 - upgrade_wave
		var wave_radius := 58.0 + wave_t * 155.0
		draw_arc(pos, wave_radius, 0.0, TAU, 64, Color(1.0, 0.68, 0.28, upgrade_wave * 0.38), 3.0)

	draw_string(font, pos + Vector2(-55, 70), "ОЧАГ %d" % level, HORIZONTAL_ALIGNMENT_CENTER, 110, 12, Color("#eadfc8"))


func _draw_centered_texture(texture: Texture2D, pos: Vector2, size: Vector2, modulate: Color = Color.WHITE) -> void:
	var rect := Rect2(pos - size * 0.5, size)
	draw_texture_rect(texture, rect, false, modulate)


func _asset_modulate(pos: Vector2, minimum_visibility: float = 0.10) -> Color:
	var visibility := maxf(minimum_visibility, _light_visibility(pos))
	var distance := pos.distance_to(HEARTH_POS)
	var warmth := clampf(1.0 - distance / maxf(1.0, light_display_radius), 0.0, 1.0)
	var base := Color(0.60, 0.68, 0.70, visibility)
	var warm := Color(1.0, 0.91, 0.75, visibility)
	return base.lerp(warm, warmth * 0.58)


func _draw_hero(pos: Vector2) -> void:
	var moving := hero_pos.distance_to(hero_target) > 3.0 or joystick_vector.length() > JOYSTICK_DEADZONE
	var work_kind := _nearby_resource_kind()
	var texture: Texture2D = TEX_HERO_IDLE
	var size := Vector2(64, 64)

	if carried_wood > 0:
		if carried_wood == 1:
			texture = TEX_HERO_CARRY_1
		elif carried_wood == 2:
			texture = TEX_HERO_CARRY_2
		else:
			texture = TEX_HERO_CARRY_3
	elif work_kind != "" and gather_cd > 0.04:
		texture = TEX_HERO_ATTACK
		size = Vector2(72, 62)
	elif moving:
		texture = TEX_HERO_WALK

	var bob := 0.0
	if moving:
		bob = sin(hero_walk_phase * 1.15) * 1.6

	_draw_ellipse_custom(pos + Vector2(0, 18), Vector2(16, 5), Color(0.01, 0.02, 0.015, 0.30))
	_draw_centered_texture(texture, pos + Vector2(0, -9 + bob), size, _asset_modulate(pos, 0.34))

	# Stone cargo remains readable until its dedicated production sprite arrives in Sprint 2.
	if carried_stone > 0:
		var sack := pos + Vector2(-19, 5 + bob)
		draw_circle(sack, 8.5, Color("#746b59"))
		draw_line(sack + Vector2(-6, -5), sack + Vector2(6, -5), Color("#a9997f"), 2.0)
		for i in range(mini(carried_stone, 4)):
			var p := sack + Vector2(-4 + float(i % 2) * 8.0, -2 + float(i / 2) * 6.0)
			draw_circle(p, 2.7, Color("#a4aaa7"))


func _nearby_resource_kind() -> String:
	if not _gathering_enabled():
		return ""
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
	var visible_logs := mini(carried_wood, 7)
	if visible_logs > 0:
		# A visible carrying frame keeps the logs clearly behind the character.
		draw_line(pos + Vector2(-13, -25), pos + Vector2(-13, 9), Color("#6d5235"), 3.0, true)
		draw_line(pos + Vector2(13, -25), pos + Vector2(13, 9), Color("#6d5235"), 3.0, true)
		draw_line(pos + Vector2(-13, -10), pos + Vector2(13, -10), Color("#876540"), 2.0, true)
		for i in range(visible_logs):
			var row := i / 2
			var side := -1.0 if i % 2 == 0 else 1.0
			var center := pos + Vector2(side * 4.0, -7.0 - float(row) * 7.0)
			var tilt := 0.06 * side
			var axis := Vector2(cos(tilt), sin(tilt))
			draw_line(center - axis * 16.0, center + axis * 16.0, Color("#8d5c32"), 6.5, true)
			draw_circle(center - axis * 16.0, 3.2, Color("#c78e56"))
			draw_circle(center + axis * 16.0, 3.2, Color("#c78e56"))
		draw_line(pos + Vector2(-13, -1), pos + Vector2(10, -27), Color(0.73, 0.60, 0.39, 0.88), 2.3)
		draw_line(pos + Vector2(13, -1), pos + Vector2(-10, -27), Color(0.73, 0.60, 0.39, 0.88), 2.3)

	if carried_stone > 0:
		var sack := pos + Vector2(-19, 6)
		draw_circle(sack, 9.5, Color("#746b59"))
		draw_line(sack + Vector2(-6, -5), sack + Vector2(6, -5), Color("#a9997f"), 2.0)
		for i in range(mini(carried_stone, 4)):
			var p := sack + Vector2(-4 + float(i % 2) * 8.0, -2 + float(i / 2) * 6.0)
			draw_circle(p, 2.7, Color("#a4aaa7"))


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
	var visibility := _light_visibility(pos)
	var lit_coat := _lit_world_color(coat, pos)
	var skin := _lit_world_color(Color("#c69c7d"), pos)
	var dark_leg := _lit_world_color(Color("#403c34"), pos)
	_draw_ellipse_custom(pos + Vector2(0, 18), Vector2(14, 5), Color(0.01, 0.02, 0.015, 0.30 * maxf(0.2, visibility)))

	draw_line(base + Vector2(-5, 8), base + Vector2(-7 + moving_stride, 19), dark_leg, 4.0, true)
	draw_line(base + Vector2(5, 8), base + Vector2(7 - moving_stride, 19), dark_leg, 4.0, true)
	draw_line(base + Vector2(-10 + moving_stride, 19), base + Vector2(-4 + moving_stride, 19), _lit_world_color(Color("#272824"), pos), 4.0, true)
	draw_line(base + Vector2(4 - moving_stride, 19), base + Vector2(10 - moving_stride, 19), _lit_world_color(Color("#272824"), pos), 4.0, true)

	var torso := PackedVector2Array([
		base + Vector2(-10, -10), base + Vector2(10, -10),
		base + Vector2(12, 9), base + Vector2(-12, 9)
	])
	draw_colored_polygon(torso, lit_coat)
	draw_rect(Rect2(base + Vector2(-11, 4), Vector2(22, 3)), _lit_world_color(Color("#5a4630"), pos))

	var arm_sway := sin(phase + 1.2) * 3.0
	draw_line(base + Vector2(-9, -5), base + Vector2(-14 - arm_sway, 6), lit_coat.lightened(0.06), 4.0, true)
	draw_line(base + Vector2(9, -5), base + Vector2(14 + arm_sway, 5), lit_coat.lightened(0.06), 4.0, true)

	draw_circle(base + Vector2(0, -17), 7.2, skin)
	draw_arc(base + Vector2(0, -18), 7.0, PI, TAU, 16, _lit_world_color(Color("#5b4737"), pos), 4.0)
	draw_circle(base + Vector2(2.5 * facing, -17), 0.9, _lit_world_color(Color("#342f28"), pos))

	if visibility > 0.30:
		var fire_dir := (HEARTH_POS - pos).normalized()
		draw_line(base + fire_dir * 8.0 + Vector2(0, -5), base + fire_dir * 10.0 + Vector2(0, 7), Color(1.0, 0.67, 0.30, 0.20 * visibility), 2.2, true)
		draw_circle(base + Vector2(0, -17) + fire_dir * 4.8, 2.2, Color(1.0, 0.73, 0.42, 0.18 * visibility))

	if role == "hunter":
		var hand := base + Vector2(13, 0)
		draw_arc(hand + Vector2(7, -2), 9.0, -1.55, 1.55, 12, _lit_world_color(Color("#d1b989"), pos), 2.0)
		draw_line(hand + Vector2(7, -11), hand + Vector2(7, 7), _lit_world_color(Color("#b69a6c"), pos), 1.5)
	elif role == "worker":
		var work := 0.25 + sin(phase) * 0.45
		var hand := base + Vector2(13, 0)
		var tip := hand + Vector2(cos(-0.8 + work), sin(-0.8 + work)) * 20.0
		draw_line(hand, tip, _lit_world_color(Color("#b2875b"), pos), 3.0)
		draw_rect(Rect2(tip + Vector2(-4, -4), Vector2(8, 6)), _lit_world_color(Color("#8d8c83"), pos))
	elif role == "guard":
		draw_line(base + Vector2(11, -1), base + Vector2(24, -13), _lit_world_color(Color("#c5c9c4"), pos), 2.5)
		draw_line(base + Vector2(19, -14), base + Vector2(26, -9), _lit_world_color(Color("#c5c9c4"), pos), 2.0)


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
	if area != Area.CAMP and _light_visibility(pos) < 0.12:
		return
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
	var pos := _workshop_pos()
	_draw_ellipse_custom(pos + Vector2(0, 23), Vector2(38, 10), Color(0.01, 0.02, 0.015, 0.26))
	draw_rect(Rect2(pos + Vector2(-31, -14), Vector2(62, 42)), _lit_world_color(Color("#5c4935"), pos))
	var roof := PackedVector2Array([
		pos + Vector2(-38, -14), pos + Vector2(0, -43), pos + Vector2(38, -14)
	])
	draw_colored_polygon(roof, _lit_world_color(Color("#7b5f3c"), pos))
	draw_rect(Rect2(pos + Vector2(-20, 4), Vector2(17, 13)), Color("#302d27"))
	draw_line(pos + Vector2(12, 5), pos + Vector2(28, -7), Color("#c0a574"), 3.0)
	draw_rect(Rect2(pos + Vector2(25, -11), Vector2(8, 7)), Color("#8f8c81"))
	draw_string(font, pos + Vector2(-52, 45), "МАСТЕРСКАЯ", HORIZONTAL_ALIGNMENT_CENTER, 104, 10, Color("#ded1b7"))


func _draw_tower() -> void:
	var pos := _tower_pos()
	_draw_ellipse_custom(pos + Vector2(0, 22), Vector2(30, 9), Color(0.01, 0.02, 0.015, 0.25))
	draw_line(pos + Vector2(-13, 25), pos + Vector2(-8, -38), _lit_world_color(Color("#604a31"), pos), 7.0)
	draw_line(pos + Vector2(13, 25), pos + Vector2(8, -38), _lit_world_color(Color("#604a31"), pos), 7.0)
	draw_rect(Rect2(pos + Vector2(-24, -48), Vector2(48, 17)), _lit_world_color(Color("#765939"), pos))
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


func _draw_stockpile() -> void:
	if camp_wood > 0:
		var wood_pos := HEARTH_POS + Vector2(-76, 47)
		var shown := mini(camp_wood, 6)
		for i in range(shown):
			var row := i / 3
			var col := i % 3
			var p := wood_pos + Vector2(float(col) * 11.0 - 11.0, -float(row) * 7.0)
			draw_line(p + Vector2(-6, 0), p + Vector2(6, 0), Color("#8f5d33"), 5.0, true)
			draw_circle(p + Vector2(-6, 0), 2.3, Color("#c58b54"))
			draw_circle(p + Vector2(6, 0), 2.3, Color("#c58b54"))
		draw_string(font, wood_pos + Vector2(-24, 19), "%d" % camp_wood, HORIZONTAL_ALIGNMENT_CENTER, 48, 9, Color("#d9bf91"))

	if camp_stone > 0:
		var stone_pos := HEARTH_POS + Vector2(76, 48)
		var shown := mini(camp_stone, 6)
		for i in range(shown):
			var row := i / 3
			var col := i % 3
			var p := stone_pos + Vector2(float(col) * 10.0 - 10.0, -float(row) * 7.0)
			draw_circle(p, 4.2, Color("#858f8c"))
		draw_string(font, stone_pos + Vector2(-24, 19), "%d" % camp_stone, HORIZONTAL_ALIGNMENT_CENTER, 48, 9, Color("#c5ccc8"))


func _draw_world_progress() -> void:
	if stage == Stage.DAY1_GATHER:
		var delivered := mini(camp_wood, 5)
		draw_string(font, HEARTH_POS + Vector2(-72, -78), "БРЁВНА %d/5" % delivered, HORIZONTAL_ALIGNMENT_CENTER, 144, 12, Color("#f1d79f"))
	elif stage == Stage.DAY2_BUILD:
		var pos := _workshop_pos()
		var wood_progress := clampi(camp_wood - current_stage_wood_start, 0, 8)
		var stone_progress := clampi(camp_stone - current_stage_stone_start, 0, 5)
		draw_string(font, pos + Vector2(-78, -58), "МАСТЕРСКАЯ", HORIZONTAL_ALIGNMENT_CENTER, 156, 11, Color("#e7dbc4"))
		draw_string(font, pos + Vector2(-82, -42), "дерево %d/8 | камень %d/5" % [wood_progress, stone_progress], HORIZONTAL_ALIGNMENT_CENTER, 164, 10, Color("#d4ba88"))
	elif stage == Stage.DAY3_TOWER and area == Area.CAMP and day3_route == "":
		draw_string(font, HEARTH_POS + Vector2(-96, -92), "ДО РАССВЕТА — ОДИН ПУТЬ", HORIZONTAL_ALIGNMENT_CENTER, 192, 10, Color("#d4ba88"))


func _nearest_resource_pos(kind: String) -> Vector2:
	var best_pos := HEARTH_POS
	var best_distance := INF
	for node: Dictionary in resource_nodes:
		if not bool(node.get("alive", false)):
			continue
		var node_kind := String(node.get("kind", "tree"))
		if kind == "wood" and node_kind != "tree":
			continue
		if kind == "stone" and node_kind != "rock":
			continue
		var d := hero_pos.distance_to(node["pos"])
		if d < best_distance:
			best_distance = d
			best_pos = node["pos"]
	return best_pos


func _nearest_enemy_pos() -> Vector2:
	var best_pos := hero_pos
	var best_distance := INF
	for enemy: Dictionary in enemies:
		if float(enemy.get("hp", 0.0)) <= 0.0:
			continue
		var enemy_pos: Vector2 = enemy["pos"]
		var distance := hero_pos.distance_to(enemy_pos)
		if distance < best_distance:
			best_distance = distance
			best_pos = enemy_pos
	return best_pos


func _guidance_info() -> Dictionary:
	if stage == Stage.DAY1_GATHER:
		if carried_wood + carried_stone > 0:
			return {"pos": HEARTH_POS, "text": "ВЕРНИСЬ К ОЧАГУ"}
		if resource_pickups.size() > 0:
			var best: Dictionary = resource_pickups[0]
			var best_d := hero_pos.distance_to(best["pos"])
			for pickup: Dictionary in resource_pickups:
				var d := hero_pos.distance_to(pickup["pos"])
				if d < best_d:
					best = pickup
					best_d = d
			return {"pos": best["pos"], "text": "ПОДБЕРИ БРЁВНА"}
		return {"pos": _nearest_resource_pos("wood"), "text": "СРУБИ ДЕРЕВО"}

	if stage == Stage.DAY1_RESCUE:
		if area == Area.HUNTER_TRAIL:
			if day1_route_complete:
				return {"pos": ROUTE_RETURN_GATE, "text": "К ОЧАГУ"}
			if enemies.size() > 0:
				return {"pos": _nearest_enemy_pos(), "text": "ТВАРИ"}
			return {"pos": survivor_one_pos, "text": "ОХОТНИК"}
		if area == Area.SAWMILL:
			if day1_route_complete:
				return {"pos": ROUTE_RETURN_GATE, "text": "К ОЧАГУ"}
			if enemies.size() > 0:
				return {"pos": _nearest_enemy_pos(), "text": "ТВАРИ"}
			return {"pos": Vector2(240, 220), "text": "ЛЕСОПИЛКА"}
		return {}

	if stage == Stage.DAY2_BUILD:
		if carried_wood + carried_stone > 0:
			return {"pos": HEARTH_POS, "text": "НЕСИ В ЗАПАС"}
		if camp_wood < current_stage_wood_start + 8:
			return {"pos": _nearest_resource_pos("wood"), "text": "НУЖНО ДЕРЕВО"}
		if camp_stone < current_stage_stone_start + 5:
			return {"pos": _nearest_resource_pos("stone"), "text": "НУЖЕН КАМЕНЬ"}

	if stage == Stage.WORKSHOP_CHOICE:
		return {"pos": (left_choice_pos + right_choice_pos) * 0.5, "text": "ВЫБЕРИ ПОСТРОЙКУ"}

	if stage == Stage.DAY2_RESCUE:
		if area == Area.CAMP:
			return {}
		if area == Area.WORKER_RUINS and worker_route_complete:
			return {"pos": ROUTE_RETURN_GATE, "text": "К ОЧАГУ"}
		if area == Area.WORKER_RUINS and enemies.size() > 0:
			return {"pos": _nearest_enemy_pos(), "text": "СТРАЖИ"}
		if area == Area.WORKER_RUINS:
			return {"pos": survivor_two_pos, "text": "РАБОЧИЙ"}

	if stage == Stage.DAY3_TOWER:
		if area == Area.WATCH_RIDGE:
			if day3_route_complete:
				return {"pos": ROUTE_RETURN_GATE, "text": "К ОЧАГУ"}
			if enemies.size() > 0:
				return {"pos": _nearest_enemy_pos(), "text": "ТВАРИ"}
			return {"pos": Vector2(240, 205), "text": "ДОЗОР"}
		if area == Area.ALTAR_GLADE:
			if day3_route_complete:
				return {"pos": ROUTE_RETURN_GATE, "text": "К ОЧАГУ"}
			if enemies.size() > 0:
				return {"pos": _nearest_enemy_pos(), "text": "ТВАРИ"}
			return {"pos": Vector2(240, 210), "text": "АЛТАРЬ"}
		return {}

	if stage == Stage.EXPEDITION_CHOICE:
		return {"pos": (left_choice_pos + right_choice_pos) * 0.5, "text": "ВЫБЕРИ СИЛУ"}

	if stage == Stage.CORE_RETURN:
		if core_carried:
			return {"pos": HEARTH_POS, "text": "НЕСИ ЯДРО К ОГНЮ"}
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
	draw_string(font, Vector2(pos.x - 76, marker_y - 8), label, HORIZONTAL_ALIGNMENT_CENTER, 152, 10, Color("#f0dfbd"))


func _draw_particles() -> void:
	for p: Dictionary in particles:
		var pos: Vector2 = p["pos"]
		var max_life := maxf(0.01, float(p.get("max_life", 0.6)))
		var life := clampf(float(p.get("life", 0.0)) / max_life, 0.0, 1.0)
		var kind := String(p.get("kind", "ember"))
		var size := float(p.get("size", 2.6))
		if kind == "wood":
			var vel: Vector2 = p.get("vel", Vector2.RIGHT)
			var dir := vel.normalized() if vel.length() > 0.1 else Vector2.RIGHT
			draw_line(pos - dir * size, pos + dir * size, Color(0.73, 0.43, 0.21, life), 2.0)
		elif kind == "stone":
			draw_circle(pos, size * 0.72, Color(0.50, 0.55, 0.53, life * 0.85))
		else:
			draw_circle(pos, size, Color(1.0, 0.66, 0.24, life))
			draw_circle(pos, size * 0.42, Color(1.0, 0.91, 0.60, life))


func _draw_floaters() -> void:
	for f: Dictionary in floaters:
		var pos: Vector2 = f["pos"]
		var life := clampf(float(f.get("life", 0.0)), 0.0, 1.0)
		var color: Color = f["color"]
		color.a = life
		draw_string(font, pos + Vector2(-55, 0), String(f.get("text", "")), HORIZONTAL_ALIGNMENT_CENTER, 110, 12, color)


func _draw_icon_people(pos: Vector2, color: Color) -> void:
	draw_circle(pos + Vector2(0, -4), 3.5, color)
	draw_line(pos + Vector2(0, 0), pos + Vector2(0, 8), color, 3.0)
	draw_line(pos + Vector2(-5, 3), pos + Vector2(5, 3), color, 2.2)


func _draw_icon_ember(pos: Vector2, color: Color) -> void:
	var pts := PackedVector2Array([
		pos + Vector2(0, -7), pos + Vector2(6, 1),
		pos + Vector2(0, 8), pos + Vector2(-6, 1)
	])
	draw_colored_polygon(pts, color)
	draw_circle(pos + Vector2(0, 1), 2.2, Color("#ffe0a0"))


func _draw_icon_log(pos: Vector2, color: Color) -> void:
	draw_line(pos + Vector2(-7, 0), pos + Vector2(7, 0), color, 5.0, true)
	draw_circle(pos + Vector2(-7, 0), 2.4, Color("#d29a62"))
	draw_circle(pos + Vector2(7, 0), 2.4, Color("#d29a62"))


func _draw_icon_stone(pos: Vector2, color: Color) -> void:
	var pts := PackedVector2Array([
		pos + Vector2(-6, 4), pos + Vector2(-4, -5), pos + Vector2(4, -7),
		pos + Vector2(7, 1), pos + Vector2(3, 6), pos + Vector2(-4, 7)
	])
	draw_colored_polygon(pts, color)


func _draw_icon_cargo(pos: Vector2, color: Color) -> void:
	draw_rect(Rect2(pos + Vector2(-6, -5), Vector2(12, 11)), Color(color.r, color.g, color.b, 0.20))
	draw_line(pos + Vector2(-6, -5), pos + Vector2(6, -5), color, 2.0)
	draw_line(pos + Vector2(-6, 6), pos + Vector2(6, 6), color, 2.0)


func _draw_hud() -> void:
	draw_rect(Rect2(Vector2(0, 0), Vector2(480, 82)), Color(0.025, 0.04, 0.032, 0.92))

	if mode == Mode.HUB:
		draw_string(font, Vector2(14, 28), "ПОСЛЕДНИЙ ОЧАГ", HORIZONTAL_ALIGNMENT_LEFT, 245, 17, Color("#f0e4cd"))
		_draw_icon_ember(Vector2(387, 22), Color("#d99b50"))
		draw_string(font, Vector2(400, 27), "%d" % int(meta.get("embers", 0)), HORIZONTAL_ALIGNMENT_LEFT, 52, 14, Color("#e6c57e"))
		draw_string(font, Vector2(14, 55), "Карта — новая вылазка. Здания — постоянные улучшения.", HORIZONTAL_ALIGNMENT_LEFT, 410, 10, Color("#98a89c"))
		draw_string(font, Vector2(430, 55), "v0.10", HORIZONTAL_ALIGNMENT_RIGHT, 38, 10, Color("#728077"))
		return

	if mode == Mode.RESULT:
		return

	var stage_title := _stage_title()
	var short_goal := _short_objective_text()
	draw_string(font, Vector2(14, 27), stage_title, HORIZONTAL_ALIGNMENT_LEFT, 270, 15, Color("#f1e7d2"))

	_draw_icon_people(Vector2(302, 22), Color("#c9c0aa"))
	draw_string(font, Vector2(313, 27), "%d" % survivors, HORIZONTAL_ALIGNMENT_LEFT, 38, 12, Color("#d8cfba"))
	_draw_icon_ember(Vector2(375, 22), Color("#d99b50"))
	draw_string(font, Vector2(387, 27), "%d" % run_embers, HORIZONTAL_ALIGNMENT_LEFT, 32, 12, Color("#efc071"))

	draw_string(font, Vector2(14, 56), short_goal, HORIZONTAL_ALIGNMENT_LEFT, 252, 11, Color("#aebcaf"))

	_draw_icon_log(Vector2(286, 52), Color("#9f6b3c"))
	draw_string(font, Vector2(298, 56), "%d" % camp_wood, HORIZONTAL_ALIGNMENT_LEFT, 30, 11, Color("#d6c19a"))
	_draw_icon_stone(Vector2(342, 52), Color("#8f9996"))
	draw_string(font, Vector2(354, 56), "%d" % camp_stone, HORIZONTAL_ALIGNMENT_LEFT, 30, 11, Color("#ccd0ca"))
	_draw_icon_cargo(Vector2(403, 52), Color("#b6a57f"))
	var cargo := carried_wood + carried_stone
	draw_string(font, Vector2(415, 56), "%d/%d" % [cargo, carry_limit], HORIZONTAL_ALIGNMENT_LEFT, 52, 11, Color("#d9c39a"))

	if stage in [Stage.NIGHT1, Stage.NIGHT2, Stage.NIGHT3]:
		draw_rect(Rect2(Vector2(14, 70), Vector2(450, 5)), Color("#2b302b"))
		draw_rect(Rect2(Vector2(14, 70), Vector2(450.0 * clampf(hearth_hp / hearth_max_hp, 0.0, 1.0), 5)), Color("#d18c51"))
	elif area != Area.CAMP:
		draw_rect(Rect2(Vector2(14, 70), Vector2(450, 5)), Color("#2b302b"))
		draw_rect(Rect2(Vector2(14, 70), Vector2(450.0 * clampf(hero_hp / hero_max_hp, 0.0, 1.0), 5)), Color("#b86856"))


func _short_objective_text() -> String:
	match stage:
		Stage.DAY1_GATHER:
			if carried_wood > 0:
				return "Вернись к Очагу"
			if resource_pickups.size() > 0:
				return "Подбери брёвна"
			return "Сруби ближайшее дерево"
		Stage.DAY1_RESCUE:
			if area == Area.CAMP and day1_route == "":
				return "Выбери один путь до наступления темноты"
			if area == Area.HUNTER_TRAIL and not day1_route_complete:
				if enemies.size() > 0:
					return "Твари на тропе: %d" % enemies.size()
				return "Подойди к охотнику"
			if area == Area.SAWMILL and not sawmill_claimed:
				return "Запусти старую лесопилку"
			if area == Area.SAWMILL and enemies.size() > 0:
				return "Отбей нападение: %d" % enemies.size()
			if not day1_route_complete:
				return "Закончи начатое"
			return "Вернись к Последнему Очагу"
		Stage.NIGHT1: return "Защити огонь"
		Stage.DAY2_BUILD:
			if carried_wood + carried_stone > 0:
				return "Верни ресурсы в запас лагеря"
			return "Собери ресурсы для мастерской"
		Stage.WORKSHOP_CHOICE: return "Выбери развитие мастерской"
		Stage.DAY2_RESCUE:
			if area == Area.WORKER_RUINS and worker_route_complete:
				return "Вернись с рабочим к Очагу"
			if area == Area.WORKER_RUINS and enemies.size() > 0:
				return "Стражи у руин: %d" % enemies.size()
			if area == Area.WORKER_RUINS:
				return "Подойди к рабочему"
			return "Иди по следам к старой мастерской"
		Stage.NIGHT2: return "Защити Очаг от второй волны"
		Stage.DAY3_TOWER:
			if area == Area.CAMP and day3_route == "":
				return "Выбери последнюю подготовку"
			if area == Area.WATCH_RIDGE and not watch_repair_started:
				return "Восстанови старый дозор"
			if area == Area.ALTAR_GLADE and not final_altar_claimed:
				return "Пробуди древний алтарь"
			if enemies.size() > 0:
				return "Переживи нападение: %d" % enemies.size()
			if not day3_route_complete:
				return "Заверши выбранный путь"
			return "Вернись к Очагу"
		Stage.EXPEDITION_CHOICE: return "Выбери силу перед последней ночью"
		Stage.NIGHT3: return "Хранитель идёт за огнём"
		Stage.CORE_RETURN: return "Верни ядро Хранителя в Очаг"
	return ""


func _stage_title() -> String:
	match stage:
		Stage.DAY1_GATHER: return "ДЕНЬ 1 | разожги очаг"
		Stage.DAY1_RESCUE:
			if area == Area.HUNTER_TRAIL: return "ДЕНЬ 1 | тропа охотника"
			if area == Area.SAWMILL: return "ДЕНЬ 1 | старая лесопилка"
			return "ДЕНЬ 1 | выбери путь"
		Stage.NIGHT1: return "НОЧЬ 1"
		Stage.DAY2_BUILD: return "ДЕНЬ 2 | восстанови мастерскую"
		Stage.WORKSHOP_CHOICE: return "ДЕНЬ 2 | выбери развитие"
		Stage.DAY2_RESCUE:
			if area == Area.WORKER_RUINS: return "ДЕНЬ 2 | руины мастерской"
			return "ДЕНЬ 2 | след к руинам"
		Stage.NIGHT2: return "НОЧЬ 2"
		Stage.DAY3_TOWER:
			if area == Area.WATCH_RIDGE: return "ДЕНЬ 3 | сломанный дозор"
			if area == Area.ALTAR_GLADE: return "ДЕНЬ 3 | древний алтарь"
			return "ДЕНЬ 3 | последний выбор"
		Stage.EXPEDITION_CHOICE: return "ДЕНЬ 3 | древний алтарь"
		Stage.NIGHT3: return "НОЧЬ 3 | хранитель идёт"
		Stage.CORE_RETURN: return "ПОСЛЕ БОЯ | ядро хранителя"
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


func _wrap_story_lines(text: String, max_chars: int = 42) -> Array[String]:
	var explicit := text.split("\n")
	var result: Array[String] = []
	for part_variant: Variant in explicit:
		var part := String(part_variant)
		if part.length() <= max_chars:
			result.append(part)
			continue
		var words := part.split(" ")
		var line := ""
		for word_variant: Variant in words:
			var word := String(word_variant)
			var candidate := word if line == "" else line + " " + word
			if candidate.length() > max_chars and line != "":
				result.append(line)
				line = word
			else:
				line = candidate
		if line != "":
			result.append(line)
	return result


func _draw_story_card() -> void:
	if story_hint_timer <= 0.0 or story_hint == "":
		return
	var lines := _wrap_story_lines(story_hint, 44)
	var count := mini(lines.size(), 3)
	var height := 30.0 + float(count) * 18.0
	var y := 94.0
	draw_rect(Rect2(Vector2(48, y), Vector2(384, height)), Color(0.015, 0.025, 0.020, 0.88))
	draw_rect(Rect2(Vector2(48, y), Vector2(4, height)), Color("#c18d50"))
	for i in range(count):
		var color := Color("#ead7ae") if i == 0 else Color("#c8d1c8")
		var size := 12 if i == 0 else 11
		draw_string(font, Vector2(64, y + 25.0 + float(i) * 18.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, 350, size, color)


func _draw_hub_feedback() -> void:
	if mode != Mode.HUB or hub_feedback_timer <= 0.0 or hub_feedback_text == "":
		return
	var pos := hub_feedback_pos
	var box := Rect2(pos + Vector2(-78, -77), Vector2(156, 30))
	draw_rect(box, Color(0.02, 0.03, 0.025, 0.90))
	draw_string(font, box.position + Vector2(6, 20), hub_feedback_text, HORIZONTAL_ALIGNMENT_CENTER, 144, 10, Color("#f0d7a1"))


func _draw_region_map_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.005, 0.012, 0.009, 0.76))
	draw_rect(Rect2(Vector2(28, 176), Vector2(424, 390)), Color("#15231c"))
	draw_string(font, Vector2(50, 220), "КАРТА ОКРЕСТНОСТЕЙ", HORIZONTAL_ALIGNMENT_CENTER, 380, 20, Color("#f2e5cf"))
	draw_string(font, Vector2(60, 250), "Выбери путь", HORIZONTAL_ALIGNMENT_CENTER, 360, 11, Color("#9eafa3"))

	var forest_rect := Rect2(Vector2(50, 292), Vector2(172, 150))
	var dead_rect := Rect2(Vector2(258, 292), Vector2(172, 150))
	draw_rect(forest_rect, Color("#21352a"))
	draw_rect(dead_rect, Color("#1c2723"))
	draw_rect(Rect2(forest_rect.position, Vector2(forest_rect.size.x, 4)), Color("#83a070"))
	draw_rect(Rect2(dead_rect.position, Vector2(dead_rect.size.x, 4)), Color("#665a51"))

	draw_circle(Vector2(136, 345), 28.0, Color(0.23, 0.43, 0.27, 0.85))
	for i in range(5):
		var a := TAU * float(i) / 5.0
		draw_circle(Vector2(136, 345) + Vector2(cos(a), sin(a)) * 20.0, 7.0, Color("#34593a"))
	draw_string(font, Vector2(61, 391), "ЗАБЫТЫЙ ЛЕС", HORIZONTAL_ALIGNMENT_CENTER, 150, 12, Color("#e6dbc6"))
	draw_string(font, Vector2(61, 411), "ОЧИЩЕН | ПОВТОРИТЬ", HORIZONTAL_ALIGNMENT_CENTER, 150, 9, Color("#9fbea2"))

	draw_circle(Vector2(344, 345), 30.0, Color(0.18, 0.17, 0.15, 0.88))
	draw_line(Vector2(322, 355), Vector2(365, 330), Color("#55483d"), 5.0)
	draw_circle(Vector2(356, 336), 5.0, Color("#b87845"))
	draw_string(font, Vector2(269, 391), "МЁРТВЫЕ ПОЛЯ", HORIZONTAL_ALIGNMENT_CENTER, 150, 12, Color("#d7ccbc"))
	draw_string(font, Vector2(269, 411), "СЛЕДУЮЩАЯ ГЛАВА", HORIZONTAL_ALIGNMENT_CENTER, 150, 9, Color("#897e74"))
	draw_string(font, Vector2(68, 518), "Коснись вне карты, чтобы закрыть", HORIZONTAL_ALIGNMENT_CENTER, 344, 10, Color("#839187"))


func _draw_enemy_deaths() -> void:
	for death: Dictionary in enemy_deaths:
		var life := float(death.get("life", 0.0))
		var max_life := maxf(0.01, float(death.get("max_life", 0.34)))
		var alpha := clampf(life / max_life, 0.0, 1.0)
		var pos: Vector2 = death["pos"]
		var radius := float(death.get("radius", 14.0))
		draw_circle(pos, radius * (1.0 + (1.0 - alpha) * 0.25), Color(0.18, 0.14, 0.17, 0.28 * alpha))
		for i in range(5):
			var a := TAU * float(i) / 5.0 + (1.0 - alpha)
			var p := pos + Vector2(cos(a), sin(a)) * radius * (1.0 + (1.0 - alpha))
			draw_circle(p, 2.5, Color(0.32, 0.23, 0.28, 0.45 * alpha))


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


func _run_choice_line(day: int) -> String:
	if day == 1:
		if day1_route == "hunter": return "ДЕНЬ 1  •  Охотник спасён"
		if day1_route == "sawmill": return "ДЕНЬ 1  •  Лесопилка укреплена"
		return "ДЕНЬ 1  •  путь не завершён"
	if day == 2:
		if workshop_choice == "armory": return "ДЕНЬ 2  •  Оружейная"
		if workshop_choice == "lumber": return "ДЕНЬ 2  •  Лесопилка"
		return "ДЕНЬ 2  •  мастерская не выбрана"
	if day3_route == "watch": return "ДЕНЬ 3  •  Дозор восстановлен"
	if day3_route == "altar": return "ДЕНЬ 3  •  Огненные стрелы"
	return "ДЕНЬ 3  •  путь не завершён"


func _draw_result_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.005, 0.012, 0.009, 0.86))
	var panel := Rect2(Vector2(30, 185), Vector2(420, 420))
	draw_rect(panel, Color("#16231c"))
	draw_rect(Rect2(panel.position, Vector2(panel.size.x, 5)), Color("#d29550") if result_win else Color("#824842"))

	draw_string(font, Vector2(50, 235), result_title, HORIZONTAL_ALIGNMENT_CENTER, 380, 20, Color("#f4e6ce"))

	if result_win:
		var distant := Vector2(240, 278)
		draw_circle(distant, 18.0, Color(0.93, 0.55, 0.22, 0.08))
		draw_circle(distant, 8.0, Color("#d77e38"))
		var flame := PackedVector2Array([
			distant + Vector2(0, -12), distant + Vector2(7, 4),
			distant + Vector2(0, 10), distant + Vector2(-7, 4)
		])
		draw_colored_polygon(flame, Color("#f2b14e"))
		draw_string(font, Vector2(62, 315), "ГДЕ-ТО ЕЩЁ ГОРИТ ОГОНЬ", HORIZONTAL_ALIGNMENT_CENTER, 356, 12, Color("#e7cf9b"))
		draw_string(font, Vector2(62, 336), "Следующий путь: Мёртвые поля", HORIZONTAL_ALIGNMENT_CENTER, 356, 11, Color("#a9b9aa"))
	else:
		draw_string(font, Vector2(62, 296), "Огонь погас, но поселение помнит этот поход.", HORIZONTAL_ALIGNMENT_CENTER, 356, 11, Color("#b8c7bb"))
		draw_string(font, Vector2(62, 318), "Постоянные улучшения и найденные угли сохранены.", HORIZONTAL_ALIGNMENT_CENTER, 356, 11, Color("#b8c7bb"))

	draw_string(font, Vector2(62, 374), "ТВОЯ ИСТОРИЯ ЭТОЙ ВЫЛАЗКИ", HORIZONTAL_ALIGNMENT_CENTER, 356, 11, Color("#d7bc86"))
	for i in range(3):
		draw_string(font, Vector2(84, 402 + i * 23), _run_choice_line(i + 1), HORIZONTAL_ALIGNMENT_LEFT, 320, 11, Color("#b9c5ba"))

	draw_string(font, Vector2(62, 478), "УГЛИ ЗА ВЫЛАЗКУ  +%d" % run_embers, HORIZONTAL_ALIGNMENT_CENTER, 356, 14, Color("#ecc178"))

	if result_win:
		draw_string(font, Vector2(62, 509), "Забытый лес очищен. Но ответы только начались.", HORIZONTAL_ALIGNMENT_CENTER, 356, 11, Color("#9eb09f"))
	else:
		draw_string(font, Vector2(62, 509), "Следующая попытка может пойти по другому пути.", HORIZONTAL_ALIGNMENT_CENTER, 356, 11, Color("#9eb09f"))

	draw_rect(Rect2(Vector2(93, 544), Vector2(294, 42)), Color("#2a382e"))
	draw_string(font, Vector2(105, 570), "КОСНИСЬ | ВЕРНУТЬСЯ К ОЧАГУ", HORIZONTAL_ALIGNMENT_CENTER, 270, 11, Color("#f0d7a1"))


func _draw_ellipse_custom(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
