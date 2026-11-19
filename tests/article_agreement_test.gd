# The English article before a type or class name: "an int", "an Array", "a float", "a String", "an Area2D".
# One helper reads every sentence that puts "a" in front of a name; a translated sentence passes through
# untouched, and the hover on a function head says what the function hands back with the right article.
@tool
class_name ArticleAgreementTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const Articles := preload("res://addons/eventforge/article_agreement.gd")


static func run() -> bool:
	var ok: bool = true
	ok = SUPPORT.pin_table("article_agreement", {
		"int": "an int", "float": "a float", "bool": "a bool", "String": "a String", "Array": "an Array",
		"Dictionary": "a Dictionary", "Variant": "a Variant", "Object": "an Object", "Node2D": "a Node2D",
		"Area2D": "an Area2D", "AudioStreamPlayer": "an AudioStreamPlayer", "AABB": "an AABB",
		"HBoxContainer": "an HBoxContainer", "AStar2D": "an AStar2D", "UDPServer": "a UDPServer",
		"RigidBody2D": "a RigidBody2D", "Image": "an Image", "Input": "an Input", "Unique": "a Unique",
		"UndoRedo": "an UndoRedo", "Vector2": "a Vector2", "Color": "a Color", "": "a value", "  ": "a value",
		"XRCamera3D": "an XRCamera3D", "Control": "a Control", "NavigationAgent2D": "a NavigationAgent2D",
		"Error": "an Error", "PackedStringArray": "a PackedStringArray",
	}, func(name: Variant) -> Variant: return Articles.with_article(str(name))) and ok

	ok = SUPPORT.pins("article_agreement sentences", [
		["int", Articles.agree_article("This function hands back a int.", "int"), "This function hands back an int."],
		["Array", Articles.agree_article("This function hands back a Array.", "Array"), "This function hands back an Array."],
		["float", Articles.agree_article("This function hands back a float.", "float"), "This function hands back a float."],
		["String", Articles.agree_article("This function hands back a String.", "String"), "This function hands back a String."],
		["sentence opening", Articles.agree_article("A Area2D: a node, one that extends CollisionObject2D.", "Area2D"), "An Area2D: a node, one that extends CollisionObject2D."],
		["two names", Articles.agree_article("It is a Image, not a Image.", "Image"), "It is an Image, not an Image."],
		["consonant name untouched", Articles.agree_article("Add a Node2D to the scene", "Node2D"), "Add a Node2D to the scene"],
	]) and ok


	# A name that only starts like another is not rewritten: "a Array2" is not the name "Array".
	ok = SUPPORT.pin_value("article_agreement", "a longer word is left alone",
		Articles.agree_article("It is a Arrayish thing.", "Array"), "It is a Arrayish thing.") and ok
	# A translated sentence holds no English "a <name>", so nothing changes.
	ok = SUPPORT.pin_value("article_agreement", "a translated sentence passes through",
		Articles.agree_article("Esta función devuelve un Array.", "Array"), "Esta función devuelve un Array.") and ok
	# A typed collection name carries brackets, which never break the pattern.
	ok = SUPPORT.pin_value("article_agreement", "a name with symbols",
		Articles.agree_article("This function hands back a Array[int].", "Array[int]"), "This function hands back an Array[int].") and ok

	return ok
