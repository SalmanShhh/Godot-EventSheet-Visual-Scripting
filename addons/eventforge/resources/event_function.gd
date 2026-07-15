# EventForge - EventFunction resource
# Callable event-sheet function compiled to a GDScript function.
@tool
class_name EventFunction
extends Resource

@export var enabled: bool = true
@export var function_name: String = ""
@export var description: String = ""
## When true, the generated function carries `@ace_*` annotations, so dropping the compiled
## script into res://eventsheet_addons/ publishes this function as an ACE in every sheet -
## the sheet → script → addon loop that makes behaviors/custom nodes extend the vocabulary.
@export var expose_as_ace: bool = false
## Set when this function was reverse-lifted from a hand-written body that had NO `## @ace_*`
## annotation block (a plain helper in an opened .gd). Suppresses the `## @ace_hidden` emission the
## un-exposed path would otherwise add, so the source round-trips byte-identically. `expose_as_ace`
## stays false - re-exposing it (editing the function) clears this and restores normal annotations.
@export var lifted_unannotated: bool = false
## GDScript annotation lines kept VERBATIM (`@rpc(...)`, `@warning_ignore(...)`, `@abstract`, stacked), each
## emitted on its own line between the `## @ace_*` block and the `func` header - the GDScript convention.
## Set on lift from the leading annotation lines above a function and byte-gated, so a `@rpc` function opens as
## an editable function instead of a raw block. Empty = none.
@export var annotation_lines: PackedStringArray = PackedStringArray()
## Inspector button: a non-empty label emits
## `@export_tool_button("Label") var _btn_<name>: Callable = <name>` so the Inspector
## shows a clickable button running this function. Needs a @tool sheet to act in-editor
## (the compiler warns otherwise). Godot 4.4+.
@export var tool_button_label: String = ""
## Optional ACE presentation when exposed (fall back to a humanized function name).
@export var ace_display_name: String = ""
@export var ace_category: String = ""
## Optional readable sentence for the published-verb row, with {param_id} slots that show each
## parameter's label (e.g. "Draw line from ({from_x}, {from_y}) to ({to_x}, {to_y})"). Emitted as
## `## @ace_display_template("...")` and lifted back, so it round-trips. Empty = the row auto-derives
## a slot line from the name plus the humanized parameter ids.
@export var display_template: String = ""
@export var params: Array[ACEParam] = []
@export var parameters: Array[String] = [] # Backwards-compatible alias.
@export var return_type: int = TYPE_NIL
## A return type `return_type` (a Variant.Type) can't name: a custom class (`HealthPool`), an engine
## class (`Camera2D`), or a typed collection. When set, the emitter uses it VERBATIM and ignores
## return_type - so a helper returning `-> HealthPool` lifts into a real, editable function instead
## of staying a raw block. Empty = use return_type as before.
@export var return_type_name: String = ""
@export var is_async: bool = false
## When true, the generated function is emitted as `static func` (a class-level helper with no `self`).
## Set on lift from a `static func` header and re-emitted verbatim, so a static utility helper opens as a
## real editable function instead of a raw block. Default false keeps every existing function byte-identical.
@export var is_static: bool = false
@export var events: Array[Resource] = []
@export var rows: Array[Resource] = [] # Backwards-compatible alias.
@export var local_variables: Dictionary = {}
