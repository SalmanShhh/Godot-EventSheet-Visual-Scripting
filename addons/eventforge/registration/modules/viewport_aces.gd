# EventForge module - the knobs of a view (a SubViewport, and the window's own viewport).
#
# A SubViewport is how a Godot project draws a second picture: the minimap, the rear-view mirror,
# the security monitor, the screen standing in a 3D room, the character portrait that renders a real
# model rather than a painted sprite. The node itself is plumbing, and everything a game wants to do
# with one is a property or a call nobody remembers the spelling of - so the five rows here are the
# five questions actually asked of a view:
#
#   HOW BIG IS IT          `size`, in pixels. A minimap that renders 200x120 costs a fraction of one
#                          that renders 1920x1080 and then squeezes the result into a corner.
#   WHAT IS IN IT          the world. Sharing another viewport's `world_2d` / `world_3d` is what
#                          makes a second view show the SAME game rather than an empty stage, and it
#                          is the one line between a minimap that works and one that renders nothing.
#   WHERE IS THE CURSOR    a view has its own coordinate space, so the pointer inside a rear-view
#                          mirror or an in-world screen is not the pointer on the window.
#   HOW DO I KEEP A COPY   a still, written to a PNG. It waits for the frame to finish drawing
#                          first, which is the whole difference between a picture and a black image.
#
# Two rows this module deliberately does NOT ship, because the vocabulary already has them and a
# second row writing the same line would take the reading away from the first:
#   * HOW OFTEN IT REDRAWS is Set Surface Redraw (native_3d_aces.gd), which writes
#     `render_target_update_mode` and now offers the once-now choice as well as the other three.
#   * THE LIVE PICTURE is Rendered As An Image (window_aces.gd), which is `{viewport}.get_texture()`
#     already and reads the same way pointed at a SubViewport.
#
# Everything compiles to plain Godot calls with zero plugin references, honouring the parity
# covenant.
@tool
class_name EventForgeViewportACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Views"

## The view a row acts on when nobody names another. The window's own viewport is the one every
## script can reach with no scene path at all, so a dropped row compiles wherever it lands - and a
## reader who wants the off-screen one puts `$SubViewport` in the field.
const THIS_VIEW := "get_viewport()"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.act("ViewSetSize", "Set View Size", "size = {size}", CAT, "set view size to [b]{size}[/b]", "How many pixels a view renders. This is the cost of the view: a minimap drawn into a 200 by 120 panel should render 200 by 120, not the whole window and then a squeeze. Whole pixels only, which is what a view is measured in.", "SubViewport").param_typed("Vector2i", "size", "Vector2i(320, 180)", "Size", "The width and height the view renders at, in pixels.", "expression").featured())

	descriptors.append(F.act("ViewShareWorld2D", "Share The World (2D)", "{target.}world_2d = {other}.world_2d", CAT, "share the 2D world of [b]{other}[/b]", "Points a view at the same 2D world another viewport is already drawing, so it shows the running game rather than an empty stage. This is the line a minimap needs: without it the second view has a world of its own and renders nothing.", "SubViewport").param("other", THIS_VIEW, "Same world as", "The viewport whose world this view should show. Leave it on the game's own viewport for a second view of the running game.", "expression").param_built(_on_node_param()).featured())

	descriptors.append(F.act("ViewShareWorld3D", "Share The World (3D)", "{target.}world_3d = {other}.world_3d", CAT, "share the 3D world of [b]{other}[/b]", "The 3D twin: points a view at the same 3D world another viewport is drawing, so a rear-view mirror or a security monitor shows the level everybody is standing in rather than an empty one.", "SubViewport").param("other", THIS_VIEW, "Same world as", "The viewport whose world this view should show. Leave it on the game's own viewport for a second camera on the running level.", "expression").param_built(_on_node_param()))

	# The still WAITS, and that is the whole row. Reading a viewport's texture before the frame has
	# finished drawing hands back whatever was in the buffer - usually black, sometimes last frame -
	# so `RenderingServer.frame_post_draw` is not an optimisation here, it is the difference between a
	# picture and a bug report. The `await` makes the event that holds it a coroutine, which is why
	# this id is written down in the compiler's and the Doctor's coroutine lists as well.
	descriptors.append(F.act("ViewSaveStill", "Save A Still Of A View", "await RenderingServer.frame_post_draw\n{view}.get_texture().get_image().save_png({path})", CAT, "save a still of [b]{view}[/b] to [b]{path}[/b]", "Writes what a view is drawing to a PNG file, after waiting for the frame to finish. A photo mode, a level thumbnail, a save-slot picture, the postcard a player shares. The event pauses for the rest of that frame, so keep it off a per-frame trigger.").param("view", THIS_VIEW, "View", "The viewport to photograph. Leave it on the game's own viewport for what the player is looking at, or name a SubViewport for an off-screen one.", "expression").param("path", "\"user://still.png\"", "File", "Where to write the PNG. user:// is the writable folder on every platform.", "file_path").featured())

	descriptors.append(F.expr("ViewMousePosition", "Mouse Position In View", "{view}.get_mouse_position()", CAT, "mouse position in [b]{view}[/b]", "Where the pointer is inside one view, in that view's own pixels. A view has its own coordinate space, so this is the answer an in-world screen or a magnifier needs - the window's own answer is somewhere else entirely.").param("view", THIS_VIEW, "View", "The viewport to ask. Name a SubViewport for a picture drawn off screen.", "expression"))

	return descriptors


## The "On node" parameter in the shape the automatic retarget pass gives every other node-scoped
## row, for the two rows that spell their own `{target.}` slot. They have to: the retarget pass
## refuses to prefix a line whose right-hand side reads the assigned member back, and
## `world_2d = {other}.world_2d` does exactly that. It is safe here for the same reason it is safe on
## the drawing-order rows - the member being read belongs to the OTHER viewport, which the row names
## in a field of its own. Same id and same words as the automatic one, so a reader meets one field
## rather than two that look alike.
static func _on_node_param() -> ACEParam:
	return F.make_param("target", "String", "", "On node", "Act on another node instead of this one. Leave blank for this node, pick a node, or address one without a tree path - e.g. get_node(\"%Minimap\").", "expression")


static func section_descriptions() -> Dictionary:
	return {CAT: "A second picture of the game: how big a view renders, which world it shows, where the pointer is inside it, and how to keep a still of one."}
