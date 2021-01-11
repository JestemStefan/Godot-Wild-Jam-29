extends KinematicBody



# StateMachine #
enum States {IDLE, RUNNING, JUMPING, FALLING, FLYING}
var state : int = States.IDLE

# Movement Variables #
const GRAVITY: int = -40
var velocity: Vector3= Vector3.ZERO
const MAX_SPEED: int = 25
const JUMP_SPEED: int = 20
const ACCELERATION: int = 6
const DEACCELERATION: int = 50
const MAX_SLOPE_ANGLE: int = 40
const FLYING_SPEED: int = 50
const HOVER_SPEED: int = 20

var input_movement_vector: Vector2
var direction := Vector3.ZERO
var hover_dir: Vector3


# Camera Variables #
onready var gimbal_x := $GimbalX
onready var gimbal_y := $GimbalX/GimbalY
onready var camera_position := $GimbalX/GimbalY/CameraPosition
const DEFAULT_ROTATION_SPEED: float = 0.2
const FLYING_ROTATION_SPEED: float = 0.2
var mouse_camera_sensitivity: float = 0.2
var look_dir: Vector3

onready var player_mesh: Spatial = $PlayerMesh
onready var anim_tree: AnimationTree = $PlayerMesh/AnimationTree
onready var anim_state_machine: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/state_machine/playback")
onready var goose: Spatial = $GoosePlaceholder

# Cloud collector #
onready var vacuum_muzzle: Area = $PlayerMesh/PullingArea
onready var spawn_cloud = preload("res://scenes/entities/TestCloud.tscn")

var isSucking: bool = false
var isShooting: bool = false


func _ready() -> void:
	
	# enable mouse to rotate camera
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	$PlayerMesh/AnimationPlayer.get_animation("Armature|Idle").loop = true
	$PlayerMesh/AnimationPlayer.get_animation("Armature|Walk").loop = true
	# enter IDLE state at the beggining of the game
	enter_state(States.IDLE)


func enter_state(new_state) -> void:
	
	#change current state to new state
	state = new_state
	
	match state:
		
		States.IDLE:
			# TODO: Despawn goose glider
			goose.visible = false
			mouse_camera_sensitivity = DEFAULT_ROTATION_SPEED
			anim_tree.set("parameters/speed/scale", 1.0)
			anim_state_machine.travel("idle")
		
		States.RUNNING:
			anim_tree.set("parameters/speed/scale", 5.0)
			anim_state_machine.travel("running")
		
		States.JUMPING:
			# add velocity up to jump
			velocity.y += JUMP_SPEED
			anim_tree.set("parameters/speed/scale", 5.0)
			anim_state_machine.travel("jump")
		
		States.FALLING:
			# TODO: Despawn goose glider
			goose.visible = false
			mouse_camera_sensitivity = DEFAULT_ROTATION_SPEED
			anim_tree.set("parameters/speed/scale", 5.0)
			anim_state_machine.travel("falling")
		
		States.FLYING:
			# TODO: Spawn goose glider
			goose.visible = true
			anim_tree.set("parameters/speed/scale", 5.0)
			anim_state_machine.travel("goose_grab")
			
			# change camera rotation speed
			mouse_camera_sensitivity = FLYING_ROTATION_SPEED


func _input(event: InputEvent) -> void:
	# use mouse to rotate view
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		gimbal_x.rotate_y(deg2rad(-event.relative.x * mouse_camera_sensitivity))
		gimbal_y.rotate_x(deg2rad(-event.relative.y * mouse_camera_sensitivity))
		
		gimbal_y.rotation_degrees.x = clamp(gimbal_y.rotation_degrees.x, -75, 40)

	# VACUUM ON/OFF #
	if event is InputEventMouseButton:
		match event.button_index:
			
			1: # LMB
				if event.is_pressed():
					isShooting = true
					isSucking = false
					
				else:
					isShooting = false
			
			2: # RMB
				if event.is_pressed():
					isSucking = true
					isShooting = false
					
				else:
					isSucking = false


func _physics_process(delta: float) -> void:
	process_input(delta)
	process_movement(delta)
	process_actions(delta)


func process_input(_delta: float) -> void:
	input_movement_vector = Vector2.ZERO
	
	input_movement_vector.y += int(Input.is_action_pressed("move_forward")) - int(Input.is_action_pressed("move_backward"))
	input_movement_vector.x += int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	
	match state:
	
	#### IDLE ####################################################################
		States.IDLE:
			input_movement_vector = input_movement_vector.normalized()
		#-----------------------------------------------------------------------
			# if player move then switch state to running
			if input_movement_vector != Vector2.ZERO:
				enter_state(States.RUNNING)
		#-----------------------------------------------------------------------
			
		#-----------------------------------------------------------------------
			# Jumping
			if is_on_floor():
				if Input.is_action_just_pressed("move_jump"):
					enter_state(States.JUMPING)
		#-----------------------------------------------------------------------
			
	#### RUNNING ###############################################################
		States.RUNNING:
			input_movement_vector = input_movement_vector.normalized()
		#-----------------------------------------------------------------------
			# if player don't move then switch state to idle
			if input_movement_vector == Vector2.ZERO:
				enter_state(States.IDLE)
		#-----------------------------------------------------------------------
			
		#-----------------------------------------------------------------------
			# move into direction relative to camera rotation
			direction = Vector3.ZERO
			var camera_xform = camera_position.get_global_transform()
			
			direction += -camera_xform.basis.z * input_movement_vector.y
			direction += camera_xform.basis.x * input_movement_vector.x
			
		
			# Rotate to match looking direction if moving
			if input_movement_vector != Vector2.ZERO:
				look_dir.x = lerp_angle(look_dir.x, direction.x, 0.1)
				look_dir.z = lerp_angle(look_dir.z, direction.z, 0.1)
				
				player_mesh.look_at(player_mesh.global_transform.origin - look_dir, Vector3.UP)
		#-----------------------------------------------------------------------
		
		#-----------------------------------------------------------------------
			# Jump if you are on the floor
			if is_on_floor():
				if Input.is_action_just_pressed("move_jump"):
					enter_state(States.JUMPING)
		#-----------------------------------------------------------------------
		
		
	#### JUMPING ###############################################################
		States.JUMPING:
			input_movement_vector = input_movement_vector.normalized()
		#-----------------------------------------------------------------------
			# move into direction relative to camera rotation
			direction = Vector3.ZERO
			var camera_xform = camera_position.get_global_transform()
			
			direction += -camera_xform.basis.z * input_movement_vector.y
			direction += camera_xform.basis.x * input_movement_vector.x
		#-----------------------------------------------------------------------
		
		#-----------------------------------------------------------------------
			# Start gliding/flying if you press jump while in air
			if Input.is_action_just_pressed("move_jump"):
					enter_state(States.FLYING)
		#-----------------------------------------------------------------------
	
	
	#### FALLING ###############################################################
		States.FALLING:
			input_movement_vector = input_movement_vector.normalized()
		#-----------------------------------------------------------------------
			# move into direction relative to camera rotation
			direction = Vector3.ZERO
			var camera_xform = camera_position.get_global_transform()
			
			direction += -camera_xform.basis.z * input_movement_vector.y
			direction += camera_xform.basis.x * input_movement_vector.x
		#-----------------------------------------------------------------------
		
		#-----------------------------------------------------------------------
			# Start gliding/flying if you press jump while in air
			if Input.is_action_just_pressed("move_jump"):
					enter_state(States.FLYING)
		#-----------------------------------------------------------------------
	
	
	#### FLYING ################################################################
		States.FLYING:
		#-----------------------------------------------------------------------
		# move into direction of camera
			#direction = Vector3.ZERO
			var camera_xform = camera_position.get_global_transform()
			var camera_forward = -camera_xform.basis.z
			var target_dir: Vector3 = Vector3.ZERO
			hover_dir = Vector3.ZERO
			
			target_dir = camera_forward
			hover_dir = camera_xform.basis.x * input_movement_vector.x
			
			
			direction = lerp(direction, target_dir, 0.05)
			
		
			# Rotate to match looking direction if moving
			look_dir.x = lerp_angle(look_dir.x, direction.x, 0.1)
			look_dir.z = lerp_angle(look_dir.z, direction.z, 0.1)
			
			player_mesh.look_at(player_mesh.global_transform.origin - look_dir, Vector3.UP)
			
			if input_movement_vector.y < 0:
				goose.look_at(goose.global_transform.origin + Vector3(direction.x, 0, direction.z), Vector3.UP)
				
			else:
				goose.look_at(goose.global_transform.origin + direction, Vector3.UP)
			
			# goose roll when turning
			var signed_angle = direction.cross(camera_forward).dot(Vector3.UP)
			goose.rotation_degrees.z = 60 * signed_angle
			
			# Cancel flying
			if Input.is_action_just_pressed("move_jump"):
					enter_state(States.FALLING)
		#-----------------------------------------------------------------------
	
	############################################################################


func process_movement(delta : float) -> void:
	
	match state:
		
	#############################################################################
		States.IDLE:
			
			velocity.y += GRAVITY * delta

			var new_velocity: Vector3
			new_velocity = new_velocity.linear_interpolate(velocity, DEACCELERATION * delta)
			
			velocity.x = new_velocity.x
			velocity.z = new_velocity.z
			
			velocity = move_and_slide(velocity, Vector3.UP, 0.05, 4, deg2rad(MAX_SLOPE_ANGLE))
			
			if !is_on_floor():
				enter_state(States.FALLING)
	
	
	#############################################################################
		States.RUNNING:
			
			direction.y = 0
			direction = direction.normalized()
			
			velocity.y += GRAVITY * delta
			
			var new_velocity := velocity
			new_velocity.y = 0
			
			var target := direction
			target *= MAX_SPEED
			
			new_velocity = new_velocity.linear_interpolate(target, ACCELERATION * delta)
			velocity.x = new_velocity.x
			velocity.z = new_velocity.z
			velocity = move_and_slide(velocity, Vector3.UP, 0.05, 4, deg2rad(MAX_SLOPE_ANGLE))
			
			if !is_on_floor():
				enter_state(States.FALLING)
	
	#############################################################################
		States.JUMPING:
			
			direction = direction.normalized()
			
			velocity.y += GRAVITY * delta
			
			var new_velocity := velocity
			
			var target := direction
			target *= MAX_SPEED
			
			new_velocity = new_velocity.linear_interpolate(target, 1 * delta)
			velocity.x = new_velocity.x
			velocity.z = new_velocity.z
			velocity = move_and_slide(velocity, Vector3.UP, 0.05, 4, deg2rad(MAX_SLOPE_ANGLE))
			
			
			if is_on_floor():
				enter_state(States.IDLE)
		
	
	#### FALLING ###############################################################
		States.FALLING:
			
			direction = direction.normalized()
			
			velocity.y += GRAVITY * delta
			
			var new_velocity := velocity
			
			var target := direction
			target *= MAX_SPEED
			
			new_velocity = new_velocity.linear_interpolate(target, 1 * delta)
			velocity.x = new_velocity.x
			velocity.z = new_velocity.z
			velocity = move_and_slide(velocity, Vector3.UP, 0.05, 4, deg2rad(MAX_SLOPE_ANGLE))
			
			if is_on_floor():
				enter_state(States.IDLE)
	
		
	#############################################################################
		States.FLYING:
			
			var target := direction
		
			
			target *= FLYING_SPEED * (1 + input_movement_vector.y)
			
			target += HOVER_SPEED * hover_dir
			
			velocity = lerp(velocity, target, 0.05)
			velocity = move_and_slide(velocity, Vector3.UP, 0.05, 4, deg2rad(MAX_SLOPE_ANGLE))
			
			if is_on_floor():
				enter_state(States.IDLE)


func process_actions(_delta: float) -> void:
	if isSucking:
		pull_clouds()
		
	if isShooting:
		shoot_clouds()


func pull_clouds() -> void:
	var clouds_in_area = vacuum_muzzle.get_overlapping_bodies()
	
	if clouds_in_area.size() > 0:
		for cloud in clouds_in_area:
			cloud.pull(vacuum_muzzle.global_transform.origin)
	else:
		pass


func shoot_clouds() -> void:
	var cloud: Cloud = spawn_cloud.instance()
	
	owner.add_child(cloud)
	cloud.global_transform.origin = vacuum_muzzle.global_transform.origin
	cloud.shoot(-vacuum_muzzle.global_transform.basis.z)


func _on_Muzzle_body_entered(body: Node) -> void:
	if isSucking:
		# TODO: store clouds somewhere
		body.call_deferred("free")