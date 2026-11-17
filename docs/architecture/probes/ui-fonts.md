# Probe P3: UI Static Fonts

Run: `/opt/homebrew/bin/godot --headless --path godot -s res://tools/probes/probe_ui_fonts.gd`

## Result: PASS (0 failures)

All seven static UI TTFs under `godot/assets/fonts/` and the bake input `tools/ui_bake/fonts/CinzelDecorative-Black.ttf` are installed with `OFL.txt`, credited in `godot/CREDITS.md`, and imported with `antialiasing=1`, `hinting=1`, `multichannel_signed_distance_field=false`, and `allow_system_fallback=false`.

### Character coverage (`cmap` / `FontFile.has_char`)

Required set checked: ASCII (`0x20..0x7E`), Latin-1 Supplement (`0xA0..0xFF`), all characters occurring in `godot/data/geography/*.json` names (161 unique characters including all European Latin Extended-A diacritics), `− · × %` on all fonts, and `→ ↑ ↓` on body/heading fonts.

| Font | Required missing | Latin Extended-A (`0x100..0x17F`) missing | `lnum` + `tnum` |
|---|---|---|---|
| `Cinzel-Bold.ttf` | 0 (display set; lacks `→ ↑ ↓`) | 25 (`Ĉ ĉ Ĕ ĕ Ĝ ĝ Ĥ ĥ Ĩ ĩ Ĭ ĭ Ĵ ĵ ĸ ŉ Ŏ ŏ Ŝ ŝ Ũ ũ Ŭ ŭ ſ`) | — |
| `Alegreya-MediumItalic.ttf` | 0 | 1 (`ŉ`) | yes |
| `AlegreyaSC-Bold.ttf` | 0 | 2 (`ŉ ſ`) | yes |
| `AlegreyaSans-Regular.ttf` | 0 | 2 (`ŉ ſ`) | yes |
| `AlegreyaSans-Medium.ttf` | 0 | 2 (`ŉ ſ`) | yes |
| `AlegreyaSans-Bold.ttf` | 0 | 2 (`ŉ ſ`) | yes |
| `NotoSans-Regular.ttf` | 0 (fallback set; lacks `→ ↑ ↓`) | 0 | `tnum` |
| `CinzelDecorative-Black.ttf` | bake input (`HEXA` covered) | 25 | — |

### Tabular digits, Cinzel tracking, and fallback

- **Tabular digits** (`FontVariation` with `lnum=1`, `tnum=1` via `TextServer.name_to_tag`): `"1111"`, `"0000"`, and `"8888"` measure identically (`31.00 px` at 16 px in Alegreya Sans Regular/Medium/Bold; `29.00 px` at 16 px in Alegreya SC Bold).
- **Cinzel tracking** (`spacing_glyph = roundi(size * em)`): `"GENOA"` measures `62.00 px` -> `70.00 px` at 16 px (`0.10 em` = 2 px), `78.00 px` -> `90.00 px` at 20 px (`0.14 em` = 3 px), `58.00 px` -> `66.00 px` at 15 px (`0.14 em` = 2 px).
- **Fallback with system fallback disabled**: `Cinzel-Bold` alone returns `has_char(0x0108) == false`; adding `NotoSans-Regular` to `FontVariation.fallbacks` resolves `U+0108` (`true`) while `U+4E2D` remains unmapped (`false`).
