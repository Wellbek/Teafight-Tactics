extends Node

#var peer = ENetMultiplayerPeer.new()
@export var player_scene: PackedScene
@export var player_bar_scene: PackedScene
#var port = 9999

@export var main: Node
@export var timer: Timer

@export_subgroup("Temporary GUI Stuff")
@export var startButton: Button
@export var enable_on_start: Array[Control]
@export var disable_on_start: Array[Control]
@export var id_box: TextEdit

var lobby_id = 0
var peer = SteamMultiplayerPeer.new()

func _init() -> void:
	# Set your game's Steam app ID here
	OS.set_environment("SteamAppId", str(480))
	OS.set_environment("SteamGameId", str(480))
	Steam.steamInitEx()
	
func _process(delta):
	Steam.run_callbacks()

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	peer.lobby_created.connect(_on_lobby_created)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	open_lobby_list()
	
	for c in enable_on_start:
		c.visible = false
	startButton.visible = false

func _on_tmp_host_pressed():	
	#peer.create_server(port, 8)
	peer.create_lobby(SteamMultiplayerPeer.LOBBY_TYPE_PUBLIC)
	multiplayer.multiplayer_peer = peer
	disable_enable()

func _on_tmp_join_pressed():
	#peer.create_client(ip_box.text, port)
	#multiplayer.multiplayer_peer = peer
	var id = id_box.text
	if id.is_valid_int():	
		join_lobby(int(id_box.text))
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
	
func join_lobby(id):
	peer.connect_lobby(id)
	multiplayer.multiplayer_peer = peer
	lobby_id = id
	disable_enable()

func _on_tmp_start_game_pressed():
	start_game()
	
func open_lobby_list():
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.requestLobbyList()
	
func _on_lobby_match_list(lobbies):
	for lobby in lobbies:
		var lobby_name = Steam.getLobbyData(lobby, "name")
		var mem_count = Steam.getNumLobbyMembers(lobby)
		
		var but = Button.new()
		but.set_text(str(lobby_name) + " | " + str(mem_count) + "/8")
		but.set_size(Vector2(100,5))
		
		but.connect("pressed", Callable(self, "join_lobby").bind(lobby))
		
		$"../GUI/LobbyContainer/Lobbies".add_child(but)
	
func _on_lobby_created(connect, id):
	if connect:
		lobby_id = id
		Steam.setLobbyData(lobby_id, "name", str(Steam.getPersonaName()+ "'s Lobby"))
		Steam.setLobbyJoinable(lobby_id, true)
		print("lobby created with id " + str(lobby_id))
	
func _on_peer_connected():
	print("someone connected")
	
func _on_peer_disconnected():
	print("someone disconnected")

func _on_tmp_lobbies_pressed():
	$"../GUI/LobbyContainer".visible = !$"../GUI/LobbyContainer".visible
	if $"../GUI/LobbyContainer".visible:
		if $"../GUI/LobbyContainer/Lobbies".get_child_count() > 0:
			for n in $"../GUI/LobbyContainer/Lobbies".get_children():
				n.queue_free()
		open_lobby_list()
