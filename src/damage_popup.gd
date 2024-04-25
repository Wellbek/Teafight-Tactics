extends Label3D

@export var anim_player: AnimationPlayer

func _ready():
	anim_player.play("dmg_popup")

func _on_timer_timeout():
	queue_free()
