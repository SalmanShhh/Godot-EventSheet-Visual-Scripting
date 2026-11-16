# Godot EventSheets - the second process of guide_examples_test.
#
# The parent test writes one script per code example of the two API guides and a manifest naming
# them; this runs each one in a process of its own, so what an example registers (a Doctor check, a
# palette command, a block kind) dies with the process instead of standing in the suite. One line per
# example goes to the output as `GUIDE|<number>|<verdict>`, where the verdict is `ok` or the reason:
#
#   statement   the example was wrapped in a function; it must parse and run with no script error
#   class       the example is a whole script; it must parse
#   kind        the example is (a fragment of) a block kind; it must parse, build, and write its
#               default row, and a kind that also lifts must reopen its own line as its own row
#
# The process quits with 0 when it ends, which also proves that an example registering a lambda
# no longer ends the process in a crash.
@tool
extends SceneTree


## Counts script errors the way a reader's Output panel would show them.
class ErrorEar extends Logger:
	var heard: PackedStringArray = PackedStringArray()

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			heard.append(rationale if not rationale.is_empty() else code)


func _init() -> void:
	var manifest: String = OS.get_cmdline_user_args()[0]
	var ear: ErrorEar = ErrorEar.new()
	OS.add_logger(ear)
	for entry: String in FileAccess.get_file_as_string(manifest).split("\n", false):
		var parts: PackedStringArray = entry.split("|")
		ear.heard.clear()
		var verdict: String = _try(parts[1], parts[2])
		if verdict == "ok" and not ear.heard.is_empty():
			verdict = ear.heard[0]
		print("GUIDE|%s|%s" % [parts[0], verdict.replace("\n", " ").replace("|", "/")])
	OS.remove_logger(ear)
	quit(0)


## "ok", or why the example at `path` does not hold.
static func _try(kind: String, path: String) -> String:
	var script: GDScript = load(path) as GDScript
	if script == null or not script.can_instantiate():
		return "does not parse"
	match kind:
		"statement":
			script.new().call("run")
		"kind":
			return _try_kind(script, path)
	return "ok"


## Builds the kind, writes its default row, and when the kind has a lift of its own, reopens that
## line as that row.
static func _try_kind(script: GDScript, path: String) -> String:
	var kind: EventSheetBlockKind = script.new() as EventSheetBlockKind
	if kind == null:
		return "is not a block kind"
	var row: CustomBlockRow = CustomBlockRow.new()
	row.kind_id = kind.kind_id
	for field: Dictionary in kind.fields():
		row.fields[str(field["id"])] = field.get("default")
	var lines: PackedStringArray = kind.emit(row)
	if not FileAccess.get_file_as_string(path).contains("func lift("):
		return "ok"
	if lines.is_empty():
		return "ok"
	var refusal: String = EventSheets.try_register_block_kind(kind)
	if not refusal.is_empty():
		return "registering the kind was refused: " + refusal
	var source: String = "extends Node\n\n%s\n" % "\n".join(lines)
	var lifted: PackedStringArray = PackedStringArray()
	for entry: Variant in EventSheets.open_gd_as_sheet(source).events:
		if entry is CustomBlockRow:
			lifted.append((entry as CustomBlockRow).kind_id)
	var reproduces: bool = EventSheets.round_trips(source)
	EventSheets.unregister_block_kind(kind.kind_id)
	if lifted != PackedStringArray([kind.kind_id]):
		return "its own line did not reopen as its row (found %s)" % str(lifted)
	if not reproduces:
		return "the file with its row does not save back byte for byte"
	return "ok"
