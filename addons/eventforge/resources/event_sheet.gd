# EventForge — EventSheet resource
# Top-level event sheet resource attached to one host node.
@tool
extends Resource
class_name EventSheetResource

@export var host_class: String = "Node"
@export var host_node_path: NodePath = NodePath(".")
## Behavior sheets compile to attachable Node component scripts (Construct 3 behaviors,
## Godot-style): the script extends Node, acts on its PARENT via the generated `host`
## accessor, and host_class becomes the declared/required host type (typed accessor +
## attach-time warning + lint/completion context).
@export var behavior_mode: bool = false
## When set, the generated script declares `class_name <this>` — the sheet then defines a
## custom node type that appears in Godot's Create Node dialog, exactly like a hand-written
## GDScript class. Must be unique across the project (Godot enforces this).
@export var custom_class_name: String = ""
## Optional icon for the custom node type (emitted as `@icon("path")`; shown in the Create
## Node dialog and scene tree). 16×16 SVG recommended, like engine icons.
@export_file("*.svg", "*.png") var custom_class_icon: String = ""
@export var events: Array[Resource] = []
@export var variables: Dictionary = {}
@export var includes: Array[NodePath] = []
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
