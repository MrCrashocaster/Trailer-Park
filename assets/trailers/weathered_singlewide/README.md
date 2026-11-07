# Weathered single-wide trailer A

Original furnished trailer for the neighborhood game. Blender 4.3.2, meters, Z up. Nominal footprint: 12 × 3.5 m. Root origin is ground level at the shell center. No third-party assets.

## Files

- `trailer_singlewide_a.blend`: editable exterior and furnished interior, saved in cutaway presentation mode.
- `trailer_singlewide_a.glb`: full exterior and interior, including roof and facade. Presentation objects excluded. Procedural wear is not baked; PBR base colors export.
- `preview.png`: current interior cutaway rendered in Blender Cycles.
- `preview_exterior.png` and `trailer_singlewide_a_exterior.blend`: preserved exterior-only version before the interior update.
- `build_asset.py`: rebuilds exterior, calls interior builder, exports and renders.
- `build_interior.py`: adds interior, cuts real openings, organizes cutaway collections, exports and renders. Do not run on an already furnished file.
- `asset_report.json`: geometry counts and limitations.

## Layout

Living area at the left end; kitchen/dining in the middle, beside the existing entrance. On the right, a continuous 0.90 m rear hallway starts beside the fridge and serves the bathroom, spare room and main bedroom. No transverse wall at the hallway entrance. Wall openings are 0.77 m for the bathroom and 0.80 m for bedrooms; inset jambs reduce clear widths to approximately 0.705 m and 0.735 m. Interior doors are open openings, not animated doors. The exterior door remains static and closed.

Furniture includes sofa, recliner, TV, coffee table, cabinet/counter run, sink, stove, fridge, dining table/chairs, shower, toilet, vanity, single and double beds, desk and wardrobe. Small props include receipts, coffee mugs, packing boxes and secondhand stereos.

## Cutaway controls

Within ASSET, the two CUTAWAY collections retain the roof/front facade and upper partition pieces. They are hidden from rendering and individually hidden in the saved viewport. To restore the complete building: enable rendering for both collections and unhide their objects (Alt+H in the viewport). The GLB was exported before these visibility changes, so it contains the complete model.

INTERIOR contains furnishings, floor, wall segments, and clipped siding. Doors/windows have actual shell openings. Window panes are opaque dusty material, not clear transmission glass. Presentation lights, ground and camera remain outside the asset hierarchy.

This is an editable art prototype with many separate objects. It has no collision, LODs, baked atlas, interaction scripts, navigation mesh or multiplayer integration. Merge/batch and build engine-specific collision before production use.

## Rebuild

```sh
blender -b --threads 4 --python /workspace/Trailer-Park/assets/trailers/weathered_singlewide/build_asset.py
```

Replaces generated current deliverables. Save manual edits separately first. Preserved exterior-only files are not changed by this rebuild command.
