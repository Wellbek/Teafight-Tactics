extends Node3D

@export var x: int = 7
@export var z: int = 4

#https://www.redblobgames.com/grids/hexagons/
const size = 1
const w = sqrt(3) * size
const h = 2*size
const offset = .55*w

# gaps between tiles
const hCorrection = .8 
const wCorrection = 1.1

func _ready():
	generateHexGrid(x,z)

func generateHexGrid(_x: int, _z:int):
	for xi in _x:
		for zi in _z:
			var hex = preload("res://src/hextile/hex.tscn").instantiate()
			add_child(hex)
			var hexX = w*xi*wCorrection
			var hexZ = hCorrection*h*zi
			if zi % 2 != 0:
				hexX += offset
			hex.global_transform.origin = Vector3(hexX, 0, hexZ)
