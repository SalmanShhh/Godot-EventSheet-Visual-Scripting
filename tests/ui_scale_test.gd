# EventSheet - editor display scale (the HiDPI contract)
#
# On a Retina Mac the editor runs at 200%: Godot bakes that scale into every size IT generates
# (theme fonts, icons, margins), so plugin chrome that passes a LITERAL 12 to draw_string - or
# overrides a Control's font_size with a literal - reads at HALF the size of the surrounding
# editor. The one bridge is EventSheetPalette.scaled()/scaled_f(): author sizes at 1x, multiply
# at use time. This test pins the bridge's math AND lints the source so a new literal can never
# ship again (the bug was invisible on every 100% Windows/Linux dev machine).
@tool
class_name UIScaleTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# ── The bridge's math ─────────────────────────────────────────────────────────────────
	EventSheetPalette.set_scale_override(2.0)
	all_passed = _check("scaled(12) at 200% is 24", EventSheetPalette.scaled(12), 24) and all_passed
	all_passed = _check("scaled(11) at 200% is 22", EventSheetPalette.scaled(11), 22) and all_passed
	all_passed = _check("scaled_f(22.0) at 200% is 44.0", EventSheetPalette.scaled_f(22.0), 44.0) and all_passed
	EventSheetPalette.set_scale_override(1.5)
	all_passed = _check("scaled(13) at 150% rounds to 20", EventSheetPalette.scaled(13), 20) and all_passed
	EventSheetPalette.set_scale_override(1.0)
	all_passed = _check("scaled(12) at 100% is unchanged", EventSheetPalette.scaled(12), 12) and all_passed
	EventSheetPalette.set_scale_override(0.0)  # back to auto-detect
	# Headless (no editor): auto-detect lands on exactly 1.0, so tests and harnesses see 1x.
	all_passed = _check("headless auto-detect scale is 1.0", EventSheetPalette.ui_scale(), 1.0) and all_passed

	# ── Source lint: no literal font sizes outside the bridge ───────────────────────────
	# A Control font_size override with an integer literal replaces the editor's SCALED size
	# with an unscaled one; a draw_string/get_string_size int literal draws at 1x forever.
	# Both classes of regression are caught here, across the whole plugin.
	var override_pattern: RegEx = RegEx.create_from_string("add_theme_font_size_override\\((&?\"font_size\"),\\s*\\d")
	var draw_pattern: RegEx = RegEx.create_from_string("(draw_string|draw_multiline_string|get_string_size)\\([^()]*,\\s*\\d+\\s*[,)]")
	for path: String in _plugin_scripts():
		var code: String = _code_only(path)
		var override_hit: RegExMatch = override_pattern.search(code)
		all_passed = _check("no literal font_size override in %s%s" % [path.get_file(),
			"" if override_hit == null else (" (found: %s)" % override_hit.get_string())],
			override_hit == null, true) and all_passed
		for line: String in code.split("\n"):
			var draw_hit: RegExMatch = draw_pattern.search(line)
			if draw_hit == null:
				continue
			# Only flag when the int literal sits in the SIZE slot: the segment before it must
			# already carry the width arg (a float or expression), i.e. "-1.0, 12," style tails.
			if line.contains("-1.0, %s" % _int_tail(draw_hit.get_string())) or _looks_like_size_literal(line):
				all_passed = _check("no literal draw size in %s: %s" % [path.get_file(), line.strip_edges().left(90)],
					false, true) and all_passed
	return all_passed


## The int literal at the tail of a matched call fragment ("... , 12," -> "12").
static func _int_tail(fragment: String) -> String:
	var digits: String = ""
	for i: int in range(fragment.length() - 1, -1, -1):
		var ch: String = fragment[i]
		if ch >= "0" and ch <= "9":
			digits = ch + digits
		elif not digits.is_empty():
			break
	return digits


## True when a draw/measure line passes a bare int (8..29) where the font size goes - the
## design range of every text size in this plugin, so a literal there is always a miss.
static func _looks_like_size_literal(line: String) -> bool:
	var size_slot: RegEx = RegEx.create_from_string(",\\s*(2[0-9]|1[0-9]|[89])\\s*,\\s*(Color|[a-z_]+_color|pill\\[|chip\\.|segment\\.|accent|label_color)")
	return size_slot.search(line) != null


static func _plugin_scripts() -> PackedStringArray:
	var scripts: PackedStringArray = PackedStringArray()
	var queue: Array[String] = ["res://addons/eventsheet", "res://addons/eventforge"]
	while not queue.is_empty():
		var dir_path: String = queue.pop_back()
		for sub: String in DirAccess.get_directories_at(dir_path):
			queue.append(dir_path + "/" + sub)
		for file: String in DirAccess.get_files_at(dir_path):
			if file.ends_with(".gd"):
				scripts.append(dir_path + "/" + file)
	return scripts


## Source with comment lines stripped (a size in a comment creates no bug).
static func _code_only(path: String) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if not line.strip_edges().begins_with("#"):
			lines.append(line)
	return "\n".join(lines)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] ui_scale_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
