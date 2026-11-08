# Project handoff

## Current state

The repository is `MrCrashocaster/Trailer-Park`, branch `main`. It now contains a **runnable Godot 4.7.2 cooperative park-management prototype**, the approved furnished trailer source/export/builders, preliminary research notes and concept art. The user authorized implementation of the substantial first-prototype plan. Earlier statements that no Godot project or gameplay exists are superseded.

The user requested that completed changes be committed and pushed to GitHub by default. Follow `AGENTS.md`. Check actual Git status and publishing results before claiming a change has reached GitHub.

## User direction

- Build for **iOS and Android using Godot**, with approximately **2–4 people sharing one game**. The MacBook Air does not define game performance requirements.
- The selected implementation follows the latest Cities: Skylines-style cooperative trailer-park planning and management direction. Players manage the shared park with independent cameras. No player must take a supervisor character role.
- The first prototype should be substantial and well developed. A three-lot placement demonstration does not satisfy that request. See [FIRST_PROTOTYPE.md](FIRST_PROTOTYPE.md).
- The tone is grounded, shabby, mundane and funny: faded siding, cramped yards, worn possessions, petty schemes, complaints and questionable decisions. Use an original setting, identity and situations.
- **The trailer is the only approved source art asset so far.** The user rejected the character models and requested their removal, including textures, source data, previews and builders. They remain recoverable in Git history but must not be restored as approved content. No replacement character model was requested.
- Concept images remain generated mockups, not screenshots or completed production assets.

## Running and architecture

Import the repository's `project.godot` in Godot 4.7.2 and run `scenes/main.tscn`. The installed Mac executable is `/Applications/Godot.app/Contents/MacOS/Godot`. The project currently uses the Compatibility renderer for the initial cross-platform build; this does not establish performance on the eventual minimum mobile device.

- `scripts/sim/park_state.gd`, autoload **Park**: deterministic simulation and command validation. Owns the authoritative park dictionary, saved random state, buildings, roads, occupancy, services, finances, events and progression.
- `scripts/net/park_session.gd`, autoload **Session**: ENet hosting/joining, authoritative command routing, snapshots, construction plans, spending approvals, persistence and command-line server options.
- `scripts/world/park_world.gd`: procedural landscape, batched approved trailer exteriors, prototype facilities, grid/selection/preview geometry and overlays.
- `scripts/world/park_camera.gd`: independent overhead camera.
- `scripts/main.gd`: world/HUD integration and mouse/touch construction controls.
- `scripts/ui/park_hud.gd` and `ui_theme.gd`: construction catalog, inspection, management views, session menus, guidance and interface sounds.

The world is 48 × 36 cells at 6 meters per cell, divided into six 16 × 18-cell land parcels. The normal park starts with eight occupied homes, working utilities/services and $28,000. The planning limit is forty homes. Utility/service availability follows the entrance-connected road graph and facility capacity; there are no separately drawn pipe/wire networks or service-vehicle routing systems.

Simulation changes enter through `Park.apply_command`. `Session` controls authority and sends validated results to clients. Preserve transactional rejection, stable identifiers, consistent budgets and saved random-state continuation when changing systems. JSON numbers can arrive as floats even when they represent integer coordinates or identifiers.

## Implemented play loop

Players buy adjoining land, extend connected roads, place/rotate trailers and facilities, supply power/water/sewage, attract households, collect rent and business income, pay operating costs, repair wear, upgrade capacity and respond to authored situations. Satisfaction and affordability influence move-in/move-out. Progression unlocks the corner store and development grants.

Players can host locally or join by address, port and optional access code. Player hosts support three friends; dedicated servers support four clients. Shared funds and optional spending approvals support cooperation. Host migration, automatic matchmaking, relay hosting and cloud account services are not implemented. Hosting a public internet session still requires reachable server infrastructure.

Park saves are versioned JSON under `user://saves`; the default slot is `park`. The authority writes saves and autosaves. A dedicated server restores its selected save slot on startup and sleeps its simulation when no players remain. A graphical local/host session can load saved parks through the session menu. Camera positions are local UI state, not part of the authoritative simulation save.

## Existing trailer

Location: `assets/trailers/weathered_singlewide/`. Read its README before geometry edits or rebuilding.

- `trailer_singlewide_a.blend`: furnished exterior/interior, studio and camera, saved as a cutaway. Roof/front wall and upper partitions remain in toggleable CUTAWAY collections.
- `trailer_singlewide_a.glb`: full building/interior without the studio. Nominal shell is 12 × 3.5 meters, metric, Z-up in Blender; Godot imports the asset into its own coordinate convention.
- `preview.png`: actual Blender cutaway render. `preview_exterior.png` and the exterior-only `.blend` preserve the earlier exterior.
- `build_asset.py` invokes `build_interior.py` to rebuild and render. Rebuilding overwrites generated deliverables; preserve manual edits under another filename first.

The source trailer files are unchanged by game implementation. The game filters Interior-prefixed materials when batching the exterior, restores the source builder's authored base-color palette where procedural GLB materials omit it, preserves correctly converted linear vertex colors and caches trailer/yard variants. The imported master contains 1,170 mesh nodes; an exterior batch has one surface, and each current trailer-lot visual uses three nodes including its label. That reduces scene-node overhead; it is not a measured mobile frame-rate result. Procedural Blender weathering is not baked into the GLB. No interactive interiors, resident characters, locomotion set or vehicle simulation has been added.

## Verification and limits

See [PLAYTEST.md](PLAYTEST.md) for exact commands and hands-on actions.

- Simulation: **312 checks passing**, including atomic road paths, placement/cost validation, relocation, road dependencies, capacity, households, bills/loans, events, invalid commands/saves and deterministic JSON restoration.
- Developed fixture: forty actual placed homes with all services supplied and forty occupied households after thirty days; JSON restore plus another thirty days remains operational. The fixture uses an explicit test-only development grant.
- World integration: **65 checks passing** for finite/scaled GLB batching, cached variants, all quarter-turn footprints, real HUD commands, overlays, selection deletion, GUI release cleanup and camera-driven placement previews.
- HUD: **33 integrated checks passing**, including the latest verified layout changes. ENet tests exercise real dedicated-server/four-client processes, including concurrent purchases, malformed/replayed requests, approval policy/queue revalidation, fifth-player refusal, rejoining, manager promotion and save/backup recovery. Check their latest reports after networking changes.
- Android/iOS/macOS export presets are present. Generated packages and SDK/template caches are ignored by Git. Root-level build work may update artifact status; verify the files and logs before reporting successful exports.
- Signed mobile distribution, physical iOS/Android touch/performance testing and a deployed public-internet service are **not established by the local/headless checks**. Minimum supported devices and hosting budget remain undecided.

## References and local viewing

The user has a 2020 Intel i5 MacBook Air and previously showed Blender 4.0.2; Material Preview caused Blender to close. The source asset was created in Blender 4.3.2. These are local Blender-viewing notes only. PNG previews are the reliable reference for procedural surface detail. Prefer clear menu instructions and verify the current Blender version before version-specific advice.

[Concept art](concept-art/README.md) records earlier management/life/building mockups. Their interface imagery does not prove a feature is implemented. Older `docs/research/` notes remain recalled, explicitly unverified background; they are not a completed episode-by-episode research corpus.

## Next verification priorities

Complete and inspect generated exports, install signed builds on actual iOS and Android devices, profile the developed park, playtest internet joining/reconnection on real networks, and assess whether four people have useful simultaneous work. Refine the prototype's art, control comfort, simulation balance and progression from those results. Preserve the substantial integrated milestone rather than treating one passing subsystem test as completion of every acceptance goal.
