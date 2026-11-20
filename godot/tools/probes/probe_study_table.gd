## Headless probe for StudyTable (m4-5-build-spec.md 6.2; m4-5-build-spec.md 10: "study_table_rows_ms"): 100 rows with two
## custom-drawn columns (a bar and a spark) built by set_rows, the median and 90th percentile of RUNS builds in ms.
## Run: godot --headless --path godot -s res://tools/probes/probe_study_table.gd
extends SceneTree

const RUNS := 40
const ROWS := 100


func _initialize() -> void:
	var host := Control.new()
	host.theme = KitTheme.load_for(1.0)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var table := StudyTable.new()
	table.size = Vector2(1280.0, 720.0)
	host.add_child(table)
	var cols: Array = [
		{"id": &"place", "title": "Place"},
		{"id": &"gain", "title": "A year", "kind": &"number"},
		{"id": &"change", "title": "This season", "kind": &"delta"},
		{"id": &"share", "title": "Share", "kind": &"bar", "ink": 1},
		{"id": &"seasons", "title": "Seasons", "kind": &"spark", "ink": 0},
		{"id": &"go", "title": "", "kind": &"button"},
	]
	var rows: Array = []
	for i: int in ROWS:
		rows.append({
			"id": i + 1,
			"cells": {
				"place": "Place %03d" % (i + 1),
				"gain": (i * 37) % 90,
				"change": (i % 7) - 3,
				"share": (i * 13) % 1001,
				"seasons": PackedInt32Array([i % 5, 2, 4, i % 3]),
				"go": {"text": "Go"},
			},
		})
	var build_ms: Array[float] = []
	for _run: int in RUNS:
		var t0 := Time.get_ticks_usec()
		table.set_columns(cols)
		table.set_rows(rows)
		build_ms.append((Time.get_ticks_usec() - t0) / 1000.0)
	build_ms.sort()
	var median := build_ms[floori(RUNS * 0.5)]
	var p90 := build_ms[int(RUNS * 0.9)]
	print("study_table_rows_ms median=%.3f p90=%.3f runs=%d rows=%d shown=%d" % [median, p90, RUNS, ROWS, table.shown_count()])
	quit(0)
