extends CharacterBody2D
class_name EnemyDrone

# Enemy drone AI script - patrols area and detects player
# Part of NEXUS-7's security network

# Movement constants
const PATROL_SPEED = 150.0
const CHASE_SPEED = 250.0
const ROTATION_SPEED = 2.0

# Detection constants
const DETECTION_RANGE = 200.0
const DETECTION_ANGLE = 60.0  # degrees, total cone width
const DETECTION_TIME = 1.5    # seconds to fully detect player
const LOSE_TARGET_TIME = 3.0  # seconds before giving up chase

# Patrol constants
const PATROL_WAIT_TIME = 2.0
const PATROL_POINT_THRESHOLD = 10.0

# Drone states
enum DroneState {
	PATROLLING,
	DETECTING,
	CHASING,
	SEARCHING,
	RETURNING
}

# Current state and timers
var current_state = DroneState.PATROLLING
var detection_timer = 0.0
var lose_target_timer = 0.0
var patrol_wait_timer = 0.0

# Patrol system
var patrol_points: Array[Vector2] = []
var current_patrol_index = 0
var patrol_direction = 1  # 1 for forward, -1 for backward

# Target tracking
var player_reference: Player = null
var last_known_player_position: Vector2
var search_center: Vector2

# Signals
signal player_detected(player)
signal player_lost
signal patrol_completed

@onready var detection_area = $DetectionArea
@onready var vision_cone = $VisionCone
@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D

func _ready():
	# Setup detection area
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_entered)
		detection_area.body_exited.connect(_on_detection_area_exited)
	
	# Find player reference
	player_reference = get_tree().get_first_node_in_group("player")
	
	# Setup default patrol if no points set
	if patrol_points.is_empty():
		setup_default_patrol()
	
	print("Drone ", name, " initialized - State: PATROLLING")

func _physics_process(delta):
	match current_state:
		DroneState.PATROLLING:
			handle_patrol_state(delta)
		DroneState.DETECTING:
			handle_detection_state(delta)
		DroneState.CHASING:
			handle_chase_state(delta)
		DroneState.SEARCHING:
			handle_search_state(delta)
		DroneState.RETURNING:
			handle_return_state(delta)
	
	# Update sprite rotation to face movement direction
	if velocity.length() > 0:
		sprite.rotation = velocity.angle()

func setup_default_patrol():
	# Create a simple back-and-forth patrol around spawn point
	var spawn_pos = global_position
	patrol_points = [
		spawn_pos + Vector2(-100, 0),
		spawn_pos + Vector2(100, 0)
	]

func setup_patrol_points(points: Array[Vector2]):
	# Set custom patrol points
	patrol_points = points
	current_patrol_index = 0

func handle_patrol_state(delta):
	if patrol_points.is_empty():
		return
	
	var target_point = patrol_points[current_patrol_index]
	var distance_to_target = global_position.distance_to(target_point)
	
	if distance_to_target < PATROL_POINT_THRESHOLD:
		# Reached patrol point - wait or move to next
		patrol_wait_timer += delta
		velocity = Vector2.ZERO
		
		if patrol_wait_timer >= PATROL_WAIT_TIME:
			patrol_wait_timer = 0.0
			advance_patrol_point()
	else:
		# Move toward patrol point
		var direction = (target_point - global_position).normalized()
		velocity = direction * PATROL_SPEED
	
	move_and_slide()

func advance_patrol_point():
	if patrol_points.size() <= 1:
		return
	
	current_patrol_index += patrol_direction
	
	# Handle patrol boundaries
	if current_patrol_index >= patrol_points.size():
		current_patrol_index = patrol_points.size() - 2
		patrol_direction = -1
	elif current_patrol_index < 0:
		current_patrol_index = 1
		patrol_direction = 1

func handle_detection_state(delta):
	if not player_reference:
		change_state(DroneState.PATROLLING)
		return
	
	var can_see_player = is_player_in_vision_cone()
	
	if can_see_player:
		detection_timer += delta
		# Face the player while detecting
		var direction_to_player = (player_reference.global_position - global_position).normalized()
		sprite.rotation = direction_to_player.angle()
		
		if detection_timer >= DETECTION_TIME:
			# Player fully detected
			last_known_player_position = player_reference.global_position
			player_detected.emit(player_reference)
			player_reference.on_detected_by_enemy(self)
			change_state(DroneState.CHASING)
	else:
		# Lost sight of player
		detection_timer = 0.0
		change_state(DroneState.PATROLLING)

func handle_chase_state(delta):
	if not player_reference:
		change_state(DroneState.SEARCHING)
		return
	
	var can_see_player = is_player_in_vision_cone()
	
	if can_see_player:
		# Continue chasing
		last_known_player_position = player_reference.global_position
		lose_target_timer = 0.0
		
		var direction_to_player = (player_reference.global_position - global_position).normalized()
		velocity = direction_to_player * CHASE_SPEED
		sprite.rotation = direction_to_player.angle()
	else:
		# Lost sight - start timer
		lose_target_timer += delta
		
		if lose_target_timer >= LOSE_TARGET_TIME:
			search_center = last_known_player_position
			change_state(DroneState.SEARCHING)
		else:
			# Continue toward last known position
			var direction = (last_known_player_position - global_position).normalized()
			velocity = direction * CHASE_SPEED
	
	move_and_slide()

func handle_search_state(delta):
	# Simple search pattern around last known position
	var distance_to_search_center = global_position.distance_to(search_center)
	
	if distance_to_search_center > 300.0:
		# Too far from search area, return to patrol
		change_state(DroneState.RETURNING)
		return
	
	# Check if player is visible during search
	if player_reference and is_player_in_vision_cone():
		last_known_player_position = player_reference.global_position
		change_state(DroneState.CHASING)
		return
	
	# Simple circular search pattern
	var search_radius = 50.0
	var search_angle = Time.get_time_dict_from_system()["second"] * 0.1  # Slow rotation
	var search_target = search_center + Vector2(cos(search_angle), sin(search_angle)) * search_radius
	
	var direction = (search_target - global_position).normalized()
	velocity = direction * PATROL_SPEED
	sprite.rotation = direction.angle()
	
	move_and_slide()
	
	# Timeout search after a while
	lose_target_timer += delta
	if lose_target_timer > LOSE_TARGET_TIME * 2:
		change_state(DroneState.RETURNING)

func handle_return_state(delta):
	# Return to nearest patrol point
	if patrol_points.is_empty():
		change_state(DroneState.PATROLLING)
		return
	
	var nearest_point = patrol_points[current_patrol_index]
	var distance = global_position.distance_to(nearest_point)
	
	if distance < PATROL_POINT_THRESHOLD:
		change_state(DroneState.PATROLLING)
		return
	
	var direction = (nearest_point - global_position).normalized()
	velocity = direction * PATROL_SPEED
	sprite.rotation = direction.angle()
	
	move_and_slide()

func is_player_in_vision_cone() -> bool:
	if not player_reference:
		return false
	
	var distance_to_player = global_position.distance_to(player_reference.global_position)
	if distance_to_player > DETECTION_RANGE:
		return false
	
	# Check if player is within vision cone
	var direction_to_player = (player_reference.global_position - global_position).normalized()
	var drone_forward = Vector2.RIGHT.rotated(sprite.rotation)
	var angle_to_player = rad_to_deg(abs(drone_forward.angle_to(direction_to_player)))
	
	if angle_to_player > DETECTION_ANGLE / 2:
		return false
	
	# Apply stealth detection modifier
	var detection_chance = 1.0
	if player_reference.has_method("get_detection_multiplier"):
		detection_chance = player_reference.get_detection_multiplier()
	
	# Simple raycast check for line of sight
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player_reference.global_position)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	if result and result.collider != player_reference:
		return false  # Something is blocking the view
	
	return randf() < detection_chance

func change_state(new_state: DroneState):
	if current_state == new_state:
		return
	
	# Exit current state
	match current_state:
		DroneState.DETECTING:
			detection_timer = 0.0
		DroneState.CHASING:
			lose_target_timer = 0.0
		DroneState.SEARCHING:
			lose_target_timer = 0.0
	
	current_state = new_state
	print("Drone ", name, " changed state to: ", DroneState.keys()[new_state])

func _on_detection_area_entered(body):
	if body is Player and current_state == DroneState.PATROLLING:
		change_state(DroneState.DETECTING)

func _on_detection_area_exited(body):
	if body is Player and current_state == DroneState.DETECTING:
		change_state(DroneState.PATROLLING)

# Public methods for level designers
func set_patrol_route(points: Array[Vector2]):
	setup_patrol_points(points)

func get_current_state() -> DroneState:
	return current_state
