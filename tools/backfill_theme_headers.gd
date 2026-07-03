# One-shot maintenance: presets created before the column-header tokens existed render
# headers with generic defaults — backfill them from each preset's own palette
# (background-derived surface; existing condition/action text colors).
@tool
extends SceneTree


func _init() -> void:
	var paths: PackedStringArray = PackedStringArray()
	for dir_path in ["res://demo/themes", "res://addons/eventsheet/themes"]:
		var dir: DirAccess = DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry: String = dir.get_next()
		while not entry.is_empty():
			if entry.ends_with(".tres"):
				paths.append("%s/%s" % [dir_path, entry])
			entry = dir.get_next()
	for path in paths:
		var style: EventSheetEditorStyle = load(path) as EventSheetEditorStyle
		if style == null or style.event_style == null:
			print("skip (not an editor style): %s" % path)
			continue
		var events: EventSheetEventStyle = style.event_style
		# Heuristic: untouched defaults == script defaults; only backfill those.
		var defaults: EventSheetEventStyle = EventSheetEventStyle.new()
		if events.column_header_background_color != defaults.column_header_background_color:
			print("ok: %s" % path)
			continue
		events.column_header_background_color = events.row_background_color.darkened(0.25)
		events.column_header_conditions_color = style.condition_style.text_color if style.condition_style != null else events.group_title_color
		events.column_header_actions_color = style.action_style.text_color if style.action_style != null else events.group_title_color
		var save_error: Error = ResourceSaver.save(style, path)
		print("backfilled (%d): %s" % [save_error, path])
	quit()
