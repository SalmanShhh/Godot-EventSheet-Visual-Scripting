@tool
class_name RunControlsAdoptTest
extends RefCounted

# Two strips carry the preview buttons - the toolbar and Simple mode's Add toolbar - and both
# adopt the same four ids. A single slot per id let whichever strip built LAST steal the other's
# relabel, so the toolbar's Preview button never became Stop while a game ran. This pins the
# multi-adopter registry: every adopted button receives the label, a freed adopter is pruned
# rather than crashed on, and re-adopting the same button does not double it.


static func run() -> bool:
	var ok: bool = true
	var controls: EventSheetRunControls = EventSheetRunControls.new()
	var first: Button = Button.new()
	var second: Button = Button.new()
	controls.adopt("preview_layout", first)
	controls.adopt("preview_layout", second)
	controls.refresh()
	var resting: String = EventSheetL10n.translate(EventSheetRunControls.label_for("preview_layout", false))
	ok = _check("the first adopter is relabelled, not stolen from", first.text, resting) and ok
	ok = _check("the second adopter is relabelled too", second.text, resting) and ok
	ok = _check("the running label is the stop word", EventSheetRunControls.label_for("preview_layout", true), "■ Stop") and ok
	controls.adopt("preview_layout", second)
	controls.refresh()
	ok = _check("re-adopting does not double the entry", second.text, resting) and ok
	first.free()
	var third: Button = Button.new()
	controls.adopt("preview_layout", third)
	controls.refresh()
	ok = _check("a freed adopter is pruned and the newcomer is relabelled", third.text, resting) and ok
	ok = _check("the survivor still wears its label after the prune", second.text, resting) and ok
	second.free()
	third.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] run_controls_adopt_test: %s" % label)
		return true
	print("[FAIL] run_controls_adopt_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
