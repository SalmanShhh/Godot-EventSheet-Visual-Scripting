# EventForge module - Gradient & Curve vocabulary (smooth colour ramps and shaped 0-1 curves).
#
# A Gradient is a smooth colour ramp (fire, sky, a health-bar tint); a Curve is a shaped value over
# 0..1 (easing, falloff, spawn-rate-over-lifetime). Author rich multi-stop gradients and hand-drawn
# curves by giving a variable the Gradient / Curve type - Godot shows its native editors in the
# Inspector (the ramp with draggable colour stops, the curve editor). These ACEs cover the rest:
# BUILD a quick two-colour gradient from events, and SAMPLE either at a 0-to-1 position to get the
# colour / value at that point (drive a tint, a difficulty ramp, an eased motion). Compiles to plain
# Godot with zero plugin references.
@tool
class_name EventForgeGradientCurveACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Gradients & Curves"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Create ──
	descriptors.append(F.make_descriptor("Core", "MakeGradient", "Make Gradient", ACEDescriptor.ACEType.ACTION, "var __grad_{uid} := Gradient.new()\n__grad_{uid}.set_color(0, {from})\n__grad_{uid}.set_color(1, {to})\n{var_name} = __grad_{uid}", "", [F.make_param("var_name", "String", "ramp", "Into Variable", "A Gradient-typed variable to build into.", "variable_reference"), F.make_param("from", "Color", "Color.RED", "From", "Colour at position 0.", ""), F.make_param("to", "Color", "Color.YELLOW", "To", "Colour at position 1.", "")], CAT, "make gradient {from} -> {to} into {var_name}")
		.described("Builds a smooth two-colour ramp into a variable at runtime - the quick way to make a fire or sky gradient without opening the editor. For many stops, give a variable the Gradient type and edit it in the Inspector.").featured())

	# ── Sample ──
	descriptors.append(F.make_descriptor("Core", "SampleGradient", "Sample Gradient", ACEDescriptor.ACEType.EXPRESSION, "{gradient}.sample({position})", "", [F.make_param("gradient", "String", "ramp", "Gradient", "A variable holding a Gradient.", "variable_reference"), F.make_param("position", "float", "0.5", "Position", "0 = the left/first colour, 1 = the right/last colour.", "expression")], CAT, "sample {gradient} at {position}")
		.described("Reads the smooth colour at a 0-to-1 position along a gradient - drive a health-bar tint, a day/night sky, a heat map from one line.").featured())
	descriptors.append(F.make_descriptor("Core", "SampleCurve", "Sample Curve", ACEDescriptor.ACEType.EXPRESSION, "{curve}.sample_baked({position})", "", [F.make_param("curve", "String", "falloff", "Curve", "A variable holding a Curve.", "variable_reference"), F.make_param("position", "float", "0.5", "Position", "0 = the curve's start, 1 = its end.", "expression")], CAT, "sample {curve} at {position}")
		.described("Reads a curve's value at a 0-to-1 position - turn a designer-drawn easing / falloff / difficulty curve into a number, no math."))

	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "Smooth colour ramps and shaped 0-1 curves - build a quick two-colour gradient, and sample any gradient or curve at a position. Author rich multi-stop gradients and hand-drawn curves by giving a variable the Gradient / Curve type (the Inspector shows Godot's native editors)."}
