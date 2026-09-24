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

	var world_textures: Array[Texture2D] = [
		game.TEX_FOREST_TREE_A_V018,
		game.TEX_FOREST_TREE_B_V018,
		game.TEX_FOREST_TREE_C_V018,
		game.TEX_FOREST_BUSH_V018,
		game.TEX_FOREST_FERN_V018,
		game.TEX_FOREST_ROCK_V018,
		game.TEX_FOREST_GROUND_PATCH_V018,
		game.TEX_HEARTH_3_V018,
		game.TEX_HEARTH_4_V018,
		game.TEX_HEARTH_5_V018,
		game.TEX_MASTER_HUT_V018,
		game.TEX_WORKSHOP_V018,
		game.TEX_WATCHTOWER_V018,
		game.TEX_FOREST_TREE_FALLEN_V018,
		game.TEX_FOREST_STUMP_V018,
		game.TEX_LOG_PICKUP_V018,
		game.TEX_STONE_PICKUP_V018,
		game.TEX_CARGO_FRAME_V018
	]
	for texture in world_textures:
		if texture == null:
			fail("A v0.18-B authored world texture failed to load")
			return
		if not String(texture.resource_path).contains("res://assets/v018/world/"):
			fail("v0.18-B world art escaped the dedicated asset pipeline")
			return

	if game.TEX_FOREST_TREE_A_V018.get_height() < 100:
		fail("Forest production trees are too small for the approved hero scale")
		return
	if game.TEX_HEARTH_5_V018.get_width() < 120:
		fail("Final Hearth stage is not visually larger than the prototype")
		return
	if game.TEX_MASTER_HUT_V018.get_width() < 110:
		fail("Resident hut asset is not production scale")
		return

	print("V018_WORLD_ART_SANITY_OK")
	quit(0)
