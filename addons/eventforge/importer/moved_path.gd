@tool
extends RefCounted

## Where a path ends up when a file or a folder is moved. Shared by the open tabs (which follow their
## files) and by the project-wide indexes (which follow the scripts and scenes they name), so the two
## can never disagree about what a move did to a path.


## The path `path` becomes when `old_path` moves to `new_path`: a file maps only itself, a folder maps
## everything under it. `path` itself when nothing moved it.
static func mapped(path: String, old_path: String, new_path: String, is_folder: bool) -> String:
	if path.is_empty() or old_path.is_empty():
		return path
	var key: String = path.simplify_path()
	if is_folder:
		var from: String = old_path.simplify_path().trim_suffix("/") + "/"
		if key.begins_with(from):
			return new_path.simplify_path().trim_suffix("/") + "/" + key.trim_prefix(from)
		return path
	return new_path.simplify_path() if key == old_path.simplify_path() else path


## Whether the move changes `path` at all: it is the moved file, or lies under the moved folder. A plain
## comparison with nothing simplified, for a walk over thousands of paths a move almost never touches (the
## paths an index holds are already clean). `mapped` gives the answer for the ones that do.
static func is_moved(path: String, old_path: String, is_folder: bool) -> bool:
	if is_folder:
		return path.begins_with(old_path.trim_suffix("/") + "/")
	return path == old_path
