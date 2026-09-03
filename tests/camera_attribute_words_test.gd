# The camera attribute words, the two focus rows, and the lens a camera is given when it has none.
#
# The claim this file holds to account is that the sheet says ONE word where Godot says a property
# name on a resource hanging off a node: `camera exposure` is `exposure_multiplier`, `auto exposure`
# is `auto_exposure_enabled` plus three numbers that are the same decision, and "focus on that crate"
# is three depth-of-field properties nobody outside a camera menu has met. The mapping is derived from
# ClassDB, so what is pinned here is the ANSWERS - by value - rather than the table producing them.
#
# And the OWN-IT COURTESY, which is the whole reason these templates are several lines rather than
# one: every write gives this node its own copy of the camera attributes first, so an attributes file
# worn by two cameras never changes under the other one. A slot holding nothing is given a PRACTICAL
# lens; a slot somebody filled with a physical one keeps it, and every line only a practical lens can
# answer sits inside a guard. Both promises are pinned as the emitted BYTES, because they are only
# kept by what the rows actually write.
@tool
class_name CameraAttributeWordsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const W := preload("res://addons/eventforge/registration/camera_attribute_words.gd")
const MODULE := preload("res://addons/eventforge/registration/modules/focus_and_exposure_aces.gd")

## The four lines every camera write opens with, written out here rather than read from the file
## under test: a test that builds its expectation from the same constant proves only that a constant
## equals itself.
const OWN_LINES := "if attributes == null:\n" \
	+ "\tattributes = CameraAttributesPractical.new()\n" \
	+ "elif not attributes.resource_path.is_empty():\n" \
	+ "\tattributes = attributes.duplicate()\n"

## The same four for the world's own slot, which is the second host and the second spelling.
const WORLD_OWN_LINES := "if camera_attributes == null:\n" \
	+ "\tcamera_attributes = CameraAttributesPractical.new()\n" \
	+ "elif not camera_attributes.resource_path.is_empty():\n" \
	+ "\tcamera_attributes = camera_attributes.duplicate()\n"


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_word_map() and ok
	ok = _test_the_defaults_come_from_classdb() and ok
	ok = _test_the_id_stems() and ok
	ok = _test_the_templates() and ok
	ok = _test_the_focus_rows() and ok
	ok = _test_both_hosts_ship_the_words() and ok
	ok = _test_ids_are_unique() and ok
	ok = _test_every_row_carries_help() and ok
	ok = _test_the_forward_plus_answer() and ok
	ok = _test_a_hand_written_line_reads_as_the_word() and ok
	ok = _test_the_doctor_says_the_renderer() and ok
	return ok


## Every word resolves to a property CameraAttributesPractical really has - the one thing the whole
## vocabulary is derived from, so it is pinned by value, word by word.
static func _test_the_word_map() -> bool:
	var resolved: Dictionary = {}
	for word: String in W.words():
		resolved[word] = W.property_of(word)
	var ok: bool = SUPPORT.check("camera_attribute_words_test",
		"each word resolves to its property", resolved, {
			"camera exposure": "exposure_multiplier",
			"auto exposure": "auto_exposure_enabled"
		})
	return SUPPORT.check("camera_attribute_words_test",
		"every word the table names really resolves", W.words().size(), W.WORDS.size()) and ok


## The value a row opens on is Godot's own, asked of ClassDB - so a dropped row starts where the
## engine starts, and a reader never meets the float32 widening that printing one in full would write
## into their script.
static func _test_the_defaults_come_from_classdb() -> bool:
	return SUPPORT.pin_table("camera_attribute_words_test", {
		"exposure_multiplier": "1.0",
		"auto_exposure_speed": "0.5",
		"auto_exposure_min_sensitivity": "0.0",
		"auto_exposure_max_sensitivity": "800.0",
		"dof_blur_far_transition": "5.0"
	}, func(property: Variant) -> String:
		return W.default_literal(str(property)))


## The one thing that is NOT derived, because an ace_id is a compatibility promise: the stem each
## word's rows are named after, on each of the two hosts.
static func _test_the_id_stems() -> bool:
	var stems: Dictionary = {}
	for host: Dictionary in W.HOSTS:
		for word: String in W.words():
			stems["%s %s" % [str(host["host"]), word]] = W.id_stem(word, host)
	return SUPPORT.check("camera_attribute_words_test", "the frozen id stems", stems, {
		"Camera3D camera exposure": "Exposure",
		"Camera3D auto exposure": "AutoExposure",
		"WorldEnvironment camera exposure": "ExposureWorld",
		"WorldEnvironment auto exposure": "AutoExposureWorld"
	})


## The bytes the word rows write. The own-it lines first on every write, the companions that are the
## same decision written on the same row, the two of them only a practical lens can answer written
## inside the guard that asks, and a read that is the plain line a person would type.
static func _test_the_templates() -> bool:
	var templates: Dictionary = _templates()
	return SUPPORT.pins("camera_attribute_words_test", [
		["a plain write owns the lens first", templates.get("CamSetExposure", ""),
			OWN_LINES + "attributes.exposure_multiplier = {value}"],
		["the world's slot is the same write through the other spelling",
			templates.get("CamSetExposureWorld", ""),
			WORLD_OWN_LINES + "camera_attributes.exposure_multiplier = {value}"],
		["a fade walks the owned copy, never the shared file",
			templates.get("CamFadeExposure", ""),
			OWN_LINES + "create_tween().tween_property(attributes, \"exposure_multiplier\", {value}, {seconds})"],
		["a read is the plain member a person would type",
			templates.get("CamExposure", ""), "attributes.exposure_multiplier"],
		["the switch settles the whole behaviour on one row, and guards what only a practical lens has",
			templates.get("CamAutoExposureOn", ""),
			OWN_LINES + "attributes.auto_exposure_enabled = true\n"
				+ "attributes.auto_exposure_speed = {speed}\n"
				+ "if attributes is CameraAttributesPractical:\n"
				+ "\tattributes.auto_exposure_min_sensitivity = {least}\n"
				+ "\tattributes.auto_exposure_max_sensitivity = {most}"],
		["and turning it off is the flag alone, on this scene's own copy",
			templates.get("CamAutoExposureOff", ""),
			OWN_LINES + "attributes.auto_exposure_enabled = false"],
		["the question is the plain flag", templates.get("CamIsAutoExposureOn", ""),
			"attributes.auto_exposure_enabled"]
	])


## The two rows a table cannot build: one sentence a person says, three numbers the engine wants.
static func _test_the_focus_rows() -> bool:
	var templates: Dictionary = _templates()
	return SUPPORT.pins("camera_attribute_words_test", [
		["focusing measures the subject once and remembers it",
			templates.get("CamFocusOn", ""),
			OWN_LINES + "var __subject_{uid} = {subject}\n"
				+ "if attributes is CameraAttributesPractical:\n"
				+ "\tattributes.dof_blur_far_enabled = true\n"
				+ "\tattributes.dof_blur_far_distance = global_position.distance_to(__subject_{uid}.global_position) if __subject_{uid} is Node3D else float(__subject_{uid})\n"
				+ "\tcreate_tween().tween_property(attributes, \"dof_blur_far_transition\", {beyond}, {seconds})"],
		["and clearing it puts the blur amount back where it was",
			templates.get("CamFocusEverywhere", ""),
			OWN_LINES + "if attributes is CameraAttributesPractical:\n"
				+ "\tvar __blur_{uid}: float = attributes.dof_blur_amount\n"
				+ "\tvar __clear_{uid}: Tween = create_tween()\n"
				+ "\t__clear_{uid}.tween_property(attributes, \"dof_blur_amount\", 0.0, {seconds})\n"
				+ "\t__clear_{uid}.tween_callback(attributes.set.bind(\"dof_blur_far_enabled\", false))\n"
				+ "\t__clear_{uid}.tween_callback(attributes.set.bind(\"dof_blur_amount\", __blur_{uid}))"],
		["the distance reads back as the plain member",
			templates.get("CamFocusDistance", ""), "attributes.dof_blur_far_distance"],
		["and all three are the camera's own rows, because only a camera stands somewhere",
			_hosts_of(["CamFocusOn", "CamFocusEverywhere", "CamFocusDistance"]),
			PackedStringArray(["Camera3D", "Camera3D", "Camera3D"])]
	])


## Both nodes that can carry a lens get every word, and each row is hosted on the node it writes
## through - the twin rule, proved by NAMING the rows each host publishes rather than counting them.
static func _test_both_hosts_ship_the_words() -> bool:
	var by_host: Dictionary = {}
	for row: ACEDescriptor in MODULE.get_descriptors():
		var host: String = str(row.node_type)
		var published: PackedStringArray = by_host.get(host, PackedStringArray())
		published.append(row.ace_id)
		by_host[host] = published
	return SUPPORT.check("camera_attribute_words_test", "the rows each host publishes", by_host, {
		"Camera3D": PackedStringArray(["CamSetExposure", "CamExposure", "CamFadeExposure",
			"CamAutoExposureOn", "CamAutoExposureOff", "CamIsAutoExposureOn", "CamFocusOn",
			"CamFocusEverywhere", "CamFocusDistance"]),
		"WorldEnvironment": PackedStringArray(["CamSetExposureWorld", "CamExposureWorld",
			"CamFadeExposureWorld", "CamAutoExposureWorldOn", "CamAutoExposureWorldOff",
			"CamIsAutoExposureWorldOn"])
	})


## No id is published twice, and every row is a row the module really built.
static func _test_ids_are_unique() -> bool:
	var seen: Dictionary = {}
	var doubled: PackedStringArray = PackedStringArray()
	for row: ACEDescriptor in MODULE.get_descriptors():
		if seen.has(row.ace_id):
			doubled.append(row.ace_id)
		seen[row.ace_id] = true
	var ok: bool = SUPPORT.check("camera_attribute_words_test", "no id is published twice", doubled,
		PackedStringArray())
	return SUPPORT.check("camera_attribute_words_test", "every row carries its own id", seen.size(),
		MODULE.get_descriptors().size()) and ok


## Every row and every field says what it is for. A row that ships without words is a row nobody can
## use without reading the source.
static func _test_every_row_carries_help() -> bool:
	var silent: PackedStringArray = PackedStringArray()
	for row: ACEDescriptor in MODULE.get_descriptors():
		if str(row.description).strip_edges().is_empty():
			silent.append(row.ace_id)
		for parameter: ACEParam in row.params:
			if str(parameter.description).strip_edges().is_empty():
				silent.append("%s.%s" % [row.ace_id, parameter.id])
	return SUPPORT.check("camera_attribute_words_test", "every row and field carries help", silent,
		PackedStringArray())


## What only works on Forward+, derived from the word table rather than listed a second time - so a
## word marked Forward+ and the Doctor's note about it can never drift apart. One pair per host,
## because the two nodes spell the same word differently.
static func _test_the_forward_plus_answer() -> bool:
	var fragments: PackedStringArray = PackedStringArray()
	for reason: Array in W.forward_plus_reasons():
		fragments.append("%s -> %s" % [str(reason[0]), str(reason[1])])
	return SUPPORT.check("camera_attribute_words_test",
		"the fragments that do nothing off Forward+", fragments, PackedStringArray([
			"attributes.auto_exposure_enabled -> auto exposure",
			"camera_attributes.auto_exposure_enabled -> auto exposure"]))


## A LINE SOMEBODY TYPED reads as the word the sheet has for it - which is the other half of the
## claim, and the half a picked row cannot prove on its own.
static func _test_a_hand_written_line_reads_as_the_word() -> bool:
	return SUPPORT.pin_table("camera_attribute_words_test", {
		"attributes.exposure_multiplier = 2.0": "Set camera exposure to 2",
		"camera_attributes.exposure_multiplier = 0.5": "Set camera exposure to 0.5",
		"attributes.auto_exposure_enabled = true": "Set auto exposure on",
		"attributes.auto_exposure_enabled = false": "Set auto exposure off",
		"attributes.auto_exposure_speed = 0.8": "Set speed to 0.8",
		"attributes.dof_blur_far_distance = 12.0": "Set focus distance to 12",
		"attributes.dof_blur_far_transition = 3.0": "Set focus falloff to 3",
		"attributes.dof_blur_far_enabled = false": "Set focus blur off",
		# A property no word here means keeps whatever reading it already had, which is the honest
		# answer: this table claims the lens, not every resource a node can hold.
		"attributes.resource_name = \"lens\"": "(nothing)"
	}, func(line: Variant) -> String:
		var text: String = str(line)
		var written: int = text.find(" = ")
		var target: String = text.substr(0, written)
		var said: Dictionary = EventSheetSentence.camera_attributes_assignment(
			target.substr(target.rfind(".") + 1), target.substr(0, target.rfind(".")),
			text.substr(written + 3), {})
		if said.is_empty():
			return "(nothing)"
		var words: PackedStringArray = PackedStringArray()
		for segment: Variant in (said["segments"] as Array):
			words.append(str((segment as Dictionary)["text"]))
		return "".join(words))


## The ship-it note, over two made-up projects: the one Forward+-only word the lens has is one quiet
## note in a Compatibility project, and silence in a Forward+ one.
static func _test_the_doctor_says_the_renderer() -> bool:
	const SOURCE := "func _ready() -> void:\n\tattributes.auto_exposure_enabled = true\n"
	var old_gpu: Array[Dictionary] = EventSheetShipItDoctor.renderer_findings(
		{"res://lens.gd": SOURCE}, "gl_compatibility")
	var forward: Array[Dictionary] = EventSheetShipItDoctor.renderer_findings(
		{"res://lens.gd": SOURCE}, "forward_plus")
	return SUPPORT.pins("camera_attribute_words_test", [
		["a Forward+ lens row in a Compatibility project is one quiet note", old_gpu.size(), 1],
		["and it names the renderer and the row that does nothing",
			"" if old_gpu.is_empty() else str(old_gpu[0]["message"]),
			"lens.gd asks for auto exposure, which only the Forward+ renderer draws - this row does nothing on compatibility. Either build for Forward+, or drop the row."],
		["the same row on Forward+ says nothing at all", forward.size(), 0]
	])


## Every template the module publishes, by ace_id - the one walk the pins above share.
static func _templates() -> Dictionary:
	var found: Dictionary = {}
	for row: ACEDescriptor in MODULE.get_descriptors():
		found[row.ace_id] = str(row.codegen_template)
	return found


## The host each of the named rows belongs to, in the order asked.
static func _hosts_of(ace_ids: Array) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var by_id: Dictionary = {}
	for row: ACEDescriptor in MODULE.get_descriptors():
		by_id[row.ace_id] = str(row.node_type)
	for ace_id: Variant in ace_ids:
		found.append(str(by_id.get(str(ace_id), "")))
	return found
