# EventForge module - Game Options vocabulary (the knobs an options menu changes).
#
# The settings a player expects to tune: audio volume as a friendly 0-100 PERCENT (options sliders are
# not decibels), mute state, and saving a setting to a file so it survives a restart. They compile to
# plain Godot (AudioServer, ConfigFile, FileAccess) with zero plugin references. (The decibel Set Bus
# Volume / Mute Bus already live in the Audio vocabulary; these add the percent-friendly and
# persistence pieces.) Fullscreen, vsync, and the FPS cap live in the Game Window module. Grouped
# under "Game Options".
@tool
class_name EventForgeOptionsACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Game Options"

const SETTINGS_PATH := "\"user://settings.cfg\""


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Audio, as a 0-100 percent (what a volume slider gives you) ──
	descriptors.append(F.make_descriptor("Core", "OptionsSetMasterPercent", "Set Master Volume (percent)", ACEDescriptor.ACEType.ACTION, "AudioServer.set_bus_volume_db(0, linear_to_db(clampf({percent} / 100.0, 0.0, 1.0)))", "", [F.make_param("percent", "float", "100.0", "Percent", "0 = silent, 100 = full volume.", "expression")], CAT, "set master volume {percent}%")
		.described("Sets the overall game volume from a 0-100 slider value.").featured())
	descriptors.append(F.make_descriptor("Core", "OptionsSetBusPercent", "Set Bus Volume (percent)", ACEDescriptor.ACEType.ACTION, "AudioServer.set_bus_volume_db(AudioServer.get_bus_index({bus}), linear_to_db(clampf({percent} / 100.0, 0.0, 1.0)))", "", [F.make_param("bus", "String", "\"Music\"", "Bus", "Audio bus name (Master, Music, SFX, ...).", "expression"), F.make_param("percent", "float", "100.0", "Percent", "0 = silent, 100 = full volume.", "expression")], CAT, "set {bus} volume {percent}%")
		.described("Sets one audio bus's volume from a 0-100 slider value (for separate music / sfx sliders)."))
	descriptors.append(F.make_descriptor("Core", "OptionsGetBusPercent", "Bus Volume (percent)", ACEDescriptor.ACEType.EXPRESSION, "clampf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index({bus}))), 0.0, 1.0) * 100.0", "", [F.make_param("bus", "String", "\"Master\"", "Bus", "Audio bus name.", "expression")], CAT, "{bus} volume %")
		.described("Reads a bus's volume back as a 0-100 percent (to set a slider's start value)."))
	descriptors.append(F.make_descriptor("Core", "OptionsIsBusMuted", "Is Bus Muted", ACEDescriptor.ACEType.CONDITION, "AudioServer.is_bus_mute(AudioServer.get_bus_index({bus}))", "", [F.make_param("bus", "String", "\"Master\"", "Bus", "Audio bus name.", "expression")], CAT, "{bus} is muted")
		.described("True when an audio bus is currently muted."))

	# ── Persistence: one setting to a config file (loads what is there, sets, saves) ──
	descriptors.append(F.make_descriptor("Core", "OptionsSaveSetting", "Save Setting", ACEDescriptor.ACEType.ACTION, "var __cfg_{uid} = ConfigFile.new()\n__cfg_{uid}.load(%s)\n__cfg_{uid}.set_value({section}, {key}, {value})\n__cfg_{uid}.save(%s)" % [SETTINGS_PATH, SETTINGS_PATH], "", [F.make_param("section", "String", "\"audio\"", "Section", "A group name in the file (audio, video, ...).", "expression"), F.make_param("key", "String", "\"master_volume\"", "Key", "The setting's name.", "expression"), F.make_param("value", "String", "1.0", "Value", "The value to store (any type).", "expression")], CAT, "save setting {section}/{key} = {value}")
		.described("Writes one setting to user://settings.cfg, keeping the other saved settings intact."))
	descriptors.append(F.make_descriptor("Core", "OptionsHasSavedSettings", "Has Saved Settings", ACEDescriptor.ACEType.CONDITION, "FileAccess.file_exists(%s)" % SETTINGS_PATH, "", [], CAT, "has saved settings")
		.described("True when a settings file has been saved before (so you can load it on startup)."))

	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "The knobs a settings menu changes - audio volume per bus as a 0-100 percent, mute, and saving a setting to a file."}
