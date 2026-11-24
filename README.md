# Pale Sovereign Origin and Reforged Extension

A Battle Brothers mod collection built around the Pale Sovereign origin and extensions for Reforged. The origin follows a necromancer rebuilding a company with permanent undead, branching progression, original events, skills, artwork, and campaign mechanics.

This repository contains the source and build tooling for four local bundles:

| Bundle | Contents |
| --- | --- |
| `zz_local_integration.zip` | Pale Sovereign origin and cross-mod integrations |
| `zz_local_rules.zip` | Local gameplay rules, including background-specific perks |
| `zz_local_campaign.zip` | Campaign and content mods, including siege content |
| `zz_local_interface.zip` | Interface and utility mods |

The collection was developed for the GOG release of Battle Brothers 1.5.2.3 with Reforged 0.9.3, Modern Hooks 0.7.0, and the other dependencies listed in [Readme.txt](Readme.txt). The existing `Readme.txt` describes a separate prebuilt distribution; its installation instructions and included files do not describe this source repository.

## Source layout

- `integration/`, `rules/`, and `interface/`: maintained mod modules and integrations.
- `patches/`: patches applied by the build.
- `art/`: artwork and reference material.
- `manifest.json`: source archive names, checksums, conflicts, modules, and output bundles.
- `build.py` and `deploy.py`: build and local deployment tools.

## Building

Python 3.11 or later is required. The build also requires the original source ZIP archives listed in `manifest.json`, with matching SHA-256 hashes, in the following path relative to the parent of this repository:

```text
data_removed_mods/整合前_20261120/packages/
```

Those source archives and the game dependencies are **not included** in this repository. The scripts expect the repository to sit alongside that `data_removed_mods` directory; a clone alone is not sufficient to reproduce the bundles. With the required inputs in place, use:

```bash
python build.py audit --profile modular
python build.py build --profile modular
python build.py verify --profile modular
```

Build outputs are written to `dist/modular/`. `deploy.py` is intended for the original local game directory layout and changes installed game files; inspect it and back up saves and existing mods before using it elsewhere.

## License and third-party material

Original material that the copyright holder has the right to license is offered under the [MIT License](LICENSE). This collection also contains third-party mods and modified third-party material; their authors' terms still apply. See [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt) and `manifest.json`. Permission to redistribute or relicense each third-party component has not been verified.

Battle Brothers and Reforged are the property of their respective owners. This is an unofficial fan project.
