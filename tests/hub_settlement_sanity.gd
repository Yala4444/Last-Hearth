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

	game.meta["forest_fires"] = 1
	game.meta["rescued_hunter"] = true
	game.meta["rescued_worker"] = true
	game.meta["forester_home_built"] = false
	game.meta["hunter_home_built"] = false
	game.meta["worker_home_built"] = false
	for key in ["forester_home_wood", "forester_home_stone", "hunter_home_wood", "hunter_home_stone", "worker_home_wood", "worker_home_stone"]:
		game.meta[key] = 0

	game._enter_hub()
	if game.hub_area != "center":
		fail("Hub did not start in the settlement center")
		return

	var sites = game._hub_build_sites()
	if sites.size() != 3:
		fail("Expected forester, hunter and worker construction sites after the first fire")
		return

	# The settlement must have continuous side areas rather than menu-only resource buttons.
	game.hero_pos = game.HUB_GROVE_GATE
	game._update_hub_area_transitions()
	if game.hub_area != "grove":
		fail("Walking left from the Last Hearth did not enter the grove")
		return
	if float(game.hero_pos.x) < 400.0:
		fail("Entering the grove from the left gate did not spawn at the right edge")
		return
	if game.resource_nodes.size() < 4 or not bool(game._gathering_enabled()):
		fail("The grove is not a playable gathering area")
		return

	# Entering beside the return gate must NOT bounce back on the next frame.
	game._update_hub_area_transitions()
	if game.hub_area != "grove":
		fail("The grove immediately bounced back to the Last Hearth")
		return
	if bool(game.hub_return_armed):
		fail("The grove exit armed before the player walked into the area")
		return

	game.hero_pos = Vector2(280.0, 535.0)
	game._update_hub_area_transitions()
	if not bool(game.hub_return_armed):
		fail("Walking into the grove did not arm the return path")
		return

	game.hero_pos = game.hub_area_return_gate
	game._update_hub_area_transitions()
	if game.hub_area != "center":
		fail("The grove did not return to the settlement center")
		return
	if float(game.hero_pos.x) > 120.0:
		fail("Returning from the grove did not preserve spatial continuity")
		return

	# Construction is physical: carried materials must be delivered to the scaffold.
	var forester_site: Dictionary = {}
	for site in game._hub_build_sites():
		if String(site["id"]) == "forester_home":
			forester_site = site
			break
	if forester_site.is_empty():
		fail("Forester construction site missing")
		return

	game.hero_pos = forester_site["pos"]
	game.carried_wood = int(forester_site["wood_cost"])
	game.carried_stone = int(forester_site["stone_cost"])
	for i in range(8):
		game.unload_cd = 0.0
		game._update_hub_construction(0.2)
	if not bool(game.meta.get("forester_home_built", false)):
		fail("Delivering the required materials did not finish the forester home")
		return

	# The opposite side of the hub must work the same way for stone.
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
