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
	var first_speed: float = game.hero_velocity.length()
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

	# Notification priority: story stays readable and lower-priority notices wait.
	game.story_hint = ""
	game.story_hint_timer = 0.0
	game.banner_text = ""
	game.banner_timer = 0.0
	game.hub_feedback_text = ""
	game.hub_feedback_timer = 0.0
	game.notice_queue.clear()
	game._story("IMPORTANT STORY", 1.0)
	game._banner("LATER BANNER", 1.0)
	if game.story_hint != "IMPORTANT STORY" or game.notice_queue.size() != 1:
		fail("Notification queue did not serialize story and banner")
		return
	game.story_hint_timer = 0.0
	game._advance_notice_queue()
	if game.banner_text != "LATER BANNER" or game.banner_timer <= 0.0:
		fail("Queued banner did not advance after story")
		return

	# Worker identity: during a night the worker repairs the hearth instead of acting like another shooter.
	game.survivor_agents.clear()
	game.hearth_max_hp = 150.0
	game.hearth_hp = 100.0
	game.stage = game.Stage.NIGHT2
	game._add_survivor("worker", Vector2(260.0, 430.0))
	var worker: Dictionary = game.survivor_agents[0]
	worker["repair_cd"] = 0.0
	game.survivor_agents[0] = worker
	game._update_survivor_agents(0.1)
	if game.hearth_hp <= 100.0:
		fail("Worker did not repair the hearth during night")
		return

	# First return teaches settlement construction contextually instead of opening the full book modal.
	game.meta["forest_fires"] = 1
	game.meta["hub_intro_seen"] = false
	game.help_open = false
	game._enter_hub()
	if game.help_open:
		fail("First return still opens a blocking help overlay")
		return
	if not bool(game.meta.get("hub_intro_seen", false)):
		fail("Hub return intro was not marked as seen")
		return
	if game.story_hint.find("ОГОНЬ ОСТАЛСЯ В ЛЕСУ") < 0:
		fail("First return did not explain that restored fires persist in the region")
		return

	print("V015_CLARITY_SANITY_OK")
	quit(0)
