@tool
class_name EventForgeMultiplayerACEs
extends RefCounted

# S10. Godot's high-level multiplayer as ONE object in the sheet's words.
#
# A networked script says four things: it sends a message, it asks whether it is the host, it asks
# whether it owns the object it is running on, and it wants to know its own peer id. Those are the
# rows here, and their templates are EXACTLY the lines the reading recognises - `f.rpc(...)`,
# `f.rpc_id(1, ...)`, `multiplayer.is_server()`, `multiplayer.get_unique_id()` - so a sent message
# reads the same sentence whether it was typed by hand or picked from this vocabulary.
#
# The message itself is a function marked `@rpc`; marking it is what the function row's own menu
# does, because the annotation belongs to the function rather than to the row that sends to it.
# Everything is filed under one category so the whole vocabulary reads and picks as one object -
# Multiplayer, standing next to System, exactly as the Editor object does.

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The one category every row here is filed under, which is also the object label the canvas draws.
const CATEGORY := "Multiplayer"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.make_descriptor("Core", "SendMessageToEveryone", "Send Message To Everyone", ACEDescriptor.ACEType.ACTION, "{message}.rpc({args})", "", [F.make_param("message", "String", "print", "Message", "The function marked as a message. Every peer runs it.", "expression"), F.make_param("args", "String", "", "Values", "Values to send with the message, comma separated.", "expression")], CATEGORY, "Send {message} to everyone {args}")
		.described("Runs a message on every peer in the game, including this one when the message says so. The function must be marked as a message first.").featured())
	descriptors.append(F.make_descriptor("Core", "SendMessageToHost", "Send Message To The Host", ACEDescriptor.ACEType.ACTION, "{message}.rpc_id(1{, args})", "", [F.make_param("message", "String", "print", "Message", "The function marked as a message.", "expression"), F.make_param("args", "String", "", "Values", "Values to send with the message, comma separated.", "expression")], CATEGORY, "Send {message} to the host {args}")
		.described("Runs a message on the host only - the peer that decides what is true, so cheats cannot be sent straight to everybody."))
	descriptors.append(F.make_descriptor("Core", "SendMessageToPeer", "Send Message To One Peer", ACEDescriptor.ACEType.ACTION, "{message}.rpc_id({peer}{, args})", "", [F.make_param("message", "String", "print", "Message", "The function marked as a message.", "expression"), F.make_param("peer", "String", "1", "Peer", "The peer id to send to.", "expression"), F.make_param("args", "String", "", "Values", "Values to send with the message, comma separated.", "expression")], CATEGORY, "Send {message} to {peer} {args}")
		.described("Runs a message on one named peer only - a private reply, or a correction sent back to the player it is about."))
	descriptors.append(F.make_descriptor("Core", "IsHost", "Is Host", ACEDescriptor.ACEType.CONDITION, "multiplayer.is_server()", "", [], CATEGORY, "Is host")
		.described("True on the peer that is hosting the game. Put everything that decides what is true behind this.").featured())
	descriptors.append(F.make_descriptor("Core", "OwnsThisObject", "Owns This Object", ACEDescriptor.ACEType.CONDITION, "is_multiplayer_authority()", "", [], CATEGORY, "Owns this object")
		.described("True when this peer is the one allowed to move and change this object - the player's own character rather than everybody else's copy of it."))
	descriptors.append(F.make_descriptor("Core", "MyPeerId", "My ID", ACEDescriptor.ACEType.EXPRESSION, "multiplayer.get_unique_id()", "", [], CATEGORY, "MyID")
		.described("This peer's own id. The host is always 1; everyone else gets a number when they join."))
	return descriptors


static func section_descriptions() -> Dictionary:
	return {
		CATEGORY: "Playing together over a network: the messages peers send each other, who is the host, and who owns which object."
	}
