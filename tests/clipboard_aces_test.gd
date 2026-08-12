# Godot EventSheets - the copying vocabulary (clipboard_aces): share codes, the clipboard read side,
# Clone Into, and Remember / Restore.
#
# Two proofs per verb, because an emission pin alone would not catch a template that compiles and
# then does the wrong thing:
#   1. EMITTED: the row is compiled through SheetCompiler and the exact line is pinned.
#   2. REAL: the SHIPPED template (fetched from the registry, never re-typed here) is substituted
#      into a GDScript, reload()ed and RUN, including the failure branches each verb promises -
#      a share code that does not decode, a paste that is not a code at all, a Restore with nothing
#      remembered, a Forget of a name that was never remembered, a clone of a node that has no
#      position, and a blank group.
#
# Two things are deliberately stood in for, both noted at their call site: the OS clipboard (the
# headless display server has none, so the comparison verb is driven through a member in place of
# DisplayServer.clipboard_get()), and per-row uids (the dock bakes those at apply time).
# The three no-parameter clipboard readers cannot be run headless at all, so they are proven the
# only honest way available: the exact shipped call is type-checked against the real DisplayServer,
# with a negative control showing that check has teeth.
#
# Two engine error lines are EXPECTED during this test, both from cases that are the point:
# "Error when trying to decode Variant" is Marshalls refusing the deliberately corrupted share code
# (the ONE bad-paste shape the cheap tag and length tests cannot catch before the decoder), and the
# "clipboard_has_banana()" parse error is the negative control proving the binding check above would
# actually catch a mistyped DisplayServer call.
@tool
class_name ClipboardACEsTest
extends RefCounted

## The uid the dock would bake into a row; fixed here so the emitted locals are pinnable.
const UID := "t"


static func run() -> bool:
	var passed: bool = true
	# Share codes (#10)
	passed = _test_share_code_emits_tagged_base64() and passed
	passed = _test_share_code_round_trips_records_and_nested_lists() and passed
	passed = _test_share_code_keeps_types_json_would_lose() and passed
	passed = _test_share_code_is_one_pasteable_line() and passed
	passed = _test_share_code_validity_refuses_garbage() and passed
	passed = _test_value_from_a_bad_share_code_is_nothing() and passed
	# Clipboard In (#11)
	passed = _test_clipboard_readers_emit_display_server_calls() and passed
	passed = _test_clipboard_readers_are_real_display_server_calls() and passed
	passed = _test_clipboard_text_is_compares_with_the_chosen_operator() and passed
	# Clone Into (#12)
	passed = _test_clone_into_emits_duplicate_add_place_group() and passed
	passed = _test_clone_into_adds_places_and_groups_for_real() and passed
	passed = _test_clone_into_group_is_persistent() and passed
	passed = _test_clone_into_survives_a_node_with_no_position() and passed
	# Remember / Restore (#13)
	passed = _test_memory_verbs_emit_name_keyed_metadata() and passed
	passed = _test_remember_and_restore_round_trip_any_value() and passed
	passed = _test_restore_with_nothing_remembered_leaves_the_variable() and passed
	passed = _test_forget_clears_and_is_safe_when_there_is_nothing() and passed
	passed = _test_two_names_never_collide() and passed
	return passed


# ── Share codes (#10) ────────────────────────────────────────────────────────────────────────
## The encoder lands as the tagged base64 line, and the clipboard action carries the same payload.
static func _test_share_code_emits_tagged_base64() -> bool:
	var sheet: EventSheetResource = _sheet()
	var row: EventRow = _ready_row()
	row.actions.append(_set_var("code", _filled("ShareCodeFor", {"value": "run_seed"})))
	row.actions.append(_action("CopyShareCode", {"value": "run_seed"}))
	sheet.events.append(row)
	var output: String = _compile(sheet, "user://clipboard_share_emit.gd")
	var ok: bool = _check("Share Code For emits tagged base64 of the value",
		output.contains("\tcode = (\"EF1.\" + Marshalls.variant_to_base64(run_seed))"), true)
	ok = _check("Copy Share Code To Clipboard puts the same tagged payload on the clipboard",
		output.contains("\tDisplayServer.clipboard_set(\"EF1.\" + Marshalls.variant_to_base64(run_seed))"), true) and ok
	# The clipboard action carries its OWN copy of the encoder expression, so nothing but this check
	# stops the two drifting apart into codes that Value From Share Code can no longer read. Compared
	# as the shipped templates rather than as the strings typed above, which only equal themselves.
	var encoder: String = str(ACERegistry.find_descriptor("Core", "ShareCodeFor").codegen_template)
	var copier: String = str(ACERegistry.find_descriptor("Core", "CopyShareCode").codegen_template)
	# Share Code For's template is already parenthesised, so the clipboard action is exactly the
	# encoder handed to clipboard_set - any drift in either one breaks this equality.
	ok = _check("and it is the SAME encoder, not a second one that could drift",
		copier, "DisplayServer.clipboard_set" + encoder) and ok
	# It cannot be RUN headless (there is no clipboard), so the remaining way it can fail for real is
	# a mistyped binding - type-checked against the real DisplayServer, with the same negative control
	# the readers use proving that check has teeth.
	ok = _check("Copy Share Code To Clipboard calls a real DisplayServer method",
		_type_checks("func f() -> void:\n\t%s\n" % _filled("CopyShareCode", {"value": "0"})), true) and ok
	return ok


## The point of the pair: a Dictionary holding a nested Array comes back equal, not merely similar.
static func _test_share_code_round_trips_records_and_nested_lists() -> bool:
	var codec: Node = _codec()
	if codec == null:
		return _check("the share-code templates compile", false, true)
	var payload: Dictionary = {"seed": 12345, "items": [["sword", 3], ["shield", 1]], "on": true}
	var code: Variant = codec.call("encode", payload)
	var back: Variant = codec.call("decode", code)
	var ok: bool = _check("a record with a nested list survives the round trip", back, payload)
	ok = _check("the nested list is still reachable by index", str((back as Dictionary)["items"][1][0]), "shield") and ok
	ok = _check("a plain list round trips", codec.call("decode", codec.call("encode", [1, "two", 3.5])), [1, "two", 3.5]) and ok
	ok = _check("an empty record round trips to an empty record", codec.call("decode", codec.call("encode", {})), {}) and ok
	ok = _check("empty text round trips to empty text", codec.call("decode", codec.call("encode", "")), "") and ok
	ok = _check("its own code reads as valid", codec.call("valid", code), true) and ok
	codec.free()
	return ok


## Why base64-of-a-Variant and not JSON: whole numbers stay whole and a Vector2 stays a Vector2.
static func _test_share_code_keeps_types_json_would_lose() -> bool:
	var codec: Node = _codec()
	if codec == null:
		return _check("the share-code templates compile", false, true)
	var back: Variant = codec.call("decode", codec.call("encode", {"score": 7, "at": Vector2(3, 4)}))
	var ok: bool = _check("a whole number comes back a whole number, not a float",
		typeof((back as Dictionary)["score"]), TYPE_INT)
	ok = _check("a Vector2 comes back a Vector2", typeof((back as Dictionary)["at"]), TYPE_VECTOR2) and ok
	ok = _check("the Vector2 keeps its value", (back as Dictionary)["at"], Vector2(3, 4)) and ok
	codec.free()
	return ok


## A code has to survive a chat box: one line, no spaces, and the tag up front.
static func _test_share_code_is_one_pasteable_line() -> bool:
	var codec: Node = _codec()
	if codec == null:
		return _check("the share-code templates compile", false, true)
	var code: String = str(codec.call("encode", {"seed": 99, "items": [1, 2, 3]}))
	var ok: bool = _check("the code is tagged so a paste box can recognise it", code.begins_with("EF1."), true)
	ok = _check("the code holds no line break", code.contains("\n"), false) and ok
	ok = _check("the code holds no space", code.contains(" "), false) and ok
	codec.free()
	return ok


## The load-bearing verb: a paste box refuses anything that is not a code. Untagged text is refused
## WITHOUT calling the decoder (the tag test short-circuits), so ordinary pasted prose is silent.
static func _test_share_code_validity_refuses_garbage() -> bool:
	var codec: Node = _codec()
	if codec == null:
		return _check("the share-code templates compile", false, true)
	var ok: bool = _check("pasted prose is not a share code", codec.call("valid", "have you seen my cat"), false)
	ok = _check("empty text is not a share code", codec.call("valid", ""), false) and ok
	ok = _check("a bare base64 blob without the tag is not a share code",
		codec.call("valid", "AgAAAAcAAAA="), false) and ok
	# Tagged but corrupt: this one DOES reach the decoder, which logs the engine error noted in the
	# header. It is the exact case the condition exists for - a code that was mangled in transit.
	ok = _check("a tagged code that does not decode is refused",
		codec.call("valid", "EF1.aGVsbG8gd29ybGQ="), false) and ok
	ok = _check("the tag test comes first in the shipped template",
		str(ACERegistry.find_descriptor("Core", "ShareCodeIsValid").codegen_template).begins_with("(str({code}).begins_with(\"EF1.\")"), true) and ok

	# The two SHAPE tests that sit between the tag and the decoder. The realistic bad paste is a code
	# a chat client cut short, and a base64 payload always has a length that is a multiple of 4 - so
	# three truncations in four are refused without the decoder being called at all, and therefore
	# without the engine error line that a per-frame paste check would otherwise print every frame.
	var good_code: String = str(codec.call("encode", {"seed": 99, "items": [1, 2, 3]}))
	ok = _check("a genuine code is still accepted", codec.call("valid", good_code), true) and ok
	ok = _check("a code cut short by one character is refused",
		codec.call("valid", good_code.left(good_code.length() - 1)), false) and ok
	ok = _check("a code cut short by two is refused",
		codec.call("valid", good_code.left(good_code.length() - 2)), false) and ok
	ok = _check("the tag with nothing after it is refused", codec.call("valid", "EF1."), false) and ok
	ok = _check("the tag with a scrap after it is refused", codec.call("valid", "EF1.QUJD"), false) and ok
	ok = _check("the shipped template checks the payload LENGTH before it decodes",
		str(ACERegistry.find_descriptor("Core", "ShareCodeIsValid").codegen_template).contains(".length() % 4 == 0 and Marshalls.base64_to_variant"), true) and ok
	codec.free()
	return ok


## The reader's own failure branch: nothing back, rather than a wrong value or a crash.
static func _test_value_from_a_bad_share_code_is_nothing() -> bool:
	var codec: Node = _codec()
	if codec == null:
		return _check("the share-code templates compile", false, true)
	var ok: bool = _check("untagged text decodes to nothing", codec.call("decode", "have you seen my cat"), null)
	ok = _check("empty text decodes to nothing", codec.call("decode", ""), null) and ok
	ok = _check("a valid code still decodes to its value",
		codec.call("decode", codec.call("encode", 4242)), 4242) and ok
	codec.free()
	return ok


# ── Clipboard In (#11) ───────────────────────────────────────────────────────────────────────
## The four readers land as the plain DisplayServer calls, with the operator dropdown substituted.
static func _test_clipboard_readers_emit_display_server_calls() -> bool:
	var sheet: EventSheetResource = _sheet()
	var row: EventRow = _ready_row()
	row.conditions.append(_condition("ClipboardHasText", {}))
	row.actions.append(_set_var("pasted", _filled("ClipboardImage", {})))
	sheet.events.append(row)
	var image_row: EventRow = _ready_row()
	image_row.conditions.append(_condition("ClipboardHasImage", {}))
	image_row.actions.append(_raw("pass"))
	sheet.events.append(image_row)
	var compare_row: EventRow = _ready_row()
	compare_row.conditions.append(_condition("ClipboardTextIs", {"op": "!=", "value": "\"\""}))
	compare_row.actions.append(_raw("pass"))
	sheet.events.append(compare_row)
	var output: String = _compile(sheet, "user://clipboard_read_emit.gd")
	var ok: bool = _check("Clipboard Has Text emits the has-text call", output.contains("if DisplayServer.clipboard_has():"), true)
	ok = _check("Clipboard Has Image emits the has-image call", output.contains("if DisplayServer.clipboard_has_image():"), true) and ok
	ok = _check("Clipboard Image emits the image getter", output.contains("\tpasted = DisplayServer.clipboard_get_image()"), true) and ok
	ok = _check("Clipboard Text Is emits the chosen operator", output.contains("if DisplayServer.clipboard_get() != \"\":"), true) and ok
	return ok


## The headless display server has no clipboard, so the three readers cannot be RUN here. What can
## still fail for real is a mistyped binding, and that is what this catches: each shipped call is
## type-checked against the real DisplayServer. The negative control proves the check has teeth -
## an invented method name is rejected by the same route.
static func _test_clipboard_readers_are_real_display_server_calls() -> bool:
	var ok: bool = _check("Clipboard Has Text calls a real DisplayServer method",
		_type_checks("func f() -> bool:\n\treturn %s\n" % _filled("ClipboardHasText", {})), true)
	ok = _check("Clipboard Has Image calls a real DisplayServer method",
		_type_checks("func f() -> bool:\n\treturn %s\n" % _filled("ClipboardHasImage", {})), true) and ok
	ok = _check("Clipboard Image returns an Image from a real DisplayServer method",
		_type_checks("func f() -> Image:\n\treturn %s\n" % _filled("ClipboardImage", {})), true) and ok
	ok = _check("negative control: an invented clipboard method does NOT type-check",
		_type_checks("func f() -> bool:\n\treturn DisplayServer.clipboard_has_banana()\n"), false) and ok
	return ok


## The comparison really compares, for every operator the dropdown offers. The clipboard read is the
## ONE thing swapped out of the shipped template (there is no clipboard in a headless run) - the
## operator and the value come straight from the descriptor.
static func _test_clipboard_text_is_compares_with_the_chosen_operator() -> bool:
	var template: String = str(ACERegistry.find_descriptor("Core", "ClipboardTextIs").codegen_template)
	var ok: bool = _check("the shipped template reads the clipboard", template.contains("DisplayServer.clipboard_get()"), true)
	var source: String = "extends Node\n\nvar clip: String = \"\"\n\n\nfunc equals(value: String) -> bool:\n\treturn %s\n\n\nfunc differs(value: String) -> bool:\n\treturn %s\n" % [
		_filled("ClipboardTextIs", {"op": "==", "value": "value"}).replace("DisplayServer.clipboard_get()", "clip"),
		_filled("ClipboardTextIs", {"op": "!=", "value": "value"}).replace("DisplayServer.clipboard_get()", "clip")]
	var node: Node = _instantiate(source, Node.new())
	if node == null:
		return _check("the Clipboard Text Is statement compiles", false, true) and ok
	node.set("clip", "EF1.abc")
	ok = _check("a matching clipboard passes the equality form", node.call("equals", "EF1.abc"), true) and ok
	ok = _check("a different clipboard fails the equality form", node.call("equals", "something else"), false) and ok
	ok = _check("a different clipboard passes the not-equal form", node.call("differs", "something else"), true) and ok
	node.set("clip", "")
	ok = _check("an empty clipboard is not equal to a real value", node.call("equals", "EF1.abc"), false) and ok
	ok = _check("an empty clipboard equals empty text", node.call("equals", ""), true) and ok
	node.free()
	return ok


# ── Clone Into (#12) ─────────────────────────────────────────────────────────────────────────
## One row, four steps: duplicate, add, place (only when the copy has a position), group (only when
## a group was named), with the group flagged persistent.
static func _test_clone_into_emits_duplicate_add_place_group() -> bool:
	var sheet: EventSheetResource = _sheet()
	var row: EventRow = _ready_row()
	row.actions.append(_action("CloneInto", {"source": "self", "parent": "get_parent()", "at": "Vector2(24, 0)", "group": "\"enemies\""}))
	sheet.events.append(row)
	var output: String = _compile(sheet, "user://clipboard_clone_emit.gd")
	var ok: bool = _check("the copy is made", output.contains("\tvar __clone_t = self.duplicate()"), true)
	ok = _check("the copy is added to the chosen parent", output.contains("\tget_parent().add_child(__clone_t)"), true) and ok
	ok = _check("placing is guarded by the copy having a position",
		output.contains("\tif __clone_t is Node2D or __clone_t is Node3D or __clone_t is Control:"), true) and ok
	ok = _check("the copy is placed", output.contains("\t\t__clone_t.global_position = Vector2(24, 0)"), true) and ok
	ok = _check("grouping is skipped when no group was named", output.contains("\tif not str(\"enemies\").is_empty():"), true) and ok
	ok = _check("the group is added as PERSISTENT (a non-persistent group is lost when the node is packed)",
		output.contains("\t\t__clone_t.add_to_group(StringName(\"enemies\"), true)"), true) and ok
	return ok


## Run it: the copy exists under the parent, at the position asked for, in the group named.
static func _test_clone_into_adds_places_and_groups_for_real() -> bool:
	var host: Node2D = _cloner()
	if host == null:
		return _check("the Clone Into statement compiles", false, true)
	var parent: Node2D = host.get_parent() as Node2D
	host.call("clone_into", parent, Vector2(24, 8), "enemies")
	var ok: bool = _check("the parent gained exactly one child", parent.get_child_count(), 2)
	var copy: Node = parent.get_child(1)
	ok = _check("the copy is a copy of the original", copy.get_class(), "Node2D") and ok
	ok = _check("the copy sits where it was asked to", (copy as Node2D).global_position, Vector2(24, 8)) and ok
	ok = _check("the copy joined the named group", copy.is_in_group("enemies"), true) and ok
	ok = _check("the original is untouched", host.global_position, Vector2.ZERO) and ok
	host.call("clone_into", parent, Vector2(0, 0), "")
	ok = _check("a blank group leaves the copy ungrouped", parent.get_child(2).get_groups(), [] as Array) and ok
	parent.free()
	return ok


## The persistent flag, proven the only way it shows: pack the parent into a scene and rebuild it.
## A group added without the flag would be gone here.
static func _test_clone_into_group_is_persistent() -> bool:
	var host: Node2D = _cloner()
	if host == null:
		return _check("the Clone Into statement compiles", false, true)
	var parent: Node2D = host.get_parent() as Node2D
	host.owner = parent
	host.call("clone_into", parent, Vector2(5, 5), "pickups")
	var copy: Node = parent.get_child(1)
	copy.owner = parent
	var packed: PackedScene = PackedScene.new()
	var ok: bool = _check("the parent packs into a scene", packed.pack(parent), OK)
	var rebuilt: Node = packed.instantiate()
	ok = _check("the rebuilt scene still holds the copy", rebuilt.get_child_count(), 2) and ok
	ok = _check("the copy is STILL in its group after packing and rebuilding",
		rebuilt.get_child(1).is_in_group("pickups"), true) and ok
	rebuilt.free()
	parent.free()
	return ok


## The guard earns its place: cloning a plain Node (no position at all) must not crash.
static func _test_clone_into_survives_a_node_with_no_position() -> bool:
	var source: String = "extends Node\n\n\nfunc clone_into(source_node: Node, parent: Node, at: Vector2, group: String) -> void:\n%s\n" \
		% _indent(_filled("CloneInto", {"source": "source_node", "parent": "parent", "at": "at", "group": "group"}))
	var host: Node = _instantiate(source, Node.new())
	if host == null:
		return _check("the Clone Into statement compiles for a plain Node", false, true)
	var parent: Node = Node.new()
	var plain: Node = Node.new()
	plain.name = "Timer_Holder"
	parent.add_child(plain)
	host.call("clone_into", plain, parent, Vector2(9, 9), "helpers")
	var ok: bool = _check("a node with no position is still copied and added", parent.get_child_count(), 2)
	ok = _check("and still joins its group", parent.get_child(1).is_in_group("helpers"), true) and ok
	parent.free()
	host.free()
	return ok


# ── Remember / Restore (#13) ─────────────────────────────────────────────────────────────────
## All five verbs key the SAME metadata name, so a Remember here and a Restore in a different event
## agree with no declared variable between them. No members, no per-row state.
static func _test_memory_verbs_emit_name_keyed_metadata() -> bool:
	var sheet: EventSheetResource = _sheet()
	var row: EventRow = _ready_row()
	row.actions.append(_action("RememberValueAs", {"name": "\"ui_scale_before\"", "value": "ui_scale"}))
	row.actions.append(_action("RestoreValueInto", {"name": "\"ui_scale_before\"", "var_name": "ui_scale"}))
	row.actions.append(_set_var("ui_scale", _filled("RememberedValue", {"name": "\"ui_scale_before\"", "fallback": "1.0"})))
	row.actions.append(_action("ForgetRemembered", {"name": "\"ui_scale_before\""}))
	sheet.events.append(row)
	var gate_row: EventRow = _ready_row()
	gate_row.conditions.append(_condition("HasRemembered", {"name": "\"ui_scale_before\""}))
	gate_row.actions.append(_raw("pass"))
	sheet.events.append(gate_row)
	var output: String = _compile(sheet, "user://clipboard_memory_emit.gd")
	var ok: bool = _check("Remember Value As stores under the name",
		output.contains("\tset_meta(&\"__ef_mem_\" + str(\"ui_scale_before\"), ui_scale)"), true)
	ok = _check("Restore Value Into falls back to the variable's own value",
		output.contains("\tui_scale = get_meta(&\"__ef_mem_\" + str(\"ui_scale_before\"), ui_scale)"), true) and ok
	ok = _check("Remembered Value reads with the author's fallback",
		output.contains("\tui_scale = get_meta(&\"__ef_mem_\" + str(\"ui_scale_before\"), 1.0)"), true) and ok
	ok = _check("Forget Remembered checks before removing",
		output.contains("\tif has_meta(&\"__ef_mem_\" + str(\"ui_scale_before\")): remove_meta(&\"__ef_mem_\" + str(\"ui_scale_before\"))"), true) and ok
	ok = _check("Has Remembered gates on the same name",
		output.contains("if has_meta(&\"__ef_mem_\" + str(\"ui_scale_before\")):"), true) and ok
	return ok


## The preview-then-cancel loop, run for real - including a Dictionary, since the promise is "any value".
static func _test_remember_and_restore_round_trip_any_value() -> bool:
	var memory: Node = _memory()
	if memory == null:
		return _check("the memory statements compile", false, true)
	memory.set("value", 1.0)
	var ok: bool = _check("nothing is remembered to begin with", memory.call("has_memory", "ui_scale_before"), false)
	memory.call("remember", "ui_scale_before", memory.get("value"))
	ok = _check("after remembering, the gate reads true", memory.call("has_memory", "ui_scale_before"), true) and ok
	memory.set("value", 2.5)
	ok = _check("the live value changed while the memory did not",
		memory.call("remembered", "ui_scale_before", -1.0), 1.0) and ok
	memory.call("restore", "ui_scale_before")
	ok = _check("restoring pours the remembered value back", memory.get("value"), 1.0) and ok
	memory.call("remember", "loadout", {"weapon": "bow", "charms": [2, 5]})
	ok = _check("a whole record can be remembered and read back",
		memory.call("remembered", "loadout", null), {"weapon": "bow", "charms": [2, 5]}) and ok
	ok = _check("an unknown name hands back the fallback",
		memory.call("remembered", "never_set", "fallback"), "fallback") and ok
	memory.free()
	return ok


## The failure branch of Restore: with nothing remembered the variable keeps what it had.
static func _test_restore_with_nothing_remembered_leaves_the_variable() -> bool:
	var memory: Node = _memory()
	if memory == null:
		return _check("the memory statements compile", false, true)
	memory.set("value", 7.5)
	memory.call("restore", "never_remembered")
	var ok: bool = _check("restoring an unknown name leaves the variable alone", memory.get("value"), 7.5)
	ok = _check("and does not invent a memory", memory.call("has_memory", "never_remembered"), false) and ok
	memory.free()
	return ok


## Forget really forgets, and forgetting twice (or forgetting something never remembered) is safe.
static func _test_forget_clears_and_is_safe_when_there_is_nothing() -> bool:
	var memory: Node = _memory()
	if memory == null:
		return _check("the memory statements compile", false, true)
	memory.call("remember", "ui_scale_before", 3.0)
	memory.call("forget", "ui_scale_before")
	var ok: bool = _check("forgetting clears the memory", memory.call("has_memory", "ui_scale_before"), false)
	memory.call("forget", "ui_scale_before")
	ok = _check("forgetting again is harmless", memory.call("has_memory", "ui_scale_before"), false) and ok
	memory.call("forget", "was_never_remembered")
	ok = _check("forgetting a name that was never remembered is harmless",
		memory.call("has_memory", "was_never_remembered"), false) and ok
	memory.set("value", 9.0)
	memory.call("restore", "ui_scale_before")
	ok = _check("a forgotten memory no longer restores anything", memory.get("value"), 9.0) and ok
	memory.free()
	return ok


## Two names are two memories - the whole point of keying by name rather than by row.
static func _test_two_names_never_collide() -> bool:
	var memory: Node = _memory()
	if memory == null:
		return _check("the memory statements compile", false, true)
	memory.call("remember", "camera_pose", Vector2(10, 20))
	memory.call("remember", "ui_scale_before", 0.5)
	var ok: bool = _check("the first name keeps its own value", memory.call("remembered", "camera_pose", null), Vector2(10, 20))
	ok = _check("the second name keeps its own value", memory.call("remembered", "ui_scale_before", null), 0.5) and ok
	memory.call("forget", "camera_pose")
	ok = _check("forgetting one leaves the other", memory.call("has_memory", "ui_scale_before"), true) and ok
	ok = _check("the forgotten one is gone", memory.call("has_memory", "camera_pose"), false) and ok
	memory.free()
	return ok


# ── Harness ──────────────────────────────────────────────────────────────────────────────────
## A script carrying the three share-code templates as callable functions, straight from the registry.
static func _codec() -> Node:
	var source: String = "extends Node\n\n\nfunc encode(value: Variant) -> String:\n\treturn %s\n\n\nfunc decode(code: Variant) -> Variant:\n\treturn %s\n\n\nfunc valid(code: Variant) -> bool:\n\treturn %s\n" % [
		_filled("ShareCodeFor", {"value": "value"}),
		_filled("ValueFromShareCode", {"code": "code"}),
		_filled("ShareCodeIsValid", {"code": "code"})]
	return _instantiate(source, Node.new())


## A Node2D holding the Clone Into statement, already parented so the copy has somewhere to land.
static func _cloner() -> Node2D:
	var source: String = "extends Node2D\n\n\nfunc clone_into(parent: Node, at: Vector2, group: String) -> void:\n%s\n" \
		% _indent(_filled("CloneInto", {"source": "self", "parent": "parent", "at": "at", "group": "group"}))
	var host: Node2D = _instantiate(source, Node2D.new()) as Node2D
	if host == null:
		return null
	var parent: Node2D = Node2D.new()
	parent.name = "Arena"
	host.name = "Original"
	parent.add_child(host)
	return host


## A script carrying the five memory templates as callable functions, straight from the registry.
static func _memory() -> Node:
	var source: String = "extends Node\n\nvar value: Variant = 0.0\n\n\nfunc remember(name_key: Variant, new_value: Variant) -> void:\n\t%s\n\n\nfunc restore(name_key: Variant) -> void:\n\t%s\n\n\nfunc remembered(name_key: Variant, fallback: Variant) -> Variant:\n\treturn %s\n\n\nfunc has_memory(name_key: Variant) -> bool:\n\treturn %s\n\n\nfunc forget(name_key: Variant) -> void:\n\t%s\n" % [
		_filled("RememberValueAs", {"name": "name_key", "value": "new_value"}),
		_filled("RestoreValueInto", {"name": "name_key", "var_name": "value"}),
		_filled("RememberedValue", {"name": "name_key", "fallback": "fallback"}),
		_filled("HasRemembered", {"name": "name_key"}),
		_filled("ForgetRemembered", {"name": "name_key"})]
	return _instantiate(source, Node.new())


## The SHIPPED template for an ace_id with its placeholders filled: values given here, the rest at
## their shipped defaults, and the per-row uid baked exactly as the dock bakes it at apply time.
static func _filled(ace_id: String, values: Dictionary) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if descriptor == null:
		return "<%s is not registered>" % ace_id
	var template: String = str(descriptor.codegen_template).replace("{uid}", UID)
	for parameter: ACEParam in descriptor.params:
		template = template.replace("{%s}" % parameter.id, str(values.get(parameter.id, parameter.default_value)))
	return template


## True when the body type-checks against the real engine API (the negative control in the clipboard
## test proves an invented method name comes back false here).
static func _type_checks(body: String) -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = "extends Node\n\n\n%s" % body
	return script.reload() == OK


## Shifts a whole statement one level in, so a multi-line template can sit inside a function body.
static func _indent(statement: String) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for line: String in statement.split("\n"):
		lines.append("\t" + line)
	return "\n".join(lines)


static func _sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.events.append(_variable("run_seed", "int", 1234))
	sheet.events.append(_variable("code", "String", ""))
	sheet.events.append(_variable("pasted", "String", ""))
	sheet.events.append(_variable("ui_scale", "float", 1.0))
	return sheet


static func _variable(variable_name: String, type_name: String, default_value: Variant) -> LocalVariable:
	var variable: LocalVariable = LocalVariable.new()
	variable.name = variable_name
	variable.type_name = type_name
	variable.default_value = default_value
	return variable


static func _ready_row() -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	return row


static func _action(ace_id: String, values: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.codegen_template = _filled(ace_id, values)
	return action


static func _condition(ace_id: String, values: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.codegen_template = _filled(ace_id, values)
	return condition


static func _set_var(variable_name: String, value: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetVar"
	action.codegen_template = "%s = %s" % [variable_name, value]
	return action


static func _raw(statement: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "RawCode"
	action.codegen_template = statement
	return action


static func _compile(sheet: EventSheetResource, path: String) -> String:
	return str(SheetCompiler.compile(sheet, path).get("output", ""))


static func _instantiate(source: String, node: Node) -> Node:
	var script: GDScript = GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		print("  source failed to reload:\n%s" % source)
		node.free()
		return null
	node.set_script(script)
	return node


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] clipboard_aces_test: %s" % label)
		return true
	print("[FAIL] clipboard_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
