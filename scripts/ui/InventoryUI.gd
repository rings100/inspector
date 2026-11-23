## InventoryUI.gd
## Hotbar estilo Minecraft: 9 slots en un HBoxContainer anclado a PRESET_BOTTOM_WIDE.
## Se construye 100% por código (se pueden añadir assets visuales después).
## Comunicación: SOLO vía EventBus (no referencia nada del mundo 3D).
class_name InventoryUI
extends Control

const SLOT_COUNT: int = 9

## Herramientas asignadas por orden a los slots (máx. 9). Arrastra los .tres aquí.
@export var tools: Array[ToolResource] = []
@export_group("Layout")
@export var slot_size: Vector2 = Vector2(88.0, 88.0)
@export var slot_separation: int = 8
@export var bottom_margin: int = 12
@export_group("Colors")
@export var normal_color: Color = Color(0.15, 0.15, 0.15, 0.75)
@export var selected_color: Color = Color(1.0, 0.85, 0.2, 0.95)
@export var border_width: int = 4

var _hbox: HBoxContainer
var _slots: Array[Button] = []
var _styles_normal: StyleBoxFlat
var _styles_selected: StyleBoxFlat
## -1 = ninguna herramienta equipada.
var _selected_index: int = -1


func _ready() -> void:
	# El contenedor raíz no debe bloquear toques destinados al mundo 3D.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_styles()
	_build_hotbar()
	_publish_inventory()


## Construye los StyleBox una sola vez (se reutilizan en todos los slots).
func _build_styles() -> void:
	_styles_normal = StyleBoxFlat.new()
	_styles_normal.bg_color = normal_color
	_styles_normal.set_border_width_all(2)
	_styles_normal.border_color = Color(0.0, 0.0, 0.0, 0.9)
	_styles_selected = _styles_normal.duplicate() as StyleBoxFlat
	_styles_selected.border_color = selected_color
	_styles_selected.set_border_width_all(border_width)


func _build_hotbar() -> void:
	_hbox = HBoxContainer.new()
	_hbox.name = "Hotbar"
	_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_hbox.add_theme_constant_override("separation", slot_separation)
	_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hbox)
	# Ancla ancha inferior: ocupa todo el ancho, pegada al borde de abajo.
	_hbox.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hbox.offset_top = -(slot_size.y + float(bottom_margin))
	_hbox.offset_bottom = -float(bottom_margin)

	for i: int in SLOT_COUNT:
		var slot: Button = Button.new()
		slot.name = "Slot%d" % i
		slot.custom_minimum_size = slot_size
		slot.focus_mode = Control.FOCUS_NONE
		slot.expand_icon = true
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.clip_text = true
		slot.add_theme_font_size_override("font_size", 12)
		_apply_slot_style(slot, false)
		_hbox.add_child(slot)
		# bind(i): cada botón avisa con su índice. Soporta toque y clic.
		slot.pressed.connect(_on_slot_pressed.bind(i))
		_slots.append(slot)
		_refresh_slot(i)


## Rellena icono/texto del slot según la herramienta asignada.
func _refresh_slot(index: int) -> void:
	var slot: Button = _slots[index]
	var tool_res: ToolResource = _get_tool(index)
	if tool_res == null:
		slot.icon = null
		slot.text = ""
		slot.disabled = true
		slot.tooltip_text = ""
		return
	slot.disabled = false
	slot.icon = tool_res.icon
	# Sin icono se muestra el nombre, para poder probar sin arte.
	slot.text = "" if tool_res.icon != null else tool_res.get_label()
	slot.tooltip_text = tool_res.get_label()


func _get_tool(index: int) -> ToolResource:
	if index < 0 or index >= tools.size():
		return null
	return tools[index]


func _apply_slot_style(slot: Button, selected: bool) -> void:
	var style: StyleBoxFlat = _styles_selected if selected else _styles_normal
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		slot.add_theme_stylebox_override(state, style)


# ============================ Selección ========================================
func _on_slot_pressed(index: int) -> void:
	select_slot(index)


## Resalta el slot y emite tool_equipped. Tocar el slot activo lo desequipa.
func select_slot(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	var tool_res: ToolResource = _get_tool(index)
	if tool_res == null:
		return
	var new_index: int = -1 if index == _selected_index else index
	_set_highlight(new_index)
	var tool_id: String = "" if new_index == -1 else tool_res.tool_id
	EventBus.tool_equipped.emit(tool_id)


func _set_highlight(new_index: int) -> void:
	if _selected_index >= 0:
		_apply_slot_style(_slots[_selected_index], false)
		_slots[_selected_index].scale = Vector2.ONE
	_selected_index = new_index
	if _selected_index >= 0:
		_apply_slot_style(_slots[_selected_index], true)


## Publica qué herramientas se poseen (las pasivas, como la máscara, lo requieren).
func _publish_inventory() -> void:
	var ids: PackedStringArray = PackedStringArray()
	for tool_res: ToolResource in tools:
		if tool_res != null and not tool_res.tool_id.is_empty():
			ids.append(tool_res.tool_id)
	EventBus.tool_inventory_changed.emit(ids)


## API para añadir una herramienta en caliente (p. ej. recogida en el nivel).
func set_tool(index: int, tool_res: ToolResource) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	while tools.size() <= index:
		tools.append(null)
	tools[index] = tool_res
	_refresh_slot(index)
	_publish_inventory()
