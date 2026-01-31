extends CharacterBody2D

# États de l'IA
enum State { WANDER, CHASE }
var current_state = State.WANDER

# --- PARAMÈTRES ---
@export var wander_speed = 100.0
@export var chase_speed = 165.0
@export var wander_range = 250.0

# --- RÉFÉRENCES ---
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var timer: Timer = $Timer
@onready var sprite: Sprite2D = $Sprite2D
@onready var ray_cast: RayCast2D = $RayCast2D

var player_ref = null    
var last_position: Vector2
var stuck_timer: float = 0.0

func _ready():
	motion_mode = MOTION_MODE_FLOATING
	
	nav_agent.path_postprocessing = NavigationPathQueryParameters2D.PATH_POSTPROCESSING_CORRIDORFUNNEL
	nav_agent.path_desired_distance = 20.0
	nav_agent.target_desired_distance = 30.0
	
	ray_cast.add_exception(self)
	
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	
	await get_tree().physics_frame
	get_new_wander_target()

func _physics_process(delta):
	if get_tree().paused: return 
	
	rotation = 0 
	
	# --- LOGIQUE DE VISION ---
	var can_see_player = false
	if player_ref != null:
		ray_cast.target_position = to_local(player_ref.global_position)
		ray_cast.force_raycast_update()
		var collider = ray_cast.get_collider()
		if collider != null and collider.name == "Player":
			can_see_player = true
	
	if can_see_player:
		current_state = State.CHASE
		timer.stop() 
		stuck_timer = 0
	else:
		if current_state == State.CHASE:
			current_state = State.WANDER
			get_new_wander_target()

	# --- DÉPLACEMENT ---
	var current_speed = wander_speed
	if current_state == State.CHASE:
		current_speed = chase_speed
		if player_ref:
			nav_agent.target_position = player_ref.global_position
	
	if nav_agent.is_navigation_finished():
		if current_state == State.WANDER and timer.is_stopped():
			velocity = Vector2.ZERO
			timer.start()
		return

	
	if current_state == State.WANDER:
		if global_position.distance_to(last_position) < 1.0:
			stuck_timer += delta
		else:
			stuck_timer = 0
		
		if stuck_timer > 0.5: 
			get_new_wander_target() 
			stuck_timer = 0
		last_position = global_position

	# Calcul du mouvement
	var current_pos = global_position
	var next_pos = nav_agent.get_next_path_position()
	var new_velocity = current_pos.direction_to(next_pos) * current_speed
	
	velocity = velocity.move_toward(new_velocity, 1200 * delta)
	

	if velocity.x > 0: sprite.flip_h = false
	elif velocity.x < 0: sprite.flip_h = true
	
	move_and_slide()

# --- SYSTÈME DE BALADE ---
func get_new_wander_target():
	var random_dir = Vector2.RIGHT.rotated(randf_range(0, TAU))
	var unsafe_target = global_position + (random_dir * wander_range)
	var map = get_world_2d().navigation_map
	var safe_target = NavigationServer2D.map_get_closest_point(map, unsafe_target)
	nav_agent.target_position = safe_target

func _on_timer_timeout():
	if current_state == State.WANDER:
		get_new_wander_target()

# --- SIGNAUX ---

# DetectionArea 
func _on_detection_area_body_entered(body):
	if body.name == "Player": player_ref = body

func _on_detection_area_body_exited(body):
	if body.name == "Player": player_ref = null

# KillArea 
func _on_kill_area_body_entered(body):
	if body.name == "Player":
		if body.has_method("kill_player"):
			body.kill_player()
