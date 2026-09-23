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

	# v0.16: rescued people do not magically create residential plots.
	game.meta["forest_fires"] = 1
	game.meta["rescued_hunter"] = true
	game.meta["rescued_worker"] = true
	game.meta["hunter_fate"] = "keeper_fire_1"
	game.meta["master_relationship_state"] = "waiting_forest"
	game.meta["worker_home_built"] = false
	game.meta["worker_home_wood"] = 0
	game.meta["worker_home_stone"] = 0
	game._enter_hub()
	if game.hub_area != "center":
		fail("Hub did not start in the settlement center")
		return
	if game._hub_build_sites().size() != 0:
		fail("Hub exposed a residential plot before anyone chose to live there")
		return

	# After the forest chapter is complete, the Master can choose the Last Hearth.
	game.meta["forest_fires"] = 3
	game.meta["master_relationship_state"] = "joining_home"
	var sites = game._hub_build_sites()
	if sites.size() != 1 or String(sites[0]["id"]) != "worker_home":
		fail("Master arrival did not unlock exactly one real home construction")
		return
	var master_site: Dictionary = sites[0]

	# The settlement still has continuous side areas for physical construction resources.
	game.hero_pos = game.HUB_GROVE_GATE
	game.hero_target = game.hero_pos
	game._process(0.016)
	if game.hub_area != "grove":
		fail("Walking left from the Last Hearth did not enter the grove")
		return
	if float(game.hero_pos.x) < 400.0:
		fail("Entering the grove from the left gate did not spawn at the right edge")
		return
	if game.resource_nodes.size() < 4 or not bool(game._gathering_enabled()):
		fail("The grove is not a playable gathering area when a real construction is pending")
		return

	game._process(0.016)
	if game.hub_area != "grove":
		fail("The grove immediately bounced back to the Last Hearth")
		return
	if bool(game.hub_return_armed):
		fail("The grove exit armed before the player walked into the area")
		return

	game.hero_pos = Vector2(280.0, 535.0)
	game.hero_target = game.hero_pos
	game._process(0.016)
	if not bool(game.hub_return_armed):
		fail("Walking into the grove did not arm the return path")
		return

	game.hero_pos = game.hub_area_return_gate
	game.hero_target = game.hero_pos
	game._process(0.016)
	if game.hub_area != "center":
		fail("The grove did not return to the settlement center")
		return

	# Construction is physical and completing the home changes the Master into a resident.
	game.hero_pos = master_site["pos"]
	game.carried_wood = int(master_site["wood_cost"])
	game.carried_stone = int(master_site["stone_cost"])
	for i in range(12):
		game.unload_cd = 0.0
		game._update_hub_construction(0.2)
	if not bool(game.meta.get("worker_home_built", false)):
		fail("Delivering the required materials did not finish the Master home")
		return
	if String(game.meta.get("master_relationship_state", "")) != "resident":
		fail("Building the Master home did not convert him into a permanent resident")
		return

	# The opposite side still preserves spatial continuity.
	game.hero_pos = game.HUB_QUARRY_GATE
	game._update_hub_area_transitions()
	if game.hub_area != "quarry":
		fail("Walking right from the Last Hearth did not enter the quarry")
		return
	if float(game.hero_pos.x) > 80.0:
		fail("Entering the quarry from the right gate did not spawn at the left edge")
		return

	print("HUB_SETTLEMENT_SANITY_OK")
	quit(0)
