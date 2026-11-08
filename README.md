# Trailer Park

A cooperative 3D trailer-park builder and management prototype for **2–4 players**, built with **Godot 4.7.2** for iOS and Android. Build roads and homes, supply utilities, attract households, balance the park's books and deal with the consequences of expansion.

**The repository now contains a runnable Godot project.** It starts with eight occupied homes and can develop to forty lots across six land parcels. The supplied trailer remains the approved source asset; rejected character models have been removed.

## Play the project

Import `project.godot` in Godot 4.7.2 and press **Run Project**. On this Mac, the editor executable is `/Applications/Godot.app/Contents/MacOS/Godot`.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

Choose **Continue to the park** to play locally, or use **Host with friends** / **Join a park** for multiplayer. See [the playtest walkthrough](docs/PLAYTEST.md) for controls, expansion steps, multiplayer setup and save locations.

## What works

- Independent overhead cameras with touch pan/pinch/orbit, mouse controls and keyboard navigation.
- Grid-based road paths, connected road branches, trailer/facility placement, quarter-turn rotation, relocation and eligible demolition.
- Purchasable land, forty-home capacity, placement previews and access validation.
- Road-network-based power, water and sewage supply with capacity limits; trash and maintenance capacity; facility upgrades.
- Households moving in and leaving according to services, condition, rent affordability and satisfaction.
- Rent income, recurring operating costs, business income, loans and repayments, arrears, building wear and repairs.
- Authored management situations with choices, park reputation and progression grants/unlocks.
- Budget, services, household, situations and growth interfaces; service overlays, building inspection, guidance and interface sounds.
- Server-authoritative ENet multiplayer, shared state, visible construction plans, optional spending approvals, late joining and reconnecting.
- Versioned JSON saves, autosaves and backup recovery. Clients cannot write the authority's park save.

The detailed original scope and implementation boundaries are tracked in [FIRST_PROTOTYPE.md](docs/FIRST_PROTOTYPE.md). This is a prototype implementation; signed mobile distribution and physical-device validation remain separate checks.

## Multiplayer

A player-hosted park supports the host plus three friends. A dedicated server supports four players. Players share construction and the treasury; a supervisor character is not required. Each player keeps their own camera and menus. Spending approval is off by default; when enabled, non-manager purchases above the threshold, loans and demolition need manager approval. The shared simulation speed is authoritative; time voting is not implemented.

Hosting uses a reachable address, UDP port **27840** by default, and an optional shared access code. Automatic matchmaking, relay hosting and host migration are not implemented. Internet hosting needs a reachable server or UDP forwarding; the project does not provision a cloud service.

```sh
sh tools/run_server.sh --port=27840 --save-slot=friends --access-code=your-code
```

See [multiplayer operation and persistence details](docs/MULTIPLAYER.md). Friends join through the in-game menu. A command-line client can also use:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --join=127.0.0.1 --port=27840 --name=Manager --access-code=your-code
```

## Validation

These checks run the actual Godot implementation:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_simulation.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_world.tscn -- --skip-welcome
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_hud.gd
python3 tools/test_network.py --report test-results/network.json
```

The simulation suite currently passes **312 checks**. A developed forty-home fixture runs for thirty days, survives JSON save/restore and operates for another thirty days with all homes occupied and services supplied. World/HUD integration checks cover mesh validity and scale, rotated footprints, real management actions, selection cleanup, GUI input boundaries and camera-driven preview updates. The HUD suite passes 33 integrated checks, including the latest verified mobile-layout changes. Networking tests use actual ENet server/client processes rather than mocked peers, including simultaneous requests, approval revalidation, rejoining, capacity refusal and save backup recovery.

For a reproducible developed park during debug play:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --developed --skip-welcome --no-autosave
```

That explicit test fixture receives a development grant and is not normal starting progression. Headless checks do not establish mobile GPU performance, touch comfort on a physical screen, or public-internet deployment reliability.

## Assets and export status

The [original furnished trailer](assets/trailers/weathered_singlewide/README.md), its Blender files, GLB and previews are preserved. The game batches approved exterior geometry and procedural yard props into cached mesh variants; source furnishings remain in the master. The game restores the source builder's authored base-color palette where the GLB omitted procedural material colors and handles vertex colors in linear space. Blender's procedural surface wear remains unbaked. Other service buildings, landscaping and props are prototype geometry. There are no replacement character models, individual walking-resident simulation or simulated service vehicles.

`export_presets.cfg` supplies Android, iOS and macOS presets. Generated packages and local SDK/template downloads live under ignored `builds/` and `.tools/` directories. A configured preset or successful export does not mean a signed release has been installed and tested on a physical phone. See [PLAYTEST.md](docs/PLAYTEST.md) for current build and testing boundaries.

Start with [PROJECT_HANDOFF.md](docs/PROJECT_HANDOFF.md) when continuing development. Completed requested changes should be committed and pushed by default, as recorded in `AGENTS.md`.
