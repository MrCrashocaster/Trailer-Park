# Resident 01 — rough resident

A realistic middle-aged resident with a heavier build, patchy stubble, tired under-eyes, flushed cheeks/nose, dirty hands and graying dark hair. Clothing: a faded earthy plaid work shirt with collar/armpit sweat, irregular old spills, dusty worn jeans and muddy/scuffed shoes. Approximately 1.78 m neutral height, Z up, facing -Y.

The anatomical base, clothing proxies, skeleton, weights and underlying image maps are adapted from **CC0 MakeHuman assets**. Project work includes age/weight customization, worn clothing/skin texture treatments, fine eyebrow geometry, hair silhouette edits and inspection poses. See [SOURCES.md](SOURCES.md) for provenance and license evidence. The supplied photo informs the rough, lived-in direction; the face and costume are not a recreation of its performers.

## Files

- `resident_01.blend`: editable skinned model with packed textures; opens in the slouched inspection pose.
- `resident_01.glb`: neutral reference pose with embedded weathered textures and skinning; presentation studio and inspection animation omitted.
- `preview.png`: textured full-body slouched render.
- `preview_face.png`: facial details, stubble and tired skin.
- `preview_back.png`: rear view of the slouched character.
- `preview_reference.png`: neutral A-pose, for judging proportions and garment fit.
- `asset_report.json`: morphology, rig and file scope.
- `build_character.py`: rebuilds the model, exports and renders.
- `weather_materials.py`: deterministic UV-based texture weathering; retains the original normal maps and source images.
- `verify_character.py`: model, inspection-pose, weights, textures, deformation and GLB import checks.

The four `textures/weathered_*.png` diffuse maps hold the actual weathering. Dirt, stains, facial flush, stubble, dusty shoes and faded plaid therefore travel into the GLB. Small procedural skin pores remain Blender-only. The source images remain intact in `source_data/`; generated texture maps can be repainted without altering them.

## View on your MacBook Air

The `.blend` starts in **Solid shading → Color: Texture**, with relationship lines hidden and diffuse texture nodes selected. This lighter viewport shows the image-map dirt and pattern without compiling the full Material Preview shaders that previously crashed on your laptop. Normal maps, subsurface shading and final lighting appear in the PNG renders. If needed, switch Solid Color back to Material for flat colors. File created in Blender 4.3.2; older versions can differ.

The timeline contains two inspection frames:

- **Frame 1:** neutral A-pose for modeling and export reference.
- **Frame 2:** hunched back, dropped chin and uneven lowered arms for the presentation.

These are reference poses, not a gameplay walk or intoxication animation. The GLB is exported before these inspection keys are created, in neutral pose without an animation payload.

For posing, expand CHARACTER in the Outliner, unhide `Resident01_RIG`, select it and enter Pose Mode. It is the 163-bone source FK skeleton with body, finger and facial bone weights, without a dedicated IK/control rig. Clear or mute the inspection action before authoring unrelated poses. Frame 1 is the best starting point.

## Rebuild / verify

```sh
blender -b --threads 4 --python /workspace/Trailer-Park/assets/characters/resident_01/build_character.py
blender -b --threads 2 --python /workspace/Trailer-Park/assets/characters/resident_01/verify_character.py
```

Rebuilding replaces generated files and all four weathered maps. Save manual edits separately. Source data is retained locally; no network is needed for rebuilding.

## Remaining work

This is a character art prototype. No locomotion set, drunken movement system, facial-expression library, IK controls, collision, LODs, dynamic clothing or game integration is included. Body masking and a representative arm deformation are validated; extreme poses and engine-specific retargeting still need review.
