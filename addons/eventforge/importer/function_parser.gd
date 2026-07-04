# EventForge - Function parser
# Parses top-level `func name(params) -> ret:` blocks from GDScript source, capturing each
# function's name, typed params, return type, and verbatim (indented) body text.
@tool
class_name FunctionParser
extends RefCounted


func parse(source: String) -> Array:
	var functions: Array = []
	var lines: PackedStringArray = source.split("\n")
	var index: int = 0
	while index < lines.size():
		var line: String = lines[index]
		if not line.begins_with("func "):
			index += 1
			continue
		var header: Dictionary = _parse_header(line.strip_edges())
		var body_lines: Array[String] = []
		var cursor: int = index + 1
		while cursor < lines.size():
			var body_line: String = lines[cursor]
			if body_line.strip_edges().is_empty():
				body_lines.append(body_line)
				cursor += 1
				continue
			if body_line.begins_with("\t") or body_line.begins_with(" "):
				body_lines.append(body_line)
				cursor += 1
			else:
				break
		while not body_lines.is_empty() and body_lines[body_lines.size() - 1].strip_edges().is_empty():
			body_lines.remove_at(body_lines.size() - 1)
		functions.append({
			"name": header.get("name", ""),
			"params": header.get("params", []),
			"return": header.get("return", "void"),
			"body": "\n".join(body_lines)
		})
		index = cursor
	return functions


func _parse_header(header: String) -> Dictionary:
	var function_name: String = ""
	var params: Array = []
	var return_type: String = "void"
	var open_index: int = header.find("(")
	var close_index: int = header.rfind(")")
	if open_index > 5 and close_index > open_index:
		function_name = header.substr(5, open_index - 5).strip_edges()
		var params_text: String = header.substr(open_index + 1, close_index - open_index - 1).strip_edges()
		if not params_text.is_empty():
			for part: String in params_text.split(","):
				var param_text: String = part.strip_edges()
				if param_text.is_empty():
					continue
				var colon_index: int = param_text.find(":")
				if colon_index >= 0:
					params.append({"id": param_text.substr(0, colon_index).strip_edges(), "type": param_text.substr(colon_index + 1).strip_edges()})
				else:
					params.append({"id": param_text, "type": "Variant"})
	var arrow_index: int = header.find("->")
	if arrow_index >= 0:
		return_type = header.substr(arrow_index + 2).strip_edges().trim_suffix(":").strip_edges()
	return {"name": function_name, "params": params, "return": return_type}
