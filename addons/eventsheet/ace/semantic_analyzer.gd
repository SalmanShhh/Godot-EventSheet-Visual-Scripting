@tool
class_name EventSheetSemanticAnalyzer
extends RefCounted

func parse_source_metadata(script: Script) -> Dictionary:
    var metadata := {
        "class_name": "",
        "class_description": "",
        "tags": [],
        "signals": {},
        "methods": {},
        "properties": {}
    }
    if script == null or script.resource_path.is_empty() or not FileAccess.file_exists(script.resource_path):
        return metadata
    var source: String = FileAccess.get_file_as_string(script.resource_path)
    var pending_directives: Array[String] = []
    var pending_export: bool = false
    for raw_line in source.split("\n"):
        var stripped: String = raw_line.strip_edges()
        if stripped.is_empty():
            continue
        if stripped.begins_with("class_name ") or stripped.begins_with("extends "):
            # Leading `##` doc lines become the provider's description (zero-config addon
            # metadata: everything derives from the script itself, no manifest).
            if str(metadata["class_description"]).is_empty():
                var doc_lines: Array[String] = []
                for pending in pending_directives:
                    if pending.begins_with("@ace_tags"):
                        # `@ace_tags(movement, retro, jam)` -> provider tags (searchable
                        # in the picker, filterable over MCP, shown in tooltips).
                        for raw_tag in _extract_annotation_value(pending).split(","):
                            if not raw_tag.strip_edges().is_empty():
                                (metadata["tags"] as Array).append(raw_tag.strip_edges())
                    elif not pending.begins_with("@ace_"):
                        doc_lines.append(pending)
                metadata["class_description"] = " ".join(doc_lines).strip_edges()
            pending_directives.clear()
            pending_export = false
            if stripped.begins_with("class_name "):
                metadata["class_name"] = stripped.trim_prefix("class_name ").strip_edges()
            continue
        if stripped.begins_with("##"):
            pending_directives.append(stripped.trim_prefix("##").strip_edges())
            continue
        if stripped.begins_with("@ace_"):
            pending_directives.append(stripped)
            continue
        if stripped.begins_with("@export"):
            pending_export = true
            var inline_property_name: String = _parse_var_name(stripped)
            if not inline_property_name.is_empty():
                metadata["properties"][inline_property_name] = _build_overrides(pending_directives, true)
                pending_directives.clear()
                pending_export = false
            continue
        if stripped.begins_with("signal "):
            var signal_name: String = _parse_signal_name(stripped)
            metadata["signals"][signal_name] = _build_overrides(pending_directives)
            pending_directives.clear()
            pending_export = false
            continue
        if stripped.begins_with("func "):
            var method_name: String = _parse_func_name(stripped)
            metadata["methods"][method_name] = _build_overrides(pending_directives)
            pending_directives.clear()
            pending_export = false
            continue
        if pending_export and stripped.begins_with("var "):
            var property_name: String = _parse_var_name(stripped)
            metadata["properties"][property_name] = _build_overrides(pending_directives, true)
            pending_directives.clear()
            pending_export = false
            continue
        if not stripped.begins_with("@"):
            pending_directives.clear()
            pending_export = false
    return metadata

func get_provider_id(target: Object, source_metadata: Dictionary) -> String:
    var class_name_text: String = str(source_metadata.get("class_name", ""))
    if not class_name_text.is_empty():
        return class_name_text
    var script: Script = target.get_script() as Script
    if script != null and not script.resource_path.is_empty():
        return script.resource_path.get_file().get_basename().capitalize()
    return target.get_class()

func build_property_display_name(name: String) -> String:
    return _humanize_identifier(name)

func build_method_display_name(name: String, ace_type: int) -> String:
    var normalized: String = name
    if ace_type == ACEDefinition.ACEType.CONDITION and normalized.begins_with("is_"):
        normalized = normalized.trim_prefix("is_")
    elif ace_type == ACEDefinition.ACEType.EXPRESSION and normalized.begins_with("get_"):
        normalized = normalized.trim_prefix("get_")
    return _humanize_identifier(normalized)

func build_trigger_display_name(signal_name: String) -> String:
    return "On %s" % _humanize_identifier(signal_name)

func _build_overrides(directives: Array[String], exported: bool = false) -> Dictionary:
    var overrides := {
        "exported": exported,
        "hidden": false,
        "category": "",
        "name": "",
        "description": "",
        "icon": "",
        "forced_ace_type": -1
    }
    for directive_text in directives:
        var directive: String = directive_text.strip_edges()
        if directive.begins_with("@ace_hidden"):
            overrides["hidden"] = true
        elif directive.begins_with("@ace_category"):
            overrides["category"] = _extract_annotation_value(directive)
        elif directive.begins_with("@ace_name"):
            overrides["name"] = _extract_annotation_value(directive)
        elif directive.begins_with("@ace_description"):
            overrides["description"] = _extract_annotation_value(directive)
        elif directive.begins_with("@ace_icon"):
            overrides["icon"] = _extract_annotation_value(directive)
        elif directive.begins_with("@ace_action"):
            overrides["forced_ace_type"] = ACEDefinition.ACEType.ACTION
        elif directive.begins_with("@ace_condition"):
            overrides["forced_ace_type"] = ACEDefinition.ACEType.CONDITION
        elif directive.begins_with("@ace_expression"):
            overrides["forced_ace_type"] = ACEDefinition.ACEType.EXPRESSION
        elif directive.begins_with("@ace_trigger"):
            overrides["forced_ace_type"] = ACEDefinition.ACEType.TRIGGER
        elif directive.begins_with("@ace_display_template"):
            overrides["display_template"] = _extract_annotation_value(directive)
        elif directive.begins_with("@ace_codegen_template"):
            overrides["codegen_template"] = _extract_annotation_value(directive)
        elif directive.begins_with("@ace_param_options"):
            # `@ace_param_options(movement horizontal, vertical, angle)` -> the param
            # renders as a dropdown (C3's Combo) in the params dialog.
            var options_value: String = _extract_annotation_value(directive)
            var options_split: PackedStringArray = options_value.split(" ", false, 1)
            if options_split.size() == 2:
                var param_options: Dictionary = overrides.get("param_options", {})
                var option_values: Array = []
                for raw_option in options_split[1].split(","):
                    if not raw_option.strip_edges().is_empty():
                        option_values.append(raw_option.strip_edges())
                param_options[options_split[0].strip_edges()] = option_values
                overrides["param_options"] = param_options
        elif directive.begins_with("@ace_param_hint"):
            # `@ace_param_hint(amount expression)` → param "amount" gets hint "expression"
            # (drives the params dialog: expression ƒx field, variable_reference dropdown…).
            var hint_parts: PackedStringArray = _extract_annotation_value(directive).split(" ", false)
            if hint_parts.size() >= 2:
                var param_hints: Dictionary = overrides.get("param_hints", {})
                param_hints[hint_parts[0].strip_edges().trim_suffix(",")] = hint_parts[1].strip_edges()
                overrides["param_hints"] = param_hints
    return overrides

func _extract_annotation_value(text: String) -> String:
    var open_index: int = text.find("(")
    var close_index: int = text.rfind(")")
    if open_index != -1 and close_index > open_index:
        return text.substr(open_index + 1, close_index - open_index - 1).strip_edges().trim_prefix("\"").trim_suffix("\"")
    var parts: PackedStringArray = text.split(" ", false, 1)
    if parts.size() > 1:
        return parts[1].strip_edges().trim_prefix("\"").trim_suffix("\"")
    return ""

func _parse_signal_name(line: String) -> String:
    var rest: String = line.trim_prefix("signal ").strip_edges()
    var delimiter_index: int = rest.find("(")
    if delimiter_index == -1:
        delimiter_index = rest.length()
    return rest.substr(0, delimiter_index).strip_edges()

func _parse_func_name(line: String) -> String:
    var rest: String = line.trim_prefix("func ").strip_edges()
    var delimiter_index: int = rest.find("(")
    if delimiter_index == -1:
        delimiter_index = rest.length()
    return rest.substr(0, delimiter_index).strip_edges()

func _parse_var_name(line: String) -> String:
    var var_index: int = line.find("var ")
    if var_index == -1:
        return ""
    var rest: String = line.substr(var_index + 4).strip_edges()
    for separator in [":", "=", " "]:
        var separator_index: int = rest.find(separator)
        if separator_index != -1:
            rest = rest.substr(0, separator_index)
            break
    return rest.strip_edges()

func _humanize_identifier(text: String) -> String:
    if text.is_empty():
        return ""
    var builder: String = ""
    for index in range(text.length()):
        var current: String = text.substr(index, 1)
        var previous: String = text.substr(index - 1, 1) if index > 0 else ""
        if current == "_":
            builder += " "
            continue
        if index > 0 and current == current.to_upper() and previous != previous.to_upper() and previous != "_":
            builder += " "
        builder += current
    var words: PackedStringArray = builder.split(" ", false)
    for word_index in range(words.size()):
        var word: String = words[word_index].strip_edges()
        if word.is_empty():
            continue
        words[word_index] = word.substr(0, 1).to_upper() + word.substr(1).to_lower()
    return " ".join(words)
