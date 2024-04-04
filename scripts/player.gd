extends Node3D

var main

@export var benchGrid: Node3D
@export var boardGrid: Node3D
@export var camera: Camera3D
@export var enemyCam: Camera3D

@export var multiplayerSpawner: MultiplayerSpawner

var units = []

var myid

func _enter_tree():
	main = get_tree().root.get_child(0)
	myid = name.to_int()
	set_multiplayer_authority(myid)
	#print(str(multiplayer.get_unique_id()) + ": " + str(get_multiplayer_authority()))
	multiplayerSpawner.set_multiplayer_authority(1)
	
func _ready():
	if (is_multiplayer_authority()):
		main.setPlayer(self)
	
		var ids = multiplayer.get_peers()
		ids.append(myid)
		ids.sort()
		var i = ids.find(myid)

		global_transform.origin.x += 19 * i
		camera.current = true

@rpc("any_peer", "call_local", "reliable")
func combatphase_setup(enemy_path, host:bool):
	var enemy = get_tree().root.get_node(enemy_path)
	
	var unit_parent = find_child("Units")
	unit_parent.visible = false
	var combatunit_parent = find_child("CombatUnits")	
	
	if not host:	
		combatunit_parent.global_transform.origin = enemy.find_child("CombatUnits").global_transform.origin
		combatunit_parent.rotate_y(deg_to_rad(180))
		main.changeCameraByID(enemy.name.to_int())
				
	for unit in unit_parent.get_children():
		copyUnit.rpc(unit.get_path(), combatunit_parent.get_path())

	combatunit_parent.visible = true

@rpc("any_peer", "call_local", "reliable")
func copyUnit(unit_path, parent_path):
	var unit = get_tree().root.get_node(unit_path)
	var parent = get_tree().root.get_node(parent_path)
	var copy = unit.duplicate()
	parent.call("add_child", copy, true)

func appendUnit(unit):
	units.append(unit)

func eraseUnit(unit):
	units.erase(unit)

func removeUnit(index):
	units.remove(index)
	
func getUnits():
	return units

func getBenchGrid():
	return benchGrid

func getBoardGrid():
	return boardGrid
	
func getCamera():
	return camera
	
func getEnemyCam():
	return enemyCam
	
func getID():
	return myid
