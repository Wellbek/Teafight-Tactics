extends Node3D

@export var x: int = 7
@export var z: int = 4

@export var type: Type = Type.SQUARE

enum Type {SQUARE, HEX}

#https://www.redblobgames.com/grids/hexagons/
const size = 1
const w = sqrt(3) * size
const h = 2*size
const offset = .55*w

# gaps between tiles
const hCorrection = .8 
const wCorrection = 1.10

var tiles = []

func _ready():
	if type == Type.SQUARE: generateGrid(x,z)
	elif type == Type.HEX: generateHexGrid(x,z)
	else: printerr("Unknown grid type")

func generateHexGrid(_x: int, _z:int):
	for xi in _x:
		for zi in _z:
			var hex = preload("res://src/tiles/hex.tscn").instantiate()
			add_child(hex)
			var hexX = w*xi*wCorrection
			var hexZ = hCorrection*h*zi
			if zi % 2 != 0:
				hexX += offset
			hex.transform.origin = Vector3(hexX, 0, hexZ)
			tiles.append(hex)
			
func generateGrid(_x: int, _z:int):
	for xi in _x:
		for zi in _z:
			var square = preload("res://src/tiles/square.tscn").instantiate()
			add_child(square)
			var squareX = w*xi
			var squareZ = h*zi
			square.transform.origin = Vector3(squareX, 0, squareZ)
			tiles.append(square)

func getTiles():
	return tiles
	
func getFirstFreeTile():
	for tile in tiles:
		if not tile.hasUnit():
			return tile
	return null
