# EventForge - render harness (dev tool) for the two guards a merge runs into:
#   TOP     a .gd still holding conflict markers, opened READ-ONLY with the head banner naming the
#           marker lines - the one banner this editor puts at the head of a sheet, because the file
#           is not GDScript and that is a state rather than a finding.
#   BOTTOM  the Doctor's inbox row for two rows that declare the same baked local in one scope,
#           with its one chip: Re-mint one of them.
# Run NON-headless (headless cannot render):
#   godot --path . --script tools/render_merge_guards_preview.gd
@tool
extends SceneTree

const FIXTURE := "user://player_movement.gd"
const GAP: int = 14

var _frames: int = 0
var _dock: EventSheetDock = null
var _panel: EventSheetProjectDoctorPanel = null
var _blocked: Image = null


func _init() -> void:
	root.title = "Merge Guards"
	root.size = Vector2i(1180, 460)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	_write_fixture()
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		_dock = EventSheetDock.new()
		_dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(_dock)
		return
	if _frames == 6:
		# The real open path: any marker line anywhere blocks the file, so this is the guard being
		# taken rather than a banner posed for a picture.
		_dock._load_sheet_from_path(FIXTURE)
		return
	if _frames == 12:
		_blocked = _capture_control(_dock)
		_open_inbox()
		return
	if _frames < 22 or _blocked == null:
		return
	_save(_blocked, _capture_window(_panel._doctor_window))
	quit(0)


## The Doctor's inbox, filled with the one finding this preview is about rather than with a live
## audit of whatever project the harness is run in - the row and its chip are what the picture is
## for, and a real audit of this repository finds no duplicates at all.
func _open_inbox() -> void:
	_panel = EventSheetProjectDoctorPanel.new()
	_panel.init(_dock)
	_panel.open()
	_panel._doctor_window.size = Vector2i(1000, 300)
	_panel._doctor_tree.clear()
	var root_item: TreeItem = _panel._doctor_tree.create_item()
	var duplicates: Array[Dictionary] = EventSheetLocalTokens.duplicates_in(_merged_source())
	var page: Array[Dictionary] = []
	for entry: Dictionary in duplicates:
		page.append({
			"severity": "error",
			"check": EventSheetLocalTokens.CHECK_DUPLICATE_TOKEN,
			"path": "res://player_movement.gd",
			"subject": str(entry.get("token", "")),
			"message": EventSheetLocalTokens.duplicate_message(entry),
			"event": 0,
			"is_new": true,
		})
	EventSheetProjectDoctorPanel.fill_inbox(_panel._doctor_tree, root_item, page)
	var branch: TreeItem = root_item.get_first_child()
	if branch != null and branch.get_first_child() != null:
		branch.get_first_child().select(3)
		_panel._refresh_fix_button()


## A file a merge did not finish with: an ordinary movement script whose speed line came back from
## two branches, markers and all.
func _write_fixture() -> void:
	var file: FileAccess = FileAccess.open(FIXTURE, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("extends CharacterBody2D\n"
		+ "\n"
		+ "\n"
		+ "func _physics_process(delta: float) -> void:\n"
		+ "\tvar direction: float = Input.get_axis(\"move_left\", \"move_right\")\n"
		+ "<<<<<<< HEAD\n"
		+ "\tvelocity.x = direction * 260.0\n"
		+ "=======\n"
		+ "\tvelocity.x = direction * 180.0\n"
		+ "\tvelocity.y += 980.0 * delta\n"
		+ ">>>>>>> feature/tighter-jump\n"
		+ "\tmove_and_slide()\n")
	file.close()


## The other half of the same merge, one step later: the markers are gone and both branches' rows
## are in, each still declaring the local its own branch minted.
func _merged_source() -> String:
	return "extends Node\n\n\nfunc _ready() -> void:\n" \
		+ "\tvar __peer_a3f81c02 := ENetMultiplayerPeer.new()\n" \
		+ "\t__peer_a3f81c02.create_server(7777, 4)\n" \
		+ "\n" \
		+ "\tvar __peer_a3f81c02 := ENetMultiplayerPeer.new()\n" \
		+ "\t__peer_a3f81c02.create_client(\"127.0.0.1\", 7777)\n"


func _capture_control(control: Control) -> Image:
	var image: Image = root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var rect: Rect2i = Rect2i(Vector2i(control.global_position), Vector2i(control.size))
	var clipped: Rect2i = rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	return image.get_region(clipped) if clipped.has_area() else image


func _capture_window(window: Window) -> Image:
	var image: Image = window.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _save(blocked: Image, inbox: Image) -> void:
	var width: int = maxi(blocked.get_width(), inbox.get_width())
	var composed: Image = Image.create(width, blocked.get_height() + GAP + inbox.get_height(),
		false, Image.FORMAT_RGBA8)
	composed.fill(Color("#2b2b2b"))
	composed.blit_rect(blocked, Rect2i(Vector2i.ZERO, blocked.get_size()), Vector2i.ZERO)
	composed.blit_rect(inbox, Rect2i(Vector2i.ZERO, inbox.get_size()),
		Vector2i(0, blocked.get_height() + GAP))
	composed.save_png("res://docs/images/merge-guards.png")
	print("[preview] merge guards %dx%d (top: the blocked file's banner, bottom: the duplicate-token inbox row)"
		% [composed.get_width(), composed.get_height()])
