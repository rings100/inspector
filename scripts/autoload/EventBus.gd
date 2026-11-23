## EventBus.gd
## Autoload global (patrón Observer). Único canal de comunicación entre la UI y el mundo 3D:
## ningún script de UI referencia nodos del mundo, y viceversa.
## Registrado en project.godot como "EventBus". No declarar class_name (colisiona con el autoload).
extends Node

# ---------------------------------------------------------------------------
# Señales requeridas (Paso 2)
# ---------------------------------------------------------------------------
## El jugador apunta a una amenaza ("" y "" cuando deja de apuntar).
@warning_ignore("unused_signal")
signal hazard_targeted(hazard_name: String, required_tool: String)
## La herramienta activa de la hotbar cambió ("" = manos vacías).
@warning_ignore("unused_signal")
signal tool_equipped(tool_id: String)
## El manual se abrió/cerró.
@warning_ignore("unused_signal")
signal manual_toggled(is_open: bool)
## El manual cambió de página.
@warning_ignore("unused_signal")
signal manual_page_changed(page_title: String, page_text: String)
## Una amenaza fue resuelta.
@warning_ignore("unused_signal")
signal hazard_resolved(hazard_id: String)

# ---------------------------------------------------------------------------
# Señales de soporte (input táctil, inventario pasivo, salud, terremoto)
# ---------------------------------------------------------------------------
## Joystick izquierdo virtual (x: strafe, y: adelante = -1).
@warning_ignore("unused_signal")
signal move_input_changed(direction: Vector2)
## Joystick derecho virtual (x: giro, y: cabeceo).
@warning_ignore("unused_signal")
signal look_input_changed(direction: Vector2)
## Botón táctil de interactuar.
@warning_ignore("unused_signal")
signal interact_requested
## Herramientas poseídas en la hotbar (las pasivas, como la máscara, cuentan por estar aquí).
@warning_ignore("unused_signal")
signal tool_inventory_changed(owned_tool_ids: PackedStringArray)
## Daño recibido por el jugador (gas tóxico, terremoto fallido...).
@warning_ignore("unused_signal")
signal player_damaged(amount: float)
@warning_ignore("unused_signal")
signal player_health_changed(current: float, maximum: float)
@warning_ignore("unused_signal")
signal player_died
@warning_ignore("unused_signal")
signal earthquake_started
## Progreso 0..1 del temporizador de quietud en pared segura.
@warning_ignore("unused_signal")
signal earthquake_hold_progress(ratio: float)
@warning_ignore("unused_signal")
signal earthquake_finished(survived: bool)

# ---------------------------------------------------------------------------
# Estado cacheado: permite a nodos que nacen tarde conocer el último valor emitido.
# ---------------------------------------------------------------------------
var current_tool_id: String = ""
var owned_tool_ids: PackedStringArray = PackedStringArray()


func _ready() -> void:
	tool_equipped.connect(_on_tool_equipped)
	tool_inventory_changed.connect(_on_tool_inventory_changed)


func _on_tool_equipped(tool_id: String) -> void:
	current_tool_id = tool_id


func _on_tool_inventory_changed(tool_ids: PackedStringArray) -> void:
	owned_tool_ids = tool_ids
