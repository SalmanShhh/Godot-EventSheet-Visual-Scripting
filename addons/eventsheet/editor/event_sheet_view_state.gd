# Godot EventSheets — per-sheet shared view state (multi-view phase 1)
# Breakpoints, bookmarks, and the runtime disabled-state overlay are PER-SHEET facts:
# when the same sheet is open in multiple panes, every view must agree on them. Each
# viewport adopts these dictionaries by reference (Godot Dictionaries are shared), while
# per-view state (scroll, zoom, selection, folds, inline edits) stays on the viewport.
# See EDITOR-UI-SPEC "Multi-view".
@tool
extends RefCounted
class_name EventSheetViewState

var breakpoint_rows: Dictionary = {}
var bookmark_rows: Dictionary = {}
var row_disabled_state: Dictionary = {}
