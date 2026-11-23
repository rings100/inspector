## PlayerController.gd
## Controlador en primera persona para móvil (dos joysticks virtuales).
##
## Árbol de escena esperado:
##   Player (CharacterBody3D)  <- este script (torso: gira 360° en Y)
##   ├─ CollisionShape3D
##   └─ Head (Node3D)          <- "cuello": yaw ±90° respecto al torso, pitch ±85°
##      └─ Camera3D
##         └─ InteractRay (RayCast3D)  <- centro de pantalla, apunta a -Z
##
## La UI NO se referencia aquí: los joysticks emiten EventBus.move_input_changed /
## look_input_changed y este script solo escucha el bus.
class_name PlayerController
extends CharacterBody3D

# --------------------------- Movimiento ------------------------------------
@export_group("Movement")
## Velocidad máxima de caminata (m/s).
@export var move_speed: float = 3.5
## Aceleración al empezar a moverse (m/s²).
@export var acceleration: float = 18.0
## Frenado al soltar el joystick (m/s²).
@export var friction: float = 22.0
## Si es true, la gravedad se lee de ProjectSettings; si no, se usa gravity_override.
@export var use_project_gravity: bool = true
@export var gravity_override: float = 9.8

# --------------------------- Mirada / cuello --------------------------------
@export_group("Look")
## Velocidad angular máxima del joystick derecho (°/s).
@export var look_speed_deg: float = 140.0
## Zona muerta del joystick (0..1).
@export_range(0.0, 0.5, 0.01) var joystick_deadzone: float = 0.12
## Arco periférico del cuello: ±90° = 180° totales respecto al torso.
@export_range(0.0, 180.0, 1.0) var neck_yaw_limit_deg: float = 90.0
## Límite de cabeceo (±85°).
@export_range(0.0, 89.0, 1.0) var pitch_limit_deg: float = 85.0
## Velocidad (°/s) a la que el torso se alinea con la cabeza mientras caminas.
@export var torso_align_speed_deg: float = 120.0
## Invierte el eje vertical del joystick de mirada.
@export var invert_look_y: bool = false

# --------------------------- Cámara -----------------------------------------
@export_group("Camera")
## FOV vertical en pantallas apaisadas (landscape).
@export_range(50.0, 120.0, 1.0) var fov_landscape: float = 78.0
## FOV horizontal en pantallas verticales (portrait): se usa con KEEP_WIDTH.
@export_range(50.0, 120.0, 1.0) var fov_portrait_horizontal: float = 95.0

# --------------------------- Head bobbing ------------------------------------
@export_group("Head Bob")
@export var bob_enabled: bool = true
## Fase por metro recorrido (rad/m): controla la cadencia de los pasos.
@export var bob_frequency: float = 2.6
@export var bob_amplitude_y: float = 0.045
@export var bob_amplitude_x: float = 0.025
## Suavizado de entrada/salida del bobbing.
@export var bob_blend_speed: float = 8.0

# --------------------------- Interacción -------------------------------------
@export_group("Interaction")
## Capa de física de interactuables (capa 2 = valor de bitmask 2).
@export_flags_3d_physics var interact_collision_mask: int = 2
@export var interact_distance: float = 2.5
## Intervalo del sondeo del rayo (s). 0.1 s evita consultar física cada frame.
@export var ray_poll_interval: float = 0.1

# --------------------------- Salud -------------------------------------------
@export_group("Health")
@export var max_health: float = 100.0

# --------------------------- Entrada (joysticks virtuales) --------------------
## Joystick izquierdo: x = strafe, y = adelante (-1) / atrás (+1).
var move_input: Vector2 = Vector2.ZERO
## Joystick derecho: x = giro, y = cabeceo.
var look_input: Vector2 = Vector2.ZERO

# --------------------------- Estado interno -----------------------------------
var health: float = 0.0
## Offsets externos de cámara (los escribe EarthquakeSystem vía apply_camera_shake).
var _shake_offset: Vector3 = Vector3.ZERO
var _shake_roll: float = 0.0

var _head_yaw: float = 0.0
var _pitch: float = 0.0
var _bob_phase: float = 0.0
var _bob_weight: float = 0.0
var _horizontal_speed: float = 0.0
var _ray_timer: float = 0.0
var _gravity: float = 9.8
var _target: Object = null
var _is_dead: bool = false
## Valores en radianes cacheados para no convertir grados en cada frame.
var _yaw_limit_rad: float = 0.0
var _pitch_limit_rad: float = 0.0
var _look_speed_rad: float = 0.0
var _align_speed_rad: float = 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay


func _ready() -> void:
	add_to_group("player")
	health = max_health
	_gravity = (
		float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
		if use_project_gravity else gravity_override
	)
	_cache_angles()

	# Configuración del rayo central: solo capa de interactuables, detecta Area3D.
	interact_ray.enabled = true
	interact_ray.collision_mask = interact_collision_mask
	interact_ray.collide_with_areas = true
	interact_ray.collide_with_bodies = true
	interact_ray.exclude_parent = true
	interact_ray.target_position = Vector3(0.0, 0.0, -interact_distance)

	# Señales Godot 4: connect directo sobre la señal.
	EventBus.move_input_changed.connect(set_move_input)
	EventBus.look_input_changed.connect(set_look_input)
	EventBus.interact_requested.connect(interact)
	EventBus.player_damaged.connect(_on_player_damaged)
	get_viewport().size_changed.connect(_update_camera_fov)
	_update_camera_fov()
	EventBus.player_health_changed.emit(health, max_health)


# ============================ API pública =====================================
## Llamado por el joystick izquierdo (o vía EventBus).
func set_move_input(value: Vector2) -> void:
	move_input = value.limit_length(1.0)


## Llamado por el joystick derecho (o vía EventBus).
func set_look_input(value: Vector2) -> void:
	look_input = value.limit_length(1.0)


## Usado por EarthquakeSystem: desplazamiento (m) y alabeo (rad) aditivos de la cámara.
func apply_camera_shake(offset: Vector3, roll: float) -> void:
	_shake_offset = offset
	_shake_roll = roll


## Invoca interact() sobre el objeto apuntado, si lo hay.
func interact() -> void:
	if _is_dead or not is_instance_valid(_target):
		return
	if _target.has_method("interact"):
		_target.call("interact")


## Velocidad horizontal actual (la usan los sistemas de quietud, p. ej. terremoto).
func get_planar_speed() -> float:
	return _horizontal_speed


# ============================ Ciclo de vida ====================================
func _process(delta: float) -> void:
	if _is_dead:
		return
	_update_look(delta)
	_update_head_bob(delta)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_update_movement(delta)
	_poll_interaction_ray(delta)


# ============================ Movimiento ======================================
func _update_movement(delta: float) -> void:
	# Gravedad.
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	# Dirección relativa al torso; el joystick analógico escala la velocidad.
	var stick: Vector2 = _apply_deadzone(_get_move_vector())
	var wish: Vector3 = global_transform.basis * Vector3(stick.x, 0.0, stick.y)
	wish.y = 0.0
	var planar: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var rate: float = acceleration if stick != Vector2.ZERO else friction
	planar = planar.move_toward(wish * move_speed, rate * delta)
	velocity.x = planar.x
	velocity.z = planar.z

	move_and_slide()
	_horizontal_speed = Vector2(velocity.x, velocity.z).length()

	# Al caminar, el torso "sigue" a la cabeza: transfiere yaw del cuello al cuerpo.
	if stick != Vector2.ZERO and not is_zero_approx(_head_yaw):
		var max_step: float = _align_speed_rad * delta
		var step: float = clampf(_head_yaw, -max_step, max_step)
		rotate_y(step)
		_head_yaw -= step
		head.rotation.y = _head_yaw


# ============================ Mirada / cuello ==================================
func _update_look(delta: float) -> void:
	var stick: Vector2 = _apply_deadzone(_get_look_vector())
	if stick == Vector2.ZERO:
		return

	# Joystick a la derecha => giro a la derecha (yaw negativo en Godot).
	var yaw_delta: float = -stick.x * _look_speed_rad * delta
	var pitch_sign: float = 1.0 if invert_look_y else -1.0
	_pitch = clampf(
		_pitch + pitch_sign * stick.y * _look_speed_rad * delta,
		-_pitch_limit_rad, _pitch_limit_rad
	)

	# 1) El cuello absorbe el giro hasta ±90° (arco periférico de 180°).
	var new_yaw: float = _head_yaw + yaw_delta
	var clamped_yaw: float = clampf(new_yaw, -_yaw_limit_rad, _yaw_limit_rad)
	# 2) El exceso gira el torso (CharacterBody3D) => rotación libre de 360°.
	var overflow: float = new_yaw - clamped_yaw
	if not is_zero_approx(overflow):
		rotate_y(overflow)
	_head_yaw = clamped_yaw

	head.rotation = Vector3(_pitch, _head_yaw, 0.0)


func _update_camera_fov() -> void:
	# Event-driven (size_changed): no se recalcula cada frame.
	var size: Vector2 = get_viewport().get_visible_rect().size
	if size.y > size.x:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = fov_portrait_horizontal
	else:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = fov_landscape


# ============================ Head bobbing =====================================
func _update_head_bob(delta: float) -> void:
	var speed: float = velocity.length()
	var target_weight: float = 0.0
	if bob_enabled and is_on_floor() and move_speed > 0.0:
		target_weight = clampf(speed / move_speed, 0.0, 1.0)
	_bob_weight = lerpf(_bob_weight, target_weight, minf(bob_blend_speed * delta, 1.0))

	# Fase proporcional a la distancia recorrida: pasos sincronizados a la velocidad.
	_bob_phase = fmod(_bob_phase + speed * bob_frequency * delta, TAU)
	var bob: Vector3 = Vector3(
		cos(_bob_phase * 0.5) * bob_amplitude_x,
		sin(_bob_phase) * bob_amplitude_y,
		0.0
	) * _bob_weight

	camera.position = bob + _shake_offset
	camera.rotation.z = _shake_roll


# ============================ Interacción ======================================
func _poll_interaction_ray(delta: float) -> void:
	# Sondeo a baja frecuencia: no se lee el rayo en cada frame físico.
	_ray_timer += delta
	if _ray_timer < ray_poll_interval:
		return
	_ray_timer = 0.0

	var hit: Object = interact_ray.get_collider() if interact_ray.is_colliding() else null
	if hit == _target:
		return
	_target = hit

	# Solo se emite cuando el objetivo cambia (no en cada sondeo).
	if is_instance_valid(_target) and _target.has_method("get_hazard_name") \
			and _target.has_method("get_required_tool"):
		var hazard_name: String = _target.call("get_hazard_name")
		var required_tool: String = _target.call("get_required_tool")
		EventBus.hazard_targeted.emit(hazard_name, required_tool)
	else:
		EventBus.hazard_targeted.emit("", "")


# ============================ Salud ===========================================
func _on_player_damaged(amount: float) -> void:
	if _is_dead:
		return
	health = clampf(health - amount, 0.0, max_health)
	EventBus.player_health_changed.emit(health, max_health)
	if health <= 0.0:
		_is_dead = true
		velocity = Vector3.ZERO
		EventBus.player_died.emit()


# ============================ Utilidades =======================================
func _cache_angles() -> void:
	_yaw_limit_rad = deg_to_rad(neck_yaw_limit_deg)
	_pitch_limit_rad = deg_to_rad(pitch_limit_deg)
	_look_speed_rad = deg_to_rad(look_speed_deg)
	_align_speed_rad = deg_to_rad(torso_align_speed_deg)


## Reescala el vector tras la zona muerta para evitar saltos al salir de ella.
func _apply_deadzone(v: Vector2) -> Vector2:
	var length: float = v.length()
	if length <= joystick_deadzone:
		return Vector2.ZERO
	return v.normalized() * ((length - joystick_deadzone) / (1.0 - joystick_deadzone))


## Joystick virtual + fallback de teclado (WASD) para probar en escritorio.
func _get_move_vector() -> Vector2:
	if move_input != Vector2.ZERO:
		return move_input
	return Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)


## Joystick virtual + fallback de teclado (flechas) para probar en escritorio.
func _get_look_vector() -> Vector2:
	if look_input != Vector2.ZERO:
		return look_input
	return Vector2(
		float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP))
	)
