Copyright © 2021-2026 [Linden](https://github.com/thelindat), [Luke](https://github.com/LukeWasTakenn), [Dunak](https://github.com/dunak-debug) and contributors

The original source code is available at: https://github.com/overextended/ox_inventory

This repository is a modified version of the original work (see "klsh fork" at the end of this file).

---

This project is licensed under the [GPL‑3.0](https://www.gnu.org/licenses/gpl-3.0.en.html) or later. A complete copy of the license is included in the [LICENSE](./LICENSE) file.

When incorporating this work into your own project, you must:

- Clearly credit the original authors and provide a link to the original project.
- Preserve all copyright, license, and attribution notices, including this NOTICE file.
- Document any modifications made to the original work.
- Include the full text of the GPL‑3.0 license with your distribution.
- License modified versions of this project under the GPL‑3.0 or later.

If this project has been useful to you, please [consider sponsoring its continued development](https://ko-fi.com/thelindat).

---

## Frequently asked questions

### Can I redistribute modified versions of this project?
You may fork, modify, and redistribute this project, provided you comply with the license and preserve the same rights and freedoms for downstream recipients.

### Am I allowed to encrypt this project?
Recipients of this project must receive the complete corresponding source code and be able to install, motifiy, build, and run it. Distributing the project in a form — including through encryption, obfuscation, or other technical measures — that prevents recipients from exercising the rights granted by the license is not permitted.

### Can I sell a modified version of this project?
Commercial distribution is permitted, provided you comply with the terms of the license. However, recipients retain the same rights and freedoms under the license and may freely redistribute modified versions.

## klsh fork

This repository is a modified version of ox_inventory.

Modifications copyright © 2026 Cauã (klsh) and contributors, licensed under the GPL‑3.0 or later, the same license as the original work. The original authors keep the copyright of the original code.

What was modified is documented in [CHANGELOG.md](./CHANGELOG.md) and [README.md](./README.md); in the source, changes to the original code are marked with `-- klsh:`. Files under `modules/grid/`, `modules/equipment/`, `modules/appearance/`, `data/grid.lua`, `data/equipment.lua` and `tests/` are new in this fork.

Equipment slot icons (`web/images/clothing_*.png`) are rendered from Material Design Icons by
Pictogrammers (https://pictogrammers.com, Apache 2.0), except `clothing_pants.png` (drawn for this fork).

The interface fonts bundled in `web/build/*.woff2` (Inter, Rajdhani and Roboto, Latin subset) come from the
Fontsource packages (`@fontsource/inter`, `@fontsource/rajdhani`, `@fontsource/roboto`) and are licensed under the
SIL Open Font License 1.1 (https://openfontlicense.org). Inter: The Inter Project Authors. Rajdhani: Indian Type
Foundry. Roboto: The Roboto Project Authors.
