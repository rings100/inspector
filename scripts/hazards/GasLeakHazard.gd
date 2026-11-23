## GasLeakHazard.gd
## Fuga de gas. Requiere "Llave Inglesa". Al resolverse, un Tween gira la válvula 90°.
class_name GasLeakHazard
extends BaseHazard

## Nodo visual de la válvula.
@export var valve_node: Node3D
## Eje LOCAL de giro de la válvula.
@export var valve_axis: Vector3 = Vector3.UP
@export var valve_turn_degrees: float = 90.0
@export var valve_turn_duration: float = 0.6
## Visual opcional de la fuga (partículas) que se oculta al cerrar.
@export var leak_visual: Node3D

var _valve_tween: Tween


func _init() -> void:
	hazard_id = "gas_leak"
	hazard_name = "Fuga de Gas"
	required_tool = ToolResource.ID_WRENCH


func _on_resolved() -> void:
	if leak_visual != null:
		leak_visual.visible = false
	if valve_node == null:
		return
	# Interpolamos el ángulo y recomponemos la base: gira sobre un eje local sin alterar escala.
	var start_basis: Basis = valve_node.transform.basis
	var axis: Vector3 = valve_axis.normalized()
	var target_rad: float = deg_to_rad(valve_turn_degrees)
	_valve_tween = create_tween()
	_valve_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_valve_tween.tween_method(
		func(angle: float) -> void:
			valve_node.transform.basis = start_basis * Basis(axis, angle),
		0.0, target_rad, valve_turn_duration
	)
