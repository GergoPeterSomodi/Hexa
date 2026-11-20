# Mockup references

The pictures in this folder are the mockup's screens, rendered once in headless Chrome, as references for the
side-by-side checks. They are not compared by CI.

The mockup is `docs/design/ui/studiolo/hexa-ui-mockup.html`. It has no command-line switches, so each stage is a copy of
it with the milestone and the study's page and tab set by `sed`, then one Chrome screenshot at 1280 x 720. Run from the
repository root, with `CHROME` set to the Chrome executable and `T` to a temporary folder (on Windows, give `T` as a
Windows path, for example the output of `cygpath -m`):

```bash
M=docs/design/ui/studiolo/hexa-ui-mockup.html; T=$(mktemp -d); OUT=$PWD/godot/tests/fixtures/mockup
```

M4.5 stages (milestone "4.5"; the study opens on the named page and tab):

```bash
sed -e 's|<button data-v="1.5" class="on">|<button data-v="1.5">|' -e 's|<button data-v="4.5">|<button data-v="4.5" class="on">|' -e 's|ms:1.5,zoom|ms:4.5,zoom|' -e 's|st.sp="economy";st.stab="season";|st.sp="economy";st.stab="districts";|' "$M" > "$T/study_districts.html" && "$CHROME" --headless=new --disable-gpu --hide-scrollbars --window-size=1280,720 --virtual-time-budget=3000 --screenshot="$OUT/study_districts.png" "file://$T/study_districts.html#study"
sed -e 's|<button data-v="1.5" class="on">|<button data-v="1.5">|' -e 's|<button data-v="4.5">|<button data-v="4.5" class="on">|' -e 's|ms:1.5,zoom|ms:4.5,zoom|' -e 's|st.sp="economy";st.stab="season";|st.sp="economy";st.stab="goods";|' "$M" > "$T/study_goods.html" && "$CHROME" --headless=new --disable-gpu --hide-scrollbars --window-size=1280,720 --virtual-time-budget=3000 --screenshot="$OUT/study_goods.png" "file://$T/study_goods.html#study"
sed -e 's|<button data-v="1.5" class="on">|<button data-v="1.5">|' -e 's|<button data-v="4.5">|<button data-v="4.5" class="on">|' -e 's|ms:1.5,zoom|ms:4.5,zoom|' -e 's|st.sp="economy";st.stab="season";|st.sp="economy";st.stab="hist";|' "$M" > "$T/study_history_tab.html" && "$CHROME" --headless=new --disable-gpu --hide-scrollbars --window-size=1280,720 --virtual-time-budget=3000 --screenshot="$OUT/study_history_tab.png" "file://$T/study_history_tab.html#study"
sed -e 's|<button data-v="1.5" class="on">|<button data-v="1.5">|' -e 's|<button data-v="4.5">|<button data-v="4.5" class="on">|' -e 's|ms:1.5,zoom|ms:4.5,zoom|' -e 's|st.sp="economy";st.stab="season";|st.sp="rankings";st.stab="season";|' "$M" > "$T/study_rankings.html" && "$CHROME" --headless=new --disable-gpu --hide-scrollbars --window-size=1280,720 --virtual-time-budget=3000 --screenshot="$OUT/study_rankings.png" "file://$T/study_rankings.html#study"
sed -e 's|<button data-v="1.5" class="on">|<button data-v="1.5">|' -e 's|<button data-v="4.5">|<button data-v="4.5" class="on">|' -e 's|ms:1.5,zoom|ms:4.5,zoom|' -e 's|st.sp="economy";st.stab="season";|st.sp="history";st.stab="season";|' "$M" > "$T/study_history.html" && "$CHROME" --headless=new --disable-gpu --hide-scrollbars --window-size=1280,720 --virtual-time-budget=3000 --screenshot="$OUT/study_history.png" "file://$T/study_history.html#study"
```

The M4.5 study pictures are the first set here (`study_districts.png`, `study_goods.png`, `study_history_tab.png`,
`study_rankings.png`, `study_history.png`). The other stages (the M1.5 screens, the M2 to M6 switches) come with their
tasks and add their lines below.
