# EventSheet - the addon guide scaffolder. Pins VALUES from a real pack (Sine): the factual
# tables must carry the script's actual members (never phantoms), the human sections must hold
# exactly the house standard's blank count (15 use cases + 5 one-liners), and the TOC must stay
# sequential. Unreadable input fails closed.
@tool
class_name AddonGuideScaffoldTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	var markdown: String = EventSheetAddonGuideScaffold.generate("res://eventsheet_addons/sine/sine_behavior.gd")
	all_passed = _check("title leads with the category and the class doc",
		markdown.begins_with("# Sine - Makes a Node2D oscillate"), true) and all_passed
	all_passed = _check("a real action verb is in the table", markdown.contains("| `set_sine_phase` | degrees: float |"), true) and all_passed
	all_passed = _check("a real knob row carries type and default", markdown.contains("| `magnitude` | float | `50.0` |"), true) and all_passed
	all_passed = _check("the Self section carries the real chain", markdown.contains("$SineBehavior."), true) and all_passed
	all_passed = _check("private members never leak", markdown.contains("`_"), false) and all_passed

	# The house standard's blanks: exactly 15 use-case headings + 5 one-liner bullets.
	var use_cases: int = 0
	var one_liners: int = 0
	for line: String in markdown.split("\n"):
		if line.begins_with("### ") and line.contains("(Name this use case)"):
			use_cases += 1
		if line.begins_with("- **(One-liner use case"):
			one_liners += 1
	all_passed = _check("exactly 15 use-case blanks", use_cases, 15) and all_passed
	all_passed = _check("exactly 5 one-liner blanks", one_liners, 5) and all_passed

	# TOC: numbered 1..N with no gaps.
	var toc_numbers: Array = []
	var toc_regex: RegEx = RegEx.create_from_string("^(\\d+)\\. \\[")
	for line: String in markdown.split("\n"):
		var hit: RegExMatch = toc_regex.search(line)
		if hit != null:
			toc_numbers.append(int(hit.get_string(1)))
	all_passed = _check("TOC numbers are sequential", toc_numbers, [1, 2, 3, 4, 5, 6, 7]) and all_passed

	all_passed = _check("unreadable input fails closed", EventSheetAddonGuideScaffold.generate("res://nope.gd"), "") and all_passed
	# The API surface delegates to the same generator.
	all_passed = _check("EventSheets.addon_guide_skeleton delegates",
		EventSheets.addon_guide_skeleton("res://eventsheet_addons/sine/sine_behavior.gd") == markdown, true) and all_passed
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] addon_guide_scaffold_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
