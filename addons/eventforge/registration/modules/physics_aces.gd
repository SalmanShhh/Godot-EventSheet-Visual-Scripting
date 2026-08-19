# EventForge module - Physics joints (Joint2D / Joint3D)
#
# Wire joint bodies, tune spring/pin params, and break a joint at runtime (clearing node_b).
# Lane-1 wraps of native joint nodes, single-line per the parity contract (no multi-line
# templates - single-property ACEs are canonical). node_a/node_b are NodePath expressions.
# Module contract: see ace_factory.gd - ace_ids/templates are API (covenant).
@tool
class_name EventForgePhysicsACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── 2D joints ──
	descriptors.append(F.make_descriptor("Core", "SetJointBodyA", "Set Joint Body A", ACEDescriptor.ACEType.ACTION, "node_a = {target}", "", [F.make_param("target", "String", "^\"../BodyA\"", "Body A", "NodePath of the first body.", "expression")], "Joints", "Set joint body A to [i]{target}[/i]", "Joint2D")
		.described("Sets the first physics body a joint connects to."))
	descriptors.append(F.make_descriptor("Core", "SetJointBodyB", "Set Joint Body B", ACEDescriptor.ACEType.ACTION, "node_b = {target}", "", [F.make_param("target", "String", "^\"../BodyB\"", "Body B", "NodePath of the second body.", "expression")], "Joints", "Set joint body B to [i]{target}[/i]", "Joint2D")
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
	descriptors.append(F.make_descriptor("Core", "SetJointBodyA3D", "Set Joint Body A (3D)", ACEDescriptor.ACEType.ACTION, "node_a = {target}", "", [F.make_param("target", "String", "^\"../BodyA\"", "Body A", "NodePath of the first body.", "expression")], "Joints", "Set joint body A to [i]{target}[/i]", "Joint3D")
		.described("Picks the first 3D body a joint connects, wiring up what it links to."))
	descriptors.append(F.make_descriptor("Core", "SetJointBodyB3D", "Set Joint Body B (3D)", ACEDescriptor.ACEType.ACTION, "node_b = {target}", "", [F.make_param("target", "String", "^\"../BodyB\"", "Body B", "NodePath of the second body.", "expression")], "Joints", "Set joint body B to [i]{target}[/i]", "Joint3D")
		.described("Picks the second 3D body a joint connects, completing the link."))
	descriptors.append(F.make_descriptor("Core", "BreakJoint3D", "Break Joint (3D)", ACEDescriptor.ACEType.ACTION, "node_b = NodePath(\"\")", "", [], "Joints", "Break the joint", "Joint3D")
		.described("Snaps a 3D joint apart by clearing its second body, releasing the connection."))

	# ── The Physics behavior's own settings (V1) ──
	# The words an opened rigid body already READS in, so a picked row and a hand-written line are the
	# same bytes: mass, gravity scale, the material's friction and elasticity, the damping pair,
	# immovable, the sleeping question, the spin, and an area's world gravity.
	descriptors.append(F.make_descriptor("Core", "SetBodyMass", "Set Mass", ACEDescriptor.ACEType.ACTION, "mass = {mass}", "", [F.make_param("mass", "String", "1.0", "Mass", "How heavy the body is.", "expression")], "Physics", "Set mass to {mass}", "RigidBody2D")
		.described("Sets how heavy a physics body is, so the same push moves it more or less."))
	descriptors.append(F.make_descriptor("Core", "SetGravityScale", "Set Gravity Scale", ACEDescriptor.ACEType.ACTION, "gravity_scale = {scale}", "", [F.make_param("scale", "String", "1.0", "Scale", "The share of the world's gravity this body feels - 0 floats, 1 is normal.", "expression")], "Physics", "Set gravity scale to {scale}", "RigidBody2D")
		.described("Sets how much of the world's gravity this body feels, from floating to extra heavy."))
	descriptors.append(F.make_descriptor("Core", "SetBodyFriction", "Set Friction", ACEDescriptor.ACEType.ACTION, "physics_material_override.friction = {friction}", "", [F.make_param("friction", "String", "0.5", "Friction", "How much the surface grips - 0 is ice, 1 is rubber.", "expression")], "Physics", "Set friction to {friction}", "RigidBody2D")
		.described("Sets how much this body's surface grips, from ice to rubber. Needs a physics material on the body."))
	descriptors.append(F.make_descriptor("Core", "SetBodyElasticity", "Set Elasticity", ACEDescriptor.ACEType.ACTION, "physics_material_override.bounce = {elasticity}", "", [F.make_param("elasticity", "String", "0.0", "Elasticity", "How much of the impact comes back - 0 is a sandbag, 1 is a superball.", "expression")], "Physics", "Set elasticity to {elasticity}", "RigidBody2D")
		.described("Sets how bouncy this body is, from a sandbag to a superball. Needs a physics material on the body."))
	descriptors.append(F.make_descriptor("Core", "SetLinearDamping", "Set Linear Damping", ACEDescriptor.ACEType.ACTION, "linear_damp = {damping}", "", [F.make_param("damping", "String", "0.0", "Damping", "How quickly the body slows down on its own.", "expression")], "Physics", "Set linear damping to {damping}", "RigidBody2D")
		.described("Sets how quickly a body loses speed on its own, like moving through water."))
	descriptors.append(F.make_descriptor("Core", "SetAngularDamping", "Set Angular Damping", ACEDescriptor.ACEType.ACTION, "angular_damp = {damping}", "", [F.make_param("damping", "String", "0.0", "Damping", "How quickly the body stops spinning on its own.", "expression")], "Physics", "Set angular damping to {damping}", "RigidBody2D")
		.described("Sets how quickly a body stops spinning on its own."))
	descriptors.append(F.make_descriptor("Core", "SetBodyImmovable", "Set Immovable", ACEDescriptor.ACEType.ACTION, "freeze = {immovable}", "", [F.make_param("immovable", "String", "true", "Immovable", "Hold the body still?", "", ["true", "false"])], "Physics", "Set immovable {immovable}", "RigidBody2D")
		.described("Holds a physics body still where it is, or lets it move again."))
	descriptors.append(F.make_descriptor("Core", "IsBodySleeping", "Is Sleeping", ACEDescriptor.ACEType.CONDITION, "sleeping", "", [], "Physics", "Is sleeping", "RigidBody2D")
		.described("True while a physics body has settled and stopped being simulated."))
	descriptors.append(F.make_descriptor("Core", "ApplyTorque", "Apply Torque", ACEDescriptor.ACEType.ACTION, "apply_torque({torque})", "", [F.make_param("torque", "String", "0.0", "Torque", "Continuous spin applied this physics frame.", "expression")], "Physics", "Apply torque {torque}", "RigidBody2D")
		.described("Applies a steady twist to a body each physics frame, spinning it up."))
	descriptors.append(F.make_descriptor("Core", "ApplyImpulseAtOffset", "Apply Impulse At Offset", ACEDescriptor.ACEType.ACTION, "apply_impulse({impulse}, {offset})", "", [F.make_param("impulse", "String", "Vector2(0, 0)", "Impulse", "The instant push.", "expression"), F.make_param("offset", "String", "Vector2(0, 0)", "At offset", "Where on the body the push lands, from its centre.", "expression")], "Physics", "Apply impulse {impulse} at {offset}", "RigidBody2D")
		.described("Pushes a body at a point away from its centre, so it spins as well as moves."))
	descriptors.append(F.make_descriptor("Core", "SetWorldGravity", "Set World Gravity", ACEDescriptor.ACEType.ACTION, "gravity = {gravity}", "", [F.make_param("gravity", "String", "980.0", "Gravity", "How strongly this area pulls, in pixels per second squared.", "expression")], "Physics", "Set world gravity to {gravity}", "Area2D")
		.described("Sets how strongly an area pulls the bodies inside it, for low-gravity rooms and updrafts."))

	# ── The joints, named by what they DO (V1) ──
	descriptors.append(F.make_descriptor("Core", "CreateRevoluteJoint", "Create Revolute Joint", ACEDescriptor.ACEType.ACTION, "add_child(PinJoint2D.new())", "", [], "Physics", "Create revolute joint")
		.described("Adds a pin the two bodies turn around, like a hinge or an axle."))
	descriptors.append(F.make_descriptor("Core", "CreateDistanceJoint", "Create Distance Joint", ACEDescriptor.ACEType.ACTION, "add_child(DampedSpringJoint2D.new())", "", [], "Physics", "Create distance joint")
		.described("Adds a spring that holds two bodies a set distance apart, like a rope or a suspension arm."))
	descriptors.append(F.make_descriptor("Core", "CreatePrismaticJoint", "Create Prismatic Joint", ACEDescriptor.ACEType.ACTION, "add_child(GrooveJoint2D.new())", "", [], "Physics", "Create prismatic joint")
		.described("Adds a groove one body slides along, like a piston or a lift."))

	return descriptors
