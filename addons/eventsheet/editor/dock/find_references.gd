# EventSheet — symbol-aware Find References / Go-to-Definition.
#
# Project Find matches substrings; this matches whole symbols (\bname\b), so searching
# `speed` finds the variable `speed` but NOT `move_speed` or the word "speed" mid-identifier.
# It tags each hit with the surface it lives in (param / code / pick / comment / group), and
# can resolve a symbol's DEFINITION (a sheet variable, function, signal, or local var). The
# same walk backs a rename PREVIEW, so a project-wide rename shows what it will touch first.
@tool
class_name EventSheetFindReferences
extends RefCounted

## Whole-symbol references to `symbol` in one sheet: [{kind, count, preview}].
static func find_in_sheet(sheet: EventSheetResource, symbol: String) -> Array:
    var results: Array = []
    if sheet == null or symbol.strip_edges().is_empty():
        return results
    var regex: RegEx = RegEx.create_from_string("\\b%s\\b" % _escape(symbol.strip_edges()))
    if regex == null:
        return results
    var fragments: Array = []
    _collect(sheet.events, fragments)
    for function_entry: Variant in sheet.functions:
        if function_entry is EventFunction:
            _collect((function_entry as EventFunction).events if not (function_entry as EventFunction).events.is_empty() else (function_entry as EventFunction).rows, fragments)
    for fragment: Dictionary in fragments:
        var hits: Array = regex.search_all(str(fragment.get("text", "")))
        if not hits.is_empty():
            results.append({
                "kind": str(fragment.get("kind", "")),
                "count": hits.size(),
                "preview": _preview(str(fragment.get("text", "")), (hits[0] as RegExMatch).get_start())
            })
    return results

## Project-wide references: [{sheet, count, references}] for every sheet that uses `symbol`.
static func find_in_project(symbol: String) -> Array:
    var found: Array = []
    for path: String in EventSheetProjectFind.list_project_sheets():
        var sheet: EventSheetResource = load(path) as EventSheetResource
        if sheet == null:
            continue
        var references: Array = find_in_sheet(sheet, symbol)
        var total: int = 0
        for reference: Dictionary in references:
            total += int(reference.get("count", 0))
        if total > 0:
            found.append({"sheet": path, "count": total, "references": references})
    return found

## Where `symbol` is DEFINED in this sheet: {kind, found}. kind ∈ variable / function /
## signal / local / "" (not defined here).
static func find_definition(sheet: EventSheetResource, symbol: String) -> Dictionary:
    if sheet == null:
        return {"kind": "", "found": false}
    var name: String = symbol.strip_edges()
    if sheet.variables.has(name):
        return {"kind": "variable", "found": true}
    for function_entry: Variant in sheet.functions:
        if function_entry is EventFunction and (function_entry as EventFunction).function_name == name:
            return {"kind": "function", "found": true}
    var definition: Dictionary = {"kind": "", "found": false}
    _scan_definitions(sheet.events, name, definition)
    return definition

## Validate + count: what a rename of `old_name`→`new_name` would touch, BEFORE applying.
## {valid, error, reference_count, references}.
static func rename_preview(sheet: EventSheetResource, old_name: String, new_name: String) -> Dictionary:
    var error: String = EventSheetRefactor.validate_new_name(sheet, old_name, new_name)
    var references: Array = find_in_sheet(sheet, old_name)
    var count: int = 0
    for reference: Dictionary in references:
        count += int(reference.get("count", 0))
    return {"valid": error.is_empty(), "error": error, "reference_count": count, "references": references}

static func _scan_definitions(rows: Array, name: String, into: Dictionary) -> void:
    for row: Variant in rows:
        if into.get("found", false):
            return
        if row is LocalVariable and (row as LocalVariable).name == name:
            into["kind"] = "local"
            into["found"] = true
            return
        elif row is SignalRow and (row as SignalRow).signal_name == name:
            into["kind"] = "signal"
            into["found"] = true
            return
        elif row is EventGroup:
            _scan_definitions((row as EventGroup).events if not (row as EventGroup).events.is_empty() else (row as EventGroup).rows, name, into)
        elif row is EventRow:
            _scan_definitions((row as EventRow).sub_events, name, into)

## Findable text fragments tagged with their surface. Parallels project_find's collector but
## keeps the surface kind so references read "in a param" vs "in a comment".
static func _collect(rows: Array, into: Array) -> void:
    for row: Variant in rows:
        if row is CommentRow:
            into.append({"text": (row as CommentRow).text, "kind": "comment"})
        elif row is RawCodeRow:
            into.append({"text": (row as RawCodeRow).code, "kind": "code"})
        elif row is LocalVariable:
            into.append({"text": (row as LocalVariable).name, "kind": "local"})
        elif row is SignalRow:
            into.append({"text": (row as SignalRow).signal_name + " " + " ".join((row as SignalRow).params), "kind": "signal"})
        elif row is EventGroup:
            into.append({"text": (row as EventGroup).group_name, "kind": "group"})
            _collect((row as EventGroup).events if not (row as EventGroup).events.is_empty() else (row as EventGroup).rows, into)
        elif row is EventRow:
            var event_row: EventRow = row as EventRow
            for ace: Variant in event_row.conditions + event_row.actions:
                if ace is RawCodeRow:
                    into.append({"text": (ace as RawCodeRow).code, "kind": "code"})
                elif ace is Resource and ace.get("params") is Dictionary:
                    if ace.get("comment") is String and not str(ace.get("comment")).is_empty():
                        into.append({"text": str(ace.get("comment")), "kind": "comment"})
                    for value: Variant in (ace.get("params") as Dictionary).values():
                        if value is String:
                            into.append({"text": value, "kind": "param"})
            for pick: Variant in event_row.pick_filters:
                if pick is PickFilter:
                    into.append({"text": (pick as PickFilter).collection_value + " " + (pick as PickFilter).predicate_expression, "kind": "pick"})
            _collect(event_row.sub_events, into)

static func _preview(text: String, at: int) -> String:
    return text.substr(maxi(at - 18, 0), 62).replace("\n", " ").strip_edges()

## Identifiers are word chars only, but guard against regex metacharacters defensively.
static func _escape(symbol: String) -> String:
    var escaped: String = ""
    for character: String in symbol:
        if character.is_valid_identifier() or character.is_valid_int() or character == "_":
            escaped += character
        else:
            escaped += "\\" + character
    return escaped
