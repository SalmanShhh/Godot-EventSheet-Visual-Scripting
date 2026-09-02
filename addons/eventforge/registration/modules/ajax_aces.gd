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
	descriptors.append(F.act("AjaxRequest", "Request", "{node}.request({url})", CAT, "Request {url}", "Asks a server for something. The answer arrives on the request node's completed signal, not on this row.").param_typed("String", "node", NODE_DEFAULT, "Request node", "The HTTPRequest node that does the asking.", "expression").param("url", "\"https://example.com/scores\"", "URL", "The address to ask.", "expression").featured())
	descriptors.append(F.act("AjaxPost", "Post", "{node}.request({url}, [], HTTPClient.METHOD_POST, {data})", CAT, "Post {data} to {url}", "Sends something to a server. The answer arrives the same way a Request's does.").param_typed("String", "node", NODE_DEFAULT, "Request node", "The HTTPRequest node that does the sending.", "expression").param("data", "\"{}\"", "Data", "The body to send, as text. Build it with JSON ToString.", "expression").param("url", "\"https://example.com/post\"", "URL", "The address to send it to.", "expression").featured())
	descriptors.append(F.act("AjaxCancel", "Cancel Request", "{node}.cancel_request()", CAT, "Cancel request", "Stops a request that is still in flight. Safe to call when nothing is in flight.").param_typed("String", "node", NODE_DEFAULT, "Request node", "The HTTPRequest node to stop.", "expression"))

	# ── Conditions ──
	descriptors.append(F.cond("AjaxRequestSucceeded", "Request Succeeded", "{result} == HTTPRequest.RESULT_SUCCESS", CAT, "request succeeded", "True when the request reached the server and came back. Invert it for the early return every handler starts with.").param("result", "0", "Result", "The result value the completed signal handed over.", "expression").featured())
	descriptors.append(F.cond("AjaxStatusIsOk", "Status Is OK", "{code} == 200", CAT, "status is OK", "True when the server answered 200. A request can succeed and still be answered with a 404.").param("code", "200", "Status code", "The HTTP status the completed signal handed over.", "expression"))

	# ── Expressions ──
	descriptors.append(F.expr("AjaxLastData", "Last Data", "{body}.get_string_from_utf8()", CAT, "AJAX.LastData", "The answer that just arrived, as text. Feed it to JSON Parse when the server speaks JSON.").param("body", "PackedByteArray()", "Body", "The bytes the completed signal handed over.", "expression").featured())

	return descriptors
