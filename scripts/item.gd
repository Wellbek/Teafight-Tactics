extends StaticBody3D

@export var item_texture: Texture

@export_category("Stats")
@export var item_name = ""
@export var attackrange = 0
@export var health = 0
@export var attack_dmg = 0
@export var armor = 0
@export var attack_speed: float = 0
@export var crit_chance: float = 0
@export var ability_power = 0
@export var magic_resist = 0
@export var mana = 0
@export var omnivamp: float = 0
@export var ability_crit: bool = false
@export var component = false
@export var unique = false # Unique - only 1 per champion
@export_multiline var tooltip: String = ""

const RECIPES = {
	"BF Sword": {"BF Sword": "Deathblade", "Chain Vest": "Edge of Night", "Giants Belt": "Sterak's Gage", "Needlessly Large Rod": "Hextech Gunblade", "Negatron Cloak": "Bloodthirster", "Sparring Gloves": "Infinity Edge", "Recurve Bow": "Giant Slayer", "Tear of the Goddess": "Spear of Shojin"},
	"Chain Vest": {"BF Sword": "Edge of Night", "Chain Vest": "Bramble Vest", "Giants Belt": "Sunfire Cape", "Needlessly Large Rod": "", "Negatron Cloak": "Gargoyle Stoneplate", "Sparring Gloves": "Steadfast Heart", "Recurve Bow": "Titan's Resolve", "Tear of the Goddess": "Protector's Vow"},
	"Giants Belt": {"BF Sword": "Sterak's Gage", "Chain Vest": "Sunfire Cape", "Giants Belt": "Warmog's Armor", "Needlessly Large Rod": "Morellonomicon", "Negatron Cloak": "Evenshroud", "Sparring Gloves": "Guardbreaker", "Recurve Bow": "Nashor's Tooth", "Tear of the Goddess": "Redemption"},
	"Needlessly Large Rod": {"BF Sword": "Hextech Gunblade", "Chain Vest": "Crownguard", "Giants Belt": "Morellonomicon", "Needlessly Large Rod": "Rabadon's Deathcap", "Negatron Cloak": "Ionic Spark", "Sparring Gloves": "Jeweled Gauntlet", "Recurve Bow": "Guinsoo's Rageblade", "Tear of the Goddess": "Archangel's Staff"},
	"Negatron Cloak": {"BF Sword": "Bloodthirster", "Chain Vest": "Gargoyle Stoneplate", "Giants Belt": "Evenshroud", "Needlessly Large Rod": "Ionic Spark", "Negatron Cloak": "Dragon's Claw", "Sparring Gloves": "Quicksilver", "Recurve Bow": "Runaan's Hurricane", "Tear of the Goddess": "Adaptive Helm"},
	"Sparring Gloves": {"BF Sword": "Infinity Edge", "Chain Vest": "Steadfast Heart", "Giants Belt": "Guardbreaker", "Needlessly Large Rod": "Jeweled Gauntlet", "Negatron Cloak": "Quicksilver", "Sparring Gloves": "Thief's Gloves", "Recurve Bow": "Last Whisper", "Tear of the Goddess": "Hand of Justice"},
	"Recurve Bow": {"BF Sword": "Giant Slayer", "Chain Vest": "Titan's Resolve", "Giants Belt": "Nashor's Tooth", "Needlessly Large Rod": "Guinsoo's Rageblade", "Negatron Cloak": "Runaan's Hurricane", "Sparring Gloves": "Last Whisper", "Recurve Bow": "Red Buff", "Tear of the Goddess": "Statikk Shiv"},
	"Tear of the Goddess": {"BF Sword": "Spear of Shojin", "Chain Vest": "Protector's Vow", "Giants Belt": "Redemption", "Needlessly Large Rod": "Archangel's Staff", "Negatron Cloak": "Adaptive Helm", "Sparring Gloves": "Hand of Justice", "Recurve Bow": "Statikk Shiv", "Tear of the Goddess": "Blue Buff"}
}

var dragging = false

var initial_pos: Vector3

var coll

var multisync: MultiplayerSynchronizer

var main
var timer

var holder = null

func _ready():
	main = get_tree().root.get_child(0)	
	timer = main.get_timer()
	
	set_multiplayer_authority(get_parent().get_parent().get_id())
	
	multisync = find_child("MultiplayerSynchronizer", false)
	
	connect("mouse_entered", _on_mouse_entered)
	connect("mouse_exited", _on_mouse_exited)

func _input_event(camera, event, position, normal, shape_idx):
	if not is_multiplayer_authority(): return

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT and !is_dragging() and not main.get_player().is_defeated():
		set_dragging(true)
		initial_pos = global_transform.origin

		transform.origin.y += 1

func _input(event):
	if not is_multiplayer_authority(): return
	
	if is_dragging():
		if (event is InputEventMouseButton and event.is_released() and event.button_index == MOUSE_BUTTON_LEFT) or main.get_player().is_defeated():
			place_item()
		elif event is InputEventMouseMotion:
			var viewport := get_viewport()
			var mouse_position := viewport.get_mouse_position()
			var camera := viewport.get_camera_3d()
			
			var origin := camera.project_ray_origin(mouse_position)
			var direction := camera.project_ray_normal(mouse_position)

			var ray_length := camera.far
			var end := origin + direction * ray_length
			
			var space_state := get_world_3d().direct_space_state
			var query := PhysicsRayQueryParameters3D.create(origin, end, 0b00000000_00000000_00000110_00011111)
			var result := space_state.intersect_ray(query)
			if not result.is_empty() and result.collider != null:
				if (result.collider.get_collision_layer() in [8,24] and result.collider.is_multiplayer_authority()) or result.collider.get_collision_layer() == (512 if (main.get_player().defender or not main.get_player().get_current_enemy()) else 1024):
					if result.collider != coll:
						if coll:
							# reset highlight of last unit
							pass
						# highlight current unit
						coll = result.collider
						# ...
				else: 
					coll = null
					
				var mouse_position_3D:Vector3 = result.get("position", initial_pos if coll == null else coll.global_transform.origin)

				global_transform.origin = Vector3(mouse_position_3D.x, global_transform.origin.y, mouse_position_3D.z)
				
func set_dragging(value):
	dragging = value
	toggle_sync(!value)
	
func is_dragging():
	return dragging
	
func toggle_sync(value):
	if not is_multiplayer_authority(): return
	
	for prop in multisync.replication_config.get_properties():
		#print(prop)
		multisync.replication_config.property_set_watch(prop, value)

func place_item():
	if is_dragging():
		transform.origin.y -= 1
		set_dragging(false)
		
		if coll == null:  
			global_transform.origin = initial_pos
		elif coll.get_collision_layer() in [8, 24]:
			if (component and not coll.can_equip_component()) or (not component and not coll.can_equip_item(self)):
				coll = null
				global_transform.origin = initial_pos
			else:
				holder = coll
				coll.equip_item.rpc(get_path())

# this is executed on each client as equip_item is calling this
func upgrade(other_component):
	if not is_multiplayer_authority():  # If we're a client
		# Only request the server to do the combine
		request_combine.rpc_id(1, other_component.get_path())
		return
		
	# Server-only code from here
	var new_item_name = RECIPES[item_name][other_component.get_item_name()]
	var item_instance_name = new_item_name.to_lower().replacen(" ", "_").replacen("'", "")
	var instance = load("res://src/items/combined_items//" + item_instance_name + ".tscn").instantiate()
	get_parent().add_child(instance, true)
	
	if holder:
		holder.equip_item.rpc(instance.get_path())
	
	# Cleanup old items
	other_component.queue_free()
	queue_free()

@rpc("any_peer", "reliable")
func request_combine(other_component_path: NodePath):
	if not multiplayer.is_server():
		return
	var other_component = get_node(other_component_path)
	if other_component:
		upgrade(other_component)


func get_item_name():
	return item_name

func is_component():
	return component
				
func is_equipped():
	return holder
	
func unequip():
	holder = null
				
func get_attack_range():
	return attackrange
	
func get_health():
	return health
	
func get_attack_dmg():
	return attack_dmg
	
func get_armor():
	return armor
	
func get_attack_speed():
	return attack_speed	
	
func get_texture():
	return item_texture
	
func get_crit_chance():
	return crit_chance

func get_mana():
	return mana
	
func get_ability_power():
	return ability_power
	
func get_mr():
	return magic_resist
	
func get_omnivamp():
	return omnivamp
	
func get_ability_crit():
	return ability_crit

func _on_mouse_entered():
	$Tooltip.text = item_name + ":\n" + tooltip
	$Tooltip.visible = true

func _on_mouse_exited():
	$Tooltip.visible = false
	
func is_unique():
	return unique
