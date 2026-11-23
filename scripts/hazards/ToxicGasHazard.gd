## ToxicGasHazard.gd
## Gases tóxicos. Requiere "Cinta de Sellado" para resolverse.
## Mientras no esté resuelto, inflige daño continuo (EventBus.player_damaged) al jugador que
## esté dentro del área sin la "Máscara Antigás" en el inventario activo.
## El daño se envía en ticks (no cada frame) para no saturar el bus en móvil.
class_name ToxicGasHazard
extends BaseHazard

## Herramienta que protege del gas.
@export var protection_tool: String = ToolResource.ID_GAS_MASK
## false: basta con poseer la máscara en la hotbar; true: debe estar seleccionada.
@export var require_mask_equipped: bool = false
@export var damage_per_second: float = 8.0
## Segundos entre emisiones de daño.
@export_range(0.1, 2.0, 0.05) var damage_tick_interval: float = 0.5
## Capa(s) donde vive el jugador (para detectarlo con el área).
@export_flags_3d_physics var player_detect_mask: int = 1

var _player_inside: bool = false
var _tick_accum: float = 0.0


func _init() -> void:
	hazard_id = "toxic_gas"
	hazard_name = "Gases Tóxicos"
	required_tool = ToolResource.ID_SEALING_TAPE


func _ready() -> void:
	super()
	collision_mask = player_detect_mask
	monitoring = true # Esta amenaza sí necesita detectar cuerpos.
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if state == State.RESOLVED or not body.is_in_group("player"):
		return
	_player_inside = true
	_tick_accum = 0.0
	set_physics_process(true) # Solo corre con el jugador dentro.


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not _player_inside or _has_protection():
		_tick_accum = 0.0
		return
	_tick_accum += delta
	if _tick_accum >= damage_tick_interval:
		EventBus.player_damaged.emit(damage_per_second * _tick_accum)
		_tick_accum = 0.0


func _has_protection() -> bool:
	if require_mask_equipped:
		return _equipped_tool == protection_tool
	return EventBus.owned_tool_ids.has(protection_tool)


func _on_resolved() -> void:
	# Fuga sellada: se apaga el daño y la detección.
	_player_inside = false
	set_physics_process(false)
	set_deferred("monitoring", false)
