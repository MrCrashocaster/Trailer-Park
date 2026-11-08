# Playtest guide

## Run the source

Use Godot **4.7.2**. Import `project.godot` and run the project, or launch from the repository root:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

On other systems, substitute the installed Godot 4.7.2 executable. Godot imports the original GLB automatically; the project disables Blender import so no local Blender rebuild is needed.

Choose **Continue to the park**. Normal play begins with eight occupied homes, a connected road/utility network, $28,000, and the western north/south parcels. The first visit opens guidance explaining controls and the management loop.

## Controls

- Mouse: left-click selects/places; drag with the Select tool or middle-drag pans; wheel zooms; right-drag orbits.
- Touch: tap selects/places; drag with Select pans; two fingers pinch/orbit/pan.
- Keyboard: WASD/arrows pan, Q/E orbit, R rotates construction, F returns the camera home, Escape cancels/closes the active tool or panel.
- Camera buttons offer zoom/orbit/home without gestures. Landscape orientation gives the intended management layout.
- Choose a construction category and item, inspect its cost and footprint, then place it on owned land. Select tools/management panels independently of other players.

Road construction supports a grid-aligned drag path. A road path must remain connected between neighboring cells and fit owned, unoccupied land. Existing road cells are skipped rather than charged again; invalid paths do not partially spend money or build segments.

## First expansion walkthrough

1. Pause the shared simulation while reviewing the starting park. Check the top bar's household count, treasury and satisfaction.
2. Open **Manage → Services**. The initial power, water and sewage facilities each serve twelve homes; trash and maintenance serve sixteen. Inspect a trailer to check its condition and supplied services.
3. Open **Growth** and buy **Parcel 5**, the southern middle parcel adjoining the starting park. Use the Land parcels overlay to see its boundary. Display parcel numbers run west to east: 1–3 north, 4–6 south.
4. Extend the central entrance road east into the new parcel. Add a southern branch and place four trailers with a footprint edge next to the entrance-connected road. A road that is visually nearby but not orthogonally connected does not carry service access.
5. Resume at 1× or a faster shared speed. New households arrive over simulated days when access, utilities, rent and condition are viable. Check the household and service panels; the new homes should bring the park toward twelve occupied lots.
6. Upgrade power, water and sewage before increasing demand beyond their capacity. Upgrade/add trash and maintenance facilities as the park grows. Service overlays show which homes receive supply.
7. Build a laundromat. Once twelve homes are occupied, the corner store unlocks. Inspect projected daily income, expenses and net flow in **Money**; shops depend on an operating park and connected access.
8. Inspect a worn home and arrange repairs. Compare the quoted price, treasury change and restored condition. An occupied home can be relocated to a road-connected site; it cannot simply be demolished.
9. Respond to a management situation in **Manage → Problems** when one appears. Choices change cash, condition, happiness or reputation. Watch how deliberately high rent or neglected essential services affects satisfaction and occupancy over several days.
10. Save through **Menu → Park & save**, make a visible construction change, then load the saved park to check restoration. Saving/loading affects the shared park when hosting.

The initial economy is deliberately viable. Expansion, utility capacity, rent choices and maintenance create the decisions. Loans provide extra construction funds but add daily interest; requests still need to fit the credit limit and available cash.

## Cooperative play

Use two instances first, then four. Each player has an independent camera and menus. A player host counts as one of four managers; a dedicated server can host four client managers.

For a same-machine test, open **Host with friends** in one instance with port 27840. In the others choose **Join a park**, enter `127.0.0.1`, the same port and any shared access code. Across a LAN, use the host's LAN address. Across the internet, use a reachable server address and appropriate UDP forwarding/firewall configuration.

A dedicated server can be launched with:

```sh
sh tools/run_server.sh --port=27840 --save-slot=friends --access-code=your-code
```

The server restores its selected save if present. The last player leaving suspends its simulation. Internet matchmaking/relay services and host migration are not provided by this prototype.

Try these actions:

- Work in different park areas; confirm each player sees committed roads/buildings and the same treasury.
- Plan in the same location; verify construction-plan outlines are visible and conflicting purchases are rejected without duplicate buildings or extra spending.
- Have one player manage services while another develops housing. Confirm capacity and household feedback reach everyone.
- If enabled, queue a purchase above the spending threshold, approve/deny it as manager, and verify funds are checked again at approval time.
- Join after several changes, then disconnect/rejoin. Verify the current park is restored rather than the client's earlier copy.
- Save on the authority and confirm clients cannot overwrite its save. A host leaving ends that hosted connection; use a dedicated server if the park should remain reachable independently.

For protocol, policy and deployment details, see [MULTIPLAYER.md](MULTIPLAYER.md).

## Save files

The default slot is `park`; `--save-slot=friends` selects another slot. Saves are under `user://saves`, normally on macOS:

```text
~/Library/Application Support/Godot/app_userdata/Trailer Park/saves/
```

Each file contains versioned park state and spending policy. The authority writes saves; backup recovery handles a corrupt primary when a valid backup exists. Generated test saves use isolated test slots. Camera and menu state remain local.

## Automated checks

Run from the repository root:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_simulation.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_world.tscn -- --skip-welcome
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_hud.gd
python3 tools/test_network.py --report test-results/network.json
```

The simulation suite currently passes 312 checks; world integration passes 65. The HUD suite passes 33 checks, including the latest verified layout changes. Check the latest logs after changing these systems. The network harness launches actual ENet processes and reports state agreement, authority, concurrent actions, malformed/replayed requests, connection handling and persistence behavior.

For a forty-home debug park with all six parcels, use:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --developed --skip-welcome --no-autosave
```

This is an explicit fixture with a development grant, not the normal starting economy. It is useful for full-map rendering and UI inspection; its occupancy test is not a physical-mobile performance result.

## Mobile/export boundaries

`export_presets.cfg` contains Android, iOS and macOS presets. Generated builds live under ignored `builds/`; local SDK/template downloads live under ignored `.tools/`. Confirm the latest export log and generated artifact before calling any platform export successful. A package or Xcode project alone does not demonstrate a signed installation or an App Store/Play Store release.

Physical iOS/Android installation, touch usability, developed-park performance, minimum supported devices and internet play on actual mobile networks still need verification. The in-engine trailer recovers its authored base-color palette from the source builder where GLB procedural colors were omitted; prototype facilities/landscaping are additional geometry, and Blender's rendered procedural weathering is not baked. There is no walking population, service-vehicle traffic, interior interaction system or automatic cloud service to test yet.
