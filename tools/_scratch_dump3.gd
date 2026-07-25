@tool
extends SceneTree


func _init() -> void:
	for d: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		if d.ace_id in ["SetVar", "SetRotationDeg"]:
			var ps: PackedStringArray = PackedStringArray()
			for p: ACEParam in d.params:
				ps.append("%s(hint=%s,def=%s)" % [p.id, p.hint, str(p.default_value)])
			print("### ", d.ace_id, " T<<", d.codegen_template, ">> P<<", ", ".join(ps), ">>")
	quit(0)
