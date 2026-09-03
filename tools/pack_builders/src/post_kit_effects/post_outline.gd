## Outline through walls: a mask of one visual layer, edge-detected over the frame.
##
## The mask is drawn by a second camera that can see NOTHING except the layer the pack marks its
## chosen meshes with, into a viewport with a transparent background. So the mask holds the chosen
## things and only them, whole, whether or not a wall is standing in front of them - and an edge
## found in that mask is drawn straight over the finished frame. That is the whole of "through
## walls": the outline never asked what was in the way.
##
## Fill turns the same mask into a silhouette instead of an edge, which is the other half of the
## same question - where is the thing, rather than what shape is it.
## @ace_version(1.0.0)
@tool
extends "post_effect.gd"

## The colour the outline is drawn in.
## @ace_hidden
@export var ink: Color = Color(1.0, 0.85, 0.2)

## How thick the outline is, in pixels of the frame.
## @ace_hidden
@export_range(1.0, 16.0, 1.0) var width: float = 2.0

## 0 draws the edge of the mask (an outline); 1 draws the whole mask (a silhouette). Between the
## two, a silhouette with a brighter rim.
## @ace_hidden
@export_range(0.0, 1.0, 0.01) var fill: float = 0.0

## The mask this effect reads, as the rendering device knows it. The pack sets it once its mask
## viewport has drawn a frame; while it is empty the effect draws nothing at all.
var mask_texture: RID = RID()

# The one sampler the mask is read through, built the first time a frame is drawn and freed with
# the effect. Clamped at the edges so a tap off the side of the frame finds emptiness rather than
# the opposite edge, which would print an outline down the far side of the screen.
var _sampler: RID = RID()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _device != null and _sampler.is_valid():
		_device.free_rid(_sampler)
		_sampler = RID()
	super(what)


func _shader_file() -> String:
	return "post_outline.glsl"


func _effect_colour() -> Color:
	return ink


func _effect_dials() -> Vector4:
	return Vector4(maxf(width, 1.0), clampf(fill, 0.0, 1.0), 0.0, 0.0)


## The frame at binding 0 and the mask at binding 1. No mask means no uniforms, which the base reads
## as "skip this view" - so an outline row that has not been given a mask yet is simply not drawn.
func _uniforms(colour_layer: RID) -> Array[RDUniform]:
	var none: Array[RDUniform] = []
	if not mask_texture.is_valid():
		return none
	if not _sampler.is_valid():
		var state: RDSamplerState = RDSamplerState.new()
		state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
		state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
		state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
		state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
		_sampler = _device.sampler_create(state)
	if not _sampler.is_valid():
		return none
	var built: Array[RDUniform] = super(colour_layer)
	var mask: RDUniform = RDUniform.new()
	mask.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	mask.binding = 1
	mask.add_id(_sampler)
	mask.add_id(mask_texture)
	built.append(mask)
	return built
