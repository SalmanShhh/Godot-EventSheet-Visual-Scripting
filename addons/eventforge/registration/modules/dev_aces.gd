# EventForge module - Developer helper vocabulary (the everyday dev tools).
#
# The small native operations a Godot dev reaches for constantly while building + debugging:
# console output, assertions, scene-tree groups, node metadata, and tree navigation. They compile
# to the exact one-liners you'd hand-write (print(...), add_to_group(...), set_meta(...),
# get_parent()), so picking one keeps logic as an editable row instead of a raw block - and means
# common dev chores never force a drop to GDScript. Grouped under Debug / Groups / Metadata / Nodes.
@tool
class_name EventForgeDevACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Debug: console output + assertions (the #1 thing you do while building) ──
	descriptors.append(F.make_descriptor("Core", "Print", "Print", ACEDescriptor.ACEType.ACTION, "print({value})", "", [F.make_param("value", "String", "\"hello\"", "Value", "Value/expression to print to the Output console.", "expression")], "Debug", "print {value}")
		.described("Prints a value to the Output console, useful for debugging what's happening."))
	descriptors.append(F.make_descriptor("Core", "PrintLabeled", "Print Labeled", ACEDescriptor.ACEType.ACTION, "print({label}, {value})", "", [F.make_param("label", "String", "\"value:\"", "Label", "Leading label string.", "expression"), F.make_param("value", "String", "0", "Value", "Value/expression to print after the label.", "expression")], "Debug", "print {label} {value}")
		.described("Prints a value preceded by a label so you can tell debug messages apart."))
	descriptors.append(F.make_descriptor("Core", "PrintRich", "Print Rich (BBCode)", ACEDescriptor.ACEType.ACTION, "print_rich({value})", "", [F.make_param("value", "String", "\"[b]done[/b]\"", "Value", "BBCode string (colors/bold) for the Output console. Select text and hit B / I / U / S to format it.", "bbcode_text")], "Debug", "print rich {value}")
		.described("Prints colored or bold text to the Output console using BBCode formatting."))
	descriptors.append(F.make_descriptor("Core", "PushWarning", "Push Warning", ACEDescriptor.ACEType.ACTION, "push_warning({message})", "", [F.make_param("message", "String", "\"check this\"", "Message", "Warning text (shows in the debugger).", "expression")], "Debug", "warn {message}")
		.described("Logs a warning message that appears in Godot's debugger panel."))
	descriptors.append(F.make_descriptor("Core", "PushError", "Push Error", ACEDescriptor.ACEType.ACTION, "push_error({message})", "", [F.make_param("message", "String", "\"bad state\"", "Message", "Error text (shows in the debugger).", "expression")], "Debug", "error {message}")
		.described("Logs an error message that appears in Godot's debugger panel."))
	descriptors.append(F.make_descriptor("Core", "Assert", "Assert", ACEDescriptor.ACEType.ACTION, "assert({condition}, {message})", "", [F.make_param("condition", "String", "true", "Condition", "Boolean that must hold (stripped from release builds).", "expression"), F.make_param("message", "String", "\"assertion failed\"", "Message", "Message if it fails.", "expression")], "Debug", "assert {condition}")
		.described("Crashes during testing if a condition isn't true, catching bugs early; removed from release."))
	descriptors.append(F.make_descriptor("Core", "PrintTree", "Print Scene Tree", ACEDescriptor.ACEType.ACTION, "print_tree_pretty()", "", [], "Debug", "print scene tree")
		.described("Prints the whole scene's node hierarchy to the output log for debugging."))
	# (Frame Count lives in system_aces.gd under "Time" - no duplicate "Core::GetFrameCount" here.)
	# A manual debugger pause as a pickable row (complements the F9 gutter breakpoints).
	descriptors.append(F.make_descriptor("Core", "Breakpoint", "Breakpoint (pause debugger)", ACEDescriptor.ACEType.ACTION, "breakpoint", "", [], "Debug", "breakpoint")
		.described("Pauses the game in the debugger right here so you can inspect things."))

	# ── Debug: value trails (the last N values of anything, kept and dumpable) ──
	# Every other live surface here shows the CURRENT frame; an intermittent bug lives in the two
	# seconds before the frame you are looking at. A trail is a named rolling history, stored the
	# same stateless way the cooldown family stores its deadlines: in node metadata, so Remember In
	# Trail in one event and Lowest In Trail in another (or in a different sheet on the same node)
	# agree with no wiring, no members and no {uid} slot. Every trail lives inside ONE metadata
	# dictionary rather than one metadata key per name, because a metadata key must be a valid
	# identifier and a trail called "player speed" is not - the name goes in the dictionary, where
	# it is free text. It records SILENTLY: nothing shows until a row logs it, writes it, or reads it.
	descriptors.append(F.make_descriptor("Core", "RememberInTrail", "Remember In Trail", ACEDescriptor.ACEType.ACTION, "var __trails_{uid}: Dictionary = get_meta(&\"__ef_trails\", {}) as Dictionary\nvar __trail_{uid}: Array = __trails_{uid}.get({trail}, []) as Array\n__trail_{uid}.append({value})\nif __trail_{uid}.size() > maxi(int({keep}), 1):\n\t__trail_{uid} = __trail_{uid}.slice(__trail_{uid}.size() - maxi(int({keep}), 1))\n__trails_{uid}[{trail}] = __trail_{uid}\nset_meta(&\"__ef_trails\", __trails_{uid})", "", [F.make_param("value", "String", "0", "Value", "The value to record this tick - a number, a vector, anything printable.", "expression"), F.make_param("trail", "String", "\"vy\"", "Trail", "Trail name - any label you also use in the trail expressions.", "expression"), F.make_param("keep", "String", "120", "Keep", "How many recent values to hold (older ones drop off the front).", "expression")], "Debug", "remember [b]{value}[/b] in trail [b]{trail}[/b], keep [b]{keep}[/b]")
		.described("Records a value into a named rolling history you can dump, chart, or check when something goes wrong."))
	descriptors.append(F.make_descriptor("Core", "TrailValues", "Trail Values", ACEDescriptor.ACEType.EXPRESSION, "((get_meta(&\"__ef_trails\", {}) as Dictionary).get({trail}, []) as Array)", "", [F.make_param("trail", "String", "\"vy\"", "Trail", "Trail name, matching a Remember In Trail action.", "expression")], "Debug", "trail [b]{trail}[/b] values")
		.described("Returns the whole trail as an array, oldest first - feed it to a chart, a table, or an array action."))
	descriptors.append(F.make_descriptor("Core", "TrailLowest", "Lowest In Trail", ACEDescriptor.ACEType.EXPRESSION, "(((get_meta(&\"__ef_trails\", {}) as Dictionary).get({trail}, []) as Array).reduce(func(__acc, __v): return min(__acc, __v), INF))", "", [F.make_param("trail", "String", "\"vy\"", "Trail", "Trail name, matching a Remember In Trail action.", "expression")], "Debug", "lowest in trail [b]{trail}[/b]")
		.described("The smallest value recorded in a trail, which is the spike a per-frame watch blinked past. An empty trail reads as INF."))
	descriptors.append(F.make_descriptor("Core", "TrailHighest", "Highest In Trail", ACEDescriptor.ACEType.EXPRESSION, "(((get_meta(&\"__ef_trails\", {}) as Dictionary).get({trail}, []) as Array).reduce(func(__acc, __v): return max(__acc, __v), -INF))", "", [F.make_param("trail", "String", "\"vy\"", "Trail", "Trail name, matching a Remember In Trail action.", "expression")], "Debug", "highest in trail [b]{trail}[/b]")
		.described("The largest value recorded in a trail. An empty trail reads as -INF."))
	descriptors.append(F.make_descriptor("Core", "TrailAverage", "Average In Trail", ACEDescriptor.ACEType.EXPRESSION, "(((get_meta(&\"__ef_trails\", {}) as Dictionary).get({trail}, []) as Array).reduce(func(__acc, __v): return __acc + float(__v), 0.0) / maxf(float(((get_meta(&\"__ef_trails\", {}) as Dictionary).get({trail}, []) as Array).size()), 1.0))", "", [F.make_param("trail", "String", "\"vy\"", "Trail", "Trail name, matching a Remember In Trail action.", "expression")], "Debug", "average of trail [b]{trail}[/b]")
		.described("The mean of every number recorded in a trail - a rolling average that is as useful in gameplay as in debugging. An empty trail reads as 0."))
	descriptors.append(F.make_descriptor("Core", "TrailNewest", "Newest In Trail", ACEDescriptor.ACEType.EXPRESSION, "(([0] + ((get_meta(&\"__ef_trails\", {}) as Dictionary).get({trail}, []) as Array)).back())", "", [F.make_param("trail", "String", "\"vy\"", "Trail", "Trail name, matching a Remember In Trail action.", "expression")], "Debug", "newest in trail [b]{trail}[/b]")
		.described("The most recently recorded value in a trail, or 0 when nothing has been recorded yet."))
	descriptors.append(F.make_descriptor("Core", "TrailLength", "Trail Length", ACEDescriptor.ACEType.EXPRESSION, "(((get_meta(&\"__ef_trails\", {}) as Dictionary).get({trail}, []) as Array).size())", "", [F.make_param("trail", "String", "\"vy\"", "Trail", "Trail name, matching a Remember In Trail action.", "expression")], "Debug", "length of trail [b]{trail}[/b]")
		.described("How many values a trail is currently holding, which tops out at the Keep you gave it."))
	descriptors.append(F.make_descriptor("Core", "LogTrail", "Log Trail", ACEDescriptor.ACEType.ACTION, "print(\"trail \", {trail}, \": \", (get_meta(&\"__ef_trails\", {}) as Dictionary).get({trail}, []))", "", [F.make_param("trail", "String", "\"vy\"", "Trail", "Trail name, matching a Remember In Trail action.", "expression")], "Debug", "log trail [b]{trail}[/b]")
		.described("Prints the whole trail to the Output console, so the seconds before a bug arrive with the bug."))
	descriptors.append(F.make_descriptor("Core", "SaveTrailCsv", "Save Trail To CSV", ACEDescriptor.ACEType.ACTION, "var __csv_{uid}: FileAccess = FileAccess.open({path}, FileAccess.WRITE)\nif __csv_{uid} != null:\n\t__csv_{uid}.store_line(\"index,value\")\n\tvar __rows_{uid}: Array = (get_meta(&\"__ef_trails\", {}) as Dictionary).get({trail}, []) as Array\n\tfor __i_{uid}: int in __rows_{uid}.size():\n\t\t__csv_{uid}.store_line(\"%d,%s\" % [__i_{uid}, str(__rows_{uid}[__i_{uid}])])\n\t__csv_{uid}.close()", "", [F.make_param("trail", "String", "\"vy\"", "Trail", "Trail name, matching a Remember In Trail action.", "expression"), F.make_param("path", "String", "\"user://trail.csv\"", "Path", "Where to write the file. Use user:// so it works in an exported game.", "expression")], "Debug", "save trail [b]{trail}[/b] to [b]{path}[/b]")
		.described("Writes a trail to a two-column CSV file you can open in a spreadsheet and plot."))
	descriptors.append(F.make_descriptor("Core", "ClearTrail", "Clear Trail", ACEDescriptor.ACEType.ACTION, "var __trails_{uid}: Dictionary = get_meta(&\"__ef_trails\", {}) as Dictionary\n__trails_{uid}.erase({trail})\nset_meta(&\"__ef_trails\", __trails_{uid})", "", [F.make_param("trail", "String", "\"vy\"", "Trail", "Trail name, matching a Remember In Trail action.", "expression")], "Debug", "clear trail [b]{trail}[/b]")
		.described("Forgets everything a trail recorded, so the next run starts from nothing."))

	# ── Debug: frame budget conditions and named stopwatches ──
	# Vocabulary, not chrome: no row gains a margin chip and nothing is displayed anywhere. A
	# measurement becomes visible only where a row sends it (Log Measurements, a label, the Debug
	# Overlay pack). Godot emits no signal for a frame overrun or a sustained FPS drop, so these
	# are honestly CONDITIONS - the one case where polling is the only truth available.
	descriptors.append(F.make_descriptor("Core", "FrameOverBudget", "Frame Took Longer Than", ACEDescriptor.ACEType.CONDITION, "(get_process_delta_time() * 1000.0 > {ms})", "", [F.make_param("ms", "String", "20.0", "Milliseconds", "The budget. 16.6 is one frame at 60 FPS.", "expression")], "Debug", "frame took longer than [b]{ms}[/b] ms")
		.described("True on a frame that took longer than your budget, which is the hitch caught as it happens. Needs a per-frame trigger."))
	# Sustained low FPS: one stuttery frame is not a performance problem, three seconds of them is.
	# A per-instance member remembers WHEN the drop started and the helper clears it the moment the
	# framerate recovers, so the row only fires once the drop has genuinely lasted.
	descriptors.append(F.make_descriptor("Core", "FpsBelowFor", "FPS Below For", ACEDescriptor.ACEType.CONDITION, "__fps_below_for_{uid}({fps}, {seconds})", "", [F.make_param("fps", "String", "45.0", "FPS", "The framerate floor. Below this counts as a drop.", "expression"), F.make_param("seconds", "String", "3.0", "For Seconds", "How long the drop must last before this is true.", "expression")], "Debug", "FPS below [b]{fps}[/b] for [b]{seconds}[/b] seconds")
		.described("True once the framerate has stayed under your floor for the whole stretch you name, which tells a real performance drop apart from one stuttery frame. Needs a per-frame trigger.")
		.stateful("var __fpslow_{uid}: float = -1.0\n\nfunc __fps_below_for_{uid}(limit: float, seconds: float) -> bool:\n\tvar now: float = Time.get_ticks_msec() * 0.001\n\tif Engine.get_frames_per_second() >= limit:\n\t\t__fpslow_{uid} = -1.0\n\t\treturn false\n\tif __fpslow_{uid} < 0.0:\n\t\t__fpslow_{uid} = now\n\t\treturn false\n\treturn now - __fpslow_{uid} >= seconds"))
	# The MOMENT, rather than the state: the pair above answer "is it slow right now", which is true
	# on sixty frames a second and gives a row nowhere to put "and do something about it". These two
	# speak ONCE - the first fires on the frame a run of long frames reaches the length you named and
	# stays quiet until the run breaks; the second fires once the calm has lasted, and only if it saw
	# a long frame first, so a game that started well never hears "recovered" out of nowhere.
	#
	# Two thresholds and two lengths between them is HYSTERESIS, and it is the whole point: one number
	# would have the game flicking its own quality up and down on the boundary forever. Fire long at
	# over 16 ms for 30 frames, recovered at under 12 ms for 300, and the gap is what stops the
	# flapping. Each row carries its own counters, so the pair works with nothing wired between them.
	descriptors.append(F.make_descriptor("Core", "FrameRunningLong", "On The Frame Running Long", ACEDescriptor.ACEType.CONDITION, "__frame_long_{uid}({ms}, {frames})", "", [F.make_param("ms", "String", "16.0", "Over Milliseconds", "A frame longer than this counts as a long one. 16.6 is one frame at 60 FPS.", "expression"), F.make_param("frames", "String", "30", "For Frames", "How many long frames in a row before this fires. One hitch is not a problem; half a second of them is.", "expression")], "Debug", "On the frame running long [b]{ms}[/b] ms for [b]{frames}[/b] frames")
		.described("True on the ONE frame where the game has been over budget for the whole run you name, and quiet after that until a frame comes in under budget again. This is where a game turns its own effects down. Needs a per-frame trigger.")
		.stateful("var __frame_long_run_{uid}: int = 0\nvar __frame_long_said_{uid}: bool = false\n\nfunc __frame_long_{uid}(ms: float, frames: int) -> bool:\n\tif get_process_delta_time() * 1000.0 <= ms:\n\t\t__frame_long_run_{uid} = 0\n\t\t__frame_long_said_{uid} = false\n\t\treturn false\n\t__frame_long_run_{uid} += 1\n\tif __frame_long_said_{uid} or __frame_long_run_{uid} < frames:\n\t\treturn false\n\t__frame_long_said_{uid} = true\n\treturn true"))
	descriptors.append(F.make_descriptor("Core", "FrameRecovered", "On The Frame Recovered", ACEDescriptor.ACEType.CONDITION, "__frame_calm_{uid}({ms}, {frames})", "", [F.make_param("ms", "String", "12.0", "Under Milliseconds", "A frame shorter than this counts as calm. Keep it comfortably under the long threshold - the gap between the two is what stops the game flapping.", "expression"), F.make_param("frames", "String", "300", "For Frames", "How many calm frames in a row before this fires. Long enough that a lull in the action is not mistaken for a fix.", "expression")], "Debug", "On the frame recovered under [b]{ms}[/b] ms for [b]{frames}[/b] frames")
		.described("True on the ONE frame where the game has run comfortably for the whole run you name, after having been over budget. This is where the effects go back on. It never fires before a long stretch has happened, so a game that started well hears nothing. Needs a per-frame trigger.")
		.stateful("var __frame_calm_run_{uid}: int = 0\nvar __frame_was_long_{uid}: bool = false\n\nfunc __frame_calm_{uid}(ms: float, frames: int) -> bool:\n\tif get_process_delta_time() * 1000.0 >= ms:\n\t\t__frame_calm_run_{uid} = 0\n\t\t__frame_was_long_{uid} = true\n\t\treturn false\n\t__frame_calm_run_{uid} += 1\n\tif not __frame_was_long_{uid} or __frame_calm_run_{uid} < frames:\n\t\treturn false\n\t__frame_was_long_{uid} = false\n\treturn true"))
	# Named stopwatches: wrap the work you suspect, then read it back as last / average / peak.
	# Same stateless metadata idiom as the trails above: two dictionaries in node metadata, one
	# holding the open start stamps and one accumulating [total_ms, samples, peak_ms, last_ms] per
	# name. A name is free text (spaces welcome) because it is a dictionary key, never a meta key.
	descriptors.append(F.make_descriptor("Core", "StartMeasuring", "Start Measuring", ACEDescriptor.ACEType.ACTION, "var __starts_{uid}: Dictionary = get_meta(&\"__ef_span_starts\", {}) as Dictionary\n__starts_{uid}[{named}] = Time.get_ticks_usec()\nset_meta(&\"__ef_span_starts\", __starts_{uid})", "", [F.make_param("named", "String", "\"spawn wave\"", "Name", "The name this measurement is reported under.", "expression")], "Debug", "start measuring [b]{named}[/b]")
		.described("Starts a named stopwatch. Pair it with Stop Measuring around the work you suspect."))
	descriptors.append(F.make_descriptor("Core", "StopMeasuring", "Stop Measuring", ACEDescriptor.ACEType.ACTION, "var __starts_{uid}: Dictionary = get_meta(&\"__ef_span_starts\", {}) as Dictionary\nvar __span_{uid}: float = float(Time.get_ticks_usec() - int(__starts_{uid}.get({named}, Time.get_ticks_usec()))) / 1000.0\nvar __stats_{uid}: Dictionary = get_meta(&\"__ef_spans\", {}) as Dictionary\nvar __row_{uid}: Array = __stats_{uid}.get({named}, [0.0, 0, 0.0, 0.0]) as Array\n__stats_{uid}[{named}] = [float(__row_{uid}[0]) + __span_{uid}, int(__row_{uid}[1]) + 1, maxf(float(__row_{uid}[2]), __span_{uid}), __span_{uid}]\nset_meta(&\"__ef_spans\", __stats_{uid})", "", [F.make_param("named", "String", "\"spawn wave\"", "Name", "The name you gave Start Measuring.", "expression")], "Debug", "stop measuring [b]{named}[/b]")
		.described("Stops a named stopwatch and files the result, keeping the last, the average and the worst reading for that name."))
	descriptors.append(F.make_descriptor("Core", "MeasuredLast", "Last Measured (ms)", ACEDescriptor.ACEType.EXPRESSION, "(float(((get_meta(&\"__ef_spans\", {}) as Dictionary).get({named}, [0.0, 0, 0.0, 0.0]) as Array)[3]))", "", [F.make_param("named", "String", "\"spawn wave\"", "Name", "The name you gave Start Measuring.", "expression")], "Debug", "last measured [b]{named}[/b] ms")
		.described("How many milliseconds the most recent run of a named measurement took."))
	descriptors.append(F.make_descriptor("Core", "MeasuredAverage", "Average Measured (ms)", ACEDescriptor.ACEType.EXPRESSION, "(float(((get_meta(&\"__ef_spans\", {}) as Dictionary).get({named}, [0.0, 0, 0.0, 0.0]) as Array)[0]) / maxf(float(((get_meta(&\"__ef_spans\", {}) as Dictionary).get({named}, [0.0, 0, 0.0, 0.0]) as Array)[1]), 1.0))", "", [F.make_param("named", "String", "\"spawn wave\"", "Name", "The name you gave Start Measuring.", "expression")], "Debug", "average measured [b]{named}[/b] ms")
		.described("The mean cost in milliseconds across every run of a named measurement, which is the number to quote when you claim an optimization worked."))
	descriptors.append(F.make_descriptor("Core", "MeasuredPeak", "Peak Measured (ms)", ACEDescriptor.ACEType.EXPRESSION, "(float(((get_meta(&\"__ef_spans\", {}) as Dictionary).get({named}, [0.0, 0, 0.0, 0.0]) as Array)[2]))", "", [F.make_param("named", "String", "\"spawn wave\"", "Name", "The name you gave Start Measuring.", "expression")], "Debug", "peak measured [b]{named}[/b] ms")
		.described("The worst run of a named measurement in milliseconds, which is usually the one the player felt."))
	descriptors.append(F.make_descriptor("Core", "LogMeasurements", "Log Measurements", ACEDescriptor.ACEType.ACTION, "for __key_{uid}: Variant in (get_meta(&\"__ef_spans\", {}) as Dictionary):\n\tvar __row_{uid}: Array = (get_meta(&\"__ef_spans\", {}) as Dictionary)[__key_{uid}] as Array\n\tprint(\"%s: last %.2fms  avg %.2fms  peak %.2fms  (%d samples)\" % [str(__key_{uid}), float(__row_{uid}[3]), float(__row_{uid}[0]) / maxf(float(__row_{uid}[1]), 1.0), float(__row_{uid}[2]), int(__row_{uid}[1])])", "", [], "Debug", "log measurements")
		.described("Prints every named measurement taken so far with its last, average and peak cost - the report you paste into a bug or a devlog."))
	descriptors.append(F.make_descriptor("Core", "ClearMeasurements", "Clear Measurements", ACEDescriptor.ACEType.ACTION, "set_meta(&\"__ef_spans\", {})\nset_meta(&\"__ef_span_starts\", {})", "", [], "Debug", "clear measurements")
		.described("Throws away every measurement recorded so far, so a fresh run starts from a clean slate."))

	# ── Groups: the scene-tree group vocabulary (tag + query + broadcast) ──
	descriptors.append(F.make_descriptor("Core", "AddToGroup", "Add To Group", ACEDescriptor.ACEType.ACTION, "{target}.add_to_group({group})", "", [F.make_param("target", "String", "self", "Target", "Node to tag.", "expression"), F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "group_reference")], "Groups", "add [i]{target}[/i] to [b]{group}[/b]")
		.described("Tags a node into a named group so you can find or affect it later."))
	descriptors.append(F.make_descriptor("Core", "RemoveFromGroup", "Remove From Group", ACEDescriptor.ACEType.ACTION, "{target}.remove_from_group({group})", "", [F.make_param("target", "String", "self", "Target", "Node to untag.", "expression"), F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "group_reference")], "Groups", "remove [i]{target}[/i] from [b]{group}[/b]")
		.described("Untags a node from a named group when it should no longer belong."))
	descriptors.append(F.make_descriptor("Core", "IsInGroup", "Is In Group", ACEDescriptor.ACEType.CONDITION, "{target}.is_in_group({group})", "", [F.make_param("target", "String", "self", "Target", "Node to test.", "expression"), F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "group_reference")], "Groups", "[i]{target}[/i] in [b]{group}[/b]")
		.described("True when the given node currently belongs to the named group."))
	descriptors.append(F.make_descriptor("Core", "GetFirstNodeInGroup", "Get First Node In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_first_node_in_group({group})", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "group_reference")], "Groups", "first in {group}")
		.described("Returns the first node found in a named group, or nothing if empty."))
	descriptors.append(F.make_descriptor("Core", "GetNodeCountInGroup", "Count Nodes In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_node_count_in_group({group})", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "group_reference")], "Groups", "count in {group}")
		.described("Returns how many nodes are currently in the named group."))
	# Numeric roll-ups across a group with no loop (the "average health of all enemies" case): each
	# reduces over get_nodes_in_group in one line. Sum/Average start at 0; Min/Max start at +/-INF so
	# an empty group yields that sentinel instead of erroring. {property} is a bare numeric member.
	descriptors.append(F.make_descriptor("Core", "SumInGroup", "Sum In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_nodes_in_group({group}).reduce(func(__acc, __n): return __acc + __n.{property}, 0.0)", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "group_reference"), F.make_param("property", "String", "health", "Property", "Numeric member to total up across the group, e.g. health.", "expression")], "Groups", "sum of {property} in {group}")
		.described("Returns the total of a numeric property added up across every group member."))
	descriptors.append(F.make_descriptor("Core", "AverageInGroup", "Average In Group", ACEDescriptor.ACEType.EXPRESSION, "(get_tree().get_nodes_in_group({group}).reduce(func(__acc, __n): return __acc + __n.{property}, 0.0) / maxf(float(get_tree().get_nodes_in_group({group}).size()), 1.0))", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "group_reference"), F.make_param("property", "String", "health", "Property", "Numeric member to average across the group, e.g. health.", "expression")], "Groups", "average {property} in {group}")
		.described("Returns the average of a numeric property across all members of a group."))
	descriptors.append(F.make_descriptor("Core", "MinInGroup", "Lowest In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_nodes_in_group({group}).reduce(func(__acc, __n): return min(__acc, __n.{property}), INF)", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "group_reference"), F.make_param("property", "String", "health", "Property", "Numeric member to take the minimum of, e.g. health.", "expression")], "Groups", "lowest {property} in {group}")
		.described("Returns the smallest value of a property among all group members."))
	descriptors.append(F.make_descriptor("Core", "MaxInGroup", "Highest In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_nodes_in_group({group}).reduce(func(__acc, __n): return max(__acc, __n.{property}), -INF)", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "group_reference"), F.make_param("property", "String", "health", "Property", "Numeric member to take the maximum of, e.g. health.", "expression")], "Groups", "highest {property} in {group}")
		.described("Returns the largest value of a property among all group members."))
	descriptors.append(F.make_descriptor("Core", "CallGroup", "Call Method On Group", ACEDescriptor.ACEType.ACTION, "get_tree().call_group({group}, {method})", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "group_reference"), F.make_param("method", "String", "\"reset\"", "Method", "Method name to call on every member.", "expression")], "Groups", "call {method} on {group}")
		.described("Calls the named method on every node in a group at once."))
	# The SEND direction with data: a decoupled broadcast that carries a value to every group member (bare
	# call_group carries none, so passing data used to force get_node(sibling).method(x)). Leave Value blank
	# for a no-arg call - the {, args} optional-comma drops cleanly.
	descriptors.append(F.make_descriptor("Core", "CallGroupWith", "Call Method On Group (with value)", ACEDescriptor.ACEType.ACTION, "get_tree().call_group({group}, {method}{, args})", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "group_reference"), F.make_param("method", "String", "\"take_damage\"", "Method", "Method to call on every member.", "expression"), F.make_param("args", "String", "10", "Value", "Value(s) passed to the method (comma-separated); leave blank for none.", "expression")], "Groups", "call {method}({args}) on {group}")
		.described("Calls a method with a value on every member of a group at once - a decoupled broadcast that carries data."))

	# ── Metadata: arbitrary key/value on any node (Godot's set_meta/get_meta) ──
	descriptors.append(F.make_descriptor("Core", "SetMeta", "Set Metadata", ACEDescriptor.ACEType.ACTION, "{target}.set_meta({name}, {value})", "", [F.make_param("target", "String", "self", "Target", "Object to tag.", "expression"), F.make_param("name", "String", "\"key\"", "Name", "Metadata key.", "expression"), F.make_param("value", "String", "0", "Value", "Value to store.", "expression")], "Metadata", "set meta {name} = {value}")
		.described("Stores a custom named value on an object as hidden metadata."))
	descriptors.append(F.make_descriptor("Core", "GetMeta", "Get Metadata", ACEDescriptor.ACEType.EXPRESSION, "{target}.get_meta({name})", "", [F.make_param("target", "String", "self", "Target", "Object to read.", "expression"), F.make_param("name", "String", "\"key\"", "Name", "Metadata key.", "expression")], "Metadata", "meta {name}")
		.described("Returns a custom metadata value previously stored on an object."))
	descriptors.append(F.make_descriptor("Core", "HasMeta", "Has Metadata", ACEDescriptor.ACEType.CONDITION, "{target}.has_meta({name})", "", [F.make_param("target", "String", "self", "Target", "Object to test.", "expression"), F.make_param("name", "String", "\"key\"", "Name", "Metadata key.", "expression")], "Metadata", "has meta {name}")
		.described("True when the object has metadata stored under the given key."))
	descriptors.append(F.make_descriptor("Core", "RemoveMeta", "Remove Metadata", ACEDescriptor.ACEType.ACTION, "{target}.remove_meta({name})", "", [F.make_param("target", "String", "self", "Target", "Object to edit.", "expression"), F.make_param("name", "String", "\"key\"", "Name", "Metadata key.", "expression")], "Metadata", "remove meta {name}")
		.described("Deletes a stored metadata value from an object by its key."))

	# ── Nodes: scene-tree navigation (parent / child / find / owner), the everyday tree queries ──
	descriptors.append(F.make_descriptor("Core", "GetParent", "Get Parent", ACEDescriptor.ACEType.EXPRESSION, "{target}.get_parent()", "", [F.make_param("target", "String", "self", "Target", "Node whose parent to get.", "expression")], "Nodes", "[i]{target}[/i] parent")
		.described("Returns the node directly above this one in the scene tree."))
	descriptors.append(F.make_descriptor("Core", "GetChildCount", "Get Child Count", ACEDescriptor.ACEType.EXPRESSION, "{target}.get_child_count()", "", [F.make_param("target", "String", "self", "Target", "Node whose children to count.", "expression")], "Nodes", "[i]{target}[/i] child count")
		.described("Returns how many direct children a node currently has."))
	descriptors.append(F.make_descriptor("Core", "GetChild", "Get Child (by index)", ACEDescriptor.ACEType.EXPRESSION, "{target}.get_child({index})", "", [F.make_param("target", "String", "self", "Target", "Parent node.", "expression"), F.make_param("index", "String", "0", "Index", "Child index (0-based).", "expression")], "Nodes", "[i]{target}[/i] child [b]{index}[/b]")
		.described("Returns a node's child at the given position number, starting from zero."))
	descriptors.append(F.make_descriptor("Core", "FindChild", "Find Child (by name)", ACEDescriptor.ACEType.EXPRESSION, "{target}.find_child({pattern})", "", [F.make_param("target", "String", "self", "Target", "Node to search under.", "expression"), F.make_param("pattern", "String", "\"Enemy*\"", "Pattern", "Name pattern (wildcards allowed).", "expression")], "Nodes", "find [b]{pattern}[/b] in [i]{target}[/i]")
		.described("Returns a child node matching a name pattern, useful when paths vary."))
	descriptors.append(F.make_descriptor("Core", "GetNodeOrNull", "Get Node Or Null", ACEDescriptor.ACEType.EXPRESSION, "{target}.get_node_or_null({path})", "", [F.make_param("target", "String", "self", "Target", "Base node.", "expression"), F.make_param("path", "String", "\"Sprite2D\"", "Path", "Node path (returns null if missing).", "expression")], "Nodes", "[i]{target}[/i].[b]{path}[/b] or null")
		.described("Returns the node at a path, or nothing instead of erroring if missing."))
	descriptors.append(F.make_descriptor("Core", "HasNode", "Has Node", ACEDescriptor.ACEType.CONDITION, "{target}.has_node({path})", "", [F.make_param("target", "String", "self", "Target", "Base node.", "expression"), F.make_param("path", "String", "\"Sprite2D\"", "Path", "Node path to test.", "expression")], "Nodes", "[i]{target}[/i] has [b]{path}[/b]")
		.described("True when a node exists at the given path under this one."))
	descriptors.append(F.make_descriptor("Core", "GetOwner", "Get Scene Owner", ACEDescriptor.ACEType.EXPRESSION, "{target}.owner", "", [F.make_param("target", "String", "self", "Target", "Node whose scene owner to get.", "expression")], "Nodes", "[i]{target}[/i] owner")
		.described("Returns the scene that this node was saved as part of."))
	# The write half of the read-only row above it. Get Scene Owner answers which scene a node was
	# saved as part of; this is how a node built while the game runs is given that answer, which is
	# the one thing that decides whether it is written out when the branch it sits in is packed.
	# Save Branch As Scene File is the wholesale cousin: it walks a whole branch setting the owner of
	# every part that has none, because packing a branch of nodes made at run time is exactly the case
	# where nothing has one. This row is that same assignment for the one node a reader means.
	descriptors.append(F.make_descriptor("Core", "SetSceneOwner", "Set Scene Owner", ACEDescriptor.ACEType.ACTION, "{target}.owner = {root}", "", [F.make_param("target", "String", "self", "Target", "The node to give an owner to.", "expression"), F.make_param("root", "String", "get_tree().current_scene", "Owned By", "The node at the top of the scene it belongs to. That node has to be an ancestor of this one, or the assignment is refused.", "expression")], "Nodes", "make [i]{target}[/i] part of [i]{root}[/i]")
		.described("Says which scene a node belongs to, which is what decides whether it is written out when that scene is packed and saved. A node built while the game runs has no owner at all, so a branch of them packs to an empty scene until this is set."))
	descriptors.append(F.make_descriptor("Core", "IsAncestorOf", "Is Ancestor Of", ACEDescriptor.ACEType.CONDITION, "{target}.is_ancestor_of({node})", "", [F.make_param("target", "String", "self", "Target", "Potential ancestor node.", "expression"), F.make_param("node", "String", "get_node(\"Child\")", "Node", "Node to test for descendancy.", "expression")], "Nodes", "[i]{target}[/i] is ancestor of [i]{node}[/i]")
		.described("True when this node is somewhere above the other node in the tree."))

	return descriptors
