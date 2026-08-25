# Godot EventSheets - the group head, its bracket, its locals and its dialog (slice D).
#
# What this pins, in the order a reader meets it:
#   1. THE HEAD. One line: a folder mark, the title, the description beside it, then what the group
#      holds and its switch - found by span METADATA, never by position, so a later span can be
#      added without re-pinning the file.
#   2. THE COUNTS. What "3 events · 1 local" is made of, including the nested-event roll-up, the
#      "off" lead a switched-off group gets, and the object names a FOLDED head adds.
#   3. THE BRACKET. Pure geometry: where the rule runs from and to, how deep nesting insets it, and
#      that a group with nothing visible under it draws none. Static, so it needs no viewport.
#   4. THE LOCALS. A group's own variables read as Local rows at the top of its body, with the echo
#      of the line the compiler really emits for them.
#   5. THE DIALOG. Its field order and the pure mutation behind Apply, including "a key the caller
#      left out leaves that fact alone".
#   6. THE PINNED HEAD. The parent trail shortened to two names with the full chain kept for the
#      hover, and the parts the pinned copy re-draws off the head row itself.
@tool
class_name GroupHeadTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_head_spans() and all_passed
	all_passed = _test_counts() and all_passed
	all_passed = _test_brackets() and all_passed
	all_passed = _test_group_locals() and all_passed
	all_passed = _test_dialog_fields() and all_passed
	all_passed = _test_pinned_head() and all_passed
	all_passed = _test_open_all_close_all() and all_passed
	if all_passed:
		print("[PASS] group_head: the head reads in one line, and its body wears its bracket.")
	return all_passed


# ── 1. The head ──


static func _test_head_spans() -> bool:
	var passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	var group: EventGroup = _group("Combat", "Damage, hits and death.")
	group.runtime_toggleable = true
	group.events.append(_event())
	sheet.events.append(group)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var head: EventRowData = _row_for(viewport, group)
	passed = _check("the head is on the canvas", head != null, true)
	if head == null:
		editor.free()
		return false
	passed = _check("the head reads in one line", head.line_count, 1) and passed
	passed = _check("it leads with a folder mark",
		_span_text(head, "badge_style", "glyph"), ViewportRowBuilder.GROUP_FOLDER_GLYPH) and passed
	passed = _check("the title is the group's name",
		_span_text(head, "group_title", true), "Combat") and passed
	passed = _check("the description sits on the same line",
		_span_text(head, "edit_kind", "group_description"), "Damage, hits and death.") and passed
	passed = _check("what it holds is at the right",
		_span_text(head, "group_counts", true), "1 event") and passed
	passed = _check("the counts hug the right edge",
		_span_flag(head, "group_counts", true, "align_right"), true) and passed
	passed = _check("a switchable group wears the ring",
		_span_text(head, "group_action", "toggleable"), ViewportRowBuilder.GROUP_TOGGLEABLE_GLYPH) and passed
	passed = _check("and the switch says it is on",
		_span_text(head, "group_action", "enabled"), ViewportRowBuilder.HEAD_SWITCH_ON_GLYPH) and passed
	# The head echoes the very line the compiler declares this group on, character for
	# character, so the row and the file cannot disagree about what the group is.
	passed = _check("the head echoes its own declaration",
		_span_text(head, "group_echo", true),
		str(SheetCompiler.group_declaration_lines(sheet.events).get(group, ""))) and passed
	passed = _check("...which is the @ace_group line itself",
		_span_text(head, "group_echo", true),
		"## @ace_group(uid=\"combat\", name=\"Combat\", description=\"Damage, hits and death.\", toggleable=true)") and passed
	passed = _check("the echo joins the right-anchored run",
		_span_flag(head, "group_echo", true, "align_right"), true) and passed
	# The right-anchored run lays out left to right without landing on top of itself.
	viewport.get_row_layout_for_test(_index_for(viewport, group))
	var counts_span: SemanticSpan = _span_with(head, "group_counts", true)
	var switch_span: SemanticSpan = _span_with(head, "group_action", "enabled")
	passed = _check("the switch draws to the right of the counts",
		switch_span.rect.position.x >= counts_span.rect.end.x - 0.5, true) and passed
	editor.free()

	# A group that is switched off says so, and its switch reads as off.
	var off_sheet: EventSheetResource = EventSheetResource.new()
	var off_group: EventGroup = _group("Old boss fight", "kept for reference")
	off_group.enabled = false
	off_group.events.append(_event())
	off_sheet.events.append(off_group)
	var off_editor: EventSheetEditor = EventSheetEditor.new()
	off_editor.setup(off_sheet)
	var off_head: EventRowData = _row_for(off_editor.get_viewport_control(), off_group)
	passed = _check("an off group leads its counts with off",
		_span_text(off_head, "group_counts", true), "off · 1 event") and passed
	passed = _check("and its switch reads off",
		_span_text(off_head, "group_action", "enabled"), ViewportRowBuilder.HEAD_SWITCH_OFF_GLYPH) and passed
	passed = _check("the whole head is faded", off_head.disabled, true) and passed
	off_editor.free()
	return passed


# ── 2. The counts ──


static func _test_counts() -> bool:
	var passed: bool = true
	var outer: EventGroup = _group("Gameplay", "")
	var inner: EventGroup = _group("Combat", "")
	inner.events.append(_event())
	inner.events.append(_event())
	inner.local_variables.append(_local("combo", "int", 0))
	outer.events.append(inner)
	outer.events.append(_event())
	passed = _check("nested events roll up into the outer count",
		EventSheetGroupFacts.counts_text(outer), "1 group · 3 events") and passed
	passed = _check("locals are counted where they are declared",
		EventSheetGroupFacts.counts_text(inner), "2 events · 1 local") and passed
	passed = _check("an empty group says so",
		EventSheetGroupFacts.counts_text(_group("Empty", "")), "empty") and passed
	passed = _check("a folded head adds the objects inside",
		EventSheetGroupFacts.counts_text(inner, PackedStringArray(["Coin", "Heart", "Player"])),
		"2 events · 1 local · Coin, Heart, Player") and passed
	passed = _check("and trails off past the first few",
		EventSheetGroupFacts.object_list_text(PackedStringArray(["Coin", "Heart", "Player", "Enemy"])),
		"Coin, Heart, Player…") and passed
	return passed


# ── 3. The bracket ──


static func _test_brackets() -> bool:
	var passed: bool = true
	# Gameplay(0) / Combat(1) / row(2) / row(2) / row(1)  - every row 20 tall.
	var rows: Array = [
		{"group": true, "indent": 0, "top": 0.0, "height": 20.0},
		{"group": true, "indent": 1, "top": 20.0, "height": 20.0},
		{"group": false, "indent": 2, "top": 40.0, "height": 20.0},
		{"group": false, "indent": 2, "top": 60.0, "height": 20.0},
		{"group": false, "indent": 1, "top": 80.0, "height": 20.0},
	]
	var brackets: Array[Dictionary] = EventSheetGroupFacts.brackets(rows)
	passed = _check("one bracket per group with a body", brackets.size(), 2) and passed
	passed = _check("the outer bracket starts under its head", float(brackets[0]["top"]), 20.0) and passed
	passed = _check("and ends at its last row's bottom", float(brackets[0]["bottom"]), 100.0) and passed
	passed = _check("the outer bracket sits at the left edge",
		float(brackets[0]["x"]), EventSheetGroupFacts.BRACKET_LEFT) and passed
	passed = _check("the inner bracket ends where its body does", float(brackets[1]["bottom"]), 80.0) and passed
	passed = _check("a nested bracket insets by one step",
		float(brackets[1]["x"]), EventSheetGroupFacts.BRACKET_LEFT + EventSheetGroupFacts.BRACKET_DEPTH_INSET) and passed
	passed = _check("nesting depth is counted in GROUPS", int(brackets[1]["depth"]), 1) and passed
	var folded: Array = [
		{"group": true, "indent": 0, "top": 0.0, "height": 20.0},
		{"group": false, "indent": 0, "top": 20.0, "height": 20.0},
	]
	passed = _check("a group with nothing visible under it draws no bracket",
		EventSheetGroupFacts.brackets(folded).size(), 0) and passed
	passed = _check("no rows, no brackets", EventSheetGroupFacts.brackets([]).size(), 0) and passed
	return passed


# ── 4. The group's own locals ──


static func _test_group_locals() -> bool:
	var passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	var group: EventGroup = _group("Combat", "")
	group.local_variables.append(_local("combo", "int", 0))
	group.events.append(_event())
	sheet.events.append(group)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var rows: Array[Dictionary] = viewport.get_flat_rows()
	var head_index: int = _index_for(viewport, group)
	passed = _check("the head is on the canvas", head_index >= 0, true)
	if head_index < 0:
		editor.free()
		return false
	var first_child: EventRowData = rows[head_index + 1].get("row")
	passed = _check("the group's local is the first row of its body",
		first_child.variable_row, true) and passed
	passed = _check("it reads as a Local",
		_span_text(first_child, "variable_scope_span", true), "Local") and passed
	passed = _check("named for the variable",
		_span_text(first_child, "variable_name_span", true), "combo") and passed
	passed = _check("and echoes the line the compiler writes",
		_span_text(first_child, "code_echo", true), "var combo: int = 0") and passed
	passed = _check("the row addresses its group",
		first_child.source_resource == group, true) and passed
	editor.free()
	return passed


# ── 5. The dialog ──


static func _test_dialog_fields() -> bool:
	var passed: bool = true
	passed = _check("the dialog asks for six facts, in order",
		", ".join(EventSheetQuickPromptDialogs.GROUP_FIELD_ORDER),
		"Name, Description, Runs on, Active on start, Can be switched at runtime, Colour") and passed
	var group: EventGroup = _group("Combat", "old text")
	group.enabled = true
	group.runtime_toggleable = false
	var resolved: String = EventSheetDock.set_group_fields(group, "  Combat  ", "  Damage, hits and death.  ", {
		"enabled": false,
		"runtime_toggleable": true,
		"custom_color": Color(0.85, 0.64, 0.35, 1.0)
	})
	passed = _check("Apply trims the name", resolved, "Combat") and passed
	passed = _check("and mirrors it onto both name fields", group.group_name, "Combat") and passed
	passed = _check("the description is trimmed too", group.description, "Damage, hits and death.") and passed
	passed = _check("Active on start writes through", group.enabled, false) and passed
	passed = _check("switchable at runtime writes through", group.runtime_toggleable, true) and passed
	passed = _check("and the colour is the bracket's", group.custom_color.a > 0.9, true) and passed
	# A caller that says nothing about a fact leaves it exactly as it was.
	EventSheetDock.set_group_fields(group, "Combat", "Damage, hits and death.")
	passed = _check("a fact the caller left out is untouched", group.enabled, false) and passed
	passed = _check("a blank name falls back",
		EventSheetDock.set_group_fields(group, "   ", ""), "Group") and passed
	# The token the dialog and the two group rows have to agree on.
	passed = _check("the switchable flag is addressed by the compiler's own token",
		EventSheetGroupFacts.guard_value(_group("Tutorial hints", "")), "\"tutorial_hints\"") and passed
	# The swatch has to open on SOME colour, so Apply must not read "opened on lilac" as "asked for
	# lilac" - a group that carries no colour stays uncoloured unless the swatch was actually moved.
	var seeded: Color = Color(0.55, 0.45, 0.85, 1.0)
	passed = _check("an untouched swatch writes no colour at all",
		EventSheetQuickPromptDialogs.group_edit_extras(true, false, seeded, seeded).has("custom_color"),
		false) and passed
	var chosen: Color = Color(0.2, 0.7, 0.4, 1.0)
	passed = _check("and a moved one writes the colour it was moved to",
		EventSheetQuickPromptDialogs.group_edit_extras(true, false, chosen, seeded).get("custom_color"),
		chosen) and passed
	var uncoloured: EventGroup = _group("Quiet", "")
	EventSheetDock.set_group_fields(uncoloured, "Quiet", "a new description",
		EventSheetQuickPromptDialogs.group_edit_extras(true, false, seeded, seeded))
	passed = _check("so editing only the description leaves the bracket uncoloured",
		uncoloured.custom_color.a, 0.0) and passed
	return passed


# ── 6. The pinned head ──


static func _test_pinned_head() -> bool:
	var passed: bool = true
	var one: Dictionary = EventSheetGroupFacts.pinned_trail(PackedStringArray(["Combat"]))
	passed = _check("a top-level group pins with no trail", _trail_line(one), "") and passed
	passed = _check("and names itself", str(one.get("title", "")), "Combat") and passed
	var two: Dictionary = EventSheetGroupFacts.pinned_trail(PackedStringArray(["Gameplay", "Combat"]))
	passed = _check("one parent shows as one crumb", _trail_line(two), "Gameplay") and passed
	var deep: Dictionary = EventSheetGroupFacts.pinned_trail(
		PackedStringArray(["Level", "Gameplay", "Enemies", "Combat"]))
	passed = _check("a deep chain shortens to the last two parents",
		_trail_line(deep), "… ▸ Gameplay ▸ Enemies") and passed
	passed = _check("the whole chain is kept for the hover",
		str(deep.get("full", "")), "Level ▸ Gameplay ▸ Enemies ▸ Combat") and passed
	passed = _check("the innermost name is the title, not a crumb",
		str(deep.get("title", "")), "Combat") and passed

	# The trail is broken back into the names it is made of, so each can be armed as a door.
	# The elision stands for names rather than being one, so it points at nothing.
	var crumbs: Array = deep.get("crumbs", []) as Array
	passed = _check("a deep trail is three crumbs", crumbs.size(), 3) and passed
	passed = _check("led by the elision, which names no group",
		[str((crumbs[0] as Dictionary).get("text", "")), int((crumbs[0] as Dictionary).get("index", 0))],
		["…", -1]) and passed
	passed = _check("then the two parents, each pointing at its own place in the chain",
		[str((crumbs[1] as Dictionary).get("text", "")), int((crumbs[1] as Dictionary).get("index", -1)),
			str((crumbs[2] as Dictionary).get("text", "")), int((crumbs[2] as Dictionary).get("index", -1))],
		["Gameplay", 1, "Enemies", 2]) and passed
	passed = _check("a top-level group has no crumbs at all", (one.get("crumbs", []) as Array).size(), 0) and passed

	# …and where each one lands on the strip: names laid out left to right past the separators, the
	# elision arming nothing, and a click inside a name finding the row that name stands for.
	var zones: Array[Dictionary] = ViewportGroupBreadcrumb.crumb_zones(
		crumbs, PackedInt32Array([2, 5, 9, 12]), 30.0,
		PackedFloat32Array([10.0, 60.0, 50.0]), 8.0)
	passed = _check("only the two names arm a zone", zones.size(), 2) and passed
	passed = _check("the first name starts past the elision and its separator",
		[float(zones[0].get("x", 0.0)), int(zones[0].get("index", -1))], [48.0, 5]) and passed
	passed = _check("and the second past the first",
		[float(zones[1].get("x", 0.0)), int(zones[1].get("index", -1))], [116.0, 9]) and passed
	passed = _check("a click on a name scrolls to that head",
		ViewportGroupBreadcrumb.crumb_at(zones, 60.0), 5) and passed
	passed = _check("a click on the separator between them lands on neither",
		ViewportGroupBreadcrumb.crumb_at(zones, 111.0), -1) and passed
	passed = _check("and a click past the trail lands on nothing",
		ViewportGroupBreadcrumb.crumb_at(zones, 400.0), -1) and passed

	# The parts the pinned copy re-draws come off the head ROW, by metadata.
	var sheet: EventSheetResource = EventSheetResource.new()
	var group: EventGroup = _group("Combat", "Damage, hits and death.")
	group.events.append(_event())
	sheet.events.append(group)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var head: EventRowData = _row_for(editor.get_viewport_control(), group)
	var parts: Dictionary = ViewportGroupBreadcrumb.head_parts(head)
	passed = _check("the pinned copy carries the description",
		str(parts.get("description", "")), "Damage, hits and death.") and passed
	passed = _check("and what the group holds", str(parts.get("counts", "")), "1 event") and passed
	passed = _check("and the same switch glyph",
		str(parts.get("switch", "")), ViewportRowBuilder.HEAD_SWITCH_ON_GLYPH) and passed
	passed = _check("a head with no row says nothing",
		str((ViewportGroupBreadcrumb.head_parts(null) as Dictionary).get("counts", "")), "") and passed
	editor.free()
	return passed


# ── 7. Open all / Close all ──


## The one gesture that folds every group and unfolds them again. What it SAYS has to be what
## it just did: the question "is anything open?" has a different answer after the fold than before,
## so it is asked once, up front.
static func _test_open_all_close_all() -> bool:
	var passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	var group: EventGroup = _group("Combat", "")
	group.events.append(_event())
	sheet.events.append(group)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var dock: EventSheetDock = editor as EventSheetDock
	var view: EventSheetViewport = editor.get_viewport_control()
	passed = _check("the group starts open", view.any_group_open(), true)
	passed = _check("and the dock has a status line to answer on", dock._status_label != null, true) and passed
	if dock._status_label == null:
		editor.free()
		return false
	dock._toggle_all_group_folds()
	passed = _check("the first press closes them", view.any_group_open(), false) and passed
	passed = _check("and says so", dock._status_label.text, "Groups closed.") and passed
	dock._toggle_all_group_folds()
	passed = _check("the second press opens them", view.any_group_open(), true) and passed
	passed = _check("and says that", dock._status_label.text, "Groups opened.") and passed
	editor.free()
	return passed


# ── Fixtures + helpers ──


static func _group(group_name: String, description: String) -> EventGroup:
	var group: EventGroup = EventGroup.new()
	group.name = group_name
	group.group_name = group_name
	group.description = description
	return group


static func _event() -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	return event


static func _local(local_name: String, type_name: String, value: Variant) -> LocalVariable:
	var local: LocalVariable = LocalVariable.new()
	local.name = local_name
	local.type_name = type_name
	local.default_value = value
	return local


## The parent trail as the strip draws it: the crumb names, in order, with the separator between
## them. Read off the crumbs rather than off a second string, because the crumbs are what is drawn.
static func _trail_line(trail: Dictionary) -> String:
	var names: PackedStringArray = PackedStringArray()
	for crumb: Dictionary in (trail.get("crumbs", []) as Array):
		names.append(str(crumb.get("text", "")))
	return EventSheetGroupFacts.CRUMB_SEPARATOR.join(names)


static func _index_for(viewport: EventSheetViewport, resource: Resource) -> int:
	var rows: Array[Dictionary] = viewport.get_flat_rows()
	for index in range(rows.size()):
		var row: EventRowData = rows[index].get("row")
		if row != null and row.source_resource == resource and row.row_type == EventRowData.RowType.GROUP:
			return index
	return -1


static func _row_for(viewport: EventSheetViewport, resource: Resource) -> EventRowData:
	var index: int = _index_for(viewport, resource)
	return viewport.get_flat_rows()[index].get("row") if index >= 0 else null


## The first span whose metadata `key` equals `value`, or null.
static func _span_with(row_data: EventRowData, key: String, value: Variant) -> SemanticSpan:
	if row_data == null:
		return null
	for span: SemanticSpan in row_data.spans:
		if span == null or not (span.metadata is Dictionary):
			continue
		if (span.metadata as Dictionary).get(key) == value:
			return span
	return null


static func _span_text(row_data: EventRowData, key: String, value: Variant) -> String:
	var span: SemanticSpan = _span_with(row_data, key, value)
	return span.text if span != null else "<no span %s=%s>" % [key, str(value)]


static func _span_flag(row_data: EventRowData, key: String, value: Variant, flag: String) -> bool:
	var span: SemanticSpan = _span_with(row_data, key, value)
	return bool((span.metadata as Dictionary).get(flag, false)) if span != null else false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] group_head: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
