# Hexa UI design: "Studiolo"

Snapshot of the approved look and the screens built on it. Decided 2026-11-17 with the owner ("the look and style is amazing").
Status: design approved, nothing built in Godot yet. The clickable mockup and its tested CSS kit are in `studiolo/`
(see section 11). The spec and plan that build it are `docs/architecture/ui-style-and-feedback-spec.md` and
`docs/architecture/ui-style-and-feedback-plan.md`. The screens added after this snapshot (season report, upgrade
preview, insights) are in `game-feedback-screens.md`.

## 1. The brief, and why it changed twice

The UI is part of a **game**, not an app. Two earlier directions were rejected:

| Direction | Verdict | Why |
|---|---|---|
| The first dark kit (blue-grey panels, gold headings, `docs/design/ui/01_ui_kit.png`) | replaced | Generic game-UI look; no sense of the age. |
| "Chancery sheet" (flat ink on vellum, ruled like a ledger) | rejected by the owner | Reads as a polished app. Wanted richer textures and shapes, in the manner of Civilization's menus. |
| **Studiolo** | **approved** | Rich, tactile, game-like, and of 1480. |

Owner's words that set the direction: "It is not an app but a game. Focus on providing richer textures and shape
designs. Follow some of the Civilisation concepts and menu styles. Provide a richer, less flat design and texture based
solution that gets closer to game aesthetics."

## 2. Concept

Studiolo, after the walnut-inlay (intarsia) studies of Urbino (about 1476) and Gubbio (about 1480): the UI is the
furniture of a prince's study laid round the map. Frames are **walnut with gilt-bronze fillets and diamond studs**,
fields are **dark tooled leather**, controls are **brass plates and inlaid slots**, titles sit on **crimson velvet
ribbons and pointed walnut cartouches**, and documents are **vellum with a wax seal**. Lapis enamel is the only blue.

**Materials:** walnut, gilt brass, dark leather, vellum, crimson velvet, lapis enamel, vermilion wax, bone key caps.

**Panels are dark.** HUD, menus and options use leather fields with cream text. Vellum is kept for letters only:
confirm dialogs, credits, help, the season report, later events. Reasons:
- The map is bright and saturated; a dark warm frame works like a picture mat and keeps the map the brightest thing on screen.
- Dark fields tire the eye less over hours of play.
- Gilt only reads as metal on a dark ground.
- It is the grammar Civilization V/VI, Crusader Kings and Anno use: dark body, metal trim, shaped headers, one big primary control.

**The rule that keeps it readable:** frames carry the richness, text sits on calm fields. Never put an ornament inside a
text field. Texture amplitude stays under 4 %. Three ornaments only: the stud, the boss, the diamond rule.

**Fallback ("Lapis and gilt"):** same wood, brass and shapes, blue-black leather. Deltas: PANEL_BG `#141d30`,
PANEL_HEAD `#1b2946`, CARD_BG `#0c111c`, TOGGLE `#18233a`, ROW_HOVER `#22304e`, LEATHER `#16233a`.

## 3. Colour

The token names are the existing ones of `ui-and-controls-spec.md` 3.4, so the Theme generator needs no new concepts.
Material tokens are new.

| Token | Value | Use | Token | Value | Use |
|---|---|---|---|---|---|
| BG | `#14100c` | window ground | GOLD | `#e8c15a` | headings, selected edge |
| PANEL_BG | `#221a14` | panel field | GOOD | `#7fc98a` | gains |
| PANEL_HEAD | `#3a2416` | header band | BAD | `#f0806a` | losses |
| CARD_BG | `#15110e` | hover cards, log | WARN | `#f0a850` | warnings |
| LINE | `#6b5637` | rules | INFO | `#8fb8ea` | links, focus |
| TEXT | `#f2e8d0` | text | INK | `#0b0806` | outlines |
| MUTED | `#b9a987` | secondary text | SHADE | `#070504` at 72 % | modal shade |
| FAINT | `#9c8c70` | hints, disabled | ROW_HOVER | `#33271c` | row under mouse |
| BUTTON / hot / off | `#4a3120` / `#5e4029` / `#2a221b` | secondary button | TOGGLE / hot | `#2b221a` / `#382c21` | toggle |
| PRIMARY / hot | `#d9a93a` / `#f0c85a` | End season, OK | DANGER / hot | `#8e2618` / `#ad3420` | Quit, Declare war |

New material tokens: LEATHER `#2a1d15`, WOOD `#4a2f1c`, WOOD_DARK `#2c1a0f`, BRASS `#c9a04a`, BRASS_HI `#f6e3a1`,
BRASS_LO `#7a5a1e`, SLOT `#0e0a08`, VELLUM `#efe3c4`, VELLUM_INK `#2b2219`, VELLUM_MUTED `#5c4d3a`, SEAL `#a3241a`,
LAPIS `#1f3f7a`, VELVET `#5a1420`, GLOW `#ffd98a` at 45 %.

**Contrast (computed against the flat tokens; the bake tool asserts them):**

| Field | Ratios |
|---|---|
| Leather | TEXT 14.1, MUTED 7.4, FAINT 5.2, GOLD 10.0, GOOD 8.7, BAD 6.5, WARN 8.5, INFO 8.3 |
| Card | TEXT 15.4, MUTED 8.1, FAINT 5.7 |
| Slot | TEXT 16.2, MUTED 8.5 |
| Walnut | TEXT 11.9, MUTED 5.3 to 6.3, BRASS_HI 9.6 |
| Button face | TEXT 9.8 (hot 7.7); danger TEXT 7.1 (hot 5.2); gilt plate ink 8.5 (5.9 at the darkest stop) |
| Vellum | ink 12.2, muted 6.4 (9.4 and 4.9 in the darkest blotch) |
| Ribbon / key cap | 10.6 / 12.2 |

The bake tool must assert that FAINT stays at 4.5 or more on the lightest leather texel (`#2f231a` gives 4.6).
**Colour-blind:** GOOD and BAD separate by hue cast only (about 1.2 to 1.4:1 apart in protan and deutan simulation).
They are never used alone: always a sign (+ or -), an arrow or an icon.

## 4. Type

| Role | Font | Use |
|---|---|---|
| Display | Cinzel 600/700/900 | Engraved caps, tracking .10 to .14 em: ribbons, cartouches, menu buttons, the brand. Never below 13 px, never for numbers. |
| Wordmark | Cinzel Decorative 900 | "HEXA" only, baked as one PNG in Godot |
| Section heads | Alegreya SC 700 | GOLD, with a rule |
| Body and numerals | Alegreya Sans 400/500/700 | Lining and tabular figures (`lnum` + `tnum`) |
| Flavour | Alegreya italic | Vellum only |

All are OFL and on Google Fonts, with the Latin Extended glyphs the place names need (Kraków, Poznań, Diyarbakır).
They replace Gelasio and Selawik of spec 3.4. Sizes are the spec's scale plus 1 px (Alegreya Sans has a small
x-height). Open points to assert in `build_theme --check`: the `cmap` and the `tnum` feature of each file.
**Wordmark treatment:** vertical gilt gradient with a dark "horizon" band at 54 %, a 1 px light top edge, a 3 px
dark-bronze extrusion, a soft drop shadow and a 26 px warm glow.

## 5. Shape and material recipes (what the mockup proves)

| Piece | Shape and layers |
|---|---|
| Panel | 13 px walnut band, gilt fillets outside and inside, a diamond stud per corner, leather field with an inner vignette |
| Modal | Panel plus quatrefoil brass bosses (lapis centre) overhanging the corners; velvet swallow-tail ribbon title straddling the top band |
| Vellum modal | Same frame, vellum field, ink text, wax seal at the left |
| Button | Chamfered 6 px, 2 px gilt edge, walnut face: lit top line, 3 px dark lip. Hot: +20 % and inner glow. Pressed: 1 px down, face inverted. Focus: 2 px INFO inner ring |
| Primary | Brushed gilt plate, ink text, dark-bronze edge |
| Danger | Vermilion enamel face, gilt edge |
| Disabled | Flat off-face, pewter edge, FAINT text, lock icon, a MUTED reason line below |
| Menu button | 42 px, pointed (half-hex) ends, Cinzel caps |
| Segmented control | Dark inlaid slot; the selected segment is a raised gilt plate with ink text |
| Switch | Slot track; off: pewter knob left; on: lapis track, brass knob right (position, not colour alone) |
| Slider | Slot groove, gilt fill, brass diamond grabber |
| Key cap | Bone cap, ink text, 3 px lip; waiting: gilt edge |
| Nav list | Leather rows; selected: brass bar left, gold text, a gilt fade |
| Top bar | 40 px walnut plank with a brass moulding and a drop shadow |
| Resource chip | 30 px brass medallion with a two-tone icon, overlapping a dark slot plate; value in TEXT, change in GOOD/BAD |
| Date medallion | 64 px lapis medallion (conic brass ring) hanging from the bar: the year; the season dial is the same piece with four enamel quarters |
| End season | A primary plate with a 64 px medallion; busy: the ring turns; reduce-motion: a static hourglass |
| Minimap | Elongated hexagon in a 4 px gilt rim (a round frame would crop a 16:9 map too much) |
| Hex panel | Panel with a pointed walnut cartouche title, small-caps section heads on rules, a key and value ledger |
| Hover card | Card, 1 px brass, ink line, faint brass inner line; small-caps gold title. No heavy frame: it appears constantly |
| Toast | Swallow-tailed leather banner, brass top and bottom lines, a tone seal dot at the left (plain, good, bad) |
| Progress | Slot channel, brushed gilt fill with glow |
| Confirm | Vellum modal; the countdown number is embossed in the wax seal, which "presses" on open |
| Icons | Woodcut ink line with one flat pigment fill, 16 px (24 to 30 px inside medallions) |
| Arms | Code-drawn heater shield with a brass rim; pennants only on the map |

Hit areas: `clip-path` trims shadows and focus outlines, so the CSS uses inner rings. In Godot every shape is baked alpha.

## 6. Screens (first slice, M1.5) and what later milestones add

Rule: what arrives in a later milestone is **hidden**, not greyed. Greyed with a reason is for a state.

| Screen | Composition |
|---|---|
| Main menu | Full-bleed painted map, warm-graded, drifting 6 % over 70 s. Three static gradients: a dark left third, an oval vignette, a candle glow top right. Column on the left (about x = 270, as Civ VI/VII): the wordmark, "Anno Domini MCDLXXX" in italic, a gilt rule with a diamond, the framed panel of pointed buttons. Wind rose bottom right over the sea with rhumb lines at 15 %. Version bottom right, credits and the note bottom left. First slice: Map sandbox (primary, focused), Options, Credits, Quit. M2 adds New game, M3 Continue and Load game. |
| In play (HUD) | Top bar (map name, mode switch from M2, resource medallions from M4, the year medallion and End season from M3, Layers, keys, menu). Hex panel right. Zoom control and scale bar bottom right, minimap above them from M2. Hover card by the pointer. Toasts bottom centre. Key hints bottom left. F3 debug panel under the bar. |
| Pause | Walnut panel, velvet ribbon "Paused", Resume (primary), Save and Load (M3), Options, Help and keys, Main menu, Quit to desktop (danger), hint line. Map dimmed by the 72 % shade. |
| Options | 860 x 580 modal. Pages: Display, Graphics, Controls, Map, Accessibility, Advanced, About. Footer: "Defaults for this page", Apply. Display changes ask "Keep these display settings?" with a 10 s revert. |
| Help | Three columns of key caps (Move the map, Work on a hex, The window) plus the Mac gesture lines. |
| Confirm | Vellum modal, ribbon title, wax seal countdown, safe choice focused and picked by Esc. |
| Loading | "Building the map" then "Drawing the map 63 %" on a progress channel. |

Details of the options pages, controls, menus and overlays are in `docs/architecture/ui-and-controls-spec.md` (sections 4 to 8).
The look changes only the surface of those screens; the layout, behaviour and milestones stay.

### 6a. Feedback screens (added the same day)

The owner asked that the game explain itself: "End season should open a dialog of the summary of what happened, not just a
toast", "upgrade needs to showcase what the upgrade brings in, plus gains per field... change is super important per
season", and "Civ allows to look into more insights and statistics of the whole economy, trade, diplomacy". Full design,
wireframes and sample strings: `game-feedback-screens.md`. In the Studiolo kit:

| Screen | Look and behaviour | Arrives |
|---|---|---|
| **Season report** (the Chancellor's letter) | After End season, or J. A vellum letter in the walnut modal frame, ribbon "Spring 1480", wax seal with the country's initial, a left nav list with counts, one scrolling body of sections: At a glance (up to five headline chips, largest swing first), Before next season (notices with Go buttons), Treasury (every ducat explained), Goods, Works, People, Your orders, What befell you, Standing. Gains in GOOD_INK with "▲ +", losses in BAD_INK with "▼ −": sign and glyph, never colour alone. Place names are links. Space or Enter begins the next season; a 400 ms guard stops a double Space. Options: Full (default), Brief, Off. | M3 (works, orders, notices), M4 money and goods, M5 people, M6 what befell, M7+ war |
| **Works preview** (build, upgrade, clear) | A large card docked left of the hex panel, map still live, ghost piece and floating labels on the map. Shows what the work **brings** (before to after), a **four-season strip** with the current season edged in gilt, where the gain **lands** (the hex, its ring of six, the country), a before/after **chart of the country's gain per season**, cost and time with ticks, payback, next stages, "Weather not counted". Pin one option to compare. A refusal shows its reason in plain words. Hex panel rows carry delta chips. Runs the same code as the season, so the preview cannot drift. | M4 (needs seasonal output in the economy design) |
| **The Statesman's Study** (insights) | A full screen in the walnut frame, opened by I (L for Economy). Left nav of pages; ink-on-vellum charts, sortable tables, a relations matrix. Only countries you know, rounded numbers. | Economy M4, **new M4.5 "Insights I"** (chart kit, Economy tabs, History, Rankings), People M5, Military M6/M7, Diplomacy M9, Trade M10, Research M11 |

New kit pieces: `VellumSheet`, `DeltaChip`, `SeasonStrip`, `PreviewCard`, `InkChart`, `StudyTable`, `RelationMatrix`, `NavList`;
tokens `GOOD_INK`, `BAD_INK`, `WARN_INK` and five chart inks (iron-gall, lapis, madder, verdigris, ochre), each 4.5:1 or more on vellum.
The numbers in the mockup are examples; the M4 district-economy design sets the real ones. In the map data Genoa is already
level 4, so the Genoa example is 4 to 5; Savona (3 to 4) is the refused case, because Cuneo is a town beside it.

## 7. Motion and sound

- Panels fade and slide 6 px in 120 ms; the seal scales 1.15 to 1 in 180 ms; buttons glow on hover; the main-menu map drifts; the wind rose may turn once in 120 s. **All off under Reduce motion** and `prefers-reduced-motion`.
- Godot: tweens on `modulate`, scale and rotation only. No shader needed.
- Sound (M12): paper slide, quill tick, seal thud, page turn on a season, coin.

## 8. Accessibility

- Text 13 px or more (12 px in key caps only); targets 24 px or more.
- High-contrast theme (M12): flat boxes, black fields, white text (21:1), 2 px `#ffd646` borders, a 3 px INFO focus ring. It doubles as the low-memory theme.
- Contrast ratios as in section 3; colour never carries a meaning alone.
- Seasons do not change the UI. Contrast is tuned once; only the season dial changes.

## 9. Godot build (summary)

The Theme stays generated from tokens (`shell/ui/tokens.gd` to `theme.tres`). Frames, buttons and ribbons become baked
9-slice `StyleBoxTexture`s made by a new Python tool, `tools/bake_ui.py` (numpy; fractal noise to height to a
directional light for leather and vellum; stretched noise through a colour ramp for walnut; streak noise for brass; a
signed-distance bevel for edges). It writes `godot/assets/baked/ui/*.png` and a `ui_kit.json` of margins that
`build_theme.gd` reads; CI runs it with `--check`. Sizes below are at 1x; bake 2x as well and choose by UI scale.

| Texture | Size | Margins | Effort | Slice |
|---|---|---|---|---|
| `panel_frame` (band, studs, 96 px leather centre, tile stretch) | 160 x 160 | 32, content 20 | M | 1 |
| `panel_modal` (plus bosses) | 192 x 192 | 48, content 28 | M | 1 |
| `panel_vellum` | 160 x 160 | 32 | S | 1 |
| `panel_card` | 48 x 48 | 12 | S | 1 |
| `panel_bar` (wood tiles horizontally) | 128 x 48 | L/R 8, T 4, B 10 | S | 1 |
| `button_{secondary,primary,danger,toggle}_{normal,hot,pressed,off}`, `toggle_on`, `focus` | 64 x 40 | 14 | M (one recipe) | 1 |
| `button_menu_*` (pointed; fixed height) | 96 x 42 | L/R 28, T/B 21 | S | 1 |
| `ribbon`, `toast` (fixed height) | 128 x 40 | L/R 36, T/B 20 | S | 1 |
| `slot`, `plate` | 32 x 24 | 10 | S | 1 |
| `switch_off/on` 48 x 24; `grabber`, `grabber_hot` 24 x 24; `keycap` 32 x 28 | as given | keycap 10 | S | 1 |
| `wordmark` 1024 x 256; `rose` 512 x 512; `rule_diamond` 256 x 12; `glow_soft` 64 x 64 | as given | glow 24 | S/M | 1 |
| `menu_bg` (graded far map; freed after the menu) | 1920 x 1080 | none | S | 1 |
| `cartouche` | 96 x 36 | L/R 24, T/B 18 | S | 2 |
| `minimap_frame` | 256 x 144 | L/R 56, T/B 16 | M | 2 |
| `shield_rim` and `shield_rim_sm`; `pennant_pole`, `pennant_cloth` (the arms are drawn in code under the rim: `m2-build-spec.md` 7.2) | 48 x 56, 20 x 24; 24 x 56, 28 x 20 | none | M | 2 |
| `medallion_64`, `medallion_30`, `endseason_plate_*`, `dial_hand` | as named | none | M | 3 |
| `seal` (3 tones), `seal_cracked` | 72 x 72 | none | M | 3 |
| Medallion icon set | 24 px | none | L | 4 |

Stays `StyleBoxFlat`: row hover, rules, scrollbars, `LineEdit` insets, the shade, the F3 panel. New Theme variations:
`PanelVellum`, `PanelRibbon`, `PanelCartouche`, `LabelInk`, `LabelInkMuted`, `ButtonMenu`, `ButtonMedallion`.
Memory: the 1x kit is under 4 MB of VRAM, 2x under 16 MB; `menu_bg` (8 MB) is freed in game. No screen-space shaders
are needed: every material is a baked texture or a gradient. (A single captured and darkened backdrop behind modals
remains an option; the spec of `ui-and-controls-spec.md` section 8 keeps the HUD free of screen reads.)

## 10. What this overrides, and risks

**Replaced from the Chancery sheet:** light flat panels, 1 px ink boxes, square 2 px buttons, the knot corners, the sepia
menu ground, the "night desk" variant. **Kept from it:** the vellum palette (now the document inset), Cinzel and
Alegreya, the wind rose, all layout and screens.
**Against `ui-and-controls-spec.md` 3.4:** the token names, the variation list, the 4 px grid and "generated Theme" are
unchanged. Values move from blue-grey to warm umber. "Radius 5, StyleBoxFlat" becomes baked 9-slice frames. The fonts
change (Gelasio/Selawik to Cinzel/Alegreya). The top bar stays 40 px.
**Against `docs/design/godot-look/` direction A:** its layout, arms on pennants, strength badge and season dial stay; only
its flat navy chrome is re-skinned. Blue survives as lapis enamel.

| Risk | Mitigation |
|---|---|
| Kitsch | Three ornaments only. Texture under 4 %. No ornament inside text fields. |
| Legibility | Ratios above, asserted in the bake tool. Cinzel never for data. Test at 1280 x 720. |
| Memory | 1x kit under 4 MB, 2x under 16 MB. `menu_bg` freed in game. |
| HiDPI blur | `StyleBoxTexture` does not rescale. Ship 1x and 2x themes chosen by UI scale. Needs a probe. |
| Anachronism | Lapis, velvet, intarsia and wax are all about 1480. No baroque scrollwork, no blackletter. Arabic numerals are right for Italian commerce (Treviso Arithmetic, 1478); Roman numerals only as decoration. |
| Themed-UI fatigue | The HUD stays thin (card frames). Heavy frames only on modals and the side panel. |
| Fonts | Ship the TTFs with OFL.txt and a Noto fallback. |

## 11. Snapshot contents

```
docs/design/ui/design.md                     this file
docs/design/ui/game-feedback-screens.md      season report, upgrade preview, insights (design)
docs/design/ui/studiolo/hexa-ui-mockup.html  the clickable mockup (one file; open in a browser; about 800 KB with the map photos)
docs/design/ui/studiolo/kit.css              the tested CSS kit (tokens, SVG-filter textures, components)
docs/design/ui/studiolo/extra.css            the mapping layer plus the feedback screens' CSS
docs/design/ui/studiolo/*.jpg                screenshots: menu, play_m4, works_genoa, works_vineyard, report_m4,
                                             study_econ, pause, options_gfx, confirm
```

The mockup has a milestone switch (M1.5, M2, M3, M4, M4.5, M6, M11) that reveals what each milestone adds to the same
screens, a tab row for every screen, and working keys (Esc, F1, F3, 1 to 4, H, F11, F12, J, I, L, Space, U). It was
rendered in headless Chrome to check the layout; the screenshots here are those renders. The published copy lives in
the owner's Claude artifacts; this folder is the committed snapshot.

The mockup loads its fonts from Google Fonts (Cinzel, Cinzel Decorative, Alegreya, Alegreya SC, Alegreya Sans) and
uses the north Italy screenshots of `docs/design/map/godot_map/` as a backdrop. Its CSS textures are SVG
filters (`feTurbulence`, `feDiffuseLighting`) rasterised once as data URIs; the Godot bake reproduces them in numpy.
