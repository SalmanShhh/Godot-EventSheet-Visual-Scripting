# The `.uid` sidecars beside generated scripts and shaders, as the build tools and their drift gates
# see them.
#
# The sidecars are committed (a fresh clone or a user install without them invents new ids and warns
# about every one it had cached), but no builder writes one: Godot's import does, the first time it
# meets a new script. So the builders and the gates hold two rules between them:
#
#   * a build leaves every existing sidecar exactly as it was - `snapshot` before, `changed_since`
#     after - because a regenerated `.gd` keeps its identity, and a sidecar rewritten or deleted by a
#     build is every scene that names the script by uid losing it;
#   * a gate never calls a sidecar drift (it is not builder output), but it does name a script or
#     shader that has none - `missing` - with the fix: run the import and commit what it wrote.
@tool
extends RefCounted

## The file kinds Godot gives a `.uid` sidecar to, among the kinds the generated trees hold.
const SOURCES: PackedStringArray = ["gd", "gdshader", "gdshaderinc"]

## How a missing sidecar is fixed, said once for every tool that prints one.
const FIX: String = "run \"$GODOT\" --headless --path . --import and commit the .uid it writes"


## Every script and shader under `root` (recursively) without its `.uid`, sorted. A folder holding
## a `.gdignore` is skipped with everything under it, because the importer never sees it.
static func missing(root: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for path: String in _files(root):
		if SOURCES.has(path.get_extension()) and not FileAccess.file_exists(path + ".uid"):
			found.append(path)
	return found


## Every `.uid` sidecar under each of `roots`, as {res:// path: bytes}.
static func snapshot(roots: PackedStringArray) -> Dictionary:
	var taken: Dictionary = {}
	for root: String in roots:
		for path: String in _files(root):
			if path.get_extension() == "uid":
				taken[path] = FileAccess.get_file_as_bytes(path)
	return taken


## The sidecars in `before` that are gone or whose bytes changed since it was taken, sorted. Each is
## put back as it was, so a build can never be the thing that loses a script's identity.
static func changed_since(before: Dictionary) -> PackedStringArray:
	var changed: PackedStringArray = PackedStringArray()
	for path: Variant in before.keys():
		var bytes: PackedByteArray = before[path]
		if FileAccess.file_exists(str(path)) and FileAccess.get_file_as_bytes(str(path)) == bytes:
			continue
		changed.append(str(path))
		var file: FileAccess = FileAccess.open(str(path), FileAccess.WRITE)
		if file != null:
			file.store_buffer(bytes)
			file.close()
	changed.sort()
	return changed


## Every file under `root`, recursively and sorted, leaving out any folder that holds a `.gdignore`.
static func _files(root: String) -> PackedStringArray:
	var files: PackedStringArray = PackedStringArray()
	var pending: PackedStringArray = PackedStringArray([root])
	while not pending.is_empty():
		var here: String = pending[0]
		pending.remove_at(0)
		if FileAccess.file_exists(here.path_join(".gdignore")):
			continue
		var dir: DirAccess = DirAccess.open(here)
		if dir == null:
			continue
		for sub: String in dir.get_directories():
			if not sub.begins_with("."):
				pending.append(here.path_join(sub))
		for file: String in dir.get_files():
			files.append(here.path_join(file))
	files.sort()
	return files
