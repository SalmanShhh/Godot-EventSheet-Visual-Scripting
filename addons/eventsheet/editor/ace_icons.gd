# Godot EventSheets - the icons a verb, a category and a class wear, wherever they are drawn.
#
# The picker draws them in its tree and the sheet draws the SAME ones on its rows: an object's class
# icon on its head, a category's icon on a section, a verb's role dot. Both ask here, so the two can
# never disagree about which picture a thing wears.
#
# WHY A FILE OF ITS OWN: these answers used to live on the picker dialog, and the reading layer asked
# the dialog for them. Naming the dialog class compiles the dialog - and everything the dialog names -
# the moment the row builder loads, which put the whole picker into the first sheet open for the sake
# of a theme lookup. This file names only the vocabulary it reads (the registry's builtin
# descriptors, the two definition shapes, the palette's lane colours), so the rows pay for that and
# nothing more. The dialog keeps its old static entry points and forwards here.
#
# Every answer degrades to null outside a live editor (headless runs have no editor theme), and a
# caller keeps its words or its glyph when it gets null back.
@tool
class_name EventSheetACEIcons
extends RefCounted

## Categories nest one level on this separator: "Variables: Array" renders as an Array
## folder inside the Variables section. Authors get a sub-section just by naming the
## category "Parent: Sub" - no schema change. Node-type sections never sub-nest.
const SUBCATEGORY_SEPARATOR: String = ": "

## Hand-picked icons for categories that DERIVATION cannot reach: abstract groupings whose name is
## not a class and whose verbs have no host node ("Math & Random", "General Actions", "Helpers").
## Everything else resolves automatically - see category_icon_name - so adding a category to the
## vocabulary does NOT mean editing a table here. Values are EditorIcons names; unknown names and
## headless runs degrade to no icon. Entries also OVERRIDE derivation, for the cases where a human
## choice beats the derived one (an "Overlap" section reads better as an Area than a bare Node).
const CATEGORY_EDITOR_ICONS: Dictionary = {
	# The three objects batch ten added. Each names the node its rows act on, which is
	# also the icon a reader already associates with that kind of row in the Scene dock.
	"AJAX": "HTTPRequest",
	"Lighting": "PointLight2D",
	"Video": "VideoStreamPlayer",
	"Animation": "AnimationPlayer",
	"Mesh": "MeshInstance3D",
	# Material is a class with no icon in the editor theme, so its derived name draws nothing. Every
	# word these rows say is a BaseMaterial3D one, whose everyday face is the standard material.
	"Material": "StandardMaterial3D",
	"Gradients & Curves": "Gradient",
	"Audio Server": "AudioBusLayout",
	"Physics Server": "PhysicsMaterial",
	"Behavior": "Node",
	# The four game-shape sections. None of their names is a class and none of
	# their verbs has a host node, which is exactly what this table is still for: a meter is a bar, a
	# stealth row is about being heard, a boss section is the fight itself, a mission is its clock.
	"Meters": "ProgressBar",
	"Stealth": "AudioStreamPlayer",
	"Boss": "GuiRadioUnchecked",
	"Missions": "Timer",
	# The rest of a level of that shape: the doors that gate it, the things in it that
	# come for you, and the things lying around that you pick up.
	"Keys & Doors": "Key",
	"Enemies 3D": "CharacterBody3D",
	"Pickups": "Area3D",
	"Collisions": "CollisionShape2D",
	"Color": "Color",
	# The one entry the five "Compare: …" sub-categories all inherit. Nothing derivable here: the name
	# is not a class and the verbs are host-agnostic, which is exactly what this table is still for.
	"Compare": "GuiChecked",
	"Debug": "NodeWarning",
	"Display": "Window",
	"Drawing": "CanvasItem",
	"Editor Tools": "Tools",
	"Effects": "Shader",
	"Files": "File",
	"Files: Directories": "Folder",
	"Functions": "MemberMethod",
	"Game Options": "Tools",
	"Game Window": "Window",
	"Gamepad": "InputEventJoypadButton",
	"General Actions": "Play",
	"General Conditions": "GuiChecked",
	"General Expressions": "Variant",
	"Groups": "Groups",
	"Helpers": "GDScript",
	# The editor theme draws no InputEvent icon of its own (only its subclasses), so the derived
	# class name would leave the header blank. The keyboard is the editor's own picture of input.
	"Input": "Keyboard",
	# The questions asked of the ONE event a handler was handed. It wears the same picture as the
	# polled Input rows above - the difference between the two sections is which moment they ask
	# about, not what they are about.
	"Input Event": "Keyboard",
	# JSON is a class, but one the editor theme has no icon for. These rows cross the text boundary
	# (a value to JSON text and back), so the editor's own text-file mark is the picture.
	"JSON": "TextFile",
	# The engine talking to a node through its notification callback. Nothing derivable: a
	# notification is a number rather than a class, and the editor's own "something is telling you
	# this" mark is the nearest picture there is.
	"Notifications": "NodeInfo",
	"InputMap": "InputEventAction",
	"Joints": "PinJoint2D",
	"Keyboard": "InputEventKey",
	"Loops": "Loop",
	"Math & Random": "RandomNumberGenerator",
	"Metadata": "Object",
	"Mouse": "InputEventMouseButton",
	"Movement": "Path2D",
	# Nothing derivable: "Multiplayer" is not a class, and the messages a peer sends are the
	# nearest thing the editor draws to what these rows are about.
	# The Browser is not a class, so nothing derives it: the rows there leave the game (a link, the
	# clipboard, the window mode), and the editor's own "this opens somewhere else" mark says that.
	"Browser": "ExternalLink",
	"Multiplayer": "Signals",
	"Nodes": "Node",
	"Overlap 2D": "Area2D",
	"Overlap 3D": "Area3D",
	# Nothing derives "Ownership": it is not a class, and its rows carry no host node because
	# they act on whatever the sheet names. What they are about is a fact written ON a node - the
	# metadata key naming who made it - so the editor's own object mark is the human choice here.
	"Ownership": "Object",
	"Platform": "Godot",
	"Procedural": "FastNoiseLite",
	# Nothing derives "Destroy": it is not a class, and its rows carry no host node because they act
	# on whatever the sheet names rather than on a kind of thing. The editor's own remove mark is
	# what these rows are about, so it is the human choice here.
	"Destroy": "Remove",
	"Rendering": "Environment",
	"Run Context": "PlayScene",
	# The game's own mode is not a class the engine has an icon for, so it borrows the one every
	# state machine in the editor wears: the graph node a state IS.
	"Game State": "GraphNode",
	# And an OBJECT's own state is the same idea one level down, so it wears the same mark: a reader
	# who learned the icon on the game's mode reads it again on an enemy's state without being told.
	"Object State": "GraphNode",
	"Scene": "PackedScene",
	"Signals / Scene / Input": "Signals",
	"Systems": "Groups",
	# The player-facing accessibility options. Godot has no icon for the idea, so the row that
	# every one of them ends up on - a setting the player changes - lends its own.
	"Accessibility": "GuiRadioCheckedDisabled",
	# A Test sheet's claims: the name is not a class and the verbs record onto the test node rather
	# than driving one, so derivation cannot reach it. The tick reads as pass/fail, which is what a
	# claim is.
	"Testing": "GuiChecked",
	"Timed Input": "Timer",
	"Text": "String",
	"Time": "Timer",
	"Touch": "InputEventScreenTouch",
	"Utility": "Tools",
	"Variables": "MemberProperty",
	"Variables: Array": "Array",
	"Variables: Dictionary": "Dictionary",
	"Variables: String": "String",
	"Variables: Vector": "Vector2",
	"Vibration": "InputEventJoypadMotion",
	"Weapons 3D": "RayCast3D",
}


## Fetches a named editor-theme icon ("EditorIcons" - class icons and member glyphs).
## Null outside the editor or when the name is unknown, so callers degrade gracefully.
static func editor_icon(icon_name: String) -> Texture2D:
	return EventSheetEditorIcons.icon(icon_name)


## The editor-theme icon for a builtin category header ("Math & Random" -> the
## RandomNumberGenerator icon). Null outside a live editor or for unmapped categories
## (text-only header, exactly the pre-icon look). `host_hint` is the category's own host class
## when the caller knows it - a pack's definition carries one, and it lets a pack category
## resolve an icon without ever being listed anywhere.
static func category_header_icon(group_key: String, host_hint: String = "") -> Texture2D:
	var icon_name: String = category_icon_name(group_key, host_hint)
	return null if icon_name.is_empty() else editor_icon(icon_name)


## Resolves a category to its EditorIcons name, DERIVING one wherever it can so that adding a
## category to the vocabulary is not also a chore in this file. In order:
##   1. an explicit CATEGORY_EDITOR_ICONS entry (a human choice, and the override),
##   2. the category NAME read as a class, case-insensitively ("Raycast 2D" -> RayCast2D,
##      "Tilemap" -> TileMap) - the name a category already has is usually the icon it wants,
##   3. for a "Parent: Sub" key, the PARENT's explicit entry: a family whose icon someone chose
##      deliberately keeps it across its sub-sections, rather than each sub drifting to its own
##      derived host ("Nodes: Picking" stays on the Nodes icon, not Node2D),
##   4. the host class its verbs actually operate on: the caller's `host_hint`, else the most
##      specific host shared by the builtin ACEs in that category ("UI" -> Control),
##   5. a "Parent: Sub" key inheriting whatever its parent DERIVES,
##   6. "" - a text-only header, exactly the pre-icon look.
## Pure + static so the mapping stays unit-testable without a display server.
static func category_icon_name(group_key: String, host_hint: String = "") -> String:
	var explicit: String = str(CATEGORY_EDITOR_ICONS.get(group_key, ""))
	if not explicit.is_empty():
		return explicit
	var from_name: String = _class_named(group_key)
	if not from_name.is_empty():
		return from_name
	var parts: PackedStringArray = split_subcategory(group_key)
	if not parts.is_empty():
		var parent_explicit: String = str(CATEGORY_EDITOR_ICONS.get(parts[0], ""))
		if not parent_explicit.is_empty():
			return parent_explicit
	var from_hint: String = _class_named(host_hint)
	if not from_hint.is_empty():
		return from_hint
	var derived: String = str(_category_host_classes().get(group_key, ""))
	if not derived.is_empty():
		return derived
	if not parts.is_empty():
		return category_icon_name(parts[0], host_hint)
	return ""


## The engine class a label names, ignoring case and spacing, or "" when it names none. Category
## labels are written for humans ("Raycast 2D", "Tilemap") while classes are PascalCase with their
## own capitalisation quirks (RayCast2D, TileMap), so an exact match would miss almost every one.
static func _class_named(label: String) -> String:
	var key: String = label.replace(" ", "").replace("&", "").replace("-", "").to_lower()
	if key.is_empty():
		return ""
	return str(_class_names_by_lowercase().get(key, ""))


## lowercase class name -> its exact ClassDB spelling. Built once: the class list is ~1000 entries
## and this is consulted for every header drawn.
static var _class_lookup: Dictionary = {}


static func _class_names_by_lowercase() -> Dictionary:
	if not _class_lookup.is_empty():
		return _class_lookup
	for class_id: String in ClassDB.get_class_list():
		_class_lookup[class_id.to_lower()] = class_id
	return _class_lookup


## category -> the most specific host class its builtin verbs share, or "" when they are
## host-agnostic (a "Math & Random" verb runs anywhere, so nothing is derivable and the explicit
## table is the only answer). "Most specific" means the deepest in the inheritance chain that
## still covers every hosted verb, so "Raycast 2D" lands on RayCast2D rather than Node2D even
## though a few of its world-query verbs are plain Node2D.
static var _category_hosts: Dictionary = {}
## Whether the map above has been derived, kept APART from its own emptiness. Every entry is
## FILTERED on having a real ClassDB host, so a host-agnostic vocabulary derives an empty map - and
## an emptiness test would then walk every vocabulary module again for every section header drawn.
static var _category_hosts_derived: bool = false


## The Godot class a vocabulary entry is scoped to, whichever shape the entry is.
##
## The builtin list holds BOTH kinds and always has: an ACEDescriptor keeps the host in `node_type`,
## while an ACEDefinition - the shape a provider script and EventSheets.simple_ace produce - has no
## such property and keeps it in `metadata`. Reading `.node_type` unconditionally therefore threw
## once per definition, which is invisible headless (the definitions only join in a live editor) and
## filled the Output dock the moment anyone opened a sheet.
static func host_class_of(entry: Variant) -> String:
	if entry is ACEDescriptor:
		return str((entry as ACEDescriptor).node_type).strip_edges()
	if entry is ACEDefinition:
		return str(((entry as ACEDefinition).metadata as Dictionary).get("node_type", "")).strip_edges()
	return ""


static func _category_host_classes() -> Dictionary:
	if _category_hosts_derived:
		return _category_hosts
	_category_hosts_derived = true
	var counts: Dictionary = {}
	# The registry's cached builtins, not a fresh module walk: the same descriptors, already built,
	# and already reconciled - a descriptor that spells its host `nodeType` counts here too.
	for entry: Variant in ACERegistry.get_builtin_descriptors():
		var host: String = host_class_of(entry)
		if host.is_empty() or not ClassDB.class_exists(host):
			continue
		var category: String = str(entry.get("category"))
		if not counts.has(category):
			counts[category] = {}
		var per_category: Dictionary = counts[category]
		per_category[host] = int(per_category.get(host, 0)) + 1
	for category: String in counts:
		_category_hosts[category] = _dominant_host(counts[category])
	return _category_hosts


## The host that best represents a category: the one used most, breaking ties toward the more
## derived class (RayCast2D over Node2D) so the icon shows the specific thing the section is
## about rather than the generic base every node shares.
static func _dominant_host(host_counts: Dictionary) -> String:
	var best: String = ""
	var best_count: int = 0
	for host: String in host_counts:
		var count: int = int(host_counts[host])
		if count > best_count or (count == best_count and ClassDB.is_parent_class(best, host)):
			best = host
			best_count = count
	return best


## Splits a "Parent: Sub" category into [parent, child] (both stripped). Returns an empty
## array when there is no sub-category separator, so the category renders as a flat group.
## Pure + static so the grouping can be unit-tested without a display server.
static func split_subcategory(group_key: String) -> PackedStringArray:
	var index: int = group_key.find(SUBCATEGORY_SEPARATOR)
	if index == -1:
		return PackedStringArray()
	var parent_name: String = group_key.substr(0, index).strip_edges()
	var child_name: String = group_key.substr(index + SUBCATEGORY_SEPARATOR.length()).strip_edges()
	if parent_name.is_empty() or child_name.is_empty():
		return PackedStringArray()
	return PackedStringArray([parent_name, child_name])


## Resolves an ACE's icon: an explicit `res://` texture from the addon's @ace_icon annotation,
## else a small dot in the ACE type's role colour. The dot replaced two older fallbacks - the
## row's node-type class icon (redundant: the section header already shows it) and Godot's
## member glyphs (MemberSignal/MemberMethod/…, insider vocabulary a newcomer can't read).
## Colour is the sheet's own visual language: the dot reuses the exact lane colours the rows
## paint with, so "teal = a yes/no test" transfers from the picker to the sheet and back.
## Static + shared so row rendering can reuse it later.
static func resolve_definition_icon(definition: ACEDefinition) -> Texture2D:
	if definition == null:
		return null
	var cached: Texture2D = path_icon(definition.icon)
	return cached if cached != null else kind_dot(definition.ace_type)


## A `res://` picture by path, or null for anything else or a path that resolves to nothing.
## Cached per PATH, misses included. `load()` hits Godot's own resource cache after the first read,
## but `ResourceLoader.exists()` does not - it is a filesystem question every time, and this is asked
## once per row of a tree the search box rebuilds on every keystroke, and once per pack tile.
static func path_icon(path: String) -> Texture2D:
	var icon_hint: String = path.strip_edges()
	if not icon_hint.begins_with("res://"):
		return null
	if not _path_icon_cache.has(icon_hint):
		var found: Texture2D = null
		if ResourceLoader.exists(icon_hint):
			var loaded: Resource = load(icon_hint)
			if loaded is Texture2D:
				found = loaded as Texture2D
		_path_icon_cache[icon_hint] = found
	return _path_icon_cache[icon_hint] as Texture2D


## res:// icon path -> its texture, or null where the path resolves to nothing. Dropped with the
## other filesystem-derived reads when the editor reports a scan, so a pack dropped into the
## project (or an icon replaced in place) is picked up without a restart.
static var _path_icon_cache: Dictionary = {}


## Drops the resolved icons. The editor's filesystem ping calls this; nothing else needs to.
static func clear_icon_cache() -> void:
	_path_icon_cache.clear()


static var _kind_dot_cache: Dictionary = {}


## A small filled dot in the given ACE type's role colour (trigger purple, condition teal, action
## amber, expression magenta - EventSheetPalette's lane colours). Image-built and cached per type,
## so it renders identically in the editor and headless.
static func kind_dot(ace_type: int) -> Texture2D:
	if _kind_dot_cache.has(ace_type):
		return _kind_dot_cache[ace_type]
	var color: Color = EventSheetPalette.COLOR_ACTION
	match ace_type:
		ACEDefinition.ACEType.TRIGGER:
			color = EventSheetPalette.COLOR_TRIGGER
		ACEDefinition.ACEType.CONDITION:
			color = EventSheetPalette.COLOR_CONDITION
		ACEDefinition.ACEType.EXPRESSION:
			color = EventSheetPalette.COLOR_EXPRESSION
	var dot_size: int = 12
	var image: Image = Image.create(dot_size, dot_size, false, Image.FORMAT_RGBA8)
	var center: float = (dot_size - 1) * 0.5
	var radius: float = 4.5
	for y in range(dot_size):
		for x in range(dot_size):
			# 1px soft edge so the dot reads round at UI scale, not as a jagged square of pixels.
			var alpha: float = clampf(radius + 0.5 - Vector2(x - center, y - center).length(), 0.0, 1.0)
			if alpha > 0.0:
				image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_kind_dot_cache[ace_type] = texture
	return texture
