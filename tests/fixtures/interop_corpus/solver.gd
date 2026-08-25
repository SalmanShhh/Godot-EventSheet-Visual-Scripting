# eventsheets: stays code
#
# The mark above keeps this file out of the adoption table and out of every offer. It is a plain
# comment, so it survives the plugin being uninstalled and reads as what it is to anybody who opens
# the file in any editor. This one earns it: it is arithmetic, and rows would say nothing about it.
extends Node

var accumulated = 0.0


func integrate(value, step):
	accumulated += value * step * 0.5
	return accumulated
