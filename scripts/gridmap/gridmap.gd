extends Node3D

enum {SQUARE, HEX}

@export var x: int = 7
@export var z: int = 4
@export_enum("SQUARE", "HEX") var type:int = 0

@export var level_restricted = false
@export var amount_label: Label3D

#https://www.redblobgames.com/grids/hexagons/
const size = 1
const w = sqrt(3) * size
const h = 2*size
const offset = .55*w

# gaps between tiles
const hCorrection = .8 
const wCorrection = 1.10

var tiles = []

var num_units = 0

func _ready():
	if type == SQUARE: generateGrid(x,z)
	elif type == HEX: generateHexGrid(x,z)
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
			hex.set_multiplayer_authority(get_multiplayer_authority())
			tiles.append(hex)
			
func generateGrid(_x: int, _z:int):
	for xi in _x:
		for zi in _z:
			var square = preload("res://src/tiles/square.tscn").instantiate()
			add_child(square)
			var squareX = w*xi
			var squareZ = h*zi
			square.transform.origin = Vector3(squareX, 0, squareZ)
			square.set_multiplayer_authority(get_multiplayer_authority())
			tiles.append(square)

func getTiles():
	return tiles
	
func getType():
	return type
	
func getFirstFreeTile():
	for tile in tiles:
		if not tile.hasUnit():
			return tile
	return null
	
func get_number_of_units():
	return num_units
	
func increase_number_of_units():
	num_units += 1
	var player_level = get_parent().get_parent().get_level()
	if amount_label != null: 
		amount_label.text = str(num_units) + "/" + str(player_level)
		if num_units >= player_level: 
			toggle_label(false)
	
func decrease_number_of_units():
	num_units -= 1
	var player_level = get_parent().get_parent().get_level()
	if amount_label != null: 
		amount_label.text = str(num_units) + "/" + str(get_parent().get_parent().get_level())
		if num_units < player_level:
			toggle_label(true)
	
func can_place_unit():
	if level_restricted and get_parent().get_parent().get_level() <= num_units: return false
	return true

func toggle_label(val: bool):
	amount_label.text = str(num_units) + "/" + str(get_parent().get_parent().get_level())
	amount_label.visible = val
