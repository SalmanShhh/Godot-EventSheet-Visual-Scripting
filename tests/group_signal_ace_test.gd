# EventForge - decoupled group-scoped messaging ACEs.
#
# The "your nodes are too connected" fix: a listener reacts to a signal on a WHOLE GROUP of emitters with no
# per-node reference (Connect/Disconnect Group Signal, the observer direction), and a broadcast carries data
# to a whole group with no reference (Call Method On Group with value, the send direction). Both compile to
# plain get_nodes_in_group / call_group GDScript - no plugin dependency. Pins the exact emitted shape,
# including the is_connected idempotency guard and the {, args} optional-comma that drops when the value is
# blank. {uid} is supplied here exactly as the dock bakes it at apply time.
@tool
class_name GroupSignalAceTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# Connect Group Signal: wire the listener to `died` on every current member of "enemies", idempotently,
	# with no direct reference to any enemy.
	var connect_group: ACEAction = ACEAction.new()
	connect_group.provider_id = "Core"
	connect_group.ace_id = "ConnectGroupSignal"
	connect_group.enabled = true
	connect_group.params = {"group": "\"enemies\"", "signal": "died", "callable": "_on_enemy_died", "uid": "7"}
	var expected_connect: String = "for __emitter_7: Node in get_tree().get_nodes_in_group(\"enemies\"):\n\tif not __emitter_7.died.is_connected(_on_enemy_died):\n\t\t__emitter_7.died.connect(_on_enemy_died)"
	ok = _check("Connect Group Signal loops the group and guards with is_connected", ActionCodegen.generate_action(connect_group, "", ""), expected_connect) and ok

	# Disconnect Group Signal: the symmetric teardown (guard is_connected TRUE before disconnecting).
	var disconnect_group: ACEAction = ACEAction.new()
	disconnect_group.provider_id = "Core"
	disconnect_group.ace_id = "DisconnectGroupSignal"
	disconnect_group.enabled = true
	disconnect_group.params = {"group": "\"enemies\"", "signal": "died", "callable": "_on_enemy_died", "uid": "7"}
	var expected_disconnect: String = "for __emitter_7: Node in get_tree().get_nodes_in_group(\"enemies\"):\n\tif __emitter_7.died.is_connected(_on_enemy_died):\n\t\t__emitter_7.died.disconnect(_on_enemy_died)"
	ok = _check("Disconnect Group Signal unwires the whole group", ActionCodegen.generate_action(disconnect_group, "", ""), expected_disconnect) and ok

	# Call Method On Group (with value): a decoupled broadcast that carries data.
	var call_with: ACEAction = ACEAction.new()
	call_with.provider_id = "Core"
	call_with.ace_id = "CallGroupWith"
	call_with.enabled = true
	call_with.params = {"group": "\"enemies\"", "method": "\"take_damage\"", "args": "10"}
	ok = _check("Call Group (with value) passes the value to every member", ActionCodegen.generate_action(call_with, "", ""), "get_tree().call_group(\"enemies\", \"take_damage\", 10)") and ok

	# Blank value: the {, args} optional-comma drops cleanly to a bare call_group (no trailing comma).
	var call_blank: ACEAction = ACEAction.new()
	call_blank.provider_id = "Core"
	call_blank.ace_id = "CallGroupWith"
	call_blank.enabled = true
	call_blank.params = {"group": "\"enemies\"", "method": "\"reset\"", "args": ""}
	ok = _check("Call Group (with value) drops the comma when the value is blank", ActionCodegen.generate_action(call_blank, "", ""), "get_tree().call_group(\"enemies\", \"reset\")") and ok

	# Safe single-node wiring: plain Connect Signal stacks a duplicate handler when re-run, so these two
	# make re-running harmless - guard on is_connected, or let the connection fire once and drop itself.
	var connect_unique: ACEAction = ACEAction.new()
	connect_unique.provider_id = "Core"
	connect_unique.ace_id = "ConnectSignalUnique"
	connect_unique.enabled = true
	connect_unique.params = {"source": "self", "signal": "pressed", "callable": "_on_pressed"}
	ok = _check("Connect Signal (if not already) guards against a duplicate handler", ActionCodegen.generate_action(connect_unique, "", ""), "if not self.pressed.is_connected(_on_pressed):\n\tself.pressed.connect(_on_pressed)") and ok

	var connect_once: ACEAction = ACEAction.new()
	connect_once.provider_id = "Core"
	connect_once.ace_id = "ConnectSignalOneShot"
	connect_once.enabled = true
	connect_once.params = {"source": "self", "signal": "pressed", "callable": "_on_pressed"}
	ok = _check("Connect Signal (one-shot) drops itself after firing", ActionCodegen.generate_action(connect_once, "", ""), "self.pressed.connect(_on_pressed, CONNECT_ONE_SHOT)") and ok

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] group_signal_ace_test: %s" % label)
		return true
	print("[FAIL] group_signal_ace_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
