# EventForge - every name reads exactly as the file writes it. A variable, a function and the object a
# file names itself by keep their own spelling on a script opened as a sheet as much as on one being
# edited: `bullet_speed` never becomes "Bullet Speed", `take_damage` never "Take Damage", and a script
# without a class_name is the object `gun_turret`, never "Gun Turret". The respelling lens is still
# there for whoever turns it on in View, and only then.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "names_as_written_test"

const SOURCE := "extends Node2D\n\n@export var bullet_speed = 10.0\n\n\nfunc _ready() -> void:\n\tprint(bullet_speed)\n\ttake_damage(2)\n\n\nfunc take_damage(amount: int) -> void:\n\tbullet_speed -= amount\n"


static func run() -> bool:
	var path: String = "user://gun_turret.gd"
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	var ready_words: String = _words_of_event(view, "Print")
	var asked: bool = view.humanize_names_enabled()
	view.humanize_names_override = 1
	view.set_sheet(sheet)
	var lens_words: String = _words_of_event(view, "Print")
	view.free()
	return SUPPORT.pins(P, [
		["a script opened as a sheet does not respell names", asked, false],
		["a variable and a called function read as written", ready_words,
			"On created | Print bullet_speed | Call take_damage   amount = 2"],
		["the View lens still respells them once it is turned on", lens_words,
			"On created | Print Bullet Speed | Call take damage   amount = 2"],
		["a function's display name is its name", EventSheetViewportLenses.function_display_name("take_damage"), "take_damage"],
		["...unless it was published under another", EventSheetViewportLenses.function_display_name("take_damage", "Hurt"), "Hurt"],
		["a method named as the function it is", EventSheetSentence.function_words("rebuild_preview"), "rebuild_preview"],
		["a script with no class_name is the object its file names", EventSheetArrangement.self_object_of(sheet), "gun_turret"],
	])


## The words of the first event row whose words hold `needle`, minus its trigger glyph.
static func _words_of_event(view: EventSheetViewport, needle: String) -> String:
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null or row_data.row_type != EventRowData.RowType.EVENT:
			continue
		var words := PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			var text: String = span.text.strip_edges()
			if not text.is_empty() and text.length() > 1:
				words.append(span.text)
		var joined: String = " | ".join(words)
		if joined.contains(needle):
			return joined
	return ""
