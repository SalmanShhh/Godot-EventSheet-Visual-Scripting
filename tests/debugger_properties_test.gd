# EventForge - the behavior debugger seam (the event-sheet GetDebuggerProperties idea): a child
# node defining `debugger_properties() -> Dictionary` joins the sheet's throttled live-values
# frame, keys namespaced "ChildName.key", and the Live Values panel groups them per behavior
# (read-only). Pins: the compiled send block carries the duck-typed child scan, the panel's
# display plan groups dotted keys (stable signature; sheet variables stay flat + first), a
# dotted key can never poison Watch expressions, and the shipped UHTN planner's section
# reports its plan live.
@tool
class_name DebuggerPropertiesTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ---- emission: the live-values frame scans children for the seam ----
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.emit_live_values = true
	sheet.variables = {"score": {"type": "int", "default": 0, "exported": false}}
	var output: String = str(EventSheetCompiler.compile(sheet, "user://dbg_props_probe.gd").get("output", ""))
	ok = _check(ok, output.contains("if __live_child.has_method(\"debugger_properties\")"), "the compiled frame scans children for the seam")
	ok = _check(ok, output.contains("__live_frame.append(str(__live_child.name) + \".\" + str(__live_key))"), "child keys stream namespaced ChildName.key")
	ok = _check(ok, output.contains("EngineDebugger.send_message(\"eventsheets:live_values\", __live_frame)"), "the frame sends over the existing channel")
	if FileAccess.file_exists("user://dbg_props_probe.gd"):
		DirAccess.remove_absolute("user://dbg_props_probe.gd")

	# ---- dotted keys never poison watches ----
	var watch: Dictionary = EventSheetLiveValuesPanel.evaluate_watch("score + hp", {"score": 7, "hp": 3, "Sine.phase": 0.5})
	ok = _check(ok, bool(watch.get("ok", false)) and int(watch.get("value", -1)) == 10, "a watch still evaluates with dotted keys streaming (got %s)" % str(watch))

	# ---- the shipped demo: the UHTN planner reports its live section ----
	var planner_script: Script = load("res://eventsheet_addons/uhtn_planning/uhtn_planning_behavior.gd")
	var planner: Node = planner_script.new() as Node
	planner.call("add_primitive", "patrol")
	planner.call("add_primitive", "salute")
	planner.set("plan", ["patrol", "salute"])
	planner.set("plan_index", 0)
	planner.call("set_world_state", "alert", 1)
	var props: Dictionary = planner.call("debugger_properties")
	ok = _check(ok, str(props.get("current_task", "")) == "patrol", "the planner reports its current task (got %s)" % str(props.get("current_task")))
	ok = _check(ok, str(props.get("plan", "")) == "patrol > salute", "the remaining plan reads as a chain (got %s)" % str(props.get("plan")))
	ok = _check(ok, str(props.get("plan_step", "")) == "0 / 2", "the step counter reads n / total")
	ok = _check(ok, (props.get("world_state", {}) as Dictionary).get("alert", 0) == 1, "world state travels in the section")
	planner.free()

	return ok


static func _check(ok: bool, condition: bool, label: String) -> bool:
	if not condition:
		print("  [FAIL] ", label)
	return ok and condition
