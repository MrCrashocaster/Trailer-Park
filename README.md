# Trailer-Park

A trailer park management/life simulation project with an original cast and setting. The player lives in the park as its supervisor. The working direction combines park planning and finances with residents' individual lives, relationships, complaints and questionable schemes. Multiplayer remains part of the intended project.

**Current state: Blender assets and design concepts. No Godot project or playable game exists yet.**

Start with [the project handoff](docs/PROJECT_HANDOFF.md) when continuing in a new chat. It distinguishes user requests, proposed features and implemented assets.

## Art direction

An angled overhead camera with zoom, rotation and roof hiding is the proposed presentation. Realistic proportions, faded trailers, patchy yards, battered possessions and rough, scruffy residents; ordinary daylight and small personal conflicts. The requested comparison is Cities: Skylines mixed with The Sims, at the intimate scale of a trailer park. Character-driven comedy is important.

![Proposed park overview](docs/concept-art/park-management-overview.png)

The image is an AI-generated concept mockup, not a screenshot. Detailed vegetation, resident behavior and the displayed UI are not implemented.

## Existing assets

- [Furnished single-wide trailer](assets/trailers/weathered_singlewide/README.md): editable Blender model, full GLB, interior/exterior previews and rebuild scripts.
- [Rough resident](assets/characters/resident_01/README.md): realistic skinned character, weathered image textures, neutral GLB, inspection poses, previews and rebuild/verification scripts. Adapted CC0 sources and licenses included.
- [Concept art](docs/concept-art/README.md): mood, interior reference and management/life/build-mode mockups.
- [Show research notes](docs/research/README.md): preliminary recalled knowledge, explicitly unverified; not a completed show research corpus.

## Proposed engine and first milestone

Godot 4 with the Compatibility renderer was recommended for the user's Intel MacBook Air. This is a proposed implementation choice, not an existing setup or a tested performance result.

Recommended first milestone: one supervisor, three occupied lots, overhead camera, roof hiding, click-to-move and one rent-collection interaction. Expand to six lots and simple resident routines after that works. The deeper economy, unrestricted building and multiplayer would follow, with multiplayer ownership considered in the architecture from the beginning.
