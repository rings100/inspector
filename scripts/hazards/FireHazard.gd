## FireHazard.gd
## Incendio. Requiere "Extintor". Durante RESOLVING, _process() reduce la escala del
## nodo de fuego vinculado hasta apagarlo (solo corre en ese estado, ver BaseHazard).
class_name FireHazard
extends BaseHazard

## Nodo visual del fuego (partículas / malla) que se encoge.
@export var fire_node: Node3D
## Escala mínima antes de ocultarlo (evita matriz singular con escala 0 exacta).
@export var min_scale: float = 0.001

var _fire_initial_scale: Vector3 = Vector3.ONE


func _init() -> void:
	hazard_id = "fire"
	hazard_name = "Incendio"
	required_tool = ToolResource.ID_EXTINGUISHER


func _ready() -> void:
	super()
	if fire_node != null:
		_fire_initial_scale = fire_node.scale
	else:
		push_warning("FireHazard '%s': fire_node no asignado." % name)


## Sobrescribe el _process base: encoge el fuego de forma proporcional al progreso.
func _process(delta: float) -> void:
	var ratio: float = _advance_progress(delta)
	if fire_node != null:
		fire_node.scale = _fire_initial_scale * maxf(1.0 - ratio, min_scale)
	if ratio >= 1.0:
		_finish()


func _on_resolved() -> void:
	# Escala llegó a 0: el fuego queda apagado y oculto.
	if fire_node != null:
		fire_node.visible = false
