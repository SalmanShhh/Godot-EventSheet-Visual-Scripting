# EventForge module - Mesh vocabulary (build and swap 3D meshes from events).
#
# Give a MeshInstance3D a shape at runtime: the primitive builders (box, sphere, cylinder, plane,
# capsule, prism, torus) CREATE a configured mesh and assign it, so a beginner makes geometry with
# no SurfaceTool code; plus swap the surface material, clear the mesh, and read the surface count
# and world-space size (its AABB) for layout or fitting. Each builder is a small multi-line template
# (a mesh resource is built, tuned, then assigned), so it stays host-only; the plain member ops gain
# an optional "On node" target. Compiles to plain Godot with zero plugin references.
@tool
class_name EventForgeMeshACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Mesh"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Primitive builders (create a mesh + assign it) ──
	descriptors.append(F.make_descriptor("Core", "SetBoxMesh", "Make Box Mesh", ACEDescriptor.ACEType.ACTION, "var __mesh_{uid} := BoxMesh.new()\n__mesh_{uid}.size = {size}\nmesh = __mesh_{uid}", "", [F.make_param("size", "Vector3", "Vector3(1, 1, 1)", "Size", "Width, height, depth in metres.", "expression")], CAT, "make a box mesh {size}", "MeshInstance3D")
		.described("Builds a box mesh of the given size and shows it on this MeshInstance3D - the simplest way to make a block at runtime.").featured())
	descriptors.append(F.make_descriptor("Core", "SetSphereMesh", "Make Sphere Mesh", ACEDescriptor.ACEType.ACTION, "var __mesh_{uid} := SphereMesh.new()\n__mesh_{uid}.radius = {radius}\n__mesh_{uid}.height = {radius} * 2.0\nmesh = __mesh_{uid}", "", [F.make_param("radius", "float", "0.5", "Radius", "Sphere radius in metres (height is set to a full diameter).", "expression")], CAT, "make a sphere mesh radius {radius}", "MeshInstance3D")
		.described("Builds a sphere of the given radius and shows it on this MeshInstance3D."))
	descriptors.append(F.make_descriptor("Core", "SetCylinderMesh", "Make Cylinder Mesh", ACEDescriptor.ACEType.ACTION, "var __mesh_{uid} := CylinderMesh.new()\n__mesh_{uid}.top_radius = {radius}\n__mesh_{uid}.bottom_radius = {radius}\n__mesh_{uid}.height = {height}\nmesh = __mesh_{uid}", "", [F.make_param("radius", "float", "0.5", "Radius", "Cylinder radius in metres.", "expression"), F.make_param("height", "float", "2.0", "Height", "Cylinder height in metres.", "expression")], CAT, "make a cylinder mesh r{radius} h{height}", "MeshInstance3D")
		.described("Builds a cylinder of the given radius and height and shows it on this MeshInstance3D."))
	descriptors.append(F.make_descriptor("Core", "SetPlaneMesh", "Make Plane Mesh", ACEDescriptor.ACEType.ACTION, "var __mesh_{uid} := PlaneMesh.new()\n__mesh_{uid}.size = {size}\nmesh = __mesh_{uid}", "", [F.make_param("size", "Vector2", "Vector2(2, 2)", "Size", "Width and depth in metres (a flat ground plane).", "expression")], CAT, "make a plane mesh {size}", "MeshInstance3D")
		.described("Builds a flat plane of the given size and shows it on this MeshInstance3D - a quick floor or wall."))
	descriptors.append(F.make_descriptor("Core", "SetCapsuleMesh", "Make Capsule Mesh", ACEDescriptor.ACEType.ACTION, "var __mesh_{uid} := CapsuleMesh.new()\n__mesh_{uid}.radius = {radius}\n__mesh_{uid}.height = {height}\nmesh = __mesh_{uid}", "", [F.make_param("radius", "float", "0.3", "Radius", "Capsule radius in metres.", "expression"), F.make_param("height", "float", "1.8", "Height", "Capsule total height in metres.", "expression")], CAT, "make a capsule mesh r{radius} h{height}", "MeshInstance3D")
		.described("Builds a capsule (a pill shape) and shows it on this MeshInstance3D - a stand-in character body."))
	descriptors.append(F.make_descriptor("Core", "SetPrismMesh", "Make Prism Mesh", ACEDescriptor.ACEType.ACTION, "var __mesh_{uid} := PrismMesh.new()\n__mesh_{uid}.size = {size}\nmesh = __mesh_{uid}", "", [F.make_param("size", "Vector3", "Vector3(1, 1, 1)", "Size", "Width, height, depth in metres.", "expression")], CAT, "make a prism mesh {size}", "MeshInstance3D")
		.described("Builds a triangular prism (a wedge / ramp) and shows it on this MeshInstance3D."))
	descriptors.append(F.make_descriptor("Core", "SetTorusMesh", "Make Torus Mesh", ACEDescriptor.ACEType.ACTION, "var __mesh_{uid} := TorusMesh.new()\n__mesh_{uid}.inner_radius = {inner_radius}\n__mesh_{uid}.outer_radius = {outer_radius}\nmesh = __mesh_{uid}", "", [F.make_param("inner_radius", "float", "0.3", "Inner Radius", "Hole radius in metres.", "expression"), F.make_param("outer_radius", "float", "0.6", "Outer Radius", "Overall radius in metres.", "expression")], CAT, "make a torus mesh {inner_radius}/{outer_radius}", "MeshInstance3D")
		.described("Builds a torus (a ring / donut) and shows it on this MeshInstance3D."))

	# ── Material + clear ──
	descriptors.append(F.make_descriptor("Core", "SetMeshMaterial", "Set Mesh Material", ACEDescriptor.ACEType.ACTION, "material_override = {material}", "", [F.make_param("material", "String", "null", "Material", "A Material resource (or a variable holding one).", "expression")], CAT, "set mesh material to {material}", "MeshInstance3D")
		.described("Overrides the whole mesh's material - one line to recolour or reskin the shape."))
	descriptors.append(F.make_descriptor("Core", "ClearMesh", "Clear Mesh", ACEDescriptor.ACEType.ACTION, "mesh = null", "", [], CAT, "clear the mesh", "MeshInstance3D")
		.described("Removes the mesh so nothing draws on this MeshInstance3D."))

	# ── Conditions + expressions ──
	descriptors.append(F.make_descriptor("Core", "HasMesh", "Has Mesh", ACEDescriptor.ACEType.CONDITION, "mesh != null", "", [], CAT, "has a mesh", "MeshInstance3D")
		.described("True when this MeshInstance3D currently shows a mesh."))
	descriptors.append(F.make_descriptor("Core", "MeshSurfaceCount", "Mesh Surface Count", ACEDescriptor.ACEType.EXPRESSION, "(mesh.get_surface_count() if mesh != null else 0)", "", [], CAT, "mesh surface count", "MeshInstance3D")
		.described("How many surfaces (material slots) this mesh has - 0 when there is no mesh."))
	descriptors.append(F.make_descriptor("Core", "MeshSize", "Mesh Size", ACEDescriptor.ACEType.EXPRESSION, "get_aabb().size", "", [], CAT, "mesh size", "MeshInstance3D")
		.described("The mesh's bounding-box size (width, height, depth) in local space - handy for fitting or spacing."))

	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "Build and swap 3D meshes from events - primitive builders (box, sphere, cylinder, plane, capsule, prism, torus) that create and show a mesh, plus set the material, clear it, and read the surface count and size. Node-scoped to MeshInstance3D."}
