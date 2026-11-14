# Godot EventSheets - a published function of a named sheet, used from ANOTHER sheet, calls the node.
#
# A sheet that names its class and publishes a function writes a bare call into its compiled
# script's call line (`open_gate({speed})`): inside its own file that is a call on itself. When the
# script is shared so other sheets can use the function, the same bare call would compile in the
# OTHER sheet and call a function that sheet does not have. The picker reads the script, so the
# reading is where the call is aimed at the node (`$Gate`), as a behaviour pack's is. The emitted
# bytes of the sheet's own script do not change, so no shipped pack or showcase moves.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const T := "named_sheet_function_target_test"
const PATH := "user://named_sheet_target_probe.gd"


static func run() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.custom_class_name = "GateProbe"
	var open_gate: EventFunction = EventFunction.new()
	open_gate.function_name = "open_gate"
	open_gate.expose_as_ace = true
	var speed: ACEParam = ACEParam.new()
	speed.id = "speed"
	speed.type = TYPE_FLOAT
	speed.default_value = 2.0
	open_gate.params = [speed]
	var body: EventRow = EventRow.new()
	var leave: ACEAction = ACEAction.new()
	leave.provider_id = "Core"
	leave.ace_id = "ReturnEarly"
	body.actions.append(leave)
	open_gate.events = [body]
	sheet.functions = [open_gate]
	var compiled: String = str(EventSheetCompiler.compile(sheet, PATH).get("output", ""))

	# The sheet's own script keeps the bare call: it is the call on itself, and every file already
	# written this way must stay byte for byte as it is.
	ok = SUPPORT.check(T, "the script's own call line is still the bare call",
		compiled.contains("## @ace_codegen_template(\"open_gate({speed})\")"), true) and ok

	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(compiled)
	file.close()
	var script: GDScript = load(PATH)
	ok = SUPPORT.check(T, "the compiled script loads", script != null, true) and ok
	if script == null:
		return false
	var by_id: Dictionary = {}
	for definition: ACEDefinition in EventSheetACEGenerator.new().generate_from_script(script):
		by_id[str(definition.id)] = definition
	var published: ACEDefinition = by_id.get("method:open_gate", null)
	ok = SUPPORT.check(T, "the function is published", published != null, true) and ok
	if published != null:
		ok = SUPPORT.check(T, "another sheet calls it on the node, not on itself",
			str(published.metadata.get("codegen_template", "")), "{target}.open_gate({speed})") and ok
		var target_default: String = ""
		for entry: Variant in published.parameters:
			if str((entry as Dictionary).get("id", "")) == "target":
				target_default = str((entry as Dictionary).get("default_value", ""))
		ok = SUPPORT.check(T, "the node it aims at defaults to the sheet's class", target_default, "$GateProbe") and ok

	# A call the author qualified by hand is theirs: nothing is added to it.
	var qualified: String = compiled.replace("## @ace_codegen_template(\"open_gate({speed})\")",
		"## @ace_codegen_template(\"$Elsewhere.open_gate({speed})\")")
	var qualified_file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	qualified_file.store_string(qualified)
	qualified_file.close()
	var qualified_script: GDScript = ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	var qualified_definition: ACEDefinition = null
	for definition: ACEDefinition in EventSheetACEGenerator.new().generate_from_script(qualified_script):
		if str(definition.id) == "method:open_gate":
			qualified_definition = definition
	if qualified_definition != null:
		ok = SUPPORT.check(T, "a hand-qualified call keeps its own node",
			str(qualified_definition.metadata.get("codegen_template", "")), "{target}.open_gate({speed})") and ok
		var qualified_default: String = ""
		for entry: Variant in qualified_definition.parameters:
			if str((entry as Dictionary).get("id", "")) == "target":
				qualified_default = str((entry as Dictionary).get("default_value", ""))
		ok = SUPPORT.check(T, "and its default node", qualified_default, "$Elsewhere") and ok
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	return ok
