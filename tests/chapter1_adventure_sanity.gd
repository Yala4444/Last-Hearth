extends SceneTree

func fail(message: String) -> void:
	push_error(message)
	quit(1)


func _init() -> void:
	var packed: PackedScene = load("res://main.tscn")
	if packed == null:
		fail("Could not load main scene")
		return

	var game = packed.instantiate()
	root.add_child(game)
	await process_frame

	game.meta["attempts"] = 1
	game._start_expedition()

	# Five logs should still unlock the exploration decision.
	game.stage = game.Stage.DAY1_GATHER
	game.camp_wood = 5
	game.carried_wood = 0
	game.stage_transition_lock = false
	game._check_day_progress()
	if int(game.stage) != int(game.Stage.DAY1_RESCUE):
		fail("Day 1 did not advance into route choice")
		return
	if int(game.area) != int(game.Area.CAMP):
		fail("Route choice must begin in camp")
		return
	if game.day1_route != "":
		fail("Route must not be preselected")
		return

	# Hunter branch must be a separate area with enemies and a survivor objective.
	game._enter_day1_route("hunter")
	if int(game.area) != int(game.Area.HUNTER_TRAIL):
		fail("Hunter route did not load")
		return
	if game.day1_route != "hunter":
		fail("Hunter route was not locked")
		return
	if game.enemies.size() < 3:
		fail("Hunter route lacks the rescue encounter")
		return

	game.enemies.clear()
	game.hero_pos = game.survivor_one_pos
	game._update_day1_route()
	if not bool(game.day1_route_complete):
		fail("Hunter rescue did not complete")
		return
	if int(game.survivors) < 2:
		fail("Hunter did not join the group")
		return

	game.hero_pos = game.ROUTE_RETURN_GATE
	game._update_area_transitions()
	if int(game.area) != int(game.Area.CAMP):
		fail("Hunter route did not return to camp")
		return
	if int(game.stage) != int(game.Stage.NIGHT1):
		fail("Returning from hunter route did not start Night 1")
		return

	# Sawmill branch gives a different payoff and does not add the hunter.
	game._start_expedition()
	game.stage = game.Stage.DAY1_RESCUE
	game._enter_day1_route("sawmill")
	if int(game.area) != int(game.Area.SAWMILL):
		fail("Sawmill route did not load")
		return
	var before_carry := int(game.carry_limit)
	var before_hp := float(game.hearth_max_hp)
	game.sawmill_claimed = true
	game.enemies.clear()
	game._update_day1_route()
	if not bool(game.day1_route_complete):
		fail("Sawmill route did not complete")
		return
	if int(game.carry_limit) != before_carry + 1:
		fail("Sawmill route did not grant carry bonus")
		return
	if float(game.hearth_max_hp) <= before_hp:
		fail("Sawmill route did not fortify the hearth")
		return


	# After Night 1, normal play now points toward the worker ruins instead of another resource grind.
	game._start_expedition()
	game.stage = game.Stage.DAY1_RESCUE
	game.day1_route = "hunter"
	game.day1_route_complete = true
	game.area = game.Area.CAMP
	game._complete_night_one()
	if int(game.stage) != int(game.Stage.DAY2_RESCUE):
		fail("Night 1 did not advance to worker rescue")
		return

	game._enter_worker_ruins()
	if int(game.area) != int(game.Area.WORKER_RUINS):
		fail("Worker ruins did not load")
		return
	if game.enemies.size() < 4:
		fail("Worker ruins lack the rescue encounter")
		return

	game.enemies.clear()
	game.hero_pos = game.survivor_two_pos
	game._update_worker_route()
	if not bool(game.worker_route_complete):
		fail("Worker rescue did not complete")
		return
	if int(game.survivors) < 2:
		fail("Worker did not join the group")
		return

	game.hero_pos = game.ROUTE_RETURN_GATE
	game._update_area_transitions()
	if int(game.area) != int(game.Area.CAMP):
		fail("Worker route did not return to camp")
		return
	if int(game.stage) != int(game.Stage.WORKSHOP_CHOICE) or not bool(game.workshop_built):
		fail("Worker return did not restore the workshop")
		return

	print("CHAPTER1_ADVENTURE_SANITY_OK")
	quit(0)
