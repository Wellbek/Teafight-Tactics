extends Control

var peer = ENetMultiplayerPeer.new()
@export var player_scene: PackedScene

func _on_tmp_host_pressed():
	peer.create_server(135, 8)
	multiplayer.multiplayer_peer = peer
	_add_player()

func _on_tmp_join_pressed():
	peer.create_client("localhost", 135)
	multiplayer.multiplayer_peer = peer

func _add_player(id = 1):
	var player = player_scene.instantiate()
	player.name = str(id)
	get_tree().root.get_child(0).find_child("World").call_deferred("add_child", player)

func _on_tmp_test_pressed():
	print(multiplayer.get_peers())
	print(get_tree().root.get_child(0).find_child("World").get_children())

func _on_multiplayer_spawner_spawned(node):
	node.global_transform.origin.x += 18 * (multiplayer.get_peers().size())
	var newMaterial = StandardMaterial3D.new()
	newMaterial.albedo_color = Color.BROWN
	node.get_child(1).get_child(1).set_surface_override_material(0, newMaterial)
