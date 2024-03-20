extends Node

@export var unitGrid: Node3D
@export var timer: Timer
@export var gui: Control

var playerUnits = []

func getUnitGrid():
	return unitGrid
	
func getTimer():
	return timer
	
func getUI():
	return gui
