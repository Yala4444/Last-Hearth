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

	game.dev_mode = true
	game.meta["forest_fires"] = 3
	game.meta["embers"] = 41
	game.meta["forest_cleared"] = true
	var snapshot: Dictionary = game.meta.duplicate(true)

	game._start_dev_expedition(0)
	if not game.dev_test_run or game.expedition_sector != 0:
		fail("Developer replay did not start sector 1")
		return
	if game.meta != snapshot:
		fail("Developer replay changed meta before the test even finished")
		return

	game.run_embers = 99
	game._finish_run(true)
	if game.dev_test_run:
		fail("Developer replay flag was not cleared after finish")
		return
	if game.meta != snapshot:
		fail("Developer replay changed canonical save/meta progress")
		return
	if game.result_title != "ТЕСТ ЗАВЕРШЁН":
		fail("Developer replay did not use the isolated test result")
		return

	game.mode = game.Mode.HUB
	game._configure_expedition_sector(1)
	if game.expedition_sector != 1 or game._forest_final_enemy_kind() != "rootborn":
		fail("Developer sector 2 replay mapping is wrong")
		return
	game._configure_expedition_sector(2)
	if game.expedition_sector != 2 or game._forest_final_enemy_kind() != "forest_guardian":
		fail("Developer sector 3 replay mapping is wrong")
		return

	if game._dev_test_button_rect(3).size.x < 300:
		fail("Enemy showcase touch target is too small for mobile review")
		return

	print("V018_DEV_REPLAY_SANITY_OK")
	quit(0)
