## ChemicalSpillHazard.gd
## Derrame químico (cloro y alcohol).
## Requiere la herramienta ACTIVA "Kit Neutralizante" y la PASIVA "Máscara Antigás"
## (basta con poseerla en la hotbar, no hace falta tenerla seleccionada).
class_name ChemicalSpillHazard
extends BaseHazard

## Herramienta pasiva que debe estar en el inventario.
@export var passive_tool: String = ToolResource.ID_GAS_MASK
## Visual del charco (opcional): se encoge mientras se neutraliza y se oculta al final.
@export var spill_visual: Node3D

var _spill_initial_scale: Vector3 = Vector3.ONE


func _init() -> void:
	hazard_id = "chemical_spill"
	hazard_name = "Derrame Químico (Cloro y Alcohol)"
	required_tool = ToolResource.ID_NEUTRALIZER_KIT


func _ready() -> void:
	super()
	if spill_visual != null:
		_spill_initial_scale = spill_visual.scale


func _meets_requirements() -> bool:
	# Activa equipada + pasiva poseída.
	return super() and EventBus.owned_tool_ids.has(passive_tool)


func _get_denied_reason() -> String:
	if not EventBus.owned_tool_ids.has(passive_tool):
		return "Necesitas: %s" % passive_tool
	return super()


func _on_progress(ratio: float) -> void:
	if spill_visual != null:
		# Mínimo 0.001: evita bases no invertibles.
		spill_visual.scale = _spill_initial_scale * maxf(1.0 - ratio, 0.001)


func _on_resolved() -> void:
	if spill_visual != null:
		spill_visual.visible = false
