## Tests for RunLock (docs/architecture/m3-build-spec.md 4.10 "Recovery", 6.15 and section 9).
extends GutTest

const TEST_PATH := "user://test_running.lock"


func before_each() -> void:
	RunLock.path = TEST_PATH
	RunLock.is_running = OS.is_process_running
	RunLock.clear()


func after_each() -> void:
	RunLock.clear()
	RunLock.path = RunLock.PATH
	RunLock.is_running = OS.is_process_running


func test_default_path_is_the_real_lock() -> void:
	assert_eq(RunLock.PATH, "user://running.lock")


func test_no_lock_means_not_left_behind() -> void:
	assert_false(RunLock.left_behind())
	assert_eq(RunLock.read(), {})


func test_write_then_left_behind_and_read() -> void:
	RunLock.write("north_italy", 1700000000)
	assert_true(RunLock.left_behind())
	assert_eq(RunLock.read(), {"started_unix": 1700000000, "map_id": "north_italy", "pid": OS.get_process_id()})


func test_clear_removes_it_and_is_harmless_twice() -> void:
	RunLock.write("north_italy", 5)
	RunLock.clear()
	assert_false(RunLock.left_behind())
	RunLock.clear()
	assert_false(RunLock.left_behind())


func test_a_damaged_lock_is_still_left_behind_but_reads_empty() -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("not json {")
	f.close()
	assert_true(RunLock.left_behind())
	assert_eq(RunLock.read(), {})
	f = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("{\"started_unix\": \"x\", \"map_id\": 3}")
	f.close()
	assert_eq(RunLock.read(), {}, "wrong types read as empty")


func _lock_of(pid: int) -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"started_unix": 5, "map_id": "m", "pid": pid}))
	f.close()


func test_a_lock_of_another_live_process_is_not_left_behind() -> void:
	_lock_of(OS.get_process_id() + 1)
	RunLock.is_running = func(_pid: int) -> bool: return true
	assert_false(RunLock.left_behind(), "another instance is running")
	RunLock.is_running = func(_pid: int) -> bool: return false
	assert_true(RunLock.left_behind(), "that process is gone: a crash")


func test_a_lock_of_this_process_or_without_a_pid_is_left_behind() -> void:
	RunLock.is_running = func(_pid: int) -> bool: return true
	_lock_of(OS.get_process_id())
	assert_true(RunLock.left_behind())
	_lock_of(0)
	assert_true(RunLock.left_behind())
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("{\"started_unix\": 5, \"map_id\": \"m\"}")
	f.close()
	assert_true(RunLock.left_behind(), "an old lock with no pid")
	assert_eq(RunLock.read()["pid"], 0)
