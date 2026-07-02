# EventForge — EventFunction resource
# Callable event-sheet function compiled to a GDScript function.
@tool
extends Resource
class_name EventFunction

@export var enabled: bool = true
@export var function_name: String = ""
@export var description: String = ""
## When true, the generated function carries `@ace_*` annotations, so dropping the compiled
## script into res://eventsheet_addons/ publishes this function as an ACE in every sheet —
## the sheet → script → addon loop that makes behaviors/custom nodes extend the vocabulary.
@export var expose_as_ace: bool = false
## Set when this function was reverse-lifted from a hand-written body that had NO `## @ace_*`
## annotation block (a plain helper in an opened .gd). Suppresses the `## @ace_hidden` emission the
## un-exposed path would otherwise add, so the source round-trips byte-identically. `expose_as_ace`
## stays false — re-exposing it (editing the function) clears this and restores normal annotations.
@export var lifted_unannotated: bool = false
## Odin-style [Button]: a non-empty label emits
## `@export_tool_button("Label") var _btn_<name>: Callable = <name>` so the Inspector
## shows a clickable button running this function. Needs a @tool sheet to act in-editor
## (the compiler warns otherwise). Godot 4.4+.
@export var tool_button_label: String = ""
## Optional ACE presentation when exposed (fall back to a humanized function name).
@export var ace_display_name: String = ""
@export var ace_category: String = ""
@export var params: Array[ACEParam] = []
@export var parameters: Array[String] = [] # Backwards-compatible alias.
@export var return_type: int = TYPE_NIL
## A return type `return_type` (a Variant.Type) can't name: a custom class (`HealthPool`), an engine
## class (`Camera2D`), or a typed collection. When set, the emitter uses it VERBATIM and ignores
## return_type — so a helper returning `-> HealthPool` lifts into a real, editable function instead
## of staying a raw block. Empty = use return_type as before.
@export var return_type_name: String = ""
@export var is_async: bool = false
@export var events: Array[Resource] = []
@export var rows: Array[Resource] = [] # Backwards-compatible alias.
@export var local_variables: Dictionary = {}
