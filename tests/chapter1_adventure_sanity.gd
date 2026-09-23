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
	game.meta["forest_fires"] = 0
	game._start_expedition()

	# One teaching tree (three logs) should unlock the first exploration decision fast.
	game.stage = game.Stage.DAY1_GATHER
	game.camp_wood = game.FIELD_FIRE_WOOD_COST
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
	if float(game.hero_pos.x) < 400.0 or float(game.route_return_gate_pos.x) < 400.0:
		fail("Leaving camp to the left must enter the route from the right edge")
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

	game.hero_pos = game.route_return_gate_pos
	game._update_area_transitions()
	if int(game.area) != int(game.Area.CAMP):
		fail("Hunter route did not return to camp")
		return
	if int(game.stage) != int(game.Stage.NIGHT1):
		fail("Returning from hunter route did not start Night 1")
		return
	if float(game.hero_pos.x) > 120.0:
		fail("Returning from the hunter route did not re-enter camp from the left")
		return

	# Sawmill branch gives a different payoff and does not add the hunter.
	game._start_expedition()
	game.stage = game.Stage.DAY1_RESCUE
	game._enter_day1_route("sawmill")
	if int(game.area) != int(game.Area.SAWMILL):
		fail("Sawmill route did not load")
		return
	if float(game.hero_pos.x) > 80.0:
		fail("Leaving camp to the right must enter the sawmill from the left edge")
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

	# Route enemies must fight the explorer, never an invisible Hearth in the middle of the map.
	var guidance: Dictionary = game._guidance_info()
	if String(guidance.get("text", "")) != "СТРАЖИ":
		fail("Worker ruins guidance does not prioritize the active guards")
		return
	var hearth_before_route_hit := float(game.hearth_hp)
	var hero_before_route_hit := float(game.hero_hp)
	game.route_grace_timer = 0.0
	game.enemies[0]["pos"] = game.hero_pos + Vector2(8.0, 0.0)
	game.enemies[0]["hit_cd"] = 0.0
	game._update_enemies(0.1)
	if float(game.hearth_hp) != hearth_before_route_hit:
		fail("Route enemy damaged the invisible camp Hearth")
		return
	if float(game.hero_hp) >= hero_before_route_hit:
		fail("Route enemy failed to damage the explorer")
		return

	game.enemies.clear()
	game.hero_pos = game.survivor_two_pos
	game._update_worker_route()
	if not bool(game.worker_clear_announced):
		fail("Worker ruins did not announce that the encounter was cleared")
		return
	if bool(game.worker_route_complete):
		fail("Worker rescue completed before the reveal beat")
		return
	game._update_worker_route()
	if not bool(game.worker_route_complete):
		fail("Worker rescue did not complete")
		return
	if int(game.survivors) < 2:
		fail("Worker did not join the group")
		return

	game.hero_pos = game.route_return_gate_pos
	game._update_area_transitions()
	if int(game.area) != int(game.Area.CAMP):
		fail("Worker route did not return to camp")
		return
	if int(game.stage) != int(game.Stage.DAY2_BUILD) or bool(game.workshop_built):
		fail("Worker return must start the workshop construction phase")
		return
	var build_wood_start := int(game.current_stage_wood_start)
	var build_stone_start := int(game.current_stage_stone_start)
	game.camp_wood = build_wood_start + game.WORKSHOP_WOOD_COST
	game.camp_stone = build_stone_start + game.WORKSHOP_STONE_COST
	game._check_day_progress()
	if int(game.stage) != int(game.Stage.WORKSHOP_CHOICE) or not bool(game.workshop_built):
		fail("Fresh materials did not finish the workshop")
		return


	# Day 3 is now another consequential route choice instead of a 6/6 gather gate.
	game.stage = game.Stage.NIGHT2
	game._complete_night_two()
	if int(game.stage) != int(game.Stage.DAY3_TOWER):
		fail("Night 2 did not advance to final preparation")
		return
	if game.day3_route != "":
		fail("Final preparation route was preselected")
		return

	game._enter_day3_route("watch")
	if int(game.area) != int(game.Area.WATCH_RIDGE):
		fail("Watch route did not load")
		return
	game.watch_repair_started = true
	game.enemies.clear()
	game._update_day3_route()
	if not bool(game.day3_route_complete) or not bool(game.tower_built):
		fail("Watch route did not rebuild the tower")
		return
	game.hero_pos = game.route_return_gate_pos
	game._update_area_transitions()
	if int(game.area) != int(game.Area.CAMP) or int(game.stage) != int(game.Stage.NIGHT3):
		fail("Watch route did not return into Night 3")
		return

	game._start_expedition()
	game.stage = game.Stage.DAY3_TOWER
	game._enter_day3_route("altar")
	if int(game.area) != int(game.Area.ALTAR_GLADE):
		fail("Altar route did not load")
		return
	var damage_before := float(game.hero_damage)
	game.final_altar_claimed = true
	game.enemies.clear()
	game._update_day3_route()
	if not bool(game.day3_route_complete) or float(game.hero_damage) <= damage_before:
		fail("Altar route did not grant the offensive payoff")
		return

	# A completed run restores one regional signal without falsely unlocking the next chapter.
	game.mode = game.Mode.EXPEDITION
	game.meta["forest_fires"] = 0
	game.meta["forest_cleared"] = false
	game.meta["rescued_hunter"] = false
	game.meta["rescued_worker"] = false
	game.meta["watch_restored"] = false
	game.day1_route = "hunter"
	game.survivor_two_found = true
	game.day3_route = "watch"
	game.run_embers = 0
	game._finish_run(true)
	if int(game.meta.get("forest_fires", 0)) != 1:
		fail("A successful run did not restore exactly one forest fire")
		return
	if bool(game.meta.get("forest_cleared", false)):
		fail("Dead Fields must not unlock after only one restored fire")
		return
	if not bool(game.meta.get("rescued_hunter", false)) or not bool(game.meta.get("rescued_worker", false)):
		fail("People rescued during a successful run were not persisted into the Last Hearth")
		return
	if not bool(game.meta.get("watch_restored", false)):
		fail("Restored watch was not persisted into the Last Hearth")
		return

	print("CHAPTER1_ADVENTURE_SANITY_OK")
	quit(0)
