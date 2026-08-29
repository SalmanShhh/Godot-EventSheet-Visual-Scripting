# Godot EventSheets - the Doctor's Docs section (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The rows are drawn by the Project Doctor window's OWN inbox filler, so what is photographed is the
# page a reader gets rather than a lookalike of it - and the findings are this repository's real
# ones, measured off its own guides and its own CHANGELOG. That is the point of the picture: a
# corpus of ninety-four pack guides has drift in it, and a section that showed a clean page here
# would be a section that cannot see.
@tool
extends RefCounted

const PREVIEW_NAME: String = "doctor-docs-findings"
const PREVIEW_SIZE: Vector2i = Vector2i(1240, 620)


static func build(host: Window) -> Control:
	var tree: Tree = Tree.new()
	tree.hide_root = true
	tree.columns = 4
	tree.set_column_title(0, "New")
	tree.set_column_title(1, "Section")
	tree.set_column_title(2, "Where")
	tree.set_column_title(3, "Finding")
	tree.set_column_expand(0, false)
	tree.set_column_custom_minimum_width(0, 40)
	tree.set_column_expand(1, false)
	tree.set_column_custom_minimum_width(1, 190)
	tree.set_column_expand(2, false)
	tree.set_column_custom_minimum_width(2, 190)
	tree.column_titles_visible = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# The section is asked directly, with the guide budget an editor gets. A preview harness is a
	# plain game process, and outside the editor the section deliberately reads nothing - the vocabulary
	# is not loaded there, so a guide costs seconds instead of a lookup. Paying that here is the point:
	# the picture has to be of the page an editor draws.
	var findings: Array[Dictionary] = EventSheetDocsDoctor.report(EventSheetDocsDoctor.guide_pages(),
		FileAccess.get_file_as_string(EventSheetDocWhatsNew.SOURCE_PATH),
		EventSheetDocsDoctor.GUIDES_READ_LIMIT)
	# Triaged against an EMPTY read, so every line wears its "new since you last looked" mark: the
	# picture is of a page somebody is opening for the first time, which is the state the section is
	# designed around.
	EventSheetProjectDoctorPanel.fill_inbox(tree, tree.create_item(),
		EventSheetDoctorInbox.triage(findings, PackedStringArray()))
	var body: MarginContainer = EventSheetPopupUI.margined(
		EventSheetPopupUI.titled_card("Inbox", tree))
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(body)
	return body
