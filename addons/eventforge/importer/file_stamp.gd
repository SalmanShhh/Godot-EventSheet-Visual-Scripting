# EventForge - the one place a file's cache identity is worked out.
#
# Every by-file reader in this plugin caches what it parsed under `path|mtime|size`, and every one of
# them worked that string out for itself. That is a filesystem call - two, since a size means opening
# the file - BEFORE the cache can even be consulted, so a "cached" read still cost real I/O. A row
# build that asks about a shader once per dial per row asks thousands of times, and a hundred warm
# shader reads measured 85-101 ms of pure stat.
#
# So the stamp itself is held. Within one editor session a file's identity is asked once and
# remembered, and the answer is dropped wholesale when the editor says the filesystem moved
# (`filesystem_changed` / `resources_reimported`, the same ping every other cache here listens to).
# A warm read then costs a dictionary lookup and nothing else.
#
# WHY THAT IS SAFE, and where it is not: inside the editor nothing changes a file without the
# filesystem signal following it, which is the invalidation this is built around. A script writing
# files directly - a test fixture, a builder - gets no such signal, so it calls `forget` (one path) or
# `forget_all` after writing. Every reader's own `clear_cache()` forgets its stamps too, so a test
# that already clears the reader it is testing needs to know nothing about this file.
@tool
class_name EventForgeFileStamp
extends RefCounted

## `path` -> `path|mtime|size`. Session-lifetime and shared by every reader, which is the whole point:
## the shader parser and the scene reader asking about the same file ask the filesystem once between
## them.
static var _stamps: Dictionary = {}


## The cache identity of one file: its path, its saved mtime and its byte length. mtime alone has
## seconds resolution, so two saves inside one second would otherwise serve the older parse - the
## length is what tells them apart. A missing file stamps as its own path with zeroes, which is a
## stable key like any other and lets a reader cache "there is nothing here" as an answer.
static func of(path: String) -> String:
	if _stamps.has(path):
		return _stamps[path]
	var length: int = 0
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file != null:
		length = file.get_length()
		file.close()
	var stamp: String = "%s|%d|%d" % [path, FileAccess.get_modified_time(path), length]
	_stamps[path] = stamp
	return stamp


## Forgets one file, so the next question re-stats it. For a writer that knows exactly what it
## touched - a fixture generator, a pack builder - and does not want to cost every other reader its
## whole cache.
static func forget(path: String) -> void:
	_stamps.erase(path)


## Forgets every file. The editor calls this on the filesystem ping; a test calls it after writing
## fixtures, and each reader's own `clear_cache()` calls it for the same reason.
static func forget_all() -> void:
	_stamps.clear()
