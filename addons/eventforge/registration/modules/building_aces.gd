# EventForge module - Building (making nodes while the game runs, and keeping what was made)
#
# Godot builds a game out of nodes, and a running game can make more of them: `Node2D.new()` makes
# one, `add_child` puts it in the tree, `queue_free` takes it out. These rows are those calls said as
# sentences, for the things a game makes by hand most often - a node of any type, a behaviour, a
# sprite, a collision shape, a timer - plus the two that keep a result: a group that survives being
# packed, and a branch kept as a PackedScene in a variable.
#
# NOTHING HERE IS A SYSTEM. Every row is a few plain lines of GDScript a Godot user would have typed,
# and the emitted code needs nothing from the plugin to run. What the rows add is the words, the
# right order of the lines, and the two traps that are easy to fall into by hand:
#
#   - A script node made with `X.new()` is named after its NATIVE class ("Node"), not after the
#     class_name of its script, so `get_node("JetpackBehavior")` finds nothing. Add Behaviour names
#     the node itself, which is what the editor's own Add Child Node does.
#   - A node added while the game runs has NO OWNER, and `PackedScene.pack` writes out only what the
#     root owns. Keep As Prefab lends the owner for the pack and gives it back, so it is repeatable.
#
# THE NAME IS A REAL VARIABLE where the row makes one thing the next row will want (Add New Node,
# Add Behaviour), the way the spawn rows name their copy. The sprite, shape and timer rows make
# parts, and a part is usually the end of the sentence, so they use a throwaway local that is baked
# per row and cannot collide with a second part in the same event.
#
# WHERE THE NODE GOES. The new node goes under the running scene by default (`get_tree().current_scene`)
# and the row says so. Every other place is the field's to change.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant); this file
# only changes where the descriptors are AUTHORED.
@tool
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The owner walk Save Branch As Scene File writes. It lives in the Files module, which owns the
## reasoning, so the two rows cannot say different things.
const FILE_ACES := preload("res://addons/eventforge/registration/modules/file_aces.gd")

## The one category these rows group under in the picker.
const CATEGORY: String = "Building"

## The hint the "which node type" fields carry. The dialog opens Godot's own Create New Node window
## behind it, so the list is the one the editor shows everywhere else, project classes included.
const NODE_TYPE_HINT: String = "node_type"

## The metadata key a tool sheet puts on every node it builds, holding the path of the script that built
## it, so a later run can find and remove what an earlier one made - and only that script's own. One
## constant, because three places read it.
const BUILT_META: String = "built_by_sheet"

## A line break and an indent, named so the template text below reads as lines.
const NL: String = "\n"
const TAB: String = "\t"

## The lines a TOOL sheet adds after a node it builds: the node is owned by the scene being edited, so it
## is saved with the scene, and it is marked, so Remove What This Sheet Built can find it again. In a game
## sheet the segment is dropped and a row writes only what it always did. When a row is dropped into a
## tool sheet the dock keeps the segment (see tool_form), so the lines are the row's own text from then on.
const TOOL_OWNER_HEAD: String = "{?tool=yes}" + NL + "if Engine.is_editor_hint():" + NL + TAB

## A tool also asks add_child for a readable name: a second node of the same name that Godot has to rename
## is called `Fence2` in a tool (the scene is saved with it) and `@Node2D@19811` otherwise. That is the
## `, true` inside each add_child, kept by the same segment.

## The parent a node is added under in the game, and in a tool: a tool runs outside the running scene,
## so the scene being edited is the one to build in.
const GAME_PARENT: String = "get_tree().current_scene"
const TOOL_PARENT: String = "get_tree().edited_scene_root"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	_add_nodes(descriptors)
	_add_parts(descriptors)
	_add_keeping(descriptors)
	_add_tools(descriptors)
	return descriptors


# ── A node of any type, and a behaviour ──
static func _add_nodes(descriptors: Array[ACEDescriptor]) -> void:
	# The name line is optional: a blank name leaves the node with the name Godot gives it.
	descriptors.append(F.act("AddNewNodeInto", "Add New Node",
		"var {name} := {type}.new()\n{?label}{name}.name = {label}\n{/label}{parent}.add_child({name}{?tool=yes}, true{/tool})" + tool_owner("{name}"),
		CATEGORY, "Add a new [b]{type}[/b] named [b]{label}[/b] under [i]{parent}[/i], into [b]{name}[/b]",
		"Makes a node of any type, adds it under a parent and keeps it in a variable, so the next rows in this event can set it up. Leave Under as the running scene to add it to the level, or name any node. A script class with its own _init arguments is not made by this row.",
		"Node").param_built(_type_param("type", "Node2D", "Type", "What to make: any node type Godot knows, or a script class of your own that has a class_name.")).param_built(F.make_param("label", "String", "\"NewNode\"", "Named", "The node's name in the scene tree. Leave it blank to keep the name Godot gives it.", "expression")).param_built(F.make_param("parent", "String", "get_tree().current_scene", "Under", "The node it is added under. The default is the running scene.", "expression")).param_built(_variable_param("new_node")).featured())
	# Get-or-add, so the local is bound whether or not the behaviour was already there and the rows
	# below it keep working. "Only one" looks for a child with that name first; "allow another" always
	# makes a new one. Either way the node is NAMED after the class, because a script node made with
	# .new() would otherwise be called "Node".
	descriptors.append(F.act("AddBehaviourInto", "Add Behaviour",
		"{?once=yes}var {name}: {behaviour} = {target}.get_node_or_null(\"{behaviour}\") as {behaviour}\nif {name} == null:\n\t{name} = {behaviour}.new()\n\t{name}.name = \"{behaviour}\"\n\t{target}.add_child({name}){/once}{?once=no}var {name} := {behaviour}.new()\n{name}.name = \"{behaviour}\"\n{target}.add_child({name}){/once}" + tool_owner("{name}"),
		CATEGORY, "Add behaviour [b]{behaviour}[/b] to [i]{target}[/i], into [b]{name}[/b]",
		"Gives a node a behaviour: a script node added as its child, named after its class so the Inspector and get_node find it. With Only one, a node that already has the behaviour keeps it and the row uses that one; with Allow another, it always adds a new one. The behaviour's own script decides what it does and what it needs from its parent.",
		"Node").param_built(_type_param("behaviour", "Node", "Behaviour", "The behaviour to add: pick it from the list of node types, or type the class_name of a script.")).param_built(_target_param("To", "The node that gets the behaviour. Leave it as self for this node.")).param_choice("once", "yes", "How many", "Only one keeps the behaviour a node already has. Allow another adds a new one every time.", [{"key": "yes", "label": "only one"}, {"key": "no", "label": "allow another"}]).param_built(_variable_param("new_behaviour")).featured())
	descriptors.append(F.act("RemoveBehaviour", "Remove Behaviour",
		"var __behaviour_{uid} := {target}.get_node_or_null(\"{behaviour}\")\nif __behaviour_{uid} != null:\n\t{target}.remove_child(__behaviour_{uid})\n\t__behaviour_{uid}.queue_free()",
		CATEGORY, "Remove behaviour [b]{behaviour}[/b] from [i]{target}[/i]",
		"Takes a behaviour off a node, and does nothing when it is not there. It is detached first and freed after, so a check made in the same frame already says it is gone.",
		"Node").param_built(_type_param("behaviour", "Node", "Behaviour", "The behaviour to remove: pick it from the list of node types, or type the class_name of a script.")).param_built(_target_param("From", "The node to take the behaviour off. Leave it as self for this node.")))


# ── The parts a body is made of: a picture, a shape, a timer ──
static func _add_parts(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("AddSpriteTo", "Add Sprite",
		"var __sprite_{uid} := Sprite2D.new()\n__sprite_{uid}.texture = {texture}\n{target}.add_child(__sprite_{uid}{?tool=yes}, true{/tool})" + tool_owner("__sprite_{uid}"),
		CATEGORY, "Add a sprite showing [b]{texture}[/b] to [i]{target}[/i]",
		"Adds a Sprite2D showing a picture to a node.",
		"Node2D").param_built(_texture_param()).param_built(_target_param("To", "The node the sprite is added to. Leave it as self for this node.")))
	descriptors.append(F.act("AddSprite3DTo", "Add Sprite (3D)",
		"var __sprite_{uid} := Sprite3D.new()\n__sprite_{uid}.texture = {texture}\n{target}.add_child(__sprite_{uid}{?tool=yes}, true{/tool})" + tool_owner("__sprite_{uid}"),
		CATEGORY, "Add a sprite showing [b]{texture}[/b] to [i]{target}[/i]",
		"Adds a Sprite3D showing a picture to a node.",
		"Node3D").param_built(_texture_param()).param_built(_target_param("To", "The node the sprite is added to. Leave it as self for this node.")))
	# Six shape rows rather than one with a choice, because each shape has its own measurements and a
	# choice would carry fields the chosen shape never reads.
	descriptors.append(F.act("AddCircleShapeTo", "Add Circle Shape",
		"var __shape_{uid} := CollisionShape2D.new()\nvar __circle_{uid} := CircleShape2D.new()\n__circle_{uid}.radius = {radius}\n__shape_{uid}.shape = __circle_{uid}\n{target}.add_child(__shape_{uid}{?tool=yes}, true{/tool})" + tool_owner("__shape_{uid}"),
		CATEGORY, "Add a circle shape of radius [b]{radius}[/b] to [i]{target}[/i]",
		"Adds a CollisionShape2D holding a circle to a node. The node should be a physics body or an area, which is what a shape belongs to.",
		"Node2D").param_built(F.make_param("radius", "String", "16.0", "Radius", "How far the circle reaches from its centre, in pixels.", "expression")).param_built(_target_param("To", "The body or area the shape is added to. Leave it as self for this node.")))
	descriptors.append(F.act("AddRectangleShapeTo", "Add Rectangle Shape",
		"var __shape_{uid} := CollisionShape2D.new()\nvar __rectangle_{uid} := RectangleShape2D.new()\n__rectangle_{uid}.size = {size}\n__shape_{uid}.shape = __rectangle_{uid}\n{target}.add_child(__shape_{uid}{?tool=yes}, true{/tool})" + tool_owner("__shape_{uid}"),
		CATEGORY, "Add a rectangle shape of size [b]{size}[/b] to [i]{target}[/i]",
		"Adds a CollisionShape2D holding a rectangle to a node. The node should be a physics body or an area, which is what a shape belongs to.",
		"Node2D").param_built(F.make_param("size", "String", "Vector2(32, 32)", "Size", "The width and height of the rectangle, in pixels.", "expression")).param_built(_target_param("To", "The body or area the shape is added to. Leave it as self for this node.")))
	descriptors.append(F.act("AddCapsuleShapeTo", "Add Capsule Shape",
		"var __shape_{uid} := CollisionShape2D.new()\nvar __capsule_{uid} := CapsuleShape2D.new()\n__capsule_{uid}.radius = {radius}\n__capsule_{uid}.height = {height}\n__shape_{uid}.shape = __capsule_{uid}\n{target}.add_child(__shape_{uid}{?tool=yes}, true{/tool})" + tool_owner("__shape_{uid}"),
		CATEGORY, "Add a capsule shape of radius [b]{radius}[/b] and height [b]{height}[/b] to [i]{target}[/i]",
		"Adds a CollisionShape2D holding a capsule to a node, the usual shape for a character. The node should be a physics body or an area, which is what a shape belongs to.",
		"Node2D").param_built(F.make_param("radius", "String", "16.0", "Radius", "How far the circle reaches from its centre, in pixels.", "expression")).param_built(F.make_param("height", "String", "48.0", "Height", "The height of the capsule from end to end, in pixels.", "expression")).param_built(_target_param("To", "The body or area the shape is added to. Leave it as self for this node.")))
	descriptors.append(F.act("AddSphereShapeTo", "Add Sphere Shape (3D)",
		"var __shape_{uid} := CollisionShape3D.new()\nvar __sphere_{uid} := SphereShape3D.new()\n__sphere_{uid}.radius = {radius}\n__shape_{uid}.shape = __sphere_{uid}\n{target}.add_child(__shape_{uid}{?tool=yes}, true{/tool})" + tool_owner("__shape_{uid}"),
		CATEGORY, "Add a sphere shape of radius [b]{radius}[/b] to [i]{target}[/i]",
		"Adds a CollisionShape3D holding a sphere to a node. The node should be a physics body or an area, which is what a shape belongs to.",
		"Node3D").param_built(F.make_param("radius", "String", "0.5", "Radius", "How far the sphere reaches from its centre, in metres.", "expression")).param_built(_target_param("To", "The body or area the shape is added to. Leave it as self for this node.")))
	descriptors.append(F.act("AddBoxShapeTo", "Add Box Shape (3D)",
		"var __shape_{uid} := CollisionShape3D.new()\nvar __box_{uid} := BoxShape3D.new()\n__box_{uid}.size = {size}\n__shape_{uid}.shape = __box_{uid}\n{target}.add_child(__shape_{uid}{?tool=yes}, true{/tool})" + tool_owner("__shape_{uid}"),
		CATEGORY, "Add a box shape of size [b]{size}[/b] to [i]{target}[/i]",
		"Adds a CollisionShape3D holding a box to a node. The node should be a physics body or an area, which is what a shape belongs to.",
		"Node3D").param_built(F.make_param("size", "String", "Vector3(1, 1, 1)", "Size", "The width, height and depth of the box, in metres.", "expression")).param_built(_target_param("To", "The body or area the shape is added to. Leave it as self for this node.")))
	descriptors.append(F.act("AddCapsuleShape3DTo", "Add Capsule Shape (3D)",
		"var __shape_{uid} := CollisionShape3D.new()\nvar __capsule_{uid} := CapsuleShape3D.new()\n__capsule_{uid}.radius = {radius}\n__capsule_{uid}.height = {height}\n__shape_{uid}.shape = __capsule_{uid}\n{target}.add_child(__shape_{uid}{?tool=yes}, true{/tool})" + tool_owner("__shape_{uid}"),
		CATEGORY, "Add a capsule shape of radius [b]{radius}[/b] and height [b]{height}[/b] to [i]{target}[/i]",
		"Adds a CollisionShape3D holding a capsule to a node, the usual shape for a character. The node should be a physics body or an area, which is what a shape belongs to.",
		"Node3D").param_built(F.make_param("radius", "String", "0.5", "Radius", "How far the sphere reaches from its centre, in metres.", "expression")).param_built(F.make_param("height", "String", "2.0", "Height", "The height of the capsule from end to end, in metres.", "expression")).param_built(_target_param("To", "The body or area the shape is added to. Leave it as self for this node.")))
	# Autostart is set before the timer joins the tree, which is when Godot starts it. The default
	# callable does nothing: a default that freed or moved something would be a trap on a row that
	# has just been dropped in.
	descriptors.append(F.act("AddTimerTo", "Add Timer",
		"var __timer_{uid} := Timer.new()\n__timer_{uid}.wait_time = {seconds}\n__timer_{uid}.autostart = true\n__timer_{uid}.timeout.connect({callable})\n{target}.add_child(__timer_{uid}{?tool=yes}, true{/tool})" + tool_owner("__timer_{uid}"),
		CATEGORY, "Add a timer to [i]{target}[/i], every [b]{seconds}[/b] seconds, calling [b]{callable}[/b]",
		"Adds a Timer that starts as soon as it is in the scene and calls a function every time it runs out, again and again. Type the name of one of this sheet's functions to call it; the starting value does nothing.",
		"Node").param_built(F.make_param("seconds", "String", "2.0", "Every", "How many seconds pass between calls.", "expression")).param_built(F.make_param("callable", "String", "func() -> void: pass", "Calling", "What to call each time the timer runs out: the name of a function, or a function written inline.", "expression")).param_built(_target_param("To", "The node the timer is added to. Leave it as self for this node.")))


# ── Keeping what was made ──
static func _add_keeping(descriptors: Array[ACEDescriptor]) -> void:
	# `add_to_group(name)` is NOT persistent: PackedScene.pack saves persistent groups only, so a
	# group added without the flag is gone from a packed copy. The flag is the whole difference.
	descriptors.append(F.act("AddToGroupSaved", "Add To Group (Saved With Scene)",
		"{target}.add_to_group({group}, true)",
		CATEGORY, "Add [i]{target}[/i] to [b]{group}[/b], kept when the scene is saved",
		"Puts a node in a group in a way that is kept when the node is packed into a scene or a prefab. A plain Add To Group is forgotten by a packed copy.",
		"Node").param_built(_target_param("Node", "The node to put in the group.")).param("group", "\"enemies\"", "Group", "The group name.", "group_reference"))
	# The owner walk is the same one Save Branch As Scene File makes, and for the same reason: a
	# node added while the game runs is owned by nothing, and pack writes out only what the root owns.
	# The ownership is lent for the pack and given back, so the row can run twice on the same branch.
	descriptors.append(F.act("KeepAsPrefab", "Keep As Prefab",
		FILE_ACES.owner_walk_head("{node}")
		+ "{prefab} = PackedScene.new()\n"
		+ "var __packed_{uid}: Error = {prefab}.pack(__branch_{uid})\n"
		+ "for __lent_{uid}: Node in __adopted_{uid}:\n"
		+ "\t__lent_{uid}.owner = null\n"
		+ "if __packed_{uid} != OK:\n"
		+ "\tpush_error(\"Keep As Prefab: %s could not be packed (error %d).\" % [__branch_{uid}.name, __packed_{uid}])",
		CATEGORY, "Keep [i]{node}[/i] as a prefab in [b]{prefab}[/b]",
		"Packs a node and everything under it into a PackedScene held in a variable, so it can be instantiated again later or saved with Save Data Asset. Nodes that belong to another scene stay instances. Groups the branch is in are kept only when they were added saved with the scene.",
		"Node").param_typed("Node", "node", "self", "Node", "The node to pack. It becomes the root of the prefab.", "expression").param("prefab", "my_prefab", "Prefab", "The variable that holds the PackedScene. Declare it as a PackedScene in this sheet.", "variable_reference"))


## The "what kind of node" field: a type name, with Godot's own Create New Node window behind it.
static func _type_param(param_id: String, default_type: String, label: String, words: String) -> ACEParam:
	return F.make_param(param_id, "String", default_type, label, words, NODE_TYPE_HINT)


## The variable the node is kept in. A real local, so the next row in the event can say it.
static func _variable_param(default_name: String) -> ACEParam:
	return F.make_param("name", "String", default_name, "Into", "The variable the new node is kept in. Following rows in this event can use this name.", "")


## The node a part or a behaviour is added to.
static func _target_param(label: String, words: String) -> ACEParam:
	return F.make_param("target", "String", "self", label, words, "expression")


## The picture a sprite shows. A file field: the row writes the load the way a reader would have.
static func _texture_param() -> ACEParam:
	return F.make_param("texture", "String", "load(\"res://icon.svg\")", "Picture", "The image the sprite shows.", "texture_path")


# ── A tool sheet's own housekeeping ──
static func _add_tools(descriptors: Array[ACEDescriptor]) -> void:
	# The nodes a tool sheet builds are marked when they are added (see tool_owner), and this finds them
	# again: the direct children of a parent that carry the mark. Without it a rebuild button adds a second
	# copy every time it is pressed.
	descriptors.append(F.act("RemoveBuiltNodes", "Remove What This Sheet Built",
		"for __built_{uid}: Node in {parent}.get_children():\n\tif __built_{uid}.has_meta(&\"" + BUILT_META + "\") and __built_{uid}.get_meta(&\"" + BUILT_META + "\") == get_script().resource_path:\n\t\t{parent}.remove_child(__built_{uid})\n\t\t__built_{uid}.queue_free()",
		CATEGORY, "Remove the nodes this sheet built under [i]{parent}[/i]",
		"Frees the nodes this sheet built earlier under a node, the ones it marked when it added them (another sheet's are left alone), so a rebuild starts from nothing instead of adding a second copy. Each is taken out of the tree at once, so the name it had is free again. Only direct children are looked at, and in the editor this is not a step Ctrl+Z takes back.",
		"Node").param_built(F.make_param("parent", "String", "get_tree().edited_scene_root", "Under", "The node whose children are looked at. In a tool this is the scene being edited.", "expression")))


## A row's template as it is written when the row is dropped into a TOOL sheet: the owner and mark lines
## are kept as part of the row (the segment marks come off), so the row writes them from then on and a
## game sheet that never had them writes nothing extra. A template with no such segment is returned as it was.
static func tool_form(template: String) -> String:
	return template.replace("{?tool=yes}", "").replace("{/tool}", "")


## A row's values as they are filled in when the row is dropped into a tool sheet: the parent a built node
## goes under starts as the scene being edited rather than the running scene, which a tool does not have.
static func tool_params(params: Dictionary) -> Dictionary:
	var filled: Dictionary = params.duplicate()
	if str(filled.get("parent", "")).strip_edges() == GAME_PARENT:
		filled["parent"] = TOOL_PARENT
	return filled


## The owner and mark lines for the node held in `slot` (a placeholder or a throwaway local), as the
## optional segment a tool sheet keeps.
static func tool_owner(slot: String) -> String:
	return TOOL_OWNER_HEAD + slot + ".owner = get_tree().edited_scene_root" + NL + TAB \
		+ slot + ".set_meta(&\"" + BUILT_META + "\", get_script().resource_path){/tool}"
