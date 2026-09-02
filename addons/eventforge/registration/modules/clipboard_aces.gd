# EventForge module - Copying: share codes, the OS clipboard both ways, cloning a node, and
# remembering a value for this run.
#
# Four small families that are all "copy this thing somewhere else":
#
#   • SHARE CODES (Utility: Window) - any value in, one pasteable line of text out, and back again.
#     A seed, a loadout, a colour preset, a whole save slot: one grammar for every "send this to a
#     friend" moment. The encoding is base64 of Godot's own binary Variant form
#     (Marshalls.variant_to_base64) rather than JSON, for three reasons: it round-trips TYPES
#     losslessly (an int comes back an int, a Vector2 comes back a Vector2, nested Arrays and
#     Dictionaries keep their shape - JSON flattens every number to a float and has no Vector at
#     all), it is a single line with no spaces or newlines so it survives copy/paste through a chat
#     box, and base64_to_variant refuses to build OBJECTS by default, so a hostile code pasted by a
#     player cannot instantiate anything. Codes carry an "EF1." tag: Share Code Is Valid checks the
#     tag FIRST and short-circuits, so ordinary pasted prose never even reaches the decoder, then
#     two shape tests (length a multiple of 4, at least one header group) catch the realistic bad
#     paste - a code a chat client truncated - without one either. Only a tagged, correctly shaped,
#     still-corrupt payload reaches Marshalls, which logs an engine line when it refuses.
#
#   • CLIPBOARD IN (Utility: Window) - the read side of the OS clipboard. Shipped vocabulary is
#     write-only plus one blind read (Set Clipboard Text / Clipboard Text in core_aces); these are
#     the gates a paste box actually needs: has-text, has-image, the image itself, and a full
#     comparison against the clipboard text. There is deliberately NO "On Clipboard Changed"
#     trigger: the shipped Has Changed condition already turns any expression, including Clipboard
#     Text, into an edge.
#
#   • CLONE INTO (Nodes) - the one-row form of Duplicate Node + Add Child + place + group. The
#     shipped Duplicate Node is an EXPRESSION whose own help tells you to add the clone yourself,
#     so the everyday copy costs three rows and a throwaway variable. This is the LIVE-node twin of
#     Spawn Scene (Full), which already does the same job starting from a scene file. The group is
#     added with persistent = true, because a non-persistent group is dropped when a node is packed
#     into a scene and every group check then silently never fires.
#
#   • REMEMBER / RESTORE (Run Context) - a named copy of any value, for this run: preview-then-
#     cancel, before-the-buff values, a stash before a cutscene. Keyed by NAME in node metadata,
#     exactly like the shipped named cooldowns, so a Remember in one row and a Restore in a
#     completely different event agree with no declared variable between them and no member state.
#     This is the IN-SESSION twin of Remember Between Runs (the sheet-variable menu item) and Only
#     Once Ever, which both persist to disk; nothing here survives closing the game.
#
# Every template compiles to plain Godot - DisplayServer, Marshalls, duplicate/add_child, set_meta -
# with zero plugin references, honouring the parity covenant.
@tool
class_name EventForgeClipboardACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT_CLIPBOARD := "Utility: Window"
const CAT_NODES := "Nodes"
const CAT_RUN := "Run Context"

## The tag every share code carries. Reading it back is a prefix test, so a paste that is not a
## code at all is rejected without ever calling the decoder (which would log a decode error).
const CODE_TAG := "EF1."

## The metadata key prefix for Remember / Restore. Same shape as the cooldowns' "__ef_cool_",
## so the two families never collide on a name.
const MEMORY_PREFIX := "__ef_mem_"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Share codes: any value <-> one pasteable line of text ──
	descriptors.append(F.expr("ShareCodeFor", "Share Code For", "(\"%s\" + Marshalls.variant_to_base64({value}))" % CODE_TAG, CAT_CLIPBOARD, "share code for [b]{value}[/b]", "Turns any value into one compact line of text a player can paste anywhere - a seed, a loadout, a whole save. Read it back with Value From Share Code.").param("value", "0", "Value", "Anything - a run seed, a loadout list, a colour, a whole save record.", "expression"))
	descriptors.append(F.act("CopyShareCode", "Copy Share Code To Clipboard", "DisplayServer.clipboard_set(\"%s\" + Marshalls.variant_to_base64({value}))" % CODE_TAG, CAT_CLIPBOARD, "copy share code for [b]{value}[/b] to clipboard", "Encodes any value as a share code and puts it straight on the operating system clipboard, ready to paste.").param("value", "0", "Value", "Anything - a run seed, a loadout list, a whole save record.", "expression"))
	# Three cheap tests before the decoder, in order of how much they cost: the tag, then the two
	# shape facts every base64 payload has (a length that is a multiple of 4, and at least one
	# 4-character group of header). They exist because Marshalls PRINTS a red engine error for
	# anything it cannot decode, and the realistic bad paste is a code a chat client truncated - which
	# fails the length test three times out of four and is then refused in silence. A tagged payload
	# that is the right shape and still garbage does reach the decoder and does log; the description
	# says to ask this question when the text CHANGES rather than every frame, which is the only real
	# defence against that (an alphabet test would mean compiling a regular expression per evaluation,
	# which costs far more in the loop this verb actually sits in).
	descriptors.append(F.cond("ShareCodeIsValid", "Share Code Is Valid", "(str({code}).begins_with(\"%s\") and str({code}).trim_prefix(\"%s\").length() >= 8 and str({code}).trim_prefix(\"%s\").length() %% 4 == 0 and Marshalls.base64_to_variant(str({code}).trim_prefix(\"%s\")) != null)" % [CODE_TAG, CODE_TAG, CODE_TAG, CODE_TAG], CAT_CLIPBOARD, "[b]{code}[/b] is a valid share code", "True when the text really is a share code that decodes cleanly, so a paste box can refuse garbage before it reaches the game. Ask it when the pasted text CHANGES (a Paste button, On Text Changed) rather than every frame: a code mangled in transit can still reach the decoder, and the engine logs a line each time it is refused. A code that was made from nothing at all also reads as invalid.").param("code", "\"\"", "Code", "The pasted text to test - usually Clipboard Text or a paste box's text.", "expression"))
	descriptors.append(F.expr("ValueFromShareCode", "Value From Share Code", "(Marshalls.base64_to_variant(str({code}).trim_prefix(\"%s\")) if str({code}).begins_with(\"%s\") else null)" % [CODE_TAG, CODE_TAG], CAT_CLIPBOARD, "value from share code [b]{code}[/b]", "Reads the value back out of a share code, giving nothing when the text is not a valid code.").param("code", "\"\"", "Code", "The share code text to read - check it with Share Code Is Valid first.", "expression"))

	# ── Clipboard In: the read side of the OS clipboard (the write side ships in core_aces) ──
	descriptors.append(F.cond("ClipboardHasText", "Clipboard Has Text", "DisplayServer.clipboard_has()", CAT_CLIPBOARD, "clipboard has text", "True when the operating system clipboard currently holds any text - gate a paste box on it."))
	descriptors.append(F.cond("ClipboardHasImage", "Clipboard Has Image", "DisplayServer.clipboard_has_image()", CAT_CLIPBOARD, "clipboard has an image", "True when the operating system clipboard currently holds an image, such as a screenshot the player just copied."))
	descriptors.append(F.expr("ClipboardImage", "Clipboard Image", "DisplayServer.clipboard_get_image()", CAT_CLIPBOARD, "clipboard image", "The image currently on the operating system clipboard - feed it to ImageTexture.create_from_image to show it."))
	descriptors.append(F.cond("ClipboardTextIs", "Clipboard Text Is", "DisplayServer.clipboard_get() {op} {value}", CAT_CLIPBOARD, "clipboard text {op} [b]{value}[/b]", "Compares whatever text is on the clipboard against a value, with your choice of operator.").param_choice("op", "==", "Operator", "Comparison.", F.COMPARISON_OPTIONS).param("value", "\"\"", "Value", "Text to compare the clipboard against.", "expression"))

	# ── Clone Into: duplicate + add + place + group, in one row (the live-node twin of Spawn Scene) ──
	descriptors.append(F.act("CloneInto", "Clone Into", "var __clone_{uid} = {source}.duplicate()\n{parent}.add_child(__clone_{uid})\nif __clone_{uid} is Node2D or __clone_{uid} is Node3D or __clone_{uid} is Control:\n\t__clone_{uid}.global_position = {at}\nif not str({group}).is_empty():\n\t__clone_{uid}.add_to_group(StringName({group}), true)", CAT_NODES, "clone [i]{source}[/i] into [i]{parent}[/i] at [b]{at}[/b], group [b]{group}[/b]", "Copies a live node, adds the copy to a parent, places it and optionally puts it in a group - the one-row form of Duplicate Node plus Add Child plus Set Position. Use Spawn Scene when you are starting from a .tscn file instead.").param("source", "self", "Copy", "The live node to copy.", "expression").param("parent", "get_parent()", "Into", "Where the copy is added.", "expression").param("at", "Vector2(0, 0)", "At", "World position for the copy (a Vector3 for a 3D node). Only used when the copy has a position.", "expression").param("group", "\"\"", "Group", "Optional group for the copy (blank = none).", "group_reference"))

	# ── Remember / Restore: a named copy of any value, for this run (meta-keyed, like cooldowns) ──
	descriptors.append(F.act("RememberValueAs", "Remember Value As", "set_meta(&\"%s\" + str({name}), {value})" % MEMORY_PREFIX, CAT_RUN, "remember [b]{value}[/b] as [b]{name}[/b]", "Copies any value aside under a name, in memory, for this run - the before-value for a preview, a buff or a cutscene. For memory that survives closing the game use Remember Between Runs on the variable, or the Save System pack.").param("name", "\"before\"", "Name", "Any label you also use in Restore Value Into.", "expression").param("value", "0", "Value", "The value to copy aside.", "expression"))
	descriptors.append(F.act("RestoreValueInto", "Restore Value Into", "{var_name} = get_meta(&\"%s\" + str({name}), {var_name})" % MEMORY_PREFIX, CAT_RUN, "restore [b]{name}[/b] into [b]{var_name}[/b]", "Pours a remembered value back into a variable. When nothing was remembered under that name the variable keeps what it already had.").param("name", "\"before\"", "Name", "The label used in Remember Value As.", "expression").param("var_name", "value", "Into Variable", "Variable that receives the remembered value (left alone when nothing was remembered).", "variable_reference"))
	descriptors.append(F.expr("RememberedValue", "Remembered Value", "get_meta(&\"%s\" + str({name}), {fallback})" % MEMORY_PREFIX, CAT_RUN, "remembered [b]{name}[/b] or [b]{fallback}[/b]", "The value remembered under a name this run, or your fallback when there is none - read it without pouring it back.").param("name", "\"before\"", "Name", "The label used in Remember Value As.", "expression").param("fallback", "null", "Or", "What you get when nothing was remembered under that name.", "expression"))
	descriptors.append(F.cond("HasRemembered", "Has Remembered", "has_meta(&\"%s\" + str({name}))" % MEMORY_PREFIX, CAT_RUN, "has remembered [b]{name}[/b]", "True when something was remembered under that name this run - the gate on a Cancel button that should only undo a preview it actually took.").param("name", "\"before\"", "Name", "The label used in Remember Value As.", "expression"))
	descriptors.append(F.act("ForgetRemembered", "Forget Remembered", "if has_meta(&\"%s\" + str({name})): remove_meta(&\"%s\" + str({name}))" % [MEMORY_PREFIX, MEMORY_PREFIX], CAT_RUN, "forget remembered [b]{name}[/b]", "Drops a remembered value, so Has Remembered reads false again. Forgetting a name that was never remembered is harmless.").param("name", "\"before\"", "Name", "The label used in Remember Value As.", "expression"))

	return descriptors
