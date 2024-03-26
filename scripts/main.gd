extends Node

var player
@export var timer: Timer
@export var gui: Control

func setPlayer(_player):
	player = _player

func getPlayer():
	return player
	
func getTimer():
	return timer
	
func getUI():
	return gui
