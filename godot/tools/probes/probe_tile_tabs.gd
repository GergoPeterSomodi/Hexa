## Probe (tile-window spec D4, TW3): does a folder listing see the tab scripts (`*_tab.gd`) in this engine, by DirAccess and by
## ResourceLoader.list_directory? It lists the fixture folder (which holds fake_tab.gd) and prints both results, then PASS or
## FAIL. The probe runs in the editor build only: it cannot show what an exported build lists (no export templates here),
## so the registry reads the generated index for the real folder (tools/build_tile_tabs.gd).
## Run: godot --headless --path godot -s res://tools/probes/probe_tile_tabs.gd
extends SceneTree

const FIXTURE := "res://tests/shell/fixtures/tile_tabs"
const WANTED := "fake_tab.gd"


func _initialize() -> void:
	var by_dir := _names(DirAccess.get_files_at(FIXTURE))
	var by_loader := _names(ResourceLoader.list_directory(FIXTURE))
	print("probe_tile_tabs: DirAccess lists %s" % [by_dir])
	print("probe_tile_tabs: ResourceLoader.list_directory lists %s" % [by_loader])
	var ok := by_dir.has(WANTED)
	print("probe_tile_tabs: DirAccess finds %s: %s" % [WANTED, ok])
	print("probe_tile_tabs: ResourceLoader finds %s: %s" % [WANTED, by_loader.has(WANTED)])
	print("probe_tile_tabs: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


## The file names of a listing, without the `.remap` suffix an exported build adds.
func _names(entries: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for entry: String in entries:
		out.append(entry.trim_suffix(".remap"))
	return out
