## InspectorManual.gd
## Manual desplegable tipo cajón. Un Tween anima position:y entre fuera de pantalla y el centro.
## Contiene la base de datos local de amenazas y la paginación.
## Comunicación: SOLO vía EventBus.
class_name InspectorManual
extends Control

@export_group("Drawer")
@export var panel_size: Vector2 = Vector2(720.0, 460.0)
@export var open_duration: float = 0.35
@export var close_duration: float = 0.25
@export var open_button_text: String = "Manual"
@export var close_button_text: String = "Cerrar"

## Base de datos local: una entrada por amenaza (Array de Dictionary).
@export var pages: Array[Dictionary] = [
	{
		"id": "chemical_spill",
		"title": "Derrame Químico (Cloro y Alcohol)",
		"text": "[b]Equipo:[/b] Máscara Antigás (pasiva) + Kit Neutralizante (activa).\n"
			+ "1. Colócate la máscara antes de acercarte.\n"
			+ "2. [color=red]Nunca mezcles cloro con alcohol[/color]: genera gases tóxicos.\n"
			+ "3. Aplica el kit neutralizante desde el borde hacia el centro.",
	},
	{
		"id": "fire",
		"title": "Incendio",
		"text": "[b]Equipo:[/b] Extintor.\n"
			+ "1. Apunta a la [b]base[/b] de las llamas.\n"
			+ "2. Barre de lado a lado manteniendo la salida a tu espalda.\n"
			+ "3. Si el fuego crece, evacúa.",
	},
	{
		"id": "toxic_gas",
		"title": "Gases Tóxicos",
		"text": "[b]Equipo:[/b] Cinta de Sellado + Máscara Antigás.\n"
			+ "1. Sin máscara recibes daño continuo: equípala primero.\n"
			+ "2. Sella la fuente de la fuga con la cinta.\n"
			+ "3. Ventila la zona.",
	},
	{
		"id": "gas_leak",
		"title": "Fuga de Gas",
		"text": "[b]Equipo:[/b] Llave Inglesa.\n"
			+ "1. No accionar interruptores ni llamas.\n"
			+ "2. Cierra la válvula con un cuarto de vuelta de la llave.\n"
			+ "3. Ventila el área.",
	},
	{
		"id": "falls",
		"title": "Caídas",
		"text": "[b]Equipo:[/b] Trapo Absorbente.\n"
			+ "1. Seca de inmediato líquidos en el piso.\n"
			+ "2. Señaliza la zona mientras se seca.",
	},
	{
		"id": "bad_infrastructure",
		"title": "Infraestructura en Mal Estado",
		"text": "[b]Equipo:[/b] Cinta de Peligro.\n"
			+ "1. No toques estructuras dañadas.\n"
			+ "2. Bloquea el paso con la cinta de peligro y reporta.",
	},
	{
		"id": "earthquake",
		"title": "Terremoto",
		"text": "[b]Protocolo:[/b]\n"
			+ "1. Ve junto a una [b]pared segura[/b].\n"
			+ "2. [color=red]Nunca bajo la escalera[/color].\n"
			+ "3. Permanece [b]inmóvil 5 segundos[/b] hasta que pase el temblor.",
	},
]

var current_page: int = 0
var is_open: bool = false

var _panel: PanelContainer
var _title_label: Label
var _body: RichTextLabel
var _page_label: Label
var _prev_button: Button
var _next_button: Button
var _toggle_button: Button
var _tween: Tween
var _closed_y: float = 0.0
var _open_y: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_recompute_positions()
	_panel.position.y = _closed_y
	get_viewport().size_changed.connect(_on_viewport_resized)
	_update_page()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Drawer"
	_panel.size = panel_size
	add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = false
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("normal_font_size", 20)
	_body.add_theme_font_size_override("bold_font_size", 20)
	vbox.add_child(_body)

	var nav: HBoxContainer = HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 24)
	vbox.add_child(nav)

	_prev_button = _make_button("<", Vector2(88.0, 64.0))
	_page_label = Label.new()
	_next_button = _make_button(">", Vector2(88.0, 64.0))
	nav.add_child(_prev_button)
	nav.add_child(_page_label)
	nav.add_child(_next_button)
	_prev_button.pressed.connect(prev_page)
	_next_button.pressed.connect(next_page)

	# Botón de abrir/cerrar siempre visible, esquina superior derecha.
	_toggle_button = _make_button(open_button_text, Vector2(140.0, 64.0))
	add_child(_toggle_button)
	_toggle_button.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 12
	)
	_toggle_button.pressed.connect(toggle)


func _make_button(label: String, min_size: Vector2) -> Button:
	var button: Button = Button.new()
	button.text = label
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	return button


## Calcula las posiciones Y: fuera de pantalla (arriba) y centrada.
func _recompute_positions() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var width: float = minf(panel_size.x, viewport_size.x - 24.0)
	var height: float = minf(panel_size.y, viewport_size.y - 24.0)
	_panel.size = Vector2(width, height)
	_panel.position.x = (viewport_size.x - width) * 0.5
	_open_y = (viewport_size.y - height) * 0.5
	_closed_y = -height - 32.0


func _on_viewport_resized() -> void:
	_recompute_positions()
	if _tween == null or not _tween.is_running():
		_panel.position.y = _open_y if is_open else _closed_y


# ============================ Cajón animado ====================================
func toggle() -> void:
	if is_open:
		close_manual()
	else:
		open_manual()


func open_manual() -> void:
	_animate(true)


func close_manual() -> void:
	_animate(false)


func _animate(open: bool) -> void:
	is_open = open
	_toggle_button.text = close_button_text if open else open_button_text
	if _tween != null and _tween.is_valid():
		_tween.kill()
	# Un Tween nuevo por transición; se libera solo al terminar.
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_BACK if open else Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	var target_y: float = _open_y if open else _closed_y
	var duration: float = open_duration if open else close_duration
	_tween.tween_property(_panel, "position:y", target_y, duration)
	EventBus.manual_toggled.emit(open)


# ============================ Paginación =======================================
func next_page() -> void:
	# Se detiene en la última página (sin desbordar el índice).
	if pages.is_empty() or current_page >= pages.size() - 1:
		return
	current_page += 1
	_update_page()


func prev_page() -> void:
	if pages.is_empty() or current_page <= 0:
		return
	current_page -= 1
	_update_page()


## Salta a la página de una amenaza por id.
func go_to_hazard(hazard_id: String) -> void:
	for i: int in pages.size():
		if String(pages[i].get("id", "")) == hazard_id:
			current_page = i
			_update_page()
			return


func _update_page() -> void:
	if pages.is_empty():
		_title_label.text = "Sin información"
		_body.text = ""
		_page_label.text = "0 / 0"
		_prev_button.disabled = true
		_next_button.disabled = true
		return
	current_page = clampi(current_page, 0, pages.size() - 1)
	var entry: Dictionary = pages[current_page]
	var title: String = String(entry.get("title", ""))
	var text: String = String(entry.get("text", ""))
	_title_label.text = title
	_body.text = text # bbcode_enabled => se parsea una sola vez por cambio de página.
	_page_label.text = "%d / %d" % [current_page + 1, pages.size()]
	_prev_button.disabled = current_page == 0
	_next_button.disabled = current_page == pages.size() - 1
	EventBus.manual_page_changed.emit(title, text)
