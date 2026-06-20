# EventForge module — Project utility vocabulary (the everyday non-gameplay glue).
#
# The broad project chores most games need but that don't belong to a specific node: persisting
# settings to a config file, querying / driving the window & mouse, reading performance monitors,
# formatting time, and the clipboard. Each compiles to the exact native one-liner (or the small
# multi-statement block) you'd hand-write, so project plumbing stays a code-free editable row.
# Grouped under Utility: Settings / Window / Debug / Time for discoverability.
@tool
extends RefCounted
class_name EventForgeUtilityACEs

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Settings: a ConfigFile in user:// (the standard persistent-settings store) ──
	# Multi-statement templates bake a per-row {uid} local so two in one event don't collide.
	descriptors.append(F.make_descriptor("Core", "SaveSetting", "Save Setting", ACEDescriptor.ACEType.ACTION, "var __cfg_{uid} = ConfigFile.new()\n__cfg_{uid}.load({path})\n__cfg_{uid}.set_value({section}, {key}, {value})\n__cfg_{uid}.save({path})", "", [F.make_param("path", "String", "\"user://settings.cfg\"", "File", "Config file path (user:// persists across runs).", "expression"), F.make_param("section", "String", "\"audio\"", "Section", "Section name.", "expression"), F.make_param("key", "String", "\"volume\"", "Key", "Setting key.", "expression"), F.make_param("value", "String", "1.0", "Value", "Value to store (any type).", "expression")], "Utility: Settings", "save {section}/{key} = {value}"))
	descriptors.append(F.make_descriptor("Core", "LoadSettingInto", "Load Setting Into Variable", ACEDescriptor.ACEType.ACTION, "var __cfg_{uid} = ConfigFile.new()\n__cfg_{uid}.load({path})\n{var_name} = __cfg_{uid}.get_value({section}, {key}, {default})", "", [F.make_param("var_name", "String", "data", "Into Variable", "Variable receiving the loaded value.", "variable_reference"), F.make_param("path", "String", "\"user://settings.cfg\"", "File", "Config file path.", "expression"), F.make_param("section", "String", "\"audio\"", "Section", "Section name.", "expression"), F.make_param("key", "String", "\"volume\"", "Key", "Setting key.", "expression"), F.make_param("default", "String", "1.0", "Default", "Fallback when the key is missing.", "expression")], "Utility: Settings", "load {section}/{key} into {var_name}"))

	# ── Window / screen / mouse / clipboard ──
	descriptors.append(F.make_descriptor("Core", "SetWindowTitle", "Set Window Title", ACEDescriptor.ACEType.ACTION, "get_window().title = {title}", "", [F.make_param("title", "String", "\"My Game\"", "Title", "Window title bar text.", "expression")], "Utility: Window", "set window title to {title}"))
	descriptors.append(F.make_descriptor("Core", "GetWindowSize", "Window Size", ACEDescriptor.ACEType.EXPRESSION, "get_window().size", "", [], "Utility: Window", "window size"))
	descriptors.append(F.make_descriptor("Core", "GetScreenSize", "Screen Size", ACEDescriptor.ACEType.EXPRESSION, "DisplayServer.screen_get_size()", "", [], "Utility: Window", "screen size"))
	# (Set Mouse Mode lives in device_aces under "Mouse" — not duplicated here.)
	descriptors.append(F.make_descriptor("Core", "SetClipboard", "Set Clipboard Text", ACEDescriptor.ACEType.ACTION, "DisplayServer.clipboard_set({text})", "", [F.make_param("text", "String", "\"\"", "Text", "Text to copy to the OS clipboard.", "expression")], "Utility: Window", "copy {text} to clipboard"))
	descriptors.append(F.make_descriptor("Core", "GetClipboard", "Clipboard Text", ACEDescriptor.ACEType.EXPRESSION, "DisplayServer.clipboard_get()", "", [], "Utility: Window", "clipboard text"))

	# ── Debug / profiling (read live engine performance monitors) ──
	descriptors.append(F.make_descriptor("Core", "GetPerfMonitor", "Performance Monitor", ACEDescriptor.ACEType.EXPRESSION, "Performance.get_monitor({monitor})", "", [F.make_param("monitor", "String", "Performance.TIME_FPS", "Monitor", "Which engine monitor to read.", "", ["Performance.TIME_FPS", "Performance.TIME_PROCESS", "Performance.TIME_PHYSICS_PROCESS", "Performance.OBJECT_COUNT", "Performance.OBJECT_NODE_COUNT", "Performance.RENDER_TOTAL_OBJECTS_IN_FRAME", "Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME", "Performance.PHYSICS_2D_ACTIVE_OBJECTS"])], "Utility: Debug", "monitor {monitor}"))
	descriptors.append(F.make_descriptor("Core", "GetStaticMemory", "Static Memory (bytes)", ACEDescriptor.ACEType.EXPRESSION, "OS.get_static_memory_usage()", "", [], "Utility: Debug", "static memory"))

	# ── Time formatting (turn seconds into clock text; read the system clock) ──
	descriptors.append(F.make_descriptor("Core", "FormatTime", "Format Time (mm:ss)", ACEDescriptor.ACEType.EXPRESSION, "(\"%02d:%02d\" % [int({seconds}) / 60, int({seconds}) % 60])", "", [F.make_param("seconds", "String", "0.0", "Seconds", "Total seconds to format.", "expression")], "Utility: Time", "format {seconds} as mm:ss"))
	descriptors.append(F.make_descriptor("Core", "GetSystemTime", "System Time String", ACEDescriptor.ACEType.EXPRESSION, "Time.get_time_string_from_system()", "", [], "Utility: Time", "system time string"))
	descriptors.append(F.make_descriptor("Core", "GetSystemDate", "System Date String", ACEDescriptor.ACEType.EXPRESSION, "Time.get_date_string_from_system()", "", [], "Utility: Time", "system date string"))

	# ── Nodes ──
	descriptors.append(F.make_descriptor("Core", "ReparentNode", "Reparent To", ACEDescriptor.ACEType.ACTION, "reparent({new_parent})", "", [F.make_param("new_parent", "String", "get_tree().current_scene", "New Parent", "Node to become the new parent (keeps global transform).", "expression")], "Utility: Nodes", "reparent to {new_parent}"))

	return descriptors
