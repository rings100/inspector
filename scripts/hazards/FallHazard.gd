## FallHazard.gd
## Riesgo de caídas (piso mojado, derrames). Requiere "Trapo Absorbente".
class_name FallHazard
extends BaseHazard

## Visual del charco / piso mojado (opcional): se encoge al secar y se oculta al final.
@export var wet_visual: Node3D

var _wet_initial_scale: Vector3 = Vector3.ONE


func _init() -> void:
	hazard_id = "fall"
	hazard_name = "Riesgo de Caídas"
	required_tool = ToolResource.ID_ABSORBENT_RAG


func _ready() -> void:
	super()
	if wet_visual != null:
		_wet_initial_scale = wet_visual.scale


func _on_progress(ratio: float) -> void:
	if wet_visual != null:
		wet_visual.scale = _wet_initial_scale * maxf(1.0 - ratio, 0.001)


func _on_resolved() -> void:
	if wet_visual != null:
		wet_visual.visible = false
