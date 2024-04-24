extends Label

var pause = false

# Called when the node enters the scene tree for the first time.
func _ready():
	#_on_resize()
	#connect("resized", _on_resize)
	pass
	
func _on_resize():
	if pause: return
	
	pause = true
	add_theme_font_size_override("font_size", 1) # set to smallest
	var boundary = max(size.y, size.x)
	# increase until boundary reached
	while size.y < boundary:
		add_theme_font_size_override("font_size", get_theme_font_size("font_size")+1)
	add_theme_font_size_override("font_size", get_theme_font_size("font_size")-1) # undo last
	pause = false
