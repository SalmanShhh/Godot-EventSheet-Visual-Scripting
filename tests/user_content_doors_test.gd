# Godot EventSheets - the two doors content from outside the project comes in through.
#
# A drop on the window and an ask through the platform's own chooser both hand the sheet ONE thing:
# a path on the player's machine. The two loader expressions turn such a path into a texture or an
# audio stream. This test proves the four claims those rows make, in the order they would break:
#
#   1. THE DROP IS A SIGNAL LIKE ANY OTHER. It connects in `_ready` on `get_window()`, and the
#      handler takes the PackedStringArray the window sends. Pinned as the emitted LINE, because the
#      whole point of the trigger is that a hand-written project already writes that line - and the
#      lift half of this test opens exactly that line back into the event.
#   2. THE ASK HAS NO RETURN VALUE. Both Ask rows emit a VISIBLE branch - the platform's own chooser
#      where the platform has one, a filesystem-access FileDialog where it does not - and both
#      halves route into the two answer functions the sheet's answer events compile to. So the test
#      compiles a whole sheet holding an Ask row and both answers and PARSES the result: an emitted
#      call into a function nobody declared is the failure this catches.
#   3. THE LOADERS REALLY LOAD. The image expression is run against a PNG written for the occasion,
#      the sound expression against a WAV written the same way, and both against a path that is not
#      there - the fallback slot is the familiar default argument, so blank means the plain load and
#      filled means the guarded one.
#   4. THE ANSWERS OPEN BACK. A file holding the emitted drop connection, the emitted answer headers
#      and nothing else lifts to those events and re-emits BYTE FOR BYTE.
#
# ONE THING DELIBERATELY NOT TESTED HERE: whether a chooser appears. Neither half of the ask can run
# in a headless suite (there is no window to parent a dialog to, and no platform chooser to answer
# it), so what is proven is the code, not the window - which is why the emitted text is pinned to
# the byte rather than described.
@tool
class_name UserContentDoorsTest
extends RefCounted

const MODULE_PATH := "res://addons/eventforge/registration/modules/file_aces.gd"
const PROBE_PNG := "user://user_content_probe.png"
const PROBE_WAV := "user://user_content_probe.wav"
const PROBE_MISSING := "user://user_content_no_such_file.png"
const PROBE_SCRIPT := "user://user_content_probe.gd"

## The file a lift reads: the drop connection, the drop handler and the two answers, spelled exactly
## as the compiler writes them. It is the fixture AND the expected output - the lift's promise is
## that opening this and saving it again changes nothing.
const HAND_WRITTEN := """extends Node


func _ready() -> void:
	get_window().files_dropped.connect(_on_files_dropped)


func _on_files_dropped(files: PackedStringArray) -> void:
	print(files[0])


func _on_file_chosen(path: String) -> void:
	print(path)


func _on_ask_cancelled() -> void:
	print("nothing picked")
"""


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _run_registration() and all_passed
	all_passed = _run_drop() and all_passed
	all_passed = _run_ask() and all_passed
	all_passed = _run_loaders() and all_passed
	all_passed = _run_lift() and all_passed
	all_passed = _run_band() and all_passed
	if all_passed:
		print("[PASS] user_content_doors_test: the drop door, the ask door and the two loaders")
	return all_passed


## The seven rows register with the ids, kinds and defaults the picker groups them by.
static func _run_registration() -> bool:
	var ok: bool = true
	var by_id: Dictionary = _by_id()
	for ace_id: String in ["OnFilesDropped", "AskForAFileToOpen", "AskWhereToSave", "OnFileChosen",
			"OnAskCancelled", "LoadImageFile", "LoadSoundFile"]:
		ok = _check("%s is registered" % ace_id, by_id.has(ace_id), true) and ok
		ok = _check("%s groups with the files" % ace_id, str(by_id[ace_id].category), "Files") and ok
	ok = _check("the drop is a trigger", int(by_id["OnFilesDropped"].ace_type), int(ACEDescriptor.ACEType.TRIGGER)) and ok
	ok = _check("the ask is an action", int(by_id["AskForAFileToOpen"].ace_type), int(ACEDescriptor.ACEType.ACTION)) and ok
	ok = _check("the save ask is an action", int(by_id["AskWhereToSave"].ace_type), int(ACEDescriptor.ACEType.ACTION)) and ok
	ok = _check("a chosen file is a trigger", int(by_id["OnFileChosen"].ace_type), int(ACEDescriptor.ACEType.TRIGGER)) and ok
	ok = _check("a cancelled ask is a trigger", int(by_id["OnAskCancelled"].ace_type), int(ACEDescriptor.ACEType.TRIGGER)) and ok
	ok = _check("the image loader is an expression", int(by_id["LoadImageFile"].ace_type), int(ACEDescriptor.ACEType.EXPRESSION)) and ok
	ok = _check("the sound loader is an expression", int(by_id["LoadSoundFile"].ace_type), int(ACEDescriptor.ACEType.EXPRESSION)) and ok
	# The row reads as a sentence, with the fallback in the second slot rather than as a clause.
	ok = _check("the drop reads as a sentence", str(by_id["OnFilesDropped"].display_text), "On files dropped {files}") and ok
	ok = _check("the ask names its filters", str(by_id["AskForAFileToOpen"].display_text), "Ask for a file to open ({filters})") and ok
	ok = _check("the save ask names its filters", str(by_id["AskWhereToSave"].display_text), "Ask where to save ({filters})") and ok
	ok = _check("the image loader names its fallback second",
		str(by_id["LoadImageFile"].display_text), "image of file {path}, or {fallback}") and ok
	ok = _check("the sound loader names its fallback second",
		str(by_id["LoadSoundFile"].display_text), "sound of file {path}, or {fallback}") and ok
	# The drop is desktop-only, and the row is where that is said - not a doc nobody opened.
	ok = _check("the drop says it is desktop only on the row itself",
		str(by_id["OnFilesDropped"].description).contains("DESKTOP ONLY"), true) and ok
	# A path field says its place, and a default has to stand on its own in the host class.
	ok = _check("the image path field says its place", _param_hint(by_id, "LoadImageFile", "path"), "file_path") and ok
	ok = _check("the sound path field says its place", _param_hint(by_id, "LoadSoundFile", "path"), "file_path") and ok
	ok = _check("the image loader opens on a user:// picture",
		_param_default(by_id, "LoadImageFile", "path"), "\"user://portrait.png\"") and ok
	ok = _check("the sound loader opens on a user:// track",
		_param_default(by_id, "LoadSoundFile", "path"), "\"user://track.ogg\"") and ok
	ok = _check("the ask opens on a filter that is spelled the way Godot spells one",
		_param_default(by_id, "AskForAFileToOpen", "filters"), "PackedStringArray([\"*.png,*.jpg;Images\"])") and ok
	# The sound loader's parameter names the formats, because naming three and reading one would be
	# the kind of lie a test exists to catch.
	var sound_path_description: String = _param_description(by_id, "LoadSoundFile", "path")
	for extension: String in [".mp3", ".ogg", ".wav"]:
		ok = _check("the sound path field names %s" % extension, sound_path_description.contains(extension), true) and ok
	return ok


## The drop: the connection the compiler writes, and the handler it writes it to.
static func _run_drop() -> bool:
	var ok: bool = true
	var signature: Dictionary = TriggerResolver.resolve_trigger(_trigger_row("OnFilesDropped"))
	ok = _check("the drop is signal-backed", str(signature.get("signal_name", "")), "files_dropped") and ok
	ok = _check("on the window itself", str(signature.get("source_path", "")), "@window") and ok
	ok = _check("and its handler takes the list the window sends",
		str(signature.get("args", "")), "files: PackedStringArray") and ok
	var compiled: String = _compiled(_drop_sheet())
	ok = _check("the sheet connects it in _ready, on get_window()",
		compiled.contains("\tget_window().files_dropped.connect(_on_files_dropped)"), true) and ok
	ok = _check("and writes the handler the connection names",
		compiled.contains("func _on_files_dropped(files: PackedStringArray) -> void:"), true) and ok
	ok = _check("and the whole emitted file parses", _parses(compiled), true) and ok
	return ok


## The ask: the visible branch, and the two answers it routes into.
static func _run_ask() -> bool:
	var ok: bool = true
	var open_line: String = _emitted("AskForAFileToOpen", {"filters": "PackedStringArray([\"*.png;Images\"])", "uid": "3"})
	ok = _check("the branch is in the code, not behind it",
		open_line.begins_with("if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):"), true) and ok
	ok = _check("the platform's own chooser is opened when there is one",
		open_line.contains("\tDisplayServer.file_dialog_show(\"Open a file\", \"\", \"\", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, PackedStringArray([\"*.png;Images\"]), __answer_3)"), true) and ok
	ok = _check("and the fallback is a WRITTEN else, not an assumption",
		open_line.contains("\nelse:\n\tvar __chooser_3 := FileDialog.new()"), true) and ok
	ok = _check("the fallback reaches the whole filesystem, which is the point of an ask",
		open_line.contains("__chooser_3.access = FileDialog.ACCESS_FILESYSTEM"), true) and ok
	ok = _check("both halves end in the chosen answer",
		open_line.count("_on_file_chosen"), 2) and ok
	ok = _check("and both in the cancelled one", open_line.count("_on_ask_cancelled"), 2) and ok
	ok = _check("the fallback window cleans itself up either way",
		open_line.count("queue_free"), 2) and ok
	ok = _check("no segment mark survives into the code", open_line.contains("{?"), false) and ok

	var save_line: String = _emitted("AskWhereToSave", {"filters": "PackedStringArray([\"*.png;PNG image\"])", "uid": "4"})
	ok = _check("asking where to save asks the platform for a save chooser",
		save_line.contains("DisplayServer.FILE_DIALOG_MODE_SAVE_FILE"), true) and ok
	ok = _check("and its fallback is set to the same mode",
		save_line.contains("__chooser_4.file_mode = FileDialog.FILE_MODE_SAVE_FILE"), true) and ok
	ok = _check("and it writes nothing itself", save_line.contains("FileAccess.open"), false) and ok

	# THE WHOLE POINT: the emitted line calls two functions by name, and those two functions are what
	# the answer events compile to. A sheet holding all three has to parse.
	var compiled: String = _compiled(_ask_sheet())
	ok = _check("the answers compile to the functions the ask calls",
		compiled.contains("func _on_file_chosen(path: String) -> void:"), true) and ok
	ok = _check("including the cancelled one",
		compiled.contains("func _on_ask_cancelled() -> void:"), true) and ok
	# One handler each, and neither wired in `_ready`: the only `.connect(_on_file_chosen)` in the
	# file is the one INSIDE the fallback branch, on the FileDialog that row builds.
	ok = _check("the chosen answer is written once", compiled.count("func _on_file_chosen(path: String) -> void:"), 1) and ok
	ok = _check("and reached by a call, not by a connection in _ready",
		compiled.count(".connect(_on_file_chosen)"), 1) and ok
	ok = _check("and the whole emitted file parses", _parses(compiled), true) and ok
	return ok


## The loaders, run for real against files written for the occasion.
static func _run_loaders() -> bool:
	var ok: bool = true
	var picture: Image = Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	picture.fill(Color(0.25, 0.5, 1.0, 1.0))
	picture.save_png(PROBE_PNG)

	var loaded: Variant = _value(_emitted("LoadImageFile", {"path": _quote(PROBE_PNG), "fallback": "null"}))
	ok = _check("a picture from outside the project reads as a texture", loaded is ImageTexture, true) and ok
	if loaded is ImageTexture:
		ok = _check("at the size the file holds", (loaded as ImageTexture).get_size(), Vector2(4, 4) as Variant) and ok
	var plain: Variant = _value(_emitted("LoadImageFile", {"path": _quote(PROBE_PNG), "fallback": ""}))
	ok = _check("and a blank fallback reads the file plainly, with no guard", plain is ImageTexture, true) and ok
	var missing: Variant = _value(_emitted("LoadImageFile", {"path": _quote(PROBE_MISSING), "fallback": "null"}))
	ok = _check("a picture that is not there reads as the fallback", missing, null) and ok

	var sound: AudioStreamWAV = AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_8_BITS
	sound.mix_rate = 8000
	sound.data = PackedByteArray([0, 32, 64, 32, 0, 224, 192, 224])
	sound.save_to_wav(PROBE_WAV)
	var track: Variant = _value(_emitted("LoadSoundFile", {"path": _quote(PROBE_WAV), "fallback": "null"}))
	ok = _check("a .wav from outside the project reads as an audio stream", track is AudioStreamWAV, true) and ok
	var no_track: Variant = _value(_emitted("LoadSoundFile", {"path": "\"user://user_content_no_such.ogg\"", "fallback": "null"}))
	ok = _check("a sound that is not there reads as the fallback", no_track, null) and ok
	# THE PROMISE ON THE ROW: the fallback answers "when its extension is none of the three". A file
	# that EXISTS with a fourth extension used to fall off the end of the chain into the WAV reader,
	# which answered with null and an engine error nobody asked for.
	var wrong_extension: String = PROBE_WAV.get_basename() + ".flac"
	var carried: FileAccess = FileAccess.open(wrong_extension, FileAccess.WRITE)
	if carried != null:
		carried.store_string("not a sound this engine decodes")
		carried.close()
	var undecodable: Variant = _value(_emitted("LoadSoundFile", {"path": _quote(wrong_extension),
		"fallback": "\"fell back\""}))
	ok = _check("a file whose extension is none of the three reads as the fallback",
		undecodable, "fell back") and ok
	DirAccess.remove_absolute(wrong_extension)
	# The chain names one reader per format, so each extension has to reach its own.
	var sound_template: String = str(_by_id()["LoadSoundFile"].codegen_template)
	for reader: String in ["AudioStreamMP3.load_from_file", "AudioStreamOggVorbis.load_from_file",
			"AudioStreamWAV.load_from_file"]:
		ok = _check("the chain names %s" % reader, sound_template.contains(reader), true) and ok
	# One line, deliberately: an expression that spans lines is a parse error inside a condition.
	ok = _check("and it is one line, so it can sit in a condition too",
		_emitted("LoadSoundFile", {"path": "p", "fallback": "null"}).split("\n").size(), 1) and ok

	DirAccess.remove_absolute(PROBE_PNG)
	DirAccess.remove_absolute(PROBE_WAV)
	return ok


## Opening a hand-written file that already writes these spellings, and saving it again unchanged.
static func _run_lift() -> bool:
	var ok: bool = true
	var file: FileAccess = FileAccess.open(PROBE_SCRIPT, FileAccess.WRITE)
	file.store_string(HAND_WRITTEN)
	file.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(PROBE_SCRIPT, false)
	EventSheetACELifter.reset_progress()
	var lifted: bool = EventSheetACELifter.attempt_lift(sheet, HAND_WRITTEN)
	ok = _check("the file opens as events", lifted, true) and ok
	var trigger_ids: Array[String] = []
	for entry: Variant in sheet.events:
		var event_row: EventRow = entry as EventRow
		if event_row != null:
			trigger_ids.append(str(event_row.trigger_id))
	ok = _check("the window's drop connection opens as the drop event",
		trigger_ids.has("OnFilesDropped"), true) and ok
	ok = _check("the chosen-file handler opens as its own event",
		trigger_ids.has("OnFileChosen"), true) and ok
	ok = _check("and so does the cancelled one", trigger_ids.has("OnAskCancelled"), true) and ok
	var output: String = str(SheetCompiler.compile(sheet, PROBE_SCRIPT).get("output", ""))
	ok = _check("and saving it again reproduces the file byte for byte", output, HAND_WRITTEN) and ok
	DirAccess.remove_absolute(PROBE_SCRIPT)
	return ok


## The files band: a sheet that stops to ask says so once, whichever chooser it opens.
static func _run_band() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "AskForAFileToOpen"
	action.params = {"filters": "PackedStringArray([\"*.png;Images\"])"}
	row.actions.append(action)
	sheet.events.append(row)
	var bands: Array[Dictionary] = EventSheetFileFacts.bands(sheet)
	ok = _check("a sheet that opens the platform's chooser says so once", bands.size(), 1) and ok
	ok = _check("in the band's own words", str(bands[0].get("value", "")),
		EventSheetL10n.translate("asks the player to pick a file")) and ok
	ok = _check("and the echo shows the call, not the branch above it",
		str(bands[0].get("echo", "")).begins_with("DisplayServer.file_dialog_show("), true) and ok
	return ok


# -- the pieces ------------------------------------------------------------------------------


## A sheet whose only event is the drop.
static func _drop_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var row: EventRow = _trigger_row("OnFilesDropped")
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Print"
	action.codegen_template = "print(files[0])"
	row.actions.append(action)
	sheet.events.append(row)
	return sheet


## A sheet holding an Ask row and both of its answers - the shape that has to parse.
static func _ask_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var asking: EventRow = _trigger_row("OnReady")
	var ask: ACEAction = ACEAction.new()
	ask.provider_id = "Core"
	ask.ace_id = "AskForAFileToOpen"
	ask.params = {"filters": "PackedStringArray([\"*.png;Images\"])", "uid": "9"}
	ask.codegen_template = str(_by_id()["AskForAFileToOpen"].codegen_template)
	asking.actions.append(ask)
	sheet.events.append(asking)
	for pair: Array in [["OnFileChosen", "print(path)"], ["OnAskCancelled", "print(\"cancelled\")"]]:
		var answer: EventRow = _trigger_row(str(pair[0]))
		var action: ACEAction = ACEAction.new()
		action.provider_id = "Core"
		action.ace_id = "Print"
		action.codegen_template = str(pair[1])
		answer.actions.append(action)
		sheet.events.append(answer)
	return sheet


static func _trigger_row(trigger_id: String) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = trigger_id
	return row


static func _compiled(sheet: EventSheetResource) -> String:
	var output: String = str(SheetCompiler.compile(sheet, "user://user_content_compile_probe.gd").get("output", ""))
	if FileAccess.file_exists("user://user_content_compile_probe.gd"):
		DirAccess.remove_absolute("user://user_content_compile_probe.gd")
	return output


## Runs an emitted expression for real - the pinned text is also the text that is run.
static func _value(expression: String) -> Variant:
	var script: GDScript = GDScript.new()
	script.source_code = "@tool\nextends RefCounted\n\n\nstatic func probe() -> Variant:\n\treturn %s\n" % expression
	if script.reload() != OK:
		print("  [FAIL] user_content_doors_test: an emitted expression did not compile")
		return null
	return script.call("probe")


static func _parses(source: String) -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = source
	return script.reload() == OK


static func _emitted(ace_id: String, params: Dictionary) -> String:
	var by_id: Dictionary = _by_id()
	if not by_id.has(ace_id):
		return ""
	return ActionCodegen._apply_template(str(by_id[ace_id].codegen_template), params)


static func _by_id() -> Dictionary:
	var by_id: Dictionary = {}
	for descriptor: ACEDescriptor in load(MODULE_PATH).get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	return by_id


static func _param_default(by_id: Dictionary, ace_id: String, param_id: String) -> String:
	for param: ACEParam in by_id[ace_id].params:
		if param.id == param_id:
			return str(param.default_value)
	return ""


static func _param_hint(by_id: Dictionary, ace_id: String, param_id: String) -> String:
	for param: ACEParam in by_id[ace_id].params:
		if param.id == param_id:
			return str(param.hint)
	return ""


static func _param_description(by_id: Dictionary, ace_id: String, param_id: String) -> String:
	for param: ACEParam in by_id[ace_id].params:
		if param.id == param_id:
			return str(param.description)
	return ""


## A GDScript string literal for arbitrary text.
static func _quote(text: String) -> String:
	return "\"%s\"" % text.c_escape()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] user_content_doors_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
