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

	# v0.15 rule: the central field-fire clearing has no filler interactables.
	game.meta["first_run"] = false
	game.meta["attempts"] = 4
	game.meta["forest_fires"] = 1
	game._start_expedition()
	if not game.events.is_empty():
		fail("Central clearing still contains generic interactable landmarks")
		return

	# Movement should accelerate instead of jumping to full speed, then settle at the target.
	game.mode = game.Mode.HUB
	game.hub_area = "center"
	game.hero_pos = Vector2(200.0, 400.0)
	game.hero_target = Vector2(320.0, 400.0)
	game.hero_velocity = Vector2.ZERO
	game.joystick_active = false
	game._update_movement(0.016)
	var first_speed := game.hero_velocity.length()
	if first_speed <= 0.0:
		fail("Smoothed movement did not start")
		return
	if first_speed >= game.HERO_SPEED * 0.75:
		fail("Movement still jumps too close to full speed on the first frame")
		return

	for i in range(240):
		game._update_movement(0.016)

	if game.hero_pos.distance_to(game.hero_target) > 3.0:
		fail("Tap-to-move did not settle near the target")
		return
	if game.hero_velocity.length() > 5.0:
		fail("Velocity did not settle after reaching the target")
		return

	print("V015_CLARITY_SANITY_OK")
	quit(0)
