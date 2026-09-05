// Vector Shapes in 3D, taken out of what is behind it: a hole cut in a fog volume,
// and drawn over everything, so a gizmo line reads through the wall in front of it.
// The drawing itself is in the includes beside this file - a blend mode and a depth test are both
// `render_mode`, decided when the shader compiles and impossible to make a uniform, so each pairing
// is its own five lines around one shared body.
shader_type spatial;
render_mode blend_sub, cull_disabled, unshaded, depth_draw_never, depth_test_disabled;

#include "vector_shapes_3d.gdshaderinc"
