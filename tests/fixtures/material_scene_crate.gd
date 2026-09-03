# A crate and a barrel wearing one stone material between them, and a banner wearing a shader.
#
# The fixture behind the two material findings: the mesh pair is one `.tres` worn twice, which is
# what "who else wears this" has to be able to answer for a 3D scene, and the banner is the 2D item
# whose blend cannot be set from a row because its blend lives inside its shader. The two meshes wear
# the same file two DIFFERENT ways - the whole mesh on one, one surface slot on the other - because
# both spellings have to be read for the answer to be true.
extends MeshInstance3D
