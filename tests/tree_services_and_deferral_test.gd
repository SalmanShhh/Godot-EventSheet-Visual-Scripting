# Godot EventSheets - Ask The Tree (named services + capability lookup) and the deferral trio
# (Do After This Frame, Call Later, Only Once This Frame, Set Property (after this frame)).
#
# Two halves, in the order the vocabulary is trusted:
#   1. EMISSION  the descriptors compile into a real sheet and the emitted lines are pinned
#      verbatim, uid baked, with no {uid} left anywhere.
#   2. RUNTIME   every template is then RUN. The suite has no live scene tree (run_tests.gd works
#      inside SceneTree._init, where Engine.get_main_loop() is still null), so the harness below
#      takes each SHIPPED template string and substitutes `get_tree()` for `_tree()`, a stand-in
#      that answers get_meta / set_meta / get_root / create_timer. Every other character of the
#      template runs exactly as it ships, and the `get_tree()` half is pinned by the emission
#      checks above - the same compromise translation_runtime_words_test documents.
#
# The one thing that cannot be observed here is a deferred call actually landing: Godot flushes
# the message queue from the main loop, which never runs during the suite. What IS proved is the
# promise the verb makes - the action does NOT run now - plus the pinned call_deferred emission.
@tool
class_name TreeServicesAndDeferralTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true
	ok = _test_emission() and ok
	ok = _test_services_runtime() and ok
	ok = _test_capability_sweep_runtime() and ok
	ok = _test_deferral_runtime() and ok
	ok = _test_once_this_frame_runtime() and ok
	return ok


## Every new verb through the real compiler, with its defaults, and the emitted lines pinned.
static func _test_emission() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var row: EventRow = EventRow.new()
	row.trigger_id = "OnReady"
	row.trigger_provider_id = "Core"
	row.conditions.append(_baked_cond("HasService", {"service_name": "\"audio_director\""}, "h1"))
	row.conditions.append(_baked_cond("OnceThisFrame", {"key_id": "\"rebuild_bag\""}, "q1"))
	row.actions.append(_baked_act("RegisterAsService", {"service_name": "\"player\""}, "s1"))
	row.actions.append(_baked_act("DoAfterFrame", {"do": "queue_free()"}, "d1"))
	row.actions.append(_baked_act("CallLater", {"seconds": "0.15", "do": "queue_free()"}, "c1"))
	row.actions.append(_baked_act("SetPropertyDeferred", {"target": "self", "property": "\"visible\"", "value": "true"}, "p1"))
	sheet.events.append(row)
	var output: String = str(SheetCompiler.compile(sheet, "user://tree_services_out.gd").get("output", ""))

	ok = _check("Register As Service reads the shelf off the tree",
		output.contains("var __svc_s1: Dictionary = get_tree().get_meta(&\"__ef_services\", {})"), true) and ok
	ok = _check("Register As Service publishes self under the name",
		output.contains("__svc_s1[\"player\"] = self"), true) and ok
	# Deliberately NO tree_exiting eraser: a node that has already been replaced under its name would
	# delete its replacement's live registration on the way out, which is the ordinary scene-reload
	# order. Both readers test is_instance_valid instead, so a freed holder answers nothing anyway.
	ok = _check("Register As Service hangs nothing on tree_exiting",
		output.contains("tree_exiting.connect("), false) and ok
	ok = _check("Has Service guards against a freed node",
		output.contains("is_instance_valid(get_tree().get_meta(&\"__ef_services\", {}).get(\"audio_director\", null))"), true) and ok
	ok = _check("Do After This Frame defers a lambda",
		output.contains("(func(): queue_free()).call_deferred()"), true) and ok
	ok = _check("Call Later connects the timer's timeout one-shot",
		output.contains("get_tree().create_timer(maxf(0.15, 0.0)).timeout.connect(func(): queue_free(), CONNECT_ONE_SHOT)"), true) and ok
	ok = _check("Set Property (after this frame) uses set_deferred",
		output.contains("self.set_deferred(\"visible\", true)"), true) and ok
	ok = _check("Only Once This Frame calls its synthesized helper",
		output.contains("__once_frame_q1(\"rebuild_bag\")"), true) and ok
	ok = _check("Only Once This Frame declares the helper with the baked uid",
		output.contains("func __once_frame_q1(key: String) -> bool:"), true) and ok
	# The claim stamps BOTH clocks: physics can tick more than once inside one drawn frame, and a row
	# under On Physics Process means that tick when it says "this frame".
	ok = _check("Only Once This Frame claims the drawn frame and the physics tick together",
		output.contains("var stamp: String = str(Engine.get_process_frames()) + \":\" + str(Engine.get_physics_frames())"), true) and ok
	ok = _check("and stores that stamp under the name",
		output.contains("__once_frames_q1[key] = stamp"), true) and ok
	ok = _check("no {uid} survives into emitted code", output.contains("{uid}"), false) and ok
	var parsed: GDScript = GDScript.new()
	parsed.source_code = output
	ok = _check("the emitted sheet parses", parsed.reload(), OK) and ok

	# The capability sweep is a LOOPING condition, so its contract is the pick filter, not an
	# `and` term: pinned off the live descriptor rather than off an emitted if-line.
	var sweep: ACEDescriptor = ACERegistry.find_descriptor("Core", "ForEachNodeThatCan")
	ok = _check("For Each Node That Can is a condition", sweep.ace_type, ACEDescriptor.ACEType.CONDITION) and ok
	ok = _check("For Each Node That Can is a loop row", sweep.is_looping, true) and ok
	ok = _check("its items arrive as `node`", sweep.looping_iterator, "node") and ok
	ok = _check("Service Named is an expression",
		ACERegistry.find_descriptor("Core", "ServiceNamed").ace_type, ACEDescriptor.ACEType.EXPRESSION) and ok
	ok = _check("Only Once This Frame is hoisted to the end of the and-chain",
		ACERegistry.find_descriptor("Core", "OnceThisFrame").evaluate_last, true) and ok
	return ok


## Register As Service / Service Named / Has Service, running the shipped templates.
static func _test_services_runtime() -> bool:
	var ok: bool = true
	var register: String = _runnable("RegisterAsService", {"service_name": "\"player\""}, "s1")
	var lookup: String = _runnable("ServiceNamed", {"service_name": "\"player\""}, "s1")
	var has: String = _runnable("HasService", {"service_name": "\"player\""}, "s1")
	var source: String = "extends Node\n\nvar shelf: Object = null\n\nfunc _tree() -> Object:\n\treturn shelf\n\nfunc register() -> void:\n\t%s\n\nfunc lookup() -> Variant:\n\treturn %s\n\nfunc has_it() -> bool:\n\treturn %s\n" % [register.replace("\n", "\n\t"), lookup, has]
	var script: GDScript = GDScript.new()
	script.source_code = source
	ok = _check("the services harness parses", script.reload(), OK) and ok
	if script.reload() != OK:
		return ok

	var shelf: Node = Node.new()
	var player: Node = script.new()
	player.shelf = shelf
	ok = _check("nothing is registered to begin with", player.has_it(), false) and ok
	ok = _check("an unregistered name answers nothing", player.lookup(), null) and ok
	player.register()
	ok = _check("after registering, the name exists", player.has_it(), true) and ok
	ok = _check("and answers with the node that registered", player.lookup() == player, true) and ok

	ok = _check("and registering hangs nothing on the node's tree_exiting",
		player.get_signal_connection_list("tree_exiting").size(), 0) and ok

	# A second registration under the same name REPLACES, which is what makes a scene reload safe.
	var replacement: Node = script.new()
	replacement.shelf = shelf
	replacement.register()
	ok = _check("re-registering replaces the holder", player.lookup() == replacement, true) and ok

	# THE scene-reload order, which an eraser hung on tree_exiting used to get wrong: the node that
	# was replaced leaves and is freed AFTER its replacement has taken the name. The live
	# registration must survive that - it belongs to the replacement, not to the node going away.
	var reader: Node = script.new()
	reader.shelf = shelf
	player.free()
	ok = _check("the replaced node going away leaves its replacement registered",
		reader.lookup() == replacement, true) and ok
	ok = _check("and Has Service still says yes", reader.has_it(), true) and ok

	# The freed case: the shelf still holds the entry, and the is_instance_valid guard is what
	# turns it back into "nothing" rather than a crash.
	replacement.free()
	ok = _check("a freed service answers nothing", reader.lookup(), null) and ok
	ok = _check("and Has Service says no", reader.has_it(), false) and ok
	reader.free()
	shelf.free()
	return ok


## For Each Node That Can: the has_method filter over the whole tree.
static func _test_capability_sweep_runtime() -> bool:
	var ok: bool = true
	var sweep: String = _runnable("ForEachNodeThatCan", {"method_name": "\"save_state\""}, "f1")
	var source: String = "extends Node\n\nvar fake: Object = null\n\nfunc _tree() -> Object:\n\treturn fake\n\nfunc sweep() -> Array:\n\treturn %s\n" % sweep
	var script: GDScript = GDScript.new()
	script.source_code = source
	ok = _check("the sweep harness parses", script.reload(), OK) and ok
	if script.reload() != OK:
		return ok

	var saver_script: GDScript = GDScript.new()
	saver_script.source_code = "extends Node\n\nfunc save_state() -> Dictionary:\n\treturn {}\n"
	ok = _check("the saver stand-in parses", saver_script.reload(), OK) and ok

	var root: Node = Node.new()
	var saver: Node = Node.new()
	saver.set_script(saver_script)
	saver.name = "Saver"
	var plain: Node = Node.new()
	plain.name = "Plain"
	var nested: Node = Node.new()
	nested.set_script(saver_script)
	nested.name = "Nested"
	root.add_child(saver)
	root.add_child(plain)
	saver.add_child(nested)

	var fake_script: GDScript = GDScript.new()
	fake_script.source_code = "extends Node\n\nvar root_node: Node = null\n\nfunc get_root() -> Node:\n\treturn root_node\n"
	fake_script.reload()
	var fake: Node = Node.new()
	fake.set_script(fake_script)
	fake.root_node = root

	var host: Node = script.new()
	host.fake = fake
	var found: Array = host.sweep()
	var names: Array = []
	for item: Variant in found:
		names.append(str((item as Node).name))
	names.sort()
	ok = _check("only the nodes that answer to the method are picked, at any depth", names, ["Nested", "Saver"]) and ok

	# find_children skips the node it is called on, so the sweep offers the root itself separately -
	# otherwise an autoload or a scene root that answers to the method is silently left out of a save
	# or shutdown sweep the blurb promises covers the tree.
	root.name = "Root"
	root.set_script(saver_script)
	var with_root: Array = []
	for item: Variant in host.sweep():
		with_root.append(str((item as Node).name))
	with_root.sort()
	ok = _check("and the tree root itself is offered when it answers too", with_root, ["Nested", "Root", "Saver"]) and ok

	host.free()
	fake.free()
	root.free()
	return ok


## Do After This Frame, Call Later and Set Property (after this frame).
static func _test_deferral_runtime() -> bool:
	var ok: bool = true
	var defer_line: String = _runnable("DoAfterFrame", {"do": "flag = true"}, "d1")
	var later_line: String = _runnable("CallLater", {"seconds": "0.15", "do": "flag = true"}, "c1")
	var property_line: String = _runnable("SetPropertyDeferred", {"target": "self", "property": "\"flag\"", "value": "true"}, "p1")
	var source: String = "extends Node\n\nvar flag: bool = false\nvar fake: Object = null\n\nfunc _tree() -> Object:\n\treturn fake\n\nfunc do_after_frame() -> void:\n\t%s\n\nfunc call_later() -> void:\n\t%s\n\nfunc set_after_frame() -> void:\n\t%s\n" % [defer_line, later_line, property_line]
	var script: GDScript = GDScript.new()
	script.source_code = source
	ok = _check("the deferral harness parses", script.reload(), OK) and ok
	if script.reload() != OK:
		return ok

	var timer_script: GDScript = GDScript.new()
	timer_script.source_code = "extends RefCounted\n\nsignal timeout\n"
	timer_script.reload()
	var fake_tree_script: GDScript = GDScript.new()
	fake_tree_script.source_code = "extends Node\n\nvar timer: RefCounted = null\nvar asked_for: float = -1.0\n\nfunc create_timer(seconds: float) -> RefCounted:\n\tasked_for = seconds\n\treturn timer\n"
	fake_tree_script.reload()

	# Do After This Frame: the whole promise is that it does NOT run now.
	var host: Node = script.new()
	host.do_after_frame()
	ok = _check("Do After This Frame has not run the action yet", host.flag, false) and ok

	# Set Property (after this frame): same promise, on a property.
	host.flag = false
	host.set_after_frame()
	ok = _check("Set Property (after this frame) has not written yet", host.flag, false) and ok

	# Call Later: connected, not awaited, and one-shot.
	var timer: RefCounted = timer_script.new()
	var fake_tree: Node = Node.new()
	fake_tree.set_script(fake_tree_script)
	fake_tree.timer = timer
	host.fake = fake_tree
	host.flag = false
	host.call_later()
	ok = _check("Call Later asked for the delay it was given", fake_tree.asked_for, 0.15) and ok
	ok = _check("Call Later did not run the action immediately", host.flag, false) and ok
	ok = _check("and did not suspend the caller either", host.flag, false) and ok
	timer.timeout.emit()
	ok = _check("the action runs when the delay is up", host.flag, true) and ok
	host.flag = false
	timer.timeout.emit()
	ok = _check("and never a second time (CONNECT_ONE_SHOT)", host.flag, false) and ok

	host.free()
	fake_tree.free()
	return ok


## Only Once This Frame: the synthesized per-frame claim.
static func _test_once_this_frame_runtime() -> bool:
	var ok: bool = true
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "OnceThisFrame")
	var member: String = descriptor.member_template.replace("{uid}", "q1")
	var call_line: String = descriptor.codegen_template.replace("{uid}", "q1").replace("{key_id}", "key")
	var source: String = "extends RefCounted\n\n%s\n\nfunc gate(key: String) -> bool:\n\treturn %s\n" % [member, call_line]
	var script: GDScript = GDScript.new()
	script.source_code = source
	ok = _check("the once-this-frame harness parses", script.reload(), OK) and ok
	if script.reload() != OK:
		return ok

	var gate: RefCounted = script.new()
	ok = _check("the first reach in a frame passes", gate.gate("rebuild_bag"), true) and ok
	ok = _check("the second is swallowed", gate.gate("rebuild_bag"), false) and ok
	ok = _check("the fiftieth too", gate.gate("rebuild_bag"), false) and ok
	ok = _check("a different name has its own gate", gate.gate("play_sound"), true) and ok
	ok = _check("and folds on its own name", gate.gate("play_sound"), false) and ok
	var claimed: Dictionary = gate.get("__once_frames_q1")
	ok = _check("the claim is keyed on the frame counter", int(claimed["rebuild_bag"]), Engine.get_process_frames()) and ok
	# The frame counter cannot advance inside the suite, so the NEXT frame is simulated by aging
	# the claim by one - which is exactly the state the gate would find on the following frame.
	claimed["rebuild_bag"] = Engine.get_process_frames() - 1
	ok = _check("the next frame re-arms it", gate.gate("rebuild_bag"), true) and ok
	return ok


## The shipped template with its uid and parameters baked, and `get_tree()` pointed at the
## harness stand-in. Nothing else about the template is touched.
static func _runnable(ace_id: String, params: Dictionary, uid: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	var text: String = descriptor.codegen_template.replace("{uid}", uid)
	for key: String in params:
		text = text.replace("{%s}" % key, str(params[key]))
	return text.replace("get_tree()", "_tree()")


static func _baked_cond(ace_id: String, params: Dictionary, uid: String) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	condition.codegen_template = descriptor.codegen_template.replace("{uid}", uid)
	condition.member_declaration = descriptor.member_template.replace("{uid}", uid)
	return condition


static func _baked_act(ace_id: String, params: Dictionary, uid: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	action.codegen_template = descriptor.codegen_template.replace("{uid}", uid)
	return action


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("tree_services_and_deferral_test", label, actual, expected)
