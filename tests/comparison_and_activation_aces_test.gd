# EventForge - the comparison vocabulary ("Compare: …") and node activation/pausing ("Nodes: Activation").
#
# Both modules exist to close a gap the operator-based Compare Variable / Compare Values could not:
# comparisons that need a METHOD or a tolerance, and per-node control of whether something runs at all.
#
# The assertions below pin the two things that fail SILENTLY if they regress:
#   - the approximate comparisons. `==` on floats and vectors is a coin flip, so if Values Are Near or
#     Vectors Are Equal ever became a plain `==` the tests would still pass but games would break in
#     ways nobody could reproduce.
#   - the process_mode constants. These are the whole of pausing; a wrong one silently pauses the wrong
#     set of nodes, and the compile gate cannot tell PROCESS_MODE_ALWAYS from PROCESS_MODE_DISABLED.
@tool
class_name ComparisonAndActivationAcesTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true
	var by_id: Dictionary = {}
	for d: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[d.ace_id] = d

	# ---- Comparison: registration and kinds ----
	for aid: String in ["TextEqualsIgnoreCase", "TextBeginsWith", "TextIsEmpty", "TextIsBlank",
			"TextMatchesPattern", "TextIsOneOf", "TextSortsBefore", "TextNaturalOrder",
			"ValuesAreNear", "IsOutsideRange", "IsPositive", "IsNegative", "IsEven", "IsOdd",
			"IsMultipleOf", "IsWholeNumber", "CompareResult",
			"VectorsAreEqual", "IsWithinDistance", "IsFartherThan", "PointsSameDirection",
			"IsLongerThan", "ColorsAreEqual",
			"ValueIsOfType", "ValuesSameType", "ValueTypeName", "ObjectIsClass",
			"IsSameObject", "IsValidInstance", "ObjectHasMethod", "ObjectHasProperty"]:
		ok = _check("%s registered" % aid, by_id.has(aid), true) and ok

	# The approximate comparisons must stay approximate. A plain `==` here would pass every gate and
	# still be wrong: two vectors that went through any arithmetic are almost never exactly equal.
	ok = _check("Values Are Near compares with a tolerance, not ==",
		str(by_id["ValuesAreNear"].codegen_template), "absf({a} - {b}) <= {tolerance}") and ok
	ok = _check("Vectors Are Equal uses Godot's approximate compare",
		str(by_id["VectorsAreEqual"].codegen_template), "{a}.is_equal_approx({b})") and ok
	ok = _check("Colors Are Equal does too",
		str(by_id["ColorsAreEqual"].codegen_template), "{a}.is_equal_approx({b})") and ok

	# Guards: these run against values that may be nothing, or divisors that may be zero.
	ok = _check("Is Multiple Of guards against a zero divisor",
		str(by_id["IsMultipleOf"].codegen_template).contains("int({divisor}) != 0"), true) and ok
	ok = _check("Object Is Class checks for nothing-there first",
		str(by_id["ObjectIsClass"].codegen_template).begins_with("({object} != null and"), true) and ok
	ok = _check("Object Has Method checks for nothing-there first",
		str(by_id["ObjectHasMethod"].codegen_template).begins_with("({object} != null and"), true) and ok
	# Object Still Exists must use is_instance_valid: a freed node is NOT null, so a null check misses
	# it entirely and the next member access crashes.
	ok = _check("Object Still Exists uses is_instance_valid, which a null check cannot replace",
		str(by_id["IsValidInstance"].codegen_template), "is_instance_valid({object})") and ok

	ok = _check("the text comparisons are conditions and the orderings are expressions",
		[by_id["TextEqualsIgnoreCase"].ace_type, by_id["TextNaturalOrder"].ace_type, by_id["CompareResult"].ace_type],
		[ACEDescriptor.ACEType.CONDITION, ACEDescriptor.ACEType.EXPRESSION, ACEDescriptor.ACEType.EXPRESSION]) and ok

	# ---- Node activation + pausing ----
	for aid: String in ["DeactivateNode2D", "ActivateNode2D", "DeactivateNode3D", "ActivateNode3D",
			"NodeIsActive", "NodePause", "NodeResume", "NodeRunWhilePaused", "NodePauseWithGame",
			"NodeOnlyWhenPaused", "NodeSetProcessMode", "NodeGetProcessMode", "NodeIsPausedByGame",
			"NodeSetProcessing", "NodeSetPhysicsProcessing", "NodeSetInputProcessing",
			"NodeSetUnhandledInputProcessing", "NodeIsProcessing", "NodeIsPhysicsProcessing",
			"NodeIsProcessingInput", "NodeSetProcessPriority", "NodeSetPhysicsProcessPriority",
			"NodeIsReady"]:
		ok = _check("%s registered" % aid, by_id.has(aid), true) and ok

	# The pause verbs ARE process_mode - pin each constant, because swapping two of them still
	# compiles and still runs, just pausing the wrong things.
	ok = _check("Pause Node disables the node",
		str(by_id["NodePause"].codegen_template).contains("Node.PROCESS_MODE_DISABLED"), true) and ok
	ok = _check("Unpause Node returns it to following its parent",
		str(by_id["NodeResume"].codegen_template).contains("Node.PROCESS_MODE_INHERIT"), true) and ok
	ok = _check("Keep Running While Paused exempts it from the game pause",
		str(by_id["NodeRunWhilePaused"].codegen_template).contains("Node.PROCESS_MODE_ALWAYS"), true) and ok
	ok = _check("Run Only While Paused is the WHEN_PAUSED mode, not ALWAYS",
		str(by_id["NodeOnlyWhenPaused"].codegen_template).contains("Node.PROCESS_MODE_WHEN_PAUSED"), true) and ok
	ok = _check("Pause With The Game is the PAUSABLE mode",
		str(by_id["NodePauseWithGame"].codegen_template).contains("Node.PROCESS_MODE_PAUSABLE"), true) and ok

	# Deactivate is both halves - stop it running AND stop drawing it. Either alone is a half-off node.
	var deactivate: String = str(by_id["DeactivateNode2D"].codegen_template)
	ok = _check("Deactivate Node hides it AND stops it running",
		deactivate.contains("visible = false") and deactivate.contains("Node.PROCESS_MODE_DISABLED"), true) and ok
	# Node Is Running has to be can_process(): is_processing() only reports the per-frame flag and
	# would answer "yes" for a node the game pause has frozen.
	# The shipped template carries the {target.} prefix every node-scoped ACE gets automatically, so
	# the row can also ask about ANOTHER node - assert the operation, not the whole string.
	ok = _check("Node Is Running asks can_process(), which accounts for the game pause",
		str(by_id["NodeIsActive"].codegen_template), "{target.}can_process()") and ok
	# The property is process_physics_priority; the SETTER is set_physics_process_priority(), so the
	# two read in opposite orders and the wrong one is a parse error.
	ok = _check("the physics order verb uses the property name, not the method name",
		str(by_id["NodeSetPhysicsProcessPriority"].codegen_template), "{target.}process_physics_priority = {priority}") and ok

	# Every new verb explains itself, and the mode dropdown offers all five modes.
	var undescribed: Array[String] = []
	for d: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		if not (str(d.category).begins_with("Compare") or str(d.category) == "Nodes: Activation"):
			continue
		if str(d.description).strip_edges().is_empty():
			undescribed.append(str(d.ace_id))
	ok = _check("every comparison and activation verb carries a description", undescribed, [] as Array[String]) and ok
	ok = _check("the process-mode dropdown offers all five modes",
		_param(by_id["NodeSetProcessMode"], "mode").options.size(), 5) and ok
	ok = _check("the type dropdown offers the everyday Variant types",
		_param(by_id["ValueIsOfType"], "type").options.size(), 11) and ok

	return ok


static func _param(descriptor: ACEDescriptor, param_id: String) -> ACEParam:
	for p: ACEParam in descriptor.params:
		if str(p.id) == param_id:
			return p
	return ACEParam.new()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("comparison_and_activation_aces_test", label, actual, expected)
