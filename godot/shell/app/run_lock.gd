## The running lock (docs/architecture/m3-build-spec.md 4.10 "Recovery", 6.15): `user://running.lock` is written when a
## game starts and deleted on the main menu and at a clean quit. A lock found at the start of the program means the last
## run did not close properly.
class_name RunLock
extends RefCounted

const PATH := "user://running.lock"

## Where the lock lives; tests point it at a temporary file.
static var path: String = PATH
## Asks whether a process id is alive; tests replace it. A recycled pid can look alive (a known limit: the lock is
## then taken for another instance's and the recovery question is skipped once).
static var is_running: Callable = OS.is_process_running


## Writes {started_unix, map_id, pid} (pid: this process).
static func write(map_id: String, now_unix: int) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"started_unix": now_unix, "map_id": map_id, "pid": OS.get_process_id()}))
	f.close()


## Deletes the lock; nothing when there is none.
static func clear() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## True when a lock file is there that no other running instance owns: a second window's lock is not a crash. A lock
## without a readable pid counts as left behind.
static func left_behind() -> bool:
	if not FileAccess.file_exists(path):
		return false
	var pid := int(read().get("pid", 0))
	return not (pid > 0 and pid != OS.get_process_id() and bool(is_running.call(pid)))


## The lock's content ({started_unix, map_id, pid}; pid 0 when absent), or {} when there is none or it cannot be read.
static func read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		return {}
	var raw := json.data as Dictionary
	if not (raw.get("started_unix") is float or raw.get("started_unix") is int) or not (raw.get("map_id") is String):
		return {}
	var pid: Variant = raw.get("pid", 0)
	return {"started_unix": int(raw["started_unix"]), "map_id": raw["map_id"],
			"pid": int(pid) if (pid is float or pid is int) else 0}
