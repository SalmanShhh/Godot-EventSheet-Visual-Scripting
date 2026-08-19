# EventForge module - the AJAX object (asking a server for something, and sending it something).
#
# A web request in Godot is an HTTPRequest node: you call `request(url)` on it and its
# `request_completed` signal hands back a result code, an HTTP status, the headers and the body as
# bytes. These rows are those exact calls, under the one object name the sheet files web work
# under - so a hand-written request opened as a sheet and a request built from the picker are the
# same bytes and read as the same rows.
#
# Every template writes the shape the reading recognises, which is the whole contract: Request writes
# `<node>.request(<url>)`, Post writes the four-argument POST spelling, the answer's bytes read back
# as AJAX.LastData, and the success question is the comparison every handler already writes.
@tool
class_name EventForgeAjaxACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "AJAX"

## The node every row acts on. An HTTPRequest sitting beside the sheet's own node is the arrangement
## nearly every project uses, so it is the default the row arrives with.
const NODE_DEFAULT := "$HTTPRequest"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Actions ──
	descriptors.append(F.make_descriptor("Core", "AjaxRequest", "Request", ACEDescriptor.ACEType.ACTION, "{node}.request({url})", "", [F.make_param("node", "String", NODE_DEFAULT, "Request node", "The HTTPRequest node that does the asking.", "expression"), F.make_param("url", "String", "\"https://example.com/scores\"", "URL", "The address to ask.", "expression")], CAT, "Request {url}")
		.described("Asks a server for something. The answer arrives on the request node's completed signal, not on this row.").featured())
	descriptors.append(F.make_descriptor("Core", "AjaxPost", "Post", ACEDescriptor.ACEType.ACTION, "{node}.request({url}, [], HTTPClient.METHOD_POST, {data})", "", [F.make_param("node", "String", NODE_DEFAULT, "Request node", "The HTTPRequest node that does the sending.", "expression"), F.make_param("data", "String", "\"{}\"", "Data", "The body to send, as text. Build it with JSON ToString.", "expression"), F.make_param("url", "String", "\"https://example.com/post\"", "URL", "The address to send it to.", "expression")], CAT, "Post {data} to {url}")
		.described("Sends something to a server. The answer arrives the same way a Request's does.").featured())
	descriptors.append(F.make_descriptor("Core", "AjaxCancel", "Cancel Request", ACEDescriptor.ACEType.ACTION, "{node}.cancel_request()", "", [F.make_param("node", "String", NODE_DEFAULT, "Request node", "The HTTPRequest node to stop.", "expression")], CAT, "Cancel request")
		.described("Stops a request that is still in flight. Safe to call when nothing is in flight."))

	# ── Conditions ──
	descriptors.append(F.make_descriptor("Core", "AjaxRequestSucceeded", "Request Succeeded", ACEDescriptor.ACEType.CONDITION, "{result} == HTTPRequest.RESULT_SUCCESS", "", [F.make_param("result", "String", "0", "Result", "The result value the completed signal handed over.", "expression")], CAT, "request succeeded")
		.described("True when the request reached the server and came back. Invert it for the early return every handler starts with.").featured())
	descriptors.append(F.make_descriptor("Core", "AjaxStatusIsOk", "Status Is OK", ACEDescriptor.ACEType.CONDITION, "{code} == 200", "", [F.make_param("code", "String", "200", "Status code", "The HTTP status the completed signal handed over.", "expression")], CAT, "status is OK")
		.described("True when the server answered 200. A request can succeed and still be answered with a 404."))

	# ── Expressions ──
	descriptors.append(F.make_descriptor("Core", "AjaxLastData", "Last Data", ACEDescriptor.ACEType.EXPRESSION, "{body}.get_string_from_utf8()", "", [F.make_param("body", "String", "PackedByteArray()", "Body", "The bytes the completed signal handed over.", "expression")], CAT, "AJAX.LastData")
		.described("The answer that just arrived, as text. Feed it to JSON Parse when the server speaks JSON.").featured())

	return descriptors
