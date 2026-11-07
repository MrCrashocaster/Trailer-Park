# First playable prototype — proposed scope

## Confirmed direction and status

The user wants the first prototype to be substantial and well developed. The previous recommendation of three lots, basic placement and a budget is superseded as the first delivered prototype. Small technical tests can be used during development, but they are not the requested playable milestone.

Confirmed requirements are Godot, iOS and Android, multiplayer for approximately 2–4 people, and retaining the existing trailer. The character assets were rejected and removed. The latest gameplay discussion explores cooperative Cities: Skylines-style park building and management. This plan assumes that direction; its particular features and content counts are recommendations, not a finalized feature contract.

Nothing in this plan is implemented yet. There is no Godot project, mobile build, simulation or networking code in the repository.

## Playable experience

Players develop a shared trailer park from its initial occupied section into a larger community. They lay out expansion areas, connect services, attract households, collect rent, maintain buildings and recover from setbacks. Growth should create tradeoffs: adding lots increases revenue potential but also service demand, maintenance obligations and financial exposure.

The prototype should support a complete cycle of establishing services, attracting tenants, earning income, expanding, encountering problems and recovering. Several players should have useful work available at the same time.

## Proposed content target

- One detailed, expandable map with several road branches and distinct sections, rather than a single lane.
- Approximately **24–40 residential lots at developed capacity**. This is a proposed content target to validate on mobile devices, not a measured limit or a requirement to render every furnished interior at full detail simultaneously.
- A smaller occupied starting section, empty development space and purchasable expansion parcels.
- The approved trailer as the initial housing asset, with proposed exterior/yard variations that preserve its established style.
- A park office, utility facilities and a small selection of service or income buildings, such as a laundromat, maintenance shed and convenience store. These assets do not exist yet.
- Ground surfaces, fences, lighting, signs, vegetation and yard clutter sufficient to make the park feel inhabited. Existing concept images are visual references, not ready-made assets.

## Connected management systems

| System | Expected first-prototype behavior |
| --- | --- |
| Roads and lots | Create connected road segments and intersections, lay out lots, preview access and costs, rotate/place trailers, and remove or relocate eligible structures. |
| Utilities | Supply power, water and sewage service. Capacity, connectivity and operating costs affect which lots are viable. Show clear service overlays and shortage warnings. |
| Basic services | Track trash collection and maintenance coverage, facility capacity, recurring expenses and upgrade effects. |
| Housing | Households move into viable vacant lots and may leave if rent or conditions become unacceptable. Track occupancy, affordability, satisfaction and complaints without requiring Sims-style personal-life control. |
| Economy | Shared treasury, rent income, configurable rent, construction costs, recurring bills, maintenance spending and a simple loan option. Explain cash flow and upcoming expenses. |
| Condition and repairs | Buildings and infrastructure develop maintenance needs. Players prioritize repairs and upgrades, with visible costs and service consequences. |
| Progression | Unlock additional land or facilities through understandable park milestones, with several useful projects available concurrently. |
| Situations | A limited authored set of connected problems, such as utility failures, illegal dumping, late rent and an unauthorized business. Each offers choices with budget or satisfaction consequences. |

Resident and vehicle visuals can be added later through a separate asset decision. Do not restore the rejected character models or make them a prerequisite for this management prototype. Household simulation can initially be represented through buildings, records and UI feedback.

## Multiplayer experience

- Private shared parks for 2–4 players, with a simple join flow and independent cameras.
- Simultaneous building and management, with visible placement plans and clear feedback when another player is editing the same object.
- Optional responsibilities rather than mandatory supervisor/resident jobs. Everyone should have meaningful access to park management.
- Shared funds, with configurable spending permissions or approval for major purchases, loans and demolition. Routine actions should remain quick.
- One shared clock with agreed pause/speed controls. The recommended default is to save and suspend simulation when the last player leaves; continuous offline simulation is not required by the user.
- Server-controlled construction, finances and simulation results. Simultaneous purchases must not overspend funds or duplicate objects; late joiners must receive the current park state.
- Saving, leaving, joining an active park and reconnecting after an interruption, including recovery of committed construction and financial actions.

Hosting and account-service choices remain implementation decisions; persistent multiplayer hosting has not been provisioned.

## Mobile presentation and usability

- Touch camera controls for pan, zoom and rotation, with clear separation from placement gestures.
- A usable construction catalog, placement previews, access/service indicators and costs shown before committing purchases.
- Readable budget, occupancy, satisfaction, utility-capacity and maintenance views, plus actionable alerts.
- A short guided introduction and visible growth goals that introduce the connected systems.
- Consistent materials, ground treatment, lighting, building selection feedback, sound and menus throughout the playable park.
- Device-appropriate detail and graphics settings. Benchmark repeated trailers and full-park views on iOS and Android before confirming lot capacity or performance targets. The MacBook Air does not define those targets.

## Completion checks

The first playable milestone is ready for review when:

1. Two players, then four, can participate in the same park through the intended internet connection flow on the supported mobile targets.
2. Players can build a connected neighborhood, supply services, attract households, earn rent, expand and respond to a maintenance or financial setback.
3. Multiple players can work concurrently without conflicting construction, inconsistent funds or one player having nothing useful to do.
4. Service failures, household satisfaction and financial results follow from player choices and are explained clearly in the interface.
5. Save/reload and disconnect/rejoin preserve committed park changes and balances consistently.
6. A developed park has been profiled on the selected iOS and Android reference devices, with usable touch controls and readable UI.

These are acceptance goals, not claims of existing validation. No delivery date, hosting budget, supported device list or exact final content count has been agreed.

## Development order

Establish the project, mobile export path, reusable trailer scene and shared-state architecture first. Develop the construction, utility, household and economy systems incrementally, integrating them into the same park. Then complete progression, situations, presentation and the multiplayer/mobile checks above. The first delivered prototype should contain the connected experience described here; an isolated placement or networking test is an internal development checkpoint.
