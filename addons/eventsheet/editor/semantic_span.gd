@tool
class_name SemanticSpan
extends RefCounted

enum SpanType {
OBJECT,
CONDITION,
ACTION,
VALUE,
OPERATOR,
KEYWORD,
EXPRESSION,
COMMENT
}

var text: String = ""
var type: SpanType = SpanType.KEYWORD
var rect: Rect2 = Rect2()
var metadata: Variant = null
var hoverable := true
