## The tile window's tab registry (tile-window spec R11, D4). A tab is a script in shell/panels/tile_tabs/ whose name ends
## in `_tab.gd` and extends TileTab; this class finds them and orders them by their `ORDER`. Adding a tab needs no edit
## here or in the window.
##
## The real folder is read from the generated index tile_tabs_index.gd (written by tools/build_tile_tabs.gd, checked in CI
## with --check). The export probe could not run (no export templates in this environment), so the index is the fallback
## the spec names: a `.gd` file of an exported build may not be listed, so the index names the tabs instead. Extra
## folders (a test's fixture folder, `with_folder`) are listed with DirAccess.
class_name TileTabs
extends RefCounted

const FOLDER := "res://shell/panels/tile_tabs"
const BASE_SCRIPT := "tile_tab.gd"
const Index := preload("res://shell/panels/tile_tabs/tile_tabs_index.gd")

static var _extra_folders: PackedStringArray = []
static var _cache: Array[GDScript] = []
static var _cached := false
static var _errors: PackedStringArray = []


## Every tab, sorted by ORDER. Lists the folders once; errors (see check) are pushed and kept for errors().
static func all() -> Array[GDScript]:
	if not _cached:
		_cache = _collect()
		_cached = true
	return _cache.duplicate()


## The ids of the tabs that apply to a view, in ORDER.
static func for_view(view: Dictionary) -> Array[StringName]:
	return shown_in(all(), view)


## The ids of the tabs of `scripts` that apply to a view, in ORDER (the tile window's strip; R14).
static func shown_in(scripts: Array, view: Dictionary) -> Array[StringName]:
	var sorted: Array = scripts.duplicate()
	sorted.sort_custom(func(a: GDScript, b: GDScript) -> bool: return order_of(a) < order_of(b))
	var ids: Array[StringName] = []
	for script: GDScript in sorted:
		if script.call("applies", view):
			ids.append(id_of(script))
	return ids


## Id to reason for every tab of the registry that applies to the view and is dimmed (tile-window spec R13, R14).
static func dimmed_for(view: Dictionary) -> Dictionary:
	return dimmed_in(all(), view)


## Id to reason for every tab of `scripts` that applies to the view and whose `dimmed` gives a reason.
static func dimmed_in(scripts: Array, view: Dictionary) -> Dictionary:
	var out := {}
	for script: GDScript in scripts:
		if not script.call("applies", view):
			continue
		var reason := str(script.call("dimmed", view))
		if reason != "":
			out[id_of(script)] = reason
	return out


## Adds a folder to the registry (for tests) and returns every tab now listed.
static func with_folder(path: String) -> Array[GDScript]:
	if not _extra_folders.has(path):
		_extra_folders.append(path)
	_cached = false
	return all()


## Forgets the extra folders and the listing cache.
static func reset() -> void:
	_extra_folders = []
	_cached = false
	_cache = []
	_errors = []


## The problems found by the last listing (a missing constant or a duplicate ORDER), one message each.
static func errors() -> PackedStringArray:
	return _errors.duplicate()


## The messages for a list of tab scripts: a missing constant, or two tabs with one ORDER. Empty when all is well.
static func check(scripts: Array) -> PackedStringArray:
	var problems := PackedStringArray()
	var by_order: Dictionary = {}
	for script: GDScript in scripts:
		var name := script.resource_path
		var consts := script.get_script_constant_map()
		var missing := PackedStringArray()
		for key: String in ["ID", "LABEL", "ORDER"]:
			if not consts.has(key):
				missing.append(key)
		if not missing.is_empty():
			problems.append("%s: missing constant %s" % [name, ", ".join(missing)])
			continue
		var order := int(consts["ORDER"])
		if by_order.has(order):
			problems.append("%s: duplicate ORDER %d (also %s)" % [name, order, by_order[order]])
		else:
			by_order[order] = name
	return problems


## A tab missing a constant still sorts (as 0 / empty); check() names it.
static func id_of(script: GDScript) -> StringName:
	return StringName(script.get_script_constant_map().get("ID", &""))


static func order_of(script: GDScript) -> int:
	return int(script.get_script_constant_map().get("ORDER", 0))


## The tab scripts of one folder, by name, from DirAccess (base script excluded).
static func list_folder(folder: String) -> PackedStringArray:
	var out := PackedStringArray()
	for file_name: String in DirAccess.get_files_at(folder):
		var clean := file_name.trim_suffix(".remap")
		if clean.ends_with("_tab.gd") and clean != BASE_SCRIPT:
			out.append(folder + "/" + clean)
	out.sort()
	return out


static func _collect() -> Array[GDScript]:
	var paths := PackedStringArray(Index.PATHS)
	for folder: String in _extra_folders:
		for path: String in list_folder(folder):
			if not paths.has(path):
				paths.append(path)
	var found: Array[GDScript] = []
	for path: String in paths:
		var script := load(path) as GDScript
		if script == null:
			_errors.append("%s: cannot load the tab script" % path)
			continue
		found.append(script)
	_errors = check(found)
	for message: String in _errors:
		push_error(message)
	found.sort_custom(func(a: GDScript, b: GDScript) -> bool: return order_of(a) < order_of(b))
	return found
