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

	# Day 1 still advances at exactly five delivered logs.
	game.stage = 0
	game.camp_wood = 5
	game.camp_stone = 0
	game.carried_wood = 0
	game.current_stage_wood_start = 0
	game.current_stage_stone_start = 0
	game.stage_transition_lock = false
	game._check_day_progress()
	if int(game.stage) != 1 or int(game.camp_wood) != 0 or int(game.hearth_level) != 2:
		fail("Day 1 progression sanity failed")
		return

	# Rescue/night/choice phases must not allow fresh harvesting.
	game.stage = 1
	if bool(game._gathering_enabled()):
		fail("Harvesting must be disabled during rescue")
		return
	game.stage = 2
	if bool(game._gathering_enabled()):
		fail("Harvesting must be disabled at night")
		return
	game.stage = 4
	if bool(game._gathering_enabled()):
		fail("Harvesting must be disabled during workshop choice")
		return

	# Carried resources count toward the current need, preventing over-farming.
	game.stage = 0
	game.camp_wood = 0
	game.carried_wood = 5
	if bool(game._resource_kind_needed("tree")):
		fail("Day 1 allowed over-farming while enough wood was already carried")
		return

	# Day 2 must NOT auto-build from stock collected before the stage began.
	game.stage = 3
	game.current_stage_wood_start = 10
	game.current_stage_stone_start = 7
	game.camp_wood = 10
	game.camp_stone = 7
	game.carried_wood = 0
	game.carried_stone = 0
	game.workshop_built = false
	game.stage_transition_lock = false
	game._check_day_progress()
	if int(game.stage) != 3 or bool(game.workshop_built):
		fail("Workshop incorrectly consumed pre-farmed stock")
		return

	# Only eight new wood and five new stone complete the workshop; old stock survives.
	game.camp_wood = 18
	game.camp_stone = 12
	game._check_day_progress()
	if int(game.stage) != 4 or not bool(game.workshop_built):
		fail("Workshop stage progression failed after fresh resources")
		return
	if int(game.camp_wood) != 10 or int(game.camp_stone) != 7:
		fail("Workshop did not preserve pre-existing stock")
		return

	# Day 3 follows the same rule and still covers the old 6/6 soft-lock case.
	game.stage = 7
	game.current_stage_wood_start = 4
	game.current_stage_stone_start = 3
	game.camp_wood = 4
	game.camp_stone = 3
	game.tower_built = false
	game.stage_transition_lock = false
	game._check_day_progress()
	if int(game.stage) != 7 or bool(game.tower_built):
		fail("Tower incorrectly consumed pre-farmed stock")
		return

	game.camp_wood = 10
	game.camp_stone = 9
	game._check_day_progress()
	if int(game.stage) != 8 or not bool(game.tower_built):
		fail("Tower 6/6 progression sanity failed")
		return
	if int(game.camp_wood) != 4 or int(game.camp_stone) != 3:
		fail("Tower did not preserve pre-existing stock")
		return

	# Hero can never occupy the hearth center.
	game.hero_pos = game.HEARTH_POS
	game.hero_target = game.HEARTH_POS
	game.hearth_level = 4
	game._keep_hero_out_of_hearth()
	if game.hero_pos.distance_to(game.HEARTH_POS) < 60.0:
		fail("Hero-hearth separation sanity failed")
		return

	print("PROGRESSION_SANITY_OK")
	quit(0)
