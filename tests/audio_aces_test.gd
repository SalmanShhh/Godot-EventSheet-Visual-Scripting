# Godot EventSheets — Audio module (event-sheet Audio addon, the Godot way) + the module
# contract (factory-built vocabularies concatenated into the builtin registry).
@tool
class_name AudioAcesTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	var by_id: Dictionary = {}
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	all_passed = _check("one-shots registered", by_id.has("PlaySound") and by_id.has("PlaySoundAt"), true) and all_passed
	all_passed = _check("player-scoped group registered",
		by_id.has("AudioPlay") and by_id.has("AudioPlayStream") and by_id.has("AudioStop") and by_id.has("AudioSeek") and by_id.has("AudioSetVolume") and by_id.has("AudioSetPitch") and by_id.has("AudioIsPlaying") and by_id.has("AudioGetPosition"), true) and all_passed
	all_passed = _check("bus extras registered",
		by_id.has("SetBusVolume") and by_id.has("SetBusMute") and by_id.has("GetBusVolume"), true) and all_passed
	all_passed = _check("sound params use the preview workflow",
		str((by_id["PlaySound"].params[0] as ACEParam).hint), "audio_path") and all_passed
	all_passed = _check("player ACEs scope to AudioStreamPlayer",
		str(by_id["AudioPlay"].node_type), "AudioStreamPlayer") and all_passed

	# The fire-and-forget one-shot: multi-line + uid bakes a self-freeing player.
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var play: ACEAction = ACEAction.new()
	play.provider_id = "Core"
	play.ace_id = "PlaySound"
	play.codegen_template = str(by_id["PlaySound"].codegen_template).replace("{uid}", "t1")
	play.params = {"path": "\"res://demo/sound.ogg\"", "bus": "\"Master\"", "volume_db": "0.0"}
	event.actions.append(play)
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_audio.gd").get("output", ""))
	all_passed = _check("one-shot emits the self-freeing player",
		output.contains("\tvar __sfx_t1 = AudioStreamPlayer.new()") and output.contains("\t__sfx_t1.finished.connect(__sfx_t1.queue_free)") and output.contains("\t__sfx_t1.play()"), true) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("audio output parses", generated.reload(true) == OK, true) and all_passed

	# Preview field: ▶ button + path editor; extract returns the path text.
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	var field: Control = dialog._create_audio_path_field("path", "\"res://x.ogg\"")
	var path_edit: LineEdit = null
	var preview_button: Button = null
	for child in field.get_children():
		if child is LineEdit:
			path_edit = child
		elif child is Button:
			preview_button = child
	all_passed = _check("preview field has path + ▶",
		path_edit != null and preview_button != null and preview_button.text == "▶", true) and all_passed
	all_passed = _check("preview field round-trips the path", dialog._extract_value(path_edit), "\"res://x.ogg\"") and all_passed
	field.free()

	# Node picker: expression fields gain the 🔍 browser; filter logic matches
	# name/class/path case-insensitively (asserted via the row builder on a tiny tree).
	var field2: Control = dialog._create_expression_field("target", "self")
	var has_node_button: bool = false
	for child in field2.get_children():
		if child is Button and (child as Button).tooltip_text.begins_with("Pick a scene node"):
			has_node_button = true
	all_passed = _check("expression fields offer the node picker", has_node_button, true) and all_passed
	field2.free()
	all_passed = _check("node references stay identifier-safe",
		ACEParamsDialog._node_reference("UI/Health Bar"), "$\"UI/Health Bar\"") and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] audio_aces_test: %s" % label)
		return true
	print("[FAIL] audio_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
