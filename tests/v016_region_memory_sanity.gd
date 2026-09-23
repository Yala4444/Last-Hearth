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

	# Discovery model: future fires must remain absent until the previous progress reveals them.
	game.meta["forest_fires"] = 1
	game.meta["forest_fire_1_state"] = "unknown"
	game.meta["forest_fire_2_state"] = "unknown"
	game.meta["forest_fire_3_state"] = "unknown"
	game._sync_forest_discovery_from_progress()
	if game._forest_fire_state(1) != "restored":
		fail("Fire 1 was not restored at 1/3")
		return
	if game._forest_fire_state(2) != "seen":
		fail("Fire 2 was not revealed as the next signal at 1/3")
		return
	if game._forest_fire_state(3) != "unknown":
		fail("Fire 3 leaked onto the map before discovery")
		return

	game.meta["forest_fires"] = 2
	game._sync_forest_discovery_from_progress()
	if game._forest_fire_state(1) != "restored" or game._forest_fire_state(2) != "restored":
		fail("First two fires were not restored at 2/3")
		return
	if game._forest_fire_state(3) != "seen":
		fail("Fire 3 was not revealed at 2/3")
		return

	game.meta["forest_fires"] = 3
	game._sync_forest_discovery_from_progress()
	for index in range(1, 4):
		if game._forest_fire_state(index) != "restored":
			fail("All fires should be restored at 3/3")
			return

	# Character fates: local keepers do not unlock homes.
	game.meta["hunter_fate"] = "keeper_fire_1"
	game.meta["master_relationship_state"] = "waiting_forest"
	game.meta["worker_home_built"] = false
	if game._hub_build_sites().size() != 0:
		fail("Local keepers or waiting chapter NPCs created hub homes")
		return

	game.meta["master_relationship_state"] = "joining_home"
	var sites = game._hub_build_sites()
	if sites.size() != 1 or String(sites[0]["id"]) != "worker_home":
		fail("Master joining state did not unlock his home")
		return

	# Completing the first forest expedition records the Hunter as a local keeper
	# and the Master as a chapter relationship rather than instant residents.
	game.mode = game.Mode.EXPEDITION
	game.meta["forest_fires"] = 0
	game.meta["forest_fire_1_state"] = "seen"
	game.meta["forest_fire_2_state"] = "unknown"
	game.meta["forest_fire_3_state"] = "unknown"
	game.day1_route = "hunter"
	game.survivor_one_found = true
	game.day2_mission = "worker"
	game.survivor_two_found = true
	game.run_embers = 0
	game._finish_run(true)
	if String(game.meta.get("hunter_fate", "")) != "keeper_fire_1":
		fail("Hunter did not become keeper of Fire 1")
		return
	if String(game.meta.get("forest_fire_1_keeper", "")) != "Охотник":
		fail("Fire 1 did not remember its keeper")
		return
	if String(game.meta.get("master_relationship_state", "")) != "waiting_forest":
		fail("Master became a hub resident too early")
		return
	if game._forest_fire_state(2) != "seen" or game._forest_fire_state(3) != "unknown":
		fail("Completing Fire 1 revealed too much of the map")
		return

	# Fire 2 temporarily remembers the Master as its keeper so the middle chapter has continuity.
	game.mode = game.Mode.EXPEDITION
	game.meta["forest_fires"] = 1
	game.meta["master_relationship_state"] = "waiting_forest"
	game.meta["forest_fire_2_keeper"] = ""
	game.run_embers = 0
	game._finish_run(true)
	if String(game.meta.get("forest_fire_2_keeper", "")) != "Мастер":
		fail("Fire 2 did not remember the Master as its temporary keeper")
		return
	if "Мастер" not in game._forest_fire_detail(2):
		fail("Fire 2 map detail does not explain where the Master stayed")
		return

	# Three completed fires resolve the chapter and allow the Master to join.
	game.mode = game.Mode.EXPEDITION
	game.meta["forest_fires"] = 2
	game.meta["master_relationship_state"] = "waiting_forest"
	game.meta["forest_fire_2_keeper"] = "Мастер"
	game.run_embers = 0
	game._finish_run(true)
	if String(game.meta.get("master_relationship_state", "")) != "joining_home":
		fail("Master did not choose the Last Hearth after 3/3")
		return
	if String(game.meta.get("forest_fire_2_keeper", "")) != "":
		fail("Master stayed assigned to Fire 2 after choosing the Last Hearth")
		return
	if game._forest_fire_state(3) != "restored":
		fail("Final forest fire did not persist as restored")
		return

	game.expedition_sector = 1
	game.meta["hunter_fate"] = "keeper_fire_1"
	if "Охотник" not in game._forest_chapter_intro():
		fail("Second expedition intro did not reference the Hunter keeping Fire 1")
		return
	game.expedition_sector = 2
	game.meta["master_relationship_state"] = "waiting_forest"
	if "Мастер" not in game._forest_chapter_intro():
		fail("Third expedition intro did not connect the Master's chapter arc")
		return

	# Hearth Book is multi-page and no longer closes on any random tap.
	game.help_open = true
	game.hearth_book_page = 0
	game._handle_hearth_book_press(Vector2(380, 630))
	if game.hearth_book_page != 1 or not game.help_open:
		fail("Hearth Book did not advance to the next page")
		return
	game._handle_hearth_book_press(Vector2(240, 630))
	if game.help_open:
		fail("Hearth Book close control did not close the codex")
		return

	# Binary choices have separate left/right safe anchors around the fire.
	if absf(game.left_choice_pos.x - game.right_choice_pos.x) < 180.0:
		fail("Choice cards are still too close and can overlap")
		return
	if game.left_choice_pos.y < 440.0 or game.right_choice_pos.y < 440.0:
		fail("Choice cards are still occupying the top narrative lane")
		return

	print("V016_REGION_MEMORY_SANITY_OK")
	quit(0)
