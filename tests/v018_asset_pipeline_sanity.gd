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

	var hero: Texture2D = game.TEX_HERO_V018
	if hero == null or hero.get_width() != 120 or hero.get_height() != 320:
		fail("Hero must keep the proven 120x320 two-frame production sheet")
		return
	if not String(hero.resource_path).ends_with(".png"):
		fail("Hero production sheet must stay PNG on the iPhone/Web path")
		return

	var npc_sheets: Array[Texture2D] = [
		game.TEX_HUNTER_V018,
		game.TEX_MASTER_V018,
		game.TEX_SCOUT_V018,
		game.TEX_SETTLER_V018
	]
	for texture in npc_sheets:
		if texture == null:
			fail("An A7 production NPC sheet failed to load")
			return
		if texture.get_width() != 180 or texture.get_height() != 360:
			fail("A7 NPC sheets must use the normalized 180x360 3x4 grid")
			return
		if not String(texture.resource_path).ends_with(".png"):
			fail("A7 production NPC sheets must use PNG assets")
			return

	var expected_v2_paths := [
		"res://assets/v018/characters/hunter_production_v2_opt.png",
		"res://assets/v018/characters/master_production_v2_opt.png",
		"res://assets/v018/characters/scout_production_v2_opt.png",
		"res://assets/v018/characters/settler_production_v2_opt.png"
	]
	for i in range(npc_sheets.size()):
		if String(npc_sheets[i].resource_path) != expected_v2_paths[i]:
			fail("A7.2 must use final v2 NPC sheet: %s" % expected_v2_paths[i])
			return

	if game._hero_v018_direction_key(Vector2(0, 1)) != "down":
		fail("Hero down direction mapping is wrong")
		return
	if game._hero_v018_direction_key(Vector2(0, -1)) != "up":
		fail("Hero up direction mapping is wrong")
		return
	if game._hero_v018_direction_key(Vector2(-1, 0)) != "left":
		fail("Hero left direction mapping is wrong")
		return
	if game._hero_v018_direction_key(Vector2(1, 0)) != "right":
		fail("Hero right direction mapping is wrong")
		return

	var hero_down0: Rect2 = game._character_v018_source_rect_for_role("hero", "down", 0)
	var hero_down1: Rect2 = game._character_v018_source_rect_for_role("hero", "down", 1)
	if hero_down0.position != Vector2(0, 0) or hero_down0.size != Vector2(60, 80):
		fail("Hero frame zero mapping changed")
		return
	if hero_down1.position != Vector2(60, 0):
		fail("Hero walk frame one mapping changed")
		return

	var scout_right2: Rect2 = game._character_v018_source_rect_for_role("guard", "right", 2)
	var master_up1: Rect2 = game._character_v018_source_rect_for_role("worker", "up", 1)
	if scout_right2.position != Vector2(120, 180) or scout_right2.size != Vector2(60, 90):
		fail("Scout production sheet right/frame2 mapping is wrong")
		return
	if master_up1.position != Vector2(60, 270):
		fail("Master production sheet up/frame1 mapping is wrong")
		return

	game.hero_walk_phase = 0.0
	if game._hero_v018_frame_index(false) != 0:
		fail("Idle hero should use frame zero")
		return
	game.hero_walk_phase = 2.6
	if game._hero_v018_frame_index(true) != 1:
		fail("Hero two-frame walk cycle regressed")
		return
	# A7.2 gait: neutral -> first step -> neutral -> second step.
	if game._character_v018_phase_frame_for_role("guard", 0.2, true) != 0:
		fail("Production NPC gait must start from neutral")
		return
	if game._character_v018_phase_frame_for_role("guard", 2.0, true) != 1:
		fail("Production NPC gait does not reach first authored step")
		return
	if game._character_v018_phase_frame_for_role("guard", 3.7, true) != 0:
		fail("Production NPC gait must return to neutral between steps")
		return
	if game._character_v018_phase_frame_for_role("guard", 5.5, true) != 2:
		fail("Production NPC gait does not reach second authored step")
		return
	if game._character_v018_phase_frame_for_role("worker", 99.0, false) != 0:
		fail("Production NPC idle must stay on frame zero")
		return

	if game._character_v018_texture("hunter") != game.TEX_HUNTER_V018:
		fail("Hunter is not mapped to its production sheet")
		return
	if game._character_v018_texture("worker") != game.TEX_MASTER_V018:
		fail("Master is not mapped to its production sheet")
		return
	if game._character_v018_texture("guard") != game.TEX_SCOUT_V018:
		fail("Scout/guard is not mapped to its production sheet")
		return
	if game._character_v018_texture("civilian") != game.TEX_SETTLER_V018:
		fail("Settler is not mapped to its production sheet")
		return

	if game._default_survivor_label("hunter") != "ОХОТНИК":
		fail("Hunter identity label is wrong")
		return
	if game._default_survivor_label("worker") != "МАСТЕР":
		fail("Master identity label is wrong")
		return
	game.survivor_agents.clear()
	game._add_survivor("guard", Vector2(200, 200), "ВОЗНИЦА")
	if String(game.survivor_agents[0].get("label", "")) != "ВОЗНИЦА":
		fail("Explicit NPC identity was not stored")
		return
	if String(game.survivor_agents[0].get("visual_role", "")) != "civilian":
		fail("Behavior role leaked into Voznica visual identity")
		return

	if not game._has_survivor_label("ВОЗНИЦА"):
		fail("Survivor identity lookup failed")
		return
	if game._has_survivor_label("РАЗВЕДЧИК"):
		fail("Survivor identity lookup created a false duplicate")
		return

	# Regression: sector 3 can offer the Scout on day 1 and reference him again on day 2.
	# The second beat must upgrade the existing Scout, never clone him.
	game.survivor_agents.clear()
	game.survivors = 1
	game._add_survivor("guard", Vector2(210, 210), "РАЗВЕДЧИК")
	game.stage = game.Stage.DAY2_RESCUE
	game.area = game.Area.WORKER_RUINS
	game.day2_mission = "scout"
	game.worker_route_complete = false
	game.worker_clear_announced = false
	game.survivor_two_pos = Vector2(250, 185)
	game.hero_pos = game.survivor_two_pos
	game.enemies.clear()
	game.hero_damage = 24.0
	game._update_worker_route()
	game._update_worker_route()
	if game.survivor_agents.size() != 1 or game.survivors != 2:
		fail("Day 2 Scout beat duplicated an existing Scout")
		return
	if game.hero_damage <= 24.0:
		fail("Existing Scout route did not grant its replacement route bonus")
		return

	print("V018_ASSET_PIPELINE_SANITY_OK")
	quit(0)
