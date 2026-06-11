# EventForge module — System (C3 System parity)
#
# Time/engine, display, text expressions, comparisons, shader/date/platform info,
# stateful Every X Seconds and the multi-line Spawn Scene At.
# Module contract: see ace_factory.gd — ace_ids/templates are API (compatibility
# covenant); this file only changes where the descriptors are AUTHORED.
@tool
extends RefCounted
class_name EventForgeSystemACEs

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── C3 System coverage: time/engine, display, text expressions, comparisons ──
	descriptors.append(F.make_descriptor("Core", "SetTimeScale", "Set Time Scale", ACEDescriptor.ACEType.ACTION, "Engine.time_scale = {scale}", "", [F.make_param("scale", "String", "1.0", "Scale", "1 = normal, 0.5 = slow motion, 0 = paused physics/process.", "expression")], "Time", "Set time scale to {scale}"))
	descriptors.append(F.make_descriptor("Core", "GetTimeScale", "Time Scale", ACEDescriptor.ACEType.EXPRESSION, "Engine.time_scale", "", [], "Time", "time scale"))
	descriptors.append(F.make_descriptor("Core", "GetGameTime", "Game Time", ACEDescriptor.ACEType.EXPRESSION, "(Time.get_ticks_msec() / 1000.0)", "", [], "Time", "game time (seconds)"))
	descriptors.append(F.make_descriptor("Core", "GetFps", "FPS", ACEDescriptor.ACEType.EXPRESSION, "Engine.get_frames_per_second()", "", [], "Time", "fps"))
	descriptors.append(F.make_descriptor("Core", "GetFrameCount", "Frame Count", ACEDescriptor.ACEType.EXPRESSION, "Engine.get_process_frames()", "", [], "Time", "frame count"))
	descriptors.append(F.make_descriptor("Core", "SetFullscreen", "Set Fullscreen Mode", ACEDescriptor.ACEType.ACTION, "DisplayServer.window_set_mode({mode})", "", [F.make_param("mode", "String", "DisplayServer.WINDOW_MODE_FULLSCREEN", "Mode", "Window mode.", "", ["DisplayServer.WINDOW_MODE_FULLSCREEN", "DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN", "DisplayServer.WINDOW_MODE_WINDOWED", "DisplayServer.WINDOW_MODE_MAXIMIZED"])], "Display", "Set window mode to {mode}"))
	descriptors.append(F.make_descriptor("Core", "SetWindowSize", "Set Window Size", ACEDescriptor.ACEType.ACTION, "DisplayServer.window_set_size({size})", "", [F.make_param("size", "String", "Vector2i(1280, 720)", "Size", "Window size in pixels.", "expression")], "Display", "Set window size to {size}"))
	descriptors.append(F.make_descriptor("Core", "GetWindowWidth", "Window Width", ACEDescriptor.ACEType.EXPRESSION, "DisplayServer.window_get_size().x", "", [], "Display", "window width"))
	descriptors.append(F.make_descriptor("Core", "GetWindowHeight", "Window Height", ACEDescriptor.ACEType.EXPRESSION, "DisplayServer.window_get_size().y", "", [], "Display", "window height"))
	# Text (C3 System string expressions -> direct String methods)
	descriptors.append(F.make_descriptor("Core", "TextTokenAt", "Token At", ACEDescriptor.ACEType.EXPRESSION, "{text}.get_slice({separator}, {index})", "", [F.make_param("text", "String", "text", "Text", "Source string.", "expression"), F.make_param("separator", "String", "\",\"", "Separator", "Token separator.", "expression"), F.make_param("index", "String", "0", "Index", "Token index.", "expression")], "Text", "tokenat({text}, {index})"))
	descriptors.append(F.make_descriptor("Core", "TextTokenCount", "Token Count", ACEDescriptor.ACEType.EXPRESSION, "{text}.get_slice_count({separator})", "", [F.make_param("text", "String", "text", "Text", "Source string.", "expression"), F.make_param("separator", "String", "\",\"", "Separator", "Token separator.", "expression")], "Text", "tokencount({text})"))
	descriptors.append(F.make_descriptor("Core", "TextFind", "Find In Text", ACEDescriptor.ACEType.EXPRESSION, "{text}.find({needle})", "", [F.make_param("text", "String", "text", "Text", "Source string.", "expression"), F.make_param("needle", "String", "\"a\"", "Find", "Substring to find (-1 when missing).", "expression")], "Text", "find({needle})"))
	descriptors.append(F.make_descriptor("Core", "TextLeft", "Left", ACEDescriptor.ACEType.EXPRESSION, "{text}.left({count})", "", [F.make_param("text", "String", "text", "Text", "Source string.", "expression"), F.make_param("count", "String", "3", "Count", "Characters from the left.", "expression")], "Text", "left({text}, {count})"))
	descriptors.append(F.make_descriptor("Core", "TextRight", "Right", ACEDescriptor.ACEType.EXPRESSION, "{text}.right({count})", "", [F.make_param("text", "String", "text", "Text", "Source string.", "expression"), F.make_param("count", "String", "3", "Count", "Characters from the right.", "expression")], "Text", "right({text}, {count})"))
	descriptors.append(F.make_descriptor("Core", "TextMid", "Mid", ACEDescriptor.ACEType.EXPRESSION, "{text}.substr({from}, {count})", "", [F.make_param("text", "String", "text", "Text", "Source string.", "expression"), F.make_param("from", "String", "0", "From", "Start index.", "expression"), F.make_param("count", "String", "3", "Count", "Length.", "expression")], "Text", "mid({text}, {from}, {count})"))
	descriptors.append(F.make_descriptor("Core", "TextUpper", "Uppercase", ACEDescriptor.ACEType.EXPRESSION, "{text}.to_upper()", "", [F.make_param("text", "String", "text", "Text", "Source string.", "expression")], "Text", "uppercase({text})"))
	descriptors.append(F.make_descriptor("Core", "TextLower", "Lowercase", ACEDescriptor.ACEType.EXPRESSION, "{text}.to_lower()", "", [F.make_param("text", "String", "text", "Text", "Source string.", "expression")], "Text", "lowercase({text})"))
	descriptors.append(F.make_descriptor("Core", "TextLength", "Text Length", ACEDescriptor.ACEType.EXPRESSION, "{text}.length()", "", [F.make_param("text", "String", "text", "Text", "Source string.", "expression")], "Text", "len({text})"))
	descriptors.append(F.make_descriptor("Core", "TextReplace", "Replace In Text", ACEDescriptor.ACEType.EXPRESSION, "{text}.replace({what}, {with})", "", [F.make_param("text", "String", "text", "Text", "Source string.", "expression"), F.make_param("what", "String", "\"a\"", "Find", "Substring to replace.", "expression"), F.make_param("with", "String", "\"b\"", "With", "Replacement.", "expression")], "Text", "replace({text})"))
	descriptors.append(F.make_descriptor("Core", "TextTrim", "Trim", ACEDescriptor.ACEType.EXPRESSION, "{text}.strip_edges()", "", [F.make_param("text", "String", "text", "Text", "Source string.", "expression")], "Text", "trim({text})"))
	descriptors.append(F.make_descriptor("Core", "TextZeroPad", "Zero Pad", ACEDescriptor.ACEType.EXPRESSION, "(\"%0*d\" % [{digits}, {value}])", "", [F.make_param("digits", "String", "3", "Digits", "Total width.", "expression"), F.make_param("value", "String", "7", "Value", "Integer to pad.", "expression")], "Text", "zeropad({value}, {digits})"))

	# Shader params (C3 effects -> Godot materials), date & time, platform info
	descriptors.append(F.make_descriptor("Core", "SetShaderParameter", "Set Shader Parameter", ACEDescriptor.ACEType.ACTION, "material.set_shader_parameter(&{param}, {value})", "", [F.make_param("param", "String", "\"strength\"", "Parameter", "Shader uniform name."), F.make_param("value", "String", "1.0", "Value", "Value expression.", "expression")], "General Actions", "Set shader {param} to {value}", "CanvasItem"))
	descriptors.append(F.make_descriptor("Core", "GetDatetimeString", "Date & Time Text", ACEDescriptor.ACEType.EXPRESSION, "Time.get_datetime_string_from_system()", "", [], "Time", "datetime string"))
	descriptors.append(F.make_descriptor("Core", "GetUnixTime", "Unix Time", ACEDescriptor.ACEType.EXPRESSION, "Time.get_unix_time_from_system()", "", [], "Time", "unix time"))
	descriptors.append(F.make_descriptor("Core", "GetOSName", "OS Name", ACEDescriptor.ACEType.EXPRESSION, "OS.get_name()", "", [], "Platform", "os name"))
	descriptors.append(F.make_descriptor("Core", "HasOSFeature", "Platform Has Feature", ACEDescriptor.ACEType.CONDITION, "OS.has_feature({feature})", "", [F.make_param("feature", "String", "\"mobile\"", "Feature", "Feature tag to test.", "", ["\"mobile\"", "\"pc\"", "\"web\"", "\"android\"", "\"ios\"", "\"editor\"", "\"debug\"", "\"release\""])], "Platform", "platform has {feature}"))
	# Stateful conditions (C3's Every X seconds): each applied instance owns a member;
	# the prelude accumulates delta before the if, on_true rebases inside it. Only valid
	# in per-frame triggers (Every Frame / On Physics Process), where `delta` exists.
	var every_seconds: ACEDescriptor = F.make_descriptor("Core", "EveryXSeconds", "Every X Seconds", ACEDescriptor.ACEType.CONDITION, "__every_{uid} >= maxf({seconds}, 0.001)", "", [F.make_param("seconds", "String", "1.0", "Seconds", "Interval between runs (needs a per-frame trigger).", "expression")], "Time", "Every {seconds} seconds")
	every_seconds.member_template = "var __every_{uid}: float = 0.0"
	every_seconds.codegen_prelude = "__every_{uid} += delta"
	every_seconds.codegen_on_true = "__every_{uid} = fmod(__every_{uid}, maxf({seconds}, 0.001))"
	descriptors.append(every_seconds)
	# Multi-statement template: spawns AND positions (locals get a per-instance uid).
	descriptors.append(F.make_descriptor("Core", "SpawnSceneAt", "Spawn Scene At", ACEDescriptor.ACEType.ACTION, "var __spawn_{uid} = load({path}).instantiate()\n__spawn_{uid}.position = {position}\nadd_child(__spawn_{uid})", "", [F.make_param("path", "String", "\"res://enemy.tscn\"", "Scene", "Scene file to instance.", "expression"), F.make_param("position", "String", "Vector2(0, 0)", "Position", "Spawn position.", "expression")], "Scene", "Spawn {path} at {position}"))
	# Generic comparisons (C3 System: compare two values / is between values)
	descriptors.append(F.make_descriptor("Core", "CompareValues", "Compare Values", ACEDescriptor.ACEType.CONDITION, "{a} {op} {b}", "", [F.make_param("a", "String", "0", "First", "Left value.", "expression"), F.make_param("op", "String", "==", "Operator", "Comparison.", "", F.COMPARISON_OPERATORS), F.make_param("b", "String", "0", "Second", "Right value.", "expression")], "General Conditions", "{a} {op} {b}"))
	descriptors.append(F.make_descriptor("Core", "IsBetween", "Is Between Values", ACEDescriptor.ACEType.CONDITION, "({min} <= {value} and {value} <= {max})", "", [F.make_param("value", "String", "0", "Value", "Value to test.", "expression"), F.make_param("min", "String", "0", "Min", "Lower bound (inclusive).", "expression"), F.make_param("max", "String", "10", "Max", "Upper bound (inclusive).", "expression")], "General Conditions", "{value} is between {min} and {max}"))

	# Runtime group toggling (C3 Set Group Active): targets the opt-in "runtime
	# toggleable" flag members. The group param is the snake-cased group name.
	descriptors.append(F.make_descriptor("Core", "SetGroupActive", "Set Group Active", ACEDescriptor.ACEType.ACTION, "set(\"__group_\" + {group} + \"_active\", {active})", "", [F.make_param("group", "String", "\"combat\"", "Group", "Snake-cased group name (runtime-toggleable groups only).", "expression"), F.make_param("active", "String", "true", "Active", "true / false.", "", ["true", "false"])], "General Actions", "Set group {group} active: {active}"))
	descriptors.append(F.make_descriptor("Core", "IsGroupActive", "Is Group Active", ACEDescriptor.ACEType.CONDITION, "bool(get(\"__group_\" + {group} + \"_active\"))", "", [F.make_param("group", "String", "\"combat\"", "Group", "Snake-cased group name.", "expression")], "General Conditions", "group {group} is active"))

	return descriptors
