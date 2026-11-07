# Project handoff — continuing in a new chat

## Read this first

The repository contains **one furnished Blender trailer asset, its exports and builders, preliminary research notes, and concept images**. The user rejected the existing character models and requested their removal, including their builders, previews, textures and source data. **The trailer is the only approved asset so far.** There is **no Godot project, runnable game, networking implementation or gameplay code yet**. A concept image's interface and actions do not demonstrate implemented systems.

The repository is `MrCrashocaster/Trailer-Park`, on branch `main`. Earlier commits contain the rejected resident asset; do not restore it as an approved character.

The user requested that completed changes be committed and pushed to GitHub by default. See `AGENTS.md` for the project workflow.

## What the user wants

- An original game inspired by the broad atmosphere of Trailer Park Boys, with legally distinct characters, dialogue, setting, branding and stories.
- The earlier direction combined Cities: Skylines-style planning/finances with The Sims-style individual residents and homes. The latest discussion explores a **cooperative Cities: Skylines-style trailer park builder and management game** without Sims-style personal-life control. Final gameplay scope remains to be settled.
- The user confirmed **iOS and Android apps built with Godot**. Game design and performance targets should reflect mobile devices. The user's MacBook Air is not a game performance constraint; minimum supported mobile devices remain undecided.
- The earlier playable-supervisor idea is unsettled. The user asked what happens if nobody wants that job, then explored shared park management without Sims-style character control. Do not require one player to take the supervisor role.
- Multiplayer is required. The user clarified a working target of **2–4 people in one game**. The latest proposed arrangement is shared park planning and management with independent cameras and optional responsibilities. Permissions and persistence remain proposals or undecided; the player target has not been benchmarked.
- The user explicitly wants the **first prototype to be substantial and well developed**, rather than the previously proposed small three-lot demo. See [FIRST_PROTOTYPE.md](FIRST_PROTOTYPE.md) for a proposed expanded scope. Its exact feature list and lot count are recommendations, not confirmed requirements.
- The visual tone is grounded, shabby, mundane and funny: faded siding, cramped yards, worn furniture and cars, scruffy residents, petty schemes, grudges and bad judgment. Earlier wholesome repair-business concepts and a cinematic concert concept were rejected as missing the tone.
- The user explicitly requested removal of the existing character models and said they only like the trailer so far. No replacement character asset is approved or requested.
- Concept art must be honest about what can actually be built. Reuse assets efficiently and validate the requested larger park on mobile hardware; do not treat image-generated foliage or UI as existing production work.

## Current working design / recommendations

These are proposals discussed with the user, not a final feature contract:

- Independent angled overhead 3D cameras with pan, rotation and zoom, adapted for touch input.
- Shared road/lot planning, trailer placement, utilities, services, rent, maintenance and expansion.
- Residents could be simulated as households with occupancy, income, satisfaction and complaints; individual character control and detailed personal-life systems are not settled requirements.
- Park budgets and rent fund maintenance and improvements. Planning and service decisions affect household satisfaction and park reputation.
- Visible construction plans, simple spending permissions and shared time controls could support cooperation. No mandatory player jobs have been agreed.
- Roof hiding, interior furnishing and unrestricted building remain optional proposals; the trailer's existing interior can be retained without requiring those gameplay systems.
- Godot is the confirmed engine for iOS and Android. Godot 4 was previously recommended; the exact version and renderer should be selected and tested against the mobile targets. The earlier laptop-based Compatibility renderer recommendation is superseded. No engine project has been created or benchmarked.
- Prove a two-player shared park early, then test up to four players. Build ownership and shared state into the initial architecture. Those internal checks do not replace the requested substantial first playable milestone.

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

## Local Blender viewing notes

These notes concern local asset viewing only. They do not set the game's device requirements or rendering budget.

The user has a **2020 Intel i5 MacBook Air** and showed **Blender 4.0.2**. Entering Material Preview caused Blender to close. Assets were created with **Blender 4.3.2** in cloud; do not assume full compatibility or local GPU performance is verified.

PNG previews are the reliable visual reference when local shader preview is unstable. The trailer's procedural detail is visible in its renders, not in simple flat-color viewing.

Do not repeat the earlier confusing keyboard-shortcut advice. Prefer clear menu/toolbar instructions and confirm the user's Blender version before suggesting version-specific controls.

## Concept references

See [concept-art/README.md](concept-art/README.md). The most recent sheet, [park-life-home-building.png](concept-art/park-life-home-building.png), shows park complaints, home life and a simple grid-based build mode. The [overview](concept-art/park-management-overview.png) depicts six residential lots plus an office. Both are generated mockups of proposed features, not screenshots.

The older notes in `docs/research/` are recalled, explicitly unverified background. External source access was blocked when those notes were written; no complete episode-by-episode research was completed. This limitation must not be silently promoted into verified research by a later chat.

## Requested first playable milestone

The earlier small three-lot prototype recommendation is superseded. The user wants a substantial first prototype with a developed management experience. [FIRST_PROTOTYPE.md](FIRST_PROTOTYPE.md) proposes an expandable park with approximately 24–40 lots at developed capacity, connected construction/utilities/housing/finance systems, maintenance situations, progression, usable touch UI, cooperative multiplayer and saving/reconnecting. The detailed features and counts remain proposals; no tested lot capacity is established.

Implementation should still establish Godot/mobile exports, the reusable trailer scene and multiplayer shared state early, then integrate the management systems, content and presentation. Small networking or placement tests are internal checkpoints, not the requested first delivered prototype. Character imports are not required or approved.

Do not claim those steps have been implemented. Multiplayer, management simulation, roads/terrain and building tools require substantial work. No exact schedule, hosting budget, minimum device list or final content count has been agreed; 2–4 players is the working target, not a tested capacity.
