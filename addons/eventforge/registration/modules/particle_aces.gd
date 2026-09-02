# EventForge module - Particles (GPUParticles2D / CPUParticles2D)
#
# Emitting/restart/one-shot/amount + an On Particles Finished trigger (the "finished"
# signal, connected via the OnParticlesFinished arm in trigger_resolver.gd). Lane-1 wraps
# of native particle nodes, single-line per the parity contract. GPU and CPU are distinct
# classes, so the picker scopes by node_type - CPU gets its own ace_id where it differs.
# Module contract: see ace_factory.gd - ace_ids/templates are API (covenant).
@tool
class_name EventForgeParticleACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.trig("OnParticlesFinished", "On Particles Finished", "finished", "Signals / Scene / Input", "On particles finished", "Fires once when this particle emitter's one-shot burst finishes playing.", "GPUParticles2D"))
	descriptors.append(F.act("SetEmitting", "Set Emitting", "emitting = {emitting}", "Particles", "Set emitting {emitting}", "Starts or stops the particle emitter, e.g. switching an effect on.", "GPUParticles2D").param_choice("emitting", "true", "Emitting", "Start / stop emitting.", ["true", "false"]))
	descriptors.append(F.act("RestartParticles", "Restart / Burst", "restart()", "Particles", "Restart particles", "Restarts the particle system from the beginning, e.g. firing a fresh burst.", "GPUParticles2D"))
	descriptors.append(F.act("SetOneShot", "Set One-Shot", "one_shot = {one_shot}", "Particles", "Set one-shot {one_shot}", "Sets the emitter to fire a single burst then stop, rather than looping.", "GPUParticles2D").param_choice("one_shot", "true", "One-Shot", "Emit a single burst then stop.", ["true", "false"]))
	descriptors.append(F.act("SetParticleAmount", "Set Amount", "amount = {amount}", "Particles", "Set amount to {amount}", "Sets how many particles the emitter spawns, controlling effect density.", "GPUParticles2D").param("amount", "8", "Amount", "Number of particles.", "expression"))
	descriptors.append(F.cond("IsEmitting", "Is Emitting", "emitting", "Particles", "Is emitting", "True when the particle emitter is currently emitting particles.", "GPUParticles2D"))
	descriptors.append(F.expr("GetParticleAmount", "Amount", "amount", "Particles", "particle amount", "Returns how many particles the emitter is set to spawn.", "GPUParticles2D"))
	descriptors.append(F.act("SetParticleSpeedScale", "Set Speed Scale", "speed_scale = {scale}", "Particles", "Set speed scale to {scale}", "Speeds up or slows down the particle effect, e.g. 0 freezes it, 2 doubles it.", "GPUParticles2D").param("scale", "1.0", "Scale", "1 = normal, 0.5 = slow, 0 = frozen, 2 = double speed.", "expression"))
	# CPUParticles2D parallel (distinct class - same member names, separate picker section).
	descriptors.append(F.act("SetEmittingCPU", "Set Emitting (CPU)", "emitting = {emitting}", "Particles", "Set emitting {emitting}", "Starts or stops a CPU particle emitter, e.g. switching an effect on.", "CPUParticles2D").param_choice("emitting", "true", "Emitting", "Start / stop emitting.", ["true", "false"]))
	descriptors.append(F.act("RestartParticlesCPU", "Restart / Burst (CPU)", "restart()", "Particles", "Restart particles", "Restarts a CPU particle system from the beginning, e.g. firing a fresh burst.", "CPUParticles2D"))
	descriptors.append(F.act("SetParticleSpeedScaleCPU", "Set Speed Scale (CPU)", "speed_scale = {scale}", "Particles", "Set speed scale to {scale}", "Speeds up or slows down a CPU particle effect, e.g. 0 freezes it, 2 doubles it.", "CPUParticles2D").param("scale", "1.0", "Scale", "1 = normal, 0.5 = slow, 0 = frozen, 2 = double speed.", "expression"))

	return descriptors
