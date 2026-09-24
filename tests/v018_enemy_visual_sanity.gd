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

	if game.TEX_ENEMIES_V018 == null:
		fail("Enemy production atlas failed to load")
		return
	if game.TEX_ENEMIES_V018.get_width() != 192 or game.TEX_ENEMIES_V018.get_height() != 2304:
		fail("Enemy atlas must be 192x2304: two frames x 24 direction rows")
		return

	var expected := {
		"basic": 0,
		"fast": 1,
		"elite": 2,
		"guard": 2,
		"black_boar": 3,
		"rootborn": 4,
		"forest_guardian": 5,
		"boss": 5
	}
	for kind in expected.keys():
		if game._enemy_v018_kind_index(kind) != int(expected[kind]):
			fail("Wrong visual mapping for enemy kind: %s" % kind)
			return

	var rect: Rect2 = game._enemy_v018_source_rect("fast", "right", 1)
	if rect.position != Vector2(96, 576) or rect.size != Vector2(96, 96):
		fail("Fast/right enemy source cell mapping is wrong")
		return

	if game._enemy_v018_visual_size("black_boar").x <= game._enemy_v018_visual_size("basic").x:
		fail("Black boar must read larger than a basic forest creature")
		return
	if game._enemy_v018_visual_size("forest_guardian").y <= game._enemy_v018_visual_size("rootborn").y:
		fail("Forest Guardian must visually dominate Rootborn")
		return

	game.expedition_sector = 0
	if game._forest_final_enemy_kind() != "black_boar":
		fail("Forest expedition 1 must end with Black Boar")
		return
	game.expedition_sector = 1
	if game._forest_final_enemy_kind() != "rootborn":
		fail("Forest expedition 2 must end with Rootborn")
		return
	game.expedition_sector = 2
	if game._forest_final_enemy_kind() != "forest_guardian":
		fail("Forest expedition 3 must end with Forest Guardian")
		return

	game.enemies.clear()
	game._spawn_enemy_at("fast", Vector2(200, 200))
	if not game.enemies[0].has("facing"):
		fail("New enemy did not receive a persistent facing vector")
		return

	print("V018_ENEMY_VISUAL_SANITY_OK")
	quit(0)
