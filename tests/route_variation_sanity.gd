extends SceneTree

func fail(message: String) -> void:
	push_error(message)
	quit(1)


func contains_pair(a: String, b: String, x: String, y: String) -> bool:
	return (a == x and b == y) or (a == y and b == x)


func _init() -> void:
	var packed: PackedScene = load("res://main.tscn")
	if packed == null:
		fail("Could not load main scene")
		return

	var game = packed.instantiate()
	root.add_child(game)
	await process_frame

	# Sector 1 is the readable tutorial promise.
	game.meta["forest_fires"] = 0
	game._start_expedition()
	if game.expedition_sector != 0:
		fail("First forest sector index is wrong")
		return
	if game.day1_left_offer != "hunter" or game.day1_right_offer != "sawmill":
		fail("Tutorial sector lost its clear hunter/sawmill choice")
		return
	if game.day2_mission != "worker":
		fail("Tutorial sector lost the worker rescue")
		return

	# The second signal must be a materially different run, not hunter/sawmill again.
	game.meta["forest_fires"] = 1
	game._start_expedition()
	if game.expedition_sector != 1:
		fail("Second forest sector index is wrong")
		return
	if not contains_pair(game.day1_left_offer, game.day1_right_offer, "caravan", "nest"):
		fail("Second sector did not offer caravan versus nest")
		return
	if game.day2_mission != "storehouse":
		fail("Second sector did not switch Day 2 to the storehouse")
		return
	if not contains_pair(game.day3_left_offer, game.day3_right_offer, "barricade", "shrine"):
		fail("Second sector final choice is not varied")
		return

	# The safer branch in sector two must visibly provide a companion; the nest is the solo damage gamble.
	game.stage = game.Stage.DAY1_RESCUE
	game.area = game.Area.CAMP
	game.day1_route = ""
	game.day1_left_offer = "caravan"
	game.day1_right_offer = "nest"
	game._enter_day1_route("caravan")
	for i in range(game.events.size()):
		if String(game.events[i].get("kind", "")) == "wagon":
			var event: Dictionary = game.events[i]
			event["triggered"] = true
			game.events[i] = event
	game.enemies.clear()
	var survivors_before := int(game.survivors)
	game._update_day1_route()
	if int(game.survivors) != survivors_before + 1:
		fail("Caravan route did not provide the advertised ally")
		return

	# Spatial continuity still applies whichever side the randomized offer lands on.
	game._start_expedition()
	game.meta["forest_fires"] = 1
	game._configure_expedition_sector()
	var chosen_left: String = String(game.day1_left_offer)
	game.stage = game.Stage.DAY1_RESCUE
	game.area = game.Area.CAMP
	game.day1_route = ""
	game._enter_day1_route(chosen_left)
	if int(game.area) != int(game.Area.HUNTER_TRAIL):
		fail("Left dynamic route did not use the left connected area")
		return
	if float(game.hero_pos.x) < 400.0:
		fail("Left dynamic route did not enter from the opposite edge")
		return

	# The storehouse route replaces the repeated worker/build loop and proceeds straight to Night 2.
	game._start_expedition()
	game.expedition_sector = 1
	game.day2_mission = "storehouse"
	game.stage = game.Stage.DAY2_RESCUE
	game.area = game.Area.CAMP
	game.worker_route_complete = false
	game._enter_worker_ruins()
	for i in range(game.events.size()):
		if String(game.events[i].get("kind", "")) == "supply_cache":
			var event: Dictionary = game.events[i]
			event["triggered"] = true
			game.events[i] = event
	game.enemies.clear()
	game.worker_clear_announced = true
	game.hero_pos = game.survivor_two_pos
	game._update_worker_route()
	if not bool(game.worker_route_complete):
		fail("Storehouse mission did not complete")
		return
	game.hero_pos = game.route_return_gate_pos
	game._update_area_transitions()
	if int(game.stage) != int(game.Stage.NIGHT2):
		fail("Storehouse mission incorrectly repeated the workshop construction phase")
		return

	# The third signal changes the run again.
	game.meta["forest_fires"] = 2
	game._start_expedition()
	if game.expedition_sector != 2:
		fail("Third forest sector index is wrong")
		return
	if not contains_pair(game.day1_left_offer, game.day1_right_offer, "signal", "dead_fire"):
		fail("Third sector did not offer signal versus dead fire")
		return
	if game.day2_mission != "scout":
		fail("Third sector did not switch Day 2 to the scout rescue")
		return
	if not contains_pair(game.day3_left_offer, game.day3_right_offer, "beacon", "cache"):
		fail("Third sector final choice is not varied")
		return

	print("ROUTE_VARIATION_SANITY_OK")
	quit(0)
