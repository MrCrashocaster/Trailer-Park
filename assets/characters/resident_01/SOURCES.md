# Resident 01: asset sources and licenses

The realistic rebuild adapts **existing CC0 MakeHuman anatomy, fitted clothing, hair, eye geometry and image textures**. It is not a wholly original, manually sculpted human or a scan of an actor. Project-specific work assembles and morphs the body, fits garments through their authored proxy data, transfers deformation weights, configures Blender materials, and prepares the model, exports and presentation renders.

## Core anatomy, eyes and deformation data

- Upstream repository: https://github.com/makehumancommunity/makehuman
- Pinned commit: `a8bc2d54ff0ac92e78ff71431b1023eda42bf482`
- Source root at that commit: https://github.com/makehumancommunity/makehuman/tree/a8bc2d54ff0ac92e78ff71431b1023eda42bf482/makehuman/data
- Applicable asset license: **CC0 1.0 Universal**, copied in [source_data/LICENSE.ASSETS.md](source_data/LICENSE.ASSETS.md).
- The upstream [license overview](source_data/LICENSE.md) distinguishes AGPL application code from CC0 graphical assets. This character uses the CC0 asset data; the upstream application source code is not included here.

Individual OBJ, morph and material headers explicitly state their release under CC0 in September 2020. Listed release-time copyright holders are **Data Collection AB, Joel Palmius and Jonas Hauquier**. The male morph additionally records original copyright by **Manuel Bastioni (2014)** and the explicit transfer to other team members in 2016. The skeleton metadata identifies the same three release-time holders in 2020 and license CC0; weight metadata identifies them in 2021 and license CC0.

The current builder blends the hm08 basemesh with **0.70 young / 0.30 old** male age targets and a **0.65 maxweight** contribution blended by the same age factors. The applied target-delta formula is:

```text
base
+ 0.700 × caucasian-male-young.target
+ 0.300 × caucasian-male-old.target
+ 0.455 × universal-male-young-averagemuscle-maxweight.target
+ 0.195 × universal-male-old-averagemuscle-maxweight.target
```

The additional age/weight targets were acquired from the same pinned core commit and are recorded in `rough_morph_manifest.json`. The retained `universal-male-young-averagemuscle-minweight.target` is an earlier research candidate and is **not used by the current builder**. Upstream target filenames are retained for reproducibility; these numerical blends are shape parameters, not an exact age or weight measurement. The underlying mesh retains its authored UV layout. Eyes use the upstream low-poly asset and brown iris texture. Skeleton and skin weights derive from the included default MakeHuman data, not an automatically guessed skeleton.

## Textured clothing, skin, shoes and hair

- Distribution/index repository: https://github.com/Makehuman-2/MH2_Asset_Repository_CCO
- Pinned index/license commit: `c4417a850ac35924ab681bea68652cfd1ec79d11`
- Asset pack URL: https://github.com/Makehuman-2/MH2_Asset_Repository_CCO/releases/download/CC0/mh_system_CC0.zip
- Archive length at acquisition: **424,282,645 bytes**.
- License text and release declaration are retained as `source_data/system_assets/UPSTREAM_LICENSE`, `UPSTREAM_README.md` and `UPSTREAM_community_packs.json`.

The repository README declares all assets in these packs CC0. The included skin, clothes and hair companion files also explicitly state CC0 release in September 2020 and identify **Data Collection AB, Joel Palmius and Jonas Hauquier** as the release-time copyright holders. The upstream index commit pins the license/declaration records; it does not make the separately hosted release ZIP immutable. Exact locally included bytes are recorded in the SHA-256 manifest below.

Included system assets are the **middle-age male skin image**, **male_casualsuit01** blue workshirt/belt/jeans, **shoes01** practical shoes and **short02** textured hair. Source proxies, materials, image maps and available shoe weights are retained. These are stock CC0 assets adapted to the morphed resident. Diffuse maps supply actual image texture detail; available tangent-space normal maps supply clothing, hair and shoe surface detail. Additional Blender skin-pore shading is project material work rather than a supplied photographic pore map.

The archive was accessed over verified HTTPS using supported byte-range requests. Entries were decompressed with Python's ZIP reader, which checked each entry's stored CRC. File SHA-256 values are recorded for reproducibility; they are locally calculated checksums, not publisher signatures.

## Project-authored weathering and generated texture maps

The current builder applies additional project-authored UV-space weathering to copies of the CC0 source image maps using `weather_materials.py`. These local alterations add fading and marks to the workshirt/jeans, dirt and scuffing to shoes, uneven skin coloration and stubble, and adjusted hair color. The weathered maps are **derived from the attributed upstream textures**, rather than new independent photographic scans. A separate small eyebrow-color image is locally generated.

The generated maps live in `textures/`, outside `source_data/`:

- `textures/weathered_clothes.png`
- `textures/weathered_skin.png`
- `textures/weathered_shoes.png`
- `textures/weathered_hair.png`
- `textures/eyebrow_color.png`

They are rebuilt locally and used as image textures by the character materials. They are not upstream files and are intentionally excluded from the **included source-data checksum manifest**. Additional fine procedural skin-pore shading remains a Blender material effect. Source image maps are retained without replacing them with these project-derived versions.

## Included files and checksum scope

[source_data/INCLUDED_SHA256.json](source_data/INCLUDED_SHA256.json) lists **only the files actually included under source_data**, with byte sizes and SHA-256 values. It excludes itself to avoid recursive hashing. Recreate it if any source file is added or altered.

`SOURCE_MANIFEST.json`, `rough_morph_manifest.json` and `system_assets/EXTRACTION_MANIFEST.json` preserve the broader acquisition records, which may mention candidates that were downloaded during research but are **not** included in this character folder. The included-only manifest and inventory below define this deliverable's source contents. Temporary cloned repositories, downloader scripts, other outfit variants, and young-male skin candidates are not included.

### Core files and acquisition records

- `LICENSE.ASSETS.md`
- `LICENSE.md`
- `SOURCE_MANIFEST.json`
- `base.obj`
- `brown.mhmat`
- `brown_eye.png`
- `caucasian-male-old.target`
- `caucasian-male-young.target`
- `default.mhskel`
- `default_weights.mhw`
- `low-poly.mhclo`
- `low-poly.obj`
- `rough_morph_manifest.json`
- `universal-male-old-averagemuscle-maxweight.target`
- `universal-male-young-averagemuscle-maxweight.target`
- `universal-male-young-averagemuscle-minweight.target`

### System-pack files and license records

- `system_assets/EXTRACTION_MANIFEST.json`
- `system_assets/UPSTREAM_LICENSE`
- `system_assets/UPSTREAM_README.md`
- `system_assets/UPSTREAM_community_packs.json`
- `system_assets/clothes/male_casualsuit01/male_casualsuit01.mhclo`
- `system_assets/clothes/male_casualsuit01/male_casualsuit01.mhmat`
- `system_assets/clothes/male_casualsuit01/male_casualsuit01.obj`
- `system_assets/clothes/male_casualsuit01/male_casualsuit01_ao.png`
- `system_assets/clothes/male_casualsuit01/male_casualsuit01_diffuse.png`
- `system_assets/clothes/male_casualsuit01/male_casualsuit01_normal.png`
- `system_assets/clothes/shoes01/shoes01.mhclo`
- `system_assets/clothes/shoes01/shoes01.mhmat`
- `system_assets/clothes/shoes01/shoes01.mhw`
- `system_assets/clothes/shoes01/shoes01.obj`
- `system_assets/clothes/shoes01/shoes01_diffuse.png`
- `system_assets/clothes/shoes01/shoes01_normal.png`
- `system_assets/hair/short02/short02.mhclo`
- `system_assets/hair/short02/short02.mhmat`
- `system_assets/hair/short02/short02.obj`
- `system_assets/hair/short02/short02_diffuse.png`
- `system_assets/hair/short02/short02_normal.png`
- `system_assets/skins/middleage_caucasian_male/middleage_caucasian_male.mhmat`
- `system_assets/skins/middleage_caucasian_male/middleage_lightskinned_male_diffuse.png`
