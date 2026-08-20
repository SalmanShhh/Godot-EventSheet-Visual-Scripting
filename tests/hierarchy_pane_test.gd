# Godot EventSheets - the Hierarchy pane (X15) and the three hierarchy Doctor notes (X17).
#
# What this pins, and why each half matters:
#
#   READING   the words the pane shows for a parent and for each child, character for character.
#             They are the words the batch's readings use, so a drift here is a drift between the
#             pane and the canvas - the one thing the pane promises can never happen.
#   WRITING   the exact GDScript each gesture writes. This is the contract with the readings: the
#             pane writes the spellings they recognise, so what it wrote reads back as what it did.
#             The round trip is pinned directly - write the lines, read them back, get the flags.
#   NOTES     the three footguns, each with the shape that IS the bug and the shape that is the
#             accepted fix, so neither check can start accusing working code.
#
# Values, never counts: every assertion below compares a string or a list of strings.
@tool
class_name HierarchyPaneTest
extends RefCounted


static func run() -> bool:
	var passed: bool = true
	passed = _reading() and passed
	passed = _writing() and passed
	passed = _round_trip() and passed
	passed = _doctor_notes() and passed
	return passed


## What the pane SAYS. The four child shapes from the pane's own design, each pinned whole.
static func _reading() -> bool:
	var passed: bool = true
	passed = _check("a plain child says only its name and type",
		EventSheetObjectHierarchy.child_text({"label": "Camera Pivot", "type": "Camera3D"}),
		"Camera Pivot ▸ Camera3D") and passed
	passed = _check("a child with children of its own counts them",
		EventSheetObjectHierarchy.child_text({"label": "Hand", "child_count": 1}),
		"Hand · 1 child") and passed
	passed = _check("more than one child of its own reads plural",
		EventSheetObjectHierarchy.child_text({"label": "Hand", "child_count": 3}),
		"Hand · 3 children") and passed
	passed = _check("a detached child wears the broken link",
		EventSheetObjectHierarchy.child_text({"label": "HealthBar", "ignores_movement": true}),
		"HealthBar ⛓ ignores parent's movement") and passed
	passed = _check("a flagged child spells its three transforms out",
		EventSheetObjectHierarchy.child_text({"label": "Hat",
			"transforms": {"position": true, "angle": true, "size": false}}),
		"Hat transforms: position ✓ angle ✓ size ✗") and passed
	passed = _check("the layout parent carries its note",
		EventSheetObjectHierarchy.parent_text({"parent": {"label": "Level", "note": "(the layout)"}}),
		"Level (the layout)") and passed
	passed = _check("an ordinary parent is just its name",
		EventSheetObjectHierarchy.parent_text({"parent": {"label": "Hand", "note": ""}}),
		"Hand") and passed
	passed = _check("nothing above it says nothing",
		EventSheetObjectHierarchy.parent_text({"parent": {}}), "") and passed
	passed = _check("the children header counts both halves",
		EventSheetObjectHierarchy.children_header({"children": [{}, {}, {}, {}]}),
		"▾ children (4)") and passed
	# Only a node has a place in a tree, so the pane is simply absent for the rest.
	passed = _check("a group gets no hierarchy pane",
		EventSheetObjectHierarchy.is_node_object({"kind": "group"}), false) and passed
	passed = _check("an autoload gets no hierarchy pane",
		EventSheetObjectHierarchy.is_node_object({"kind": "autoload"}), false) and passed
	passed = _check("the sheet's own object does get one",
		EventSheetObjectHierarchy.is_node_object({"kind": "script"}), true) and passed
	return passed


## What the pane WRITES. These lines are the contract with the readings, so they are pinned whole
## rather than probed for substrings.
static func _writing() -> bool:
	var passed: bool = true
	passed = _check("a plain Add child is one reparent line",
		Array(EventSheetObjectHierarchy.add_child_lines("$Head", "hat",
			EventSheetObjectHierarchy.default_flags(), "3D")),
		["hat.reparent($Head)"]) and passed
	var snapping: Dictionary = EventSheetObjectHierarchy.default_flags()
	snapping["keep_place"] = false
	passed = _check("snapping to it drops the keep-place argument",
		Array(EventSheetObjectHierarchy.add_child_lines("$Horse/Saddle", "rider", snapping, "3D")),
		["rider.reparent($Horse/Saddle, false)"]) and passed
	# The size flag needs BOTH lines: an ordinary child inherits its parent's whole transform, so a
	# follower saying "do not copy the size" changes nothing while the child still follows on its own.
	var no_size: Dictionary = EventSheetObjectHierarchy.default_flags()
	no_size["size"] = false
	passed = _check("transform size off detaches the child AND drives back the rest",
		Array(EventSheetObjectHierarchy.add_child_lines("%Head", "hat", no_size, "3D")), [
			"hat.reparent(%Head)",
			"hat.top_level = true",
			"var __follow_hat := RemoteTransform3D.new()",
			"%Head.add_child(__follow_hat)",
			"__follow_hat.remote_path = __follow_hat.get_path_to(hat)",
			"__follow_hat.update_scale = false"
		]) and passed
	passed = _check("a 2D parent gets the 2D follower",
		Array(EventSheetObjectHierarchy.add_child_lines("$Head", "hat", no_size, "2D"))[2],
		"var __follow_hat := RemoteTransform2D.new()") and passed
	var nothing_follows: Dictionary = EventSheetObjectHierarchy.default_flags()
	nothing_follows["position"] = false
	nothing_follows["angle"] = false
	nothing_follows["size"] = false
	passed = _check("all three transforms off is the escape hatch, with no follower",
		Array(EventSheetObjectHierarchy.add_child_lines("$Enemy", "$Enemy/HealthBar", nothing_follows, "2D")),
		["$Enemy/HealthBar.reparent($Enemy)", "$Enemy/HealthBar.top_level = true"]) and passed
	var not_destroyed: Dictionary = EventSheetObjectHierarchy.default_flags()
	not_destroyed["destroy"] = false
	passed = _check("destroy with parent off hands the child back as the parent leaves",
		Array(EventSheetObjectHierarchy.add_child_lines("$Hand", "item", not_destroyed, "3D")), [
			"item.reparent($Hand)",
			"$Hand.tree_exiting.connect(func() -> void: item.reparent(get_tree().current_scene))"
		]) and passed
	passed = _check("Remove from parent hands it to the layout, keeping its place",
		EventSheetObjectHierarchy.remove_from_parent_line("item"),
		"item.reparent(get_tree().current_scene)") and passed
	passed = _check("nothing is written without both halves",
		Array(EventSheetObjectHierarchy.add_child_lines("", "hat",
			EventSheetObjectHierarchy.default_flags(), "3D")), []) and passed
	# 2D or 3D is decided by the classes in play: a RemoteTransform2D under a Node3D moves nothing.
	passed = _check("the dimension follows the child's own class",
		EventSheetObjectHierarchy.dimension_for(null, {"class": "Node3D"}, {"class": "Sprite2D"}), "2D") and passed
	passed = _check("with no class on the child the parent's decides",
		EventSheetObjectHierarchy.dimension_for(null, {"class": "Node3D"}, {"class": ""}), "3D") and passed
	return passed


## The round trip: write the lines a gesture writes, put them in a sheet, and read the pane back out
## of it. This is the whole promise - the pane and the canvas describe one tree.
static func _round_trip() -> bool:
	var passed: bool = true
	var lines: PackedStringArray = PackedStringArray()
	var no_size: Dictionary = EventSheetObjectHierarchy.default_flags()
	no_size["size"] = false
	lines.append_array(EventSheetObjectHierarchy.add_child_lines("$Head", "hat", no_size, "3D"))
	var nothing_follows: Dictionary = EventSheetObjectHierarchy.default_flags()
	nothing_follows["position"] = false
	nothing_follows["angle"] = false
	nothing_follows["size"] = false
	lines.append_array(EventSheetObjectHierarchy.add_child_lines("$Head", "$HealthBar", nothing_follows, "3D"))
	var snapping: Dictionary = EventSheetObjectHierarchy.default_flags()
	snapping["keep_place"] = false
	lines.append_array(EventSheetObjectHierarchy.add_child_lines("$Saddle", "rider", snapping, "3D"))
	lines.append(EventSheetObjectHierarchy.remove_from_parent_line("crate"))
	var sheet: EventSheetResource = _sheet_of(lines)

	var head: Dictionary = EventSheetObjectHierarchy.facts_for(sheet,
		{"label": "Head", "kind": "node", "class": "Node3D", "path": "$Head"}, "")
	var head_children: Array = []
	for child: Variant in head.get("children", []):
		head_children.append(EventSheetObjectHierarchy.child_text(child as Dictionary))
	passed = _check("the flagged child and the detached one read back as they were written",
		head_children, ["hat transforms: position ✓ angle ✓ size ✗", "HealthBar ⛓ ignores parent's movement"]) and passed

	var rider: Dictionary = EventSheetObjectHierarchy.facts_for(sheet,
		{"label": "rider", "kind": "node", "class": "Node3D", "path": ""}, "")
	passed = _check("a snapped child names the parent it was snapped to",
		EventSheetObjectHierarchy.parent_text(rider), "Saddle") and passed

	var crate: Dictionary = EventSheetObjectHierarchy.facts_for(sheet,
		{"label": "crate", "kind": "node", "class": "Node3D", "path": ""}, "")
	# With no scene behind the sheet there is no layout NAME to show, so the pane says the word and
	# stops - a note that just repeats its own label is worse than no note.
	passed = _check("an unparented object reads as belonging to the layout",
		EventSheetObjectHierarchy.parent_text(crate), "the layout") and passed

	# The two-line remove+add spelling parents just as the one-line reparent does, so a hand-typed
	# file and a pane-written one show the same tree.
	var by_hand: EventSheetResource = _sheet_of(PackedStringArray([
		"item.get_parent().remove_child(item)",
		"$Back.add_child(item)"
	]))
	var back: Dictionary = EventSheetObjectHierarchy.facts_for(by_hand,
		{"label": "Back", "kind": "node", "class": "Node3D", "path": "$Back"}, "")
	var back_children: Array = []
	for child: Variant in back.get("children", []):
		back_children.append(str((child as Dictionary).get("label", "")))
	passed = _check("the remove-then-add spelling reads as the same one parenting",
		back_children, ["item"]) and passed
	return passed


## X17 - the three notes. Each is shown the shape that IS the bug and the shape that is the fix.
static func _doctor_notes() -> bool:
	var passed: bool = true
	var moving_walk: String = "\n".join(PackedStringArray([
		"func drop_all() -> void:",
		"\tfor unit in $Squad.get_children():",
		"\t\tunit.reparent(get_tree().current_scene)"
	]))
	passed = _check("a walk that moves the child it is walking is named",
		Array(EventSheetProjectDoctor.reparenting_children_loops(moving_walk)), ["unit"]) and passed
	passed = _check("walking a copy is the fix, and is never accused",
		Array(EventSheetProjectDoctor.reparenting_children_loops(
			moving_walk.replace(".get_children()", ".get_children().duplicate()"))), []) and passed
	passed = _check("a walk that only reads its children is left alone",
		Array(EventSheetProjectDoctor.reparenting_children_loops("\n".join(PackedStringArray([
			"func heal() -> void:",
			"\tfor unit in $Squad.get_children():",
			"\t\tunit.hp += 10"
		])))), []) and passed

	passed = _check("a reparent of self in _ready is named, with the line",
		Array(EventSheetProjectDoctor.self_reparent_in_ready("\n".join(PackedStringArray([
			"func _ready() -> void:",
			"\treparent($Saddle)"
		])))), ["reparent($Saddle)"]) and passed
	passed = _check("deferring it is the fix, and is never accused",
		Array(EventSheetProjectDoctor.self_reparent_in_ready("\n".join(PackedStringArray([
			"func _ready() -> void:",
			"\tcall_deferred(\"reparent\", $Saddle)"
		])))), []) and passed
	passed = _check("reparenting somebody ELSE in _ready is fine",
		Array(EventSheetProjectDoctor.self_reparent_in_ready("\n".join(PackedStringArray([
			"func _ready() -> void:",
			"\t$Hat.reparent($Head)"
		])))), []) and passed

	var dangling: String = "\n".join(PackedStringArray([
		"var carried: Node3D = null",
		"",
		"func pick_up(item: Node3D) -> void:",
		"\titem.reparent($Hand)",
		"\tcarried = item",
		"",
		"func die() -> void:",
		"\t$Hand.queue_free()",
		"\tcarried.hide()"
	]))
	passed = _check("a held child whose parent this file frees is named",
		Array(EventSheetProjectDoctor.freed_parent_references(dangling)), ["carried"]) and passed
	passed = _check("asking whether it is still there is the fix, and is never accused",
		Array(EventSheetProjectDoctor.freed_parent_references(
			dangling.replace("\tcarried.hide()", "\tif is_instance_valid(carried):\n\t\tcarried.hide()"))), []) and passed
	passed = _check("freeing something that holds nothing of ours is fine",
		Array(EventSheetProjectDoctor.freed_parent_references(
			dangling.replace("$Hand.queue_free()", "$Rock.queue_free()"))), []) and passed

	# All three ride the quick-fix seam, and each chip says the one edit to make.
	passed = _check("the walk note offers walking a copy",
		_fix_labels("reparent-while-iterating", "unit"), ["Walk a copy of the children"]) and passed
	passed = _check("the _ready note offers deferring it",
		_fix_labels("reparent-in-ready", "reparent($Saddle)"), ["Do it after the tree settles"]) and passed
	passed = _check("the dangling note names the variable in its chip",
		_fix_labels("freed-parent-reference", "carried"), ["Ask whether carried is still there"]) and passed
	# Advisory only: none of the three may ever turn a clean project red.
	passed = _check("the three notes are notes, never errors", _severities_of(dangling), ["info"]) and passed
	return passed


static func _fix_labels(check_id: String, subject: String) -> Array:
	var labels: Array = []
	for offer: Dictionary in EventSheetQuickFixes.fixes_for({"check": check_id, "subject": subject}):
		labels.append(str(offer.get("label", "")))
	return labels


## The severities the hierarchy notes report for one source, deduplicated - "info" and nothing else.
static func _severities_of(source: String) -> Array:
	var findings: Array[Dictionary] = []
	for held: String in EventSheetProjectDoctor.freed_parent_references(source):
		findings.append({"severity": "info", "subject": held})
	var severities: Array = []
	for finding: Dictionary in findings:
		var severity: String = str(finding.get("severity", ""))
		if not severities.has(severity):
			severities.append(severity)
	return severities


## One sheet holding the given lines as a start-of-layout action - the shape the pane writes into.
static func _sheet_of(lines: PackedStringArray) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node3D"
	var row: RawCodeRow = RawCodeRow.new()
	row.code = "\n".join(lines)
	var setup: EventRow = EventRow.new()
	setup.trigger_provider_id = "Core"
	setup.trigger_id = "OnReady"
	setup.actions.append(row)
	sheet.events.append(setup)
	return sheet


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] hierarchy_pane_test: %s" % label)
		return true
	print("[FAIL] hierarchy_pane_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
