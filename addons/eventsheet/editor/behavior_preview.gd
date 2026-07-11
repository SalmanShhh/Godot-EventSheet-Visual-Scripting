@tool
class_name EventSheetBehaviorPreview
extends RefCounted

# In-editor behavior preview (event-sheet-style: see the motion in the editor, not just at
# runtime). Tools > Preview Behaviors on Selected Node animates the scene-editor selection by
# sampling its attached behaviors' preview functions every tick, and restores the node exactly
# when the preview stops (toggle again, select something else, or the window closes) - the
# scene's saved bytes are never touched.
#
# The contract a behavior opts in with (the Custom ACE / pack API seam):
#
#   static func editor_preview_sample(params: Dictionary, base: Dictionary, time: float) -> Dictionary
#
# - params: the behavior node's exported values, read straight off the scene instance (period,
#   magnitude, whatever the pack exports) - the preview always reflects the Inspector.
# - base: the host's captured rest state ({"position", "rotation", "scale", "modulate"} when the
#   host has them).
# - returns: {host_property: value} to apply this frame ({} = nothing).
#
# STATIC on purpose: the emitted pack script never runs in the editor (no @tool), but its statics
# are callable from editor code - so a pack adds preview with one pure function and zero editor
# dependencies. Packs that can't ship the static (or third-party scripts) can register a sampler
# for their script path via EventSheets.register_editor_preview instead.

const FRAME_SECONDS := 1.0 / 30.0

var _dock: Control = null
var _timer: Timer = null
var _time: float = 0.0
## One entry per previewable behavior on the target: {script, params, host, base}.
var _entries: Array[Dictionary] = []
var _target: Node = null


func init(dock: Control) -> void:
	_dock = dock


func is_active() -> bool:
	return _timer != null and not _timer.is_stopped()


## The Tools-menu / palette entry point: start on the scene-editor selection, or stop if running.
func toggle() -> void:
	if is_active():
		stop()
		return
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		_dock._set_status("Behavior preview runs inside the editor.", true)
		return
	var selected: Array[Node] = EditorInterface.get_selection().get_selected_nodes()
	if selected.is_empty():
		_dock._set_status("Select a node in the Scene dock first - its attached behaviors will preview.", true)
		return
	start(selected[0])


## Starts previewing every previewable behavior attached under `target` (its direct children,
## the attach convention). Safe to call with anything - a node with no previewable behaviors
## just reports so.
func start(target: Node) -> void:
	stop()
	_entries = _collect_entries(target)
	if _entries.is_empty():
		_dock._set_status("No previewable behaviors on %s - a behavior opts in with editor_preview_sample() (see the pack API guide)." % target.name, true)
		return
	_target = target
	_time = 0.0
	if _timer == null:
		_timer = Timer.new()
		_timer.wait_time = FRAME_SECONDS
		_timer.timeout.connect(_tick)
		_dock.add_child(_timer)
	# Stop (and restore) the moment the user selects something else - preview follows focus.
	if Engine.is_editor_hint():
		var selection: Object = EditorInterface.get_selection()
		if not selection.selection_changed.is_connected(stop):
			selection.selection_changed.connect(stop)
	if _timer.is_inside_tree():
		_timer.start()
	_dock._set_status("Previewing %d behavior(s) on %s - run the command again to stop." % [_entries.size(), target.name])


## Stops the preview and restores every host property to its captured rest state - the editor
## scene ends byte-identical to how it started.
func stop() -> void:
	if _timer != null:
		_timer.stop()
	for entry: Dictionary in _entries:
		var host: Node = entry.get("host")
		if host == null or not is_instance_valid(host):
			continue
		var base: Dictionary = entry.get("base", {})
		for property_name: String in base:
			host.set(property_name, base[property_name])
	_entries = []
	_target = null


## Builds the preview entries: each child behavior whose script offers a sampler (registered
## via the API, or the editor_preview_sample static) paired with its live exported params and
## its host's captured rest state.
func _collect_entries(target: Node) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for child: Node in target.get_children():
		var script: Script = child.get_script() as Script
		if script == null:
			continue
		var sampler: Callable = EventSheets.editor_preview_sampler_for(script.resource_path)
		if not sampler.is_valid() and not _has_preview_static(script):
			continue
		entries.append({
			"script": script,
			"sampler": sampler,
			"params": _exported_values(child),
			"host": target,
			"base": _capture_base(target),
		})
	return entries


static func _has_preview_static(script: Script) -> bool:
	for method: Dictionary in script.get_script_method_list():
		if str(method.get("name", "")) == "editor_preview_sample":
			return true
	return false


## The behavior node's script variables by name - the sampler sees exactly what the Inspector
## shows, so tweaking a knob re-previews live.
static func _exported_values(behavior: Node) -> Dictionary:
	var values: Dictionary = {}
	for property: Dictionary in behavior.get_property_list():
		if int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var property_name: String = str(property.get("name", ""))
			values[property_name] = behavior.get(property_name)
	return values


## The host's rest state for the transform-ish properties previews commonly drive. Only
## properties the host actually has are captured (a Node3D has no modulate).
static func _capture_base(host: Node) -> Dictionary:
	var base: Dictionary = {}
	for property_name: String in ["position", "rotation", "scale", "modulate"]:
		var value: Variant = host.get(property_name)
		if value != null:
			base[property_name] = value
	return base


func _tick() -> void:
	if _target == null or not is_instance_valid(_target):
		stop()
		return
	_time += FRAME_SECONDS
	for entry: Dictionary in _entries:
		# Live params: re-read each tick so Inspector tweaks show up mid-preview.
		entry["params"] = _exported_values_of(entry)
		var sampler: Callable = entry.get("sampler", Callable())
		var sampled: Variant
		if sampler.is_valid():
			sampled = sampler.call(entry["params"], entry["base"], _time)
		else:
			sampled = (entry["script"] as Script).call("editor_preview_sample", entry["params"], entry["base"], _time)
		if sampled is Dictionary:
			var host: Node = entry.get("host")
			for property_name: String in (sampled as Dictionary):
				host.set(property_name, (sampled as Dictionary)[property_name])


func _exported_values_of(entry: Dictionary) -> Dictionary:
	var host: Node = entry.get("host")
	if host == null or not is_instance_valid(host):
		return entry.get("params", {})
	for child: Node in host.get_children():
		if child.get_script() == entry.get("script"):
			return _exported_values(child)
	return entry.get("params", {})
