# Godot EventSheets - headless vocabulary-doc driver.
#
#   godot --headless --path . --script tools/vocabulary_doc.gd
#
# Writes the project vocabulary reference (default res://EVENTSHEETS-VOCABULARY.md;
# override with the eventsheets/project/vocabulary_doc_path setting). The Project
# Doctor notes when a generated doc has gone stale.
@tool
extends SceneTree


func _init() -> void:
	var path: String = EventSheetVocabularyDoc.write()
	if path.is_empty():
		printerr("vocabulary_doc: couldn't write %s" % EventSheetVocabularyDoc.doc_path())
		quit(1)
		return
	print("vocabulary doc written: %s" % path)
	quit(0)
