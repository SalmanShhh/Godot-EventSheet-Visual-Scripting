# Godot EventSheets - the blend vocabulary: the pack, its shaders, the two builtin clipping rows,
# and the field a mode is picked in.
#
# WHAT A TEST CAN SEE HERE, and what it cannot. There is no renderer in a headless run and no
# viewport in this harness, so nothing here looks at a pixel the graphics card drew. What it looks at
# instead is everything the decision is made of: which material an item ends up wearing, which shader
# file that material runs, what the dials on it read, what the shipped shader files declare, what the
# builtin rows emit and read back, and what the picker's own preview draws on the processor. A
# rendered picture is the verify slice's job.
#
# THE ONE THING WORTH SAYING TWICE: the pack ships fifteen shaders BESIDE its script, copied there by
# the builder from the source folder. Nothing else in the repository copies a non-script file into a
# pack, so nothing else would notice if that copy stopped happening - which is why the byte compare
# between the two trees is here rather than left to the pack drift gate, which only reads `.gd`.
@tool
class_name BlendModesTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := preload("res://eventsheet_addons/blend_modes/blend_modes_addon.gd")
const Field := preload("res://addons/eventsheet/editor/blend_mode_field.gd")

const P := "blend_modes_test"

## Where the two copies of the shaders live: the ones a person edits, and the ones a game loads.
const SOURCE_DIR := "res://tools/pack_builders/src/blend_modes"
const PACK_DIR := "res://eventsheet_addons/blend_modes"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _pack_drives() and all_passed
	all_passed = _masking() and all_passed
	all_passed = _shaders_ship() and all_passed
	all_passed = _clipping_rows() and all_passed
	all_passed = _the_field() and all_passed
	all_passed = _the_quiet_finding() and all_passed
	return all_passed


## THE QUIET FINDING: a screen-reading blend aimed at an item the scene already gives a shader. The
## row is refused when the game runs, because replacing somebody's effect to set a blend would be
## worse than doing nothing - so the look never appears, and the sheet has to say so before the game
## is run rather than after.
##
## The fixture carries all three shapes on purpose: the clash, a NATIVE mode on the same kind of node
## (which sets a field and replaces nothing, so it is never this finding), and a blend aimed at a
## node the scene gives no material at all (nothing to clash with). A check that only ever saw the
## first would be a check nobody could trust to stay quiet.
static func _the_quiet_finding() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(
		"res://tests/fixtures/blend_scene_glow.gd")
	var found: Array[Dictionary] = EventSheetEffectFindings.findings(sheet)
	var kinds: PackedStringArray = PackedStringArray()
	var subjects: PackedStringArray = PackedStringArray()
	for finding: Dictionary in found:
		kinds.append(str(finding["kind"]))
		subjects.append(str(finding["subject"]))
	var rows: Array = [
		["exactly one of the three blend rows is a finding",
			",".join(kinds), EventSheetEffectFindings.KIND_BLEND_OVER_SHADER],
		["and it is the one aimed at the item wearing a shader", ",".join(subjects), "self"]
	]
	if not found.is_empty():
		rows.append(["it names the shader and the mode, and says the look never appears",
			str(found[0]["message"]).contains("blend is refused when the game runs"), true])
		rows.append(["it carries the shader it clashes with",
			str(found[0]["shader_path"]).get_file(), "effect_dissolve.gdshader"])
		rows.append(["it is amber rather than red, because the game still runs",
			str(found[0]["severity"]), "warning"])
		rows.append(["and offers no fix door, because there are three answers and no way to pick one",
			str(found[0]["fix"]), ""])
	rows.append(["the Doctor files it under its own check id",
		str(EventSheetEffectsDoctor.CHECK_FOR_KIND[EventSheetEffectFindings.KIND_BLEND_OVER_SHADER]),
		EventSheetEffectsDoctor.CHECK_BLEND])
	rows.append(["and reads a sheet that only says the blend call, which nothing else would open",
		EventSheetEffectsDoctor.SHEET_WORDS.has(EventSheetEffectFindings.BLEND_CALL), true])
	return SUPPORT.pins(P, rows)


## The pack driven directly: a native mode is a renderer field, a shader mode is one of the pack's
## own files, somebody else's shader is never thrown away, and the record both the condition and the
## expression read is the one the action wrote.
static func _pack_drives() -> bool:
	var pack: Node = PACK.new()
	var item: Sprite2D = Sprite2D.new()
	var rows: Array = []

	pack.call("blend_as", item, "add", 1.0)
	var native: CanvasItemMaterial = item.material as CanvasItemMaterial
	rows.append(["a native mode wears an ordinary material", native != null, true])
	rows.append(["and sets the renderer's own blend field",
		native.blend_mode if native != null else -1, CanvasItemMaterial.BLEND_MODE_ADD])
	rows.append(["the expression reads the word back", str(pack.call("blend_mode", item)), "add"])
	rows.append(["the condition agrees", bool(pack.call("blend_mode_is", item, "add")), true])
	rows.append(["and disagrees about another mode",
		bool(pack.call("blend_mode_is", item, "multiply")), false])

	pack.call("blend_as", item, "screen", 0.4)
	var blended: ShaderMaterial = item.material as ShaderMaterial
	rows.append(["a shader mode wears a shader material", blended != null, true])
	rows.append(["running the pack's own file for that mode",
		blended.shader.resource_path if blended != null else "",
		"%s/blend_screen.gdshader" % PACK_DIR])
	rows.append(["with the strength the row asked for",
		blended.get_shader_parameter("strength") if blended != null else -1.0, 0.4])
	rows.append(["the pack knows the material is its own",
		bool(pack.call("is_pack_material", blended)), true])

	pack.call("set_blend_strength", item, 1.0)
	rows.append(["Set Blend Strength turns the same dial",
		(item.material as ShaderMaterial).get_shader_parameter("strength"), 1.0])
	# No tree here, so the walk lands at once rather than tweening - which is exactly what the verb
	# promises for a fade of no time or a node that is not in the scene yet.
	pack.call("fade_blend_strength", item, 0.25, 0.0)
	rows.append(["a fade with nowhere to run lands straight away",
		(item.material as ShaderMaterial).get_shader_parameter("strength"), 0.25])

	# Back to a native mode: the pack's own shader comes off, and the renderer field is set again.
	pack.call("blend_as", item, "multiply", 1.0)
	rows.append(["going back to a native mode takes the pack's shader off",
		item.material is CanvasItemMaterial, true])

	var mode_before_nonsense: String = str(pack.call("blend_mode", item))
	pack.call("blend_as", item, "not a mode at all", 1.0)
	rows.append(["a word that is not a mode changes nothing",
		str(pack.call("blend_mode", item)), mode_before_nonsense])

	# SOMEBODY ELSE'S EFFECT IS NEVER THROWN AWAY. Both halves: a shader mode refuses outright, and a
	# native mode records the ask but leaves the material where it is.
	var wearing_its_own: Sprite2D = Sprite2D.new()
	var theirs: ShaderMaterial = ShaderMaterial.new()
	wearing_its_own.material = theirs
	pack.call("blend_as", wearing_its_own, "overlay", 1.0)
	rows.append(["a screen blend never replaces somebody else's shader material",
		wearing_its_own.material == theirs, true])
	pack.call("blend_as", wearing_its_own, "add", 1.0)
	rows.append(["and neither does a native one", wearing_its_own.material == theirs, true])
	rows.append(["though the mode it was asked for is still readable",
		str(pack.call("blend_mode", wearing_its_own)), "add"])

	var untouched: Sprite2D = Sprite2D.new()
	rows.append(["an item nobody has blended reads as normal",
		str(pack.call("blend_mode", untouched)), "normal"])

	untouched.free()
	wearing_its_own.free()
	item.free()
	pack.free()
	return SUPPORT.pins(P, rows)


## The mask: the shape shader, the number the mode word becomes, and the way back.
static func _masking() -> bool:
	var pack: Node = PACK.new()
	var item: Sprite2D = Sprite2D.new()
	var shape: Texture2D = PlaceholderTexture2D.new()
	var rows: Array = []

	pack.call("mask_with", item, shape, "outside")
	var masked: ShaderMaterial = item.material as ShaderMaterial
	rows.append(["Mask With wears the mask shader",
		masked.shader.resource_path if masked != null else "", "%s/blend_mask.gdshader" % PACK_DIR])
	rows.append(["holding the shape it was handed",
		masked.get_shader_parameter("mask") == shape if masked != null else false, true])
	# The number is the mode word's PLACE in the pack's own list, which is what the shader's own
	# comment says it reads - so this pin is what keeps the two in step.
	rows.append(["and the number the shader reads for that word",
		masked.get_shader_parameter("mask_mode") if masked != null else -1, 1])
	rows.append(["the record says it is masked", str(pack.call("blend_mode", item)), "mask"])

	pack.call("unmask", item)
	rows.append(["Unmask puts back what was worn before", item.material, null])
	rows.append(["and the record goes back with it", str(pack.call("blend_mode", item)), "normal"])

	# A mask with nothing to mask with leaves the item alone rather than wearing a shader that shows
	# nothing at all.
	pack.call("mask_with", item, null, "inside")
	rows.append(["a mask with no texture masks nothing", item.material, null])

	# The node form reads the shape off another node's own picture.
	var shape_node: Sprite2D = Sprite2D.new()
	shape_node.texture = shape
	pack.call("mask_with_node", item, shape_node, "atop")
	rows.append(["Mask With Node takes the shape off that node",
		(item.material as ShaderMaterial).get_shader_parameter("mask") == shape, true])
	rows.append(["at the number that word stands for",
		(item.material as ShaderMaterial).get_shader_parameter("mask_mode"), 2])

	shape_node.free()
	item.free()
	pack.free()
	return SUPPORT.pins(P, rows)


## The shader files: one per mode, shipped beside the script, byte-identical to the source they were
## copied from, and each declaring the two things the pack reaches through them for.
static func _shaders_ship() -> bool:
	var rows: Array = []
	# One file per SHADER mode plus the mask, and none for the five native ones - a native mode needs
	# no file at all, which is the whole reason it is free.
	var expected: PackedStringArray = PackedStringArray()
	for mode: String in PACK.SHADER_MODES:
		expected.append("blend_%s.gdshader" % mode.replace(" ", "_"))
	expected.append("blend_mask.gdshader")
	expected.sort()

	var shipped: PackedStringArray = _gdshaders_in(PACK_DIR)
	var authored: PackedStringArray = _gdshaders_in(SOURCE_DIR)
	rows.append(["every mode ships a shader and nothing ships one twice",
		",".join(shipped), ",".join(expected)])
	rows.append(["and the source folder holds exactly the same set",
		",".join(authored), ",".join(expected)])

	var differing: PackedStringArray = PackedStringArray()
	for file_name: String in expected:
		if FileAccess.get_file_as_string(SOURCE_DIR.path_join(file_name)) \
				!= FileAccess.get_file_as_string(PACK_DIR.path_join(file_name)):
			differing.append(file_name)
	rows.append(["the shipped copy is byte-identical to the authored one",
		",".join(differing), ""])

	# What the pack reaches through each shader FOR: the screen it blends against, and the one dial
	# the strength verbs turn. A shader missing either is a mode that draws but cannot be driven.
	var missing_screen: PackedStringArray = PackedStringArray()
	var missing_strength: PackedStringArray = PackedStringArray()
	for mode: String in PACK.SHADER_MODES:
		var text: String = FileAccess.get_file_as_string(
			PACK_DIR.path_join("blend_%s.gdshader" % mode.replace(" ", "_")))
		if not text.contains("hint_screen_texture"):
			missing_screen.append(mode)
		if not text.contains("uniform float strength"):
			missing_strength.append(mode)
	rows.append(["every blend shader reads the screen", ",".join(missing_screen), ""])
	rows.append(["and declares the strength dial", ",".join(missing_strength), ""])

	var mask_text: String = FileAccess.get_file_as_string(PACK_DIR.path_join("blend_mask.gdshader"))
	rows.append(["the mask shader takes a shape", mask_text.contains("uniform sampler2D mask"), true])
	rows.append(["and the mode number the pack writes",
		mask_text.contains("uniform int mask_mode"), true])
	rows.append(["and it does NOT read the screen, because a mask does not need to",
		mask_text.contains("hint_screen_texture"), false])
	return SUPPORT.pins(P, rows)


## The two builtin rows: what they emit, and what a hand-written line of the same shape reads back as.
static func _clipping_rows() -> bool:
	var shipped: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		if descriptor.ace_id in ["ClipMyChildren", "StopClipping"]:
			shipped[descriptor.ace_id] = descriptor
	var clip: ACEDescriptor = shipped.get("ClipMyChildren", null) as ACEDescriptor
	var stop: ACEDescriptor = shipped.get("StopClipping", null) as ACEDescriptor
	var rows: Array = [
		["Clip My Children is shipped", clip != null, true],
		["Stop Clipping is shipped", stop != null, true]
	]
	if clip == null or stop == null:
		return SUPPORT.pins(P, rows)
	rows.append(["the clipping row writes the field, addressed to a picked node",
		clip.codegen_template, "{target.}clip_children = {mode}"])
	rows.append(["and opens on the answer that draws the node too",
		str(clip.params[0].default_value), "CanvasItem.CLIP_CHILDREN_AND_DRAW"])
	rows.append(["with the two ON values as its only choices, so nothing can spell the OFF one",
		clip.params[0].options.size(), 2])
	rows.append(["the row reads as a sentence rather than as a constant",
		clip.params[0].display_option_labels, true])
	rows.append(["Stop Clipping owns the OFF value on its own",
		stop.codegen_template, "{target.}clip_children = CanvasItem.CLIP_CHILDREN_DISABLED"])
	rows.append(["both belong to every 2D node that draws anything", clip.node_type, "CanvasItem"])

	# THE LIFT: a line somebody wrote by hand comes back as the row that would have written it, and
	# the file re-emits byte for byte either way.
	var source: String = "extends Node2D\n\n\nfunc _ready() -> void:\n\tclip_children = CanvasItem.CLIP_CHILDREN_ONLY\n"
	rows.append(["a hand-written clip line reads back as the row",
		_lifted_ids(source), PackedStringArray(["ClipMyChildren"])])
	rows.append(["and the file re-emits byte for byte",
		SUPPORT.reemit(source, "user://blend_modes_clip_roundtrip.gd"), source])
	var off_source: String = "extends Node2D\n\n\nfunc _ready() -> void:\n\tclip_children = CanvasItem.CLIP_CHILDREN_DISABLED\n"
	rows.append(["and the off line reads back as the row that owns it",
		_lifted_ids(off_source), PackedStringArray(["StopClipping"])])
	return SUPPORT.pins(P, rows)


## The field a mode is picked in: the strip it offers, the arithmetic its pictures are drawn with,
## and the seam it registers through.
static func _the_field() -> bool:
	Field.ensure_registered()
	var rows: Array = []
	rows.append(["the strip registers through the public parameter-editor seam",
		EventSheets.param_editor_for(Field.HINT).is_valid(), true])
	rows.append(["and describes its own field in the dialog's help strip",
		EventSheets.param_help_for(Field.HINT).is_empty(), false])

	# THE TWO LISTS AGREE. The strip is grouped for reading and the pack is ordered for shipping, so
	# they are written apart - and a mode in one and not the other is a mode a reader can pick and
	# the pack cannot draw, or one the pack draws and nobody can find.
	var pack_words: PackedStringArray = PackedStringArray(PACK.NATIVE_MODES.keys())
	pack_words.append_array(PACK.SHADER_MODES)
	pack_words.sort()
	var strip_words: PackedStringArray = Field.mode_words()
	strip_words.sort()
	rows.append(["every mode the strip shows is a mode the pack draws",
		",".join(strip_words), ",".join(pack_words)])

	# The arithmetic, on values worked out by hand. These are the pictures a reader chooses by, so a
	# formula that drifts from its shader is a preview that lies.
	rows.append(["multiply is the two multiplied", Field.channel("multiply", 0.5, 0.4), 0.2])
	rows.append(["screen is neither of them made darker",
		"%.4f" % Field.channel("screen", 0.5, 0.4), "0.7000"])
	rows.append(["darken keeps the darker one", Field.channel("darken", 0.5, 0.4), 0.4])
	rows.append(["lighten keeps the lighter one", Field.channel("lighten", 0.5, 0.4), 0.5])
	rows.append(["difference is the distance between them",
		"%.4f" % Field.channel("difference", 0.8, 0.3), "0.5000"])
	rows.append(["copy is the item's own colour and nothing of what is under it",
		Field.channel("copy", 0.5, 0.4), 0.4])
	rows.append(["a mode nothing here knows is previewed as a plain copy, never as an error",
		Field.channel("a project's own mode", 0.5, 0.4), 0.4])
	# The four that take a whole colour apart: luminosity keeps the colour underneath and takes only
	# the brightness, which is the one of the four with a number a person can check.
	rows.append(["luminosity takes the brightness from the item",
		"%.3f" % Field.lum_of(Field.blended("luminosity", Color(0.2, 0.4, 0.6), Color(0.9, 0.9, 0.9))),
		"%.3f" % Field.lum_of(Color(0.9, 0.9, 0.9))])

	var picture: Texture2D = Field.thumbnail("screen")
	rows.append(["a mode's picture is drawn at the strip's own size",
		"%dx%d" % [picture.get_width(), picture.get_height()],
		"%dx%d" % [Field.THUMBNAIL_WIDTH, Field.THUMBNAIL_HEIGHT]])
	rows.append(["and is the same object the second time it is asked for",
		Field.thumbnail("screen") == picture, true])
	return SUPPORT.pins(P, rows)


## The ace_ids of every action a reopened source lifted, in order - the shape both lift pins read.
static func _lifted_ids(source: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var reopened: EventSheetResource = SUPPORT.reopen(source)
	if reopened == null:
		return found
	for item: Variant in reopened.events:
		if not (item is EventRow):
			continue
		for entry: Variant in (item as EventRow).actions:
			if entry is ACEAction:
				found.append(str((entry as ACEAction).ace_id))
	return found


## Every `.gdshader` in one folder, sorted - asked of the folder rather than listed here, so a shader
## added without a mode (or a mode added without a shader) shows up as a difference.
static func _gdshaders_in(folder: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var reader: DirAccess = DirAccess.open(folder)
	if reader == null:
		return found
	for entry: String in reader.get_files():
		if entry.get_extension() == "gdshader":
			found.append(entry)
	found.sort()
	return found
