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
	descriptors.append(F.act("SetBoxMesh", "Make Box Mesh", "var __mesh_{uid} := BoxMesh.new()\n__mesh_{uid}.size = {size}\nmesh = __mesh_{uid}", CAT, "make a box mesh {size}", "Builds a box mesh of the given size and shows it on this MeshInstance3D - the simplest way to make a block at runtime.", "MeshInstance3D").param_typed("Vector3", "size", "Vector3(1, 1, 1)", "Size", "Width, height, depth in metres.", "expression").featured())
	descriptors.append(F.act("SetSphereMesh", "Make Sphere Mesh", "var __mesh_{uid} := SphereMesh.new()\n__mesh_{uid}.radius = {radius}\n__mesh_{uid}.height = {radius} * 2.0\nmesh = __mesh_{uid}", CAT, "make a sphere mesh radius {radius}", "Builds a sphere of the given radius and shows it on this MeshInstance3D.", "MeshInstance3D").param_typed("float", "radius", "0.5", "Radius", "Sphere radius in metres (height is set to a full diameter).", "expression"))
	descriptors.append(F.act("SetCylinderMesh", "Make Cylinder Mesh", "var __mesh_{uid} := CylinderMesh.new()\n__mesh_{uid}.top_radius = {radius}\n__mesh_{uid}.bottom_radius = {radius}\n__mesh_{uid}.height = {height}\nmesh = __mesh_{uid}", CAT, "make a cylinder mesh r{radius} h{height}", "Builds a cylinder of the given radius and height and shows it on this MeshInstance3D.", "MeshInstance3D").param_typed("float", "radius", "0.5", "Radius", "Cylinder radius in metres.", "expression").param_typed("float", "height", "2.0", "Height", "Cylinder height in metres.", "expression"))
	descriptors.append(F.act("SetPlaneMesh", "Make Plane Mesh", "var __mesh_{uid} := PlaneMesh.new()\n__mesh_{uid}.size = {size}\nmesh = __mesh_{uid}", CAT, "make a plane mesh {size}", "Builds a flat plane of the given size and shows it on this MeshInstance3D - a quick floor or wall.", "MeshInstance3D").param_typed("Vector2", "size", "Vector2(2, 2)", "Size", "Width and depth in metres (a flat ground plane).", "expression"))
	descriptors.append(F.act("SetCapsuleMesh", "Make Capsule Mesh", "var __mesh_{uid} := CapsuleMesh.new()\n__mesh_{uid}.radius = {radius}\n__mesh_{uid}.height = {height}\nmesh = __mesh_{uid}", CAT, "make a capsule mesh r{radius} h{height}", "Builds a capsule (a pill shape) and shows it on this MeshInstance3D - a stand-in character body.", "MeshInstance3D").param_typed("float", "radius", "0.3", "Radius", "Capsule radius in metres.", "expression").param_typed("float", "height", "1.8", "Height", "Capsule total height in metres.", "expression"))
	descriptors.append(F.act("SetPrismMesh", "Make Prism Mesh", "var __mesh_{uid} := PrismMesh.new()\n__mesh_{uid}.size = {size}\nmesh = __mesh_{uid}", CAT, "make a prism mesh {size}", "Builds a triangular prism (a wedge / ramp) and shows it on this MeshInstance3D.", "MeshInstance3D").param_typed("Vector3", "size", "Vector3(1, 1, 1)", "Size", "Width, height, depth in metres.", "expression"))
	descriptors.append(F.act("SetTorusMesh", "Make Torus Mesh", "var __mesh_{uid} := TorusMesh.new()\n__mesh_{uid}.inner_radius = {inner_radius}\n__mesh_{uid}.outer_radius = {outer_radius}\nmesh = __mesh_{uid}", CAT, "make a torus mesh {inner_radius}/{outer_radius}", "Builds a torus (a ring / donut) and shows it on this MeshInstance3D.", "MeshInstance3D").param_typed("float", "inner_radius", "0.3", "Inner Radius", "Hole radius in metres.", "expression").param_typed("float", "outer_radius", "0.6", "Outer Radius", "Overall radius in metres.", "expression"))

	# ── Material + clear ──
	descriptors.append(F.act("SetMeshMaterial", "Set Mesh Material", "material_override = {material}", CAT, "set mesh material to {material}", "Overrides the whole mesh's material - one line to recolour or reskin the shape.", "MeshInstance3D").param("material", "null", "Material", "A Material resource (or a variable holding one).", "expression"))
	descriptors.append(F.act("ClearMesh", "Clear Mesh", "mesh = null", CAT, "clear the mesh", "Removes the mesh so nothing draws on this MeshInstance3D.", "MeshInstance3D"))

	# ── Conditions + expressions ──
	descriptors.append(F.cond("HasMesh", "Has Mesh", "mesh != null", CAT, "has a mesh", "True when this MeshInstance3D currently shows a mesh.", "MeshInstance3D"))
	descriptors.append(F.expr("MeshSurfaceCount", "Mesh Surface Count", "(mesh.get_surface_count() if mesh != null else 0)", CAT, "mesh surface count", "How many surfaces (material slots) this mesh has - 0 when there is no mesh.", "MeshInstance3D"))
	descriptors.append(F.expr("MeshSize", "Mesh Size", "get_aabb().size", CAT, "mesh size", "The mesh's bounding-box size (width, height, depth) in local space - handy for fitting or spacing.", "MeshInstance3D"))

	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "Build and swap 3D meshes from events - primitive builders (box, sphere, cylinder, plane, capsule, prism, torus) that create and show a mesh, plus set the material, clear it, and read the surface count and size. Node-scoped to MeshInstance3D."}
