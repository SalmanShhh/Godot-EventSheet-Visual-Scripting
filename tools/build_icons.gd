# Writes every pack's icon from its glyph source. Run by the pack build (tools/build_sample_behaviors.gd);
# by hand:
#   godot --headless --path . --script tools/build_icons.gd             writes <pack>/icon.svg and its import
#   godot --headless --path . --script tools/build_icons.gd -- --check  writes nothing, prints icons=N drifted=N
#
# A pack with no glyph source yet keeps the icon it has (the style test lists those on its allow-list).
# A glyph named <pack>_3d where <pack>_3d is not a pack but <pack> is gives that pack a second icon,
# icon_3d.svg, for the classes in it that work in 3D; the pack's own icon.svg is then the 2D one.
# Every picker section icon (addons/eventsheet/icons/sections) gets its import the same way.
# Every Juice card kind has a glyph in tools/pack_builders/icons/cards/<kind>.glyph and gets
# eventsheet_addons/juice/cards/<kind>.svg, in the neutral ink.
# The writing is a pure function of the glyph and the pack's scripts (tools/icon_style.gd), so a build
# twice over writes the same bytes.
@tool
extends SceneTree

const STYLE := preload("res://tools/icon_style.gd")


func _init() -> void:
	var check: bool = "--check" in OS.get_cmdline_user_args()
	var result: Dictionary = build(check)
	print("[build_icons] icons=%d drifted=%d" % [int(result.get("icons", 0)), (result.get("drifted", []) as Array).size()])
	for path: Variant in result.get("drifted", []):
		print("[build_icons] drifted: %s" % path)
	quit(1 if check and not (result.get("drifted", []) as Array).is_empty() else 0)


## Builds (or, with `check`, only compares) every icon. Returns {icons, drifted}.
static func build(check: bool) -> Dictionary:
	var icons: int = 0
	var drifted: Array = []
	var packs: PackedStringArray = DirAccess.get_directories_at(STYLE.ADDONS_DIR)
	packs.sort()
	for pack: String in packs:
		var glyph: String = STYLE.glyph_for(pack)
		if glyph.is_empty():
			continue
		var has_3d_icon: bool = FileAccess.file_exists("%s/%s_3d.glyph" % [STYLE.GLYPH_DIR, pack]) \
			and not packs.has(pack + "_3d")
		var ink: String = STYLE.INK_2D if has_3d_icon else STYLE.ink_for(pack)
		var dot: bool = not STYLE.host_class(pack).is_empty()
		icons += 1
		_put("%s/%s/icon.svg" % [STYLE.ADDONS_DIR, pack], STYLE.render(glyph, ink, dot), check, drifted)
		if has_3d_icon:
			var glyph_3d: String = FileAccess.get_file_as_string("%s/%s_3d.glyph" % [STYLE.GLYPH_DIR, pack])
			icons += 1
			_put("%s/%s/icon_3d.svg" % [STYLE.ADDONS_DIR, pack], STYLE.render(glyph_3d, STYLE.INK_3D, dot), check, drifted)
	# The picker's section icons are drawn files, not made from a glyph: each only needs its import.
	var sections: PackedStringArray = DirAccess.get_files_at(STYLE.SECTION_DIR)
	sections.sort()
	for file_name: String in sections:
		if file_name.ends_with(".svg"):
			icons += 1
			_put_import("%s/%s" % [STYLE.SECTION_DIR, file_name], check, drifted)
	# The Juice card icons: one svg per card kind in the Juice pack's folder, no import beside them (the
	# card line draws them itself, so the default import is all a project ever needs).
	var cards: PackedStringArray = DirAccess.get_files_at(STYLE.CARD_GLYPH_DIR)
	cards.sort()
	if not cards.is_empty() and not check:
		DirAccess.make_dir_recursive_absolute(STYLE.CARD_DIR)
	for file_name: String in cards:
		if file_name.ends_with(".glyph"):
			icons += 1
			var glyph_text: String = FileAccess.get_file_as_string("%s/%s" % [STYLE.CARD_GLYPH_DIR, file_name])
			_put_svg("%s/%s.svg" % [STYLE.CARD_DIR, file_name.get_basename()], STYLE.render_card(glyph_text), check, drifted)
	return {"icons": icons, "drifted": drifted}


## Writes one svg alone (or records the path when it differs and `check` is set).
static func _put_svg(svg_path: String, svg: String, check: bool, drifted: Array) -> void:
	if FileAccess.file_exists(svg_path) and FileAccess.get_file_as_string(svg_path) == svg:
		return
	drifted.append(svg_path)
	if not check:
		var file: FileAccess = FileAccess.open(svg_path, FileAccess.WRITE)
		if file == null:
			push_error("[build_icons] cannot write %s" % svg_path)
			return
		file.store_string(svg)


## Writes the svg and its import (or records the path when a file differs and `check` is set).
static func _put(svg_path: String, svg: String, check: bool, drifted: Array) -> void:
	for pair: Array in [[svg_path, svg], [svg_path + ".import", STYLE.import_text(svg_path)]]:
		var path: String = pair[0]
		var text: String = pair[1]
		var have: String = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		if have == text:
			continue
		drifted.append(path)
		if not check:
			var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				push_error("[build_icons] cannot write %s" % path)
				continue
			file.store_string(text)


## Writes only the import beside a drawn svg.
static func _put_import(svg_path: String, check: bool, drifted: Array) -> void:
	var path: String = svg_path + ".import"
	var text: String = STYLE.import_text(svg_path)
	if FileAccess.file_exists(path) and FileAccess.get_file_as_string(path) == text:
		return
	drifted.append(path)
	if not check:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(text)
