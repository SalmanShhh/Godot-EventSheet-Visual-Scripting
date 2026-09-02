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
	descriptors.append(F.act("CameraShakeOnce", "Shake", "offset = Vector2(randf_range(-{amount}, {amount}), randf_range(-{amount}, {amount}))", CAT, "Shake by {amount}", "Jolts this camera by a random offset for one tick. Run it every tick while a hit lands.", "Camera2D").param("amount", "4.0", "Amount", "Biggest offset in pixels, this tick.", "expression"))
	descriptors.append(F.act("Hitstop", "Hitstop", "Engine.time_scale = {scale}\nawait get_tree().create_timer({seconds}, true, false, true).timeout\nEngine.time_scale = 1.0", CAT, "Hitstop for {seconds} seconds", "Slows the whole game to a crawl for a moment and then restores it - the punch a hit lands with.").param("seconds", "0.05", "Seconds", "How long the freeze lasts, in real time.", "expression").param("scale", "0.1", "Time scale", "0 = frozen, 1 = normal speed.", "expression"))
	descriptors.append(F.act("BobY", "Bob", "position.y = {base} + sin({time} * {frequency}) * {magnitude}", CAT, "Bob y", "Floats this object up and down on a sine wave. Run it every tick.", "Node2D").param("base", "0.0", "Around", "The height it bobs around.", "expression").param("time", "Time.get_ticks_msec() / 1000.0", "Time", "A number that grows every tick - the clock, or a variable you add delta to.", "expression").param("frequency", "3.0", "Per second", "How many bobs a second.", "expression").param("magnitude", "8.0", "Magnitude", "How far it moves, in pixels.", "expression"))
	descriptors.append(F.act("FlashColour", "Flash", "modulate = {colour}\nawait get_tree().create_timer({seconds}).timeout\nmodulate = Color.WHITE", CAT, "Flash {colour} for {seconds} seconds", "Tints this object for a moment and then puts it back - the damage flash.", "CanvasItem").param("colour", "Color.RED", "Colour", "The tint to flash.", "color").param("seconds", "0.1", "Seconds", "How long the flash lasts.", "expression"))
	descriptors.append(F.act("EaseSizeBack", "Ease Size Back", "scale = scale.lerp(Vector2.ONE, {rate} * delta)", CAT, "Ease size back to normal at {rate}", "Eases this object's size back to normal, which is how a squash recovers. Run it every tick.", "Node2D").param("rate", "10.0", "Rate", "How fast it recovers, per second.", "expression"))
	return descriptors
