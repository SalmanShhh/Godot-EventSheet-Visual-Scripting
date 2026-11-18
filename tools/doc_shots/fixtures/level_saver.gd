extends Node


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"save_level"):
		var __branch_u2: Node = $Level
		var __adopted_u2: Array[Node] = []
		for __part_u2: Node in __branch_u2.find_children("*", "", true, false):
			if __part_u2.owner == null:
				__part_u2.owner = __branch_u2
				__adopted_u2.append(__part_u2)
		var __scene_u2 := PackedScene.new()
		var __packed_u2 := __scene_u2.pack(__branch_u2)
		for __lent_u2: Node in __adopted_u2:
			__lent_u2.owner = null
		if __packed_u2 != OK:
			push_error("Save Branch As Scene File: %s could not be packed (error %d)." % [__branch_u2.name, __packed_u2])
		elif ResourceSaver.save(__scene_u2, "user://built_level.tscn") != OK:
			push_error("Save Branch As Scene File: nothing was written to %s." % "user://built_level.tscn")
	if Input.is_action_just_pressed(&"load_level") and __eventsheets_scene_is_data_only("user://built_level.tscn"):
		var __layout_u1: Node = get_tree().root.get_node_or_null("Built")
		if __layout_u1 == null:
			__layout_u1 = (load("user://built_level.tscn") as PackedScene).instantiate()
			__layout_u1.name = "Built"
			get_tree().root.add_child(__layout_u1)


func __eventsheets_scene_is_data_only(scene_path: String) -> bool:
	var scene_text: String = FileAccess.get_file_as_string(scene_path)
	if not scene_text.begins_with("[gd_scene"):
		return false
	for maker: String in ["Object(", "Resource("]:
		var maker_at: int = scene_text.find(maker)
		while maker_at >= 0:
			var lead: String = scene_text.substr(maker_at - 1, 1) if maker_at > 0 else ""
			if lead.to_lower() == lead.to_upper() and not lead.is_valid_int() and lead != "_":
				return false
			maker_at = scene_text.find(maker, maker_at + maker.length())
	var scene_lines: PackedStringArray = scene_text.split("\n")
	var line_index: int = 0
	while line_index < scene_lines.size():
		var tag: String = scene_lines[line_index].strip_edges()
		line_index += 1
		if not tag.begins_with("["):
			continue
		var closed_at: int = -1
		while closed_at < 0:
			var quoted: bool = false
			var scan: int = 0
			while scan < tag.length():
				if tag[scan] == "\"":
					quoted = not quoted
				elif tag[scan] == "]" and not quoted:
					break
				scan += 1
			if scan < tag.length():
				closed_at = scan
			elif line_index >= scene_lines.size():
				return false
			else:
				tag += " " + scene_lines[line_index].strip_edges()
				line_index += 1
		var head: String = tag.substr(1, closed_at - 1).strip_edges()
		var named_at: int = head.find(" ")
		var tag_name: String = head if named_at < 0 else head.substr(0, named_at)
		if tag_name != "ext_resource" and tag_name != "sub_resource":
			continue
		if head.contains("\\"):
			return false
		var rest: String = "" if named_at < 0 else head.substr(named_at + 1)
		var fields: Dictionary = {}
		var cursor: int = 0
		while cursor < rest.length():
			while cursor < rest.length() and rest[cursor] == " ":
				cursor += 1
			var key_at: int = cursor
			while cursor < rest.length() and rest[cursor] != "=" and rest[cursor] != " ":
				cursor += 1
			var field: String = rest.substr(key_at, cursor - key_at)
			while cursor < rest.length() and (rest[cursor] == " " or rest[cursor] == "="):
				cursor += 1
			var value: String = ""
			if cursor < rest.length() and rest[cursor] == "\"":
				var ends_at: int = rest.find("\"", cursor + 1)
				if ends_at < 0:
					return false
				value = rest.substr(cursor + 1, ends_at - cursor - 1)
				cursor = ends_at + 1
			else:
				var value_at: int = cursor
				while cursor < rest.length() and rest[cursor] != " ":
					cursor += 1
				value = rest.substr(value_at, cursor - value_at)
			if field.is_empty():
				return false
			fields[field] = value
		var kind: String = str(fields.get("type", ""))
		if kind.is_empty():
			return false
		if tag_name == "sub_resource":
			if kind.ends_with("Script"):
				return false
			continue
		var place: String = str(fields.get("path", ""))
		if place.contains("..") or not place.begins_with("res://"):
			return false
	return true
