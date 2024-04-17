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
	
	name_label.text = "host" if myid == 1 else str(myid)
	
	if is_multiplayer_authority():
		hp_bar.set_tint_progress(Color(0.757, 0.678, 0.341))
		name_label.get_parent().visible = false
		
func set_bar_value(val):
	hp_bar.value = val
	#print(hp_bar.value)
	
func set_health_text(txt):
	health_label.text = txt
