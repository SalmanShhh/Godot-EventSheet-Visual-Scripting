# EventForge - render harness (dev tool) for the ACE wizard's curation table: the Manage Providers
# dialog previewing an UNTYPED script (the case the feature exists for), with one method moved into
# the Conditions lane and one member opted out, then the confirm that shows the exact comment lines
# before anything is written. Run NON-headless (headless cannot render):
#   godot --path . --script tools/render_provider_curate_preview.gd
@tool
extends SceneTree

const UNTYPED: String = "res://tests/fixtures/untyped_provider_fixture.gd"
const GAP: int = 14

var _frames: int = 0
var _dock: EventSheetDock = null
var _table: Image = null


func _init() -> void:
	root.title = "Curate a Provider"
	root.size = Vector2i(820, 700)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		_dock = EventSheetDock.new()
		root.add_child(_dock)
		_dock._build_provider_dialog()
		_dock._preview_provider_script(UNTYPED, true)
		_dock._provider_dialog.popup_centered(Vector2i(780, 560))
		_curate()
		return
	if _frames == 10:
		_table = _capture(_dock._provider_dialog)
		# The confirm is the last step before the file changes, so it is half the story.
		_dock._on_provider_curate_pressed()
		return
	if _frames < 20 or _table == null:
		return
	_save(_table, _capture(_dock._providers_glue._curate_confirm))
	quit(0)


## Makes the edits a user would: the untyped bool method belongs in Conditions, and the raw
## `difficulty` reader is noise once the setter is there.
func _curate() -> void:
	var item: TreeItem = _dock._provider_preview_tree.get_root().get_first_child()
	while item != null:
		var row: Dictionary = item.get_metadata(0) as Dictionary
		match str(row.get("ace_id", "")):
			"method:is_wave_active":
				item.set_range(1, float(EventSheetProviderRegistryGlue.KIND_CHOICES.find("Condition")))
				item.set_text(2, "Wave Active")
				item.set_text(3, "Waves")
			"method:start_wave":
				item.set_text(2, "Start Wave")
				item.set_text(3, "Waves")
			"signal:wave_started":
				item.set_text(3, "Waves")
		item = item.get_next()


func _capture(window: Window) -> Image:
	var image: Image = window.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _save(table: Image, confirm: Image) -> void:
	var width: int = maxi(table.get_width(), confirm.get_width())
	var composed: Image = Image.create(width, table.get_height() + GAP + confirm.get_height(), false, Image.FORMAT_RGBA8)
	composed.fill(Color("#2b2b2b"))
	composed.blit_rect(table, Rect2i(Vector2i.ZERO, table.get_size()), Vector2i.ZERO)
	composed.blit_rect(confirm, Rect2i(Vector2i.ZERO, confirm.get_size()), Vector2i(0, table.get_height() + GAP))
	composed.save_png("res://docs/images/provider-curation.png")
	print("[preview] provider curation %dx%d (top: the table, bottom: the confirm)"
		% [composed.get_width(), composed.get_height()])
