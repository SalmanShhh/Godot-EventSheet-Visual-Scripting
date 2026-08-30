# Godot EventSheets - render a LIST of previews from one editor boot (dev tool).
#
# WHY BATCHING. A preview PNG is how a UI change is shown to the person who asked for it, and the
# only way to make one is to run Godot NON-headless: headless cannot render. Booting the editor is
# most of what that costs, and a slice usually has four or five pictures to take, so the harnesses
# that boot once per picture spend most of their time starting up - and each one carries its own copy
# of the same twenty lines of window setup, frame counting and file naming.
#
# This owns all of that ONCE. A preview MODULE owns only the picture:
#
#     const PREVIEW_NAME: String = "help_strip"           # the file name, without .png
#     const PREVIEW_SIZE: Vector2i = Vector2i(640, 360)   # optional; the window it wants
#     static func build(host: Window) -> Control          # what to photograph
#
# Return a Window (a dialog) and its own texture is captured; return any other Control and the
# window it was parented into is. Either way the harness waits for the frames a first paint needs,
# saves the PNG, tears the module's nodes down, and moves to the next one.
#
# USAGE (NON-headless, which is the whole point; the binary is Godot 4.7 - keep the path out of
# anything committed):
#   "$GODOT" --path . --script tools/render_previews.gd -- out=<dir> tools/previews/help_strip.gd …
#   "$GODOT" --path . --script tools/render_previews.gd -- out=<dir> all
#
# `out=` takes an absolute directory (a temporary folder outside the repo is the right place for a
# picture that is being shown to somebody, not committed). It defaults to `user://previews`.
@tool
extends SceneTree

## Where the shipped preview modules live, and what `all` means.
const PREVIEWS_DIR: String = "res://tools/previews/"

## The window a module gets unless it asks for another.
const DEFAULT_SIZE: Vector2i = Vector2i(720, 420)

## The sheet's own background, so a preview is photographed against the surface it lives on rather
## than against whatever the display server left in the buffer.
const BACKDROP: Color = Color("#252525")

## Frames to wait after building before the shutter, and after the teardown before the next build.
## Two is enough for layout; the extra ones are for a Window's first paint, which lands late.
const FRAMES_TO_PAINT: int = 8
const FRAMES_TO_SETTLE: int = 2

var _modules: Array[Script] = []
var _output_dir: String = "user://previews"
var _index: int = -1
var _built: Node = null
var _shoot_at: int = 0
var _build_at: int = 0
var _frames: int = 0
var _saved: PackedStringArray = PackedStringArray()


func _init() -> void:
	var arguments: PackedStringArray = PackedStringArray(OS.get_cmdline_user_args())
	for argument: String in arguments:
		if argument.begins_with("out="):
			_output_dir = argument.trim_prefix("out=")
		elif argument == "all":
			_modules.append_array(_shipped_modules())
		elif argument.ends_with(".gd"):
			var module: Script = load(argument)
			if module != null:
				_modules.append(module)
	if _modules.is_empty():
		_modules.append_array(_shipped_modules())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_dir))
	root.title = "EventSheets previews"
	root.size = DEFAULT_SIZE
	# Dialogs are Windows of their own; embedded, they render into this one and can be photographed.
	root.gui_embed_subwindows = true
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	process_frame.connect(_on_frame)
	_build_at = FRAMES_TO_SETTLE


func _on_frame() -> void:
	_frames += 1
	if _built == null and _frames >= _build_at:
		_build_next()
		return
	if _built != null and _frames >= _shoot_at:
		_shoot()


## Builds the next module, or finishes when the list runs out.
func _build_next() -> void:
	_index += 1
	if _index >= _modules.size():
		print("[previews] %d saved: %s" % [_saved.size(), ", ".join(_saved)])
		quit(0)
		return
	var module: Script = _modules[_index]
	root.size = module.get_script_constant_map().get("PREVIEW_SIZE", DEFAULT_SIZE)
	_built = module.call("build", root)
	if _built == null:
		push_warning("%s built nothing" % _name_of(module))
		_build_at = _frames + FRAMES_TO_SETTLE
		return
	_shoot_at = _frames + FRAMES_TO_PAINT


## Photographs whatever the module built, saves it under its own name, and clears the stage.
func _shoot() -> void:
	var source: Viewport = _built as Window if _built is Window else root
	var image: Image = source.get_texture().get_image()
	var path: String = "%s/%s.png" % [_output_dir.trim_suffix("/"), _name_of(_modules[_index])]
	image.save_png(path)
	_saved.append("%s (%dx%d)" % [path, image.get_width(), image.get_height()])
	print("[previews] %s" % _saved[_saved.size() - 1])
	_built.queue_free()
	_built = null
	_build_at = _frames + FRAMES_TO_SETTLE


## Every module in the previews folder, sorted, so `all` renders the same list on every machine.
func _shipped_modules() -> Array[Script]:
	var modules: Array[Script] = []
	var dir: DirAccess = DirAccess.open(PREVIEWS_DIR)
	if dir == null:
		return modules
	var names: PackedStringArray = PackedStringArray()
	for file_name: String in dir.get_files():
		var name: String = file_name.trim_suffix(".remap")
		if name.ends_with(".gd"):
			names.append(name)
	names.sort()
	for name: String in names:
		var module: Script = load(PREVIEWS_DIR + name)
		if module != null:
			modules.append(module)
	return modules


## A module's file name: its own PREVIEW_NAME when it declares one, else the script's.
func _name_of(module: Script) -> String:
	var declared: String = str(module.get_script_constant_map().get("PREVIEW_NAME", ""))
	return declared if not declared.is_empty() else module.resource_path.get_file().get_basename()
