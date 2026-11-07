# Project handoff — continuing in a new chat

## Read this first

The repository contains **two Blender assets, their exports and builders, preliminary research notes, and concept images**. There is **no Godot project, runnable game, networking implementation or gameplay code yet**. A concept image's interface and actions do not demonstrate implemented systems.

The repository is `MrCrashocaster/Trailer-Park`, on branch `main`. The furnished trailer and rough resident were already pushed before this handoff; this update adds the latest design direction and concept art so another chat can continue from GitHub without relying on conversation history.

## What the user wants

- An original game inspired by the broad atmosphere of Trailer Park Boys, with legally distinct characters, dialogue, setting, branding and stories.
- The latest direction is a **trailer park management and life simulation**: Cities: Skylines-style planning/finances combined with The Sims-style individual residents and homes.
- The user wants to be the park supervisor, inspired by Lahey's role: live in the community, manage it and get personally involved in its problems. That is a role reference, not an approved adaptation of the named character or actor.
- Multiplayer was requested earlier and has not been withdrawn. The latest proposed role arrangement is one supervisor player and friends occupying resident lots, with NPCs filling the park. Player count, permissions and persistence remain undecided.
- The visual tone is grounded, shabby, mundane and funny: faded siding, cramped yards, worn furniture and cars, scruffy residents, petty schemes, grudges and bad judgment. Earlier wholesome repair-business concepts and a cinematic concert concept were rejected as missing the tone.
- Character proportions must be realistic, matching the trailer's style. The first cartoon character was rejected and replaced. The current revision adds age/weight, stubble, tired skin, dirt/stains, earthy plaid and a slouched inspection stance.
- Concept art must be honest about what can actually be built. Reuse assets and keep the park small; do not treat image-generated foliage or UI as existing production work.

## Current working design / recommendations

These are proposals discussed with the user, not a final feature contract:

- Freely rotating angled overhead 3D camera with zoom. Zoom out to manage the park; zoom in for personal interactions.
- Control one supervisor through click-to-move and contextual interactions, rather than directly puppeteering every resident.
- Hide roofs and camera-facing walls when inspecting interiors.
- Resident routines, needs, relationships and competing goals; complaints, late rent, repairs and unauthorized businesses generate situations.
- Park budgets and rent fund maintenance and improvements. Decisions affect residents and relationships.
- Lot placement and simple furnishing/build tools can grow from a limited modular kit.
- Godot 4 was recommended, with the **Compatibility renderer** for the user's laptop. The user asked about using Godot; no engine project has been created or benchmarked.
- Begin with a small single-player loop while designing ownership/interactions to support eventual multiplayer.

## Existing trailer asset

Location: `assets/trailers/weathered_singlewide/`.

- `trailer_singlewide_a.blend`: furnished exterior/interior, camera and studio. Saved as a cutaway; roof/front wall and upper partition pieces are retained in toggleable CUTAWAY collections.
- `trailer_singlewide_a.glb`: full building and interior; no studio setup.
- `preview.png`: actual Blender interior cutaway render.
- `preview_exterior.png` / `trailer_singlewide_a_exterior.blend`: earlier exterior-only version.
- `build_asset.py` calls `build_interior.py` to rebuild and render.
- Nominal shell 12 × 3.5 m, metric, Z up. Clear rear hallway starts beside the fridge and serves bathroom and two bedrooms. AC is fitted into an actual framed end window, corrected after user feedback.
- Verified clear hallway/doorway volumes and GLB reimport during creation. The verification commands for the trailer were session scripts; they are not a permanent trailer test suite in the repo.
- No collision, LODs, navigation, interactive doors or gameplay integration. Many separate objects; needs optimization for repeating lots. Procedural surface wear is not baked into the trailer GLB, which has basic material colors/roughness.

Read its README before changing geometry or rebuilding.

## Existing resident asset

Location: `assets/characters/resident_01/`.

- `resident_01.blend`: current rough realistic resident with packed texture maps and FK skeleton.
- `resident_01.glb`: neutral pose, skinned, embedded image maps; excludes studio and inspection keys.
- `preview.png`, `preview_face.png`, `preview_back.png`: actual Blender renders of the current slouched presentation.
- `preview_reference.png`: neutral A-pose.
- `build_character.py` and `weather_materials.py`: reproducible generation and UV-based image weathering.
- `verify_character.py`: persistent meaningful checks for textures, weights, inspection poses, representative arm deformation, covered-body masks and actual GLB import.
- Approximately 1.78 m neutral height; 163-bone FK skeleton; five skinned meshes. Body shape uses 70% young / 30% old macro blend and 65% maxweight. Source pose arms are relaxed A-pose with forearms forward.
- Frame **1** is neutral. Frame **2** is slouched with lowered asymmetric arms. These are two inspection poses, not an intoxication animation or locomotion set. Clear/mute the inspection action before authoring unrelated poses.
- Source anatomy, garments, proxies, weights and texture maps are adapted from **CC0 MakeHuman assets**. `SOURCES.md`, licenses and source hashes are included. Do not claim the asset was entirely hand-sculpted or that it depicts an actor.
- Four `textures/weathered_*.png` maps hold clothing/skin/hair/shoe changes. Original sources remain intact. Dirt and pattern export into GLB; tiny procedural skin pores remain Blender-only.
- No dedicated IK controls, expression library, animation set, LODs, collision or engine-specific humanoid retargeting.

Rebuild and verify (requires Blender):

```sh
blender -b --threads 4 --python /workspace/Trailer-Park/assets/characters/resident_01/build_character.py
blender -b --threads 2 --python /workspace/Trailer-Park/assets/characters/resident_01/verify_character.py
```

Scripts locate their own source files, so equivalent commands using a different checkout root work. Rebuilding overwrites generated files; preserve manual edits under a different filename first.

## User hardware / viewing constraints

The user has a **2020 Intel i5 MacBook Air** and showed **Blender 4.0.2**. Entering Material Preview caused Blender to close. Assets were created with **Blender 4.3.2** in cloud; do not assume full compatibility or local GPU performance is verified.

The latest character file starts in **Solid shading → Color: Texture**, with diffuse image nodes selected and relationship lines hidden. This shows base-color maps without the full material-preview shading. PNG previews are the reliable visual reference when local shader preview is unstable. The trailer's procedural detail is visible in its renders, not in simple flat-color viewing.

Do not repeat the earlier confusing keyboard-shortcut advice. Prefer clear menu/toolbar instructions and confirm the user's Blender version before suggesting version-specific controls.

## Concept references

See [concept-art/README.md](concept-art/README.md). The most recent sheet, [park-life-home-building.png](concept-art/park-life-home-building.png), shows park complaints, home life and a simple grid-based build mode. The [overview](concept-art/park-management-overview.png) depicts six residential lots plus an office. Both are generated mockups of proposed features, not screenshots.

The older notes in `docs/research/` are recalled, explicitly unverified background. External source access was blocked when those notes were written; no complete episode-by-episode research was completed. This limitation must not be silently promoted into verified research by a later chat.

## Recommended next milestone

When the user requests implementation, a practical starting slice is:

1. Create a minimal Godot 4 project using Compatibility rendering; confirm the available Godot version and test on the user's target hardware early.
2. Import the trailer and resident GLBs; verify scale, textures, rig, roof/interior visibility and object count. Create reusable trailer and character scenes.
3. Build one flat gravel lane and three occupied lots using repeated assets and a small number of props.
4. Add overhead pan/orbit/zoom, click selection, click-to-move and simple navigation.
5. Add one resident interaction: collect rent, update a visible balance and save that state.
6. Then expand to six lots, a basic repair/complaint, resident routines and a small budget UI.

Do not claim those steps have been implemented. Multiplayer, deeper social simulation, arbitrary roads/terrain and unrestricted building require separate substantial work. No exact schedule, engine budget or supported player count has been agreed.
