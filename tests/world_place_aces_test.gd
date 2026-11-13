@tool
class_name WorldPlaceAcesTest
extends RefCounted

# Pins the world-space twins and the deprecations that point at them. A node's `position` is measured
# from its parent and `global_position` is the place in the level; a handful of shipped verbs wrote the
# wrong one, and the compatibility rule is that nothing shipped is edited: each of those is deprecated
# (hidden from the picker, still compiling and reading) and a new verb writes the right place.
#
# What this holds, per verb: the template AFTER the node-scoped transform, the sentence, the host, and
# for a deprecated verb that it is hidden, names its twin, compiles byte for byte as before and still
# has a sentence to read with.

const SUPPORT := preload("res://tests/support.gd")
const NAME := "world_place_aces_test"

## id -> [template after the `{target.}` transform, sentence, host class].
const NEW_ACES: Dictionary = {
	"SetWorldPosition2D": ["{target.}set_global_position({pos})", "Set world position to {pos}", "Node2D"],
	"SetWorldPosition3D": ["{target.}set_global_position({pos})", "Set world position to {pos}", "Node3D"],
	"SetPositionToObject2D": ["global_position = {other}.global_position", "Set world position to [b]{other}[/b]", "Node2D"],
	"GetPositionX2D": ["{target.}position.x", "X", "Node2D"],
	"GetPositionY2D": ["{target.}position.y", "Y", "Node2D"],
	"GetWorldX2D": ["{target.}global_position.x", "world X", "Node2D"],
	"GetWorldY2D": ["{target.}global_position.y", "world Y", "Node2D"],
	"GetWorldPosition2D": ["{target.}global_position", "world position", "Node2D"],
	"GetPositionX3D": ["{target.}position.x", "X", "Node3D"],
	"GetPositionY3D": ["{target.}position.y", "Y", "Node3D"],
	"GetPositionZ3D": ["{target.}position.z", "Z", "Node3D"],
	"GetWorldX3D": ["{target.}global_position.x", "world X", "Node3D"],
	"GetWorldY3D": ["{target.}global_position.y", "world Y", "Node3D"],
	"GetWorldZ3D": ["{target.}global_position.z", "world Z", "Node3D"],
	"GetWorldPosition3D": ["{target.}global_position", "world position", "Node3D"],
	"GlideTowardWorld": ["{host.}global_position = {host.}global_position.move_toward({destination}, {speed} * {delta_t})",
		"Move toward {destination} at {speed}", "Node2D"],
	"WrapAroundLayoutXWorld": ["{host.}global_position.x = wrapf({host.}global_position.x, {low}, {high})",
		"Wrap around scene horizontally", "Node2D"],
	"WrapAroundLayoutYWorld": ["{host.}global_position.y = wrapf({host.}global_position.y, {low}, {high})",
		"Wrap around scene vertically", "Node2D"],
	"BoundToLayoutWorld": ["{host.}global_position = {host.}global_position.clamp({low}, {high})",
		"Bound to scene (inside {low} - {high})", "Node2D"],
	"WrapInsideScreenWorld": ["var __wrap_size_{uid}: Vector2 = get_viewport_rect().size\nglobal_position = Vector2(wrapf(global_position.x, 0.0, __wrap_size_{uid}.x), wrapf(global_position.y, 0.0, __wrap_size_{uid}.y))",
		"wrap inside the screen", "Node2D"],
	"SpawnNewCopyDeferredWorld": ["var {name} = {scene}.instantiate()\n{parent}.call_deferred(\"add_child\", {name})\n{name}.call_deferred(\"set_global_position\", {at})",
		"Instantiate [b]{scene}[/b] as [b]{name}[/b] at {at}, under [i]{parent}[/i], added on the next idle moment", "Node2D"],
	"SpawnNewCopyDeferredWorld3D": ["var {name} = {scene}.instantiate()\n{parent}.call_deferred(\"add_child\", {name})\n{name}.call_deferred(\"set_global_position\", {at})",
		"Instantiate [b]{scene}[/b] as [b]{name}[/b] at {at}, under [i]{parent}[/i], added on the next idle moment", "Node3D"],
	"SpawnSceneInWorld": ["var __spawn_{uid} = load({path}).instantiate()\nget_tree().current_scene.add_child(__spawn_{uid})\n__spawn_{uid}.global_position = {position}",
		"Instantiate {path} in the level at {position}", ""],
	"SetControlPosition": ["{target.}position = {pos}", "Set position to {pos}", "Control"],
	"SetControlWorldPosition": ["{target.}set_global_position({pos})", "Set world position to {pos}", "Control"],
	"SetControlSize": ["{target.}set_size({size})", "Set size to {size}", "Control"],
}

## deprecated id -> its world twin. Every one stays in the vocabulary with its template unchanged.
const DEPRECATED: Dictionary = {
	"SpawnNewCopyDeferred": "SpawnNewCopyDeferredWorld",
	"SpawnNewCopyDeferred3D": "SpawnNewCopyDeferredWorld3D",
	"WrapInsideScreen": "WrapInsideScreenWorld",
	"WrapAroundLayoutX": "WrapAroundLayoutXWorld",
	"WrapAroundLayoutY": "WrapAroundLayoutYWorld",
	"BoundToLayout": "BoundToLayoutWorld",
	"GlideToward": "GlideTowardWorld",
	"ApplyPushes": "ApplyPushesWorld",
}

## The templates the deprecated verbs shipped with. They are public API; this table is the proof they
## did not move.
const SHIPPED_TEMPLATES: Dictionary = {
	"SpawnNewCopyDeferred": "var {name} = {scene}.instantiate()\n{name}.position = {at}\n{parent}.call_deferred(\"add_child\", {name})",
	"SpawnNewCopyDeferred3D": "var {name} = {scene}.instantiate()\n{name}.position = {at}\n{parent}.call_deferred(\"add_child\", {name})",
	"WrapAroundLayoutX": "{host.}position.x = wrapf({host.}position.x, {low}, {high})",
	"WrapAroundLayoutY": "{host.}position.y = wrapf({host.}position.y, {low}, {high})",
	"BoundToLayout": "{host.}position = {host.}position.clamp({low}, {high})",
	"GlideToward": "{host.}position = {host.}position.move_toward({destination}, {speed} * {delta_t})",
}


static func run() -> bool:
	var by_id: Dictionary = _vocabulary()
	var ok: bool = _new_aces_are_pinned(by_id)
	ok = _deprecations_hold(by_id) and ok
	ok = _readings_without_a_space_now_say_it(by_id) and ok
	ok = _control_set_is_complete(by_id) and ok
	ok = _new_aces_compile(by_id) and ok
	ok = _spawn_twin_lands_in_the_world() and ok
	ok = _twins_read_like_their_lines() and ok
	return ok


static func _vocabulary() -> Dictionary:
	var by_id: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	return by_id


static func _new_aces_are_pinned(by_id: Dictionary) -> bool:
	var rows: Array = []
	for ace_id: String in NEW_ACES:
		var expected: Array = NEW_ACES[ace_id]
		var descriptor: ACEDescriptor = by_id.get(ace_id, null)
		rows.append(["%s exists" % ace_id, descriptor != null, true])
		if descriptor == null:
			continue
		rows.append(["%s template (post-transform)" % ace_id, descriptor.codegen_template, expected[0]])
		rows.append(["%s sentence" % ace_id, descriptor.display_text, expected[1]])
		rows.append(["%s host" % ace_id, descriptor.node_type, expected[2]])
		rows.append(["%s is not deprecated" % ace_id, descriptor.is_deprecated, false])
	return SUPPORT.pins(NAME, rows)


static func _deprecations_hold(by_id: Dictionary) -> bool:
	var rows: Array = []
	for old_id: String in DEPRECATED:
		var descriptor: ACEDescriptor = by_id.get(old_id, null)
		rows.append(["%s still ships" % old_id, descriptor != null, true])
		if descriptor == null:
			continue
		var definition: ACEDefinition = EventSheetACEAdapter.from_eventforge_descriptor(descriptor)
		rows.append(["%s is flagged deprecated for the picker" % old_id,
			bool(definition.metadata.get("deprecated", false)), true])
		rows.append(["%s names its twin" % old_id, descriptor.replacement_ace_id, "Core::%s" % DEPRECATED[old_id]])
		rows.append(["%s still has a sentence to read with" % old_id, descriptor.display_text.is_empty(), false])
		rows.append(["%s description points at the twin" % old_id,
			descriptor.description.contains(str(DEPRECATED[old_id])), true])
		if SHIPPED_TEMPLATES.has(old_id):
			rows.append(["%s template is the shipped one" % old_id, descriptor.codegen_template, SHIPPED_TEMPLATES[old_id]])
		# A deprecated verb is a hint, not a forwarding address: the twin writes another place, so the
		# migrate dialog must never offer to rewrite a stored row onto it.
		rows.append(["%s offers no automatic rewrite" % old_id, descriptor.successor_ace_id, ""])
	# The compiler still accepts a row that uses one, byte for byte.
	var compiled: String = _compiled("GlideToward", {"destination": "Vector2(10, 10)", "speed": "5.0", "delta_t": "delta"})
	rows.append(["a deprecated row still compiles as it always did",
		compiled.contains("\tposition = position.move_toward(Vector2(10, 10), 5.0 * delta)"), true])
	var deferred: String = _compiled("SpawnNewCopyDeferred", {"scene": "load(\"res://a.tscn\")", "name": "b", "at": "Vector2(1, 2)", "parent": "self"})
	rows.append(["the shipped safe spawn still places before it parents",
		deferred.find("\tb.position = Vector2(1, 2)") < deferred.find("\tself.call_deferred(\"add_child\", b)"), true])
	return SUPPORT.pins(NAME, rows)


static func _readings_without_a_space_now_say_it(by_id: Dictionary) -> bool:
	var rows: Array = [
		["Move In Direction says world space", (by_id["MoveInDirection3D"] as ACEDescriptor).display_text.contains("in world space"), true],
		["Move In Direction template untouched", (by_id["MoveInDirection3D"] as ACEDescriptor).codegen_template,
			"{target.}global_position += {direction} * {speed} * {delta_t}"],
		["Move By (3D) says its own axes", (by_id["TranslateNode3D"] as ACEDescriptor).display_text.contains("along its own axes"), true],
		["Move By (3D) template untouched", (by_id["TranslateNode3D"] as ACEDescriptor).codegen_template, "{target.}translate({offset})"],
		["Move Cursor To says screen pixels", (by_id["MouseMoveCursorTo"] as ACEDescriptor).display_text.contains("screen pixels"), true],
		["Move Cursor To template untouched", (by_id["MouseMoveCursorTo"] as ACEDescriptor).codegen_template, "Input.warp_mouse({position})"],
		["Instantiate Scene At says whose child it is", (by_id["SpawnSceneAt"] as ACEDescriptor).display_text.contains("as a child of this node"), true],
		["Instantiate Scene (Full) says whose child it is", (by_id["SpawnSceneFull"] as ACEDescriptor).display_text.contains("as a child of this node"), true],
		["Instantiate Scene As says where its place is measured from", (by_id["SpawnSceneAs"] as ACEDescriptor).display_text.contains("placed from its parent"), true],
		["Instantiate Scene At template untouched", (by_id["SpawnSceneAt"] as ACEDescriptor).codegen_template,
			"var __spawn_{uid} = load({path}).instantiate()\n__spawn_{uid}.position = {position}\nadd_child(__spawn_{uid})"],
		["Set Position (3D) template untouched", (by_id["SetPosition3D"] as ACEDescriptor).codegen_template, "{target.}position = {pos}"],
		["Set Position To Another Object (3D) reads world", (by_id["SetPositionToObject3D"] as ACEDescriptor).display_text,
			"Set world position to [b]{other}[/b]"],
		["a tween on global_position reads world position", EventSheetSentence.tween_property_word("global_position"), "world position"],
		["a tween on position keeps its own word", EventSheetSentence.tween_property_word("position"), "position"],
	]
	return SUPPORT.pins(NAME, rows)


## The Control set: position, world position and size are new; the anchors preset already shipped and
## now offers the whole LayoutPreset enum.
static func _control_set_is_complete(by_id: Dictionary) -> bool:
	var preset: ACEDescriptor = by_id["SetAnchorsPreset"]
	var options: PackedStringArray = PackedStringArray()
	for param: ACEParam in preset.params:
		if param.id == "preset":
			for choice: Variant in param.options:
				options.append(str((choice as Dictionary).get("key", choice)) if choice is Dictionary else str(choice))
	var expected: PackedStringArray = PackedStringArray()
	for member: String in ["TOP_LEFT", "TOP_RIGHT", "BOTTOM_LEFT", "BOTTOM_RIGHT", "CENTER_LEFT", "CENTER_TOP",
			"CENTER_RIGHT", "CENTER_BOTTOM", "CENTER", "LEFT_WIDE", "TOP_WIDE", "RIGHT_WIDE", "BOTTOM_WIDE",
			"VCENTER_WIDE", "HCENTER_WIDE", "FULL_RECT"]:
		expected.append("Control.PRESET_%s" % member)
	var missing: PackedStringArray = PackedStringArray()
	for member: String in expected:
		if not options.has(member):
			missing.append(member)
	return SUPPORT.pins(NAME, [
		["the anchors preset dropdown offers every LayoutPreset", missing, PackedStringArray()],
		["the anchors preset shipped template is unchanged", preset.codegen_template,
			"{target.}set_anchors_and_offsets_preset({preset})"],
	])


## Every new verb compiles, under its own host, with its defaults filled in.
static func _new_aces_compile(by_id: Dictionary) -> bool:
	var rows: Array = []
	var sample: Dictionary = {
		"SetWorldPosition2D": {"pos": "Vector2(3, 4)"},
		"SetControlSize": {"size": "Vector2(10, 20)"},
	}
	for ace_id: String in sample:
		var host: String = (by_id[ace_id] as ACEDescriptor).node_type
		var output: String = _compiled(ace_id, sample[ace_id], host)
		rows.append(["%s compiles in %s" % [ace_id, host], output.is_empty(), false])
	var world: String = _compiled("SetWorldPosition2D", {"pos": "Vector2(3, 4)"})
	rows.append(["Set World Position writes the world place", world.contains("\tset_global_position(Vector2(3, 4))"), true])
	var targeted: String = _compiled("SetWorldPosition2D", {"pos": "Vector2(3, 4)", "target": "$Sword"})
	rows.append(["Set World Position on another node writes the world place there", targeted.contains("\t$Sword.set_global_position(Vector2(3, 4))"), true])
	var wrap: String = _compiled("WrapAroundLayoutXWorld", {"low": "0.0", "high": "100.0"})
	rows.append(["Wrap Around Scene Horizontally (world) wraps the world place",
		wrap.contains("\tglobal_position.x = wrapf(global_position.x, 0.0, 100.0)"), true])
	var glide: String = _compiled("GlideTowardWorld", {"destination": "Vector2(10, 10)", "speed": "5.0", "delta_t": "delta"})
	rows.append(["Move Toward Position (world) moves the world place",
		glide.contains("\tglobal_position = global_position.move_toward(Vector2(10, 10), 5.0 * delta)"), true])
	var push: String = _compiled("ApplyPushesWorld", {"friction": "8.0"})
	rows.append(["Apply Pushes (world) adds to the world place", push.contains("\t\tglobal_position += __push_"), true])
	return SUPPORT.pins(NAME, rows)


## The safe spawn that lands where it was told: add the copy first, then place it in the level, both
## booked for the same idle moment so they run in that order.
static func _spawn_twin_lands_in_the_world() -> bool:
	var output: String = _compiled("SpawnNewCopyDeferredWorld", {"scene": "load(\"res://a.tscn\")", "name": "b", "at": "Vector2(1, 2)", "parent": "self"})
	var add_at: int = output.find("\tself.call_deferred(\"add_child\", b)")
	var place_at: int = output.find("\tb.call_deferred(\"set_global_position\", Vector2(1, 2))")
	return SUPPORT.pins(NAME, [
		["the world safe spawn books the add", add_at >= 0, true],
		["the world safe spawn books the world place after the add", place_at > add_at and add_at >= 0, true],
		["the world safe spawn never writes the local place", output.contains("b.position"), false],
	])


## The twins read in the same words as the lines they write. A glide or a fence that moves ANOTHER node
## (a behaviour moving the node it rides on) is a line about that node, so its shape line keeps the
## receiver; one that moves this node is the bare line the behaviour shapes read. And a hand-written
## copy of another node's place is never claimed by the 2D Set Position To Another Object: its 3D twin
## writes the same line, so the row would land on 3D scripts too.
static func _twins_read_like_their_lines() -> bool:
	var params: Dictionary = {"host": "host", "destination": "target", "speed": "5.0", "delta_t": "dt"}
	var own: Dictionary = {"host": "", "low": "Vector2.ZERO", "high": "Vector2(10, 10)"}
	var copied: Resource = EventSheetACELifter.lift_one_line("global_position = marker.global_position")
	return SUPPORT.pins(NAME, [
		["a glide on another node keeps its receiver", EventSheetBehaviorShapes.line_for("GlideTowardWorld", params),
			"host.global_position = host.global_position.move_toward(target, 5.0 * dt)"],
		["a fence on this node is the bare line", EventSheetBehaviorShapes.line_for("BoundToLayoutWorld", own),
			"global_position = global_position.clamp(Vector2.ZERO, Vector2(10, 10))"],
		["the local glide line is unchanged", EventSheetBehaviorShapes.line_for("GlideToward", params),
			"position = position.move_toward(target, 5.0 * dt)"],
		["a hand-written place copy is not claimed by the 2D row",
			copied is ACEAction and str((copied as ACEAction).ace_id) == "SetPositionToObject2D", false],
	])


static func _compiled(ace_id: String, params: Dictionary, host: String = "Node2D") -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = host
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params.duplicate()
	event.actions.append(action)
	sheet.events.append(event)
	return str(SheetCompiler.compile(sheet, "user://world_place_aces_test.gd").get("output", ""))
