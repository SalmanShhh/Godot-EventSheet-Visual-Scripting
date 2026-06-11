# Godot EventSheets — the addon-author loop (dock subsystem)
#
# Extracted from EventSheetDock (decomposition arc, step 2): the Publish Preview
# window, the generated pack README, and the Test Bench. Surface collection and the
# README are pure statics over a sheet (the dock's delegates forward to them); the
# window/bench methods hold a dock back-reference for status, ownership and the
# current sheet.
@tool
extends RefCounted
class_name EventSheetAuthorLoop

var _dock: Control = null

func _init(dock: Control) -> void:
    _dock = dock


## Everything this sheet will publish to OTHER sheets' pickers, straight from the model
## (no compile round-trip): exposed functions, annotated block ACEs, signals-as-triggers
## and exported properties. Shared by the Publish Preview window and the pack README.
static func collect_publish_surface(sheet: EventSheetResource) -> Dictionary:
    var surface: Dictionary = {"actions": [], "triggers": [], "conditions": [], "expressions": [], "properties": []}
    if sheet == null:
        return surface
    var keys: Array = sheet.variables.keys()
    keys.sort()
    for key: Variant in keys:
        var descriptor: Variant = sheet.variables[key]
        if descriptor is Dictionary and bool((descriptor as Dictionary).get("exported", true)):
            (surface["properties"] as Array).append({
                "name": str(key),
                "type": str((descriptor as Dictionary).get("type", "Variant")),
                "default": (descriptor as Dictionary).get("default"),
                "attributes": (descriptor as Dictionary).get("attributes", {})
            })
    for function_entry: Variant in sheet.functions:
        if function_entry is EventFunction and (function_entry as EventFunction).expose_as_ace:
            var exposed: EventFunction = function_entry
            var param_names: PackedStringArray = PackedStringArray()
            for param: Variant in exposed.params:
                if param is ACEParam:
                    param_names.append("%s: %s" % [(param as ACEParam).id, (param as ACEParam).type_name])
            (surface["actions" if exposed.return_type == TYPE_NIL else "expressions"] as Array).append({
                "name": exposed.ace_display_name if not exposed.ace_display_name.is_empty() else exposed.function_name.capitalize(),
                "category": exposed.ace_category,
                "params": ", ".join(param_names),
                "description": exposed.description
            })
    # Annotated GDScript blocks: signals -> triggers, funcs -> conditions/expressions.
    var annotation_regex: RegEx = RegEx.new()
    annotation_regex.compile("## @ace_(trigger|condition|expression)\\b")
    var name_regex: RegEx = RegEx.new()
    name_regex.compile("## @ace_name\\(\"([^\"]+)\"\\)")
    var symbol_regex: RegEx = RegEx.new()
    symbol_regex.compile("(?m)^(?:signal|func)\\s+([A-Za-z_][A-Za-z0-9_]*)")
    for row: Variant in sheet.events:
        if not (row is RawCodeRow):
            continue
        var chunks: PackedStringArray = (row as RawCodeRow).code.split("\n\n")
        for chunk: String in chunks:
            var kind_match: RegExMatch = annotation_regex.search(chunk)
            if kind_match == null:
                continue
            var symbol_match: RegExMatch = symbol_regex.search(chunk)
            if symbol_match == null:
                continue
            var shown_match: RegExMatch = name_regex.search(chunk)
            var bucket: String = kind_match.get_string(1) + "s"
            (surface[bucket] as Array).append({
                "name": shown_match.get_string(1) if shown_match != null else symbol_match.get_string(1).capitalize(),
                "category": "", "params": "", "description": ""
            })
    return surface

var _publish_preview_window: Window = null
var _publish_preview_text: RichTextLabel = null

## Shows what THIS sheet publishes — refreshed from the live model on every open, so
## renaming a function updates the surface immediately (no compile-and-reopen loop).
func open_publish_preview() -> void:
    if _dock._current_sheet == null:
        return
    if _publish_preview_window == null:
        _publish_preview_window = Window.new()
        _publish_preview_window.title = "Publish Preview — what other sheets will see"
        _publish_preview_window.size = Vector2i(440, 460)
        _publish_preview_window.close_requested.connect(func() -> void: _publish_preview_window.hide())
        _publish_preview_text = RichTextLabel.new()
        _publish_preview_text.set_anchors_preset(Control.PRESET_FULL_RECT)
        _publish_preview_text.bbcode_enabled = true
        _publish_preview_window.add_child(_publish_preview_text)
        _dock.add_child(_publish_preview_window)
    _publish_preview_text.text = publish_surface_text(collect_publish_surface(_dock._current_sheet))
    _publish_preview_window.popup_centered()

## Renders a publish surface as readable BBCode (also testable headless).
static func publish_surface_text(surface: Dictionary) -> String:
    var sections: PackedStringArray = PackedStringArray()
    for bucket: String in ["triggers", "conditions", "actions", "expressions", "properties"]:
        var entries: Array = surface.get(bucket, [])
        if entries.is_empty():
            continue
        sections.append("[b]%s[/b]" % bucket.capitalize())
        for entry: Dictionary in entries:
            var line: String = "  • %s" % str(entry.get("name", ""))
            if not str(entry.get("params", "")).is_empty():
                line += " (%s)" % str(entry.get("params"))
            if not str(entry.get("category", "")).is_empty():
                line += "   [%s]" % str(entry.get("category"))
            if bucket == "properties":
                line = "  • %s: %s = %s" % [str(entry.get("name")), str(entry.get("type")), str(entry.get("default"))]
            sections.append(line)
    if sections.is_empty():
        return "Nothing published yet — expose a function as an ACE, or annotate a signal with @ace_trigger."
    return "\n".join(sections)

## Markdown sections for a publish surface — shared by the pack README and the project
## vocabulary doc (EventSheetVocabularyDoc). `heading` sets the section level so callers
## can nest the sections under their own headings.
static func surface_markdown(surface: Dictionary, heading: String = "##") -> PackedStringArray:
    var lines: PackedStringArray = PackedStringArray()
    for section_pair: Array in [["Properties", "properties"], ["Triggers", "triggers"], ["Conditions", "conditions"], ["Actions", "actions"], ["Expressions", "expressions"]]:
        var entries: Array = surface.get(section_pair[1], [])
        if entries.is_empty():
            continue
        lines.append("")
        lines.append("%s %s" % [heading, str(section_pair[0])])
        for entry: Dictionary in entries:
            if str(section_pair[1]) == "properties":
                var attributes: Dictionary = entry.get("attributes", {}) if entry.get("attributes") is Dictionary else {}
                var note: String = str(attributes.get("tooltip", ""))
                lines.append("- `%s: %s` (default `%s`)%s" % [str(entry.get("name")), str(entry.get("type")), str(entry.get("default")), " — " + note if not note.is_empty() else ""])
            else:
                var ace_line: String = "- **%s**" % str(entry.get("name"))
                if not str(entry.get("params", "")).is_empty():
                    ace_line += " (`%s`)" % str(entry.get("params"))
                if not str(entry.get("description", "")).is_empty():
                    ace_line += " — %s" % str(entry.get("description"))
                lines.append(ace_line)
    return lines

## The pack README: name/tags/host, properties with attributes, the full ACE surface,
## and composition dependencies — generated so shared packs are documented by default.
static func generate_pack_readme(sheet: EventSheetResource) -> String:
    var surface: Dictionary = collect_publish_surface(sheet)
    var lines: PackedStringArray = PackedStringArray()
    lines.append("# %s" % sheet.custom_class_name)
    lines.append("")
    lines.append("An EventSheets behavior pack (editable `.tres` sheet + compiled `.gd` script —")
    lines.append("the script is plain GDScript and runs without the plugin).")
    if not sheet.addon_tags.is_empty():
        lines.append("")
        lines.append("**Tags:** %s" % ", ".join(sheet.addon_tags))
    if sheet.behavior_mode:
        lines.append("")
        lines.append("**Attach to:** a child of any `%s` node." % sheet.host_class)
    lines.append_array(surface_markdown(surface))
    if not sheet.includes.is_empty() or not sheet.uses_addons.is_empty() or not sheet.requires_behaviors.is_empty():
        lines.append("")
        lines.append("## Dependencies")
        for include_path: String in sheet.includes:
            lines.append("- includes `%s` (bundled)" % include_path.get_file())
        for uses_class: String in sheet.uses_addons:
            lines.append("- uses `%s` (owned helper instance)" % uses_class)
        for requires_class: String in sheet.requires_behaviors:
            lines.append("- requires a `%s` sibling behavior" % requires_class)
    lines.append("")
    return "\n".join(lines)

## Test Bench: one click builds host + behavior scene from the CURRENT sheet and runs
## it — verify a behavior without hand-building a scene. The scene builder is the
## testable core; running needs the editor.
func open_test_bench() -> void:
    if _dock._current_sheet == null or not _dock._current_sheet.behavior_mode:
        _dock._set_status("Test Bench drives behavior sheets — set the type to Behavior first.", true)
        return
    var bench_error: String = build_test_bench(_dock._current_sheet, "res://.eventsheets_test_bench.tscn")
    if not bench_error.is_empty():
        _dock._set_status(bench_error, true)
        return
    if Engine.is_editor_hint() and _dock.is_inside_tree():
        EditorInterface.play_custom_scene("res://.eventsheets_test_bench.tscn")
        _dock._set_status("Test Bench running — Live Values shows the behavior's variables if enabled.")

## Builds + saves the bench scene (host of host_class + the compiled behavior child).
## Returns "" or the user-facing problem.
func build_test_bench(sheet: EventSheetResource, scene_path: String) -> String:
    var host_class: String = sheet.host_class if ClassDB.class_exists(sheet.host_class) else "Node2D"
    var bench_script_path: String = scene_path.get_basename() + ".gd"
    var compile_result: Dictionary = SheetCompiler.compile(sheet, bench_script_path)
    if not bool(compile_result.get("success", false)):
        return "Test Bench: the sheet doesn't compile (%s)." % str(compile_result.get("errors"))
    var host: Node = ClassDB.instantiate(host_class)
    host.name = "BenchHost"
    var behavior: Node = Node.new()
    behavior.name = sheet.custom_class_name if not sheet.custom_class_name.is_empty() else "Behavior"
    behavior.set_script(load(bench_script_path))
    host.add_child(behavior)
    behavior.owner = host
    var packed: PackedScene = PackedScene.new()
    if packed.pack(host) != OK:
        host.queue_free()
        return "Test Bench: couldn't pack the scene."
    var save_error: Error = ResourceSaver.save(packed, scene_path)
    host.queue_free()
    return "" if save_error == OK else "Test Bench: couldn't save %s (error %d)." % [scene_path, save_error]

