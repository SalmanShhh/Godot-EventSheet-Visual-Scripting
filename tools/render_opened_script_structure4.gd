# EventForge - render harness (dev tool) for the STRUCTURE a hand-written script is organised with.
#
# Batch 4's four approved readings, in one file: `#region` folds (N1, nested), commented-out code
# next to real prose (N2), a repeating Timer and a while-true-await loop (N3), and a script that
# extends another project script (N12). It writes:
#   docs/images/opened-script-structure4.png
# Run NON-headless (headless runs cannot render):
#   godot --path . --script tools/render_opened_script_structure4.gd
@tool
extends SceneTree

const BASE_PATH: String = "res://enemy_base_preview.gd"
const FIXTURE_PATH: String = "res://opened_script_structure4_preview.gd"

const BASE_SOURCE: String = """class_name PreviewEnemyBase
extends Node2D


func _ready() -> void:
	pass


func take_damage(amount: int) -> void:
	pass
"""

const FIXTURE_SOURCE: String = """extends "res://enemy_base_preview.gd"

var hp: int = 10
var seconds_left: int = 3


#region Movement
func _ready() -> void:
	super._ready()
	$SpawnTimer.wait_time = 2.0
	$SpawnTimer.timeout.connect(_spawn)
	$SpawnTimer.start()


func _physics_process(delta: float) -> void:
	# velocity.x = 0.0
	# TODO: add coyote time
	hp += 1
	# if hp <= 0: hp = 10
#endregion


#region Combat
func take_damage(amount: int) -> void:
	super.take_damage(amount)
	hp -= amount


#region Death
func die() -> void:
	hp = 0
#endregion
#endregion


func _spawn() -> void:
	hp += 1


func _blink() -> void:
	while true:
		await get_tree().create_timer(0.5).timeout
		visible = not visible
"""

var _frames: int = 0
var _viewport: EventSheetViewport = null
var _scroll: ScrollContainer = null
var _sheet: EventSheetResource = null


func _init() -> void:
	root.title = "Opened script structure"
	root.size = Vector2i(1500, 1000)
	var modern_base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = modern_base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	_scroll.add_child(_viewport)
	# The base script must exist in the PROJECT for the Include bar to resolve it - that is exactly
	# the question N12 asks (is this base a project script or an engine class?).
	_write(BASE_PATH, BASE_SOURCE)
	_write(FIXTURE_PATH, FIXTURE_SOURCE)
	_sheet = GDScriptImporter.new().import_external(FIXTURE_PATH)
	# The dock opens a .gd as a read-only preview; the importer leaves the flag alone.
	_sheet.read_only = true
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	EventSheetGodotTheme.apply(style, modern_base, modern_base.darkened(0.15), modern_base.darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	_sheet.editor_style = style
	_viewport.set_sheet(_sheet)
	_viewport.set_reading_mode(true)
	# The head bars and the verb blocks fold closed by default; the shapes this shot exists for all
	# live under them. Opened pass by pass, because unfolding a bar is what reveals the next bar.
	for _pass: int in 4:
		for entry: Dictionary in _viewport.get_flat_rows():
			var row_data: EventRowData = entry.get("row")
			if row_data != null and not row_data.row_uid.is_empty():
				_viewport._fold_state[row_data.row_uid] = false
		_viewport.set_sheet(_sheet)
	root.gui_disable_input = true
	process_frame.connect(_on_frame)


func _write(path: String, source: String) -> void:
	var writer: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	writer.store_string(source)
	writer.close()


func _on_frame() -> void:
	_frames += 1
	if _frames < 12:
		return
	var image: Image = root.get_texture().get_image()
	image.save_png("res://docs/images/opened-script-structure4.png")
	print("[preview] opened script structure %dx%d" % [image.get_width(), image.get_height()])
	print("[preview] round-trips: %s" % str(str(SheetCompiler.new().compile(_sheet).get("output", "")) == FIXTURE_SOURCE))
	_print_rows()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BASE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_PATH))
	quit(0)


## What every row READS as, so a run doubles as a text check of the words behind the image.
func _print_rows() -> void:
	for entry: Dictionary in _viewport.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null:
			continue
		_viewport._ensure_event_spans(row_data)
		var texts: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			if not span.text.strip_edges().is_empty():
				texts.append(span.text)
		print("  row: [%s]" % " | ".join(texts))
