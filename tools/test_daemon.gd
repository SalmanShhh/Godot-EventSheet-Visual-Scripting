# Godot EventSheets - a Godot that stays open, so a test takes a second instead of thirty.
#
# WHAT THIS IS FOR. Running one test from cold costs a Godot boot and a project import - about
# twenty-five seconds of which none is the test. While a change is still moving that is the entire
# cost of trying an idea. So this holds the imported project open and runs tests on request:
# the first one still pays the boot, and every one after it is the test itself.
#
# IT IS NOT A VERDICT, AND THE REASON IS THE POINT. A warm process carries whatever the last test
# left behind - a static the compiler filled, a registry that was rescanned, an autoload that was
# added. That is exactly the contamination `tests/compiler_state_leak_test.gd` exists to find, and a
# daemon is the one place it can silently pass. So: ITERATE here, and run a COLD suite before you
# believe anything. Always run cold after touching a static, an autoload, or registration.
#
# HOW IT TALKS. Through files under `.godot/test_daemon/`, not through a pipe, so a client that runs
# for one second at a time still finds the same warm process waiting - which is what makes it useful
# to a script (and to an agent) rather than only to somebody sitting at a terminal. A client writes
# `request-<token>.txt` holding one test name per line; the daemon deletes it, runs them, and writes
# `response-<token>.txt`. `tools/test_daemon_client.ps1` is that client.
#
#   $env:GODOT = "<the Godot 4.7 console binary>"
#   powershell -File tools/test_daemon.ps1              # start it (it restarts itself; Ctrl+C stops)
#   powershell -File tools/test_daemon_client.ps1 lighting_lift_test shard_split_test
#
# IT RESTARTS ITSELF, twice over: every RESTART_AFTER_RUNS tests, because contamination accumulates
# whether or not anything notices, and IMMEDIATELY when the state-leak sweep fails, because that is
# the sweep saying this process is no longer worth believing. Both exit with RESTART_EXIT_CODE, and
# tools/test_daemon.ps1 starts a fresh one.
@tool
extends SceneTree

## Where requests and responses live. Under `.godot/`, which is machine-local and ignored by git.
const QUEUE_DIR: String = "res://.godot/test_daemon/"

## Where the tests are, and what one is called.
const TESTS_DIR: String = "res://tests/"

## How many tests one process serves before it hands over to a fresh one. Measured against nothing
## in particular - it is a guess, deliberately low, because the cost of being wrong in this
## direction is one boot and the cost in the other is a green run that means nothing.
const RESTART_AFTER_RUNS: int = 25

## The test whose whole job is to notice the contamination this daemon can cause. When it fails, the
## process is done: whatever it says next is about the daemon rather than about the tree.
const CANARY_TEST: String = "compiler_state_leak_test"

## The exit code that means "start another one of me". tools/test_daemon.ps1 loops on it.
const RESTART_EXIT_CODE: int = 70

## How long to sleep between looks at the queue, in seconds. Short enough that a client does not
## wait for it, long enough that an idle daemon costs nothing.
const POLL_SECONDS: float = 0.05

## The folders whose source this process is holding compiled in memory. A file under one of them
## that changes after boot means the answers here are about code that is no longer on disk - the one
## way a warm process can be actively WRONG rather than merely stale, so it hands over instead.
const WATCHED_DIRS: Array[String] = ["res://addons/", "res://tools/"]

## Shared helper files under `tests/` that this process is also holding compiled in memory. The
## requested test itself is re-read from disk every time (CACHE_MODE_IGNORE below), but a file it
## `preload`s resolves through the resource cache, so an edit to one of these would be answered
## from the copy compiled at first use. Watching them by name keeps that honest without watching
## all of `tests/`, which would hand over on every edit the loop exists to serve.
const WATCHED_FILES: Array[String] = ["res://tests/support.gd"]

var _runs_served: int = 0
var _waited: float = 0.0
var _source_stamp: int = 0


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(QUEUE_DIR))
	_source_stamp = _newest_source_time()
	print("[daemon] warm and waiting. Requests: %s" % QUEUE_DIR)
	print("[daemon] ITERATION ONLY - run a cold suite before believing anything.")


func _process(delta: float) -> bool:
	_waited += delta
	if _waited < POLL_SECONDS:
		return false
	_waited = 0.0
	var request: String = _next_request()
	if request.is_empty():
		return false
	var token: String = request.trim_prefix("request-").trim_suffix(".txt")
	var lines: PackedStringArray = FileAccess.get_file_as_string(QUEUE_DIR + request).split("\n", false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(QUEUE_DIR + request))
	if _newest_source_time() > _source_stamp:
		_respond(token, PackedStringArray([
			"[daemon] the plugin source changed since this process booted, so what it holds is not",
			"[daemon] what is on disk. Handing over to a fresh one - ask again in a moment."]))
		quit(RESTART_EXIT_CODE)
		return true
	var report: PackedStringArray = PackedStringArray()
	var canary_tripped: bool = false
	for name: String in lines:
		var test_name: String = name.strip_edges()
		if test_name.is_empty():
			continue
		if test_name == "quit":
			_respond(token, PackedStringArray(["[daemon] stopping"]))
			quit(0)
			return true
		var outcome: Dictionary = _run_one(test_name)
		report.append("%s %s (%d ms)" % [test_name, "green" if outcome["passed"] else "RED",
			int(outcome["ms"])])
		_runs_served += 1
		if test_name == CANARY_TEST and not bool(outcome["passed"]):
			canary_tripped = true
	if canary_tripped:
		report.append("[daemon] the state-leak sweep failed here, so this process is contaminated -")
		report.append("[daemon] restarting, and rerun that test COLD before believing either answer.")
	elif _runs_served >= RESTART_AFTER_RUNS:
		report.append("[daemon] %d runs served, restarting for a clean one" % _runs_served)
	_respond(token, report)
	if canary_tripped or _runs_served >= RESTART_AFTER_RUNS:
		quit(RESTART_EXIT_CODE)
		return true
	return false


## One test, run in this process. The same contract the suite uses: load the file, call `run`,
## believe the boolean - so a test cannot pass here and fail there for want of a different harness.
func _run_one(test_name: String) -> Dictionary:
	var path: String = TESTS_DIR + test_name.trim_suffix(".gd") + ".gd"
	if not FileAccess.file_exists(path):
		print("[daemon] no such test: %s" % test_name)
		return {"passed": false, "ms": 0}
	var started_at: int = Time.get_ticks_msec()
	# Read from DISK rather than from the resource cache: the test file being edited between two
	# requests is the whole loop this exists to serve, and a cached copy would answer about the
	# version before the edit. What it holds of the PLUGIN is handled the other way - by handing over
	# to a fresh process the moment anything under addons/ or tools/ changes.
	var script: GDScript = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	if script == null or not script.has_method("run"):
		print("[daemon] %s has no run()" % test_name)
		return {"passed": false, "ms": Time.get_ticks_msec() - started_at}
	print("--- %s" % test_name)
	var passed: bool = bool(script.call("run"))
	return {"passed": passed, "ms": Time.get_ticks_msec() - started_at}


## The oldest request waiting, or "". Sorted so two clients are served in a stable order.
func _next_request() -> String:
	var dir: DirAccess = DirAccess.open(QUEUE_DIR)
	if dir == null:
		return ""
	var names: PackedStringArray = PackedStringArray()
	for file_name: String in dir.get_files():
		if file_name.begins_with("request-") and file_name.ends_with(".txt"):
			names.append(file_name)
	names.sort()
	return "" if names.is_empty() else names[0]


## The newest modification time across the watched folders and the watched shared files. Walked per
## request, which is a few milliseconds against the twenty-five seconds a boot costs.
func _newest_source_time() -> int:
	var newest: int = 0
	for dir_path: String in WATCHED_DIRS:
		newest = maxi(newest, _newest_in(dir_path))
	for file_path: String in WATCHED_FILES:
		if FileAccess.file_exists(file_path):
			newest = maxi(newest, int(FileAccess.get_modified_time(file_path)))
	return newest


func _newest_in(dir_path: String) -> int:
	var newest: int = 0
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return 0
	for file_name: String in dir.get_files():
		if file_name.ends_with(".gd"):
			newest = maxi(newest, int(FileAccess.get_modified_time(dir_path + file_name)))
	for sub_dir: String in dir.get_directories():
		newest = maxi(newest, _newest_in(dir_path + sub_dir + "/"))
	return newest


func _respond(token: String, lines: PackedStringArray) -> void:
	var file: FileAccess = FileAccess.open("%sresponse-%s.txt" % [QUEUE_DIR, token], FileAccess.WRITE)
	if file == null:
		return
	for line: String in lines:
		file.store_line(line)
		print("[daemon] %s" % line)
	file.close()
