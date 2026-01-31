extends CharacterBody2D

# --- PARAMÈTRES ---
@export var speed : float = 150.0
@export var acceleration : float = 1500.0
@export var friction : float = 1200.0

@onready var jumpscare_layer = $JumpscareLayer
@onready var scream_sound = $JumpscareLayer/AudioStreamPlayer

func _ready():

	process_mode = Node.PROCESS_MODE_ALWAYS
	
	jumpscare_layer.visible = false

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return

	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_vector != Vector2.ZERO:
		velocity = velocity.move_toward(input_vector * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	
	look_at(get_global_mouse_position())

# --- FONCTION DE MORT ---
func kill_player():
	if get_tree().paused: return
	
	print("JUMPSCARE !")
	
	jumpscare_layer.visible = true
	if scream_sound: scream_sound.play()
	
	get_tree().paused = true
	
	await get_tree().create_timer(2.0).timeout
	
	get_tree().paused = false
	get_tree().reload_current_scene()
