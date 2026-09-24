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

	var hero_textures: Array[Texture2D] = [
		game.TEX_HERO_V018_DOWN_0, game.TEX_HERO_V018_DOWN_1,
		game.TEX_HERO_V018_LEFT_0, game.TEX_HERO_V018_LEFT_1,
		game.TEX_HERO_V018_RIGHT_0, game.TEX_HERO_V018_RIGHT_1,
		game.TEX_HERO_V018_UP_0, game.TEX_HERO_V018_UP_1
	]
	for texture in hero_textures:
		if texture == null:
			fail("A v0.18 hero production frame failed to load")
			return
		if texture.get_width() != 96 or texture.get_height() != 128:
			fail("A v0.18 hero frame lost its normalized 96x128 canvas")
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

	game.hero_walk_phase = 0.0
	if game._hero_v018_frame_index(false) != 0:
		fail("Idle hero should use the stable first frame")
		return
	if game._hero_v018_frame_index(true) != 0:
		fail("Walk phase zero should use frame zero")
		return
	game.hero_walk_phase = 2.6
	if game._hero_v018_frame_index(true) != 1:
		fail("Walking did not advance to the second production frame")
		return

	if game._hero_v018_texture("left", 1) != game.TEX_HERO_V018_LEFT_1:
		fail("Hero texture selector returned the wrong frame")
		return

	print("V018_ASSET_PIPELINE_SANITY_OK")
	quit(0)
