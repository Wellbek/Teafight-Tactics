extends Control

var main
var myid

@export var name_label: Label
@export var health_label: Label
@export var hp_bar: TextureProgressBar

func _enter_tree():
	myid = name.to_int()
	set_multiplayer_authority(myid)

func _ready():
	main = get_tree().root.get_child(0)
	
	name_label.text = "Player" + str(myid)
	
func init_bar():
	if is_multiplayer_authority():
		hp_bar.set_tint_progress(Color(0.757, 0.678, 0.341))
		name_label.get_parent().visible = false
		if not main.get_node("MultiplayerManager").test: set_bar_name.rpc(Steam.getPersonaName())
		
@rpc("any_peer", "call_local", "reliable")
func set_bar_name(name):
	name_label.text = name	
	
func set_bar_value(val):
	hp_bar.value = val
	#print(hp_bar.value)
	
func set_health_text(txt):
	health_label.text = txt
