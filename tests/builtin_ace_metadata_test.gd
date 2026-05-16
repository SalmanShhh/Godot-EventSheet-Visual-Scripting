# EventForge — Built-in ACE metadata test
@tool
extends RefCounted
class_name BuiltinACEMetadataTest

## Verifies user-facing names/categories while preserving internal IDs.
static func run() -> bool:
	var on_ready: ACEDescriptor = ACERegistry.find_descriptor("Core", "OnReady")
	var on_process: ACEDescriptor = ACERegistry.find_descriptor("Core", "OnProcess")
	var on_signal: ACEDescriptor = ACERegistry.find_descriptor("Core", "OnSignal")
	assert(on_ready != null, "Missing Core/OnReady descriptor")
	assert(on_process != null, "Missing Core/OnProcess descriptor")
	assert(on_signal != null, "Missing Core/OnSignal descriptor")
	assert(on_ready.display_name == "On Ready", "OnReady display_name mismatch")
	assert(on_process.display_name == "On Process", "OnProcess display_name mismatch")
	assert(on_signal.display_name == "On Signal", "OnSignal display_name mismatch")
	assert(on_signal.params.size() == 2, "OnSignal should expose target_node and signal_name params")
	assert(on_ready.category == "System", "OnReady category should be System")
	assert(on_process.category == "System", "OnProcess category should be System")
	assert(on_signal.category == "Signals", "OnSignal category should be Signals")
	assert(on_ready.ace_id == "OnReady", "OnReady internal ID changed unexpectedly")
	assert(on_process.ace_id == "OnProcess", "OnProcess internal ID changed unexpectedly")
	print("[PASS] builtin_ace_metadata_test")
	return true
