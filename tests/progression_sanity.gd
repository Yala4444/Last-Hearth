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

	# v0.9 removes the old Day 3 6/6 resource gate entirely.
	game.stage = 7
	game.day3_route = ""
	game.current_stage_wood_start = 4
	game.current_stage_stone_start = 3
	game.camp_wood = 20
	game.camp_stone = 20
	game.tower_built = false
	game.stage_transition_lock = false
	game._check_day_progress()
	if int(game.stage) != 7 or bool(game.tower_built):
		fail("Day 3 resources should not auto-build the tower in v0.9")
		return
	if bool(game._gathering_enabled()):
		fail("Day 3 should no longer be a gathering phase")
		return

	# Hero can never occupy the hearth center.
	game.hero_pos = game.HEARTH_POS
	game.hero_target = game.HEARTH_POS
	game.hearth_level = 4
	game._keep_hero_out_of_hearth()
	if game.hero_pos.distance_to(game.HEARTH_POS) < 60.0:
		fail("Hero-hearth separation sanity failed")
		return


	# Sprint 1 production assets must all import as textures.
	var asset_paths: Array[String] = [
		"res://assets/v08/sprint1/hero_idle.svg",
		"res://assets/v08/sprint1/hero_walk.svg",
		"res://assets/v08/sprint1/hero_attack.svg",
		"res://assets/v08/sprint1/hero_carry_1.svg",
		"res://assets/v08/sprint1/hero_carry_2.svg",
		"res://assets/v08/sprint1/hero_carry_3.svg",
		"res://assets/v08/sprint1/tree_a.svg",
		"res://assets/v08/sprint1/tree_b.svg",
		"res://assets/v08/sprint1/tree_c.svg",
		"res://assets/v08/sprint1/tree_falling.svg",
		"res://assets/v08/sprint1/stump.svg",
		"res://assets/v08/sprint1/log.svg",
		"res://assets/v08/sprint1/hearth_1.svg",
		"res://assets/v08/sprint1/hearth_2.svg",
		"res://assets/v08/sprint1/rock.svg",
		"res://assets/v08/sprint1/grass.svg"
	]
	for asset_path: String in asset_paths:
		var texture: Resource = load(asset_path)
		if texture == null:
			fail("Visual asset failed to import: " + asset_path)
			return

	print("PROGRESSION_SANITY_OK")
	quit(0)
