## Headless probe for the soak's error counter (docs/architecture/m8-build-spec.md 4.17, 10; M8 plan K22, day one): does an engine
## `Logger` added with `OS.add_logger` see a script error and a `push_error` in this engine? Prints PASS or FAIL. On FAIL the
## soak's CI step relies on its grep for SCRIPT ERROR and Parse Error alone (the invariant `errors` then reads the push_error count).
## Run: godot --headless --path godot -s res://tools/probes/probe_logger.gd
extends SceneTree


class Counter extends Logger:
	var errors := 0
	var script_errors := 0
	var messages: Array[String] = []

	func _log_error(function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		errors += 1
		if error_type == Logger.ERROR_TYPE_SCRIPT:
			script_errors += 1
		messages.append("%s: %s %s" % [function, code, rationale])


func _initialize() -> void:
	var counter := Counter.new()
	OS.add_logger(counter)
	push_error("probe: a deliberate push_error")
	var before := counter.errors
	var script := GDScript.new()
	script.source_code = "extends RefCounted\nfunc boom() -> int:\n\tvar a: Array = []\n\treturn a[5]\n"
	script.reload()
	var node: Object = script.new()
	node.call("boom")  # an out-of-bounds read: a SCRIPT ERROR at run time
	var script_seen := counter.errors - before
	OS.remove_logger(counter)
	print("push_error counted: %s; script error counted: %s (errors %d, of script type %d)" % [before >= 1, script_seen >= 1,
		counter.errors, counter.script_errors])
	var ok := before >= 1 and script_seen >= 1
	print("probe_logger: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
