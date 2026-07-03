# EventForge module — System (event-sheet System parity)
#
# Time/engine, display, text expressions, comparisons, shader/date/platform info,
# stateful Every X Seconds and the multi-line Spawn Scene At.
# Module contract: see ace_factory.gd — ace_ids/templates are API (compatibility
# covenant); this file only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeSystemACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Event-sheet System coverage: time/engine, display, text expressions, comparisons ──
	descriptors.append(F.make_descriptor("Core", "SetTimeScale", "Set Time Scale", ACEDescriptor.ACEType.ACTION, "Engine.time_scale = {scale}", "", [F.make_param("scale", "String", "1.0", "Scale", "1 = normal, 0.5 = slow motion, 0 = paused physics/process.", "expression")], "Time", "Set time scale to {scale}")
		.described("Speeds up or slows the whole game; use for slow-motion or pausing."))
	descriptors.append(F.make_descriptor("Core", "GetTimeScale", "Time Scale", ACEDescriptor.ACEType.EXPRESSION, "Engine.time_scale", "", [], "Time", "time scale")
		.described("Gives the current game speed (1 = normal, below 1 = slow motion)."))
	descriptors.append(F.make_descriptor("Core", "GetGameTime", "Game Time", ACEDescriptor.ACEType.EXPRESSION, "(Time.get_ticks_msec() / 1000.0)", "", [], "Time", "game time (seconds)")
		.described("Gives seconds elapsed since the game started, handy for timers."))
	descriptors.append(F.make_descriptor("Core", "GetFps", "FPS", ACEDescriptor.ACEType.EXPRESSION, "Engine.get_frames_per_second()", "", [], "Time", "fps")
		.described("Gives the current frames per second, useful for performance checks."))
	descriptors.append(F.make_descriptor("Core", "GetFrameCount", "Frame Count", ACEDescriptor.ACEType.EXPRESSION, "Engine.get_process_frames()", "", [], "Time", "frame count")
		.described("Gives how many frames have run since startup."))
	descriptors.append(F.make_descriptor("Core", "SetFullscreen", "Set Fullscreen Mode", ACEDescriptor.ACEType.ACTION, "DisplayServer.window_set_mode({mode})", "", [F.make_param("mode", "String", "DisplayServer.WINDOW_MODE_FULLSCREEN", "Mode", "Window mode.", "", ["DisplayServer.WINDOW_MODE_FULLSCREEN", "DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN", "DisplayServer.WINDOW_MODE_WINDOWED", "DisplayServer.WINDOW_MODE_MAXIMIZED"])], "Display", "Set window mode to {mode}")
		.described("Switches the game window between windowed, fullscreen and other display modes."))
	descriptors.append(F.make_descriptor("Core", "SetWindowSize", "Set Window Size", ACEDescriptor.ACEType.ACTION, "DisplayServer.window_set_size({size})", "", [F.make_param("size", "String", "Vector2i(1280, 720)", "Size", "Window size in pixels.", "expression")], "Display", "Set window size to {size}")
		.described("Resizes the game window to a chosen pixel width and height."))
	descriptors.append(F.make_descriptor("Core", "GetWindowWidth", "Window Width", ACEDescriptor.ACEType.EXPRESSION, "DisplayServer.window_get_size().x", "", [], "Display", "window width")
		.described("Gives the current window width in pixels."))
	descriptors.append(F.make_descriptor("Core", "GetWindowHeight", "Window Height", ACEDescriptor.ACEType.EXPRESSION, "DisplayServer.window_get_size().y", "", [], "Display", "window height")
		.described("Gives the current window height in pixels."))
	# Text (event-sheet System string expressions -> direct String methods)
	descriptors.append(F.make_descriptor("Core", "TextTokenAt", "Token At", ACEDescriptor.ACEType.EXPRESSION, "{text}.get_slice({separator}, {index})", "", [F.make_param("text", "String", "text", "Text", "Source string.", "expression"), F.make_param("separator", "String", "\",\"", "Separator", "Token separator.", "expression"), F.make_param("index", "String", "0", "Index", "Token index.", "expression")], "Text", "tokenat({text}, {index})")
		.described("Splits text by a separator and gives the chosen piece, like a CSV column."))
	descriptors.append(F.make_descriptor("Core", "TextTokenCount", "Token Count", ACEDescriptor.ACEType.EXPRESSION, "{text}.get_slice_count({separator})", "", [F.make_param("text", "String", "text", "Text", "Source string.", "expression"), F.make_param("separator", "String", "\",\"", "Separator", "Token separator.", "expression")], "Text", "tokencount({text})")
		.described("Gives how many pieces text breaks into when split by a separator."))
	descriptors.append(F.make_descriptor("Core", "TextFind", "Find In Text", ACEDescriptor.ACEType.EXPRESSION, "{text}.find({needle})", "", [F.make_param("text", "String", "text", "Text", "Source string.", "expression"), F.make_param("needle", "String", "\"a\"", "Find", "Substring to find (-1 when missing).", "expression")], "Text", "find({needle})")
		.described("Gives where a substring first appears in text, or -1 if it's missing."))
	descriptors.append(F.make_descriptor("Core", "TextLeft", "Left", ACEDescriptor.ACEType.EXPRESSION, "{text}.left({count})", "", [F.make_param("text", "String", "text", "Text", "Source string.", "expression"), F.make_param("count", "String", "3", "Count", "Characters from the left.", "expression")], "Text", "left({text}, {count})")
		.described("Gives the first few characters from the start of some text."))
	descriptors.append(F.make_descriptor("Core", "TextRight", "Right", ACEDescriptor.ACEType.EXPRESSION, "{text}.right({count})", "", [F.make_param("text", "String", "text", "Text", "Source string.", "expression"), F.make_param("count", "String", "3", "Count", "Characters from the right.", "expression")], "Text", "right({text}, {count})")
		.described("Gives the last few characters from the end of some text."))
	descriptors.append(F.make_descriptor("Core", "TextMid", "Mid", ACEDescriptor.ACEType.EXPRESSION, "{text}.substr({from}, {count})", "", [F.make_param("text", "String", "text", "Text", "Source string.", "expression"), F.make_param("from", "String", "0", "From", "Start index.", "expression"), F.make_param("count", "String", "3", "Count", "Length.", "expression")], "Text", "mid({text}, {from}, {count})")
		.described("Gives a chunk of text starting at a position for a set length."))
	descriptors.append(F.make_descriptor("Core", "TextUpper", "Uppercase", ACEDescriptor.ACEType.EXPRESSION, "{text}.to_upper()", "", [F.make_param("text", "String", "text", "Text", "Source string.", "expression")], "Text", "uppercase({text})")
		.described("Gives the text converted to all uppercase letters."))
	descriptors.append(F.make_descriptor("Core", "TextLower", "Lowercase", ACEDescriptor.ACEType.EXPRESSION, "{text}.to_lower()", "", [F.make_param("text", "String", "text", "Text", "Source string.", "expression")], "Text", "lowercase({text})")
		.described("Gives the text converted to all lowercase letters."))
	descriptors.append(F.make_descriptor("Core", "TextLength", "Text Length", ACEDescriptor.ACEType.EXPRESSION, "{text}.length()", "", [F.make_param("text", "String", "text", "Text", "Source string.", "expression")], "Text", "len({text})")
		.described("Gives how many characters are in some text."))
	descriptors.append(F.make_descriptor("Core", "TextReplace", "Replace In Text", ACEDescriptor.ACEType.EXPRESSION, "{text}.replace({what}, {with})", "", [F.make_param("text", "String", "text", "Text", "Source string.", "expression"), F.make_param("what", "String", "\"a\"", "Find", "Substring to replace.", "expression"), F.make_param("with", "String", "\"b\"", "With", "Replacement.", "expression")], "Text", "replace({text})")
		.described("Gives the text with every match of one substring swapped for another."))
	descriptors.append(F.make_descriptor("Core", "TextTrim", "Trim", ACEDescriptor.ACEType.EXPRESSION, "{text}.strip_edges()", "", [F.make_param("text", "String", "text", "Text", "Source string.", "expression")], "Text", "trim({text})")
		.described("Gives the text with leading and trailing whitespace removed."))
	descriptors.append(F.make_descriptor("Core", "TextZeroPad", "Zero Pad", ACEDescriptor.ACEType.EXPRESSION, "(\"%0*d\" % [{digits}, {value}])", "", [F.make_param("digits", "String", "3", "Digits", "Total width.", "expression"), F.make_param("value", "String", "7", "Value", "Integer to pad.", "expression")], "Text", "zeropad({value}, {digits})")
		.described("Gives a number padded with leading zeros to a fixed width, like 007."))

	# Shader params (event-sheet effects -> Godot materials), date & time, platform info
	descriptors.append(F.make_descriptor("Core", "SetShaderParameter", "Set Shader Parameter", ACEDescriptor.ACEType.ACTION, "material.set_shader_parameter(&{param}, {value})", "", [F.make_param("param", "String", "\"strength\"", "Parameter", "Shader uniform name."), F.make_param("value", "String", "1.0", "Value", "Value expression.", "expression")], "General Actions", "Set shader {param} to {value}", "CanvasItem")
		.described("Feeds a value into a shader uniform to drive a visual effect at runtime."))
	descriptors.append(F.make_descriptor("Core", "GetDatetimeString", "Date & Time Text", ACEDescriptor.ACEType.EXPRESSION, "Time.get_datetime_string_from_system()", "", [], "Time", "datetime string")
		.described("Gives the system's current date and time as readable text."))
	descriptors.append(F.make_descriptor("Core", "GetUnixTime", "Unix Time", ACEDescriptor.ACEType.EXPRESSION, "Time.get_unix_time_from_system()", "", [], "Time", "unix time")
		.described("Gives the current Unix timestamp in seconds, useful for saving real-world time."))
	descriptors.append(F.make_descriptor("Core", "GetOSName", "OS Name", ACEDescriptor.ACEType.EXPRESSION, "OS.get_name()", "", [], "Platform", "os name")
		.described("Gives the name of the operating system the game is running on."))
	descriptors.append(F.make_descriptor("Core", "HasOSFeature", "Platform Has Feature", ACEDescriptor.ACEType.CONDITION, "OS.has_feature({feature})", "", [F.make_param("feature", "String", "\"mobile\"", "Feature", "Feature tag to test.", "", ["\"mobile\"", "\"pc\"", "\"web\"", "\"android\"", "\"ios\"", "\"editor\"", "\"debug\"", "\"release\""])], "Platform", "platform has {feature}")
		.described("True when the current platform supports the given feature tag, like mobile or web."))
	# Stateful conditions (the Every X seconds pattern): each applied instance owns a member;
	# the prelude accumulates frame time (get_process_delta_time, defined on any Node) before the
	# if, on_true rebases inside it. Compiles under any trigger; best used under a per-frame one.
	var every_seconds: ACEDescriptor = F.make_descriptor("Core", "EveryXSeconds", "Every X Seconds", ACEDescriptor.ACEType.CONDITION, "__every_{uid} >= maxf({seconds}, 0.001)", "", [F.make_param("seconds", "String", "1.0", "Seconds", "Interval between runs (needs a per-frame trigger).", "expression")], "Time", "Every {seconds} seconds").described("True once each time the chosen number of seconds passes, for repeating timers.")
	every_seconds.member_template = "var __every_{uid}: float = 0.0"
	every_seconds.codegen_prelude = "__every_{uid} += get_process_delta_time()"
	every_seconds.codegen_on_true = "__every_{uid} = fmod(__every_{uid}, maxf({seconds}, 0.001))"
	descriptors.append(every_seconds)
	# Multi-statement template: spawns AND positions (locals get a per-instance uid).
	descriptors.append(F.make_descriptor("Core", "SpawnSceneAt", "Spawn Scene At", ACEDescriptor.ACEType.ACTION, "var __spawn_{uid} = load({path}).instantiate()\n__spawn_{uid}.position = {position}\nadd_child(__spawn_{uid})", "", [F.make_param("path", "String", "\"res://enemy.tscn\"", "Scene", "Scene file to instance.", "scene_path"), F.make_param("position", "String", "Vector2(0, 0)", "Position", "Spawn position.", "expression")], "Scene", "Spawn {path} at {position}")
		.described("Loads a scene and drops a copy into the world at a position."))
	# Spawn + position + rotation + an optional group tag in one row (replaces a raw load/instantiate block).
	descriptors.append(F.make_descriptor("Core", "SpawnSceneFull", "Spawn Scene (Full)", ACEDescriptor.ACEType.ACTION, "var __spawn_{uid} = load({path}).instantiate()\n__spawn_{uid}.position = {position}\n__spawn_{uid}.rotation_degrees = {rotation}\nadd_child(__spawn_{uid})\nif {group} != \"\": __spawn_{uid}.add_to_group({group})", "", [F.make_param("path", "String", "\"res://enemy.tscn\"", "Scene", "Scene file to instance.", "scene_path"), F.make_param("position", "String", "Vector2(0, 0)", "Position", "Spawn position.", "expression"), F.make_param("rotation", "String", "0.0", "Rotation", "Rotation in degrees.", "expression"), F.make_param("group", "String", "\"\"", "Group", "Optional group to add the spawned node to (blank = none).", "expression")], "Scene", "Spawn {path} (rot {rotation}, group {group})")
		.described("Spawns a scene copy with position, rotation and an optional group in one step."))
	# Generic comparisons (event-sheet System: compare two values / is between values)
	descriptors.append(F.make_descriptor("Core", "CompareValues", "Compare Values", ACEDescriptor.ACEType.CONDITION, "{a} {op} {b}", "", [F.make_param("a", "String", "0", "First", "Left value.", "expression"), F.make_param("op", "String", "==", "Operator", "Comparison.", "", F.COMPARISON_OPERATORS), F.make_param("b", "String", "0", "Second", "Right value.", "expression")], "General Conditions", "{a} {op} {b}")
		.described("True when two values match your chosen comparison, like equal, greater or less than."))
	descriptors.append(F.make_descriptor("Core", "IsBetween", "Is Between Values", ACEDescriptor.ACEType.CONDITION, "({min} <= {value} and {value} <= {max})", "", [F.make_param("value", "String", "0", "Value", "Value to test.", "expression"), F.make_param("min", "String", "0", "Min", "Lower bound (inclusive).", "expression"), F.make_param("max", "String", "10", "Max", "Upper bound (inclusive).", "expression")], "General Conditions", "{value} is between {min} and {max}")
		.described("True when a value falls within a low and high range, bounds included."))
	# Generic boolean escape hatch (the code-free fallback): use any GDScript that returns a bool as a
	# condition — e.g. a behavior method like $Player/WeaponKit.can_fire() — without dropping the whole
	# row to a raw GDScript block. Emitted verbatim (opaque param), so the expression is the user's to
	# get right; it inverts to `not (...)` for free. Prefer a named pack condition where one exists.
	descriptors.append(F.make_descriptor("Core", "ExpressionIsTrue", "Expression Is True", ACEDescriptor.ACEType.CONDITION, "{expr}", "", [F.make_param("expr", "String", "true", "Expression", "Any GDScript boolean expression, e.g. $Player/WeaponKit.can_fire() or health > 0.", "expression")], "General Conditions", "{expr}")
		.described("True when your custom GDScript expression evaluates to true; an escape hatch for advanced checks."))

	# Runtime group toggling (event-sheet Set Group Active): targets the opt-in "runtime
	# toggleable" flag members. The group param is the snake-cased group name.
	descriptors.append(F.make_descriptor("Core", "SetGroupActive", "Set Group Active", ACEDescriptor.ACEType.ACTION, "set(\"__group_\" + {group} + \"_active\", {active})", "", [F.make_param("group", "String", "\"combat\"", "Group", "Snake-cased group name (runtime-toggleable groups only).", "expression"), F.make_param("active", "String", "true", "Active", "true / false.", "", ["true", "false"])], "General Actions", "Set group {group} active: {active}")
		.described("Turns a runtime-toggleable group on or off to enable or disable its behaviour."))
	descriptors.append(F.make_descriptor("Core", "IsGroupActive", "Is Group Active", ACEDescriptor.ACEType.CONDITION, "bool(get(\"__group_\" + {group} + \"_active\"))", "", [F.make_param("group", "String", "\"combat\"", "Group", "Snake-cased group name.", "expression")], "General Conditions", "group {group} is active")
		.described("True when the named runtime group is currently switched on."))

	# Shader materials (assign / swap / clear / read uniforms — completes the one-uniform
	# SetShaderParameter above into a usable visual-effects surface).
	descriptors.append(F.make_descriptor("Core", "SetShaderMaterial", "Set Material", ACEDescriptor.ACEType.ACTION, "material = {material}", "", [F.make_param("material", "String", "null", "Material", "ShaderMaterial / CanvasItemMaterial resource — e.g. preload(\"res://your_material.tres\") once that file exists. Defaults to null (no material).", "expression")], "Rendering", "Set material to {material}", "CanvasItem")
		.described("Assigns a shader or canvas material to this node to change how it draws."))
	descriptors.append(F.make_descriptor("Core", "ClearMaterial", "Clear Material", ACEDescriptor.ACEType.ACTION, "material = null", "", [], "Rendering", "Clear material", "CanvasItem")
		.described("Removes any material from this node, returning it to default drawing."))
	descriptors.append(F.make_descriptor("Core", "GetShaderParameter", "Shader Parameter", ACEDescriptor.ACEType.EXPRESSION, "material.get_shader_parameter(&{param})", "", [F.make_param("param", "String", "\"strength\"", "Parameter", "Shader uniform name.")], "Rendering", "shader param {param}", "CanvasItem")
		.described("Gives the current value of a named shader uniform on this node."))

	return descriptors
