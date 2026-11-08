# First playable prototype — implementation record

## Scope and status

The user requested a substantial first prototype and authorized building the expanded cooperative park-management plan. This document records that target and the implemented source. The Godot project is now runnable; the earlier statement that no project or gameplay exists is superseded.

The game targets iOS and Android, uses Godot 4.7.2 and supports approximately 2–4 players in one park. It follows the cooperative Cities: Skylines-style direction, with shared planning and finances and independent cameras. The normal start has eight occupied homes; the developed park can contain forty homes across six land parcels. Rejected character models remain removed.

A runnable source build and successful local tests do not complete the physical-mobile-device and public-network acceptance goals below.

## Connected systems

| System | Current implementation |
| --- | --- |
| Roads and lots | Grid-based connected road paths, intersections, placement previews, rotated footprints, access validation, eligible demolition and building relocation. Multi-cell road purchases apply atomically. |
| Land and housing | Six purchasable adjoining parcels, approved trailer exteriors, occupancy, household affordability, satisfaction and move-in/move-out. Forty-home planning limit. |
| Utilities | Power, water and sewage capacity supplied through the entrance-connected road graph. Working power is required by water/sewage facilities. Facility wear and upgrades affect availability. |
| Services | Trash and maintenance capacity. Maintenance coverage slows household building wear. These are management simulations, not moving collection/repair vehicles. |
| Economy | Shared treasury, adjustable daily rent, operating costs, business income, arrears, loans, interest, repayments and transaction history. |
| Maintenance | Building condition, quoted repairs, facility/home upgrades and persistent service failures affecting households. |
| Progression | Household milestones unlock development grants and the corner store. Land ownership, lot count and satisfaction goals are visible. |
| Situations | Authored illegal-dumping, unauthorized-business, late-rent and pump-maintenance situations with cost and satisfaction/reputation consequences. |
| Multiplayer | ENet host/client or dedicated-server sessions, independent cameras, validated authoritative actions, late joining, reconnecting, construction-plan visibility and optional spending approvals. |
| Persistence | Versioned JSON state including generator state, transactional load validation, authority-only saves, autosaves and backup recovery. |
| Interface | Construction catalog, inspector, finance/services/households/events/growth panels, overlays, session controls, guidance, interface sounds and touch camera gestures. |

## Content and presentation

The world has several connected road branches at developed capacity, housing and utility/service facilities, a park office, laundromat, corner store, yards, trees, fences, lights, signs and surrounding landscape. Facilities and grounds use prototype geometry. There is one approved trailer source asset with cached exterior/yard variants; the furnished master is retained unchanged.

The game batch recovers the source builder's authored palette where procedural GLB materials omitted their base colors, retaining the faded siding/trim colors through correctly converted linear vertex colors. The Blender renders' procedural weathering is not baked into the GLB. The project contains no replacement character models, individual resident life-control system, walking population or simulated road traffic. Indoor furnishing tools, roof-hide interactions, arbitrary terrain sculpting and unrestricted curved-road construction are not implemented.

## Multiplayer boundaries

A graphical host plus three friends, or four clients on a dedicated server, share one park and budget. Sessions use a reachable IP/hostname, UDP port and optional shared access code. Normal building actions remain quick; optional spending policy queues major client requests for the session manager. Final approval still checks the current park state and funds.

There is one authoritative shared simulation speed; group time voting is not implemented. Dedicated servers suspend progression when empty; a background economy that runs forever without players is not required. There is no automatic matchmaking, relay/cloud provisioning, host migration or synchronized player camera. Internet reachability and reliable play across physical mobile networks need separate deployment and testing.

## Validation completed locally

- **312 simulation checks** pass under Godot 4.7.2.
- A genuine forty-home fixture is built through commands, with explicit test-only funding. All forty households are occupied and supplied after thirty simulated days. JSON restore and thirty more days preserve a viable park.
- **65 world integration checks** pass. The imported trailer has finite meter-scale geometry; all four rotations fit their logical lots. The source's 1,170 mesh nodes are reduced to a shared single-surface exterior batch and cached yard variants. Selection, HUD callbacks, GUI input cleanup and camera-driven preview refresh are exercised.
- The HUD suite passes **33 integrated checks** for construction categories, management/session controls and commands against the real autoloads, including the latest verified layout changes.
- ENet tests use real server/client processes to check shared state and authority rather than a mocked transport. Refer to their latest generated report after changing networking.

The developed fixture proves placement/simulation capacity on the tested engine. It does not establish the eventual mobile frame-rate, memory budget or minimum supported device.

## Acceptance goals that remain device/deployment work

- Install and run signed builds on physical iOS and Android devices.
- Verify touch comfort, text readability, thermal/memory behavior and a developed park's frame rate on selected reference devices.
- Play together across the intended public-internet hosting path, including interruption/reconnection on actual mobile networks.
- Evaluate whether 2–4 players have useful simultaneous projects and whether the economy/progression supports satisfying sessions.
- Review the new prototype facilities and surroundings against the approved trailer's art direction and refine their quality.

No fixed delivery date, hosting budget or supported physical-device list has been agreed. See [PLAYTEST.md](PLAYTEST.md) for the concrete walkthrough and [PROJECT_HANDOFF.md](PROJECT_HANDOFF.md) for architecture and source-asset notes.
