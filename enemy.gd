extends CharacterBody2D

# --- ÉTATS ---
# Ajout de l'état NOTICE
enum State { WANDER, NOTICE, CHASE }
var current_state = State.WANDER

# --- PARAMÈTRES ---
@export var wander_speed = 100.0
@export var chase_speed = 160.0
@export var wander_range = 250.0
@export var notice_duration = 1.0 # Le temps de pause avant l'attaque

# --- RÉFÉRENCES ---
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var timer: Timer = $Timer
@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var ray_cast: RayCast2D = $RayCast2D
@onready var tension_sound: AudioStreamPlayer = $TensionSound

# --- VARIABLES INTERNES ---
var player_ref = null      
var last_position: Vector2  
var stuck_timer: float = 0.0
var audio_tween: Tween     

func _ready():
	motion_mode = MOTION_MODE_FLOATING
	
	ray_cast.add_exception(self)
	
	nav_agent.path_postprocessing = NavigationPathQueryParameters2D.PATH_POSTPROCESSING_CORRIDORFUNNEL
	nav_agent.path_desired_distance = 20.0
	nav_agent.target_desired_distance = 30.0
	
	# Timer setup
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	
	# Attendre que la map soit chargée
	await get_tree().physics_frame
	get_new_wander_target()

func _physics_process(delta):
	if get_tree().paused: return
	
	rotation = 0 
	
	# --- 1. SYSTÈME DE VISION INTELLIGENT ---
	var can_see_player = false
	
	if player_ref != null:
		var is_player_hidden = false
		if "is_hidden" in player_ref and player_ref.is_hidden:
			is_player_hidden = true
		
		if not is_player_hidden:
			ray_cast.target_position = to_local(player_ref.global_position)
			ray_cast.force_raycast_update()
			var collider = ray_cast.get_collider()
			
			if collider != null and collider.name == "Player":
				can_see_player = true
	
	# --- 2. GESTION DES ÉTATS ---
	if can_see_player:
		# Si on était en train de se balader, on marque une pause (NOTICE)
		if current_state == State.WANDER:
			start_notice_delay()
		
		# Si on est déjà en NOTICE ou CHASE, on ne fait rien de spécial ici
		# La transition NOTICE -> CHASE se fait via le timer
			
	else:
		# Si on perd le joueur de vue, on retourne patrouiller
		if current_state == State.CHASE or current_state == State.NOTICE:
			current_state = State.WANDER
			get_new_wander_target()

	# --- 3. DÉPLACEMENT ---
	var current_speed = wander_speed
	
	# Gestion spécifique selon l'état
	match current_state:
		State.NOTICE:
			# PENDANT LE NOTICE : ON STOPPE TOUT
			velocity = Vector2.ZERO
			# Petit effet visuel optionnel : se tourner vers le joueur
			if player_ref:
				var dir = global_position.direction_to(player_ref.global_position)
				if dir.x > 0: sprite.flip_h = false
				elif dir.x < 0: sprite.flip_h = true
			move_and_slide()
			return # On arrête la fonction ici pour ne pas calculer le pathfinding

		State.CHASE:
			current_speed = chase_speed
			timer.stop() # On s'assure que le timer de wander est coupé
			if player_ref:
				nav_agent.target_position = player_ref.global_position
				
		State.WANDER:
			current_speed = wander_speed

	# Logique de mouvement standard (pour Wander et Chase)
	if nav_agent.is_navigation_finished():
		if current_state == State.WANDER and timer.is_stopped():
			velocity = Vector2.ZERO
			timer.start()
		return

	# --- 4. ANTI-STUCK ---
	if current_state == State.WANDER:
		if global_position.distance_to(last_position) < 1.0:
			stuck_timer += delta
		else:
			stuck_timer = 0
		
		if stuck_timer > 0.5:
			get_new_wander_target()
			stuck_timer = 0
		last_position = global_position

	# Calcul de la vélocité finale
	var next_pos = nav_agent.get_next_path_position()
	var new_velocity = global_position.direction_to(next_pos) * current_speed
	
	# Application avec inertie
	velocity = velocity.move_toward(new_velocity, 1200 * delta)
	
	# Gestion du Sprite (Gauche/Droite)
	if velocity.x > 0: sprite.flip_h = false
	elif velocity.x < 0: sprite.flip_h = true
	
	move_and_slide()

# --- NOUVELLE FONCTION POUR LE DÉLAI ---
func start_notice_delay():
	current_state = State.NOTICE
	velocity = Vector2.ZERO
	timer.stop() # On arrête le timer de patrouille
	
	# On crée un petit timer temporaire de 0.5 seconde
	# create_timer crée un timer qui se détruit tout seul à la fin
	await get_tree().create_timer(notice_duration).timeout
	
	# Vérification de sécurité : est-ce qu'on est TOUJOURS en mode Notice ?
	# (Le joueur pourrait s'être caché entre temps)
	if current_state == State.NOTICE:
		current_state = State.CHASE
		stuck_timer = 0

# --- FONCTIONS DE NAVIGATION ---

func get_new_wander_target():
	var random_dir = Vector2.RIGHT.rotated(randf_range(0, TAU))
	var unsafe_target = global_position + (random_dir * wander_range)
	var map = get_world_2d().navigation_map
	var safe_target = NavigationServer2D.map_get_closest_point(map, unsafe_target)
	nav_agent.target_position = safe_target

func _on_timer_timeout():
	if current_state == State.WANDER:
		get_new_wander_target()

# --- GESTION AUDIO ---

func play_tension():
	if audio_tween: audio_tween.kill()
	if not tension_sound.playing:
		tension_sound.volume_db = -80.0
		tension_sound.play()
	audio_tween = get_tree().create_tween()
	audio_tween.tween_property(tension_sound, "volume_db", 0.0, 2.0)

func stop_tension():
	if audio_tween: audio_tween.kill()
	audio_tween = get_tree().create_tween()
	audio_tween.tween_property(tension_sound, "volume_db", -80.0, 3.0)
	audio_tween.tween_callback(tension_sound.stop)

# --- SIGNAUX ---

func _on_detection_area_body_entered(body):
	if body.name == "Player":
		player_ref = body
		play_tension() 

func _on_detection_area_body_exited(body):
	if body.name == "Player":
		player_ref = null
		stop_tension() 
		# Si on quitte la zone, on reset tout en Wander
		if current_state == State.CHASE or current_state == State.NOTICE:
			current_state = State.WANDER
			get_new_wander_target()

func _on_kill_area_body_entered(body):
	if body.name == "Player":
		if body.has_method("kill_player"):
			body.kill_player()
