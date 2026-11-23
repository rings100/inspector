## BadInfrastructureHazard.gd
## Infraestructura en mal estado. Requiere "Cinta de Peligro".
## Al resolverse instancia la cinta (PackedScene) y activa un StaticBody3D que bloquea el paso.
class_name BadInfrastructureHazard
extends BaseHazard

## Escena visual de la cinta de peligro (la aporta el equipo de arte).
@export var tape_scene: PackedScene
## Punto donde se coloca la cinta; si es null se usa la posición de este nodo.
@export var tape_anchor: Node3D
## Bloqueo físico preexistente (con CollisionShape3D). Si es null se crea uno por código.
@export var blocker: StaticBody3D
## Tamaño del bloqueo generado por código.
@export var blocker_size: Vector3 = Vector3(2.0, 2.0, 0.2)
## Capa de física del bloqueo (debe estar en la máscara del jugador).
@export_flags_3d_physics var blocker_layer: int = 1

var _blocker_saved_layer: int = 0


func _init() -> void:
	hazard_id = "bad_infrastructure"
	hazard_name = "Infraestructura en Mal Estado"
	required_tool = ToolResource.ID_HAZARD_TAPE


func _ready() -> void:
	super()
	# El bloqueo existente permanece "apagado" hasta que se coloque la cinta.
	if blocker != null:
		_blocker_saved_layer = blocker.collision_layer if blocker.collision_layer != 0 else blocker_layer
		blocker.collision_layer = 0


func _on_resolved() -> void:
	var body: StaticBody3D = blocker
	if body == null:
		body = _create_blocker()
	else:
		body.collision_layer = _blocker_saved_layer

	# Se instancia una sola vez, al resolver: nunca en _process.
	if tape_scene != null:
		var tape: Node3D = tape_scene.instantiate() as Node3D
		if tape != null:
			body.add_child(tape)


## Crea un StaticBody3D con caja de colisión en la posición del ancla.
func _create_blocker() -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "HazardTapeBlocker"
	body.collision_layer = blocker_layer
	body.collision_mask = 0
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = blocker_size
	shape_node.shape = box
	body.add_child(shape_node)

	var host: Node = get_parent() if get_parent() != null else self
	host.add_child(body)
	body.global_transform = tape_anchor.global_transform if tape_anchor != null else global_transform
	return body
