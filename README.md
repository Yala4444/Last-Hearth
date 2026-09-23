# Last Hearth / Последний Очаг

Standalone Godot project for the second game.

## Current build — v0.17: The World Takes Shape

The playable chapter is still the Forgotten Forest, but the project now has the world architecture needed for the full game:

- one persistent Last Hearth settlement;
- one region = three expeditions = three restored fires = one connected mini-story;
- restored fires remain part of the world and are remembered on the map;
- character fates: temporary companion, local keeper or permanent resident;
- Forgotten Forest finales now escalate through Black Boar, Rootborn and the true Forest Guardian;
- the Forest Guardian only appears at Fire 3 and has multiple combat phases;
- repeated setup is shortened on Fire 2 and Fire 3;
- route and night pressure differ between the three forest expeditions;
- first procedural sound-design pass: fire/wind ambience, gathering, pickup, shooting, night, boss, map and home feedback;
- persistent hub growth and ember upgrades;
- resident-gated construction, with the Master as the Forgotten Forest chapter resident;
- five-region world spine prepared in code: Forgotten Forest, Dead Fields, Flooded Lowlands, Ashen Ridge and Old City.

Only the Forgotten Forest is playable in v0.17. Future regions are deliberately design data until their own chapter passes begin.

See `docs/V0.17_DEV_PLAN.md` for the locked progression and resident plan.

## Project separation

AXEHOLD is a separate project and must not be developed in this repository.

## Web build

GitHub Actions validates the Godot project, runs progression/regression tests, exports the Web build and deploys it to GitHub Pages.
