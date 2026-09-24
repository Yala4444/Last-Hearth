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

	var sheets: Array[Texture2D] = [
		game.TEX_HERO_V018,
		game.TEX_HUNTER_V018,
		game.TEX_MASTER_V018,
		game.TEX_SCOUT_V018,
		game.TEX_SETTLER_V018
	]
	for texture in sheets:
		if texture == null:
			fail("A v0.18-A2 production character sheet failed to load")
			return
		if texture.get_width() != 120 or texture.get_height() != 320:
			fail("A production character sheet lost its normalized 120x320 grid")
			return

	# The iPhone corruption fix is specifically the hero path: no per-frame transparent WebP.
	if not String(game.TEX_HERO_V018.resource_path).ends_with(".png"):
		fail("Hero production sheet must use PNG on the iPhone/Web path")
		return
	if not String(game.TEX_MASTER_V018.resource_path).ends_with(".svg"):
		fail("Master sheet must use the stable SVG import path")
		return
	if not String(game.TEX_SCOUT_V018.resource_path).ends_with(".svg"):
		fail("Scout sheet must use its distinct SVG production path")
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

	var down0: Rect2 = game._character_v018_source_rect("down", 0)
	var down1: Rect2 = game._character_v018_source_rect("down", 1)
	var up0: Rect2 = game._character_v018_source_rect("up", 0)
	if down0.position != Vector2(0, 0) or down0.size != Vector2(60, 80):
		fail("Down frame zero does not use the clean first PNG cell")
		return
	if down1.position != Vector2(60, 0):
		fail("Down walk frame does not use the second PNG cell")
		return
	if up0.position != Vector2(0, 240):
		fail("Up row mapping is wrong")
		return

	game.hero_walk_phase = 0.0
	if game._hero_v018_frame_index(false) != 0:
		fail("Idle hero should use frame zero")
		return
	game.hero_walk_phase = 2.6
	if game._hero_v018_frame_index(true) != 1:
		fail("Walking did not advance to frame one")
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

	if not game._has_survivor_label("ВОЗНИЦА"):
		fail("Survivor identity lookup failed")
		return
	if game._has_survivor_label("РАЗВЕДЧИК"):
		fail("Survivor identity lookup created a false duplicate")
		return

	print("V018_ASSET_PIPELINE_SANITY_OK")
	quit(0)
