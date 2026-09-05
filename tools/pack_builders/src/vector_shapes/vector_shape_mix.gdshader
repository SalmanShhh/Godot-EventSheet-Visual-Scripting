// Vector Shapes, drawn the ordinary way: the shape over what is behind it.
// The drawing itself is in the include beside this file - a blend mode is a render_mode, which is
// decided when the shader compiles and cannot be a uniform, so each blend is its own four lines.
shader_type canvas_item;
render_mode blend_mix;

#include "vector_shapes.gdshaderinc"
