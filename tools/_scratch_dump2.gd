@tool
extends SceneTree


func _init() -> void:
	for d: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		var t: String = d.codegen_template
		if d.ace_id.to_lower().contains("rotat") or d.ace_id.to_lower().contains("setvar") or d.ace_id.begins_with("On") and d.ace_type == ACEDescriptor.ACEType.TRIGGER:
			print("### ", d.ace_id, " | type=", d.ace_type, " | node=", d.node_type, " | T<<", t.replace("\n", "\n"), ">>")
	quit(0)
