# EventForge - the Preview button a behaviour carries when it can be watched without playing.
#
# A behaviour whose builder declares `previews` compiles to a `@tool` script with one Inspector
# button, Preview (it reads Stop preview while playing), and one guarded line at the top of every
# per-frame callback: in the editor, do nothing unless Preview was pressed. The preview is the
# behaviour's own code running on the open scene, so it needs nothing from the plugin.
#
# THE SCENE IS NEVER CHANGED. When Preview starts, every stored property of the host is written
# down (the values the .tscn would save); Stop, leaving the tree (another scene tab, closing the
# scene, quitting) and the editor's pre-save notification (saving, and Play, which saves first)
# put each one back. Values are set straight on the node, never through the undo history, so the
# scene tab never shows as modified. The behaviour's own unsaved script variables are written down
# and restored too, so the next Preview starts from the same state the first one did. The written
# down values live in an Engine meta table keyed by host, shared by every behaviour on that host,
# so several can preview at once and the first one to start is the one that remembers the rest
# state. Engine metadata is never saved into a scene.
#
# A HAND EDIT IS KEPT. Dragging the host in the viewport, typing into its Inspector or undoing a move
# during a preview is the user's change, not the preview's, so the preview must not overwrite it or
# put the old value back on Stop. Each table entry also holds "seen": the host's values as the preview
# last left them, noted just before a frame is drawn (after input, physics, process, timers and tweens
# have all run). At the start of the next frame, before the preview writes anything, a value that
# differs from "seen" was changed by someone else: it becomes the host's new resting value and the
# preview stops. The editor normally draws nothing when nothing on screen changed, so a preview that
# is quiet for a moment would note nothing, and a hand edit made then would be noted as the preview's
# own. While any preview plays the editor is therefore asked to draw every frame, as a running game
# does (its low-processor setting is kept in an Engine meta and put back when the last preview stops).
# A note is also trusted once, so a frame that is not drawn anyway never reads the preview's own
# writes as a hand edit.
#
# DELIBERATELY NO `class_name`: the compiler reaches it with a const preload.
@tool
extends RefCounted

## The line spliced after the head of each per-frame callback.
const GUARD_LINES: PackedStringArray = [
	"\tif Engine.is_editor_hint() and not _previewing:",
	"\t\treturn",
]


## The tooltip both buttons carry.
const BUTTON_TIP: String = "Plays in the editor. Your scene is not changed."


## The class-level block, as source lines. `begin_code` runs when Preview is pressed (and again every
## `repeat_expression` seconds while it plays, when that is given), `nudge_code` adds a Nudge button.
static func block_lines(begin_code: String, nudge_code: String, repeat_expression: String) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var has_nudge: bool = not nudge_code.strip_edges().is_empty()
	var has_repeat: bool = not repeat_expression.strip_edges().is_empty()
	lines.append("@warning_ignore(\"unused_private_class_variable\")")
	lines.append("## @ace_hidden")
	lines.append("## %s" % BUTTON_TIP)
	lines.append("@export_tool_button(\"Preview\", \"Play\") var _preview_start_button: Callable = _preview_start")
	lines.append("")
	lines.append("@warning_ignore(\"unused_private_class_variable\")")
	lines.append("## @ace_hidden")
	lines.append("## %s" % BUTTON_TIP)
	lines.append("@export_tool_button(\"Stop preview\", \"Stop\") var _preview_stop_button: Callable = _preview_stop")
	if has_nudge:
		lines.append("")
		lines.append("@warning_ignore(\"unused_private_class_variable\")")
		lines.append("## @ace_hidden")
		lines.append("## Sets the effect off in the editor. Your scene is not changed.")
		lines.append("@export_tool_button(\"Nudge\", \"ToolMove\") var _preview_nudge_button: Callable = _preview_nudge")
	lines.append("")
	lines.append("## The Engine meta key every previewing behaviour shares for its table of rest values, one entry per host.")
	lines.append("const _PREVIEW_TABLE_META: String = \"_eventsheets_previews\"")
	lines.append("")
	lines.append("## The key of a table entry's remembered rest values.")
	lines.append("const _PREVIEW_REST: String = \"rest\"")
	lines.append("")
	lines.append("## The key of a table entry's count of behaviours previewing on that host.")
	lines.append("const _PREVIEW_USERS: String = \"users\"")
	lines.append("")
	lines.append("## The key of a table entry's host values as the preview last left them, to tell a hand edit from the preview's own writes.")
	lines.append("const _PREVIEW_SEEN: String = \"seen\"")
	lines.append("")
	lines.append("## The Engine meta key that holds the editor's own low-processor setting while any preview plays, so it can be put back.")
	lines.append("const _PREVIEW_IDLE_META: String = \"_eventsheets_previews_low_processor\"")
	lines.append("")
	lines.append("## True while Preview is playing in the editor. Always false in a running game.")
	lines.append("var _previewing: bool = false")
	lines.append("")
	lines.append("## Counts the Preview presses, so a repeat loop from an earlier press ends.")
	lines.append("var _preview_run: int = 0")
	lines.append("")
	lines.append("## This behaviour's own unsaved values from when Preview started, put back on Stop.")
	lines.append("var _preview_own: Dictionary = {}")
	lines.append("")
	lines.append("## True when the host's values were noted since the last check for a hand edit, so the note is fresh enough to trust.")
	lines.append("var _preview_noted: bool = false")
	lines.append("")
	lines.append("func _validate_property(property: Dictionary) -> void:")
	lines.append("\tif property.name == \"_preview_start_button\" and _previewing:")
	lines.append("\t\tproperty.usage = PROPERTY_USAGE_NONE")
	lines.append("\telif property.name == \"_preview_stop_button\" and not _previewing:")
	lines.append("\t\tproperty.usage = PROPERTY_USAGE_NONE")
	lines.append("")
	lines.append("func _notification(what: int) -> void:")
	lines.append("\tif not Engine.is_editor_hint() or not _previewing:")
	lines.append("\t\treturn")
	lines.append("\tif what == NOTIFICATION_EXIT_TREE:")
	lines.append("\t\t_preview_stop()")
	lines.append("\telif what == NOTIFICATION_EDITOR_PRE_SAVE:")
	lines.append("\t\t_preview_keep_hand_edits()")
	lines.append("\t\t_preview_put_back(host, _preview_rest_of(host))")
	lines.append("\t\t_preview_note_seen()")
	lines.append("")
	lines.append("static func _preview_values(node: Object, own: bool) -> Dictionary:")
	lines.append("\tvar values: Dictionary = {}")
	lines.append("\tfor info: Dictionary in node.get_property_list():")
	lines.append("\t\tvar usage: int = info.usage")
	lines.append("\t\tvar prop_name: String = info.name")
	lines.append("\t\tif info.type == TYPE_NIL or info.type == TYPE_CALLABLE or prop_name.contains(\"/\") or prop_name == \"script\" or prop_name == \"owner\":")
	lines.append("\t\t\tcontinue")
	lines.append("\t\tif own:")
	lines.append("\t\t\tif not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or (usage & PROPERTY_USAGE_STORAGE) or prop_name.begins_with(\"_preview\") or prop_name == \"host\":")
	lines.append("\t\t\t\tcontinue")
	lines.append("\t\telif not (usage & PROPERTY_USAGE_STORAGE):")
	lines.append("\t\t\tcontinue")
	lines.append("\t\tvar value: Variant = node.get(prop_name)")
	lines.append("\t\tvalues[prop_name] = value.duplicate() if (value is Array or value is Dictionary) else value")
	lines.append("\treturn values")
	lines.append("")
	lines.append("static func _preview_put_back(node: Object, values: Dictionary) -> void:")
	lines.append("\tif node == null or not is_instance_valid(node):")
	lines.append("\t\treturn")
	lines.append("\tfor prop_name: String in values:")
	lines.append("\t\tvar now: Variant = node.get(prop_name)")
	lines.append("\t\tvar rest: Variant = values[prop_name]")
	lines.append("\t\tif typeof(now) != typeof(rest) or now != rest:")
	lines.append("\t\t\tnode.set(prop_name, rest)")
	lines.append("")
	lines.append("static func _preview_table() -> Dictionary:")
	lines.append("\tif not Engine.has_meta(_PREVIEW_TABLE_META):")
	lines.append("\t\tEngine.set_meta(_PREVIEW_TABLE_META, {})")
	lines.append("\treturn Engine.get_meta(_PREVIEW_TABLE_META)")
	lines.append("")
	lines.append("func _preview_rest_of(node: Object) -> Dictionary:")
	lines.append("\tif node == null:")
	lines.append("\t\treturn {}")
	lines.append("\tvar entry: Dictionary = _preview_table().get(node.get_instance_id(), {})")
	lines.append("\treturn entry.get(_PREVIEW_REST, {})")
	lines.append("")
	lines.append("func _preview_start() -> void:")
	lines.append("\tif not Engine.is_editor_hint() or _previewing or host == null or not is_inside_tree():")
	lines.append("\t\treturn")
	lines.append("\tvar table: Dictionary = _preview_table()")
	lines.append("\tvar key: int = host.get_instance_id()")
	lines.append("\tif table.has(key):")
	lines.append("\t\t_preview_put_back(host, table[key][_PREVIEW_REST])")
	lines.append("\t\ttable[key][_PREVIEW_USERS] += 1")
	lines.append("\telse:")
	lines.append("\t\ttable[key] = {_PREVIEW_REST: _preview_values(host, false), _PREVIEW_USERS: 1}")
	lines.append("\t_preview_own = _preview_values(self, true)")
	lines.append("\t_previewing = true")
	lines.append("\t_preview_run += 1")
	lines.append("\tnotify_property_list_changed()")
	lines.append("\t_preview_kick()")
	if has_repeat:
		lines.append("\t_preview_repeat(_preview_run)")
	lines.append("\t_preview_watch_begin()")
	lines.append("")
	lines.append("## Starts watching for a hand edit: notes the host as it stands now, then again just before each drawn frame, and")
	lines.append("## checks at the start of each physics and process frame, before anything has written to the host that frame.")
	lines.append("func _preview_watch_begin() -> void:")
	lines.append("\tif not Engine.has_meta(_PREVIEW_IDLE_META):")
	lines.append("\t\tEngine.set_meta(_PREVIEW_IDLE_META, OS.low_processor_usage_mode)")
	lines.append("\t\tOS.low_processor_usage_mode = false")
	lines.append("\t_preview_note_seen()")
	lines.append("\tvar tree: SceneTree = get_tree()")
	lines.append("\tif not RenderingServer.frame_pre_draw.is_connected(_preview_note_seen):")
	lines.append("\t\tRenderingServer.frame_pre_draw.connect(_preview_note_seen)")
	lines.append("\tif tree != null and not tree.physics_frame.is_connected(_preview_watch):")
	lines.append("\t\ttree.physics_frame.connect(_preview_watch)")
	lines.append("\tif tree != null and not tree.process_frame.is_connected(_preview_watch):")
	lines.append("\t\ttree.process_frame.connect(_preview_watch)")
	lines.append("")
	lines.append("func _preview_watch_end() -> void:")
	lines.append("\t_preview_noted = false")
	lines.append("\tvar tree: SceneTree = Engine.get_main_loop() as SceneTree")
	lines.append("\tif RenderingServer.frame_pre_draw.is_connected(_preview_note_seen):")
	lines.append("\t\tRenderingServer.frame_pre_draw.disconnect(_preview_note_seen)")
	lines.append("\tif tree != null and tree.physics_frame.is_connected(_preview_watch):")
	lines.append("\t\ttree.physics_frame.disconnect(_preview_watch)")
	lines.append("\tif tree != null and tree.process_frame.is_connected(_preview_watch):")
	lines.append("\t\ttree.process_frame.disconnect(_preview_watch)")
	lines.append("")
	lines.append("## Writes the host's values down as the preview leaves them. Taken just before a frame is drawn, it is what the")
	lines.append("## next frame's check compares the host with.")
	lines.append("func _preview_note_seen() -> void:")
	lines.append("\tif not is_instance_valid(host):")
	lines.append("\t\treturn")
	lines.append("\tvar entry: Dictionary = _preview_table().get(host.get_instance_id(), {})")
	lines.append("\tif entry.is_empty():")
	lines.append("\t\treturn")
	lines.append("\tentry[_PREVIEW_SEEN] = _preview_values(host, false)")
	lines.append("\t_preview_noted = true")
	lines.append("")
	lines.append("## Takes anything on the host that is not what the preview last left there as the host's new resting value, so")
	lines.append("## Stop and a save keep it. Returns whether there was any. A note that has not been refreshed since the last check")
	lines.append("## is stale and proves nothing, so then there is nothing to keep.")
	lines.append("func _preview_keep_hand_edits() -> bool:")
	lines.append("\tif not _preview_noted or not is_instance_valid(host):")
	lines.append("\t\treturn false")
	lines.append("\tvar entry: Dictionary = _preview_table().get(host.get_instance_id(), {})")
	lines.append("\tif not entry.has(_PREVIEW_SEEN):")
	lines.append("\t\treturn false")
	lines.append("\tvar seen: Dictionary = entry[_PREVIEW_SEEN]")
	lines.append("\tvar rest: Dictionary = entry.get(_PREVIEW_REST, {})")
	lines.append("\tvar kept: bool = false")
	lines.append("\tfor prop_name: String in seen:")
	lines.append("\t\tvar now: Variant = host.get(prop_name)")
	lines.append("\t\tvar before: Variant = seen[prop_name]")
	lines.append("\t\tif typeof(now) != typeof(before) or now != before:")
	lines.append("\t\t\trest[prop_name] = now.duplicate() if (now is Array or now is Dictionary) else now")
	lines.append("\t\t\tkept = true")
	lines.append("\treturn kept")
	lines.append("")
	lines.append("## Runs at the start of every physics and process frame, once per drawn frame: a hand edit ends the preview and keeps the edit.")
	lines.append("func _preview_watch() -> void:")
	lines.append("\tif not _previewing or not _preview_noted:")
	lines.append("\t\treturn")
	lines.append("\tif _preview_keep_hand_edits():")
	lines.append("\t\t_preview_stop()")
	lines.append("\t_preview_noted = false")
	lines.append("")
	lines.append("func _preview_stop() -> void:")
	lines.append("\tif not _previewing:")
	lines.append("\t\treturn")
	lines.append("\t_preview_keep_hand_edits()")
	lines.append("\t_preview_watch_end()")
	lines.append("\t_previewing = false")
	lines.append("\t_preview_kill_tweens()")
	lines.append("\t_preview_put_back(self, _preview_own)")
	lines.append("\tvar table: Dictionary = _preview_table()")
	lines.append("\tvar key: int = host.get_instance_id() if host != null else 0")
	lines.append("\tif table.has(key):")
	lines.append("\t\t_preview_put_back(host, table[key][_PREVIEW_REST])")
	lines.append("\t\ttable[key][_PREVIEW_USERS] -= 1")
	lines.append("\t\tif table[key][_PREVIEW_USERS] <= 0:")
	lines.append("\t\t\ttable.erase(key)")
	lines.append("\tif table.is_empty() and Engine.has_meta(_PREVIEW_IDLE_META):")
	lines.append("\t\tOS.low_processor_usage_mode = Engine.get_meta(_PREVIEW_IDLE_META)")
	lines.append("\t\tEngine.remove_meta(_PREVIEW_IDLE_META)")
	lines.append("\tnotify_property_list_changed()")
	lines.append("")
	lines.append("func _preview_kill_tweens() -> void:")
	lines.append("\tfor info: Dictionary in get_property_list():")
	lines.append("\t\tif not (info.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or info.name == \"host\":")
	lines.append("\t\t\tcontinue")
	lines.append("\t\tvar held: Variant = get(info.name)")
	lines.append("\t\tvar live_tweens: Array = []")
	lines.append("\t\tif held is Tween:")
	lines.append("\t\t\tlive_tweens.append(held)")
	lines.append("\t\telif held is Dictionary:")
	lines.append("\t\t\tlive_tweens.append_array((held as Dictionary).values())")
	lines.append("\t\telif held is Array:")
	lines.append("\t\t\tlive_tweens.append_array(held)")
	lines.append("\t\tfor candidate: Variant in live_tweens:")
	lines.append("\t\t\tif candidate is Tween and (candidate as Tween).is_valid():")
	lines.append("\t\t\t\t(candidate as Tween).kill()")
	lines.append("")
	lines.append("func _preview_kick() -> void:")
	var kick_lines: PackedStringArray = _indented(begin_code)
	if kick_lines.is_empty():
		kick_lines.append("\tpass")
	lines.append_array(kick_lines)
	if has_repeat:
		lines.append("")
		lines.append("func _preview_repeat(run: int) -> void:")
		lines.append("\twhile true:")
		lines.append("\t\tawait get_tree().create_timer(maxf(%s, 0.1)).timeout" % repeat_expression.strip_edges())
		lines.append("\t\tif not _previewing or run != _preview_run:")
		lines.append("\t\t\treturn")
		lines.append("\t\t_preview_kick()")
	if has_nudge:
		lines.append("")
		lines.append("func _preview_nudge() -> void:")
		lines.append("\t_preview_start()")
		lines.append("\tif not _previewing:")
		lines.append("\t\treturn")
		lines.append_array(_indented(nudge_code))
	return lines


## Splices the guard after the head of every per-frame callback in `lines` (compiled output), and
## moves the source-map spans that sit below each splice. Returns how many callbacks were guarded.
static func guard_callbacks(lines: PackedStringArray, source_map: Array) -> int:
	var guarded: int = 0
	var index: int = lines.size() - 1
	while index >= 0:
		var line: String = lines[index]
		if line.begins_with("func _process(") or line.begins_with("func _physics_process("):
			# `index` is the 0-based position of the head; the head is 1-based line `index + 1`.
			for added: int in range(GUARD_LINES.size()):
				lines.insert(index + 1 + added, GUARD_LINES[added])
			for entry: Variant in source_map:
				if not (entry is Dictionary):
					continue
				var span: Dictionary = entry as Dictionary
				if int(span.get("start", 0)) > index + 1:
					span["start"] = int(span["start"]) + GUARD_LINES.size()
				if int(span.get("end", 0)) > index + 1:
					span["end"] = int(span["end"]) + GUARD_LINES.size()
			guarded += 1
		index -= 1
	return guarded


static func _indented(code: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for code_line: String in code.split("\n"):
		if code_line.strip_edges().is_empty():
			continue
		out.append("\t" + code_line)
	return out
