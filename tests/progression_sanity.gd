extends SceneTree

func _init() -> void:
	var packed: PackedScene = load("res://main.tscn")
	if packed == null:
		push_error("Could not load main scene")
		quit(1)
		return

	var game = packed.instantiate()
	root.add_child(game)
	await process_frame

	# Day 1: exact requirement must advance once and consume exactly 5 wood.
	game.stage = 0
	game.camp_wood = 5
	game.camp_stone = 0
	game.stage_transition_lock = false
	game._check_day_progress()
	if int(game.stage) != 1 or int(game.camp_wood) != 0 or int(game.hearth_level) != 2:
		push_error("Day 1 progression sanity failed")
		quit(1)
		return

	# Day 2: pre-stocked resources must build the workshop even without a new deposit.
	game.stage = 3
	game.camp_wood = 10
	game.camp_stone = 7
	game.workshop_built = false
	game.stage_transition_lock = false
	game._check_day_progress()
	if int(game.stage) != 4 or not bool(game.workshop_built):
		push_error("Workshop progression sanity failed")
		quit(1)
		return
	if int(game.camp_wood) != 2 or int(game.camp_stone) != 2:
		push_error("Workshop overstock preservation failed")
		quit(1)
		return

	# Day 3: the exact soft-lock case from mobile testing must always advance.
	game.stage = 7
	game.camp_wood = 6
	game.camp_stone = 6
	game.tower_built = false
	game.stage_transition_lock = false
	game._check_day_progress()
	if int(game.stage) != 8 or not bool(game.tower_built):
		push_error("Tower 6/6 progression sanity failed")
		quit(1)
		return
	if int(game.camp_wood) != 0 or int(game.camp_stone) != 0:
		push_error("Tower resource consumption failed")
		quit(1)
		return

	print("PROGRESSION_SANITY_OK")
	quit(0)
