// Vector Shapes in 3D, added to what is behind it: a beam, a glow, a hologram line,
// and sorted against the world the ordinary way, so a shape behind a wall is behind it.
// The drawing itself is in the includes beside this file - a blend mode and a depth test are both
// `render_mode`, decided when the shader compiles and impossible to make a uniform, so each pairing
// is its own five lines around one shared body.
shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_never;

#include "vector_shapes_3d.gdshaderinc"
