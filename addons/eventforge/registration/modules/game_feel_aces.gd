# EventForge module - Game Feel: the five snippets every game copies, as rows.
#
# Each row writes the exact shape the opened-script reading recognises, so a game-feel pattern typed
# by hand and the same pattern dropped from the picker are the same bytes and read the same words:
#
#   Shake            offset = Vector2(randf_range(-4, 4), randf_range(-4, 4))
#   Hitstop          Engine.time_scale down, a real-time wait, then back to 1
#   Bob              position.y = base + sin(t * f) * magnitude
#   Flash            modulate = a colour, a wait, then back to white
#   Ease size back   scale = scale.lerp(Vector2.ONE, rate * delta)
#
# The Juice, Sine and Flash behavior packs do all of this and more with state of their own (decaying
# trauma, composed camera effects, an On Finished trigger), so attaching one of them is the first
# option and these one-liners are the second. Module contract: see ace_factory.gd - ace_ids/templates
# are API (covenant).
@tool
class_name EventForgeGameFeelACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Juice"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.make_descriptor("Core", "CameraShakeOnce", "Shake", ACEDescriptor.ACEType.ACTION,
		"offset = Vector2(randf_range(-{amount}, {amount}), randf_range(-{amount}, {amount}))", "", [
			F.make_param("amount", "String", "4.0", "Amount", "Biggest offset in pixels, this tick.", "expression")
		], CAT, "Shake by {amount}", "Camera2D")
		.described("Jolts this camera by a random offset for one tick. Run it every tick while a hit lands."))
	descriptors.append(F.make_descriptor("Core", "Hitstop", "Hitstop", ACEDescriptor.ACEType.ACTION,
		"Engine.time_scale = {scale}\nawait get_tree().create_timer({seconds}, true, false, true).timeout\nEngine.time_scale = 1.0",
		"", [
			F.make_param("seconds", "String", "0.05", "Seconds", "How long the freeze lasts, in real time.", "expression"),
			F.make_param("scale", "String", "0.1", "Time scale", "0 = frozen, 1 = normal speed.", "expression")
		], CAT, "Hitstop for {seconds} seconds")
		.described("Slows the whole game to a crawl for a moment and then restores it - the punch a hit lands with."))
	descriptors.append(F.make_descriptor("Core", "BobY", "Bob", ACEDescriptor.ACEType.ACTION,
		"position.y = {base} + sin({time} * {frequency}) * {magnitude}", "", [
			F.make_param("base", "String", "0.0", "Around", "The height it bobs around.", "expression"),
			F.make_param("time", "String", "Time.get_ticks_msec() / 1000.0", "Time",
				"A number that grows every tick - the clock, or a variable you add delta to.", "expression"),
			F.make_param("frequency", "String", "3.0", "Per second", "How many bobs a second.", "expression"),
			F.make_param("magnitude", "String", "8.0", "Magnitude", "How far it moves, in pixels.", "expression")
		], CAT, "Bob y", "Node2D")
		.described("Floats this object up and down on a sine wave. Run it every tick."))
	descriptors.append(F.make_descriptor("Core", "FlashColour", "Flash", ACEDescriptor.ACEType.ACTION,
		"modulate = {colour}\nawait get_tree().create_timer({seconds}).timeout\nmodulate = Color.WHITE", "", [
			F.make_param("colour", "String", "Color.RED", "Colour", "The tint to flash.", "color"),
			F.make_param("seconds", "String", "0.1", "Seconds", "How long the flash lasts.", "expression")
		], CAT, "Flash {colour} for {seconds} seconds", "CanvasItem")
		.described("Tints this object for a moment and then puts it back - the damage flash."))
	descriptors.append(F.make_descriptor("Core", "EaseSizeBack", "Ease Size Back", ACEDescriptor.ACEType.ACTION,
		"scale = scale.lerp(Vector2.ONE, {rate} * delta)", "", [
			F.make_param("rate", "String", "10.0", "Rate", "How fast it recovers, per second.", "expression")
		], CAT, "Ease size back to normal at {rate}", "Node2D")
		.described("Eases this object's size back to normal, which is how a squash recovers. Run it every tick."))
	return descriptors
