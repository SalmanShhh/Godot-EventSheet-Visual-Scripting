# EventSheets - a text saved by the Save System comes back exactly, in every file format.
#
# csv, ini and xml keep each value on one line, and the pack used to strip the line breaks that
# var_to_str leaves INSIDE a text, so "two" + newline + "lines" came back as "twolines". Each format is
# given texts that are hard on it (line breaks, a tab, quotes, backslashes, the format's own delimiters,
# unicode, a control character, a key with an equals sign) and must give every one of them back.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "save_text_round_trip_test"
const PACK := "res://eventsheet_addons/save_system/save_system_addon.gd"
const FORMATS: Array[String] = ["config", "json", "binary", "csv", "ini", "xml"]


static func run() -> bool:
	var script: GDScript = load(PACK)
	var rows: Array = []
	var nasty: Dictionary = _nasty()
	for fmt: String in FORMATS:
		var system: Node = script.new()
		system.save_directory = SUPPORT.own_folder("save_text")
		system.file_pattern = "round_%s_{slot}.%s" % [fmt, {"config": "cfg", "binary": "dat"}.get(fmt, fmt)]
		system.format = fmt
		system.slot = 3
		system.backup_count = 0
		for key: String in nasty:
			system.save_value(key, nasty[key])
		# A second system reads the file from disk: nothing held in memory is helping.
		var reader: Node = script.new()
		reader.save_directory = system.save_directory
		reader.file_pattern = system.file_pattern
		reader.format = fmt
		reader.slot = 3
		for key: String in nasty:
			rows.append(["%s keeps %s" % [fmt, key], reader.load_value(key, "MISSING"), nasty[key]])
		system.delete_slot()
		system.free()
		reader.free()
	# A file the OLD code wrote (line breaks already stripped, no escapes) is still read as it was.
	var legacy_dir: String = SUPPORT.own_folder("save_text_legacy")
	_write(legacy_dir + "/old_0.csv", "gems,5\nname,\"\"\"Rex\"\"\"\nstate,\"{\"\"hp\"\": 3}\"\n")
	_write(legacy_dir + "/old_0.ini", "[save]\ngems=5\nname=\"Rex\"\n")
	_write(legacy_dir + "/old_0.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<save section=\"save\">\n\t<entry key=\"gems\">5</entry>\n\t<entry key=\"name\">&quot;Rex&quot;</entry>\n</save>\n")
	for fmt: String in ["csv", "ini", "xml"]:
		var old_reader: Node = script.new()
		old_reader.save_directory = legacy_dir
		old_reader.file_pattern = "old_{slot}.%s" % fmt
		old_reader.format = fmt
		old_reader.slot = 0
		rows.append(["an older %s file still reads: a number" % fmt, old_reader.load_value("gems", "MISSING"), 5])
		rows.append(["an older %s file still reads: a text" % fmt, old_reader.load_value("name", "MISSING"), "Rex"])
		old_reader.free()
	# Output that needed no change is byte for byte what it was: a plain number is the line it always was.
	var plain: Node = script.new()
	rows.append(["a value with no line break is written as it always was", plain._one_line("[1, 2]"), "[1, 2]"])
	rows.append(["pretty-printed elements are joined as before", plain._one_line("{" + char(10) + "\"a\": 1" + char(10) + "}"), "{\"a\": 1}"])
	rows.append(["a backslash and an n inside a text stay two characters", str_to_var(plain._one_line(var_to_str("a" + char(92) + "nb"))), "a" + char(92) + "nb"])
	plain.free()
	return SUPPORT.pins(P, rows)


static func _nasty() -> Dictionary:
	var lf: String = char(10)
	var nasty: Dictionary = {}
	nasty["two_lines"] = "first" + lf + "second"
	nasty["crlf"] = "a" + char(13) + lf + "b"
	nasty["blank_line"] = "a" + lf + lf + "b" + lf
	nasty["tab"] = "col1" + char(9) + "col2"
	nasty["quotes"] = "say " + char(34) + "hi" + char(34) + " and " + char(39) + "bye" + char(39)
	nasty["backslashes"] = "C:" + char(92) + "dir" + char(92) + "new" + char(92) + "n" + char(92) + char(92)
	nasty["delimiters"] = "a,b;c=d [e] #f <g> &h &amp; " + char(37) + "41"
	nasty["unicode"] = "caf" + char(233) + " " + String.chr(0x65E5) + String.chr(0x672C) + " " + String.chr(0x1F600)
	nasty["control"] = "bell" + char(7) + "end"
	nasty["leading_space"] = "  padded  "
	nasty["empty"] = ""
	nasty["list_of_texts"] = ["x" + lf + "y", "z"]
	nasty["nested"] = {"inner": "p" + lf + "q", "n": 3}
	nasty["a=b"] = "key with an equals sign"
	nasty["[sect]"] = "key that looks like a section"
	nasty["; note"] = "key that looks like a comment"
	nasty["pct%41"] = "key with a percent sign"
	return nasty


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
