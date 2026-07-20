# EventForge module - Camera FOV vocabulary (field of view from events).
#
# The field-of-view moves a 3D camera reaches for constantly: aim-down-sights zoom, a speed-boost
# FOV widen, a sniper punch-in. Set Camera FOV already exists (a plain assignment); this adds the
# rest of the toolkit - a SMOOTH tween to a target FOV, a relative nudge (clamped to the legal
# 1..179 range so a stacked zoom can never invert the camera), and the read expression a HUD or a
# dynamic-FOV rig needs. Every ACE is node-scoped to Camera3D, so it also gains an optional
# "On node" target (act on another camera) for free via the builtin targetable pass. Compiles to
# plain Godot with zero plugin references. (The Juice 3D pack drives ADDITIVE FOV punches on the
# ACTIVE camera; these set the camera's OWN base FOV.)
@tool
class_name EventForgeCameraFovACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Camera"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# Active-camera (not node-scoped): eases THE camera you are looking through, guarded so no camera is
	# safe. Kept off the node-scoped targetable path on purpose - a tween that named `self` as the property
	# owner would animate the wrong camera if retargeted, so this resolves the real camera explicitly.
	descriptors.append(F.make_descriptor("Core", "TweenCameraFov", "Tween Camera FOV", ACEDescriptor.ACEType.ACTION, "var __fovcam_{uid} := get_viewport().get_camera_3d()\nif __fovcam_{uid} != null:\n\tcreate_tween().tween_property(__fovcam_{uid}, \"fov\", clampf({degrees}, 1.0, 179.0), {duration}).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)", "", [F.make_param("degrees", "float", "40.0", "Degrees", "Target field of view (lower zooms in, higher widens).", "expression"), F.make_param("duration", "float", "0.25", "Seconds", "How long the zoom takes.", "expression")], CAT, "tween FOV to {degrees} over {duration}s")
		.described("Smoothly eases the active 3D camera's field of view to a target over time - the aim-down-sights zoom, a speed-boost widen. Clamped to the legal 1-179 range; safe when there is no camera.").featured())
	descriptors.append(F.make_descriptor("Core", "AdjustCameraFov", "Adjust Camera FOV", ACEDescriptor.ACEType.ACTION, "fov = clampf(fov + {delta}, 1.0, 179.0)", "", [F.make_param("delta", "float", "-10.0", "Change", "Degrees to add (negative zooms in, positive widens).", "expression")], CAT, "adjust FOV by {delta}", "Camera3D")
		.described("Nudges a 3D camera's field of view by a relative amount, clamped so a repeated zoom can never flip the camera inside-out."))
	descriptors.append(F.make_descriptor("Core", "GetCameraFov", "Camera FOV", ACEDescriptor.ACEType.EXPRESSION, "fov", "", [], CAT, "camera FOV", "Camera3D")
		.described("A 3D camera's current field of view in degrees - read it for a HUD zoom indicator or a dynamic-FOV rig."))

	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "Field of view for 3D cameras - set it, ease it smoothly to a target, nudge it relatively (clamped legal), or read it. Node-scoped to Camera3D with an optional On node target."}
