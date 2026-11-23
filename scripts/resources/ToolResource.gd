## ToolResource.gd
## Recurso base de herramienta. Crea instancias .tres desde el inspector y arrástralas
## al array `tools` de InventoryUI.
class_name ToolResource
extends Resource

# IDs canónicos: los hazards los usan como valores por defecto de `required_tool`.
const ID_GAS_MASK: String = "Máscara Antigás"
const ID_NEUTRALIZER_KIT: String = "Kit Neutralizante"
const ID_EXTINGUISHER: String = "Extintor"
const ID_SEALING_TAPE: String = "Cinta de Sellado"
const ID_WRENCH: String = "Llave Inglesa"
const ID_ABSORBENT_RAG: String = "Trapo Absorbente"
const ID_HAZARD_TAPE: String = "Cinta de Peligro"

## Identificador único; es el string que viaja por EventBus.tool_equipped.
@export var tool_id: String = ""
## Icono mostrado en el slot de la hotbar.
@export var icon: Texture2D
## Nombre visible (si está vacío se usa tool_id). Se muestra como texto si no hay icono.
@export var display_name: String = ""
## Herramienta pasiva: basta con poseerla en la hotbar (p. ej. Máscara Antigás).
@export var is_passive: bool = false


## Nombre para mostrar en UI.
func get_label() -> String:
	return display_name if not display_name.is_empty() else tool_id
