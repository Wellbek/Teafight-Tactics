extends Node3D

enum {SQUARE, HEX}

@export var x: int = 7
@export var z: int = 4
@export_enum("SQUARE", "HEX") var type:int = 0

@export var level_restricted = false
@export var amount_label: Label3D

#https://www.redblobgames.com/grids/hexagons/
const SIZE = 1
const W = sqrt(3) * SIZE
const H = 2*SIZE
const OFFSET = .55*W

# gaps between tiles
const H_CORRECTION = .8 
const W_CORRECTION = 1.10

var tiles = []

var num_units = 0

func _ready():
	if type == SQUARE: generate_grid(x,z)
	elif type == HEX: generate_hex_grid(x,z)
	else: printerr("Unknown grid type")

func generate_hex_grid(_x: int, _z:int):
	for zi in _z:
		for xi in _x:
			var hex = preload("res://src/tiles/hex.tscn").instantiate()
			add_child(hex)
			var hexX = W*xi*W_CORRECTION
			var hexZ = H_CORRECTION*H*zi
			if zi % 2 != 0:
				hexX += OFFSET
			hex.transform.origin = Vector3(hexX, 0, hexZ)
			hex.set_multiplayer_authority(get_multiplayer_authority())
			tiles.append(hex)
			
func generate_grid(_x: int, _z:int):
	for zi in _z:
		for xi in _x:
			var square = preload("res://src/tiles/square.tscn").instantiate()
			add_child(square)
			var squareX = W*xi
			var squareZ = H*zi
			square.transform.origin = Vector3(squareX, 0, squareZ)
			square.set_multiplayer_authority(get_multiplayer_authority())
			tiles.append(square)

func get_tiles():
	return tiles
	
func get_type():
	return type
	
func get_first_free_tile():
	for tile in tiles:
		if not tile.has_unit():
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
	var player = get_parent().get_parent()
	if amount_label != null: 
		amount_label.text = str(num_units) + "/" + str(player.get_level())
		if num_units < player.get_level() and not player.is_defeated():
			toggle_label(true)
	
func can_place_unit():
	if (level_restricted and get_parent().get_parent().get_level() <= num_units) or get_parent().get_parent().is_defeated(): return false
	return true

func toggle_label(val: bool):
	if not can_place_unit(): amount_label.visible = false
	
	amount_label.text = str(num_units) + "/" + str(get_parent().get_parent().get_level())
	amount_label.visible = val
