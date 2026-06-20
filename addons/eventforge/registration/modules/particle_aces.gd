# EventForge module — Particles (GPUParticles2D / CPUParticles2D)
#
# Emitting/restart/one-shot/amount + an On Particles Finished trigger (the "finished"
# signal, connected via the OnParticlesFinished arm in trigger_resolver.gd). Lane-1 wraps
# of native particle nodes, single-line per the parity contract. GPU and CPU are distinct
# classes, so the picker scopes by node_type — CPU gets its own ace_id where it differs.
# Module contract: see ace_factory.gd — ace_ids/templates are API (covenant).
@tool
extends RefCounted
class_name EventForgeParticleACEs

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.make_descriptor("Core", "OnParticlesFinished", "On Particles Finished", ACEDescriptor.ACEType.TRIGGER, "", "finished", [], "Signals / Scene / Input", "On particles finished", "GPUParticles2D"))
	descriptors.append(F.make_descriptor("Core", "SetEmitting", "Set Emitting", ACEDescriptor.ACEType.ACTION, "emitting = {emitting}", "", [F.make_param("emitting", "String", "true", "Emitting", "Start / stop emitting.", "", ["true", "false"])], "Particles", "Set emitting {emitting}", "GPUParticles2D"))
	descriptors.append(F.make_descriptor("Core", "RestartParticles", "Restart / Burst", ACEDescriptor.ACEType.ACTION, "restart()", "", [], "Particles", "Restart particles", "GPUParticles2D"))
	descriptors.append(F.make_descriptor("Core", "SetOneShot", "Set One-Shot", ACEDescriptor.ACEType.ACTION, "one_shot = {one_shot}", "", [F.make_param("one_shot", "String", "true", "One-Shot", "Emit a single burst then stop.", "", ["true", "false"])], "Particles", "Set one-shot {one_shot}", "GPUParticles2D"))
	descriptors.append(F.make_descriptor("Core", "SetParticleAmount", "Set Amount", ACEDescriptor.ACEType.ACTION, "amount = {amount}", "", [F.make_param("amount", "String", "8", "Amount", "Number of particles.", "expression")], "Particles", "Set amount to {amount}", "GPUParticles2D"))
	descriptors.append(F.make_descriptor("Core", "IsEmitting", "Is Emitting", ACEDescriptor.ACEType.CONDITION, "emitting", "", [], "Particles", "Is emitting", "GPUParticles2D"))
	descriptors.append(F.make_descriptor("Core", "GetParticleAmount", "Amount", ACEDescriptor.ACEType.EXPRESSION, "amount", "", [], "Particles", "particle amount", "GPUParticles2D"))
	# CPUParticles2D parallel (distinct class — same member names, separate picker section).
	descriptors.append(F.make_descriptor("Core", "SetEmittingCPU", "Set Emitting (CPU)", ACEDescriptor.ACEType.ACTION, "emitting = {emitting}", "", [F.make_param("emitting", "String", "true", "Emitting", "Start / stop emitting.", "", ["true", "false"])], "Particles", "Set emitting {emitting}", "CPUParticles2D"))
	descriptors.append(F.make_descriptor("Core", "RestartParticlesCPU", "Restart / Burst (CPU)", ACEDescriptor.ACEType.ACTION, "restart()", "", [], "Particles", "Restart particles", "CPUParticles2D"))

	return descriptors
