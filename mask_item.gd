extends Area2D

@onready var label = $Label
@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D

var player_in_zone = null
var is_active = true 

func _ready():
	label.visible = false
	# Connexions
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Player" and is_active:
		player_in_zone = body
		label.visible = true

func _on_body_exited(body):
	if body.name == "Player":
		player_in_zone = null
		label.visible = false

func _input(event):
	if is_active and player_in_zone and event.is_action_pressed("interact"):
		take_mask()

func take_mask():
	if player_in_zone.has_method("add_mask"):
		player_in_zone.add_mask()
		
		start_respawn_cycle()

func start_respawn_cycle():
	print("Masque pris ! Respawn dans 60s...")
	is_active = false
	player_in_zone = null 
	
	# On cache tout
	visible = false 
	label.visible = false
	

	collision.set_deferred("disabled", true)
	
	# 3. On attend 60 secondes
	await get_tree().create_timer(60.0).timeout
	
	# 4. On réactive tout
	print("Le masque est réapparu !")
	visible = true
	collision.set_deferred("disabled", false)
	is_active = true
