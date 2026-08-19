# Godot EventSheets - the Scene dock and the sheet follow each other's selection.
# Two-way, and the difficulty is entirely in not fighting: each half causes the other's trigger, so
# the crossing guard is what makes the follow possible at all. Pins: which Object-bar entry a
# selected node is (by name, then by class, then nothing), which node a selected row is about, the
# guard recognising the echo of a selection this side caused, and the setting that turns it off.
@tool
class_name SceneSelectionLinkTest
extends RefCounted


static func _census() -> Array:
	return [
		{"label": "Enemy", "kind": "node", "class": "CharacterBody2D"},
		{"label": "CharacterBody2D", "kind": "node", "class": "CharacterBody2D"},
		{"label": "Timer", "kind": "node", "class": "Timer"},
	]


static func _row_about(object_label: String) -> EventRowData:
	var row_data: EventRowData = EventRowData.new()
	var span: SemanticSpan = SemanticSpan.new()
	span.text = object_label
	span.metadata = {"lane": "action", "object_label": object_label}
	row_data.spans.append(span)
	return row_data


static func run() -> bool:
	var ok: bool = true

	# ── Scene dock -> sheet: which entry a node IS ──
	ok = _check("a node is matched by its own name",
		EventSheetSceneSelectionLink.object_label_for_node(_census(), "Enemy",
			"CharacterBody2D"), "Enemy") and ok
	ok = _check("a node the sheet only knows by kind falls back to the class",
		EventSheetSceneSelectionLink.object_label_for_node(_census(), "Hero",
			"CharacterBody2D"), "CharacterBody2D") and ok
	ok = _check("a node this sheet does not talk about matches nothing",
		EventSheetSceneSelectionLink.object_label_for_node(_census(), "Hero", "Camera2D"),
		"") and ok
	ok = _check("an empty census matches nothing",
		EventSheetSceneSelectionLink.object_label_for_node([], "Enemy", "CharacterBody2D"),
		"") and ok

	# ── sheet -> Scene dock: which node a row is about ──
	ok = _check("a row names the object it is about",
		EventSheetSceneSelectionLink.object_label_for_row(_row_about("Enemy")), "Enemy") and ok
	ok = _check("a row about nothing in particular selects nothing",
		EventSheetSceneSelectionLink.object_label_for_row(EventRowData.new()), "") and ok
	ok = _check("no row at all selects nothing",
		EventSheetSceneSelectionLink.object_label_for_row(null), "") and ok

	# ── The guard: nothing is crossing until something crosses ──
	var link: EventSheetSceneSelectionLink = EventSheetSceneSelectionLink.new(null)
	ok = _check("a fresh link is not crossing", link.is_crossing(), false) and ok
	ok = _check("and is expecting no echo", link.driven_label(), "") and ok
	# follow_row with no dock is a no-op rather than an error - the guard must not latch on.
	link.follow_row(_row_about("Enemy"))
	ok = _check("a crossing that could not run leaves no guard behind", link.is_crossing(),
		false) and ok

	# ── The setting ──
	var had: bool = ProjectSettings.has_setting(EventSheetSceneSelectionLink.FOLLOW_SETTING)
	var before: Variant = ProjectSettings.get_setting(
		EventSheetSceneSelectionLink.FOLLOW_SETTING, true) if had else null
	ProjectSettings.set_setting(EventSheetSceneSelectionLink.FOLLOW_SETTING, false)
	ok = _check("the setting turns the follow off",
		EventSheetSceneSelectionLink.follow_enabled(), false) and ok
	ProjectSettings.set_setting(EventSheetSceneSelectionLink.FOLLOW_SETTING, true)
	ok = _check("and back on", EventSheetSceneSelectionLink.follow_enabled(), true) and ok
	if had:
		ProjectSettings.set_setting(EventSheetSceneSelectionLink.FOLLOW_SETTING, before)
	else:
		ProjectSettings.set_setting(EventSheetSceneSelectionLink.FOLLOW_SETTING, null)
	# An unset setting follows by default: the reader who came from an editor where the layout and
	# the sheet were one surface should not have to find a switch.
	ok = _check("the follow is on when nothing has been set",
		EventSheetSceneSelectionLink.follow_enabled(), true) and ok
	if had:
		ProjectSettings.set_setting(EventSheetSceneSelectionLink.FOLLOW_SETTING, before)

	# ── The offer, by value: an offer, never a silent filter ──
	ok = _check("the offer names the object",
		EventSheetSceneSelectionLink.FILTER_OFFER % "Enemy",
		"Filter events to Enemy") and ok

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] scene_selection_link_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
