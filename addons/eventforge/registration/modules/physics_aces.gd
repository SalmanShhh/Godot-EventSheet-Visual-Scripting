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
	descriptors.append(F.act("SetJointBodyA", "Set Joint Body A", "node_a = {target}", "Joints", "Set joint body A to [i]{target}[/i]", "Sets the first physics body a joint connects to.", "Joint2D").param("target", "^\"../BodyA\"", "Body A", "NodePath of the first body.", "expression"))
	descriptors.append(F.act("SetJointBodyB", "Set Joint Body B", "node_b = {target}", "Joints", "Set joint body B to [i]{target}[/i]", "Sets the second physics body a joint connects to.", "Joint2D").param("target", "^\"../BodyB\"", "Body B", "NodePath of the second body.", "expression"))
	descriptors.append(F.act("BreakJoint", "Break Joint", "node_b = NodePath(\"\")", "Joints", "Break the joint", "Breaks a joint by clearing its second body, e.g. snapping a rope or chain.", "Joint2D"))
	descriptors.append(F.act("SetJointDisableCollision", "Set Disable Collision", "disable_collision = {disabled}", "Joints", "Set disable collision {disabled}", "Toggles whether the two bodies linked by the joint can collide with each other.", "Joint2D").param_choice("disabled", "true", "Disabled", "Disable collision between bodies?", ["true", "false"]))
	descriptors.append(F.act("SetPinJointSoftness", "Set Pin Softness", "softness = {softness}", "Joints", "Set pin softness to {softness}", "Sets how springy a pin joint is, higher values make the link looser.", "PinJoint2D").param("softness", "0.0", "Softness", "Pin joint softness.", "expression"))
	descriptors.append(F.act("SetDampedSpringLength", "Set Spring Rest Length", "rest_length = {length}", "Joints", "Set spring rest length to {length}", "Sets a spring joint's resting length, the distance it tries to hold.", "DampedSpringJoint2D").param("length", "50.0", "Rest Length", "Spring rest length.", "expression"))
	descriptors.append(F.act("SetDampedSpringStiffness", "Set Spring Stiffness", "stiffness = {stiffness}", "Joints", "Set spring stiffness to {stiffness}", "Sets how rigid a damped spring joint feels, so it snaps back harder or softer.", "DampedSpringJoint2D").param("stiffness", "20.0", "Stiffness", "Spring stiffness.", "expression"))
	descriptors.append(F.act("SetDampedSpringDamping", "Set Spring Damping", "damping = {damping}", "Joints", "Set spring damping to {damping}", "Sets how quickly a damped spring stops bouncing, controlling its wobble.", "DampedSpringJoint2D").param("damping", "1.0", "Damping", "Spring damping.", "expression"))

	# ── 3D joints ──
	descriptors.append(F.act("SetJointBodyA3D", "Set Joint Body A (3D)", "node_a = {target}", "Joints", "Set joint body A to [i]{target}[/i]", "Picks the first 3D body a joint connects, wiring up what it links to.", "Joint3D").param("target", "^\"../BodyA\"", "Body A", "NodePath of the first body.", "expression"))
	descriptors.append(F.act("SetJointBodyB3D", "Set Joint Body B (3D)", "node_b = {target}", "Joints", "Set joint body B to [i]{target}[/i]", "Picks the second 3D body a joint connects, completing the link.", "Joint3D").param("target", "^\"../BodyB\"", "Body B", "NodePath of the second body.", "expression"))
	descriptors.append(F.act("BreakJoint3D", "Break Joint (3D)", "node_b = NodePath(\"\")", "Joints", "Break the joint", "Snaps a 3D joint apart by clearing its second body, releasing the connection.", "Joint3D"))

	# ── The Physics behavior's own settings ──
	# The words an opened rigid body already READS in, so a picked row and a hand-written line are the
	# same bytes: mass, gravity scale, the material's friction and elasticity, the damping pair,
	# immovable, the sleeping question, the spin, and an area's world gravity.
	descriptors.append(F.act("SetBodyMass", "Set Mass", "mass = {mass}", "Physics", "Set mass to {mass}", "Sets how heavy a physics body is, so the same push moves it more or less.", "RigidBody2D").param("mass", "1.0", "Mass", "How heavy the body is.", "expression"))
	descriptors.append(F.act("SetGravityScale", "Set Gravity Scale", "gravity_scale = {scale}", "Physics", "Set gravity scale to {scale}", "Sets how much of the world's gravity this body feels, from floating to extra heavy.", "RigidBody2D").param("scale", "1.0", "Scale", "The share of the world's gravity this body feels - 0 floats, 1 is normal.", "expression"))
	descriptors.append(F.act("SetBodyFriction", "Set Friction", "physics_material_override.friction = {friction}", "Physics", "Set friction to {friction}", "Sets how much this body's surface grips, from ice to rubber. Needs a physics material on the body.", "RigidBody2D").param("friction", "0.5", "Friction", "How much the surface grips - 0 is ice, 1 is rubber.", "expression"))
	descriptors.append(F.act("SetBodyElasticity", "Set Elasticity", "physics_material_override.bounce = {elasticity}", "Physics", "Set elasticity to {elasticity}", "Sets how bouncy this body is, from a sandbag to a superball. Needs a physics material on the body.", "RigidBody2D").param("elasticity", "0.0", "Elasticity", "How much of the impact comes back - 0 is a sandbag, 1 is a superball.", "expression"))
	descriptors.append(F.act("SetLinearDamping", "Set Linear Damping", "linear_damp = {damping}", "Physics", "Set linear damping to {damping}", "Sets how quickly a body loses speed on its own, like moving through water.", "RigidBody2D").param("damping", "0.0", "Damping", "How quickly the body slows down on its own.", "expression"))
	descriptors.append(F.act("SetAngularDamping", "Set Angular Damping", "angular_damp = {damping}", "Physics", "Set angular damping to {damping}", "Sets how quickly a body stops spinning on its own.", "RigidBody2D").param("damping", "0.0", "Damping", "How quickly the body stops spinning on its own.", "expression"))
	descriptors.append(F.act("SetBodyImmovable", "Set Immovable", "freeze = {immovable}", "Physics", "Set immovable {immovable}", "Holds a physics body still where it is, or lets it move again.", "RigidBody2D").param_choice("immovable", "true", "Immovable", "Hold the body still?", ["true", "false"]))
	descriptors.append(F.cond("IsBodySleeping", "Is Sleeping", "sleeping", "Physics", "Is sleeping", "True while a physics body has settled and stopped being simulated.", "RigidBody2D"))
	descriptors.append(F.act("ApplyTorque", "Apply Torque", "apply_torque({torque})", "Physics", "Apply torque {torque}", "Applies a steady twist to a body each physics frame, spinning it up.", "RigidBody2D").param("torque", "0.0", "Torque", "Continuous spin applied this physics frame.", "expression"))
	descriptors.append(F.act("ApplyImpulseAtOffset", "Apply Impulse At Offset", "apply_impulse({impulse}, {offset})", "Physics", "Apply impulse {impulse} at {offset}", "Pushes a body at a point away from its centre, so it spins as well as moves.", "RigidBody2D").param("impulse", "Vector2(0, 0)", "Impulse", "The instant push.", "expression").param("offset", "Vector2(0, 0)", "At offset", "Where on the body the push lands, from its centre.", "expression"))
	descriptors.append(F.act("SetWorldGravity", "Set World Gravity", "gravity = {gravity}", "Physics", "Set world gravity to {gravity}", "Sets how strongly an area pulls the bodies inside it, for low-gravity rooms and updrafts.", "Area2D").param("gravity", "980.0", "Gravity", "How strongly this area pulls, in pixels per second squared.", "expression"))

	# ── The joints, named by what they DO ──
	descriptors.append(F.act("CreateRevoluteJoint", "Create Revolute Joint", "add_child(PinJoint2D.new())", "Physics", "Create revolute joint", "Adds a pin the two bodies turn around, like a hinge or an axle."))
	descriptors.append(F.act("CreateDistanceJoint", "Create Distance Joint", "add_child(DampedSpringJoint2D.new())", "Physics", "Create distance joint", "Adds a spring that holds two bodies a set distance apart, like a rope or a suspension arm."))
	descriptors.append(F.act("CreatePrismaticJoint", "Create Prismatic Joint", "add_child(GrooveJoint2D.new())", "Physics", "Create prismatic joint", "Adds a groove one body slides along, like a piston or a lift."))

	return descriptors
