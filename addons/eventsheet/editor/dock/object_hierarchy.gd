@tool
class_name EventSheetObjectHierarchy
extends RefCounted

# X15 - the HIERARCHY section of the Object properties popup: an object's parent, its children, and
# the follow-flags each child carries, in one pane you can drag into.
#
# Godot already draws a tree - the Scene dock - but that tree knows nothing about the sheet's rows,
# and the sheet's rows are where a running game's hierarchy actually changes. So this pane reads BOTH
# and says which is which:
#
#   the .tscn      - children the scene file owns. Shown muted, with "in the scene file". The pane
#                    NEVER edits a scene; that stays Godot's job, and the muted hint says so.
#   the sheet rows - the parenting the game does while it runs. This is the half the pane writes.
#
# What it writes is plain GDScript, in exactly the spellings the hierarchy readings recognise:
# `child.reparent(parent)` for Add child keeping its place, `child.reparent(parent, false)` for
# snapping to it, `child.reparent(get_tree().current_scene)` for Remove from parent, `top_level` for
# Ignore parent's movement, and a RemoteTransform node when a transform flag is switched off. That
# way the pane and the canvas can never disagree: the canvas reads back the very lines the pane
# wrote, and a hand-typed line reads back as a pane row without anything being converted.
#
# Everything above the live section is a pure function of a sheet + a census entry, so a headless
# test pins the exact words a pane shows without a display server.


## The note a parent carries when it IS the scene root - the sheet's word for the whole scene.
const LAYOUT_NOTE := "(the layout)"

## The mark a child wears when it stays in the hierarchy but stops following its parent's transform.
const IGNORE_MARK := "⛓"

## Ticks for the transform flags. A flag that is ON is what Godot does by default.
const FLAG_ON := "✓"
const FLAG_OFF := "✗"

## The local a RemoteTransform emission is parked in. Anything under this prefix is plumbing, never
## an object in its own right, so the link scan below skips it.
const FOLLOW_PREFIX := "__follow_"


## Every hierarchy fact one object answers with:
##   "parent"   - {} when nothing parents it, else {"label", "note", "scene_owned"}
##   "children" - in reading order: the scene's own first, then whatever the rows parent onto it.
##                Each {"label", "type", "child_count", "scene_owned", "ignores_movement",
##                "transforms": {} or {"position", "angle", "size"}}
static func facts_for(sheet: EventSheetResource, entry: Dictionary,
		source_path: String = "") -> Dictionary:
	var facts: Dictionary = {"parent": {}, "children": []}
	if entry.is_empty() or not is_node_object(entry):
		return facts
	var label: String = str(entry.get("label", "")).strip_edges()
	if label.is_empty():
		return facts
	var scene: Dictionary = EventSheetObjectFacts.scene_facts(scene_path_for(sheet, source_path))
	_append_scene_side(facts, scene, label, str(entry.get("kind", "")))
	_append_row_side(facts, sheet, label, str(scene.get("root", "")))
	return facts


## Only a node has a place in a tree. A group is a name, an autoload has no parent worth showing, a
## scene file is not in this tree at all - so the section is simply not built for them.
static func is_node_object(entry: Dictionary) -> bool:
	return str(entry.get("kind", "")) in ["script", "node", "behaviour"]


## The scene whose tree this pane is reading, or "" when no scene in the project uses the sheet's
## script. Same scan the head bar and the object popup use, so all three name one scene.
static func scene_path_for(sheet: EventSheetResource, source_path: String) -> String:
	var path: String = source_path.strip_edges()
	if path.is_empty() and sheet != null:
		path = str(sheet.get("external_source_path")).strip_edges()
	if path.is_empty():
		return ""
	return str(ViewportRowBuilder.scene_using_script(path).get("scene_path", ""))


## The half of the pane the .tscn owns. Muted, and never written to: the pane's whole contract is
## that it adds runtime rows and leaves the scene file alone.
static func _append_scene_side(facts: Dictionary, scene: Dictionary, label: String, kind: String) -> void:
	if scene.is_empty():
		return
	var root: String = str(scene.get("root", ""))
	var nodes: Array = scene.get("children", [])
	var is_root: bool = kind == "script" or label == root
	if not is_root:
		var owner_path: String = _scene_parent_path_of(nodes, label)
		if not owner_path.is_empty():
			facts["parent"] = {
				"label": root if owner_path == "." else owner_path.get_file(),
				"note": LAYOUT_NOTE if owner_path == "." else "",
				"scene_owned": true
			}
	for item: Variant in nodes:
		var node: Dictionary = item
		var owner_name: String = _owner_name_of(str(node.get("parent", "")), root)
		if owner_name != (root if is_root else label):
			continue
		facts["children"].append({
			"label": str(node.get("name", "")),
			"type": str(node.get("type", "")),
			"child_count": _scene_child_count(nodes, str(node.get("name", ""))),
			"scene_owned": true,
			"ignores_movement": false,
			"transforms": {}
		})


## The layout root as a parent line. It is named when the editor knows which scene this is - "Level
## (the layout)" - and says only "the layout" when it does not, because a note that repeats its own
## label twice is worse than no note.
static func _layout_parent(layout_root: String, links: Dictionary) -> Dictionary:
	if layout_root.strip_edges().is_empty():
		return {"label": str(links.get("layout_word", "")), "note": "", "scene_owned": false}
	return {"label": layout_root, "note": LAYOUT_NOTE, "scene_owned": false}


## The `parent="..."` path a named scene node is written under, "" when the scene has no such node.
static func _scene_parent_path_of(nodes: Array, label: String) -> String:
	for item: Variant in nodes:
		var node: Dictionary = item
		if str(node.get("name", "")) == label:
			return str(node.get("parent", ""))
	return ""


## A `parent="Hand/Fingers"` attribute names the node the child hangs under; "." is the scene root.
static func _owner_name_of(parent_path: String, root: String) -> String:
	if parent_path == "." or parent_path.is_empty():
		return root
	return parent_path.get_file()


static func _scene_child_count(nodes: Array, label: String) -> int:
	var count: int = 0
	for item: Variant in nodes:
		var node: Dictionary = item
		if str(node.get("parent", "")).get_file() == label:
			count += 1
	return count


## The half the ROWS own: whatever the sheet parents at run time, with the flags each child carries.
## A child the rows move onto this object joins the list; a child the rows move OFF it (Remove from
## parent, or Add child onto somebody else) leaves it, because the last row to speak is the one the
## game obeys.
static func _append_row_side(facts: Dictionary, sheet: EventSheetResource, label: String,
		layout_root: String) -> void:
	var links: Dictionary = row_links(sheet)
	var key: String = reference_key(label)
	var parented: Dictionary = links.get("parent_of", {})
	if parented.has(key):
		# A row that moves a scene-owned node REPLACES the scene's answer rather than showing two
		# parents: at run time the last row to speak is the one the game obeys.
		var owner_key: String = str(parented[key])
		facts["parent"] = _layout_parent(layout_root, links) if owner_key.is_empty() \
			else {"label": owner_key, "note": "", "scene_owned": false}
	# A runtime child's TYPE is whatever the file already says it is - the same class map the object
	# column reads - so a child parented by a row names its class exactly like a scene-owned one.
	var classes: Dictionary = EventSheetViewportReadingRows.object_class_map(sheet)
	for child_key: String in links.get("order", PackedStringArray()):
		if str(parented.get(child_key, "")) != key:
			continue
		# A detached child WITH a follower driving it is the transform-flags shape, not the escape
		# hatch: it does follow, just not with everything. Only a bare `top_level` reads as the
		# broken link, which is why the two are never shown at once.
		var transforms: Dictionary = (links.get("transforms", {}) as Dictionary).get(child_key, {})
		facts["children"].append({
			"label": child_key,
			"type": str(classes.get(child_key, "")),
			"child_count": 0,
			"scene_owned": false,
			"ignores_movement": transforms.is_empty() \
				and bool((links.get("ignores", {}) as Dictionary).get(child_key, false)),
			"transforms": transforms
		})


## Every hierarchy line the sheet's rows hold, read straight out of the ONE text the object census
## reads - so a lifted Add child row and a hand-typed `reparent` are seen by the same scan and can
## never report two different trees.
##
## Returns {"parent_of": {child -> parent ("" = the layout)}, "order": PackedStringArray of children
## in file order, "ignores": {child -> bool}, "transforms": {child -> {position, angle, size}},
## "layout_word": String}.
static func row_links(sheet: EventSheetResource) -> Dictionary:
	var links: Dictionary = {
		"parent_of": {}, "order": PackedStringArray(), "ignores": {},
		"transforms": {}, "layout_word": EventSheetL10n.translate("the layout")
	}
	if sheet == null:
		return links
	var follow_targets: Dictionary = {}
	for raw_line: String in EventSheetViewportReadingRows.sheet_code_text(sheet).split("\n"):
		var line: String = raw_line.strip_edges()
		_read_reparent(line, links)
		_read_add_child(line, links)
		_read_remove_child(line, links)
		_read_top_level(line, links)
		_read_remote_transform(line, links, follow_targets)
	return links


## `x.reparent(p)` / `x.reparent(p, false)` - the hierarchy's own verb. Reparenting to the current
## scene is the layout root, which is what Remove from parent writes.
static func _read_reparent(line: String, links: Dictionary) -> void:
	var at: int = line.find(".reparent(")
	if at < 0:
		return
	var child: String = reference_key(line.substr(0, at))
	if child.is_empty():
		return
	var inside: String = _inside_call(line, at + ".reparent(".length())
	var owner_text: String = inside.get_slice(",", 0).strip_edges()
	_note_link(links, child, "" if _is_layout_root(owner_text) else reference_key(owner_text))


## `p.add_child(x)` - the older spelling, and the one the two-line remove+add shape ends with.
static func _read_add_child(line: String, links: Dictionary) -> void:
	var at: int = line.find(".add_child(")
	if at < 0:
		return
	var owner_key: String = reference_key(line.substr(0, at))
	var child: String = reference_key(_inside_call(line, at + ".add_child(".length()).get_slice(",", 0))
	if child.is_empty() or child.begins_with("__"):
		return
	_note_link(links, child, owner_key)


## A bare `remove_child` with no re-add takes the child out of the layout entirely. The pane shows
## that as "no parent" rather than pretending the old one still holds.
static func _read_remove_child(line: String, links: Dictionary) -> void:
	var at: int = line.find(".remove_child(")
	if at < 0:
		return
	var child: String = reference_key(_inside_call(line, at + ".remove_child(".length()).get_slice(",", 0))
	if child.is_empty() or child.begins_with("__"):
		return
	(links["parent_of"] as Dictionary)[child] = ""


## X13's first escape hatch: still a child, no longer following.
static func _read_top_level(line: String, links: Dictionary) -> void:
	var at: int = line.find(".top_level = ")
	if at < 0:
		return
	var child: String = reference_key(line.substr(0, at))
	if child.is_empty():
		return
	(links["ignores"] as Dictionary)[child] = line.ends_with("true")


## X11's partial-follow shape: a RemoteTransform node driving the child with one update flag off.
## The `remote_path` line names WHICH child the follower belongs to; the `update_*` lines that follow
## are its flags, so the two are read in order and joined by the follower's own local name.
static func _read_remote_transform(line: String, links: Dictionary, follow_targets: Dictionary) -> void:
	var path_at: int = line.find(".remote_path = ")
	if path_at >= 0:
		var follower: String = line.substr(0, path_at).strip_edges().trim_prefix("var ").strip_edges()
		var target_at: int = line.find(".get_path_to(")
		if target_at >= 0:
			follow_targets[follower] = reference_key(
				_inside_call(line, target_at + ".get_path_to(".length()).get_slice(",", 0))
		return
	for flag_name: String in ["update_position", "update_rotation", "update_scale"]:
		var flag_at: int = line.find(".%s = " % flag_name)
		if flag_at < 0:
			continue
		var owner_local: String = line.substr(0, flag_at).strip_edges()
		if not follow_targets.has(owner_local):
			continue
		var child: String = str(follow_targets[owner_local])
		var transforms: Dictionary = links["transforms"]
		if not transforms.has(child):
			transforms[child] = {"position": true, "angle": true, "size": true}
		(transforms[child] as Dictionary)[_transform_word(flag_name)] = line.ends_with("true")


static func _transform_word(flag_name: String) -> String:
	match flag_name:
		"update_position":
			return "position"
		"update_rotation":
			return "angle"
	return "size"


static func _note_link(links: Dictionary, child: String, owner_key: String) -> void:
	(links["parent_of"] as Dictionary)[child] = owner_key
	var order: PackedStringArray = links["order"]
	if not Array(order).has(child):
		order.append(child)
		links["order"] = order


## True for the two ways a sheet names the layout root it reparents back to.
static func _is_layout_root(text: String) -> bool:
	var clean: String = text.strip_edges()
	return clean == "get_tree().current_scene" or clean == "get_tree().root"


## The text between a call's brackets, balanced, so a nested call in the first argument does not
## truncate it.
static func _inside_call(line: String, from: int) -> String:
	var depth: int = 1
	var index: int = from
	while index < line.length():
		var character: String = line[index]
		if character == "(":
			depth += 1
		elif character == ")":
			depth -= 1
			if depth == 0:
				return line.substr(from, index - from)
		index += 1
	return line.substr(from)


## The one name two spellings of the same object share: `$Camera Pivot`, `%Hat`, `$Hand/Glove` and a
## plain local `hat` all key on their last segment, which is the name the pane and the scene use.
static func reference_key(text: String) -> String:
	var clean: String = text.strip_edges().trim_prefix("$").trim_prefix("%").strip_edges()
	if clean.contains("/"):
		clean = clean.get_file()
	if clean.begins_with("\"") or clean.begins_with("'"):
		clean = clean.substr(1, clean.length() - 2)
	if clean.contains(" ") or clean.contains("(") or clean.contains("."):
		return ""
	return clean


## How the pane writes an object into a line of code: its node path when it has one, its own name
## when it is a local or a parameter, `self` for the object the sheet itself is.
static func reference_for(entry: Dictionary) -> String:
	var path: String = str(entry.get("path", "")).strip_edges()
	if path.begins_with("$") or path.begins_with("%"):
		return path
	if str(entry.get("kind", "")) == "script":
		return "self"
	return str(entry.get("label", "")).strip_edges()


# ── What the pane says ─────────────────────────────────────────────────────────────────────────


## The parent line, as the pane reads it: "Level (the layout)", or "" when nothing parents this one.
static func parent_text(facts: Dictionary) -> String:
	var parent: Dictionary = facts.get("parent", {})
	if parent.is_empty():
		return ""
	var note: String = str(parent.get("note", ""))
	var label: String = str(parent.get("label", ""))
	if note.is_empty():
		return label
	return "%s %s" % [label, EventSheetL10n.translate(note)]


## "▾ children (4)" - the header over the list, counting both halves.
static func children_header(facts: Dictionary) -> String:
	return "▾ %s (%d)" % [EventSheetL10n.translate("children"), (facts.get("children", []) as Array).size()]


## One child, exactly as the pane shows it - the name, then whichever of the four notes it earns:
##   Camera Pivot ▸ Camera3D            its type
##   Hand · 1 child                     it has children of its own
##   HealthBar ⛓ ignores parent's movement
##   Hat transforms: position ✓ angle ✓ size ✗
## A plain child earns none of them, which is the point: nothing configured, nothing shown.
static func child_text(child: Dictionary) -> String:
	var text: String = str(child.get("label", ""))
	var type_name: String = str(child.get("type", "")).strip_edges()
	if not type_name.is_empty():
		text += " ▸ %s" % type_name
	var count: int = int(child.get("child_count", 0))
	if count > 0:
		text += " · " + (EventSheetL10n.translate("1 child") if count == 1
			else EventSheetL10n.translate("%d children") % count)
	if bool(child.get("ignores_movement", false)):
		text += " %s %s" % [IGNORE_MARK, EventSheetL10n.translate("ignores parent's movement")]
	var transforms: Dictionary = child.get("transforms", {})
	if not transforms.is_empty():
		text += " %s %s %s %s %s %s %s" % [
			EventSheetL10n.translate("transforms:"),
			EventSheetL10n.translate("position"), _tick(transforms, "position"),
			EventSheetL10n.translate("angle"), _tick(transforms, "angle"),
			EventSheetL10n.translate("size"), _tick(transforms, "size")]
	return text


static func _tick(transforms: Dictionary, key: String) -> String:
	return FLAG_ON if bool(transforms.get(key, true)) else FLAG_OFF


## The muted trailing note on a child the .tscn owns. The pane writes runtime rows only, so this is
## the honest answer to "why can I not drag this one out".
static func scene_note() -> String:
	return EventSheetL10n.translate("in the scene file")


## The gesture line under the list - the whole feature in one sentence.
static func hint_text() -> String:
	return EventSheetL10n.translate("drag an object here = Add child · drag a child out to unparent · right-click: flags…, Remove from parent, Select in scene")


# ── What the pane writes ───────────────────────────────────────────────────────────────────────


## The flags an Add child starts with: a plain Godot child, keeping the place it already stands in.
static func default_flags() -> Dictionary:
	return {"position": true, "angle": true, "size": true, "destroy": true, "keep_place": true}


## The lines Add child writes, in emission order. Only what DIFFERS from a plain child is written,
## so the ordinary case stays the one clean `reparent` line the readings show:
##
##   keeping its place        child.reparent(parent)
##   snapping to it           child.reparent(parent, false)
##   all transforms off       child.top_level = true            (Ignore parent's movement)
##   some transforms off      child.top_level = true, PLUS a RemoteTransform on the parent putting
##                            back exactly the parts that stayed ticked
##   destroy with parent off  the parent hands the child back to the layout as it leaves the tree
##
## The `top_level` line under a PARTIAL choice is not optional and was proved by running it: an
## ordinary child inherits its parent's whole transform, so a RemoteTransform saying "do not copy
## the size" changes nothing at all while the child is still following on its own. Detaching it and
## then driving back the ticked parts is the only arrangement that delivers what the ticks promise.
static func add_child_lines(parent_reference: String, child_reference: String, flags: Dictionary,
		dimension: String = "3D") -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if parent_reference.strip_edges().is_empty() or child_reference.strip_edges().is_empty():
		return lines
	lines.append("%s.reparent(%s)" % [child_reference, parent_reference] if bool(flags.get("keep_place", true))
		else "%s.reparent(%s, false)" % [child_reference, parent_reference])
	var position_on: bool = bool(flags.get("position", true))
	var angle_on: bool = bool(flags.get("angle", true))
	var size_on: bool = bool(flags.get("size", true))
	if not (position_on and angle_on and size_on):
		lines.append("%s.top_level = true" % child_reference)
	if not (position_on and angle_on and size_on) and (position_on or angle_on or size_on):
		var follower: String = "%s%s" % [FOLLOW_PREFIX, reference_key(child_reference).to_snake_case()]
		lines.append("var %s := RemoteTransform%s.new()" % [follower, dimension])
		lines.append("%s.add_child(%s)" % [parent_reference, follower])
		lines.append("%s.remote_path = %s.get_path_to(%s)" % [follower, follower, child_reference])
		if not position_on:
			lines.append("%s.update_position = false" % follower)
		if not angle_on:
			lines.append("%s.update_rotation = false" % follower)
		if not size_on:
			lines.append("%s.update_scale = false" % follower)
	if not bool(flags.get("destroy", true)):
		lines.append("%s.tree_exiting.connect(func() -> void: %s.reparent(get_tree().current_scene))"
			% [parent_reference, child_reference])
	return lines


## The one line Remove from parent writes - the child keeps the place it stands in, and the layout
## takes it back. Exactly the spelling the reading reads as "Remove from parent".
static func remove_from_parent_line(child_reference: String) -> String:
	if child_reference.strip_edges().is_empty():
		return ""
	return "%s.reparent(get_tree().current_scene)" % child_reference


## 2D or 3D, decided by the classes actually in play rather than guessed: a RemoteTransform2D under a
## Node3D would silently never move anything.
static func dimension_for(sheet: EventSheetResource, parent_entry: Dictionary, child_entry: Dictionary) -> String:
	for candidate: String in [str(child_entry.get("class", "")), str(parent_entry.get("class", "")),
			str(sheet.host_class) if sheet != null else ""]:
		if candidate.ends_with("3D"):
			return "3D"
		if candidate.ends_with("2D"):
			return "2D"
	return "2D"


# ── The pane itself ────────────────────────────────────────────────────────────────────────────

## What a child chip hands a drag. The canvas answers it as Remove from parent, which is the "drag a
## child out to unparent" half of the gesture line.
const CHILD_DRAG_TYPE := "eventsheet_hierarchy_child"

## Right-click item ids. Explicit, because a menu that renumbers when an item is hidden dispatches
## the wrong command - and a scene-owned child hides two of these.
const MENU_FLAGS := 0
const MENU_UNPARENT := 1
const MENU_SELECT_IN_SCENE := 2


## The HIERARCHY section of the Object properties popup, or null for an object with no place in a
## tree. Display-free, so a headless test builds and reads it without a display server.
##
## `handlers` carries what the live editor does with each gesture, each optional:
##   "jump"       (String label)  - the parent line is a click: go to that object's popup
##   "add_child"  (String label)  - something was dropped in: open the flags dialog, then write
##   "flags"      (String label)  - right-click ▸ flags… on an existing child
##   "unparent"   (String label)  - right-click ▸ Remove from parent, or a chip dragged out
##   "select"     (String label)  - right-click ▸ Select in scene
##   "edit_scene" (String label)  - the muted offer beside a child the .tscn owns
static func build_section(facts: Dictionary, handlers: Dictionary = {}) -> Control:
	if facts.get("parent", {}).is_empty() and (facts.get("children", []) as Array).is_empty():
		return null
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	var parent_line: String = parent_text(facts)
	if not parent_line.is_empty():
		box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("parent"),
			_parent_field(facts, parent_line, handlers)))
	var header: Label = Label.new()
	header.text = children_header(facts)
	box.add_child(header)
	var zone: HierarchyDropZone = HierarchyDropZone.new()
	zone.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(2.0)))
	zone.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(320.0), EventSheetPalette.scaled_f(24.0))
	zone.on_object_dropped = handlers.get("add_child", Callable())
	box.add_child(zone)
	for item: Variant in facts.get("children", []):
		zone.add_child(_child_row(item as Dictionary, handlers))
	box.add_child(EventSheetPopupUI.hint_label(hint_text(), EventSheetPalette.scaled_f(320.0)))
	return EventSheetPopupUI.panel_section(box)


## The parent line. A click jumps to that object, because "who holds this" is the question a reader
## asks right before wanting to look at the holder.
static func _parent_field(facts: Dictionary, parent_line: String, handlers: Dictionary) -> Control:
	var jump: Callable = handlers.get("jump", Callable())
	if not jump.is_valid():
		var label: Label = Label.new()
		label.text = parent_line
		return label
	var button: Button = Button.new()
	button.text = parent_line
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var parent_label: String = str((facts.get("parent", {}) as Dictionary).get("label", ""))
	button.pressed.connect(func() -> void: jump.call(parent_label))
	return button


## One child: the chip that says what it is and what it carries, plus - for a child the .tscn owns -
## the muted note and the offer to go and edit the scene, which is the only place that child changes.
static func _child_row(child: Dictionary, handlers: Dictionary) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
	var chip: HierarchyChildChip = HierarchyChildChip.new()
	chip.text = child_text(child)
	chip.flat = true
	chip.alignment = HORIZONTAL_ALIGNMENT_LEFT
	chip.child_label = str(child.get("label", ""))
	chip.scene_owned = bool(child.get("scene_owned", false))
	chip.handlers = handlers
	row.add_child(chip)
	if not bool(child.get("scene_owned", false)):
		return row
	chip.modulate = Color(1.0, 1.0, 1.0, 0.62)
	var note: Label = Label.new()
	note.text = scene_note()
	note.add_theme_color_override("font_color", EventSheetActiveTheme.reading().muted_text_color)
	row.add_child(note)
	var edit_scene: Callable = handlers.get("edit_scene", Callable())
	if edit_scene.is_valid():
		var offer: Button = Button.new()
		offer.text = EventSheetL10n.translate("edit the scene")
		offer.flat = true
		var child_label: String = str(child.get("label", ""))
		offer.pressed.connect(func() -> void: edit_scene.call(child_label))
		row.add_child(offer)
	return row


## The list an object can be dropped INTO. It accepts exactly what the Object bar drags, so the
## gesture is the one a reader already learned from dropping an object on the canvas.
class HierarchyDropZone:
	extends VBoxContainer
	var on_object_dropped: Callable = Callable()

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return on_object_dropped.is_valid() and data is Dictionary \
			and str((data as Dictionary).get("type", "")) == EventSheetObjectsPanel.DRAG_TYPE

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if not on_object_dropped.is_valid():
			return
		on_object_dropped.call(str((data as Dictionary).get("label", "")))


## One child's chip: draggable OUT (which unparents it), right-clickable for the three commands.
## A child the scene file owns still drags nowhere and still offers no flags, because this pane
## refuses to edit a .tscn - it says "in the scene file" instead of failing halfway through.
class HierarchyChildChip:
	extends Button
	var child_label: String = ""
	var scene_owned: bool = false
	var handlers: Dictionary = {}
	var _menu: PopupMenu = null

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if scene_owned or not (handlers.get("unparent", Callable()) as Callable).is_valid():
			return null
		var preview: Label = Label.new()
		preview.text = child_label
		set_drag_preview(preview)
		return {"type": EventSheetObjectHierarchy.CHILD_DRAG_TYPE, "label": child_label}

	func _gui_input(event: InputEvent) -> void:
		var button_event: InputEventMouseButton = event as InputEventMouseButton
		if button_event == null or not button_event.pressed \
				or button_event.button_index != MOUSE_BUTTON_RIGHT:
			return
		open_menu(button_event.global_position)
		accept_event()

	## Built once, then re-graded per opening: a scene-owned child can be FOUND in the scene, but
	## nothing here may rewrite a .tscn, so the two writing commands grey out rather than pretending.
	func open_menu(at_position: Vector2) -> void:
		if _menu == null:
			_menu = PopupMenu.new()
			_menu.add_item(EventSheetL10n.translate("flags…"), EventSheetObjectHierarchy.MENU_FLAGS)
			_menu.add_item(EventSheetL10n.translate("Remove from parent"),
				EventSheetObjectHierarchy.MENU_UNPARENT)
			_menu.add_item(EventSheetL10n.translate("Select in scene"),
				EventSheetObjectHierarchy.MENU_SELECT_IN_SCENE)
			_menu.id_pressed.connect(on_menu_id)
			add_child(_menu)
		_menu.set_item_disabled(_menu.get_item_index(EventSheetObjectHierarchy.MENU_FLAGS), scene_owned)
		_menu.set_item_disabled(_menu.get_item_index(EventSheetObjectHierarchy.MENU_UNPARENT), scene_owned)
		_menu.reset_size()
		_menu.popup(Rect2i(Vector2i(at_position), Vector2i.ZERO))

	## The command dispatch, public so a headless test drives a menu choice without a display server.
	func on_menu_id(id: int) -> void:
		var handler: Callable = handlers.get(handler_key(id), Callable())
		if handler.is_valid():
			handler.call(child_label)

	func handler_key(id: int) -> String:
		match id:
			EventSheetObjectHierarchy.MENU_FLAGS:
				return "flags"
			EventSheetObjectHierarchy.MENU_UNPARENT:
				return "unparent"
		return "select"
