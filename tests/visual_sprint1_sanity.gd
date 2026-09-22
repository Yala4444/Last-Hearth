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

	# Production sprint-1 assets must all import as textures.
	var textures: Array = [
		game.TEX_HERO_IDLE, game.TEX_HERO_WALK, game.TEX_HERO_ATTACK,
		game.TEX_HERO_CARRY_1, game.TEX_HERO_CARRY_2, game.TEX_HERO_CARRY_3,
		game.TEX_TREE_A, game.TEX_TREE_B, game.TEX_TREE_C, game.TEX_TREE_FALLING,
		game.TEX_STUMP, game.TEX_LOG, game.TEX_HEARTH_1, game.TEX_HEARTH_2,
		game.TEX_ROCK, game.TEX_GRASS
	]
	for texture in textures:
		if texture == null:
			fail("Sprint 1 asset failed to import")
			return

	# The first expedition must have a deliberately readable teaching tree.
	game.meta["attempts"] = 1
	game.rng.seed = 12345
	game._generate_layout()
	var teaching_tree_found := false
	for node in game.resource_nodes:
		if String(node.get("kind", "")) == "tree" and Vector2(node["pos"]).distance_to(Vector2(240.0, 590.0)) < 1.0:
			teaching_tree_found = true
			break
	if not teaching_tree_found:
		fail("Teaching tree missing from first expedition")
		return

	# Visual light should start aligned with the gameplay light target.
	game.light_radius = 165.0
	game.light_display_radius = 165.0
	game.hearth_level = 1
	game.upgrade_wave = 0.0
	if absf(game.light_display_radius - game.light_radius) > 0.01:
		fail("Visual light radius starts desynced")
		return

	print("VISUAL_SPRINT1_SANITY_OK")
	quit(0)
