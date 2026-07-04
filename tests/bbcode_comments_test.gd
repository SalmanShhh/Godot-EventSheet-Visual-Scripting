# Godot EventSheets - BBCode-lite comments
# [b]/[i]/[color=…] style comment text on the canvas; the RAW text (tags included) stays
# the editing/serialization truth, so styling can never lose data.
@tool
class_name BBCodeCommentsTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# Parser: colors, bold, nesting, named colors, graceful unknown/unclosed tags.
	var segments: Array[Dictionary] = EventSheetBBCodeLite.parse("plain [b]bold [color=#ff0000]red[/color][/b] tail")
	all_passed = _check("segment count", segments.size(), 4) and all_passed
	all_passed = _check("plain head", segments[0].get("text"), "plain ") and all_passed
	all_passed = _check("bold flag", segments[1].get("bold"), true) and all_passed
	all_passed = _check("nested color keeps bold",
		segments[2].get("bold") == true and (segments[2].get("color") as Color).is_equal_approx(Color("#ff0000")), true) and all_passed
	all_passed = _check("tail resets", segments[3].get("bold") == false and segments[3].get("color") == null, true) and all_passed
	var named: Array[Dictionary] = EventSheetBBCodeLite.parse("[color=red]x[/color]")
	all_passed = _check("named colors parse", (named[0].get("color") as Color).is_equal_approx(Color.RED), true) and all_passed
	var unknown: Array[Dictionary] = EventSheetBBCodeLite.parse("a [wave]b[/wave] c")
	var unknown_text: String = ""
	for segment in unknown:
		unknown_text += str(segment.get("text"))
	all_passed = _check("unknown tags strip, inner text survives", unknown_text, "a b c") and all_passed
	var unclosed: Array[Dictionary] = EventSheetBBCodeLite.parse("a [b]rest")
	all_passed = _check("unclosed tags degrade gracefully",
		unclosed.size() == 2 and unclosed[1].get("text") == "rest" and unclosed[1].get("bold") == true, true) and all_passed
	all_passed = _check("strip() flattens to plain text",
		EventSheetBBCodeLite.strip("[b]hi[/b] [color=red]there[/color]"), "hi there") and all_passed
	all_passed = _check("has_markup ignores plain brackets",
		EventSheetBBCodeLite.has_markup("array[0] access"), false) and all_passed

	# Spans: markup lines carry segments; the span TEXT stays raw (edit/serialize truth).
	var sheet: EventSheetResource = EventSheetResource.new()
	var comment: CommentRow = CommentRow.new()
	comment.text = "[b]Setup[/b] phase\nplain line"
	sheet.events.append(comment)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var row: EventRowData = viewport.get_flat_rows()[0].get("row")
	var styled_meta: Dictionary = row.spans[0].metadata
	all_passed = _check("markup lines carry segments", (styled_meta.get("bbcode_segments", []) as Array).size() >= 2, true) and all_passed
	all_passed = _check("span text stays RAW (no data loss on edit)", row.spans[0].text, "[b]Setup[/b] phase") and all_passed
	all_passed = _check("plain lines carry no segments",
		(row.spans[1].metadata as Dictionary).has("bbcode_segments"), false) and all_passed
	editor.free()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] bbcode_comments_test: %s" % label)
		return true
	print("[FAIL] bbcode_comments_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
