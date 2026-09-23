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

	# Global world architecture: five regions, each with one chapter resident and one gameplay modifier.
	if game.REGION_PROFILES.size() != 5:
		fail("v0.17 world spine does not contain five regions")
		return
	for region_id in ["forgotten_forest", "dead_fields", "flooded_lowlands", "ashen_ridge", "old_city"]:
		var profile: Dictionary = game._region_profile(region_id)
		if profile.is_empty():
			fail("Missing region profile: " + region_id)
			return
		if not profile.has("resident") or String(profile["resident"]) == "":
			fail("Region lacks a chapter resident: " + region_id)
			return
		if not profile.has("modifier") or String(profile["modifier"]) == "":
			fail("Region lacks a gameplay modifier: " + region_id)
			return
		if not profile.has("fires") or profile["fires"].size() != 3:
			fail("Region does not define exactly three fires: " + region_id)
			return
		if not profile.has("people") or profile["people"].size() < 3:
			fail("Region does not define a meaningful people roster: " + region_id)
			return
		var resident_count := 0
		for person_variant in profile["people"]:
			var person: Dictionary = person_variant
			if String(person.get("fate", "")) == "chapter_resident":
				resident_count += 1
		if resident_count != 1:
			fail("Region must define exactly one chapter resident: " + region_id)
			return

	# Forgotten Forest must escalate through two mini-bosses into the real regional boss.
	game.expedition_sector = 0
	if game._forest_final_enemy_kind() != "black_boar":
		fail("Fire 1 does not end with Black Boar")
		return
	if game._field_fire_wood_cost() != 3:
		fail("Fire 1 teaching setup cost changed unexpectedly")
		return

	game.expedition_sector = 1
	if game._forest_final_enemy_kind() != "rootborn":
		fail("Fire 2 does not end with Rootborn")
		return
	if game._field_fire_wood_cost() != 2:
		fail("Fire 2 did not shorten repeated opening setup")
		return

	game.expedition_sector = 2
	if game._forest_final_enemy_kind() != "forest_guardian":
		fail("Fire 3 does not end with the Forest Guardian")
		return
	if game._field_fire_wood_cost() != 1:
		fail("Fire 3 did not shorten repeated opening setup")
		return

	# Night 3 queues the correct finale enemy for each regional fire.
	for sector in range(3):
		game.expedition_sector = sector
		game.day1_route = "hunter"
		game.survivors = 2
		game._start_night(3)
		var expected: String = String(["black_boar", "rootborn", "forest_guardian"][sector])
		if game.night_queue.is_empty() or String(game.night_queue.back()) != expected:
			fail("Night 3 queued the wrong boss for sector %d" % sector)
			return

	# Bosses have visibly different combat profiles.
	game.enemies.clear()
	game._spawn_enemy_at("black_boar", Vector2(240, 120))
	game._spawn_enemy_at("rootborn", Vector2(240, 120))
	game._spawn_enemy_at("forest_guardian", Vector2(240, 120))
	if game.enemies.size() != 3:
		fail("Could not spawn all three forest finale enemies")
		return
	if float(game.enemies[0]["speed"]) <= float(game.enemies[1]["speed"]):
		fail("Black Boar is not faster than Rootborn")
		return
	if float(game.enemies[2]["max_hp"]) <= float(game.enemies[0]["max_hp"]):
		fail("Forest Guardian is not stronger than the first mini-boss")
		return

	# Guardian phases must escalate and call reinforcements.
	game.enemies.clear()
	game.night_queue.clear()
	game.mode = game.Mode.EXPEDITION
	game.area = game.Area.CAMP
	game.expedition_sector = 2
	game.light_radius = 300.0
	game._spawn_enemy_at("forest_guardian", Vector2(240, 120))
	game.enemies[0]["hp"] = float(game.enemies[0]["max_hp"]) * 0.60
	game._update_enemies(0.01)
	if int(game.enemies[0].get("boss_phase", 1)) != 2:
		fail("Forest Guardian did not enter phase 2")
		return
	if game.night_queue.size() < 2:
		fail("Forest Guardian phase 2 did not call lesser creatures")
		return
	game.enemies[0]["hp"] = float(game.enemies[0]["max_hp"]) * 0.30
	game._update_enemies(0.01)
	if int(game.enemies[0].get("boss_phase", 1)) != 3:
		fail("Forest Guardian did not enter phase 3")
		return

	# Rootborn must pressure the light rather than behaving like the same boss with a new sprite.
	game.enemies.clear()
	game.night_queue.clear()
	game.expedition_sector = 1
	game.light_radius = 300.0
	game._spawn_enemy_at("rootborn", Vector2(240, 120))
	game.enemies[0]["hp"] = float(game.enemies[0]["max_hp"]) * 0.45
	var light_before := float(game.light_radius)
	game._update_enemies(0.01)
	if int(game.enemies[0].get("boss_phase", 1)) != 2:
		fail("Rootborn did not trigger its rooted phase")
		return
	if float(game.light_radius) >= light_before:
		fail("Rootborn did not squeeze the firelight")
		return

	# First sound pass must exist without external audio assets.
	if game.audio_sfx_streams.size() < 10:
		fail("v0.17 sound pass did not initialize the expected sound set")
		return
	if game.audio_wind == null or game.audio_fire == null:
		fail("Ambient wind/fire players were not created")
		return
	for sound_id in ["chop", "stone", "pickup", "shot", "night", "boss", "boss_down", "map", "home"]:
		if not game.audio_sfx_streams.has(sound_id):
			fail("Missing procedural sound: " + sound_id)
			return

	if int(game.meta.get("build_version", 0)) != 17:
		fail("Build schema was not bumped to v0.17")
		return

	print("V017_WORLD_SHAPE_SANITY_OK")
	quit(0)
