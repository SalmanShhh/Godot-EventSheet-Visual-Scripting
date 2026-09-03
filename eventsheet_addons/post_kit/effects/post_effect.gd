## The frame the camera just drew, run once through a compute shader. Every Post Kit effect is one
## of these: a CompositorEffect the pack hangs on a Camera3D's or a WorldEnvironment's Compositor,
## which reads the colour buffer, changes it in place, and writes it back.
##
## ONLY FORWARD+ HAS A COMPOSITOR. Mobile and Compatibility have no rendering device to hand a
## compute shader to, so everything here checks for one and does nothing at all when there is none -
## no error, no warning, no frame drawn differently. The 2D packs (Screen FX, Blend Modes) do the
## same jobs on any renderer, which is the door the ship-it note points at.
##
## A subclass says three things and nothing else: which shader file it is, what colour it works in,
## and what its own dials hold. The push constant is the same 64 bytes for every effect, so one
## shader header is the whole contract.
## @ace_version(1.0.0)
@tool
extends CompositorEffect

## Where the pack's compute shaders live once it is installed. The builder copies them here beside
## these scripts, so an effect is a file on disk rather than a string compiled at run time.
const SHADER_DIRECTORY: String = "res://eventsheet_addons/post_kit/effects/"

## The compute shader's workgroup, in both directions. It is written twice - once here and once in
## every `local_size_x` - because a dispatch has to count groups and a shader has to declare them.
const GROUP_SIZE: int = 8

## How far the effect goes, 0 to 1. 0 hands the frame back exactly as it arrived, which is what an
## effect sitting on a camera doing nothing should cost the reader to understand.
## @ace_hidden
@export_range(0.0, 1.0, 0.01) var strength: float = 0.6

# The rendering device the frame belongs to, and the two things compiled out of the shader file.
# All three stay empty on a renderer that has no compositor, which is the whole of the Mobile and
# Compatibility story.
var _device: RenderingDevice = null
var _shader: RID = RID()
var _pipeline: RID = RID()


func _init() -> void:
	# After the transparent pass: the effect sees the whole frame, glass and particles included.
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT


## Frees the shader when the effect is dropped. Freeing a shader frees the pipelines built from it,
## so the pipeline is not freed a second time here.
func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	if _device != null and _shader.is_valid():
		_device.free_rid(_shader)
	_shader = RID()
	_pipeline = RID()


## One frame. Runs on the render thread, so everything it needs is fetched here rather than kept:
## the buffers, the size, and the colour layer of each view (two of them, in stereo).
func _render_callback(callback_type: int, render_data: RenderData) -> void:
	if callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:
		return
	if not _compiled():
		return
	var buffers: RenderSceneBuffersRD = render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null:
		return
	var size: Vector2i = buffers.get_internal_size()
	if size.x <= 0 or size.y <= 0:
		return
	var push: PackedFloat32Array = _push_constant(size)
	var groups_x: int = int((size.x - 1) / GROUP_SIZE) + 1
	var groups_y: int = int((size.y - 1) / GROUP_SIZE) + 1
	for view: int in buffers.get_view_count():
		var uniforms: Array[RDUniform] = _uniforms(buffers.get_color_layer(view))
		if uniforms.is_empty():
			continue
		var set_rid: RID = UniformSetCacheRD.get_cache(_shader, 0, uniforms)
		var list: int = _device.compute_list_begin()
		_device.compute_list_bind_compute_pipeline(list, _pipeline)
		_device.compute_list_bind_uniform_set(list, set_rid, 0)
		_device.compute_list_set_push_constant(list, push.to_byte_array(), push.size() * 4)
		_device.compute_list_dispatch(list, groups_x, groups_y, 1)
		_device.compute_list_end()


## The shader file this effect is, by name. Every subclass answers, and the name is the effect's own
## word under one prefix, so a word and its file can never drift apart.
func _shader_file() -> String:
	return ""


## The colour the effect works in - what a vignette shades towards, what a fade lands on. White is
## the answer for an effect that has no colour of its own.
func _effect_colour() -> Color:
	return Color.WHITE


## The effect's own four dials, whatever they mean to its shader. Zero for an effect that has none.
func _effect_dials() -> Vector4:
	return Vector4.ZERO


## Four more, for the one effect that needed them. Kept in the shared header so every shader
## declares the same push constant and no subclass has to think about alignment.
func _effect_more() -> Vector4:
	return Vector4.ZERO


## What the shader is handed: the frame at binding 0, and whatever else a subclass binds beside it.
## An empty array skips the view, which is how an effect that is not ready yet draws nothing.
func _uniforms(colour_layer: RID) -> Array[RDUniform]:
	var frame: RDUniform = RDUniform.new()
	frame.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	frame.binding = 0
	frame.add_id(colour_layer)
	var built: Array[RDUniform] = [frame]
	return built


## The 64 bytes every shader reads: the frame's size, the strength after the accessibility dials
## have had their say, the aspect ratio (a circle on a wide screen is an ellipse without it), the
## colour, and the two sets of dials.
func _push_constant(size: Vector2i) -> PackedFloat32Array:
	var push: PackedFloat32Array = PackedFloat32Array()
	push.resize(16)
	push[0] = float(size.x)
	push[1] = float(size.y)
	push[2] = clampf(strength, 0.0, 1.0)
	push[3] = float(size.x) / maxf(float(size.y), 1.0)
	var tint: Color = _effect_colour()
	push[4] = tint.r
	push[5] = tint.g
	push[6] = tint.b
	push[7] = tint.a
	var dials: Vector4 = _effect_dials()
	push[8] = dials.x
	push[9] = dials.y
	push[10] = dials.z
	push[11] = dials.w
	var more: Vector4 = _effect_more()
	push[12] = more.x
	push[13] = more.y
	push[14] = more.z
	push[15] = more.w
	return push


## Whether there is a shader to run, compiling it the first time it is asked for. Lazy on purpose:
## the answer needs a rendering device, and the one place there is certainly one is the render
## thread. A project with no compositor asks, gets false, and goes on drawing its frame.
func _compiled() -> bool:
	if _pipeline.is_valid():
		return true
	if _device == null:
		_device = RenderingServer.get_rendering_device()
	if _device == null:
		return false
	var file_name: String = _shader_file()
	if file_name.is_empty():
		return false
	var file: RDShaderFile = load(SHADER_DIRECTORY + file_name) as RDShaderFile
	if file == null:
		return false
	var spirv: RDShaderSPIRV = file.get_spirv()
	if spirv == null:
		return false
	_shader = _device.shader_create_from_spirv(spirv)
	if not _shader.is_valid():
		return false
	_pipeline = _device.compute_pipeline_create(_shader)
	return _pipeline.is_valid()
