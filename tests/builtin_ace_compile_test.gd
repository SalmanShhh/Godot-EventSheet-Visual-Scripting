# EventForge - Built-in ACE compile-coverage guard
#
# "Do all the built-in ACEs actually produce valid GDScript?" This test answers it directly:
# it walks EVERY built-in descriptor, fills each param with a realistic value of its type,
# runs the real ActionCodegen._apply_template substitution, wraps the result in its declared
# host class (node_type), and reload()s it as GDScript. A template that doesn't parse - a typo,
# an unbalanced paren, a method that doesn't exist on its host - fails here, not in a game.
#
# Honest coverage: two kinds of ACE are listed-and-skipped rather than mis-tested -
#   (1) a param with a bare placeholder the user MUST supply that has no compilable stand-in
#       (a function name to call, a group name) - see the skip in _fill_params;
#   (2) ACEs that are correct GDScript but only compile inside a context this standalone
#       harness deliberately doesn't build (a loop, a return-typed function, compiler-injected
#       companion state, a user-chosen call target) - see NOT_STANDALONE.
# Triggers are skipped (they name a signal, they have no inline template). Nothing is dropped
# silently: every skip is printed.
@tool
class_name BuiltinACECompileTest
extends RefCounted

## Correct ACEs that cannot compile in ISOLATION - they need surrounding context this harness
## intentionally does not build: a loop (break/continue), a return-typed function (return X),
## compiler-injected companion state (frame-budget / every-N-seconds accumulators emitted as
## sibling declarations), a preloaded user resource, or a user-supplied call/connect target.
## Their templates are exercised by their own feature tests; here they are listed, not dropped.
const NOT_STANDALONE: Array[String] = [
	"LoopBreak", "LoopContinue", "ReturnValue",
	"EveryXSeconds", "TriggerOnce", "SingleFlight", "HasChanged",  # call sheet-synthesized companion state (an accumulator / an edge-test helper / a busy latch / a previous-value slot)
	"EveryRandomSeconds",  # calls a sheet-synthesized helper over its own accumulator + rolled-interval slots
	"WasRecentlyTrue", "OnlyOnceEver",  # calls a sheet-synthesized helper over its own last-true timestamp slot
	"OnceThisFrame",  # calls a sheet-synthesized helper over its own per-frame claim slots
	"FpsBelowFor",  # calls a sheet-synthesized helper over its own drop-started-at slot
	"OnGroupEmptied", "OnGroupFirstMember",  # call sheet-synthesized helpers over their own previous-count slots
	"AwaitIfOverBudget", "BeginFrameBudget", "AwaitNextFrame",
	"CallFunction", "CallMethod", "CallMethodValue", "ConnectSignal", "DisconnectSignal", "IsSignalConnected",
	"ConnectGroupSignal", "DisconnectGroupSignal",  # loop over a group and touch a user signal/callable - same as ConnectSignal
	"ConnectSignalUnique", "ConnectSignalOneShot",  # same user-supplied signal/callable as ConnectSignal
	"IsLocaleChangeNotification",  # references `what` - only exists inside _notification (its trigger's virtual)
	"ExportIsDebug", "ExportHasFeature",  # read `is_debug` / `features` - the arguments On Project Export's handler receives
	"BehaviorHost", "BehaviorHostValid",  # read the behaviour-only `host` var (synthesized only when behavior_mode)
	# R30. The Editor object's plugin verbs are EditorPlugin METHODS - they compile in an EditorPlugin
	# host and nowhere else, and this harness deliberately builds one host class (Node) rather than a
	# per-ACE menagerie. Their templates are exercised by editor_object_reading_test, which opens a real
	# hand-written plugin and gates the byte round-trip of what it re-emits.
	"AddToolsMenuItem", "RemoveToolsMenuItem", "AddEditorDock", "RemoveEditorDock",
	"AddEditorObjectType", "RemoveEditorObjectType", "AddEditorInspectorPlugin",
	"RemoveEditorInspectorPlugin", "UpdateViewportOverlays", "EditorUndoHistory",
	# W17 / W18. Same reason, three more EditorPlugin methods: the bottom-panel pair, and the command
	# palette entry (whose Calls default names a function the plugin defines, exactly as the Tools
	# menu item's does). Their round-trip is gated by editor_tool_shapes_test.
	"AddBottomPanel", "RemoveBottomPanel", "AddCommandPaletteCommand",
	# W10. `quit()` is SceneTree's, and a command tool IS a SceneTree - it is the whole main loop,
	# not a node in one. Same reason as the EditorPlugin methods above: the harness builds one host
	# class by hand, and a row that only exists in a SceneTree script has no business compiling in a
	# Node. Their round-trip is gated by editor_tool_shapes_test, which compiles the Command tool
	# skeleton, opens the result and recompiles it byte for byte.
	"CommandToolFinish", "CommandToolFinishWithCode",
	"AtMostEvery",  # calls a sheet-synthesized helper over its own last-run timestamp slot
	"OnlyOncePerNode", "OnlyOncePerName", "OnlyOnceThisSceneLoad",  # call sheet-synthesized once-memory helpers
	"StopRetrying",  # ends with `break` - only compiles inside the Retry Up To N Times loop it belongs to
	"RetryAttemptNumber",  # reads `attempt`, the Retry Up To N Times loop's own iterator
	"RetryUpTo", "RetriesExhausted",  # call sheet-synthesized helpers over the retry's own three-state record
	# X2 / X30. All five aimed-cursor words call ONE sheet-synthesized helper - the masked ray the
	# compiler writes into the file the first time any of them appears - so none of them compiles in
	# a class this harness wraps by hand, exactly like the once-memory and retry helpers above. Their
	# templates and the helper itself are gated by cursor_and_canvas_reading_test, which compiles them
	# through the real compiler and pins that the helper lands exactly once per file.
	"CursorIsOverObject3D", "OnObjectClicked3D",
	"MouseFloorPoint", "MouseFloorObject", "MouseFloorSlope",
	"AimedFloorPoint", "AimedFloorObject", "AimedFloorSlope",
]


static func run() -> bool:
	var descriptors: Array[ACEDescriptor] = EventForgeBuiltinACEs.get_descriptors()
	var checked: int = 0
	var skipped: Array[String] = []
	var failures: Array[String] = []

	for d: ACEDescriptor in descriptors:
		if d.ace_type == ACEDescriptor.ACEType.TRIGGER:
			continue
		if str(d.codegen_template).strip_edges().is_empty():
			continue
		if NOT_STANDALONE.has(d.ace_id):
			skipped.append("%s/%s (not standalone-compilable)" % [d.provider_id, d.ace_id])
			continue
		var fill: Dictionary = _fill_params(d)
		if fill.get("skip", false):
			skipped.append("%s/%s (%s)" % [d.provider_id, d.ace_id, fill.get("reason", "")])
			continue
		var source: String = _wrap(d, fill["params"])
		var script: GDScript = GDScript.new()
		script.source_code = source
		var err: int = script.reload()
		checked += 1
		if err != OK:
			failures.append("%s/%s [%s host=%s] -> %s\n----\n%s\n----" % [
				d.provider_id, d.ace_id, _type_name(d.ace_type),
				(d.node_type if not str(d.node_type).is_empty() else "Node"),
				error_string(err), source])

	for f: String in failures:
		print("[FAIL] builtin_ace_compile_test: %s" % f)
	print("[INFO] builtin_ace_compile_test: checked=%d compiled, skipped=%d, failed=%d" % [checked, skipped.size(), failures.size()])
	if not skipped.is_empty():
		print("[INFO] builtin_ace_compile_test: skipped (need user-supplied context; covered by feature tests + the template audit): %s" % ", ".join(skipped))

	return _check("every auto-fillable built-in ACE compiles in its host", failures.is_empty(), true)


## Builds a params dict that fills each placeholder with a value of the param's type that
## compiles. Returns {"skip": true, ...} when a param has only a bare placeholder the user must
## supply (e.g. a function name) with no compilable stand-in, so the ACE is reported, not mis-tested.
static func _fill_params(d: ACEDescriptor) -> Dictionary:
	var params: Dictionary = {}
	for p: ACEParam in d.params:
		var hint: String = str(p.hint)
		var default: String = str(p.default_value)
		if hint.begins_with("variable_reference"):
			params[p.id] = "v"                       # the declared scaffold var
		elif hint == "signal_reference:quoted":
			params[p.id] = "\"sig\""                 # &"sig" StringName form
		elif hint.begins_with("signal_reference"):
			params[p.id] = "sig"                     # the declared scaffold signal
		elif d.codegen_template.contains("{%s.}" % p.id) or d.codegen_template.contains("{, %s}" % p.id):
			params[p.id] = default.strip_edges()     # optional {id.} prefix / {, id} arg - default or "" both drop cleanly
		elif not default.strip_edges().is_empty():
			params[p.id] = default                   # concrete default - used verbatim (self, KEY_SPACE, "enemies", a member name, …)
		else:
			var typed: String = _value_for_type(str(p.type_name))
			if not typed.is_empty():
				params[p.id] = typed                 # synthesize a value of the declared type
			elif hint == "expression":
				params[p.id] = "0"
			else:
				return {"skip": true, "reason": "bare placeholder for '%s'" % p.id}
	params["uid"] = "0"                              # per-row unique id the compiler injects
	return {"params": params}


## Wraps the substituted template in its host class so host methods/properties resolve. Scaffold
## members stand in for the run context a real sheet provides: an untyped `v` for a sheet variable
## of any type, `item` for a For-Each iterator, `event` for an input event, `delta` for the
## per-frame delta, `sig` for a signal. They are untyped so any member access parses.
static func _wrap(d: ACEDescriptor, params: Dictionary) -> String:
	var line: String = ActionCodegen._apply_template(d.codegen_template, params)
	var host: String = d.node_type if not str(d.node_type).strip_edges().is_empty() else "Node"
	var body_lines: Array[String] = []
	match d.ace_type:
		ACEDescriptor.ACEType.CONDITION:
			body_lines = ["if (%s):" % line, "\tpass"]
		ACEDescriptor.ACEType.EXPRESSION:
			body_lines = ["var __e = (%s)" % line, "__sink(__e)"]
		_:
			for stmt: String in line.split("\n"):    # ACTION - may be multi-statement
				body_lines.append(stmt)
	var body: String = ""
	for l: String in body_lines:
		body += "\t" + l + "\n"
	# Stand-ins for the run context a real sheet provides: untyped `v` (a sheet variable of any
	# type), `item` (a For-Each iterator), `loop_index` (the named loop counter), `event` (an
	# input event), `text` (a string operand),
	# `delta`, `sig` (a signal). Each is declared ONLY when the host doesn't already expose that
	# member, so e.g. `var text` never collides with Label.text - the template then resolves
	# against the host's own member instead.
	var scaffold: String = ""
	for sv: String in ["v", "item", "loop_index", "event", "text", "data", "delta"]:
		if not _host_has_member(host, sv):
			scaffold += ("var %s := 0.0\n" % sv) if sv == "delta" else ("var %s\n" % sv)
	if not _host_has_member(host, "sig"):
		scaffold += "signal sig\n"
	scaffold += "func __sink(_a: Variant) -> void:\n\tpass\n"
	return "@tool\nextends %s\n%sfunc __t() -> void:\n%s" % [host, scaffold, body]


## True when the host class (incl. inherited members) already exposes a property or method with
## this name, so the scaffold can skip declaring a colliding stand-in (e.g. Label.text).
static func _host_has_member(host: String, member: String) -> bool:
	if not ClassDB.class_exists(host):
		return false
	if ClassDB.class_has_method(host, member):
		return true
	for prop: Dictionary in ClassDB.class_get_property_list(host):
		if str(prop.get("name", "")) == member:
			return true
	return false


## A compilable literal of the given declared type, or "" when there is no obvious stand-in.
static func _value_for_type(type_name: String) -> String:
	match type_name:
		"String", "StringName": return "\"x\""
		"int": return "0"
		"float": return "0.0"
		"bool": return "true"
		"Array": return "[]"
		"Dictionary": return "{}"
		"Vector2": return "Vector2(0, 0)"
		"Vector2i": return "Vector2i(0, 0)"
		"Vector3": return "Vector3(0, 0, 0)"
		"Color": return "Color.WHITE"
	return ""


static func _type_name(ace_type: int) -> String:
	match ace_type:
		ACEDescriptor.ACEType.CONDITION: return "CONDITION"
		ACEDescriptor.ACEType.EXPRESSION: return "EXPRESSION"
		ACEDescriptor.ACEType.ACTION: return "ACTION"
		ACEDescriptor.ACEType.TRIGGER: return "TRIGGER"
	return "?"


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] builtin_ace_compile_test: %s" % label)
		return true
	print("[FAIL] builtin_ace_compile_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
