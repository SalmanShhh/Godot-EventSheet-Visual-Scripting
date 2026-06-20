# EventForge — EventSheet resource
# Top-level event sheet resource attached to one host node.
# The @icon makes sheets recognizable at a glance in the FileSystem dock and the
# Create Resource dialog instead of reading as generic .tres files.
@tool
@icon("res://addons/eventsheet/icons/eventsheet.svg")
extends Resource
class_name EventSheetResource

@export var host_class: String = "Node"
@export var host_node_path: NodePath = NodePath(".")
## Behavior sheets compile to attachable Node component scripts (Construct 3 behaviors,
## Godot-style): the script extends Node, acts on its PARENT via the generated `host`
## accessor, and host_class becomes the declared/required host type (typed accessor +
## attach-time warning + lint/completion context).
@export var behavior_mode: bool = false
## Autoload (Singleton) sheets: compiles to an `extends Node` class meant to be
## registered as a project autoload under autoload_name — Game State, Event Bus,
## Save System and friends, project-wide. Exposed functions publish ACEs that call
## through the autoload name (`GameState.add_score(...)`), usable from every sheet.
@export var autoload_mode: bool = false
@export var autoload_name: String = ""
## EXPERIMENTAL (editor-version-coupled): emits `@tool` so the generated script runs
## inside the editor. Combine with host_class "EditorScript" + the On Editor Run trigger
## to build editor tooling from events (File > Run / Ctrl+Shift+X). Runtime ACEs stay on
## stable APIs only — editor APIs are Godot's most volatile surface.
@export var tool_mode: bool = false
## Debug compile: emit `breakpoint` statements for rows flagged via the gutter (F9).
@export var emit_breakpoints: bool = false
## Debug compile: stream this sheet's variables to the editor's Live Values window
## (throttled EngineDebugger messages from _process — plain core-Godot API, debug
## compiles only; normal compiles never carry it).
@export var emit_live_values: bool = false
## Live event trace (debugging rung 3): with Live Values on, each event appends its UID to a
## buffer as it fires, streamed each tick over the same channel so the editor can HIGHLIGHT the
## firing rows in real time. Debug compiles only; plain core-Godot API (EngineDebugger); off in
## normal compiles. Piggybacks on the Live Values _process, so it needs Live Values + variables.
@export var emit_event_trace: bool = false
## When set, the generated script declares `class_name <this>` — the sheet then defines a
## custom node type that appears in Godot's Create Node dialog, exactly like a hand-written
## GDScript class. Must be unique across the project (Godot enforces this).
@export var custom_class_name: String = ""
## Addon tags (C3-style: organize/filter your addon library): emitted as a class-level
## `@ace_tags(...)` annotation, searchable in the picker and over MCP.
@export var addon_tags: PackedStringArray = PackedStringArray()
## Optional icon for the custom node type (emitted as `@icon("path")`; shown in the Create
## Node dialog and scene tree). 16×16 SVG recommended, like engine icons.
@export_file("*.svg", "*.png") var custom_class_icon: String = ""
@export var events: Array[Resource] = []
@export var variables: Dictionary = {}
## Compile-time includes (C3-style): paths to other event sheets (res://….tres) whose
## variables, class-level blocks, events, and functions merge into this sheet's generated
## script. The root sheet wins name collisions (warnings emitted); cycles are detected and
## skipped. Edited via the Inspector; ignored for GDScript-backed sheets.
@export var includes: Array[String] = []
## Lane B composition (has-a): addon CLASS NAMES this sheet uses as owned helper
## instances — each emits `var __uses_<snake> := <Class>.new()` so ƒx/blocks can call
## them (suits RefCounted provider/helper addons; Node-behavior auto-attach is the
## planned Lane B.2). See docs/ADDON-COMPOSITION-SPEC.md.
@export var uses_addons: Array[String] = []
## Lane B.2 composition: behavior CLASS NAMES this pack expects as SIBLING nodes —
## compiles to _get_configuration_warnings(), so Godot shows the ⚠ badge when a
## dependency is missing (the Unity RequireComponent idiom, warning-only by design).
@export var requires_behaviors: Array[String] = []
@export var functions: Array[Resource] = []
@export var editor_style: EventSheetEditorStyle = null
## Paths to GDScript files registered as custom-ACE providers. Each script is
## instantiated and reflected so its annotated methods/signals/exported properties
## appear in the ACE picker as conditions/actions/triggers/expressions.
@export var ace_provider_scripts: Array[String] = []
## Non-empty when this sheet was opened FROM a GDScript file (GDScript-backed sheet): the
## .gd file is the single source of truth — saving compiles back to it (order-preserving,
## no generated header), and no .tres exists unless the user saves-as. See
## docs/GDSCRIPT-PAIRING-SPEC.md "Open any GDScript as a sheet".
@export var external_source_path: String = ""
## When true this sheet is a read-only PREVIEW (e.g. a .gd opened just to look at it): the
## editor blocks all mutations and refuses to save back over the source file. Clearing it
## (the banner's "Edit Events" button) re-enables normal editing. Preview is the safe default
## when opening a .gd, so a casual look can never overwrite a hand-written script.
@export var read_only: bool = false
