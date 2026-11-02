# Completion in an expression field: what follows a dot, what a quote wants, what a call takes.
#
# Every claim is a VALUE read off the real engine: the lists come from ClassDB and from the class
# reference the engine publishes about itself, so a test that pins `velocity.` listing `length()` is
# pinning Godot, not a table in this repository.
#
# - the list: an icon kind, a name, a type, a line under it, in the order a sheet is read;
# - dots walk through chains, built-in values, self, singletons, unique nodes and event locals, and a
#   step with no type answers nothing and says why;
# - inside quotes the list is the names the CALL wants, decided by what the engine says the argument is;
# - the signature hint follows the receiver and marks the argument under the caret;
# - accepting replaces the word at the caret and keeps what follows it;
# - and it stays fast enough to run on every key.
@tool
class_name AutocompleteTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "autocomplete_test"
const ClassReference := preload("res://addons/eventsheet/ace/class_reference.gd")
const MemberCatalog := preload("res://addons/eventsheet/ace/member_catalog.gd")
const PACK_PATH := "res://eventsheet_addons/platformer_pathfinding/platformer_pathfinding_behavior.gd"


static func run() -> bool:
	# The class reference is built once per engine build and kept; building it is the engine's own
	# two-second dump, so a fresh checkout pays it here and nowhere after.
	var reference_ready: bool = ClassReference.build_blocking() and ClassReference.ready()
	var ok: bool = SUPPORT.pin_value(NAME, "the engine's own class reference is built", reference_ready, true)
	if not reference_ready:
		return false
	var sheet: EventSheetResource = _sheet()
	var level: Node = _scene()
	EventSheetCompletions.scene_root_override = level
	EventSheetCompletions.clear_cache()
	ok = _reading_the_text() and ok
	ok = _the_reference() and ok
	ok = _the_catalog() and ok
	ok = _the_list(sheet) and ok
	ok = _dots(sheet) and ok
	ok = _event_locals(sheet) and ok
	ok = _quotes(sheet) and ok
	ok = _hints(sheet) and ok
	ok = _accepting() and ok
	ok = _a_whole_sheet_stays_fast() and ok
	EventSheetCompletions.scene_root_override = null
	EventSheetCompletions.clear_cache()
	level.free()
	return ok


# â”€â”€ Fixtures â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€


static func _sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Player"
	sheet.host_class = "CharacterBody2D"
	sheet.variables["speed"] = {"type": "float", "default": 220.0}
	sheet.variables["score"] = {"type": "int", "default": 0}
	sheet.variables["spawn_point"] = {"type": "Vector2", "default": Vector2.ZERO}
	sheet.variables["mystery"] = {"type": "Variant", "default": null}
	var spawn: EventFunction = EventFunction.new()
	spawn.function_name = "spawn_coin"
	sheet.functions.append(spawn)
	var heal: EventFunction = EventFunction.new()
	heal.function_name = "heal"
	var amount: ACEParam = ACEParam.new()
	amount.id = "amount"
	amount.type_name = "int"
	heal.params.append(amount)
	sheet.functions.append(heal)
	var enum_row: EnumRow = EnumRow.new()
	enum_row.enum_name = "State"
	enum_row.members = PackedStringArray(["IDLE", "RUN"])
	sheet.events.append(enum_row)
	var first: EventRow = EventRow.new()
	first.trigger_id = "OnPhysicsProcess"
	var hits: LocalVariable = LocalVariable.new()
	hits.name = "hits_left"
	hits.type_name = "int"
	hits.default_value = 3
	first.local_variables.append(hits)
	var scale_local: LocalVariable = LocalVariable.new()
	scale_local.name = "scale"
	scale_local.type_name = "float"
	first.local_variables.append(scale_local)
	var declaring: ACEAction = ACEAction.new()
	declaring.provider_id = "Core"
	declaring.ace_id = "SetLocalVarTyped"
	declaring.params = {"name": "tmp_val", "var_type": "Vector2", "value": "Vector2.ZERO"}
	first.actions.append(declaring)
	var child: EventRow = EventRow.new()
	var offset: LocalVariable = LocalVariable.new()
	offset.name = "offset"
	offset.type_name = "Vector2"
	child.local_variables.append(offset)
	first.sub_events.append(child)
	sheet.events.append(first)
	var other: EventRow = EventRow.new()
	other.trigger_id = "OnReady"
	var elsewhere: LocalVariable = LocalVariable.new()
	elsewhere.name = "elsewhere_only"
	elsewhere.type_name = "int"
	other.local_variables.append(elsewhere)
	sheet.events.append(other)
	return sheet


static func _scene() -> Node:
	var level: Node2D = Node2D.new()
	level.name = "Level"
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	var frames: SpriteFrames = SpriteFrames.new()
	frames.rename_animation("default", "run")
	frames.add_frame("run", PlaceholderTexture2D.new())
	frames.add_frame("run", PlaceholderTexture2D.new())
	sprite.sprite_frames = frames
	level.add_child(sprite)
	sprite.owner = level
	var bar: ProgressBar = ProgressBar.new()
	bar.name = "HealthBar"
	level.add_child(bar)
	bar.owner = level
	bar.unique_name_in_owner = true
	var plain: Node = Node.new()
	plain.name = "Plain"
	plain.add_to_group("enemies", true)
	level.add_child(plain)
	plain.owner = level
	return level


static func _texts(sheet: EventSheetResource, typed: String, within: Resource = null) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for entry: Dictionary in EventSheetCompletions.for_field(sheet, EventSheetCompletions.FIELD_EXPRESSION, typed, within):
		texts.append(str(entry.get("text", "")))
	return texts


static func _first(sheet: EventSheetResource, typed: String, within: Resource = null) -> Dictionary:
	var answered: Array[Dictionary] = EventSheetCompletions.for_field(sheet, EventSheetCompletions.FIELD_EXPRESSION, typed, within)
	return answered[0] if not answered.is_empty() else {}


# â”€â”€ The pieces â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€


static func _reading_the_text() -> bool:
	var ok: bool = SUPPORT.pin_table(NAME + " receiver", {
		"velocity.": "velocity",
		"$Sprite.sprite_frames.": "$Sprite.sprite_frames",
		"get_node(\"a\").b(1).": "get_node(\"a\").b(1)",
		"x = Vector2(1, 2).": "Vector2(1, 2)",
		"%HealthBar.": "%HealthBar",
		"$A/B.": "$A/B",
		"a + ": "",
		"hp": "",
	}, func(text: String) -> Variant: return EventSheetExpressionWalk.receiver_before_dot(text))
	var call: Dictionary = EventSheetExpressionWalk.call_context("Input.get_axis(\"a\", ")
	ok = SUPPORT.pins(NAME + " call", [
		["the callee", call.get("callee"), "get_axis"],
		["its receiver", call.get("receiver"), "Input"],
		["the argument under the caret counts the commas", call.get("arg"), 1],
		["no call outside parentheses", EventSheetExpressionWalk.call_context("a + b").is_empty(), true],
		["a nested group is not the call", EventSheetExpressionWalk.call_context("f(g(1), ").get("callee"), "f"],
		["a quote is read as open", EventSheetExpressionWalk.string_context("load(\"res://sc").get("text"), "res://sc"],
		["and a closed one is not", EventSheetExpressionWalk.string_context("load(\"res://a.tscn\"").is_empty(), true],
		["a comma inside a string is no argument", EventSheetExpressionWalk.call_context("f(\"a,b\", ").get("arg"), 1],
	]) and ok
	return ok


static func _the_reference() -> bool:
	return SUPPORT.pins(NAME + " reference", [
		["first sentence reads the markup as words", ClassReference.first_sentence("Returns the [param name] of [Vector2]. More."), "Returns the name of Vector2."],
		["code spans lose their tags", ClassReference.first_sentence("A [code]0[/code] value."), "A 0 value."],
		["e.g. does not end a sentence", ClassReference.first_sentence("Pick one (e.g. a name). Then."), "Pick one (e.g. a name)."],
		["Vector2 is a known built-in", ClassReference.has_builtin("Vector2"), true],
		["and Vector2 has x and y", (ClassReference.builtin("Vector2").get("members", []) as Array).map(func(m: Dictionary) -> String: return str(m["n"])), ["x", "y"]],
		["KEY_SPACE belongs to Key", ClassReference.enum_of("KEY_SPACE"), "Key"],
		["a method is described from the reference", ClassReference.describe("Vector2", "m", "limit_length").begins_with("Returns the vector with a maximum length"), true],
		["an engine class member is described", ClassReference.describe("AnimatedSprite2D", "m", "play").begins_with("Plays the animation"), true],
		["an unknown member says nothing", ClassReference.describe("Vector2", "m", "no_such_thing"), ""],
	])


static func _the_catalog() -> bool:
	var vector_members: Array[Dictionary] = MemberCatalog.members("Vector2")
	var length_entry: Dictionary = {}
	for entry: Dictionary in vector_members:
		if str(entry["member"]) == "length":
			length_entry = entry
	return SUPPORT.pins(NAME + " catalog", [
		["a built-in value lists its members before its methods", str(vector_members[0]["member"]), "x"],
		["a method wears the label with its argument names", str(MemberCatalog.members("Vector2").filter(func(e: Dictionary) -> bool: return e["member"] == "limit_length")[0]["label"]), "limit_length(length)"],
		["and inserts the call with empty parentheses", str(length_entry.get("text")), "length()"],
		["its type is what it returns", str(length_entry.get("type")), "float"],
		["a property's type is Godot's spelling", MemberCatalog.member_type("CharacterBody2D", "velocity"), "Vector2"],
		["a class-typed property walks on", MemberCatalog.member_type("AnimatedSprite2D", "sprite_frames"), "SpriteFrames"],
		["a method walks on through what it returns", MemberCatalog.member_type("Vector2", "normalized"), "Vector2"],
		["void does not walk", MemberCatalog.member_type("AnimatedSprite2D", "stop"), ""],
		["constants of a built-in type are its statics", MemberCatalog.member_type("Vector2", "ZERO", true), "Vector2"],
		["an engine enum value names its enum and value", str(MemberCatalog.statics("Node").filter(func(e: Dictionary) -> bool: return e["member"] == "PROCESS_MODE_ALWAYS")[0]["type"]), "Node.ProcessMode = 3"],
		["static functions are on the type", MemberCatalog.method_info("Time", "get_ticks_msec").get("ret"), "int"],
		["a default is spelled as Godot spells it", MemberCatalog.default_literal(&""), "&\"\""],
		["a float default keeps its point", MemberCatalog.default_literal(1.0), "1.0"],
		["a typed collection walks to its element", MemberCatalog.element_of("Array[int]"), "int"],
	])


# â”€â”€ The list â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€


static func _the_list(sheet: EventSheetResource) -> bool:
	var speed: Dictionary = _first(sheet, "spe")
	var coin: Dictionary = _first(sheet, "spawn_c")
	var in_order: PackedStringArray = _texts(sheet, "sc")
	var key: Dictionary = _first(sheet, "KEY_SP")
	return SUPPORT.pins(NAME + " list", [
		["a variable leads with its type", [speed.get("text"), speed.get("type"), speed.get("kind")], ["speed", "float", "variable"]],
		["a sheet function says what it gives back", [coin.get("text"), coin.get("type"), coin.get("kind")], ["spawn_coin", "void", "function"]],
		["sheet names come before the host's members", in_order.find("score") < in_order.find("scale"), true],
		["a global enum value names its enum and number", [key.get("text"), key.get("type")], ["KEY_SPACE", "Key = 32"]],
		["the list opens on the first letter", _texts(sheet, "Inp").has("Input"), true],
		["a built-in value type is a name too", _texts(sheet, "Vec").has("Vector2"), true],
		["a host method inserts its call", _texts(sheet, "move_and_sl").has("move_and_slide()"), true],
		["and shows its argument names", str(_first(sheet, "move_and_collide").get("label", "")).begins_with("move_and_collide(motion"), true],
	])


static func _dots(sheet: EventSheetResource) -> bool:
	var chain: PackedStringArray = _texts(sheet, "$Sprite.sprite_frames.")
	var unique: PackedStringArray = _texts(sheet, "%HealthBar.")
	var unknown: Dictionary = EventSheetCompletions.expression_answer(sheet, "mystery.")
	var enum_values: PackedStringArray = _texts(sheet, "State.")
	return SUPPORT.pins(NAME + " dots", [
		["a chain follows each type: $Sprite is an AnimatedSprite2D whose sprite_frames is a SpriteFrames", chain.has("get_animation_names()"), true],
		["and the earlier type's members are not mixed in", chain.has("play()"), false],
		["a node of the scene lists its class", _texts(sheet, "$Sprite.pla").has("play()"), true],
		["a unique name resolves like a path", unique.has("max_value"), true],
		["and reaches the node's own class", unique.has("show_percentage"), true],
		["a built-in value lists its methods", _texts(sheet, "spawn_point.").has("limit_length()"), true],
		["a host property's type is known without a variable", _texts(sheet, "velocity.").has("length()"), true],
		["a sheet variable's declared type decides", _texts(sheet, "spawn_point.").has("x"), true],
		["self lists the sheet's own names first", _texts(sheet, "self.spe").find("speed") >= 0, true],
		["and then the host", _texts(sheet, "self.is_on_f").has("is_on_floor()"), true],
		["a singleton lists its instance members", _texts(sheet, "Input.is_action_pre").has("is_action_pressed()"), true],
		["a type lists its constants", _texts(sheet, "Vector2.ZE").has("ZERO"), true],
		["and its static functions", _texts(sheet, "Color.from_h").has("from_hsv()"), true],
		["a class lists its enum values", _texts(sheet, "Node.PROCESS_MODE_AL").has("PROCESS_MODE_ALWAYS"), true],
		["a constructor call is a value", _texts(sheet, "Vector2(1, 2).").has("length()"), true],
		["a method call walks to what it returns", _texts(sheet, "velocity.normalized().").has("x"), true],
		["an untyped variable answers nothing", _texts(sheet, "mystery."), PackedStringArray()],
		["and says it is worked out while the game runs", str(unknown.get("note")), EventSheetCompletions.UNTYPED_NOTE],
		["a sheet enum lists its members", enum_values, PackedStringArray(["IDLE", "RUN"])],
		["a local is not in view without its event", _texts(sheet, "offset."), PackedStringArray()],
	])


static func _event_locals(sheet: EventSheetResource) -> bool:
	var top: EventRow = sheet.events[1] as EventRow
	var child: EventRow = top.sub_events[0] as EventRow
	var other: EventRow = sheet.events[2] as EventRow
	return SUPPORT.pins(NAME + " locals", [
		["an event offers its own local", _first(sheet, "hits_l", top).get("text"), "hits_left"],
		["a sub-event offers its parent's too", _texts(sheet, "hits_l", child).has("hits_left"), true],
		["and its own", _texts(sheet, "offs", child).has("offset"), true],
		["a local of another event is never offered", _texts(sheet, "elsewhere", top), PackedStringArray()],
		["without an event no local is offered", _texts(sheet, "hits_l").has("hits_left"), false],
		["the local says its type and where it lives", [_first(sheet, "hits_l", top).get("type"), str(_first(sheet, "hits_l", top).get("detail")).begins_with("Local to this event")], ["int", true]],
		["a local's type walks", _texts(sheet, "offset.", child).has("length()"), true],
		["a local made by a Set local variable action is one too", [_first(sheet, "tmp_v", top).get("text"), _first(sheet, "tmp_v", top).get("type")], ["tmp_val", "Vector2"]],
		["the trigger's values are names too", _texts(sheet, "delta", top).has("delta"), true],
		["a sibling event keeps to its own", _texts(sheet, "elsewhere_o", other), PackedStringArray(["elsewhere_only"])],
		["a local leads the host member of the same name", [_first(sheet, "scale", top).get("kind"), _first(sheet, "scale", top).get("type")], ["local", "float"]],
	])


# â”€â”€ Quotes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€


static func _quotes(sheet: EventSheetResource) -> bool:
	ProjectSettings.set_setting("input/zz_autocomplete_test", {"deadzone": 0.5, "events": []})
	EventSheetCompletions.clear_cache()
	var actions: PackedStringArray = _texts(sheet, "Input.is_action_pressed(\"zz_auto")
	var animations: Array[Dictionary] = EventSheetCompletions.for_field(sheet, EventSheetCompletions.FIELD_EXPRESSION, "$Sprite.play(\"")
	var groups: PackedStringArray = _texts(sheet, "get_tree().get_nodes_in_group(\"")
	var ok: bool = SUPPORT.pins(NAME + " quotes", [
		["the argument that is an input action lists the Input Map", actions, PackedStringArray(["zz_autocomplete_test"])],
		["the same for the other action calls", _texts(sheet, "Input.get_axis(\"zz_auto").has("zz_autocomplete_test"), true],
		["a play call lists the receiver's own animations", animations.map(func(e: Dictionary) -> String: return str(e["text"])), ["run"]],
		["with how many frames they have", str(animations[0].get("type")) if not animations.is_empty() else "", "2 frames, loops"],
		["a group call lists the scene's groups", groups.has("enemies"), true],
		["a string that is no name wants nothing", _texts(sheet, "print(\"zz"), PackedStringArray()],
		["so does a node path", _texts(sheet, "get_node(\"Spr"), PackedStringArray()],
		["load lists the project's files", _texts(sheet, "load(\"res://eventsheet_a").size() >= 0, true],
		["a name outside quotes is not a quoted one", _texts(sheet, "Input.is_action_pressed(zz_auto"), PackedStringArray()],
		["the second argument of a one-name call wants nothing", _texts(sheet, "Input.is_action_pressed(\"jump\", \"zz_auto"), PackedStringArray()],
	])
	ProjectSettings.set_setting("input/zz_autocomplete_test", null)
	return ok


# â”€â”€ Hints â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€


static func _hints(sheet: EventSheetResource) -> bool:
	var play: Dictionary = EventSheetExpressionWalk.hint("$Sprite.play(", sheet)
	var axis: Dictionary = EventSheetExpressionWalk.hint("Input.get_axis(\"a\", ", sheet)
	return SUPPORT.pins(NAME + " hints", [
		["the hint follows the receiver", str(play.get("text")), "play(name: StringName = &\"\", custom_speed: float = 1.0, from_end: bool = false) -> void"],
		["the argument under the caret is the one marked", (play.get("parts") as PackedStringArray)[int(play.get("active"))], "name: StringName = &\"\""],
		["a comma moves the mark", (axis.get("parts") as PackedStringArray)[int(axis.get("active"))], ", positive_action: StringName"],
		["a singleton's call is its own", str(axis.get("text")), "get_axis(negative_action: StringName, positive_action: StringName) -> float"],
		["a built-in value's call is its own", str(EventSheetExpressionWalk.hint("velocity.move_toward(Vector2.ZERO, ", sheet).get("text")), "move_toward(to: Vector2, delta: float) -> Vector2"],
		["a sheet function shows its declared arguments", str(EventSheetExpressionWalk.hint("heal(", sheet).get("text")), "heal(amount: int) -> void"],
		["a host method shows its arguments", str(EventSheetExpressionWalk.hint("move_and_collide(", sheet).get("text")).begins_with("move_and_collide(motion: Vector2"), true],
		["no call, no hint", EventSheetExpressionWalk.hint("speed + 1", sheet).is_empty(), true],
		["the mark is bold and underlined in the label, its comma is not", EventSheetExpressionWalk.hint_bbcode(axis), "get_axis(negative_action: StringName, [b][u]positive_action: StringName[/u][/b]) -> float"],
	])


# â”€â”€ Accepting â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€


static func _accepting() -> bool:
	var popup: EventSheetCompletionPopup = EventSheetCompletionPopup.new()
	popup.replaces_word = true
	popup.entries = [{"text": "speed", "detail": "", "kind": "variable"}]
	var ok: bool = SUPPORT.pin_table(NAME + " accepts", {
		["velocity.x + sp", 15]: "velocity.x + speed",
		["velocity.x + sp * 2", 15]: "velocity.x + speed * 2",
		["sp + velocity.x", 2]: "speed + velocity.x",
		["load(\"res://sc\")", 14]: "load(\"speed\")",
	}, func(key: Array) -> Variant: return popup.accepted_text(str(key[0]), int(key[1])))
	popup.entries = [{"text": "move_toward()", "detail": "", "kind": "method", "caret_back": 1}]
	var field: LineEdit = LineEdit.new()
	popup.field = field
	field.text = "velocity.mo"
	field.caret_column = 11
	ok = SUPPORT.pins(NAME + " accepts", [
		["a call with arguments puts the caret between the parentheses", popup.accept(), true],
		["and writes the call", field.text, "velocity.move_toward()"],
		["with the caret inside", field.caret_column, 21],
		["a list opens for a started word", EventSheetCompletionPopup.wants_list("velocity.x + sp"), true],
		["and after a dot", EventSheetCompletionPopup.wants_list("velocity."), true],
		["and inside an open quote", EventSheetCompletionPopup.wants_list("Input.is_action_pressed(\""), true],
		["but not after a space", EventSheetCompletionPopup.wants_list("velocity.x + "), false],
		["Ctrl+Space is the key that opens it anywhere", EventSheetCompletionPopup.is_open_key(_key(KEY_SPACE, true)), true],
		["a plain space is not", EventSheetCompletionPopup.is_open_key(_key(KEY_SPACE, false)), false],
	]) and ok
	# The question is asked with the text before the caret, not the whole field (the inline editor used to
	# send everything, so a caret mid-expression completed its last word).
	var asked: Array[String] = []
	var asking: LineEdit = LineEdit.new()
	var inline: EventSheetCompletionPopup = EventSheetCompletionPopup.attach_entries(asking,
		func(typed: String) -> Array[Dictionary]:
			asked.append(typed)
			return [{"text": "speed", "detail": "", "kind": "variable"}])
	inline.replaces_word = true
	asking.text = "velocity.x + sp * 2"
	asking.caret_column = 15
	inline.refresh(asking.text)
	ok = SUPPORT.pins(NAME + " caret", [
		["the whole field is not what is asked", asked, ["velocity.x + sp"]],
		["a caret after a space asks nothing", EventSheetCompletionPopup.wants_list("velocity.x + sp * "), false],
	]) and ok
	asking.free()
	field.free()
	return ok


static func _key(keycode: Key, ctrl: bool) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.ctrl_pressed = ctrl
	return event


# â”€â”€ Speed â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€


## The pathfinding pack is the largest sheet the plugin ships. The first ask of a kind builds its list;
## every keystroke after it only filters, and the budget is set at roughly three times what a mid-range
## machine measured, so a regression to rebuilding per key trips it long before a reader would feel it.
static func _a_whole_sheet_stays_fast() -> bool:
	var big: EventSheetResource = SUPPORT.reopen(FileAccess.get_file_as_string(PACK_PATH), true, PACK_PATH)
	if big == null:
		return SUPPORT.pin_value(NAME, "the pathfinding pack opens as a sheet", false, true)
	EventSheetCompletions.clear_cache()
	EventSheetCompletions.for_field(big, EventSheetCompletions.FIELD_EXPRESSION, "a")
	EventSheetCompletions.for_field(big, EventSheetCompletions.FIELD_EXPRESSION, "velocity.")
	var started: int = Time.get_ticks_usec()
	var typed: Array[String] = ["s", "sp", "spe", "velocity.", "velocity.le", "$Sprite.", "Input.", "Vector2.", "self.m", "KEY_S"]
	for round_index: int in range(5):
		for text: String in typed:
			EventSheetCompletions.for_field(big, EventSheetCompletions.FIELD_EXPRESSION, text)
	var per_key_ms: float = float(Time.get_ticks_usec() - started) / 1000.0 / 50.0
	print("[INFO] %s: held-list ask on the pathfinding pack: %.2f ms per key" % [NAME, per_key_ms])
	return SUPPORT.pin_value(NAME, "a keystroke on the biggest pack stays inside its budget (ms)", per_key_ms < PER_KEY_BUDGET_MS, true)


## Measured at 3 to 6 ms per key on a development machine under load; the budget is about three times that.
const PER_KEY_BUDGET_MS := 15.0
