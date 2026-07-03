# EventForge — trigger tempo classification. TriggerResolver.tempo_class_for
# maps every trigger id to one of four TEMPO classes (every-tick / input / once / signal) so a row's
# badge says HOW OFTEN it runs. Pins the mapping + exhaustiveness: every id resolve_trigger recognises
# classifies to a known class, and any unknown id falls to signal (the honest default).
@tool
class_name TriggerTempoTest
extends RefCounted

# The full id census of TriggerResolver.resolve_trigger, grouped by expected tempo. Kept in lock-step
# with resolve_trigger's match (both live in trigger_resolver.gd) — a new trigger id must land here too.
const EVERY_TICK := ["OnProcess", "OnPhysicsProcess", "OnPostTick", "OnPhysicsPostTick"]
const INPUT := ["OnInput", "OnUnhandledInput"]
const ONCE := ["OnReady", "OnEditorRun"]
const SIGNAL := [
	"OnCloseRequested", "OnBodyEntered", "OnAreaEntered", "OnBodyExited", "OnAreaExited", "OnTimeout",
	"OnAnimationFinished", "OnButtonPressed", "OnButtonToggled", "OnParticlesFinished", "OnTreeEntered",
	"OnTreeExiting", "OnTreeExited", "OnRenamed", "OnChildEnteredTree", "OnSignal",
]


static func run() -> bool:
	var ok: bool = true
	var known: Array[String] = [TriggerResolver.TEMPO_EVERY_TICK, TriggerResolver.TEMPO_INPUT, TriggerResolver.TEMPO_ONCE, TriggerResolver.TEMPO_SIGNAL]

	for id: String in EVERY_TICK:
		ok = _check("%s is every-tick" % id, TriggerResolver.tempo_class_for(id), TriggerResolver.TEMPO_EVERY_TICK) and ok
	for id: String in INPUT:
		ok = _check("%s is input" % id, TriggerResolver.tempo_class_for(id), TriggerResolver.TEMPO_INPUT) and ok
	for id: String in ONCE:
		ok = _check("%s is once" % id, TriggerResolver.tempo_class_for(id), TriggerResolver.TEMPO_ONCE) and ok
	for id: String in SIGNAL:
		ok = _check("%s is signal" % id, TriggerResolver.tempo_class_for(id), TriggerResolver.TEMPO_SIGNAL) and ok

	# Custom "signal:<name>" triggers + any unknown id fall to the signal default — never unclassified.
	ok = _check("signal:custom_event is signal", TriggerResolver.tempo_class_for("signal:custom_event"), TriggerResolver.TEMPO_SIGNAL) and ok
	ok = _check("an unknown id is signal (honest default)", TriggerResolver.tempo_class_for("SomethingNew"), TriggerResolver.TEMPO_SIGNAL) and ok
	ok = _check("an empty id is signal", TriggerResolver.tempo_class_for(""), TriggerResolver.TEMPO_SIGNAL) and ok

	# Exhaustiveness: every census id classifies to one of the four known classes (no typo'd class).
	var all_ids: Array = EVERY_TICK + INPUT + ONCE + SIGNAL
	var all_known: bool = true
	for id: String in all_ids:
		if not known.has(TriggerResolver.tempo_class_for(id)):
			all_known = false
			print("  unclassified: %s -> %s" % [id, TriggerResolver.tempo_class_for(id)])
	ok = _check("every census id maps to a known tempo class", all_known, true) and ok

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] trigger_tempo_test: %s" % label)
		return true
	print("[FAIL] trigger_tempo_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
