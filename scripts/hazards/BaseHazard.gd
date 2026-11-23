## BaseHazard.gd
## Máquina de estados base de las amenazas: ACTIVE -> RESOLVING -> RESOLVED.
## Es un Area3D en la capa de interactuables para que el RayCast3D del jugador la detecte.
## Solo progresa si la herramienta equipada (recibida por EventBus.tool_equipped) coincide
## con `required_tool`. Las subclases extienden los hooks virtuales (prefijo `_`).
class_name BaseHazard
extends Area3D

enum State { ACTIVE, RESOLVING, RESOLVED }

## Señales locales del propio hazard (la UI no las usa; la UI solo escucha EventBus).
signal state_changed(new_state: State)
signal interaction_denied(reason: String)

@export_group("Hazard")
## ID usado en EventBus.hazard_resolved. Si está vacío se deriva del nombre del nodo.
@export var hazard_id: String = ""
## Nombre mostrado al apuntar (EventBus.hazard_targeted).
@export var hazard_name: String = "Amenaza"
## tool_id de la herramienta activa necesaria.
@export var required_tool: String = ""
## Segundos que tarda en resolverse tras iniciar la interacción.
@export_range(0.1, 30.0, 0.1) var resolve_duration: float = 2.0
## Capa de física de interactuables (debe coincidir con la máscara del RayCast3D del jugador).
@export_flags_3d_physics var interactable_layer: int = 2

var state: State = State.ACTIVE
var _equipped_tool: String = ""
## Progreso 0..1 de la resolución (se conserva si se cancela y se reanuda).
var _progress: float = 0.0


func _ready() -> void:
	if hazard_id.is_empty():
		hazard_id = String(name).to_snake_case()
	collision_layer = interactable_layer
	monitorable = true
	monitoring = false # Las subclases que detecten cuerpos lo activan (ahorra física).
	set_process(false)
	set_physics_process(false)
	# Estado inicial desde el bus: el hazard puede nacer después de equipar.
	_equipped_tool = EventBus.current_tool_id
	EventBus.tool_equipped.connect(_on_tool_equipped)
	EventBus.tool_inventory_changed.connect(_on_inventory_changed)


# ============================ API pública =====================================
func get_hazard_name() -> String:
	return hazard_name


func get_required_tool() -> String:
	return required_tool


## Llamado por PlayerController.interact().
func interact() -> void:
	if state != State.ACTIVE:
		return
	if not _meets_requirements():
		interaction_denied.emit(_get_denied_reason())
		return
	_set_state(State.RESOLVING)


# ============================ Reglas (sobrescribibles) ==========================
func _meets_requirements() -> bool:
	return _equipped_tool == required_tool


func _get_denied_reason() -> String:
	return "Necesitas: %s" % required_tool


# ============================ Máquina de estados ================================
func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	# _process solo corre mientras se resuelve; en ACTIVE/RESOLVED el nodo está inactivo.
	set_process(state == State.RESOLVING)
	state_changed.emit(state)


## Avanza el progreso y lo devuelve (0..1). Reutilizable por subclases con _process propio.
func _advance_progress(delta: float) -> float:
	_progress = minf(_progress + delta / maxf(resolve_duration, 0.01), 1.0)
	return _progress


func _process(delta: float) -> void:
	var ratio: float = _advance_progress(delta)
	_on_progress(ratio)
	if ratio >= 1.0:
		_finish()


## Marca como resuelto, ejecuta el hook visual y notifica al bus.
func _finish() -> void:
	if state == State.RESOLVED:
		return
	_progress = 1.0
	_set_state(State.RESOLVED)
	collision_layer = 0 # Deja de ser apuntable.
	_on_resolved()
	EventBus.hazard_resolved.emit(hazard_id)


# ============================ Hooks virtuales ===================================
## Cada frame mientras RESOLVING con el progreso 0..1.
func _on_progress(_ratio: float) -> void:
	pass


## Una sola vez al resolverse.
func _on_resolved() -> void:
	pass


# ============================ Reacción al inventario ============================
func _on_tool_equipped(tool_id: String) -> void:
	_equipped_tool = tool_id
	_revalidate()


func _on_inventory_changed(_tool_ids: PackedStringArray) -> void:
	_revalidate()


## Si se pierden los requisitos a mitad de resolución, vuelve a ACTIVE (conserva progreso).
func _revalidate() -> void:
	if state == State.RESOLVING and not _meets_requirements():
		_set_state(State.ACTIVE)
