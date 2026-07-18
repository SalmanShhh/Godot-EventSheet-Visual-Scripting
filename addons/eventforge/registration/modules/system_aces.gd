# EventForge module - System (event-sheet System parity)
#
# Time/engine, display, text expressions, comparisons, shader/date/platform info,
# stateful Every X Seconds and the multi-line Spawn Scene At.
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility
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
	# The beginner text-building hero: {name} placeholders, no printf codes to learn ("%d" never
	# appears). Compiles to String.format with a Dictionary - plain GDScript, zero runtime.
	descriptors.append(F.make_descriptor("Core", "TextFromPattern", "Text From Pattern", ACEDescriptor.ACEType.EXPRESSION, "{pattern}.format({values})", "", [F.make_param("pattern", "String", "\"{score} points\"", "Pattern", "Text with {name} slots, e.g. \"{player} scored {score}!\".", "expression"), F.make_param("values", "String", "{\"score\": 100}", "Values", "What fills the slots: {\"name\": value, ...} - e.g. {\"player\": player_name, \"score\": score}.", "expression")], "Text", "text from {pattern}")
		.described("Builds text by filling {name} slots in a pattern - \"{player} scored {score}!\" becomes \"Ada scored 300!\". The friendly way to mix words and values, no format codes.").featured())
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
	descriptors.append(F.make_descriptor("Core", "ToText", "To Text", ACEDescriptor.ACEType.EXPRESSION, "str({value})", "", [F.make_param("value", "String", "42", "Value", "Any value to turn into text.", "expression")], "Text", "str({value})")
		.described("Gives any value as text, for joining into messages and labels."))

	# Math expressions (the everyday number toolkit - degree-based trig included so angles read
	# the way sheet authors expect, no radians required)
	descriptors.append(F.make_descriptor("Core", "MathAbs", "Absolute Value", ACEDescriptor.ACEType.EXPRESSION, "absf({value})", "", [F.make_param("value", "String", "-5.0", "Value", "Number to strip the sign from.", "expression")], "Math & Random", "abs({value})")
		.described("Gives the number without its sign: abs(-5) is 5."))
	descriptors.append(F.make_descriptor("Core", "MathSqrt", "Square Root", ACEDescriptor.ACEType.EXPRESSION, "sqrt({value})", "", [F.make_param("value", "String", "9.0", "Value", "Number to take the root of.", "expression")], "Math & Random", "sqrt({value})")
		.described("Gives the square root of a number."))
	descriptors.append(F.make_descriptor("Core", "MathPow", "Power", ACEDescriptor.ACEType.EXPRESSION, "pow({base}, {exponent})", "", [F.make_param("base", "String", "2.0", "Base", "The number to raise.", "expression"), F.make_param("exponent", "String", "8.0", "Exponent", "The power to raise it to.", "expression")], "Math & Random", "{base} ^ {exponent}")
		.described("Gives a number raised to a power: 2 ^ 8 is 256."))
	descriptors.append(F.make_descriptor("Core", "MathExp", "Exponential", ACEDescriptor.ACEType.EXPRESSION, "exp({value})", "", [F.make_param("value", "String", "1.0", "Value", "The exponent for e.", "expression")], "Math & Random", "exp({value})")
		.described("Gives e raised to a power, the natural growth curve."))
	descriptors.append(F.make_descriptor("Core", "MathPi", "Pi", ACEDescriptor.ACEType.EXPRESSION, "PI", "", [], "Math & Random", "pi")
		.described("Gives the circle constant 3.14159…"))
	descriptors.append(F.make_descriptor("Core", "SinDegrees", "Sin (degrees)", ACEDescriptor.ACEType.EXPRESSION, "sin(deg_to_rad({degrees}))", "", [F.make_param("degrees", "String", "90.0", "Degrees", "Angle in degrees.", "expression")], "Math & Random", "sin({degrees})")
		.described("Gives the sine of an angle given in degrees - waves, bobbing, circular motion."))
	descriptors.append(F.make_descriptor("Core", "CosDegrees", "Cos (degrees)", ACEDescriptor.ACEType.EXPRESSION, "cos(deg_to_rad({degrees}))", "", [F.make_param("degrees", "String", "0.0", "Degrees", "Angle in degrees.", "expression")], "Math & Random", "cos({degrees})")
		.described("Gives the cosine of an angle given in degrees."))
	descriptors.append(F.make_descriptor("Core", "TanDegrees", "Tan (degrees)", ACEDescriptor.ACEType.EXPRESSION, "tan(deg_to_rad({degrees}))", "", [F.make_param("degrees", "String", "45.0", "Degrees", "Angle in degrees.", "expression")], "Math & Random", "tan({degrees})")
		.described("Gives the tangent of an angle given in degrees."))
	descriptors.append(F.make_descriptor("Core", "ToInteger", "To Integer", ACEDescriptor.ACEType.EXPRESSION, "int({value})", "", [F.make_param("value", "String", "\"42\"", "Value", "Text or number to convert.", "expression")], "Math & Random", "int({value})")
		.described("Gives the value as a whole number: int(\"42\") is 42, int(3.9) is 3."))
	descriptors.append(F.make_descriptor("Core", "ToDecimal", "To Decimal", ACEDescriptor.ACEType.EXPRESSION, "float({value})", "", [F.make_param("value", "String", "\"3.5\"", "Value", "Text or number to convert.", "expression")], "Math & Random", "float({value})")
		.described("Gives the value as a decimal number: float(\"3.5\") is 3.5."))

	# System actions (engine/frame control + the screenshot verb)
	descriptors.append(F.make_descriptor("Core", "TakeScreenshot", "Take Screenshot", ACEDescriptor.ACEType.ACTION, "get_viewport().get_texture().get_image().save_png({path})", "", [F.make_param("path", "String", "\"user://screenshot.png\"", "Path", "Where to save the PNG (user:// is the writable folder).", "expression")], "General Actions", "Take screenshot to {path}")
		.described("Saves what's on screen right now as a PNG file."))
	descriptors.append(F.make_descriptor("Core", "SetMaxFps", "Set Max FPS", ACEDescriptor.ACEType.ACTION, "Engine.max_fps = int({fps})", "", [F.make_param("fps", "String", "60", "FPS", "Frame cap (0 = uncapped).", "expression")], "Time", "Set max fps to {fps}")
		.described("Caps how many frames per second the game renders - save battery or steady the pace."))
	descriptors.append(F.make_descriptor("Core", "SetPhysicsRate", "Set Physics Rate", ACEDescriptor.ACEType.ACTION, "Engine.physics_ticks_per_second = int({fps})", "", [F.make_param("fps", "String", "60", "Ticks", "Physics updates per second.", "expression")], "Time", "Set physics rate to {fps}")
		.described("Changes how often physics steps per second (default 60)."))
	descriptors.append(F.make_descriptor("Core", "SetRandomSeed", "Set Random Seed", ACEDescriptor.ACEType.ACTION, "seed(int({seed}))", "", [F.make_param("seed", "String", "12345", "Seed", "Any integer - the same seed replays the same randomness.", "expression")], "Math & Random", "Set random seed to {seed}")
		.described("Pins the global randomness so a run replays identically - daily challenges, replays, tests."))

	# System conditions (angle tests, value-type tests, fullscreen state)
	descriptors.append(F.make_descriptor("Core", "IsWithinAngle", "Is Within Angle", ACEDescriptor.ACEType.CONDITION, "absf(rad_to_deg(angle_difference(deg_to_rad({angle}), deg_to_rad({target})))) <= {within}", "", [F.make_param("angle", "String", "0.0", "Angle", "The angle to test (degrees).", "expression"), F.make_param("within", "String", "10.0", "Within", "Allowed difference in degrees.", "expression"), F.make_param("target", "String", "90.0", "Of Angle", "The angle to compare against (degrees).", "expression")], "Math & Random", "{angle} is within {within} of {target}")
		.described("True when two angles are close, taking wrap-around into account (350 is within 20 of 10)."))
	descriptors.append(F.make_descriptor("Core", "IsClockwiseFrom", "Is Clockwise From", ACEDescriptor.ACEType.CONDITION, "angle_difference(deg_to_rad({from}), deg_to_rad({angle})) >= 0.0", "", [F.make_param("angle", "String", "45.0", "Angle", "The angle to test (degrees).", "expression"), F.make_param("from", "String", "0.0", "From", "The reference angle (degrees).", "expression")], "Math & Random", "{angle} is clockwise from {from}")
		.described("True when the shortest turn from the reference angle to this one is clockwise (in 2D screen space, where +Y points down)."))
	descriptors.append(F.make_descriptor("Core", "ValueIsNumber", "Value Is A Number", ACEDescriptor.ACEType.CONDITION, "(typeof({value}) == TYPE_FLOAT or typeof({value}) == TYPE_INT)", "", [F.make_param("value", "String", "0", "Value", "The value to type-test.", "expression")], "Math & Random", "{value} is a number")
		.described("True when the value holds a number - guard untyped variables and loaded JSON before math."))
	descriptors.append(F.make_descriptor("Core", "ValueIsText", "Value Is Text", ACEDescriptor.ACEType.CONDITION, "typeof({value}) == TYPE_STRING", "", [F.make_param("value", "String", "\"text\"", "Value", "The value to type-test.", "expression")], "Text", "{value} is text")
		.described("True when the value holds text - guard untyped variables and loaded JSON before string work."))
	descriptors.append(F.make_descriptor("Core", "IsNaNValue", "Is NaN", ACEDescriptor.ACEType.CONDITION, "is_nan({value})", "", [F.make_param("value", "String", "0.0", "Value", "The number to test.", "expression")], "Math & Random", "{value} is NaN")
		.described("True when a calculation broke and produced not-a-number (like dividing zero by zero)."))
	descriptors.append(F.make_descriptor("Core", "IsFullscreen", "Is Fullscreen", ACEDescriptor.ACEType.CONDITION, "(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)", "", [], "Display", "is fullscreen")
		.described("True while the game window is in fullscreen mode - pair with Set Fullscreen Mode for a toggle."))

	# Shader params (event-sheet effects -> Godot materials), date & time, platform info
	descriptors.append(F.make_descriptor("Core", "SetShaderParameter", "Set Shader Parameter", ACEDescriptor.ACEType.ACTION, "material.set_shader_parameter(&{param}, {value})", "", [F.make_param("param", "String", "\"strength\"", "Parameter", "Shader uniform name."), F.make_param("value", "String", "1.0", "Value", "Value expression.", "expression")], "General Actions", "Set shader {param} to {value}", "CanvasItem")
		.described("Feeds a value into a shader uniform to drive a visual effect at runtime."))
	descriptors.append(F.make_descriptor("Core", "GetDatetimeString", "Date & Time Text", ACEDescriptor.ACEType.EXPRESSION, "Time.get_datetime_string_from_system()", "", [], "Time", "datetime string")
		.described("Gives the system's current date and time as readable text."))
	descriptors.append(F.make_descriptor("Core", "GetUnixTime", "Unix Time", ACEDescriptor.ACEType.EXPRESSION, "Time.get_unix_time_from_system()", "", [], "Time", "unix time")
		.described("Gives the current Unix timestamp in seconds, useful for saving real-world time."))
	descriptors.append(F.make_descriptor("Core", "GetOSName", "OS Name", ACEDescriptor.ACEType.EXPRESSION, "OS.get_name()", "", [], "Platform", "os name")
		.described("Gives the name of the operating system the game is running on."))
	# Feature tags upgraded from a fixed 8-entry dropdown to an editable suggest combo: the
	# full curated tag set is one pick away, and a CUSTOM tag (export presets can define
	# any) is typeable - same ace_id, same template, same quoted-value shape, so every
	# existing sheet compiles and lifts unchanged.
	descriptors.append(F.make_descriptor("Core", "HasOSFeature", "Platform Has Feature", ACEDescriptor.ACEType.CONDITION, "OS.has_feature({feature})", "", [F.make_param("feature", "String", "\"mobile\"", "Feature", "Feature tag to test - pick a common one or type a custom tag from your export preset.", "", [], [
		"\"mobile\"", "\"pc\"", "\"web\"", "\"android\"", "\"ios\"", "\"windows\"", "\"linux\"", "\"macos\"",
		"\"editor\"", "\"debug\"", "\"release\"", "\"template\"", "\"template_debug\"", "\"template_release\"",
		"\"movie\"", "\"threads\"", "\"touchscreen\"", "\"etc2\"", "\"s3tc\""
	])], "Platform", "platform has {feature}")
		.described("True when the current platform supports the given feature tag - mobile, web, editor, debug/release, a specific OS, or any custom tag your export preset defines."))
	# Stateful conditions (the Every X seconds pattern): each applied instance owns a member;
	# the prelude accumulates frame time (get_process_delta_time, defined on any Node) before the
	# if, on_true rebases inside it. Compiles under any trigger; best used under a per-frame one.
	descriptors.append(F.make_descriptor("Core", "EveryXSeconds", "Every X Seconds", ACEDescriptor.ACEType.CONDITION, "__every_{uid} >= maxf({seconds}, 0.001)", "", [F.make_param("seconds", "String", "1.0", "Seconds", "Interval between runs (needs a per-frame trigger).", "expression")], "Time", "Every {seconds} seconds")
		.described("True once each time the chosen number of seconds passes, for repeating timers.")
		.stateful("var __every_{uid}: float = 0.0", "__every_{uid} += get_process_delta_time()", "__every_{uid} = fmod(__every_{uid}, maxf({seconds}, 0.001))"))
	# Trigger Once: run the event only on the FIRST tick of each stretch where the row's OTHER conditions
	# hold, re-arming once they go false again. .evaluated_last() HOISTS the term to the end of the emitted
	# `and` chain no matter which condition cell it sits in, so short-circuiting guarantees it is reached
	# exactly when everything else is true - which makes "was I reached on the previous tick?" exactly the
	# question "were the other conditions already true last tick?". The prelude ages a per-instance tick
	# counter every tick; the helper reads it and zeroes it the moment the term is reached, so a gap wider
	# than one tick is the rising edge. On its own (no other conditions) it fires exactly once.
	descriptors.append(F.make_descriptor("Core", "TriggerOnce", "Trigger Once", ACEDescriptor.ACEType.CONDITION, "__trigger_once_{uid}()", "", [], "Run Context", "Trigger once while true")
		.described("True only on the first tick each time the event's other conditions become true, and again after they have gone false. Works in any condition slot.")
		.stateful("var __once_{uid}: int = 1\n\nfunc __trigger_once_{uid}() -> bool:\n\tvar ticks_since_last: int = __once_{uid}\n\t__once_{uid} = 0\n\treturn ticks_since_last > 1", "__once_{uid} += 1")
		.evaluated_last())
	# Once At A Time (single-flight, the async-events re-entry gate): a busy latch set on entry
	# and cleared by the on_exit hook AFTER the whole body - in a coroutine body that reset runs
	# when the last await completes, so a per-frame trigger with a Wait can't stack overlapping
	# runs. The answer GDevelop's async events leave to "be careful".
	descriptors.append(F.make_descriptor("Core", "SingleFlight", "Once At A Time", ACEDescriptor.ACEType.CONDITION, "not __busy_{uid}", "", [], "Run Context", "Once at a time (skip while still running)")
		.described("Skips the event while a previous run is still going. A run that awaits (Wait, Wait For Signal) counts as still going until it finishes - so a per-frame event with a Wait runs one copy at a time instead of stacking a new one every frame.")
		.stateful("var __busy_{uid}: bool = false", "", "__busy_{uid} = true", "__busy_{uid} = false")
		.evaluated_last())
	# Multi-statement template: spawns AND positions (locals get a per-instance uid).
	descriptors.append(F.make_descriptor("Core", "SpawnSceneAt", "Spawn Scene At", ACEDescriptor.ACEType.ACTION, "var __spawn_{uid} = load({path}).instantiate()\n__spawn_{uid}.position = {position}\nadd_child(__spawn_{uid})", "", [F.make_param("path", "String", "\"res://enemy.tscn\"", "Scene", "Scene file to instance.", "scene_path"), F.make_param("position", "String", "Vector2(0, 0)", "Position", "Spawn position.", "expression")], "Scene", "Spawn {path} at {position}")
		.described("Loads a scene and drops a copy into the world at a position."))
	# Spawn + position + rotation + an optional group tag in one row (replaces a raw load/instantiate block).
	descriptors.append(F.make_descriptor("Core", "SpawnSceneFull", "Spawn Scene (Full)", ACEDescriptor.ACEType.ACTION, "var __spawn_{uid} = load({path}).instantiate()\n__spawn_{uid}.position = {position}\n__spawn_{uid}.rotation_degrees = {rotation}\nadd_child(__spawn_{uid})\nif {group} != \"\": __spawn_{uid}.add_to_group({group})", "", [F.make_param("path", "String", "\"res://enemy.tscn\"", "Scene", "Scene file to instance.", "scene_path"), F.make_param("position", "String", "Vector2(0, 0)", "Position", "Spawn position.", "expression"), F.make_param("rotation", "String", "0.0", "Rotation", "Rotation in degrees.", "expression"), F.make_param("group", "String", "\"\"", "Group", "Optional group to add the spawned node to (blank = none).", "group_reference")], "Scene", "Spawn {path} (rot {rotation}, group {group})")
		.described("Spawns a scene copy with position, rotation and an optional group in one step."))
	# Generic comparisons (event-sheet System: compare two values / is between values)
	descriptors.append(F.make_descriptor("Core", "CompareValues", "Compare Values", ACEDescriptor.ACEType.CONDITION, "{a} {op} {b}", "", [F.make_param("a", "String", "0", "First", "Left value.", "expression"), F.make_param("op", "String", "==", "Operator", "Comparison.", "", F.COMPARISON_OPERATORS), F.make_param("b", "String", "0", "Second", "Right value.", "expression")], "General Conditions", "{a} {op} {b}")
		.described("True when two values match your chosen comparison, like equal, greater or less than."))
	descriptors.append(F.make_descriptor("Core", "IsBetween", "Is Between Values", ACEDescriptor.ACEType.CONDITION, "({min} <= {value} and {value} <= {max})", "", [F.make_param("value", "String", "0", "Value", "Value to test.", "expression"), F.make_param("min", "String", "0", "Min", "Lower bound (inclusive).", "expression"), F.make_param("max", "String", "10", "Max", "Upper bound (inclusive).", "expression")], "General Conditions", "{value} is between {min} and {max}")
		.described("True when a value falls within a low and high range, bounds included."))
	# Generic boolean escape hatch (the code-free fallback): use any GDScript that returns a bool as a
	# condition - e.g. a behavior method like $Player/WeaponKit.can_fire() - without dropping the whole
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

	# Shader materials (assign / swap / clear / read uniforms - completes the one-uniform
	# SetShaderParameter above into a usable visual-effects surface).
	descriptors.append(F.make_descriptor("Core", "SetShaderMaterial", "Set Material", ACEDescriptor.ACEType.ACTION, "material = {material}", "", [F.make_param("material", "String", "null", "Material", "ShaderMaterial / CanvasItemMaterial resource - e.g. preload(\"res://your_material.tres\") once that file exists. Defaults to null (no material).", "expression")], "Rendering", "Set material to {material}", "CanvasItem")
		.described("Assigns a shader or canvas material to this node to change how it draws."))
	descriptors.append(F.make_descriptor("Core", "ClearMaterial", "Clear Material", ACEDescriptor.ACEType.ACTION, "material = null", "", [], "Rendering", "Clear material", "CanvasItem")
		.described("Removes any material from this node, returning it to default drawing."))
	descriptors.append(F.make_descriptor("Core", "GetShaderParameter", "Shader Parameter", ACEDescriptor.ACEType.EXPRESSION, "material.get_shader_parameter(&{param})", "", [F.make_param("param", "String", "\"strength\"", "Parameter", "Shader uniform name.")], "Rendering", "shader param {param}", "CanvasItem")
		.described("Gives the current value of a named shader uniform on this node."))

	return descriptors
