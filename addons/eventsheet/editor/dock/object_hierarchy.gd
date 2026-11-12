@tool
class_name EventSheetObjectHierarchy
extends RefCounted

# The lines an Add child row's flags dialog writes: `child.reparent(parent)` for keeping its place,
# `child.reparent(parent, false)` for snapping to it, `top_level` for Ignore parent's movement, and a
# RemoteTransform node when a transform flag is switched off. They are the plain spellings the
# hierarchy readings recognise, so the canvas reads back exactly what the dialog wrote.


## The local a RemoteTransform emission is parked in. Anything under this prefix is plumbing, never
## an object in its own right, so the link scan below skips it.
const FOLLOW_PREFIX := "__follow_"


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
