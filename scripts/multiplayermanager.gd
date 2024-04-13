extends Node

var peer = ENetMultiplayerPeer.new()
@export var player_scene: PackedScene
@export var player_bar_scene: PackedScene
var port = 6005

@export var main: Node
@export var timer: Timer

@export_subgroup("Temporary GUI Stuff")
@export var startButton: Button
@export var enable_on_start: Array[Control]
@export var disable_on_start: Array[Control]

func _ready():
	for c in enable_on_start:
		c.visible = false
	startButton.visible = false

func _on_tmp_host_pressed():
	peer.create_server(port, 8)
	multiplayer.multiplayer_peer = peer
	disable_enable()

func _on_tmp_join_pressed():
	peer.create_client("192.168.178.33", port)
	multiplayer.multiplayer_peer = peer
	disable_enable()

# only executed on server but sync using multiplayerspawner to other clients
func add_player(id = 1):
	var player = player_scene.instantiate()
	var player_bar = player_bar_scene.instantiate()
	player.name = str(id)
	player_bar.name = str(id)
	
	get_tree().root.get_child(0).get_node("GUI/PlayerBars/ColorRect/VBoxContainer").call("add_child", player_bar, true)
	get_tree().root.get_child(0).find_child("World").call("add_child", player, true)
	
	main.players.append(player)

func start_game():
	if not multiplayer.is_server(): return
	
	startButton.visible = false
	
	for id in multiplayer.get_peers():
		add_player(id)
	
	if not OS.has_feature("dedicated_server"):
		add_player()

	timer.initialize()
	
func disable_enable():
	for c in enable_on_start:
		c.visible = true
	for c in disable_on_start:
		c.visible = false
	
	if multiplayer.is_server(): startButton.visible = true

func _on_tmp_start_game_pressed():
	start_game()
