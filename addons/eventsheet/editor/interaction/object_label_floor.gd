# Godot EventSheets - the widest object name of each lane, so the sheet's object column can hold it whole.
#
# The object column is a fixed width shared by every row of a lane, which kept a long class name
# ("ScriptRowsAnnotatedTwin") cut to "ScriptRowsAnnotatedT..." in a lane with room to spare. The viewport asks
# for the widest name drawn in each lane and widens the column to it, up to the share of the lane the
# column may take. Loaded by path by the viewport, so the editor's first open compiles none of it.
@tool
extends RefCounted


## {lane: widest object name in pixels} for `viewport`, measured again only when its rows were built
## again, its fold changed what is flattened, or its font changed. Kept on the viewport itself.
static func floors_for(viewport: Control) -> Dictionary:
	var key: int = hash([viewport._row_builds, viewport._flat_generation, viewport._get_font_size()])
	var held: Dictionary = viewport.get_meta(&"object_label_floors", {})
	if int(held.get("key", 0)) != key or not held.has("floors"):
		held = {"key": key, "floors": measure(viewport)}
		viewport.set_meta(&"object_label_floors", held)
	return held["floors"]


## {lane: widest object name in pixels} over the rows the viewport has built words for, measured in
## the face and size each span draws its name in. A lane with no name is not in the answer.
static func measure(viewport: Control) -> Dictionary:
	var widest: Dictionary = {}
	var font: Font = viewport._get_font()
	var font_size: int = viewport._get_font_size()
	var measured: Dictionary = {}
	for entry: Dictionary in viewport._flat_rows:
		var row_data: EventRowData = entry.get("row")
		if row_data == null:
			continue
		for span: EventSheetSemanticSpan in row_data.spans:
			if span == null or not (span.metadata is Dictionary):
				continue
			var metadata: Dictionary = span.metadata as Dictionary
			var lane: String = str(metadata.get("lane", ""))
			var label: String = str(metadata.get("object_label", ""))
			if label.is_empty() or (lane != "condition" and lane != "action"):
				continue
			var drawn_size: int = EventSheetPalette.resolve_font_size(font_size, int(metadata.get("font_size_delta", 0)))
			var key: String = "%s|%d" % [label, drawn_size]
			if not measured.has(key):
				measured[key] = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, drawn_size).x
			widest[lane] = maxf(float(widest.get(lane, 0.0)), float(measured[key]))
	return widest
