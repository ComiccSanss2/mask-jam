extends CharacterBody2D

# --- PARAMÈTRES ---
@export var speed : float = 150.0
@export var acceleration : float = 1500.0
@export var friction : float = 1200.0

# --- RÉFÉRENCES ---
@onready var jumpscare_layer = $JumpscareLayer
@onready var jumpscare_anim = $JumpscareLayer/JumpscareAnim 
@onready var scream_sound = $ScreamSound

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	jumpscare_layer.visible = false

func _physics_process(delta: float) -> void:
	if get_tree().paused: return

	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_vector != Vector2.ZERO:
		velocity = velocity.move_toward(input_vector * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	look_at(get_global_mouse_position())

# --- FONCTION DE MORT (Version AnimatedSprite) ---
func kill_player():
	if get_tree().paused: return
	
	print("JUMPSCARE ANIMATION !")
	
	# 1. On affiche le layer
	jumpscare_layer.visible = true
	
	# 2. On lance l'animation (assure-toi que l'anim s'appelle "default")
	jumpscare_anim.play("default") 
	
	# 3. On joue le son
	if scream_sound: scream_sound.play()
	
	# 4. On met en pause
	get_tree().paused = true
	
	# 5. On attend la fin de l'animation
	await jumpscare_anim.animation_finished
	
	# 6. Reload
	get_tree().paused = false
	get_tree().reload_current_scene()
