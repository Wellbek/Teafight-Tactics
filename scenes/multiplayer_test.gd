extends Control

var peer = ENetMultiplayerPeer.new()
@export var player_scene: PackedScene

@export_subgroup("Temporary GUI Stuff")
@export var startButton: Button
@export var enable_on_start: Array[Control]
@export var disable_on_start: Array[Control]

func _ready():
	for c in enable_on_start:
		c.visible = false
	startButton.visible = false

func _on_tmp_host_pressed():
	peer.create_server(135, 8)
	multiplayer.multiplayer_peer = peer
	disable_enable()

func _on_tmp_join_pressed():
	peer.create_client("127.0.0.1", 135)
	multiplayer.multiplayer_peer = peer
	disable_enable()

func add_player(id = 1):
	var player = player_scene.instantiate()
	player.name = str(id)
	get_tree().root.get_child(0).find_child("World").call_deferred("add_child", player, true)
			
func start_game():
	if not multiplayer.is_server(): return
	
	startButton.visible = false
	
	for id in multiplayer.get_peers():
		add_player(id)
	
	if not OS.has_feature("dedicated_server"):
		add_player()
		
	#print(get_tree().root.get_child(0).find_child("World").get_children())
	
func disable_enable():
	for c in enable_on_start:
		c.visible = true
	for c in disable_on_start:
		c.visible = false
	
	if multiplayer.is_server(): startButton.visible = true

func _on_tmp_start_game_pressed():
	start_game()
