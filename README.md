# GodotEventSheet — EventForge

Construct 3–style event sheet visual scripting for Godot 4.x. Compiles to clean, readable GDScript at save time. No runtime interpreter.

> 🚧 **Status:** Phase 1 scaffold in progress. See the open PR.

## What This Is

EventForge is a Godot editor plugin that adds a first-class **Event Sheet** editor to the Godot editor UI. Designers and developers author game logic visually using the familiar **Event → Condition → Action** paradigm, while staying fully interoperable with GDScript through code generation and signal bridging.

- ✅ Compiles to GDScript — zero runtime overhead
- ✅ One sheet, one host node
- ✅ Bidirectional with GDScript: import any `.gd`, bind to any function, toggle views
- ✅ Full C3 parity: events, conditions, actions, sub-events, else/elif, loops, picking, edge triggers, functions, groups, comments

## Roadmap

See `docs/SPEC.md` (added in Phase 1) for the full specification and phase-by-phase roadmap.

## License

MIT
