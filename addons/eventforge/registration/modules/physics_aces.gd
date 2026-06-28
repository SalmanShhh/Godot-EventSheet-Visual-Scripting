# EventForge module — Physics joints (Joint2D / Joint3D)
#
# Wire joint bodies, tune spring/pin params, and break a joint at runtime (clearing node_b).
# Lane-1 wraps of native joint nodes, single-line per the parity contract (no multi-line
# templates — single-property ACEs are canonical). node_a/node_b are NodePath expressions.
# Module contract: see ace_factory.gd — ace_ids/templates are API (covenant).
@tool
extends RefCounted
class_name EventForgePhysicsACEs

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── 2D joints ──
	descriptors.append(F.make_descriptor("Core", "SetJointBodyA", "Set Joint Body A", ACEDescriptor.ACEType.ACTION, "node_a = {target}", "", [F.make_param("target", "String", "^\"../BodyA\"", "Body A", "NodePath of the first body.", "expression")], "Joints", "Set joint body A to {target}", "Joint2D")
		.described("Sets the first physics body a joint connects to."))
	descriptors.append(F.make_descriptor("Core", "SetJointBodyB", "Set Joint Body B", ACEDescriptor.ACEType.ACTION, "node_b = {target}", "", [F.make_param("target", "String", "^\"../BodyB\"", "Body B", "NodePath of the second body.", "expression")], "Joints", "Set joint body B to {target}", "Joint2D")
		.described("Sets the second physics body a joint connects to."))
	descriptors.append(F.make_descriptor("Core", "BreakJoint", "Break Joint", ACEDescriptor.ACEType.ACTION, "node_b = NodePath(\"\")", "", [], "Joints", "Break the joint", "Joint2D")
		.described("Breaks a joint by clearing its second body, e.g. snapping a rope or chain."))
	descriptors.append(F.make_descriptor("Core", "SetJointDisableCollision", "Set Disable Collision", ACEDescriptor.ACEType.ACTION, "disable_collision = {disabled}", "", [F.make_param("disabled", "String", "true", "Disabled", "Disable collision between bodies?", "", ["true", "false"])], "Joints", "Set disable collision {disabled}", "Joint2D")
		.described("Toggles whether the two bodies linked by the joint can collide with each other."))
	descriptors.append(F.make_descriptor("Core", "SetPinJointSoftness", "Set Pin Softness", ACEDescriptor.ACEType.ACTION, "softness = {softness}", "", [F.make_param("softness", "String", "0.0", "Softness", "Pin joint softness.", "expression")], "Joints", "Set pin softness to {softness}", "PinJoint2D")
		.described("Sets how springy a pin joint is, higher values make the link looser."))
	descriptors.append(F.make_descriptor("Core", "SetDampedSpringLength", "Set Spring Rest Length", ACEDescriptor.ACEType.ACTION, "rest_length = {length}", "", [F.make_param("length", "String", "50.0", "Rest Length", "Spring rest length.", "expression")], "Joints", "Set spring rest length to {length}", "DampedSpringJoint2D")
		.described("Sets a spring joint's resting length, the distance it tries to hold."))
	descriptors.append(F.make_descriptor("Core", "SetDampedSpringStiffness", "Set Spring Stiffness", ACEDescriptor.ACEType.ACTION, "stiffness = {stiffness}", "", [F.make_param("stiffness", "String", "20.0", "Stiffness", "Spring stiffness.", "expression")], "Joints", "Set spring stiffness to {stiffness}", "DampedSpringJoint2D")
		.described("Sets how rigid a damped spring joint feels, so it snaps back harder or softer."))
	descriptors.append(F.make_descriptor("Core", "SetDampedSpringDamping", "Set Spring Damping", ACEDescriptor.ACEType.ACTION, "damping = {damping}", "", [F.make_param("damping", "String", "1.0", "Damping", "Spring damping.", "expression")], "Joints", "Set spring damping to {damping}", "DampedSpringJoint2D")
		.described("Sets how quickly a damped spring stops bouncing, controlling its wobble."))

	# ── 3D joints ──
	descriptors.append(F.make_descriptor("Core", "SetJointBodyA3D", "Set Joint Body A (3D)", ACEDescriptor.ACEType.ACTION, "node_a = {target}", "", [F.make_param("target", "String", "^\"../BodyA\"", "Body A", "NodePath of the first body.", "expression")], "Joints", "Set joint body A to {target}", "Joint3D")
		.described("Picks the first 3D body a joint connects, wiring up what it links to."))
	descriptors.append(F.make_descriptor("Core", "SetJointBodyB3D", "Set Joint Body B (3D)", ACEDescriptor.ACEType.ACTION, "node_b = {target}", "", [F.make_param("target", "String", "^\"../BodyB\"", "Body B", "NodePath of the second body.", "expression")], "Joints", "Set joint body B to {target}", "Joint3D")
		.described("Picks the second 3D body a joint connects, completing the link."))
	descriptors.append(F.make_descriptor("Core", "BreakJoint3D", "Break Joint (3D)", ACEDescriptor.ACEType.ACTION, "node_b = NodePath(\"\")", "", [], "Joints", "Break the joint", "Joint3D")
		.described("Snaps a 3D joint apart by clearing its second body, releasing the connection."))

	return descriptors
